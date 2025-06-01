import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'ocr_cache_manager.dart';
import 'ocr_error_handler.dart';
import 'ocr_performance_monitor.dart';
import '../utils/ocr_image_utils.dart';

class ConsolidatedOCRService {
  static ConsolidatedOCRService? _instance;
  static ConsolidatedOCRService get instance => _instance ??= ConsolidatedOCRService._();
  
  ConsolidatedOCRService._();

  // Core components
  late TextRecognizer _textRecognizer;
  late ICacheManager _cacheManager;
  
  // Configuration
  static OCRServiceConfig _config = const OCRServiceConfig();
  
  // State management
  bool _isInitialized = false;
  int _currentProcessingTasks = 0;
  final List<CancellationToken> _activeTasks = [];
  
  // Constants
  static const int maxConcurrentProcessing = 2;
  static const Duration processingTimeout = Duration(seconds: 30);
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  
  // PriceSmart store profile (as requested - keeping only this one)
  static final _priceSmartProfile = StoreProfile(
    name: 'PriceSmart',
    patterns: [
      RegExp(r'PRICE\s*SMART', caseSensitive: false),
      RegExp(r'PRICESMART', caseSensitive: false),
    ],
    pricePatterns: [
      RegExp(r'(\d+)\s+(\w+(?:\s+\w+)*)\s+(\d+\.\d{2})', multiLine: true),
      RegExp(r'(\w+(?:\s+\w+)*)\s+J?\$?(\d+\.\d{2})', caseSensitive: false),
    ],
  );

  /// Initialize the OCR service with configuration
  Future<void> initialize({OCRServiceConfig? config}) async {
    if (_isInitialized) {
      debugPrint('ConsolidatedOCRService: Already initialized');
      return;
    }

    try {
      _config = config ?? const OCRServiceConfig();
      
      // Initialize core components
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      
      // Initialize cache manager
      _cacheManager = _config.usePersistentCache
          ? OCRCacheManager()
          : MemoryOnlyCacheManager();
      await _cacheManager.initialize();
      
      // Initialize performance monitoring if enabled
      if (_config.enablePerformanceMonitoring) {
        await OCRPerformanceMonitor.initialize();
      }
      
      _isInitialized = true;
      debugPrint('✅ ConsolidatedOCRService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ ConsolidatedOCRService: Failed to initialize - $e');
      rethrow;
    }
  }

  /// Process a single receipt image
  Future<OCRResult> processSingleReceipt(
    String imagePath, {
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
  }) async {
    _ensureInitialized();
    
    final stopwatch = Stopwatch()..start();
    final sessionId = _generateSessionId();
    final token = cancellationToken ?? CancellationToken();
    
    try {
      // Check cache first
      final cacheKey = _generateCacheKey(imagePath);
      final cached = await _cacheManager.getCachedResult(cacheKey);
      if (cached != null) {
        debugPrint('ConsolidatedOCRService: Cache hit for $imagePath');
        return cached;
      }

      // Wait for processing slot
      await _waitForProcessingSlot(priority);
      _currentProcessingTasks++;
      _activeTasks.add(token);

      // Process the image
      final result = await _processImageInternal(
        imagePath, 
        isLongReceipt: false,
        cancellationToken: token,
      );

      // Cache the result
      await _cacheManager.cacheResult(cacheKey, result);

      // Log performance
      stopwatch.stop();
      await _logPerformance(sessionId, imagePath, stopwatch.elapsedMilliseconds, result, false);

      return result;
    } catch (e) {
      stopwatch.stop();
      await _logPerformance(sessionId, imagePath, stopwatch.elapsedMilliseconds, null, false, e.toString());
      rethrow;
    } finally {
      _currentProcessingTasks--;
      _activeTasks.remove(token);
    }
  }

  /// Process a long receipt with multiple sections
  Future<OCRResult> processLongReceipt(
    List<String> sectionPaths, {
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
  }) async {
    _ensureInitialized();
    
    if (sectionPaths.isEmpty) {
      throw OCRException(
        'No receipt sections provided',
        type: OCRErrorType.insufficientSections,
      );
    }

    final stopwatch = Stopwatch()..start();
    final sessionId = _generateSessionId();
    final token = cancellationToken ?? CancellationToken();
    
    try {
      // Check cache
      final cacheKey = _generateLongReceiptCacheKey(sectionPaths);
      final cached = await _cacheManager.getCachedResult(cacheKey);
      if (cached != null) {
        debugPrint('ConsolidatedOCRService: Cache hit for long receipt');
        return cached;
      }

      // Wait for processing slot
      await _waitForProcessingSlot(priority);
      _currentProcessingTasks++;
      _activeTasks.add(token);

      // Process each section
      final sectionResults = <OCRResult>[];
      for (int i = 0; i < sectionPaths.length; i++) {
        if (token.isCancelled) {
          throw CancellationException('Long receipt processing cancelled');
        }
        
        debugPrint('ConsolidatedOCRService: Processing section ${i + 1}/${sectionPaths.length}');
        final sectionResult = await _processImageInternal(
          sectionPaths[i],
          isLongReceipt: true,
          cancellationToken: token,
        );
        sectionResults.add(sectionResult);
      }

      // Merge results
      final mergedResult = _mergeLongReceiptResults(sectionResults);
      
      // Cache the result
      await _cacheManager.cacheResult(cacheKey, mergedResult);

      // Log performance
      stopwatch.stop();
      await _logPerformance(sessionId, cacheKey, stopwatch.elapsedMilliseconds, mergedResult, true);

      return mergedResult;
    } catch (e) {
      stopwatch.stop();
      await _logPerformance(sessionId, sectionPaths.first, stopwatch.elapsedMilliseconds, null, true, e.toString());
      rethrow;
    } finally {
      _currentProcessingTasks--;
      _activeTasks.remove(token);
    }
  }

  /// Internal image processing logic
  Future<OCRResult> _processImageInternal(
    String imagePath, {
    required bool isLongReceipt,
    CancellationToken? cancellationToken,
  }) async {
    try {
      // Load and validate image
      final image = await _loadAndValidateImage(imagePath);
      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      // Preprocess image for optimal OCR
      final preprocessed = await _preprocessImage(image);
      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      // Perform OCR
      final recognizedText = await _performOCR(preprocessed);
      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      // Detect store type
      final storeType = _detectStoreType(recognizedText.text);

      // Extract prices using multiple methods
      final extractedPrices = _extractPrices(recognizedText, storeType);
      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      // Apply NLP enhancements
      final enhancedPrices = _enhancePricesWithNLP(extractedPrices, recognizedText.text, storeType);

      // Calculate confidence
      final confidence = _calculateOverallConfidence(enhancedPrices, recognizedText);

      return OCRResult(
        fullText: recognizedText.text,
        prices: enhancedPrices,
        confidence: confidence,
        enhancement: EnhancementType.hybrid,
        storeType: storeType,
        metadata: {
          'processing_time': DateTime.now().millisecondsSinceEpoch,
          'is_long_receipt': isLongReceipt,
          'original_price_count': extractedPrices.length,
          'enhanced_price_count': enhancedPrices.length,
          'store_detected': storeType,
        },
      );
    } catch (e) {
      debugPrint('ConsolidatedOCRService: Processing failed - $e');
      rethrow;
    }
  }

  /// Load and validate image file
  Future<img.Image> _loadAndValidateImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw OCRException('Image file not found: $imagePath');
    }

    final fileSize = await file.length();
    if (fileSize > maxFileSize) {
      throw OCRException('Image file too large: ${fileSize / (1024 * 1024)}MB');
    }

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw OCRException('Failed to decode image');
    }

    return image;
  }

  /// Preprocess image for optimal OCR accuracy
  Future<img.Image> _preprocessImage(img.Image image) async {
    try {
      // Use the advanced preprocessing from OCRImageUtils
      return await OCRImageUtils.preprocessForOCR(image);
    } catch (e) {
      debugPrint('Advanced preprocessing failed, using lightweight: $e');
      return OCRImageUtils.lightweightPreprocess(image);
    }
  }

  /// Perform OCR using ML Kit
  Future<RecognizedText> _performOCR(img.Image image) async {
    final bytes = img.encodeJpg(image, quality: 90);
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.yuv420,
        bytesPerRow: image.width * 3,
      ),
    );

    return await _textRecognizer.processImage(inputImage)
        .timeout(processingTimeout);
  }

  /// Detect store type from recognized text
  String _detectStoreType(String text) {
    final lowerText = text.toLowerCase();
    
    // Check for PriceSmart patterns
    for (final pattern in _priceSmartProfile.patterns) {
      if (pattern.hasMatch(lowerText)) {
        debugPrint('✅ Detected store: PriceSmart');
        return 'pricesmart';
      }
    }

    // Fallback to generic
    if (lowerText.contains('supermarket') || lowerText.contains('grocery')) {
      return 'generic_supermarket';
    }

    debugPrint('⚠️ Store type not detected, using generic');
    return 'generic';
  }

  /// Extract prices using multiple pattern matching approaches
  List<ExtractedPrice> _extractPrices(RecognizedText recognizedText, String storeType) {
    final prices = <ExtractedPrice>[];
    
    // Method 1: Store-specific patterns
    prices.addAll(_extractWithStorePatterns(recognizedText, storeType));
    
    // Method 2: Generic patterns
    prices.addAll(_extractWithGenericPatterns(recognizedText));
    
    // Method 3: Line-by-line analysis
    prices.addAll(_extractFromLines(recognizedText));
    
    // Deduplicate and validate
    return _deduplicateAndValidatePrices(prices);
  }

  /// Extract prices using store-specific patterns
  List<ExtractedPrice> _extractWithStorePatterns(RecognizedText recognizedText, String storeType) {
    final prices = <ExtractedPrice>[];
    List<RegExp> patterns;

    if (storeType == 'pricesmart') {
      patterns = _priceSmartProfile.pricePatterns;
    } else {
      // Generic patterns
      patterns = [
        RegExp(r'(\w+(?:\s+\w+)*)\s+J?\$?(\d+\.\d{2})', caseSensitive: false),
        RegExp(r'(\w+(?:\s+\w+)*)\s*\*?\s*(\d+\.\d{2})', multiLine: true),
      ];
    }

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text;
        if (_isNonProductLine(text)) continue;

        for (final pattern in patterns) {
          final matches = pattern.allMatches(text);
          for (final match in matches) {
            final itemName = match.group(1)?.trim() ?? '';
            final priceStr = match.group(2) ?? match.group(3) ?? '';
            final price = double.tryParse(priceStr);

            if (price != null && price > 0 && price < 50000 && itemName.isNotEmpty) {
              prices.add(ExtractedPrice(
                itemName: itemName,
                price: price,
                originalText: text,
                confidence: _calculatePatternConfidence(match, text),
                position: _convertBoundingBox(line.boundingBox),
                category: 'Other',
                unit: 'each',
                metadata: {
                  'extraction_method': 'store_pattern',
                  'store_type': storeType,
                },
              ));
            }
          }
        }
      }
    }

    return prices;
  }

  /// Extract prices using generic patterns
  List<ExtractedPrice> _extractWithGenericPatterns(RecognizedText recognizedText) {
    final prices = <ExtractedPrice>[];
    final patterns = [
      RegExp(r'(\w+(?:\s+\w+)*)\s+(\d+\.\d{2})\s*$', multiLine: true),
      RegExp(r'(\w+(?:\s+\w+)*)\s*J\$(\d+\.\d{2})', caseSensitive: false),
      RegExp(r'(\w+(?:\s+\w+)*)\s*\$(\d+\.\d{2})', multiLine: true),
    ];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text;
        if (_isNonProductLine(text)) continue;

        for (final pattern in patterns) {
          final matches = pattern.allMatches(text);
          for (final match in matches) {
            final itemName = match.group(1)?.trim() ?? '';
            final priceStr = match.group(2) ?? '';
            final price = double.tryParse(priceStr);

            if (price != null && price > 0 && price < 50000 && itemName.isNotEmpty) {
              prices.add(ExtractedPrice(
                itemName: itemName,
                price: price,
                originalText: text,
                confidence: _calculatePatternConfidence(match, text),
                position: _convertBoundingBox(line.boundingBox),
                category: 'Other',
                unit: 'each',
                metadata: {'extraction_method': 'generic_pattern'},
              ));
            }
          }
        }
      }
    }

    return prices;
  }

  /// Extract prices from lines using end-of-line price detection
  List<ExtractedPrice> _extractFromLines(RecognizedText recognizedText) {
    final prices = <ExtractedPrice>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (_isNonProductLine(text)) continue;

        final priceMatch = RegExp(r'(\d+\.\d{2})\s*$').firstMatch(text);
        if (priceMatch != null) {
          final priceStr = priceMatch.group(1)!;
          final price = double.tryParse(priceStr);
          
          if (price != null && price > 0 && price < 50000) {
            final itemName = text.substring(0, priceMatch.start).trim();
            if (itemName.isNotEmpty) {
              prices.add(ExtractedPrice(
                itemName: itemName,
                price: price,
                originalText: text,
                confidence: 0.7,
                position: _convertBoundingBox(line.boundingBox),
                category: 'Other',
                unit: 'each',
                metadata: {'extraction_method': 'line_analysis'},
              ));
            }
          }
        }
      }
    }

    return prices;
  }

  /// Apply NLP enhancements to extracted prices
  List<ExtractedPrice> _enhancePricesWithNLP(List<ExtractedPrice> prices, String fullText, String storeType) {
    final enhanced = <ExtractedPrice>[];

    for (final price in prices) {
      final cleanedName = _cleanItemName(price.itemName);
      final category = _detectCategory(cleanedName, price.originalText);
      final unit = _detectUnit(price.originalText, category);

      if (_validatePrice(price.price, category, storeType)) {
        enhanced.add(ExtractedPrice(
          itemName: cleanedName,
          price: price.price,
          originalText: price.originalText,
          confidence: (price.confidence * 1.1).clamp(0.0, 1.0),
          position: price.position,
          category: category,
          unit: unit,
          metadata: {
            ...price.metadata ?? {},
            'nlp_enhanced': true,
            'original_name': price.itemName,
          },
        ));
      }
    }

    return enhanced;
  }

  /// Clean and normalize item names
  String _cleanItemName(String itemName) {
    if (itemName.isEmpty) return 'Unknown Item';
    
    var cleaned = itemName.toLowerCase().trim();
    
    // Remove special characters and normalize spaces
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.trim();

    // Capitalize properly
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Detect item category based on name and context
  String _detectCategory(String itemName, String originalText) {
    final text = '$itemName $originalText'.toLowerCase();
    
    final categoryKeywords = {
      'Meat': ['chicken', 'beef', 'pork', 'fish', 'meat', 'bacon', 'ham'],
      'Produce': ['apple', 'banana', 'orange', 'lettuce', 'tomato', 'onion', 'fruit', 'vegetable'],
      'Dairy': ['milk', 'cheese', 'yogurt', 'butter', 'cream', 'eggs'],
      'Beverages': ['juice', 'soda', 'water', 'drink', 'cola', 'beer', 'wine'],
      'Groceries': ['rice', 'bread', 'flour', 'sugar', 'oil', 'pasta', 'cereal'],
      'Household': ['soap', 'detergent', 'tissue', 'paper', 'cleaning'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return 'Other';
  }

  /// Detect appropriate unit for the item
  String _detectUnit(String originalText, String category) {
    final text = originalText.toLowerCase();
    
    if (RegExp(r'\b(lb|lbs|pound|pounds)\b').hasMatch(text)) return 'per lb';
    if (RegExp(r'\b(kg|kilo|kilogram)\b').hasMatch(text)) return 'per kg';
    if (RegExp(r'\b(gal|gallon|gallons)\b').hasMatch(text)) return 'per gallon';
    if (RegExp(r'\b(l|lt|liter|litre)\b').hasMatch(text)) return 'per liter';
    if (RegExp(r'\b(pk|pack|package)\b').hasMatch(text)) return 'per pack';
    
    // Category-based defaults
    switch (category) {
      case 'Meat':
      case 'Produce':
        return 'per lb';
      case 'Beverages':
        return 'each';
      case 'Dairy':
        return text.contains('eggs') ? 'per dozen' : 'each';
      default:
        return 'each';
    }
  }

  /// Validate if price is reasonable for the category and store
  bool _validatePrice(double price, String category, String storeType) {
    if (price <= 0 || price > 50000) return false;

    final priceRanges = {
      'Meat': {'min': 100, 'max': 5000},
      'Produce': {'min': 20, 'max': 2000},
      'Dairy': {'min': 50, 'max': 2000},
      'Beverages': {'min': 30, 'max': 1500},
      'Groceries': {'min': 25, 'max': 3000},
      'Household': {'min': 50, 'max': 4000},
      'Other': {'min': 10, 'max': 10000},
    };

    final range = priceRanges[category] ?? priceRanges['Other']!;
    
    // PriceSmart typically has higher minimum prices
    final minPrice = storeType == 'pricesmart' 
        ? max(range['min']! * 2, 100.0)
        : range['min']!.toDouble();
    
    return price >= minPrice && price <= range['max']!;
  }

  /// Deduplicate and validate extracted prices
  List<ExtractedPrice> _deduplicateAndValidatePrices(List<ExtractedPrice> prices) {
    final unique = <ExtractedPrice>[];
    
    for (final price in prices) {
      bool isDuplicate = false;
      for (int i = 0; i < unique.length; i++) {
        if (_areSimilarPrices(price, unique[i])) {
          if (price.confidence > unique[i].confidence) {
            unique[i] = price;
          }
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        unique.add(price);
      }
    }

    // Sort by confidence
    unique.sort((a, b) => b.confidence.compareTo(a.confidence));
    return unique;
  }

  /// Check if two prices are similar (likely duplicates)
  bool _areSimilarPrices(ExtractedPrice price1, ExtractedPrice price2) {
    // Same price and close position
    if ((price1.price - price2.price).abs() < 0.01) {
      final distance = _calculateDistance(price1.position.center, price2.position.center);
      return distance < 50;
    }
    return false;
  }

  /// Calculate distance between two points
  double _calculateDistance(Offset point1, Offset point2) {
    return sqrt(pow(point1.dx - point2.dx, 2) + pow(point1.dy - point2.dy, 2));
  }

  /// Merge results from multiple receipt sections
  OCRResult _mergeLongReceiptResults(List<OCRResult> sectionResults) {
    if (sectionResults.isEmpty) {
      return _createEmptyResult();
    }

    final allPrices = <ExtractedPrice>[];
    final allText = <String>[];
    double totalConfidence = 0.0;

    for (int i = 0; i < sectionResults.length; i++) {
      final result = sectionResults[i];
      allPrices.addAll(result.prices);
      allText.add('--- Section ${i + 1} ---\n${result.fullText}');
      totalConfidence += result.confidence;
    }

    // Remove semantic duplicates across sections
    final uniquePrices = _removeSemanticDuplicates(allPrices);
    final avgConfidence = sectionResults.isNotEmpty ? totalConfidence / sectionResults.length : 0.0;

    return OCRResult(
      fullText: allText.join('\n\n'),
      prices: uniquePrices,
      confidence: avgConfidence,
      enhancement: EnhancementType.hybrid,
      storeType: sectionResults.first.storeType,
      metadata: {
        'merged_from_sections': sectionResults.length,
        'total_prices_before_dedup': allPrices.length,
        'unique_prices': uniquePrices.length,
      },
    );
  }

  /// Remove semantic duplicates (similar items across sections)
  List<ExtractedPrice> _removeSemanticDuplicates(List<ExtractedPrice> prices) {
    final unique = <ExtractedPrice>[];
    
    for (final price in prices) {
      bool isDuplicate = false;
      for (int i = 0; i < unique.length; i++) {
        if (_areSemanticallySimilar(price, unique[i])) {
          if (price.confidence > unique[i].confidence) {
            unique[i] = price;
          }
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        unique.add(price);
      }
    }
    
    return unique;
  }

  /// Check if two prices are semantically similar
  bool _areSemanticallySimilar(ExtractedPrice price1, ExtractedPrice price2) {
    final nameSimilarity = _calculateStringSimilarity(
      price1.itemName.toLowerCase(),
      price2.itemName.toLowerCase(),
    );
    
    if (nameSimilarity > 0.8) {
      final priceDiff = (price1.price - price2.price).abs() / max(price1.price, price2.price);
      return priceDiff < 0.15; // 15% price difference tolerance
    }
    
    return false;
  }

  /// Calculate string similarity
  double _calculateStringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final words1 = s1.split(' ').toSet();
    final words2 = s2.split(' ').toSet();
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);
    
    return intersection.length / union.length;
  }

  /// Calculate overall confidence score
  double _calculateOverallConfidence(List<ExtractedPrice> prices, RecognizedText recognizedText) {
    if (prices.isEmpty) return 0.0;

    // Average price confidence
    final avgPriceConfidence = prices.map((p) => p.confidence).reduce((a, b) => a + b) / prices.length;

    // Text recognition confidence
    double textConfidence = 0.8; // Default
    int elementCount = 0;
    double totalTextConfidence = 0.0;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          if (element.confidence != null) {
            totalTextConfidence += element.confidence!;
            elementCount++;
          }
        }
      }
    }

    if (elementCount > 0) {
      textConfidence = totalTextConfidence / elementCount;
    }

    return (avgPriceConfidence * 0.7) + (textConfidence * 0.3);
  }

  /// Calculate pattern confidence based on match quality
  double _calculatePatternConfidence(RegExpMatch match, String fullText) {
    double confidence = 0.6; // Base confidence
    
    final itemName = match.group(1) ?? '';
    final price = match.group(2) ?? '';
    
    // Boost confidence based on quality indicators
    if (itemName.length > 3) confidence += 0.1;
    if (itemName.contains(' ')) confidence += 0.1; // Multi-word items
    if (price.contains('.') && price.length >= 4) confidence += 0.1; // Proper price format
    if (!_isNonProductLine(fullText)) confidence += 0.1; // Not a total/tax line
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Check if line should be skipped (totals, headers, etc.)
  bool _isNonProductLine(String text) {
    final lowerText = text.toLowerCase().trim();
    final skipPatterns = [
      'total', 'subtotal', 'tax', 'cash', 'change', 'thank', 'receipt',
      'date', 'time', 'cashier', 'transaction', 'balance', 'tender'
    ];
    
    for (final pattern in skipPatterns) {
      if (lowerText.contains(pattern)) return true;
    }
    
    if (RegExp(r'^\d+$').hasMatch(lowerText) || lowerText.length < 3) {
      return true;
    }
    
    return false;
  }

  /// Convert bounding box to Rect
  Rect _convertBoundingBox(Rect? boundingBox) {
    return boundingBox ?? Rect.zero;
  }

  /// Wait for available processing slot
  Future<void> _waitForProcessingSlot(ProcessingPriority priority) async {
    while (_currentProcessingTasks >= maxConcurrentProcessing) {
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  /// Generate cache key for single image
  String _generateCacheKey(String imagePath) {
    final file = File(imagePath);
    final fileName = file.path.split('/').last;
    final timestamp = file.lastModifiedSync().millisecondsSinceEpoch;
    return sha256.convert(utf8.encode('$fileName-$timestamp')).toString();
  }

  /// Generate cache key for long receipt
  String _generateLongReceiptCacheKey(List<String> sectionPaths) {
    final combined = sectionPaths.join('|');
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// Generate session ID for tracking
  String _generateSessionId() {
    return 'consolidated_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// Log performance metrics
  Future<void> _logPerformance(String sessionId, String imagePath, int processingTime, OCRResult? result, bool isLongReceipt, [String? error]) async {
    if (!_config.enablePerformanceMonitoring) return;

    await OCRPerformanceMonitor.logOCRAttempt(
      sessionId: sessionId,
      imagePath: imagePath,
      processingTimeMs: processingTime,
      extractedPricesCount: result?.prices.length ?? 0,
      averageConfidence: result?.confidence ?? 0.0,
      bestEnhancement: result?.enhancement.toString() ?? 'none',
      storeType: result?.storeType ?? 'unknown',
      isLongReceipt: isLongReceipt,
      metadata: result?.metadata ?? {},
      errorMessage: error,
    );
  }

  /// Create empty result for error cases
  OCRResult _createEmptyResult() {
    return OCRResult(
      fullText: '',
      prices: [],
      confidence: 0.0,
      enhancement: EnhancementType.original,
      storeType: 'unknown',
      metadata: {'empty_result': true},
    );
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw OCRException(
        'ConsolidatedOCRService not initialized. Call initialize() first.',
        type: OCRErrorType.unknown,
      );
    }
  }

  /// Get system performance metrics
  Future<SystemPerformanceMetrics> getSystemMetrics() async {
    return SystemPerformanceMetrics(
      memoryUsageMB: 200.0, // Mock data - would be real in production
      cpuUsagePercent: 45.0,
      batteryLevel: 80.0,
      thermalState: ThermalState.nominal,
      timestamp: DateTime.now(),
    );
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'initialized': _isInitialized,
      'current_processing_tasks': _currentProcessingTasks,
      'max_concurrent_processing': maxConcurrentProcessing,
      'cache_type': _config.usePersistentCache ? 'persistent' : 'memory',
      'performance_monitoring': _config.enablePerformanceMonitoring,
    };
  }

  /// Clear cache
  Future<void> clearCache() async {
    await _cacheManager.clear();
    debugPrint('ConsolidatedOCRService: Cache cleared');
  }

  /// Cancel all operations
  void cancelAllOperations() {
    for (final token in List.from(_activeTasks)) {
      token.cancel();
    }
    _activeTasks.clear();
  }

  /// Dispose service and cleanup resources
  void dispose() {
    _textRecognizer.close();
    _cacheManager.dispose();
    cancelAllOperations();
    _isInitialized = false;
    debugPrint('ConsolidatedOCRService: Disposed');
  }
}

// Configuration class
class OCRServiceConfig {
  final bool usePersistentCache;
  final int maxRetryAttempts;
  final Duration ocrTimeout;
  final bool enablePerformanceMonitoring;
  final ProcessingPriority defaultPriority;

  const OCRServiceConfig({
    this.usePersistentCache = true,
    this.maxRetryAttempts = 3,
    this.ocrTimeout = const Duration(seconds: 30),
    this.enablePerformanceMonitoring = true,
    this.defaultPriority = ProcessingPriority.normal,
  });
}

// Data classes
class OCRResult {
  final String fullText;
  final List<ExtractedPrice> prices;
  final double confidence;
  final EnhancementType enhancement;
  final String storeType;
  final Map<String, dynamic> metadata;

  OCRResult({
    required this.fullText,
    required this.prices,
    required this.confidence,
    required this.enhancement,
    required this.storeType,
    required this.metadata,
  });
}

class ExtractedPrice {
  final String itemName;
  final double price;
  final String originalText;
  final double confidence;
  final Rect position;
  final String category;
  final String unit;
  final Map<String, dynamic>? metadata;

  ExtractedPrice({
    required this.itemName,
    required this.price,
    required this.originalText,
    required this.confidence,
    required this.position,
    required this.category,
    required this.unit,
    this.metadata,
  });
}

class StoreProfile {
  final String name;
  final List<RegExp> patterns;
  final List<RegExp> pricePatterns;

  StoreProfile({
    required this.name,
    required this.patterns,
    required this.pricePatterns,
  });
}

class SystemPerformanceMetrics {
  final double memoryUsageMB;
  final double cpuUsagePercent;
  final double batteryLevel;
  final ThermalState thermalState;
  final DateTime timestamp;

  SystemPerformanceMetrics({
    required this.memoryUsageMB,
    required this.cpuUsagePercent,
    required this.batteryLevel,
    required this.thermalState,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'memory_usage_mb': memoryUsageMB,
      'cpu_usage_percent': cpuUsagePercent,
      'battery_level': batteryLevel,
      'thermal_state': thermalState.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

// Enums
enum ProcessingPriority { low, normal, high }
enum EnhancementType { original, contrast, brightness, sharpen, grayscale, binarize, hybrid }
enum ThermalState { nominal, fair, serious, critical }

class OCRException implements Exception {
  final String message;
  final OCRErrorType? type;

  OCRException(this.message, {this.type});

  @override
  String toString() => 'OCRException: $message';
}

class CancellationException implements Exception {
  final String message;
  CancellationException([this.message = 'Operation was cancelled']);

  @override
  String toString() => 'CancellationException: $message';
}

// Extension methods for convenience
extension StringOCRExtension on String {
  Future<OCRResult> processAsReceipt({
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
  }) {
    return ConsolidatedOCRService.instance.processSingleReceipt(
      this,
      priority: priority,
      cancellationToken: cancellationToken,
    );
  }
}

extension ListStringOCRExtension on List<String> {
  Future<OCRResult> processAsLongReceipt({
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
  }) {
    return ConsolidatedOCRService.instance.processLongReceipt(
      this,
      priority: priority,
      cancellationToken: cancellationToken,
    );
  }
}
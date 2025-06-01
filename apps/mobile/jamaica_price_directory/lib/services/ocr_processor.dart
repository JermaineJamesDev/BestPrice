import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'dart:math';
import 'nlp_processor.dart';
import 'ocr_error_handler.dart';
import 'ocr_performance_monitor.dart';
import 'ocr_cache_manager.dart';

class OCRProcessor {
  static const double confidenceThreshold = 0.75;
  static const int maxImageDimension = 2048;
  static const int maxProcessingTime = 20000;
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  
  static final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  
  static Interpreter? _priceExtractorModel;
  static bool _isModelLoaded = false;
  static late final ICacheManager _cacheManager;
  static final NLPProcessor _nlpProcessor = NLPProcessor();
  
  // Store profiles for different receipt types
  static final Map<String, StoreProfile> _storeProfiles = {
    'hi-lo': StoreProfile(
      name: 'Hi-Lo',
      patterns: [
        RegExp(r'HI-LO|HI\s*LO', caseSensitive: false),
        RegExp(r'SUPERMARKET', caseSensitive: false),
      ],
      pricePatterns: [
        RegExp(r'(\w+(?:\s+\w+)*)\s+(\d+\.\d{2})\s*$', multiLine: true),
        RegExp(r'(\w+(?:\s+\w+)*)\s*\*?\s*(\d+\.\d{2})', multiLine: true),
      ],
      characteristics: StoreCharacteristics(
        hasItemCodes: true,
        pricePosition: PricePosition.right,
        usesAsterisks: true,
        averageReceiptLength: 15,
      ),
    ),
    'megamart': StoreProfile(
      name: 'MegaMart',
      patterns: [
        RegExp(r'MEGA\s*MART', caseSensitive: false),
      ],
      pricePatterns: [
        RegExp(r'(\w+(?:\s+\w+)*)\s+J\$(\d+\.\d{2})', caseSensitive: false),
        RegExp(r'(\d{4,})\s+(\w+(?:\s+\w+)*)\s+(\d+\.\d{2})', multiLine: true),
      ],
      characteristics: StoreCharacteristics(
        hasItemCodes: true,
        pricePosition: PricePosition.right,
        usesAsterisks: false,
        averageReceiptLength: 20,
      ),
    ),
    'pricesmart': StoreProfile(
      name: 'PriceSmart',
      patterns: [
        RegExp(r'PRICE\s*SMART', caseSensitive: false),
      ],
      pricePatterns: [
        RegExp(r'(\d+)\s+(\w+(?:\s+\w+)*)\s+(\d+\.\d{2})', multiLine: true),
      ],
      characteristics: StoreCharacteristics(
        hasItemCodes: true,
        pricePosition: PricePosition.middle,
        usesAsterisks: false,
        averageReceiptLength: 25,
      ),
    ),
  };

  static Future<void> initialize() async {
    try {
      // Initialize cache manager with DI
      _cacheManager = OCRCacheManager();
      await _cacheManager.initialize();
      
      await _loadPriceExtractorModel();
      await _nlpProcessor.initialize();
      
      debugPrint('✅ Unified OCR Processor initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize OCR processor: $e');
      rethrow;
    }
  }

  static Future<void> _loadPriceExtractorModel() async {
    try {
      // For now, we'll use a placeholder - in production you'd load a real model
      // _priceExtractorModel = await Interpreter.fromAsset(
      //   'assets/models/price_extractor.tflite',
      // );
      _isModelLoaded = false; // Set to true when real model is available
      debugPrint('⚠️ Price extractor model placeholder - ML Kit will be primary');
    } catch (e) {
      debugPrint('⚠️ Failed to load price extractor model: $e');
      _isModelLoaded = false;
    }
  }

  static Future<OCRResult> processReceiptImage(
    String imagePath, {
    bool isLongReceipt = false,
    List<String>? sectionPaths,
  }) async {
    return await OCRErrorRecovery.executeWithRecovery(
      () => _processReceiptImageInternal(imagePath, isLongReceipt: isLongReceipt),
      'processReceiptImage',
      onError: (error, attempt) {
        debugPrint('OCR processing error (attempt $attempt): $error');
      },
      onRetry: (attempt) {
        debugPrint('Retrying OCR processing (attempt $attempt)');
      },
    ) ?? _createEmptyResult();
  }

  static Future<OCRResult> _processReceiptImageInternal(
    String imagePath, {
    bool isLongReceipt = false,
  }) async {
    final sessionId = _generateSessionId();
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check cache first
      final cachedResult = await _cacheManager.getCachedResult(imagePath);
      if (cachedResult != null) {
        debugPrint('✅ Returning cached OCR result');
        return cachedResult;
      }

      // Load and validate image
      final image = await _loadAndValidateImage(imagePath);
      if (image == null) {
        throw OCRException('Failed to load or validate image');
      }

      // Smart preprocessing pipeline
      final processedImage = await _smartPreprocessingPipeline(image);
      
      // Detect store type
      final storeType = await _detectStoreType(processedImage);
      
      // Hybrid processing
      final hybridResult = await _hybridProcessing(
        processedImage,
        storeType,
        isLongReceipt: isLongReceipt,
      );

      // Apply NLP enhancement
      final enhancedResult = await _applyNLPEnhancement(
        hybridResult,
        storeType,
      );

      // Cache the result
      await _cacheManager.cacheResult(imagePath, enhancedResult);

      stopwatch.stop();

      // Log performance metrics
      await OCRPerformanceMonitor.logOCRAttempt(
        sessionId: sessionId,
        imagePath: imagePath,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        extractedPricesCount: enhancedResult.prices.length,
        averageConfidence: enhancedResult.confidence,
        bestEnhancement: enhancedResult.enhancement.toString(),
        storeType: storeType,
        isLongReceipt: isLongReceipt,
        metadata: enhancedResult.metadata,
      );

      return enhancedResult;
    } catch (e) {
      stopwatch.stop();
      
      // Log error metrics
      await OCRPerformanceMonitor.logOCRAttempt(
        sessionId: sessionId,
        imagePath: imagePath,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        extractedPricesCount: 0,
        averageConfidence: 0.0,
        bestEnhancement: 'none',
        storeType: 'unknown',
        isLongReceipt: isLongReceipt,
        metadata: {},
        errorMessage: e.toString(),
      );
      
      rethrow;
    }
  }

  // Core OCR Methods Implementation
  static Future<img.Image?> _loadAndValidateImage(String imagePath) async {
    try {
      final file = File(imagePath);
      
      // Check if file exists
      if (!await file.exists()) {
        throw OCRException('Image file does not exist: $imagePath');
      }

      // Check file size
      final fileSize = await file.length();
      if (fileSize > maxFileSize) {
        throw OCRException('Image file too large: ${fileSize / (1024 * 1024)}MB');
      }
      
      if (fileSize < 1024) {
        throw OCRException('Image file too small or corrupted');
      }

      // Load and decode image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw OCRException('Failed to decode image - file may be corrupted');
      }

      // Validate image dimensions
      if (image.width < 100 || image.height < 100) {
        throw OCRException('Image too small: ${image.width}x${image.height}');
      }

      if (image.width > 4000 || image.height > 4000) {
        debugPrint('Large image detected, will resize: ${image.width}x${image.height}');
      }

      return image;
    } catch (e) {
      debugPrint('Failed to load image: $e');
      return null;
    }
  }

  static Future<String> _detectStoreType(img.Image image) async {
    try {
      // Perform quick OCR on header region to detect store
      final headerHeight = (image.height * 0.3).round();
      final header = img.copyCrop(image, x: 0, y: 0, width: image.width, height: headerHeight);
      
      final ocrResult = await _performOCR(header);
      final headerText = ocrResult.text.toLowerCase();
      
      // Check against store patterns
      for (final entry in _storeProfiles.entries) {
        final storeKey = entry.key;
        final profile = entry.value;
        
        for (final pattern in profile.patterns) {
          if (pattern.hasMatch(headerText)) {
            debugPrint('✅ Detected store type: ${profile.name}');
            return storeKey;
          }
        }
      }
      
      // Fallback detection based on common keywords
      if (headerText.contains('supermarket') || headerText.contains('grocery')) {
        return 'generic_supermarket';
      }
      
      debugPrint('⚠️ Store type not detected, using generic');
      return 'generic';
    } catch (e) {
      debugPrint('Store detection failed: $e');
      return 'generic';
    }
  }

  static Future<RecognizedText> _performOCR(img.Image image) async {
    try {
      // Resize if image is too large
      img.Image processedImage = image;
      if (image.width > maxImageDimension || image.height > maxImageDimension) {
        final ratio = maxImageDimension / max(image.width, image.height);
        processedImage = img.copyResize(
          image,
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
          interpolation: img.Interpolation.cubic,
        );
      }

      // Convert to bytes and create InputImage
      final bytes = img.encodeJpg(processedImage, quality: 90);
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(processedImage.width.toDouble(), processedImage.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: processedImage.width * 3,
        ),
      );

      // Perform OCR with timeout
      final result = await _textRecognizer.processImage(inputImage)
          .timeout(Duration(milliseconds: maxProcessingTime));
      
      return result;
    } catch (e) {
      debugPrint('OCR processing failed: $e');
      rethrow;
    }
  }

  static List<ExtractedPrice> _extractPricesWithRegex(
    RecognizedText result,
    String storeType,
  ) {
    final prices = <ExtractedPrice>[];
    final profile = _storeProfiles[storeType];
    
    // Use store-specific patterns if available
    final patterns = profile?.pricePatterns ?? [
      // Generic patterns
      RegExp(r'(\w+(?:\s+\w+)*)\s+(\d+\.\d{2})', multiLine: true),
      RegExp(r'(\w+(?:\s+\w+)*)\s*\$(\d+\.\d{2})', multiLine: true),
      RegExp(r'(\w+(?:\s+\w+)*)\s*J\$(\d+\.\d{2})', caseSensitive: false, multiLine: true),
    ];

    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text;
        
        // Skip total lines and non-product lines
        if (_isNonProductLine(text)) continue;
        
        for (final pattern in patterns) {
          final matches = pattern.allMatches(text);
          
          for (final match in matches) {
            try {
              final itemName = match.group(1)?.trim() ?? '';
              final priceStr = match.group(2) ?? match.group(3) ?? '';
              final price = double.tryParse(priceStr);
              
              if (price != null && price > 0 && price < 100000 && itemName.isNotEmpty) {
                final extractedPrice = ExtractedPrice(
                  itemName: itemName,
                  price: price,
                  originalText: text,
                  confidence: _calculateRegexConfidence(match, text),
                  position: _convertBoundingBox(line.boundingBox),
                  category: 'Other', // Will be enhanced by NLP
                  unit: 'each', // Will be enhanced by NLP
                  metadata: {
                    'extraction_method': 'regex',
                    'store_type': storeType,
                    'pattern_used': pattern.pattern,
                  },
                );
                
                prices.add(extractedPrice);
              }
            } catch (e) {
              debugPrint('Error parsing price match: $e');
            }
          }
        }
      }
    }
    
    return prices;
  }

  static List<ExtractedPrice> _mergeAndRankPrices(List<ExtractedPrice> allPrices) {
    if (allPrices.isEmpty) return [];
    
    // Group by similar position and price
    final groups = <List<ExtractedPrice>>[];
    
    for (final price in allPrices) {
      bool addedToGroup = false;
      
      for (final group in groups) {
        if (_areSimilarPrices(price, group.first)) {
          group.add(price);
          addedToGroup = true;
          break;
        }
      }
      
      if (!addedToGroup) {
        groups.add([price]);
      }
    }
    
    // Select best price from each group
    final mergedPrices = <ExtractedPrice>[];
    for (final group in groups) {
      group.sort((a, b) => b.confidence.compareTo(a.confidence));
      mergedPrices.add(group.first);
    }
    
    // Sort by confidence
    mergedPrices.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    return mergedPrices;
  }

  static double _calculateConfidence(List<ExtractedPrice> prices, RecognizedText result) {
    if (prices.isEmpty) return 0.0;
    
    double totalConfidence = 0.0;
    for (final price in prices) {
      totalConfidence += price.confidence;
    }
    
    final avgPriceConfidence = totalConfidence / prices.length;
    
    // Factor in OCR text confidence
    double textConfidence = 0.0;
    int textElements = 0;
    
    for (final block in result.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          textConfidence += element.confidence ?? 0.8;
          textElements++;
        }
      }
    }
    
    final avgTextConfidence = textElements > 0 ? textConfidence / textElements : 0.8;
    
    // Weighted average
    return (avgPriceConfidence * 0.7) + (avgTextConfidence * 0.3);
  }

  // Image Processing Methods Implementation
  static Future<img.Image> _smartPreprocessingPipeline(img.Image image) async {
    img.Image processed = image;
    
    try {
      // 1. Auto-orientation correction
      processed = await _autoOrientCorrection(processed);
      
      // 2. Perspective correction
      processed = await _perspectiveCorrection(processed);
      
      // 3. Adaptive enhancement
      processed = await _adaptiveEnhancement(processed);
      
      // 4. Smart denoising
      processed = _smartDenoise(processed);
      
      return processed;
    } catch (e) {
      debugPrint('Preprocessing failed, using original image: $e');
      return image;
    }
  }

  static Future<img.Image> _autoOrientCorrection(img.Image image) async {
    double bestScore = 0.0;
    img.Image bestImage = image;
    
    for (final angle in [0, 90, 180, 270]) {
      try {
        final rotated = angle == 0 ? image : img.copyRotate(image, angle: angle.toDouble());
        final score = await _scoreTextOrientation(rotated);
        
        if (score > bestScore) {
          bestScore = score;
          bestImage = rotated;
        }
      } catch (e) {
        debugPrint('Error testing orientation $angle: $e');
      }
    }
    
    return bestImage;
  }

  static Future<double> _scoreTextOrientation(img.Image image) async {
    try {
      final resized = _resizeForQuickOCR(image);
      final result = await _performOCR(resized);
      
      double score = 0.0;
      
      // Basic text length score
      score += result.text.length * 0.001;
      
      // Price pattern score
      final priceMatches = RegExp(r'\d+\.\d{2}').allMatches(result.text);
      score += priceMatches.length * 10;
      
      // Receipt keyword score
      final keywords = ['total', 'subtotal', 'tax', 'cash', 'receipt', 'thank'];
      for (final keyword in keywords) {
        if (result.text.toLowerCase().contains(keyword)) {
          score += 5;
        }
      }
      
      // Line structure score (receipts typically have many short lines)
      final lines = result.text.split('\n').where((line) => line.trim().isNotEmpty);
      if (lines.length > 5) {
        score += lines.length * 0.5;
      }
      
      return score;
    } catch (e) {
      return 0.0;
    }
  }

  static Future<img.Image> _perspectiveCorrection(img.Image image) async {
    try {
      final edges = _detectEdges(image);
      final contour = _findReceiptContour(edges);
      
      if (contour != null && contour.length == 4) {
        return _applyPerspectiveTransform(image, contour);
      }
      
      // Fallback to basic deskewing
      return _basicDeskew(image);
    } catch (e) {
      debugPrint('Perspective correction failed: $e');
      return image;
    }
  }

  static img.Image _detectEdges(img.Image image) {
    // Convert to grayscale first
    final gray = img.grayscale(image);
    
    // Apply Gaussian blur to reduce noise
    final blurred = img.gaussianBlur(gray, radius: 1);
    
    // Simple edge detection using Sobel-like operators
    final width = blurred.width;
    final height = blurred.height;
    final edges = img.Image(width: width, height: height);
    
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Get surrounding pixels
        final tl = blurred.getPixel( x - 1, y - 1).r;
        final tm = blurred.getPixel( x, y - 1).r;
        final tr = blurred.getPixel( x + 1, y - 1).r;
        final ml = blurred.getPixel( x - 1, y).r;
        final mr = blurred.getPixel( x + 1, y).r;
        final bl = blurred.getPixel( x - 1, y + 1).r;
        final bm = blurred.getPixel( x, y + 1).r;
        final br = blurred.getPixel( x + 1, y + 1).r;
        
        // Sobel operators
        final gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl);
        final gy = (bl + 2 * bm + br) - (tl + 2 * tm + tr);
        
        final magnitude = sqrt(gx * gx + gy * gy);
        final edgeValue = magnitude > 50 ? 255 : 0;
        
        edges.setPixel( x, y, img.ColorRgb8(edgeValue, edgeValue, edgeValue));
      }
    }
    
    return edges;
  }

  static List<Point>? _findReceiptContour(img.Image edges) {
    // Simplified contour detection
    // In a full implementation, you'd use more sophisticated algorithms
    final width = edges.width;
    final height = edges.height;
    final points = <Point>[];
    
    // Find corner candidates
    final cornerThreshold = 100;
    
    // Top-left corner
    for (int y = 0; y < height ~/ 3; y++) {
      for (int x = 0; x < width ~/ 3; x++) {
        if (edges.getPixel( x, y).r > cornerThreshold) {
          points.add(Point(x, y));
          break;
        }
      }
      if (points.isNotEmpty) break;
    }
    
    // Top-right corner
    for (int y = 0; y < height ~/ 3; y++) {
      for (int x = width - 1; x > (2 * width) ~/ 3; x--) {
        if (edges.getPixel( x, y).r > cornerThreshold) {
          points.add(Point(x, y));
          break;
        }
      }
      if (points.length == 2) break;
    }
    
    // Bottom-right corner
    for (int y = height - 1; y > (2 * height) ~/ 3; y--) {
      for (int x = width - 1; x > (2 * width) ~/ 3; x--) {
        if (edges.getPixel( x, y).r > cornerThreshold) {
          points.add(Point(x, y));
          break;
        }
      }
      if (points.length == 3) break;
    }
    
    // Bottom-left corner
    for (int y = height - 1; y > (2 * height) ~/ 3; y--) {
      for (int x = 0; x < width ~/ 3; x++) {
        if (edges.getPixel( x, y).r > cornerThreshold) {
          points.add(Point(x, y));
          break;
        }
      }
      if (points.length == 4) break;
    }
    
    return points.length == 4 ? points : null;
  }

  static img.Image _applyPerspectiveTransform(img.Image image, List<Point> corners) {
    // Simplified perspective correction
    // In production, you'd implement a proper perspective transform
    // For now, return the original image with basic rotation if needed
    return image;
  }

  static img.Image _basicDeskew(img.Image image) {
    // Simple deskewing by analyzing horizontal line angles
    // This is a simplified version - production would be more sophisticated
    return image;
  }

  static ImageQualityAnalysis _analyzeImageQuality(img.Image image) {
    final pixels = <int>[];
    final width = image.width;
    final height = image.height;
    
    // Sample pixels for analysis
    for (int y = 0; y < height; y += 5) {
      for (int x = 0; x < width; x += 5) {
        final pixel = image.getPixel( x, y);
        final gray = (pixel.r + pixel.g + pixel.b) ~/ 3;
        pixels.add(gray);
      }
    }
    
    if (pixels.isEmpty) {
      return ImageQualityAnalysis(brightness: 0.5, contrast: 0.5, sharpness: 0.5);
    }
    
    // Calculate brightness (average pixel value)
    final avgBrightness = pixels.reduce((a, b) => a + b) / pixels.length / 255.0;
    
    // Calculate contrast (standard deviation)
    final variance = pixels
        .map((p) => pow((p / 255.0) - avgBrightness, 2))
        .reduce((a, b) => a + b) / pixels.length;
    final contrast = sqrt(variance);
    
    // Simple sharpness estimation (edge density)
    double sharpness = 0.5; // Default value
    
    return ImageQualityAnalysis(
      brightness: avgBrightness.clamp(0.0, 1.0),
      contrast: contrast.clamp(0.0, 1.0),
      sharpness: sharpness.clamp(0.0, 1.0),
    );
  }

  static Future<img.Image> _adaptiveEnhancement(img.Image image) async {
    final analysis = _analyzeImageQuality(image);
    img.Image enhanced = image;
    
    try {
      // Adjust contrast if low
      if (analysis.contrast < 0.5) {
        enhanced = _applyCLAHE(enhanced, clipLimit: 3.0);
      }
      
      // Adjust brightness
      if (analysis.brightness < 0.3) {
        enhanced = img.adjustColor(enhanced, brightness: 20);
      } else if (analysis.brightness > 0.7) {
        enhanced = img.adjustColor(enhanced, brightness: -15);
      }
      
      // Apply sharpening if needed
      if (analysis.sharpness < 0.6) {
        enhanced = _adaptiveSharpen(enhanced);
      }
      
      return enhanced;
    } catch (e) {
      debugPrint('Adaptive enhancement failed: $e');
      return image;
    }
  }

  static img.Image _applyCLAHE(img.Image image, {double clipLimit = 2.0}) {
    // Simplified CLAHE (Contrast Limited Adaptive Histogram Equalization)
    // This is a basic implementation - production would be more sophisticated
    return img.adjustColor(image, contrast: 1.2);
  }

  static img.Image _adaptiveSharpen(img.Image image) {
    // Simple unsharp mask
    final blurred = img.gaussianBlur(image, radius: 1);
    
    final width = image.width;
    final height = image.height;
    final sharpened = img.Image.from(image);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final original = image.getPixel( x, y);
        final blur = blurred.getPixel( x, y);
        
        final sharpenedR = (original.r + (original.r - blur.r) * 0.5).clamp(0, 255).round();
        final sharpenedG = (original.g + (original.g - blur.g) * 0.5).clamp(0, 255).round();
        final sharpenedB = (original.b + (original.b - blur.b) * 0.5).clamp(0, 255).round();
        
        sharpened.setPixel( x, y, img.ColorRgb8(sharpenedR, sharpenedG, sharpenedB));
      }
    }
    
    return sharpened;
  }

  static img.Image _smartDenoise(img.Image image) {
    // Simple noise reduction using Gaussian blur
    return img.gaussianBlur(image, radius: 5);
  }

  // ML Integration Methods (Placeholders for now)
  static List<double> _prepareImageForML(img.Image image) {
    // Placeholder for ML model input preparation
    // Would normalize and reshape image data for TensorFlow Lite model
    final resized = img.copyResize(image, width: 224, height: 224);
    final normalized = <double>[];
    
    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel( x, y);
        normalized.add(pixel.r / 255.0);
        normalized.add(pixel.g / 255.0);
        normalized.add(pixel.b / 255.0);
      }
    }
    
    return normalized;
  }

  static NearbyTextResult _findNearbyText(RecognizedText result, double x, double y) {
    String bestText = '';
    String bestItem = '';
    double bestDistance = double.infinity;
    
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;
        final centerX = rect.left + rect.width / 2;
        final centerY = rect.top + rect.height / 2;
        
        final distance = sqrt(pow(centerX - x, 2) + pow(centerY - y, 2));
        
        if (distance < bestDistance && distance < 100) {
          bestDistance = distance;
          bestText = line.text;
          
          // Extract item name from line (remove price if present)
          final cleanText = line.text.replaceAll(RegExp(r'\d+\.\d{2}'), '').trim();
          bestItem = cleanText.isNotEmpty ? cleanText : line.text;
        }
      }
    }
    
    return NearbyTextResult(text: bestText, item: bestItem);
  }

  static Future<List<ExtractedPrice>> _processTextRegions(
    img.Image image,
    RecognizedText result,
  ) async {
    final regionPrices = <ExtractedPrice>[];
    
    // Process each text block as a potential price region
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text;
        
        // Look for price patterns in the line
        final pricePattern = RegExp(r'\d+\.\d{2}');
        final matches = pricePattern.allMatches(text);
        
        for (final match in matches) {
          final priceStr = match.group(0)!;
          final price = double.tryParse(priceStr);
          
          if (price != null && price > 0 && price < 10000) {
            // Extract item name (text before the price)
            final itemName = text.substring(0, match.start).trim();
            
            if (itemName.isNotEmpty && !_isNonProductLine(text)) {
              regionPrices.add(ExtractedPrice(
                itemName: itemName,
                price: price,
                originalText: text,
                confidence: 0.7, // Base confidence for region extraction
                position: _convertBoundingBox(line.boundingBox),
                category: 'Other',
                unit: 'each',
                metadata: {'extraction_method': 'region'},
              ));
            }
          }
        }
      }
    }
    
    return regionPrices;
  }

  // Hybrid Processing Implementation
  static Future<HybridOCRResult> _hybridProcessing(
    img.Image image,
    String storeType, {
    bool isLongReceipt = false,
  }) async {
    try {
      // Perform ML Kit OCR
      final mlKitResult = await _performOCR(image);
      
      // Process text regions
      final regionResults = await _processTextRegions(image, mlKitResult);
      
      // Extract prices with regex patterns
      final regexPrices = _extractPricesWithRegex(mlKitResult, storeType);
      
      // ML price extraction (if model is available)
      List<ExtractedPrice> mlPrices = [];
      if (_isModelLoaded && _priceExtractorModel != null) {
        // mlPrices = await _extractPricesWithML(image, mlKitResult);
      }
      
      // Merge and rank all extracted prices
      final allPrices = <ExtractedPrice>[
        ...mlPrices,
        ...regexPrices,
        ...regionResults,
      ];
      
      final mergedPrices = _mergeAndRankPrices(allPrices);
      
      return HybridOCRResult(
        fullText: mlKitResult.text,
        prices: mergedPrices,
        confidence: _calculateConfidence(mergedPrices, mlKitResult),
        enhancement: EnhancementType.hybrid,
        metadata: {
          'ml_kit_blocks': mlKitResult.blocks.length,
          'ml_prices': mlPrices.length,
          'regex_prices': regexPrices.length,
          'region_prices': regionResults.length,
          'merged_prices': mergedPrices.length,
          'store_type': storeType,
          'processing_time': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('Hybrid processing failed: $e');
      rethrow;
    }
  }

  static Future<OCRResult> _applyNLPEnhancement(
    HybridOCRResult hybridResult,
    String storeType,
  ) async {
    final enhancedPrices = <ExtractedPrice>[];
    
    for (final price in hybridResult.prices) {
      try {
        // Clean item name using NLP
        final cleanedName = _nlpProcessor.cleanItemName(price.itemName);
        
        // Detect category
        final category = _nlpProcessor.detectCategory(
          cleanedName,
          price.originalText,
          storeType,
        );
        
        // Extract unit
        final unit = _nlpProcessor.extractUnit(
          price.originalText,
          category,
        );
        
        // Validate price
        final isValidPrice = _nlpProcessor.validatePrice(
          price.price,
          category,
          storeType,
        );
        
        if (isValidPrice) {
          enhancedPrices.add(ExtractedPrice(
            itemName: cleanedName,
            price: price.price,
            originalText: price.originalText,
            confidence: (price.confidence * 1.1).clamp(0.0, 1.0), // Slight boost for NLP enhancement
            position: price.position,
            category: category,
            unit: unit,
            metadata: {
              ...price.metadata ?? {},
              'nlp_enhanced': true,
              'original_name': price.itemName,
              'original_category': 'Other',
            },
          ));
        }
      } catch (e) {
        debugPrint('Error enhancing price: ${price.itemName}, error: $e');
        // Keep original price if enhancement fails
        enhancedPrices.add(price);
      }
    }
    
    // Remove semantic duplicates
    final deduplicatedPrices = _nlpProcessor.removeSemanticDuplicates(enhancedPrices);
    
    return OCRResult(
      fullText: hybridResult.fullText,
      prices: deduplicatedPrices,
      confidence: hybridResult.confidence,
      enhancement: hybridResult.enhancement,
      storeType: storeType,
      metadata: {
        ...hybridResult.metadata,
        'nlp_enhanced': true,
        'original_prices': hybridResult.prices.length,
        'enhanced_prices': enhancedPrices.length,
        'deduplicated_prices': deduplicatedPrices.length,
      },
    );
  }

  // Helper Methods
  static img.Image _resizeForQuickOCR(img.Image image) {
    const maxDim = 800;
    if (image.width <= maxDim && image.height <= maxDim) {
      return image;
    }
    
    final ratio = min(maxDim / image.width, maxDim / image.height);
    return img.copyResize(
      image,
      width: (image.width * ratio).round(),
      height: (image.height * ratio).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  static bool _isNonProductLine(String text) {
    final lowerText = text.toLowerCase().trim();
    
    // Skip common non-product lines
    final skipPatterns = [
      'total',
      'subtotal',
      'tax',
      'cash',
      'change',
      'thank',
      'receipt',
      'date',
      'time',
      'cashier',
      'transaction',
      'balance',
      'tender',
      'ref',
      'seq',
      'terminal',
    ];
    
    for (final pattern in skipPatterns) {
      if (lowerText.contains(pattern)) {
        return true;
      }
    }
    
    // Skip lines with only numbers/codes
    if (RegExp(r'^\d+$').hasMatch(lowerText)) {
      return true;
    }
    
    // Skip very short lines (likely codes)
    if (lowerText.length < 3) {
      return true;
    }
    
    return false;
  }

  static double _calculateRegexConfidence(RegExpMatch match, String fullText) {
    double confidence = 0.6; // Base confidence
    
    // Boost confidence based on context
    final itemName = match.group(1) ?? '';
    final price = match.group(2) ?? '';
    
    // Item name quality
    if (itemName.length > 3) confidence += 0.1;
    if (itemName.contains(' ')) confidence += 0.1; // Multi-word items
    
    // Price format quality
    if (price.contains('.') && price.length >= 4) confidence += 0.1;
    
    // Context quality
    if (!_isNonProductLine(fullText)) confidence += 0.1;
    
    return confidence.clamp(0.0, 1.0);
  }

  static bool _areSimilarPrices(ExtractedPrice price1, ExtractedPrice price2) {
    // Check if prices are the same
    if ((price1.price - price2.price).abs() < 0.01) {
      return true;
    }
    
    // Check if positions are close
    final distance = sqrt(
      pow(price1.position.center.dx - price2.position.center.dx, 2) +
      pow(price1.position.center.dy - price2.position.center.dy, 2),
    );
    
    return distance < 50; // 50 pixels threshold
  }

  static Rect _convertBoundingBox(Rect? boundingBox) {
    return boundingBox ?? Rect.zero;
  }

  static String _generateSessionId() {
    return 'ocr_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  static OCRResult _createEmptyResult() {
    return OCRResult(
      fullText: '',
      prices: [],
      confidence: 0.0,
      enhancement: EnhancementType.original,
      storeType: 'unknown',
      metadata: {'error': 'processing_failed'},
    );
  }

  static void dispose() {
    _textRecognizer.close();
    _priceExtractorModel?.close();
    _cacheManager.dispose();
    _nlpProcessor.dispose();
  }
}

// Supporting Classes
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

class HybridOCRResult {
  final String fullText;
  final List<ExtractedPrice> prices;
  final double confidence;
  final EnhancementType enhancement;
  final Map<String, dynamic> metadata;

  HybridOCRResult({
    required this.fullText,
    required this.prices,
    required this.confidence,
    required this.enhancement,
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
  final StoreCharacteristics characteristics;

  StoreProfile({
    required this.name,
    required this.patterns,
    required this.pricePatterns,
    required this.characteristics,
  });
}

class StoreCharacteristics {
  final bool hasItemCodes;
  final PricePosition pricePosition;
  final bool usesAsterisks;
  final int averageReceiptLength;

  StoreCharacteristics({
    required this.hasItemCodes,
    required this.pricePosition,
    required this.usesAsterisks,
    required this.averageReceiptLength,
  });
}

class ImageQualityAnalysis {
  final double brightness;
  final double contrast;
  final double sharpness;

  ImageQualityAnalysis({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
  });
}

class NearbyTextResult {
  final String text;
  final String item;

  NearbyTextResult({required this.text, required this.item});
}

class Point {
  final int x;
  final int y;

  Point(this.x, this.y);
}

enum PricePosition { left, right, middle }
enum EnhancementType { original, contrast, brightness, sharpen, grayscale, binarize, hybrid }

// Extension for List reshape (for ML operations)
extension ListExtension<T> on List<T> {
  List<List<List<List<T>>>> reshape(List<int> shape) {
    // Simplified reshape for 4D tensor - implement based on your needs
    if (shape.length != 4) throw ArgumentError('Only 4D reshape supported in this example');
    
    final result = <List<List<List<T>>>>[];
    // Implementation would depend on your specific tensor shape requirements
    return result;
  }
}
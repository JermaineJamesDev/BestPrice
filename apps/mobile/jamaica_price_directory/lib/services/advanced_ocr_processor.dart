import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';

class AdvancedOCRProcessor {
  static const double confidenceThreshold = 0.7;
  static const int maxImageDimension = 2048;
  static const int maxProcessingTime = 30000; // 30 seconds timeout
  
  // Multiple OCR engines for better accuracy
  static final TextRecognizer _latinRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  
  // Store format patterns for different receipt types
  static final Map<String, List<RegExp>> _storePatterns = {
    'hi-lo': [
      RegExp(r'HI-LO', caseSensitive: false),
      RegExp(r'(\w+(?:\s+\w+)*)\s+(\d+\.\d{2})\s*$', multiLine: true),
    ],
    'megamart': [
      RegExp(r'MEGA\s*MART', caseSensitive: false),
      RegExp(r'(\w+(?:\s+\w+)*)\s+J\$(\d+\.\d{2})', caseSensitive: false),
    ],
    'pricesmart': [
      RegExp(r'PRICE\s*SMART', caseSensitive: false),
      RegExp(r'(\d+)\s+(\w+(?:\s+\w+)*)\s+(\d+\.\d{2})', multiLine: true),
    ],
    'generic': [
      RegExp(r'.*'),
      RegExp(r'(\w+(?:\s+\w+)*)\s*[:\-]?\s*J?\$?(\d+[,\.]?\d*\.?\d{2})', caseSensitive: false),
    ],
  };

  static Future<OCRResult> processReceiptImage(String imagePath) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final imageFile = File(imagePath);
      final originalBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(originalBytes);
      
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Detect receipt orientation and correct if needed
      final orientedImage = await _detectAndCorrectOrientation(originalImage);
      
      // Detect store type for targeted processing
      final storeType = await _detectStoreType(orientedImage);
      
      // Process with multiple enhancement techniques
      final attempts = await _processWithMultipleEnhancements(orientedImage, storeType);
      
      // Select best result using advanced scoring
      final bestResult = _selectBestResultAdvanced(attempts);
      
      // Post-process and enhance results
      final enhancedPrices = await _postProcessPrices(bestResult.prices, storeType);
      
      stopwatch.stop();
      
      return OCRResult(
        fullText: bestResult.fullText,
        prices: enhancedPrices,
        confidence: bestResult.confidence,
        processingTime: stopwatch.elapsedMilliseconds,
        enhancement: bestResult.enhancement,
        storeType: storeType,
        metadata: {
          'orientation_corrected': orientedImage != originalImage,
          'processing_attempts': attempts.length,
          'total_time_ms': stopwatch.elapsedMilliseconds,
        },
      );
    } catch (e) {
      debugPrint('Super Advanced OCR error: $e');
      rethrow;
    }
  }

  static Future<img.Image> _detectAndCorrectOrientation(img.Image image) async {
    // Try multiple orientations and score text detection
    final orientations = [0, 90, 180, 270];
    var bestImage = image;
    var bestScore = 0.0;
    
    for (final angle in orientations) {
      final rotatedImage = angle == 0 ? image : img.copyRotate(image, angle: angle.toDouble());
      final score = await _scoreTextOrientation(rotatedImage);
      
      if (score > bestScore) {
        bestScore = score;
        bestImage = rotatedImage;
      }
    }
    
    return bestImage;
  }

  static Future<double> _scoreTextOrientation(img.Image image) async {
    try {
      // Quick OCR to detect text quality
      final resized = _resizeForQuickOCR(image);
      final bytes = img.encodeJpg(resized, quality: 85);
      final tempFile = File('${Directory.systemTemp.path}/temp_orientation_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognizedText = await _latinRecognizer.processImage(inputImage);
      
      await tempFile.delete();
      
      // Score based on text amount and confidence
      double score = recognizedText.text.length.toDouble();
      
      // Bonus for finding price patterns
      final priceMatches = RegExp(r'\d+\.\d{2}').allMatches(recognizedText.text);
      score += priceMatches.length * 10;
      
      // Bonus for common receipt words
      final receiptWords = ['total', 'subtotal', 'tax', 'cash', 'change', 'thank you'];
      for (final word in receiptWords) {
        if (recognizedText.text.toLowerCase().contains(word)) {
          score += 5;
        }
      }
      
      return score;
    } catch (e) {
      return 0.0;
    }
  }

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
    );
  }

  static Future<String> _detectStoreType(img.Image image) async {
    try {
      // Quick OCR to detect store name
      final quickOCR = await _performQuickOCR(image);
      final text = quickOCR.text.toLowerCase();
      
      for (final storeType in _storePatterns.keys) {
        if (storeType != 'generic') {
          final patterns = _storePatterns[storeType]!;
          if (patterns.first.hasMatch(text)) {
            debugPrint('Detected store type: $storeType');
            return storeType;
          }
        }
      }
      
      return 'generic';
    } catch (e) {
      return 'generic';
    }
  }

  static Future<RecognizedText> _performQuickOCR(img.Image image) async {
    final resized = _resizeForQuickOCR(image);
    final bytes = img.encodeJpg(resized, quality: 85);
    final tempFile = File('${Directory.systemTemp.path}/temp_quick_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(bytes);
    
    final inputImage = InputImage.fromFilePath(tempFile.path);
    final result = await _latinRecognizer.processImage(inputImage);
    
    await tempFile.delete();
    return result;
  }

  static Future<List<OCRAttempt>> _processWithMultipleEnhancements(
    img.Image originalImage, 
    String storeType,
  ) async {
    final attempts = <OCRAttempt>[];
    
    // Enhanced set of processing techniques
    final enhancementStrategies = [
      EnhancementStrategy.original,
      EnhancementStrategy.highContrast,
      EnhancementStrategy.adaptiveThreshold,
      EnhancementStrategy.edgeEnhancement,
      EnhancementStrategy.noiseReduction,
      EnhancementStrategy.customStore,
    ];
    
    final futures = enhancementStrategies.map((strategy) {
      return _processWithEnhancementStrategy(originalImage, strategy, storeType);
    }).toList();
    
    final results = await Future.wait(futures);
    attempts.addAll(results.where((result) => result != null).cast<OCRAttempt>());
    
    return attempts;
  }

  static Future<OCRAttempt?> _processWithEnhancementStrategy(
    img.Image originalImage, 
    EnhancementStrategy strategy,
    String storeType,
  ) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    try {
      final enhancedImage = await _applyEnhancementStrategy(originalImage, strategy, storeType);
      final processedImage = _resizeForOCR(enhancedImage);
      final bytes = img.encodeJpg(processedImage, quality: 95);
      
      final tempFile = File('${Directory.systemTemp.path}/temp_ocr_${strategy.name}_$startTime.jpg');
      await tempFile.writeAsBytes(bytes);
      
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognizedText = await _latinRecognizer.processImage(inputImage);
      
      final extractedPrices = _extractPricesAdvanced(recognizedText, storeType);
      
      await tempFile.delete();
      
      return OCRAttempt(
        fullText: recognizedText.text,
        prices: extractedPrices,
        confidence: _calculateAdvancedConfidence(recognizedText, extractedPrices, storeType),
        enhancement: _strategyToEnhancementType(strategy),
        startTime: startTime,
        strategy: strategy,
      );
    } catch (e) {
      debugPrint('Enhancement strategy $strategy failed: $e');
      return null;
    }
  }

  static Future<img.Image> _applyEnhancementStrategy(
    img.Image image, 
    EnhancementStrategy strategy,
    String storeType,
  ) async {
    switch (strategy) {
      case EnhancementStrategy.original:
        return img.Image.from(image);
        
      case EnhancementStrategy.highContrast:
        return img.adjustColor(image, contrast: 1.5, brightness: 10, saturation: 0.8);
        
      case EnhancementStrategy.adaptiveThreshold:
        final gray = img.grayscale(image);
        return _applyAdaptiveThreshold(gray);
        
      case EnhancementStrategy.edgeEnhancement:
        final enhanced = img.convolution(image, filter: [
          -1, -1, -1,
          -1,  9, -1,
          -1, -1, -1
        ]);
        return img.adjustColor(enhanced, contrast: 1.2);
        
      case EnhancementStrategy.noiseReduction:
        final blurred = img.gaussianBlur(image, radius: 1);
        return img.adjustColor(blurred, contrast: 1.3, brightness: 5);
        
      case EnhancementStrategy.customStore:
        return _applyStoreSpecificEnhancement(image, storeType);
    }
  }

  static img.Image _applyAdaptiveThreshold(img.Image grayImage) {
    const blockSize = 15;
    const C = 10;
    
    final result = img.Image.from(grayImage);
    
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final neighborhood = _getNeighborhoodMean(grayImage, x, y, blockSize);
        final threshold = neighborhood - C;
        
        final pixel = grayImage.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        final newPixel = luminance > threshold 
          ? img.ColorRgb8(255, 255, 255) 
          : img.ColorRgb8(0, 0, 0);
        
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }

  static double _getNeighborhoodMean(img.Image image, int centerX, int centerY, int blockSize) {
    int sum = 0;
    int count = 0;
    final halfBlock = blockSize ~/ 2;
    
    for (int y = centerY - halfBlock; y <= centerY + halfBlock; y++) {
      for (int x = centerX - halfBlock; x <= centerX + halfBlock; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          sum += img.getLuminance(pixel).round();
          count++;
        }
      }
    }
    
    return count > 0 ? sum / count : 128;
  }

  static img.Image _applyStoreSpecificEnhancement(img.Image image, String storeType) {
    switch (storeType) {
      case 'hi-lo':
        // Hi-Lo receipts often have light backgrounds
        return img.adjustColor(image, contrast: 1.4, brightness: -5);
        
      case 'megamart':
        // MegaMart receipts can be low contrast
        return img.adjustColor(image, contrast: 1.6, brightness: 10);
        
      case 'pricesmart':
        // PriceSmart receipts are usually high quality
        return img.adjustColor(image, contrast: 1.2, brightness: 5);
        
      default:
        return img.adjustColor(image, contrast: 1.3, brightness: 8);
    }
  }

  static List<ExtractedPrice> _extractPricesAdvanced(
    RecognizedText recognizedText, 
    String storeType,
  ) {
    final prices = <ExtractedPrice>[];
    
    // Use store-specific patterns first
    final storePatterns = _storePatterns[storeType] ?? _storePatterns['generic']!;
    
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final lineText = line.text.trim();
        if (_shouldSkipLine(lineText)) continue;
        
        // Try store-specific patterns first
        final storePrices = _extractWithStorePatterns(lineText, line, storePatterns);
        prices.addAll(storePrices);
        
        // Fallback to generic patterns
        if (storePrices.isEmpty) {
          final genericPrices = _extractWithGenericPatterns(lineText, line);
          prices.addAll(genericPrices);
        }
      }
    }
    
    return _removeDuplicatesAndSort(prices);
  }

  static List<ExtractedPrice> _extractWithStorePatterns(
    String lineText, 
    TextLine line, 
    List<RegExp> patterns,
  ) {
    final prices = <ExtractedPrice>[];
    
    // Skip the first pattern (store identifier)
    for (int i = 1; i < patterns.length; i++) {
      final pattern = patterns[i];
      final matches = pattern.allMatches(lineText);
      
      for (final match in matches) {
        final itemName = match.groupCount >= 1 ? match.group(1)?.trim() : '';
        final priceStr = match.groupCount >= 2 ? match.group(2) : match.group(1);
        
        if (priceStr != null) {
          final price = _parsePrice(priceStr);
          if (price != null && _isValidPrice(price)) {
            final extractedItemName = itemName?.isNotEmpty == true 
              ? _formatItemName(itemName!) 
              : _extractItemName(lineText, match);
            
            final confidence = _calculateAdvancedPriceConfidence(lineText, price, line, true);
            
            prices.add(ExtractedPrice(
              itemName: extractedItemName,
              price: price,
              originalText: lineText,
              confidence: confidence,
              position: _getLineRect(line),
              category: _categorizeItem(extractedItemName),
              unit: _detectUnit(lineText),
            ));
          }
        }
      }
    }
    
    return prices;
  }

  static List<ExtractedPrice> _extractWithGenericPatterns(String lineText, TextLine line) {
    final prices = <ExtractedPrice>[];
    
    final pricePatterns = [
      RegExp(r'J?\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s*J(?:MD)?', caseSensitive: false),
      RegExp(r'(\d{1,3}(?:,\d{3})*\.\d{2})\s*$', multiLine: true),
      RegExp(r'TOTAL[\s:]*J?\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'SUBTOTAL[\s:]*J?\$?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
    ];

    for (final pattern in pricePatterns) {
      final matches = pattern.allMatches(lineText);
      for (final match in matches) {
        final priceStr = match.group(1) ?? match.group(0)!;
        final price = _parsePrice(priceStr);
        
        if (price != null && _isValidPrice(price)) {
          final itemName = _extractItemName(lineText, match);
          final confidence = _calculateAdvancedPriceConfidence(lineText, price, line, false);
          
          prices.add(ExtractedPrice(
            itemName: itemName,
            price: price,
            originalText: lineText,
            confidence: confidence,
            position: _getLineRect(line),
            category: _categorizeItem(itemName),
            unit: _detectUnit(lineText),
          ));
        }
      }
    }
    
    return prices;
  }

  static double _calculateAdvancedPriceConfidence(
    String lineText, 
    double price, 
    TextLine line, 
    bool isStoreSpecific,
  ) {
    double confidence = 0.4; // Base confidence
    
    // Store-specific pattern bonus
    if (isStoreSpecific) confidence += 0.2;
    
    // Currency indicator bonus
    if (lineText.toLowerCase().contains('j\$') || lineText.toLowerCase().contains('jmd')) {
      confidence += 0.2;
    }
    
    // Price range validation
    if (price >= 1 && price <= 50000) { // Reasonable price range for Jamaica
      confidence += 0.1;
      if (price >= 10 && price <= 10000) confidence += 0.1; // Most common range
    }
    
    // Decimal precision bonus
    if (RegExp(r'\d+\.\d{2}$').hasMatch(price.toString())) {
      confidence += 0.1;
    }
    
    // Line quality bonus
    if (line.elements.isNotEmpty) {
      final avgElementConfidence = line.elements
        .map((e) => e.confidence ?? 0.5)
        .reduce((a, b) => a + b) / line.elements.length;
      confidence = (confidence + avgElementConfidence) / 2;
    }
    
    // Text context bonus
    if (lineText.split(' ').length >= 2) confidence += 0.05;
    if (lineText.length > 5 && lineText.length < 50) confidence += 0.05;
    
    return confidence.clamp(0.0, 1.0);
  }

  static double _calculateAdvancedConfidence(
    RecognizedText text, 
    List<ExtractedPrice> prices, 
    String storeType,
  ) {
    if (prices.isEmpty) return 0.0;
    
    final avgPriceConfidence = prices
      .map((p) => p.confidence)
      .reduce((a, b) => a + b) / prices.length;
    
    double textQuality = text.text.isNotEmpty ? 0.7 : 0.1;
    
    // Store type bonus
    double storeBonus = storeType != 'generic' ? 0.1 : 0.0;
    
    // Price quantity bonus
    double quantityBonus = min(prices.length / 10.0, 0.2);
    
    return (avgPriceConfidence * 0.6 + textQuality * 0.2 + storeBonus + quantityBonus)
      .clamp(0.0, 1.0);
  }

  static OCRAttempt _selectBestResultAdvanced(List<OCRAttempt> attempts) {
    if (attempts.isEmpty) {
      throw Exception('No OCR attempts succeeded');
    }
    
    // Score each attempt
    final scoredAttempts = attempts.map((attempt) {
      double score = attempt.confidence * 0.4; // Base confidence
      score += (attempt.prices.length * 0.05).clamp(0.0, 0.3); // Price quantity
      score += _getStrategyBonus(attempt.strategy) * 0.1; // Strategy bonus
      score += _getTextQualityScore(attempt.fullText) * 0.2; // Text quality
      
      return MapEntry(attempt, score);
    }).toList();
    
    // Sort by score
    scoredAttempts.sort((a, b) => b.value.compareTo(a.value));
    
    return scoredAttempts.first.key;
  }

  static double _getStrategyBonus(EnhancementStrategy? strategy) {
    switch (strategy) {
      case EnhancementStrategy.customStore:
        return 1.0;
      case EnhancementStrategy.adaptiveThreshold:
        return 0.8;
      case EnhancementStrategy.highContrast:
        return 0.6;
      case EnhancementStrategy.edgeEnhancement:
        return 0.4;
      case EnhancementStrategy.noiseReduction:
        return 0.3;
      case EnhancementStrategy.original:
        return 0.2;
      default:
        return 0.0;
    }
  }

  static double _getTextQualityScore(String text) {
    if (text.isEmpty) return 0.0;
    
    double score = 0.0;
    
    // Length bonus
    score += min(text.length / 1000.0, 0.5);
    
    // Common receipt words
    final receiptWords = ['total', 'subtotal', 'tax', 'cash', 'change', 'thank', 'receipt'];
    for (final word in receiptWords) {
      if (text.toLowerCase().contains(word)) {
        score += 0.1;
      }
    }
    
    // Price pattern count
    final priceMatches = RegExp(r'\d+\.\d{2}').allMatches(text);
    score += min(priceMatches.length * 0.05, 0.3);
    
    return score.clamp(0.0, 1.0);
  }

  static Future<List<ExtractedPrice>> _postProcessPrices(
    List<ExtractedPrice> prices, 
    String storeType,
  ) async {
    // Remove duplicates
    final unique = _removeDuplicatesAdvanced(prices);
    
    // Apply store-specific post-processing
    final processed = _applyStoreSpecificProcessing(unique, storeType);
    
    // Sort by confidence
    processed.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // Limit to top results
    return processed.take(20).toList();
  }

  static List<ExtractedPrice> _removeDuplicatesAdvanced(List<ExtractedPrice> prices) {
    final unique = <ExtractedPrice>[];
    
    for (final price in prices) {
      bool isDuplicate = false;
      
      for (int i = 0; i < unique.length; i++) {
        final existing = unique[i];
        
        if (_areItemsSimilarAdvanced(price, existing)) {
          // Keep the one with higher confidence
          if (price.confidence > existing.confidence) {
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

  static bool _areItemsSimilarAdvanced(ExtractedPrice price1, ExtractedPrice price2) {
    // Same price within 1 cent
    if ((price1.price - price2.price).abs() < 0.01) {
      // Check item name similarity
      final similarity = _calculateAdvancedStringSimilarity(
        price1.itemName.toLowerCase(),
        price2.itemName.toLowerCase(),
      );
      return similarity > 0.75;
    }
    
    // Very similar names with similar prices
    final nameSimilarity = _calculateAdvancedStringSimilarity(
      price1.itemName.toLowerCase(),
      price2.itemName.toLowerCase(),
    );
    
    if (nameSimilarity > 0.9) {
      final priceDifference = (price1.price - price2.price).abs() / max(price1.price, price2.price);
      return priceDifference < 0.1; // 10% price difference
    }
    
    return false;
  }

  static double _calculateAdvancedStringSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;
    
    // Levenshtein distance
    final distance = _levenshteinDistance(str1, str2);
    final maxLength = max(str1.length, str2.length);
    final similarity = 1 - (distance / maxLength);
    
    // Word overlap bonus
    final words1 = str1.split(' ').toSet();
    final words2 = str2.split(' ').toSet();
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);
    final wordOverlap = intersection.length / union.length;
    
    return (similarity * 0.7 + wordOverlap * 0.3).clamp(0.0, 1.0);
  }

  static int _levenshteinDistance(String str1, String str2) {
    final matrix = List.generate(
      str1.length + 1,
      (i) => List.filled(str2.length + 1, 0),
    );
    
    for (int i = 0; i <= str1.length; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= str2.length; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= str1.length; i++) {
      for (int j = 1; j <= str2.length; j++) {
        final cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }
    
    return matrix[str1.length][str2.length];
  }

  static List<ExtractedPrice> _applyStoreSpecificProcessing(
    List<ExtractedPrice> prices, 
    String storeType,
  ) {
    switch (storeType) {
      case 'hi-lo':
        return _processHiLoReceipt(prices);
      case 'megamart':
        return _processMegaMartReceipt(prices);
      case 'pricesmart':
        return _processPriceSmartReceipt(prices);
      default:
        return prices;
    }
  }

  static List<ExtractedPrice> _processHiLoReceipt(List<ExtractedPrice> prices) {
    // Hi-Lo specific processing
    return prices.map((price) {
      var updatedPrice = price;
      
      // Fix common Hi-Lo formatting issues
      if (updatedPrice.itemName.contains('*')) {
        updatedPrice = ExtractedPrice(
          itemName: updatedPrice.itemName.replaceAll('*', '').trim(),
          price: updatedPrice.price,
          originalText: updatedPrice.originalText,
          confidence: updatedPrice.confidence * 0.95, // Slight confidence reduction for formatting issues
          position: updatedPrice.position,
          category: updatedPrice.category,
          unit: updatedPrice.unit,
        );
      }
      
      return updatedPrice;
    }).toList();
  }

  static List<ExtractedPrice> _processMegaMartReceipt(List<ExtractedPrice> prices) {
    // MegaMart specific processing
    return prices.where((price) {
      // Filter out common MegaMart non-item lines
      final itemName = price.itemName.toLowerCase();
      return !itemName.contains('cashier') && 
             !itemName.contains('terminal') &&
             !itemName.contains('store');
    }).toList();
  }

  static List<ExtractedPrice> _processPriceSmartReceipt(List<ExtractedPrice> prices) {
    // PriceSmart specific processing
    return prices.map((price) {
      var updatedPrice = price;
      
      // PriceSmart often has item codes, try to clean them
      final itemName = updatedPrice.itemName;
      final cleanedName = itemName.replaceAll(RegExp(r'^\d+\s+'), '').trim();
      
      if (cleanedName != itemName && cleanedName.isNotEmpty) {
        updatedPrice = ExtractedPrice(
          itemName: cleanedName,
          price: updatedPrice.price,
          originalText: updatedPrice.originalText,
          confidence: updatedPrice.confidence,
          position: updatedPrice.position,
          category: _categorizeItem(cleanedName),
          unit: updatedPrice.unit,
        );
      }
      
      return updatedPrice;
    }).toList();
  }

  // Utility methods
  static img.Image _resizeForOCR(img.Image image) {
    if (image.width <= maxImageDimension && image.height <= maxImageDimension) {
      return image;
    }
    
    final ratio = min(
      maxImageDimension / image.width,
      maxImageDimension / image.height,
    );
    
    return img.copyResize(
      image,
      width: (image.width * ratio).round(),
      height: (image.height * ratio).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  static Rect _getLineRect(TextLine line) {
    return Rect.fromLTRB(
      line.boundingBox.left.toDouble(),
      line.boundingBox.top.toDouble(),
      line.boundingBox.right.toDouble(),
      line.boundingBox.bottom.toDouble(),
    );
  }

  static double? _parsePrice(String priceStr) {
    try {
      String cleaned = priceStr.replaceAll(RegExp(r'[J\$,\s]'), '');
      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  static bool _isValidPrice(double price) {
    return price > 0 && price < 100000 && price.toString().contains('.');
  }

  static String _extractItemName(String lineText, RegExpMatch priceMatch) {
    String beforePrice = lineText.substring(0, priceMatch.start).trim();
    beforePrice = beforePrice
      .replaceAll(RegExp(r'^\d+[\s\.]'), '')
      .replaceAll(RegExp(r'[*@#]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
    
    if (beforePrice.isNotEmpty && beforePrice.length > 2) {
      return _formatItemName(beforePrice);
    }
    
    String afterPrice = lineText.substring(priceMatch.end).trim();
    if (afterPrice.isNotEmpty && afterPrice.length > 2) {
      return _formatItemName(afterPrice);
    }
    
    return 'Unknown Item';
  }

  static String _formatItemName(String name) {
    return name
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ')
      .substring(0, min(50, name.length));
  }

  static bool _shouldSkipLine(String line) {
    final skipPatterns = [
      RegExp(r'^\s*$'),
      RegExp(r'^[*\-_=]{3,}$'),
      RegExp(r'^\d{2}[/\-]\d{2}[/\-]\d{2,4}'),
      RegExp(r'^CASHIER|^THANK|^STORE|^ADDRESS', caseSensitive: false),
      RegExp(r'^RECEIPT|^INVOICE|^BILL', caseSensitive: false),
    ];
    
    return skipPatterns.any((pattern) => pattern.hasMatch(line));
  }

  static String _categorizeItem(String itemName) {
    final categories = {
      'Groceries': ['rice', 'bread', 'milk', 'sugar', 'flour', 'oil', 'pasta', 'cereal'],
      'Meat': ['chicken', 'beef', 'pork', 'fish', 'meat', 'bacon', 'ham'],
      'Beverages': ['juice', 'soda', 'water', 'drink', 'beer', 'wine', 'coffee', 'tea'],
      'Dairy': ['cheese', 'butter', 'yogurt', 'cream', 'eggs'],
      'Produce': ['apple', 'banana', 'orange', 'vegetable', 'fruit', 'lettuce', 'tomato'],
      'Household': ['soap', 'detergent', 'tissue', 'toilet', 'cleaning'],
      'Health': ['medicine', 'vitamin', 'bandage', 'aspirin'],
    };
    
    final lowerName = itemName.toLowerCase();
    for (final entry in categories.entries) {
      if (entry.value.any((keyword) => lowerName.contains(keyword))) {
        return entry.key;
      }
    }
    
    return 'Other';
  }

  static String _detectUnit(String lineText) {
    final unitPatterns = {
      'per lb': RegExp(r'\b(lb|pound|lbs)\b', caseSensitive: false),
      'per kg': RegExp(r'\b(kg|kilo|kilogram)\b', caseSensitive: false),
      'per gallon': RegExp(r'\b(gal|gallon|gallons)\b', caseSensitive: false),
      'per liter': RegExp(r'\b(liter|litre|l)\b', caseSensitive: false),
      'per pack': RegExp(r'\b(pack|pk|package)\b', caseSensitive: false),
    };
    
    for (final entry in unitPatterns.entries) {
      if (entry.value.hasMatch(lineText)) {
        return entry.key;
      }
    }
    
    return 'each';
  }

  static List<ExtractedPrice> _removeDuplicatesAndSort(List<ExtractedPrice> prices) {
    final unique = _removeDuplicatesAdvanced(prices);
    unique.sort((a, b) => b.confidence.compareTo(a.confidence));
    return unique;
  }

  static EnhancementType _strategyToEnhancementType(EnhancementStrategy? strategy) {
    switch (strategy) {
      case EnhancementStrategy.original:
        return EnhancementType.original;
      case EnhancementStrategy.highContrast:
        return EnhancementType.contrast;
      case EnhancementStrategy.adaptiveThreshold:
        return EnhancementType.binarize;
      case EnhancementStrategy.edgeEnhancement:
        return EnhancementType.sharpen;
      case EnhancementStrategy.noiseReduction:
        return EnhancementType.grayscale;
      case EnhancementStrategy.customStore:
        return EnhancementType.contrast;
      default:
        return EnhancementType.original;
    }
  }

  static void dispose() {
    _latinRecognizer.close();
  }
}

// Enhanced enums and classes
enum EnhancementStrategy {
  original,
  highContrast,
  adaptiveThreshold,
  edgeEnhancement,
  noiseReduction,
  customStore,
}

enum EnhancementType {
  original,
  contrast,
  brightness,
  sharpen,
  grayscale,
  binarize,
}

class OCRAttempt {
  final String fullText;
  final List<ExtractedPrice> prices;
  final double confidence;
  final EnhancementType enhancement;
  final int startTime;
  final EnhancementStrategy? strategy;

  OCRAttempt({
    required this.fullText,
    required this.prices,
    required this.confidence,
    required this.enhancement,
    required this.startTime,
    this.strategy,
  });
}

class OCRResult {
  final String fullText;
  final List<ExtractedPrice> prices;
  final double confidence;
  final int processingTime;
  final EnhancementType enhancement;
  final String storeType;
  final Map<String, dynamic> metadata;

  OCRResult({
    required this.fullText,
    required this.prices,
    required this.confidence,
    required this.processingTime,
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

  ExtractedPrice({
    required this.itemName,
    required this.price,
    required this.originalText,
    required this.confidence,
    required this.position,
    required this.category,
    required this.unit,
  });
}
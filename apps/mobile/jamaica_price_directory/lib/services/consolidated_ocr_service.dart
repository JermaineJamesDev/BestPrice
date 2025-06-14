import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'ocr_cache_manager.dart';
import 'ocr_error_handler.dart';
import 'ocr_performance_monitor.dart';
import '../utils/ocr_image_utils.dart';

class ConsolidatedOCRService {
  static ConsolidatedOCRService? _instance;
  static ConsolidatedOCRService get instance =>
      _instance ??= ConsolidatedOCRService._();

  ConsolidatedOCRService._();

  late TextRecognizer _textRecognizer;
  late ICacheManager _cacheManager;
  static OCRServiceConfig _config = const OCRServiceConfig();
  bool _isInitialized = false;
  int _currentProcessingTasks = 0;
  final List<CancellationToken> _activeTasks = [];
  Directory? _tempDirectory;

  static const int maxConcurrentProcessing = 2;
  static const Duration processingTimeout = Duration(seconds: 30);
  static const int maxFileSize = 10 * 1024 * 1024;

  static DateTime? _lastProcessingTime;
  static const Duration _minProcessingInterval = Duration(milliseconds: 500);

  // Store profile for PriceSmart
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

  Future<void> initialize({OCRServiceConfig? config}) async {
    if (_isInitialized) {
      debugPrint('ConsolidatedOCRService: Already initialized');
      return;
    }

    try {
      _config = config ?? const OCRServiceConfig();
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _cacheManager = _config.usePersistentCache
          ? OCRCacheManager()
          : MemoryOnlyCacheManager();

      // Initialize temp directory for processing
      _tempDirectory = await getTemporaryDirectory();

      await _cacheManager.initialize();

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

  static bool _shouldSkipProcessing() {
    final now = DateTime.now();
    if (_lastProcessingTime != null) {
      final timeSinceLastProcessing = now.difference(_lastProcessingTime!);
      if (timeSinceLastProcessing < _minProcessingInterval) {
        return true;
      }
    }
    _lastProcessingTime = now;
    return false;
  }

  Future<OCRResult> processSingleReceipt(
    String imagePath, {
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
  }) async {
    final batchResult = await processImageList(
      [imagePath],
      mode: ProcessingMode.individual,
      priority: priority,
      cancellationToken: cancellationToken,
    );

    if (batchResult.results.isEmpty) {
      throw OCRException('No results from single image processing');
    }

    return batchResult.results.first;
  }

  Future<OCRResult> processLongReceipt(
    List<String> sectionPaths, {
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
  }) async {
    final batchResult = await processImageList(
      sectionPaths,
      mode: ProcessingMode.longReceipt,
      priority: priority,
      cancellationToken: cancellationToken,
    );

    if (batchResult.results.isEmpty) {
      throw OCRException('No results from long receipt processing');
    }

    return batchResult.results.first;
  }

  Future<OCRResult> _processImageInternal(
    String imagePath, {
    required bool isLongReceipt,
    CancellationToken? cancellationToken,
  }) async {
    String? tempProcessedPath;

    try {
      debugPrint('🚀 Processing image: ${imagePath.split('/').last}');

      final originalFile = File(imagePath);
      if (!await originalFile.exists()) {
        throw OCRException(
          'Image file not found: $imagePath',
          type: OCRErrorType.imageNotFound,
        );
      }

      final fileSize = await originalFile.length();
      debugPrint(
        '📊 File size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB',
      );

      if (fileSize > maxFileSize) {
        throw OCRException(
          'Image file too large: ${fileSize / (1024 * 1024)}MB',
          type: OCRErrorType.imageTooLarge,
        );
      }

      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      // Try to process directly first (fastest approach)
      try {
        debugPrint('🔄 Attempting direct OCR processing...');
        final recognizedText = await _performOCRFromFile(imagePath);

        if (recognizedText.text.isEmpty) {
          debugPrint('⚠️ No text detected, will try with preprocessing');
          throw Exception('No text detected');
        }

        if (cancellationToken?.isCancelled == true) {
          throw CancellationException();
        }

        final storeType = _detectStoreType(recognizedText.text);
        final extractedPrices = _extractPrices(recognizedText, storeType);
        final enhancedPrices = _enhancePricesWithNLP(
          extractedPrices,
          recognizedText.text,
          storeType,
        );
        final confidence = _calculateOverallConfidence(
          enhancedPrices,
          recognizedText,
        );

        debugPrint(
          '✅ Direct processing successful: ${enhancedPrices.length} prices found',
        );

        return OCRResult(
          fullText: recognizedText.text,
          prices: enhancedPrices,
          confidence: confidence,
          enhancement: EnhancementType.original,
          storeType: storeType,
          metadata: {
            'processing_method': 'direct',
            'processing_time': DateTime.now().millisecondsSinceEpoch,
            'is_long_receipt': isLongReceipt,
            'file_size_mb': fileSize / (1024 * 1024),
          },
        );
      } catch (e) {
        debugPrint('⚠️ Direct processing failed: $e');
        // Continue with preprocessing approach
      }

      // If direct processing failed, try with preprocessing
      debugPrint('🔄 Attempting processing with preprocessing...');

      final originalBytes = await originalFile.readAsBytes();
      final image = img.decodeImage(originalBytes);

      if (image == null) {
        throw OCRException(
          'Failed to decode image',
          type: OCRErrorType.imageCorrupted,
        );
      }

      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      final preprocessed = await _preprocessImageSafely(image);

      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      tempProcessedPath = await _saveImageToTempFile(preprocessed);
      if (tempProcessedPath == null) {
        throw OCRException(
          'Failed to save preprocessed image',
          type: OCRErrorType.processingFailed,
        );
      }

      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      final recognizedText = await _performOCRFromFile(tempProcessedPath);

      if (cancellationToken?.isCancelled == true) {
        throw CancellationException();
      }

      final storeType = _detectStoreType(recognizedText.text);
      final extractedPrices = _extractPrices(recognizedText, storeType);
      final enhancedPrices = _enhancePricesWithNLP(
        extractedPrices,
        recognizedText.text,
        storeType,
      );
      final confidence = _calculateOverallConfidence(
        enhancedPrices,
        recognizedText,
      );

      debugPrint(
        '✅ Preprocessing method successful: ${enhancedPrices.length} prices found',
      );

      return OCRResult(
        fullText: recognizedText.text,
        prices: enhancedPrices,
        confidence: confidence,
        enhancement: EnhancementType.hybrid,
        storeType: storeType,
        metadata: {
          'processing_method': 'preprocessed',
          'processing_time': DateTime.now().millisecondsSinceEpoch,
          'is_long_receipt': isLongReceipt,
          'original_size': '${image.width}x${image.height}',
          'processed_size': '${preprocessed.width}x${preprocessed.height}',
          'file_size_mb': fileSize / (1024 * 1024),
        },
      );
    } catch (e) {
      debugPrint('❌ Image processing failed completely: $e');
      rethrow;
    } finally {
      // Clean up temp file
      if (tempProcessedPath != null) {
        try {
          final tempFile = File(tempProcessedPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint('⚠️ Failed to clean up temp file: $e');
        }
      }
    }
  }

  

  Future<BatchOCRResult> processImageList(
    List<String> imagePaths, {
    ProcessingMode mode = ProcessingMode.individual,
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
    Function(int current, int total, String imagePath)? onProgress,
  }) async {
    _ensureInitialized();

    if (imagePaths.isEmpty) {
      throw OCRException(
        'No image paths provided',
        type: OCRErrorType.insufficientSections,
      );
    }

    final stopwatch = Stopwatch()..start();
    final sessionId = _generateSessionId();
    final token = cancellationToken ?? CancellationToken();
    final results = <OCRResult>[];
    int successfulImages = 0;
    int failedImages = 0;

    try {
      await _waitForProcessingSlot(priority, _currentProcessingTasks);
      _currentProcessingTasks++;
      _activeTasks.add(token);

      switch (mode) {
        case ProcessingMode.individual:
          // Process each image separately
          for (int i = 0; i < imagePaths.length; i++) {
            if (token.isCancelled) {
              throw CancellationException('Batch processing cancelled');
            }

            final imagePath = imagePaths[i];
            onProgress?.call(i + 1, imagePaths.length, imagePath);

            try {
              final result = await _processImageInternal(
                imagePath,
                isLongReceipt: false,
                cancellationToken: token,
              );
              results.add(result);
              successfulImages++;
            } catch (e) {
              debugPrint('Failed to process image $imagePath: $e');
              failedImages++;

              // Create an error result to maintain list consistency
              final errorResult = OCRResult(
                fullText: '',
                prices: [],
                confidence: 0.0,
                enhancement: EnhancementType.original,
                storeType: 'unknown',
                metadata: {
                  'error': true,
                  'error_message': e.toString(),
                  'image_path': imagePath,
                },
              );
              results.add(errorResult);
            }
          }
          break;

        case ProcessingMode.longReceipt:
          // Process as long receipt sections
          onProgress?.call(0, 1, 'Processing long receipt...');

          try {
            final mergedResult = await _processLongReceiptInternal(
              imagePaths,
              cancellationToken: token,
            );
            results.add(mergedResult);
            successfulImages = 1;
          } catch (e) {
            failedImages = 1;
            final errorResult = OCRResult(
              fullText: '',
              prices: [],
              confidence: 0.0,
              enhancement: EnhancementType.original,
              storeType: 'unknown',
              metadata: {
                'error': true,
                'error_message': e.toString(),
                'long_receipt': true,
                'section_count': imagePaths.length,
              },
            );
            results.add(errorResult);
          }
          break;
      }

      stopwatch.stop();

      final batchResult = BatchOCRResult(
        results: results,
        totalImages: imagePaths.length,
        successfulImages: successfulImages,
        failedImages: failedImages,
        totalProcessingTime: stopwatch.elapsed,
        batchMetadata: {
          'session_id': sessionId,
          'processing_mode': mode.toString(),
          'priority': priority.toString(),
          'total_processing_time_ms': stopwatch.elapsedMilliseconds,
          'average_time_per_image': imagePaths.isNotEmpty
              ? stopwatch.elapsedMilliseconds / imagePaths.length
              : 0,
        },
      );

      await _logBatchPerformance(sessionId, batchResult, mode);
      return batchResult;
    } catch (e) {
      stopwatch.stop();
      await _logBatchPerformance(sessionId, null, mode, e.toString());
      rethrow;
    } finally {
      _currentProcessingTasks--;
      _activeTasks.remove(token);
    }
  }

  Future<OCRResult> _processLongReceiptInternal(
    List<String> sectionPaths, {
    CancellationToken? cancellationToken,
  }) async {
    final sectionResults = <OCRResult>[];

    for (int i = 0; i < sectionPaths.length; i++) {
      if (cancellationToken?.isCancelled == true) {
        throw CancellationException('Long receipt processing cancelled');
      }

      debugPrint(
        'ConsolidatedOCRService: Processing section ${i + 1}/${sectionPaths.length}',
      );

      final sectionResult = await _processImageInternal(
        sectionPaths[i],
        isLongReceipt: true,
        cancellationToken: cancellationToken,
      );
      sectionResults.add(sectionResult);
    }

    return _mergeLongReceiptResults(sectionResults);
  }

  Future<String?> _saveImageToTempFile(img.Image image) async {
    try {
      _tempDirectory ??= await getTemporaryDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${_tempDirectory!.path}/ocr_temp_$timestamp.jpg';

      final jpegBytes = img.encodeJpg(image, quality: 90);
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(jpegBytes);

      return tempPath;
    } catch (e) {
      debugPrint('Failed to save image to temp file: $e');
      return null;
    }
  }

  Future<void> _logBatchPerformance(
    String sessionId,
    BatchOCRResult? result,
    ProcessingMode mode, [
    String? error,
  ]) async {
    if (!_config.enablePerformanceMonitoring) return;

    final metadata = result?.batchMetadata ?? {};
    metadata.addAll({
      'processing_mode': mode.toString(),
      'is_batch': true,
      'error': error,
    });

    await OCRPerformanceMonitor.logOCRAttempt(
      sessionId: sessionId,
      imagePath: 'batch_processing',
      processingTimeMs: result?.totalProcessingTime.inMilliseconds ?? 0,
      extractedPricesCount:
          result?.results.fold(0, (sum, r) => sum! + r.prices.length) ?? 0,
      averageConfidence: result?.results.isNotEmpty == true
          ? result!.results.map((r) => r.confidence).reduce((a, b) => a + b) /
                result.results.length
          : 0.0,
      bestEnhancement: result?.results.isNotEmpty == true
          ? result!.results.first.enhancement.toString()
          : 'none',
      storeType: result?.results.isNotEmpty == true
          ? result!.results.first.storeType
          : 'unknown',
      isLongReceipt: mode == ProcessingMode.longReceipt,
      metadata: metadata,
      errorMessage: error,
    );
  }

  Future<img.Image> _preprocessImage(img.Image image) async {
    try {
      return await OCRImageUtils.preprocessForOCR(image);
    } catch (e) {
      debugPrint('Advanced preprocessing failed, using lightweight: $e');
      return OCRImageUtils.lightweightPreprocess(image);
    }
  }

  Future<RecognizedText> _performOCRFromFile(String imagePath) async {
    try {
      debugPrint('🔍 Starting OCR for file: ${imagePath.split('/').last}');

      // Validate file exists and is readable
      final file = File(imagePath);
      if (!await file.exists()) {
        throw OCRException(
          'Image file not found: $imagePath',
          type: OCRErrorType.imageNotFound,
        );
      }

      final fileSize = await file.length();
      debugPrint('📄 File size: ${(fileSize / 1024).toStringAsFixed(1)}KB');

      if (fileSize == 0) {
        throw OCRException(
          'Image file is empty',
          type: OCRErrorType.imageCorrupted,
        );
      }

      // Try multiple approaches for OCR
      RecognizedText? result;
      Exception? lastException;

      // Approach 1: Direct file input (most efficient)
      try {
        debugPrint('🔄 Attempting OCR with direct file input...');
        final inputImage = InputImage.fromFilePath(imagePath);
        result = await _textRecognizer
            .processImage(inputImage)
            .timeout(processingTimeout);
        debugPrint('✅ OCR successful with direct file input');
        return result;
      } catch (e) {
        debugPrint('⚠️ Direct file OCR failed: $e');
        lastException = e is Exception ? e : Exception(e.toString());
      }

      // Approach 2: Bytes input with proper metadata
      try {
        debugPrint('🔄 Attempting OCR with bytes input...');
        final bytes = await file.readAsBytes();

        // Decode image to get proper dimensions
        final image = img.decodeImage(bytes);
        if (image == null) {
          throw OCRException(
            'Failed to decode image for OCR',
            type: OCRErrorType.imageCorrupted,
          );
        }

        debugPrint('🖼️ Image dimensions: ${image.width}x${image.height}');

        // Create InputImage with proper metadata
        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.yuv420, // Try different format
            bytesPerRow: image.width * 4, // RGBA
          ),
        );

        result = await _textRecognizer
            .processImage(inputImage)
            .timeout(processingTimeout);
        debugPrint('✅ OCR successful with bytes input');
        return result;
      } catch (e) {
        debugPrint('⚠️ Bytes OCR failed: $e');
        lastException = e is Exception ? e : Exception(e.toString());
      }

      // Approach 3: Processed image with format conversion
      try {
        debugPrint('🔄 Attempting OCR with processed image...');
        final bytes = await file.readAsBytes();
        final image = img.decodeImage(bytes);

        if (image == null) {
          throw OCRException(
            'Failed to decode image for processing',
            type: OCRErrorType.imageCorrupted,
          );
        }

        // Convert to JPEG if needed and ensure proper format
        final processedBytes = img.encodeJpg(image, quality: 90);

        final inputImage = InputImage.fromBytes(
          bytes: processedBytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        );

        result = await _textRecognizer
            .processImage(inputImage)
            .timeout(processingTimeout);
        debugPrint('✅ OCR successful with processed image');
        return result;
      } catch (e) {
        debugPrint('⚠️ Processed image OCR failed: $e');
        lastException = e is Exception ? e : Exception(e.toString());
      }

      // If all approaches failed, throw the last exception
      debugPrint('❌ All OCR approaches failed');
      throw OCRException(
        'OCR processing failed after multiple attempts: ${lastException.toString() ?? "Unknown error"}',
        type: OCRErrorType.processingFailed,
      );
    } catch (e) {
      debugPrint('❌ OCR processing error: $e');
      if (e is OCRException) {
        rethrow;
      }
      throw OCRException(
        'OCR processing failed: $e',
        type: OCRErrorType.processingFailed,
      );
    }
  }

  Future<img.Image> _preprocessImageSafely(img.Image image) async {
    try {
      debugPrint('🔧 Starting safe image preprocessing...');
      debugPrint('📐 Original image: ${image.width}x${image.height}');

      // Apply lightweight preprocessing to avoid memory issues
      var processed = image;

      // Resize if too large (prevent memory crashes)
      if (image.width > 2048 || image.height > 2048) {
        debugPrint('📏 Resizing large image...');
        final maxDim = 2048;
        final ratio =
            maxDim / (image.width > image.height ? image.width : image.height);
        processed = img.copyResize(
          processed,
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
          interpolation: img.Interpolation.linear, // Faster than cubic
        );
        debugPrint('✅ Resized to: ${processed.width}x${processed.height}');
      }

      // Apply basic enhancement (safer than advanced preprocessing)
      processed = img.adjustColor(processed, contrast: 1.1, brightness: 5);

      debugPrint('✅ Image preprocessing completed safely');
      return processed;
    } catch (e) {
      debugPrint('⚠️ Preprocessing failed, using original: $e');
      return image; // Return original if preprocessing fails
    }
  }

  Future<RecognizedText> _performOCRFromBytes(List<int> bytes) async {
    try {
      // Decode image to get proper dimensions
      final image = img.decodeImage(Uint8List.fromList(bytes));
      if (image == null) {
        throw OCRException(
          'Failed to decode image for OCR',
          type: OCRErrorType.imageCorrupted,
        );
      }

      final inputImage = InputImage.fromBytes(
        bytes: Uint8List.fromList(bytes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      return await _textRecognizer
          .processImage(inputImage)
          .timeout(processingTimeout);
    } catch (e) {
      throw OCRException(
        'OCR processing from bytes failed: $e',
        type: OCRErrorType.processingFailed,
      );
    }
  }

  // Store detection method
  String _detectStoreType(String text) {
    final lowerText = text.toLowerCase();

    // explore later
    /* for (final pattern in _priceSmartProfile.patterns) {
      if (pattern.hasMatch(lowerText)) {
        debugPrint('✅ Detected store: PriceSmart');
        return 'pricesmart';
      }
    } */

    final storePatterns = {
      'pricesmart': [
        RegExp(r'price\s*smart', caseSensitive: false),
        RegExp(r'pricesmart', caseSensitive: false),
        RegExp(r'ps\s*membership', caseSensitive: false),
      ],
      'megamart': [
        RegExp(r'mega\s*mart', caseSensitive: false),
        RegExp(r'megamart', caseSensitive: false),
      ],
      'hi-lo': [
        RegExp(r'hi[\s-]*lo', caseSensitive: false),
        RegExp(r'hilo', caseSensitive: false),
      ],
      // Add more stores as needed
    };

    for (final entry in storePatterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(lowerText)) {
          debugPrint('✅ Detected store: ${entry.key}');
          return entry.key;
        }
      }
    }

    debugPrint('⚠️ Store type not detected, using generic');
    return 'generic';
  }

  // Price extraction methods
  List<ExtractedPrice> _extractPrices(
    RecognizedText recognizedText,
    String storeType,
  ) {
    final prices = <ExtractedPrice>[];

    prices.addAll(_extractWithStorePatterns(recognizedText, storeType));
    prices.addAll(_extractWithGenericPatterns(recognizedText));
    prices.addAll(_extractFromLines(recognizedText));

    return _deduplicateAndValidatePrices(prices);
  }

  List<ExtractedPrice> _extractWithStorePatterns(
    RecognizedText recognizedText,
    String storeType,
  ) {
    final prices = <ExtractedPrice>[];
    List<RegExp> patterns;

    if (storeType == 'pricesmart') {
      patterns = _priceSmartProfile.pricePatterns;
    } else {
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

            if (price != null &&
                price > 0 &&
                price < 50000 &&
                itemName.isNotEmpty) {
              prices.add(
                ExtractedPrice(
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
                ),
              );
            }
          }
        }
      }
    }

    return prices;
  }

  List<ExtractedPrice> _extractWithGenericPatterns(
    RecognizedText recognizedText,
  ) {
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

            if (price != null &&
                price > 0 &&
                price < 50000 &&
                itemName.isNotEmpty) {
              prices.add(
                ExtractedPrice(
                  itemName: itemName,
                  price: price,
                  originalText: text,
                  confidence: _calculatePatternConfidence(match, text),
                  position: _convertBoundingBox(line.boundingBox),
                  category: 'Other',
                  unit: 'each',
                  metadata: {'extraction_method': 'generic_pattern'},
                ),
              );
            }
          }
        }
      }
    }

    return prices;
  }

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
              prices.add(
                ExtractedPrice(
                  itemName: itemName,
                  price: price,
                  originalText: text,
                  confidence: 0.7,
                  position: _convertBoundingBox(line.boundingBox),
                  category: 'Other',
                  unit: 'each',
                  metadata: {'extraction_method': 'line_analysis'},
                ),
              );
            }
          }
        }
      }
    }

    return prices;
  }

  // NLP enhancement methods
  List<ExtractedPrice> _enhancePricesWithNLP(
    List<ExtractedPrice> prices,
    String fullText,
    String storeType,
  ) {
    final enhanced = <ExtractedPrice>[];

    for (final price in prices) {
      final cleanedName = _cleanItemName(price.itemName);
      final category = _detectCategory(cleanedName, price.originalText);
      final unit = _detectUnit(price.originalText, category);

      if (_validatePrice(price.price, category, storeType)) {
        enhanced.add(
          ExtractedPrice(
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
          ),
        );
      }
    }

    return enhanced;
  }

  String _cleanItemName(String itemName) {
    if (itemName.isEmpty) return 'Unknown Item';

    var cleaned = itemName.toLowerCase().trim();
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.trim();

    return cleaned
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _detectCategory(String itemName, String originalText) {
    final text = '$itemName $originalText'.toLowerCase();

    final categoryKeywords = {
      'Meat': ['chicken', 'beef', 'pork', 'fish', 'meat', 'bacon', 'ham'],
      'Produce': [
        'apple',
        'banana',
        'orange',
        'lettuce',
        'tomato',
        'onion',
        'fruit',
        'vegetable',
      ],
      'Dairy': ['milk', 'cheese', 'yogurt', 'butter', 'cream', 'eggs'],
      'Beverages': ['juice', 'soda', 'water', 'drink', 'cola', 'beer', 'wine'],
      'Groceries': [
        'rice',
        'bread',
        'flour',
        'sugar',
        'oil',
        'pasta',
        'cereal',
      ],
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

  String _detectUnit(String originalText, String category) {
    final text = originalText.toLowerCase();

    if (RegExp(r'\b(lb|lbs|pound|pounds)\b').hasMatch(text)) return 'per lb';
    if (RegExp(r'\b(kg|kilo|kilogram)\b').hasMatch(text)) return 'per kg';
    if (RegExp(r'\b(gal|gallon|gallons)\b').hasMatch(text)) return 'per gallon';
    if (RegExp(r'\b(l|lt|liter|litre)\b').hasMatch(text)) return 'per liter';
    if (RegExp(r'\b(pk|pack|package)\b').hasMatch(text)) return 'per pack';

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
    final minPrice = storeType == 'pricesmart'
        ? max(range['min']! * 2, 100.0)
        : range['min']!.toDouble();

    return price >= minPrice && price <= range['max']!;
  }

  // Deduplication and validation
  List<ExtractedPrice> _deduplicateAndValidatePrices(
    List<ExtractedPrice> prices,
  ) {
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

    unique.sort((a, b) => b.confidence.compareTo(a.confidence));
    return unique;
  }

  bool _areSimilarPrices(ExtractedPrice price1, ExtractedPrice price2) {
    if ((price1.price - price2.price).abs() < 0.01) {
      final distance = _calculateDistance(
        price1.position.center,
        price2.position.center,
      );
      return distance < 50;
    }
    return false;
  }

  double _calculateDistance(Offset point1, Offset point2) {
    return sqrt(pow(point1.dx - point2.dx, 2) + pow(point1.dy - point2.dy, 2));
  }

  // Long receipt merging
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

    final uniquePrices = _removeSemanticDuplicates(allPrices);
    final avgConfidence = sectionResults.isNotEmpty
        ? totalConfidence / sectionResults.length
        : 0.0;

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

  bool _areSemanticallySimilar(ExtractedPrice price1, ExtractedPrice price2) {
    final nameSimilarity = _calculateStringSimilarity(
      price1.itemName.toLowerCase(),
      price2.itemName.toLowerCase(),
    );

    if (nameSimilarity > 0.8) {
      final priceDiff =
          (price1.price - price2.price).abs() / max(price1.price, price2.price);
      return priceDiff < 0.15;
    }

    return false;
  }

  double _calculateStringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final words1 = s1.split(' ').toSet();
    final words2 = s2.split(' ').toSet();
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    return intersection.length / union.length;
  }

  // Confidence calculation
  double _calculateOverallConfidence(
    List<ExtractedPrice> prices,
    RecognizedText recognizedText,
  ) {
    if (prices.isEmpty) return 0.0;

    final avgPriceConfidence =
        prices.map((p) => p.confidence).reduce((a, b) => a + b) / prices.length;

    double textConfidence = 0.8;
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

  double _calculatePatternConfidence(RegExpMatch match, String fullText) {
    double confidence = 0.6;

    final itemName = match.group(1) ?? '';
    final price = match.group(2) ?? '';

    if (itemName.length > 3) confidence += 0.1;
    if (itemName.contains(' ')) confidence += 0.1;
    if (price.contains('.') && price.length >= 4) confidence += 0.1;
    if (!_isNonProductLine(fullText)) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  bool _isNonProductLine(String text) {
    final lowerText = text.toLowerCase().trim();
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
    ];

    for (final pattern in skipPatterns) {
      if (lowerText.contains(pattern)) return true;
    }

    if (RegExp(r'^\d+$').hasMatch(lowerText) || lowerText.length < 3) {
      return true;
    }

    return false;
  }

  Rect _convertBoundingBox(Rect? boundingBox) {
    return boundingBox ?? Rect.zero;
  }

  // Utility methods
  static Future<void> _waitForProcessingSlot(
    ProcessingPriority priority,
    int currentProcessingTasks,
  ) async {
    int waitTime = 0;
    const maxWaitTime = 5000; // 5 seconds max wait

    while (currentProcessingTasks >= maxConcurrentProcessing) {
      if (waitTime >= maxWaitTime) {
        throw OCRException(
          'Processing queue timeout',
          type: OCRErrorType.ocrTimeout,
        );
      }

      await Future.delayed(Duration(milliseconds: 100));
      waitTime += 100;
    }
  }

  String _generateCacheKey(String imagePath) {
    final file = File(imagePath);
    final fileName = file.path.split('/').last;
    final timestamp = file.lastModifiedSync().millisecondsSinceEpoch;
    return sha256.convert(utf8.encode('$fileName-$timestamp')).toString();
  }

  String _generateLongReceiptCacheKey(List<String> sectionPaths) {
    final combined = sectionPaths.join('|');
    return sha256.convert(utf8.encode(combined)).toString();
  }

  String _generateSessionId() {
    return 'consolidated_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  Future<void> _logPerformance(
    String sessionId,
    String imagePath,
    int processingTime,
    OCRResult? result,
    bool isLongReceipt, [
    String? error,
  ]) async {
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

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw OCRException(
        'ConsolidatedOCRService not initialized. Call initialize() first.',
        type: OCRErrorType.unknown,
      );
    }
  }

  // Public utility methods
  Future<SystemPerformanceMetrics> getSystemMetrics() async {
    return SystemPerformanceMetrics(
      memoryUsageMB: 200.0,
      cpuUsagePercent: 45.0,
      batteryLevel: 80.0,
      thermalState: ThermalState.nominal,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> getPerformanceStats() {
    return {
      'initialized': _isInitialized,
      'current_processing_tasks': _currentProcessingTasks,
      'max_concurrent_processing': maxConcurrentProcessing,
      'cache_type': _config.usePersistentCache ? 'persistent' : 'memory',
      'performance_monitoring': _config.enablePerformanceMonitoring,
    };
  }

  Future<void> clearCache() async {
    await _cacheManager.clear();
    debugPrint('ConsolidatedOCRService: Cache cleared');
  }

  void cancelAllOperations() {
    for (final token in List.from(_activeTasks)) {
      token.cancel();
    }
    _activeTasks.clear();
  }

  void dispose() {
    _textRecognizer.close();
    _cacheManager.dispose();
    cancelAllOperations();
    _isInitialized = false;
    debugPrint('ConsolidatedOCRService: Disposed');
  }
}

enum ProcessingMode {
  individual, // Process each image separately
  longReceipt, // Process as sections of a long receipt (merge results)
}

class BatchOCRResult {
  final List<OCRResult> results;
  final int totalImages;
  final int successfulImages;
  final int failedImages;
  final Duration totalProcessingTime;
  final Map<String, dynamic> batchMetadata;

  BatchOCRResult({
    required this.results,
    required this.totalImages,
    required this.successfulImages,
    required this.failedImages,
    required this.totalProcessingTime,
    required this.batchMetadata,
  });

  double get successRate =>
      totalImages > 0 ? successfulImages / totalImages : 0.0;
  bool get hasResults => results.isNotEmpty;
}

// Configuration and data classes
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

enum EnhancementType {
  original,
  contrast,
  brightness,
  sharpen,
  grayscale,
  binarize,
  hybrid,
}

enum ThermalState { nominal, fair, serious, critical }

class CancellationException implements Exception {
  final String message;

  CancellationException([this.message = 'Operation was cancelled']);

  @override
  String toString() => 'CancellationException: $message';
}

// Extensions
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
  Future<BatchOCRResult> processAsImageList({
    ProcessingMode mode = ProcessingMode.individual,
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
    Function(int current, int total, String imagePath)? onProgress,
  }) {
    return ConsolidatedOCRService.instance.processImageList(
      this,
      mode: mode,
      priority: priority,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
    );
  }
}

import 'dart:io' show File, Directory;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:jamaica_price_directory/services/consolidated_ocr_service.dart';

class OCRPerformanceManager {
  static const int maxConcurrentProcessing = 2;
  static const int imageCompressionQuality = 85;
  static const int maxImageResolution = 2048;

  static int _currentProcessingTasks = 0;
  static final List<Future<void>> _processingQueue = [];

  /// Process image with performance monitoring
  static Future<OCRResult?> processWithPerformanceOptimization(
    String imagePath, {
    bool isLongReceipt = false,
  }) async {
    // Check if we're at capacity
    if (_currentProcessingTasks >= maxConcurrentProcessing) {
      debugPrint('⚠️ OCR processing at capacity, queuing request');
      await _waitForAvailableSlot();
    }

    _currentProcessingTasks++;
    final stopwatch = Stopwatch()..start();

    try {
      // Pre-process image for optimal performance
      final optimizedPath = await _optimizeImageForOCR(imagePath);

      // Process with enhanced OCR
      final result = await ConsolidatedOCRService.instance.processSingleReceipt(
        optimizedPath ?? imagePath,
      );

      stopwatch.stop();

      // Log performance metrics
      await _logPerformanceMetrics(
        processingTime: stopwatch.elapsedMilliseconds,
        pricesExtracted: result.prices.length,
        isLongReceipt: isLongReceipt,
        success: true,
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      await _logPerformanceMetrics(
        processingTime: stopwatch.elapsedMilliseconds,
        pricesExtracted: 0,
        isLongReceipt: isLongReceipt,
        success: false,
        error: e.toString(),
      );

      return null;
    } finally {
      _currentProcessingTasks--;

      // Clean up optimized image if created
      await _cleanupTempFiles();
    }
  }

  static Future<void> _waitForAvailableSlot() async {
    while (_currentProcessingTasks >= maxConcurrentProcessing) {
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  static Future<String?> _optimizeImageForOCR(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileSize = await file.length();

      // Skip optimization if file is already small
      if (fileSize < 2 * 1024 * 1024) return null; // 2MB threshold

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Resize if too large
      img.Image optimized = image;
      if (image.width > maxImageResolution ||
          image.height > maxImageResolution) {
        final ratio = maxImageResolution / max(image.width, image.height);
        optimized = img.copyResize(
          image,
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
          interpolation: img.Interpolation.cubic,
        );
      }

      // Compress with optimal quality
      final optimizedBytes = img.encodeJpg(
        optimized,
        quality: imageCompressionQuality,
      );

      // Save optimized version
      final optimizedPath =
          '${file.parent.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(optimizedPath).writeAsBytes(optimizedBytes);

      return optimizedPath;
    } catch (e) {
      debugPrint('Image optimization failed: $e');
      return null;
    }
  }

  static Future<void> _logPerformanceMetrics({
    required int processingTime,
    required int pricesExtracted,
    required bool isLongReceipt,
    required bool success,
    String? error,
  }) async {
    // Log to performance monitor if available
    if (kDebugMode) {
      debugPrint('📊 OCR Performance:');
      debugPrint('  Time: ${processingTime}ms');
      debugPrint('  Prices: $pricesExtracted');
      debugPrint('  Long Receipt: $isLongReceipt');
      debugPrint('  Success: $success');
      if (error != null) debugPrint('  Error: $error');
    }
  }

  static Future<void> _cleanupTempFiles() async {
    try {
      final tempDir = Directory.systemTemp;
      final files = await tempDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.contains('optimized_')) {
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);

          // Delete files older than 10 minutes
          if (age.inMinutes > 10) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Cleanup failed: $e');
    }
  }
}

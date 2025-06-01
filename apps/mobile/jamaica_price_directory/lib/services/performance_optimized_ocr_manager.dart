import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'ocr_processor.dart';
import 'ocr_error_handler.dart';
import 'ocr_performance_monitor.dart';
import 'unified_ocr_service.dart';

// Performance-optimized OCR Manager
class PerformanceOptimizedOCRManager {
  static const int maxConcurrentProcessing = 2;
  static const int maxImageResolution = 2048;
  static const int maxMemoryThreshold = 512 * 1024 * 1024; // 512MB
  static const Duration processingTimeout = Duration(seconds: 30);
  
  static int _currentProcessingTasks = 0;
  static final List<CancellationToken> _activeTasks = [];
  static SystemPerformanceMetrics? _lastMetrics;

  // Main optimized processing method
  static Future<OCRResult> processWithOptimization(
    String imagePath, {
    bool isLongReceipt = false,
    ProcessingPriority priority = ProcessingPriority.normal,
    CancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? CancellationToken();
    final sessionId = _generateSessionId();
    final stopwatch = Stopwatch()..start();

    try {
      // Check system resources before starting
      await _checkSystemResources();
      
      // Wait for available processing slot
      await _waitForProcessingSlot(priority);
      
      _currentProcessingTasks++;
      _activeTasks.add(token);

      // Pre-optimization checks
      final optimizationStrategy = await _determineOptimizationStrategy(
        imagePath,
        isLongReceipt: isLongReceipt,
      );

      OCRResult result;

      // Choose processing path based on strategy
      switch (optimizationStrategy.processingPath) {
        case ProcessingPath.lightweight:
          result = await _processLightweight(imagePath, token);
          break;
        case ProcessingPath.standard:
          result = await _processStandard(imagePath, token);
          break;
        case ProcessingPath.intensive:
          result = await _processIntensive(imagePath, isLongReceipt, token);
          break;
        case ProcessingPath.isolate:
          result = await _processInIsolate(imagePath, isLongReceipt, token);
          break;
      }

      stopwatch.stop();

      // Log performance metrics
      await OCRPerformanceMonitor.logOCRAttempt(
        sessionId: sessionId,
        imagePath: imagePath,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        extractedPricesCount: result.prices.length,
        averageConfidence: result.confidence,
        bestEnhancement: result.enhancement.toString(),
        storeType: result.storeType,
        isLongReceipt: isLongReceipt,
        metadata: {
          ...result.metadata,
          'optimization_strategy': optimizationStrategy.toJson(),
          'processing_priority': priority.toString(),
          'memory_usage': await _getMemoryUsage(),
        },
      );

      return result;
    } catch (e) {
      stopwatch.stop();
      
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
    } finally {
      _currentProcessingTasks--;
      _activeTasks.remove(token);
      await _cleanupResources();
    }
  }

  // System resource monitoring
  static Future<SystemPerformanceMetrics> _getSystemMetrics() async {
    final memoryUsage = await _getMemoryUsage();
    final cpuUsage = await _getCPUUsage();
    final batteryLevel = await _getBatteryLevel();
    final thermalState = await _getThermalState();

    return SystemPerformanceMetrics(
      memoryUsageMB: memoryUsage,
      cpuUsagePercent: cpuUsage,
      batteryLevel: batteryLevel,
      thermalState: thermalState,
      timestamp: DateTime.now(),
    );
  }

  static Future<OptimizationStrategy> _determineOptimizationStrategy(
    String imagePath, {
    bool isLongReceipt = false,
  }) async {
    final file = File(imagePath);
    final fileSize = await file.length();
    final metrics = await _getSystemMetrics();
    
    // Image analysis
    final imageComplexity = await _analyzeImageComplexity(imagePath);
    
    // Determine processing path
    ProcessingPath processingPath;
    
    if (metrics.memoryUsageMB > 400 || metrics.thermalState == ThermalState.critical) {
      processingPath = ProcessingPath.lightweight;
    } else if (fileSize > 5 * 1024 * 1024 || isLongReceipt || imageComplexity == ImageComplexity.high) {
      processingPath = ProcessingPath.isolate;
    } else if (imageComplexity == ImageComplexity.medium || fileSize > 2 * 1024 * 1024) {
      processingPath = ProcessingPath.intensive;
    } else {
      processingPath = ProcessingPath.standard;
    }

    return OptimizationStrategy(
      processingPath: processingPath,
      imageComplexity: imageComplexity,
      systemMetrics: metrics,
      recommendedResolution: _getRecommendedResolution(fileSize, metrics),
      useHardwareAcceleration: metrics.cpuUsagePercent < 70,
      enableCaching: metrics.memoryUsageMB < 300,
    );
  }

  // Lightweight processing for resource-constrained scenarios
  static Future<OCRResult> _processLightweight(
    String imagePath,
    CancellationToken token,
  ) async {
    try {
      // Use minimal preprocessing
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      
      if (token.isCancelled) throw CancellationException();
      
      final image = img.decodeImage(bytes);
      if (image == null) throw OCRException('Failed to decode image');

      // Aggressive resizing to reduce memory usage
      final resized = _aggressiveResize(image, maxDimension: 1024);
      
      if (token.isCancelled) throw CancellationException();

      // Use only basic OCR without enhancement
      final result = await UnifiedOCRService.processSingleReceipt(
        await _saveTemporaryImage(resized),
      );

      return result;
    } catch (e) {
      if (e is CancellationException) rethrow;
      throw OCRException('Lightweight processing failed: $e');
    }
  }

  // Standard processing path
  static Future<OCRResult> _processStandard(
    String imagePath,
    CancellationToken token,
  ) async {
    if (token.isCancelled) throw CancellationException();
    
    return await UnifiedOCRService.processSingleReceipt(imagePath)
        .timeout(processingTimeout);
  }

  // Intensive processing with full enhancement pipeline
  static Future<OCRResult> _processIntensive(
    String imagePath,
    bool isLongReceipt,
    CancellationToken token,
  ) async {
    try {
      if (token.isCancelled) throw CancellationException();

      // Pre-optimize image
      final optimizedPath = await _preOptimizeImage(imagePath);
      
      if (token.isCancelled) throw CancellationException();

      // Process with full pipeline
      final result = await UnifiedOCRService.processSingleReceipt(
        optimizedPath,
        isLongReceipt: isLongReceipt,
      ).timeout(processingTimeout);

      // Cleanup temporary file
      await _cleanupTemporaryFile(optimizedPath);

      return result;
    } catch (e) {
      if (e is CancellationException) rethrow;
      throw OCRException('Intensive processing failed: $e');
    }
  }

  // Isolate-based processing for heavy operations
  static Future<OCRResult> _processInIsolate(
    String imagePath,
    bool isLongReceipt,
    CancellationToken token,
  ) async {
    try {
      if (token.isCancelled) throw CancellationException();

      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(
        _isolateEntryPoint,
        IsolateMessage(
          sendPort: receivePort.sendPort,
          imagePath: imagePath,
          isLongReceipt: isLongReceipt,
        ),
      );

      // Wait for result with timeout and cancellation
      final completer = Completer<OCRResult>();
      late StreamSubscription subscription;

      subscription = receivePort.listen((data) {
        subscription.cancel();
        receivePort.close();
        isolate.kill();

        if (data is Map<String, dynamic>) {
          if (data['error'] != null) {
            completer.completeError(OCRException(data['error']));
          } else {
            completer.complete(_deserializeOCRResult(data['result']));
          }
        } else {
          completer.completeError(OCRException('Invalid isolate response'));
        }
      });

      // Handle cancellation
      token.onCancel(() {
        if (!completer.isCompleted) {
          subscription.cancel();
          receivePort.close();
          isolate.kill();
          completer.completeError(CancellationException());
        }
      });

      return await completer.future.timeout(processingTimeout);
    } catch (e) {
      if (e is CancellationException || e is TimeoutException) rethrow;
      throw OCRException('Isolate processing failed: $e');
    }
  }

  // Isolate entry point
  static void _isolateEntryPoint(IsolateMessage message) async {
    try {
      // Note: In a real implementation, you'd need to set up the OCR processor in the isolate
      // This is a simplified version
      final result = {
        'result': {
          'fullText': 'Isolated processing result',
          'prices': [],
          'confidence': 0.5,
          'enhancement': 'EnhancementType.original',
          'storeType': 'unknown',
          'metadata': {},
        }
      };
      
      message.sendPort.send(result);
    } catch (e) {
      message.sendPort.send({'error': e.toString()});
    }
  }

  // Resource management methods
  static Future<void> _checkSystemResources() async {
    final metrics = await _getSystemMetrics();
    _lastMetrics = metrics;

    if (metrics.memoryUsageMB > maxMemoryThreshold / (1024 * 1024)) {
      throw OCRException(
        'Insufficient memory for processing',
        type: OCRErrorType.lowMemory,
      );
    }

    if (metrics.thermalState == ThermalState.critical) {
      throw OCRException(
        'Device overheating - processing suspended',
        type: OCRErrorType.unknown,
      );
    }
  }

  static Future<void> _waitForProcessingSlot(ProcessingPriority priority) async {
    while (_currentProcessingTasks >= maxConcurrentProcessing) {
      if (priority == ProcessingPriority.high) {
        // High priority can interrupt lower priority tasks
        final lowPriorityTasks = _activeTasks.where((t) => !t.isHighPriority).toList();
        if (lowPriorityTasks.isNotEmpty) {
          lowPriorityTasks.first.cancel();
          break;
        }
      }
      
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  static Future<void> _cleanupResources() async {
    // Force garbage collection if memory is high
    if (_lastMetrics?.memoryUsageMB != null && _lastMetrics!.memoryUsageMB > 300) {
      await _forceGarbageCollection();
    }
  }

  // Image optimization methods
  static Future<ImageComplexity> _analyzeImageComplexity(String imagePath) async {
    final file = File(imagePath);
    final fileSize = await file.length();
    
    // Simple heuristics - in production, you'd analyze actual image content
    if (fileSize > 8 * 1024 * 1024) return ImageComplexity.high;
    if (fileSize > 3 * 1024 * 1024) return ImageComplexity.medium;
    return ImageComplexity.low;
  }

  static img.Image _aggressiveResize(img.Image image, {int maxDimension = 1024}) {
    if (image.width <= maxDimension && image.height <= maxDimension) {
      return image;
    }

    final ratio = maxDimension / max(image.width, image.height);
    return img.copyResize(
      image,
      width: (image.width * ratio).round(),
      height: (image.height * ratio).round(),
      interpolation: img.Interpolation.nearest, // Fastest
    );
  }

  static Future<String> _preOptimizeImage(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) throw OCRException('Failed to decode image for optimization');

    // Apply optimizations
    var optimized = image;
    
    // Resize if too large
    if (image.width > maxImageResolution || image.height > maxImageResolution) {
      final ratio = maxImageResolution / max(image.width, image.height);
      optimized = img.copyResize(
        image,
        width: (image.width * ratio).round(),
        height: (image.height * ratio).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    // Basic enhancement
    optimized = img.adjustColor(optimized, contrast: 1.1);

    return await _saveTemporaryImage(optimized);
  }

  static Future<String> _saveTemporaryImage(img.Image image) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    final bytes = img.encodeJpg(image, quality: 85);
    await tempFile.writeAsBytes(bytes);
    
    return tempFile.path;
  }

  static Future<void> _cleanupTemporaryFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to cleanup temporary file: $e');
    }
  }

  // System metrics helpers (simplified implementations)
  static Future<double> _getMemoryUsage() async {
    try {
      // In production, use platform-specific memory monitoring
      return 256.0; // Placeholder
    } catch (e) {
      return 256.0;
    }
  }

  static Future<double> _getCPUUsage() async {
    try {
      // In production, use platform-specific CPU monitoring
      return 45.0; // Placeholder
    } catch (e) {
      return 50.0;
    }
  }

  static Future<double> _getBatteryLevel() async {
    try {
      // Use battery_plus package in production
      return 80.0; // Placeholder
    } catch (e) {
      return 100.0;
    }
  }

  static Future<ThermalState> _getThermalState() async {
    try {
      // In production, monitor device thermal state
      return ThermalState.nominal;
    } catch (e) {
      return ThermalState.nominal;
    }
  }

  static int _getRecommendedResolution(int fileSize, SystemPerformanceMetrics metrics) {
    if (metrics.memoryUsageMB > 400 || fileSize > 10 * 1024 * 1024) {
      return 1024;
    } else if (metrics.memoryUsageMB > 200 || fileSize > 5 * 1024 * 1024) {
      return 1536;
    } else {
      return 2048;
    }
  }

  static Future<void> _forceGarbageCollection() async {
    final List<List<int>> memoryPressure = [];
    try {
      for (int i = 0; i < 20; i++) {
        memoryPressure.add(List.filled(100000, i));
      }
    } catch (e) {
      // Expected - creates memory pressure
    } finally {
      memoryPressure.clear();
    }
    await Future.delayed(Duration(milliseconds: 100));
  }

  static String _generateSessionId() {
    return 'perf_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  static OCRResult _deserializeOCRResult(Map<String, dynamic> data) {
    // Simplified deserialization - implement based on your EnhancedOCRResult structure
    return OCRResult(
      fullText: data['fullText'] ?? '',
      prices: [], // Deserialize price list
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      enhancement: EnhancementType.original,
      storeType: data['storeType'] ?? 'unknown',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  static Future<SystemPerformanceMetrics> getSystemMetrics() async {
    return await _getSystemMetrics();
  }

  static int getCurrentProcessingTasks() {
    return _currentProcessingTasks;
  }

  static bool isProcessingAvailable() {
    return _currentProcessingTasks < maxConcurrentProcessing;
  }

  // Public API for cancelling operations
  static void cancelAllOperations() {
    for (final token in List.from(_activeTasks)) {
      token.cancel();
    }
    _activeTasks.clear();
  }

  static void cancelOperation(CancellationToken token) {
    token.cancel();
    _activeTasks.remove(token);
  }
}

// Supporting Classes
class OptimizationStrategy {
  final ProcessingPath processingPath;
  final ImageComplexity imageComplexity;
  final SystemPerformanceMetrics systemMetrics;
  final int recommendedResolution;
  final bool useHardwareAcceleration;
  final bool enableCaching;

  OptimizationStrategy({
    required this.processingPath,
    required this.imageComplexity,
    required this.systemMetrics,
    required this.recommendedResolution,
    required this.useHardwareAcceleration,
    required this.enableCaching,
  });

  Map<String, dynamic> toJson() {
    return {
      'processing_path': processingPath.toString(),
      'image_complexity': imageComplexity.toString(),
      'recommended_resolution': recommendedResolution,
      'use_hardware_acceleration': useHardwareAcceleration,
      'enable_caching': enableCaching,
      'system_metrics': systemMetrics.toJson(),
    };
  }
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
  bool _isHighPriority = false;
  final List<VoidCallback> _callbacks = [];

  bool get isCancelled => _isCancelled;
  bool get isHighPriority => _isHighPriority;

  CancellationToken({bool highPriority = false}) {
    _isHighPriority = highPriority;
  }

  void cancel() {
    if (_isCancelled) return;
    
    _isCancelled = true;
    for (final callback in _callbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in cancellation callback: $e');
      }
    }
    _callbacks.clear();
  }

  void onCancel(VoidCallback callback) {
    if (_isCancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }
}

class IsolateMessage {
  final SendPort sendPort;
  final String imagePath;
  final bool isLongReceipt;

  IsolateMessage({
    required this.sendPort,
    required this.imagePath,
    required this.isLongReceipt,
  });
}

enum ProcessingPath {
  lightweight,  // Minimal processing for resource-constrained scenarios
  standard,     // Normal processing path
  intensive,    // Full enhancement pipeline
  isolate,      // Heavy processing in separate isolate
}

enum ImageComplexity {
  low,     // Simple images, small file size
  medium,  // Moderate complexity
  high,    // Complex images, large file size, many elements
}

enum ThermalState {
  nominal,   // Normal operating temperature
  fair,      // Slightly warm but acceptable
  serious,   // Getting hot, should reduce performance
  critical,  // Too hot, must stop intensive operations
}

enum ProcessingPriority {
  low,     // Background processing, can be interrupted
  normal,  // Standard processing
  high,    // High priority, can interrupt low priority tasks
}

class CancellationException implements Exception {
  final String message;
  CancellationException([this.message = 'Operation was cancelled']);
  
  @override
  String toString() => 'CancellationException: $message';
}

// Adaptive Quality Manager
class AdaptiveQualityManager {
  static const int performanceHistorySize = 10;
  static final List<ProcessingMetrics> _performanceHistory = [];

  static ProcessingQuality determineOptimalQuality({
    required SystemPerformanceMetrics systemMetrics,
    required ImageComplexity imageComplexity,
    bool isLongReceipt = false,
  }) {
    // Analyze recent performance
    final avgProcessingTime = _getAverageProcessingTime();
    final successRate = _getRecentSuccessRate();

    // Base quality on system performance
    ProcessingQuality baseQuality;
    if (systemMetrics.memoryUsageMB > 400 || systemMetrics.cpuUsagePercent > 80) {
      baseQuality = ProcessingQuality.low;
    } else if (systemMetrics.memoryUsageMB > 200 || systemMetrics.cpuUsagePercent > 60) {
      baseQuality = ProcessingQuality.medium;
    } else {
      baseQuality = ProcessingQuality.high;
    }

    // Adjust based on image complexity
    if (imageComplexity == ImageComplexity.high && baseQuality == ProcessingQuality.low) {
      // For complex images, prefer medium quality even if system is constrained
      baseQuality = ProcessingQuality.medium;
    }

    // Adjust based on recent performance
    if (avgProcessingTime > 15000 && successRate < 0.8) {
      // Recent poor performance, reduce quality
      switch (baseQuality) {
        case ProcessingQuality.high:
          baseQuality = ProcessingQuality.medium;
          break;
        case ProcessingQuality.medium:
          baseQuality = ProcessingQuality.low;
          break;
        case ProcessingQuality.low:
          break;
      }
    }

    return baseQuality;
  }

  static void recordPerformance(ProcessingMetrics metrics) {
    _performanceHistory.add(metrics);
    if (_performanceHistory.length > performanceHistorySize) {
      _performanceHistory.removeAt(0);
    }
  }

  static double _getAverageProcessingTime() {
    if (_performanceHistory.isEmpty) return 0.0;
    
    return _performanceHistory
        .map((m) => m.processingTimeMs)
        .reduce((a, b) => a + b) / _performanceHistory.length;
  }

  static double _getRecentSuccessRate() {
    if (_performanceHistory.isEmpty) return 1.0;
    
    final successCount = _performanceHistory.where((m) => m.success).length;
    return successCount / _performanceHistory.length;
  }
}

class ProcessingMetrics {
  final int processingTimeMs;
  final bool success;
  final int extractedPrices;
  final double confidence;
  final DateTime timestamp;

  ProcessingMetrics({
    required this.processingTimeMs,
    required this.success,
    required this.extractedPrices,
    required this.confidence,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum ProcessingQuality {
  low,     // Fast processing, lower accuracy
  medium,  // Balanced processing
  high,    // Slow processing, higher accuracy
}
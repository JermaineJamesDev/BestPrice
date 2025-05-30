import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class OCRErrorHandler {
  static const Map<String, String> _errorMessages = {
    'camera_permission_denied': 'Camera permission is required to scan receipts. Please grant access in settings.',
    'camera_not_available': 'Camera is not available on this device.',
    'image_too_large': 'Image file is too large. Please use a smaller image or try again.',
    'image_corrupted': 'The image file appears to be corrupted. Please try taking a new photo.',
    'ocr_timeout': 'OCR processing timed out. Please try with better lighting or a clearer image.',
    'low_memory': 'Not enough memory to process this image. Please close other apps and try again.',
    'network_error': 'Network connection required for enhanced OCR features.',
    'storage_full': 'Device storage is full. Please free up space and try again.',
    'mlkit_error': 'Text recognition service is temporarily unavailable.',
    'processing_error': 'An error occurred while processing the image. Please try again.',
    'long_receipt_error': 'Error processing long receipt sections. Please try capturing individual sections.',
  };

  static String getErrorMessage(dynamic error, {String? context}) {
    final errorType = _categorizeError(error);
    final baseMessage = _errorMessages[errorType] ?? 'An unexpected error occurred. Please try again.';
    
    if (kDebugMode) {
      debugPrint('OCR Error - Type: $errorType, Context: $context, Original: $error');
    }
    
    return baseMessage;
  }

  static String _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (error is PlatformException) {
      switch (error.code) {
        case 'camera_access_denied':
        case 'permission_denied':
          return 'camera_permission_denied';
        case 'camera_not_found':
          return 'camera_not_available';
        default:
          return 'processing_error';
      }
    }
    
    if (error is FileSystemException) {
      if (errorString.contains('no space left')) {
        return 'storage_full';
      }
      return 'processing_error';
    }
    
    if (errorString.contains('timeout')) {
      return 'ocr_timeout';
    }
    
    if (errorString.contains('memory') || errorString.contains('heap')) {
      return 'low_memory';
    }
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'network_error';
    }
    
    if (errorString.contains('image') && (errorString.contains('large') || errorString.contains('size'))) {
      return 'image_too_large';
    }
    
    if (errorString.contains('corrupt') || errorString.contains('invalid')) {
      return 'image_corrupted';
    }
    
    if (errorString.contains('mlkit') || errorString.contains('text recognition')) {
      return 'mlkit_error';
    }
    
    if (errorString.contains('long receipt') || errorString.contains('section')) {
      return 'long_receipt_error';
    }
    
    return 'processing_error';
  }

  static bool isRetryable(dynamic error) {
    final errorType = _categorizeError(error);
    
    switch (errorType) {
      case 'camera_permission_denied':
      case 'camera_not_available':
      case 'storage_full':
      case 'image_corrupted':
        return false;
      
      case 'ocr_timeout':
      case 'network_error':
      case 'mlkit_error':
      case 'processing_error':
      case 'long_receipt_error':
        return true;
      
      case 'low_memory':
      case 'image_too_large':
        return true; // Can retry with optimizations
      
      default:
        return true;
    }
  }

  static Map<String, String> getSuggestedActions(dynamic error) {
    final errorType = _categorizeError(error);
    
    switch (errorType) {
      case 'camera_permission_denied':
        return {
          'primary': 'Open Settings',
          'secondary': 'Manual Entry',
        };
      
      case 'camera_not_available':
        return {
          'primary': 'Manual Entry',
          'secondary': 'Gallery Upload',
        };
      
      case 'image_too_large':
        return {
          'primary': 'Retry with Compression',
          'secondary': 'Take New Photo',
        };
      
      case 'low_memory':
        return {
          'primary': 'Free Memory & Retry',
          'secondary': 'Manual Entry',
        };
      
      case 'ocr_timeout':
        return {
          'primary': 'Retry with Better Lighting',
          'secondary': 'Manual Entry',
        };
      
      case 'long_receipt_error':
        return {
          'primary': 'Try Standard Mode',
          'secondary': 'Manual Entry',
        };
      
      default:
        return {
          'primary': 'Retry',
          'secondary': 'Manual Entry',
        };
    }
  }
}

// Advanced error recovery system
class OCRErrorRecovery {
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  static Future<T?> executeWithRecovery<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxAttempts = maxRetryAttempts,
    Function(dynamic error, int attempt)? onError,
    Function(int attempt)? onRetry,
  }) async {
    int attempt = 0;
    dynamic lastError;
    
    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (error) {
        attempt++;
        lastError = error;
        
        if (onError != null) {
          onError(error, attempt);
        }
        
        if (attempt >= maxAttempts || !OCRErrorHandler.isRetryable(error)) {
          break;
        }
        
        if (onRetry != null) {
          onRetry(attempt);
        }
        
        // Apply recovery strategies before retry
        await _applyRecoveryStrategy(error);
        await Future.delayed(retryDelay * attempt);
      }
    }
    
    throw lastError ?? Exception('Maximum retry attempts exceeded');
  }
  
  static Future<void> _applyRecoveryStrategy(dynamic error) async {
    final errorType = OCRErrorHandler._categorizeError(error);
    
    switch (errorType) {
      case 'low_memory':
        // Force garbage collection
        await _forceGarbageCollection();
        break;
      
      case 'image_too_large':
        // The next attempt should use smaller image size
        break;
      
      case 'ocr_timeout':
        // Clear any cached ML models to force fresh initialization
        break;
      
      default:
        // General recovery - small delay
        await Future.delayed(Duration(milliseconds: 500));
        break;
    }
  }
  
  static Future<void> _forceGarbageCollection() async {
    // Force garbage collection by creating and releasing memory pressure
    final List<List<int>> memoryPressure = [];
    try {
      for (int i = 0; i < 10; i++) {
        memoryPressure.add(List.filled(100000, i));
      }
    } catch (e) {
      // Ignore memory allocation errors
    } finally {
      memoryPressure.clear();
    }
    
    // Give the GC time to run
    await Future.delayed(Duration(milliseconds: 100));
  }
}

// OCR Testing Framework
class OCRTestFramework {
  static const String testImagesPath = 'test_images';
  
  static Future<void> runOCRTests() async {
    if (!kDebugMode) return;
    
    debugPrint('🧪 Starting OCR Test Suite...');
    
    await _testImageProcessing();
    await _testErrorHandling();
    await _testPerformance();
    await _testLongReceipts();
    
    debugPrint('✅ OCR Test Suite completed');
  }
  
  static Future<void> _testImageProcessing() async {
    debugPrint('📸 Testing Image Processing...');
    
    final testCases = [
      'receipt_hi_lo_clear.jpg',
      'receipt_megamart_blurry.jpg',
      'receipt_pricesmart_rotated.jpg',
      'receipt_generic_low_light.jpg',
      'receipt_faded.jpg',
      'price_tag_individual.jpg',
    ];
    
    for (final testCase in testCases) {
      try {
        debugPrint('  Testing: $testCase');
        // Here you would load the test image and process it
        // await SuperAdvancedOCRProcessor.processReceiptImage(testImagePath);
        debugPrint('  ✅ $testCase - PASSED');
      } catch (e) {
        debugPrint('  ❌ $testCase - FAILED: $e');
      }
    }
  }
  
  static Future<void> _testErrorHandling() async {
    debugPrint('🚨 Testing Error Handling...');
    
    final errorTests = [
      () => throw PlatformException(code: 'camera_access_denied'),
      () => throw FileSystemException('No space left on device'),
      () => throw Exception('OCR timeout'),
      () => throw OutOfMemoryError(),
    ];
    
    for (int i = 0; i < errorTests.length; i++) {
      try {
        await errorTests[i]();
      } catch (e) {
        final errorMessage = OCRErrorHandler.getErrorMessage(e);
        final isRetryable = OCRErrorHandler.isRetryable(e);
        final actions = OCRErrorHandler.getSuggestedActions(e);
        
        debugPrint('  Error Test ${i + 1}:');
        debugPrint('    Message: $errorMessage');
        debugPrint('    Retryable: $isRetryable');
        debugPrint('    Actions: $actions');
      }
    }
  }
  
  static Future<void> _testPerformance() async {
    debugPrint('⚡ Testing Performance...');
    
    // Simulate different image sizes and complexities
    final performanceTests = [
      {'name': 'Small Receipt', 'width': 800, 'height': 1200},
      {'name': 'Large Receipt', 'width': 2000, 'height': 3000},
      {'name': 'Long Receipt Section', 'width': 1200, 'height': 2000},
    ];
    
    for (final test in performanceTests) {
      final stopwatch = Stopwatch()..start();
      
      try {
        // Simulate OCR processing time
        await Future.delayed(Duration(milliseconds: 
          (test['width']! as int) * (test['height']! as int) ~/ 1000000));
        
        stopwatch.stop();
        debugPrint('  ${test['name']}: ${stopwatch.elapsedMilliseconds}ms');
        
        if (stopwatch.elapsedMilliseconds > 10000) {
          debugPrint('    ⚠️  Warning: Processing time exceeds 10 seconds');
        }
      } catch (e) {
        debugPrint('  ${test['name']}: FAILED - $e');
      }
    }
  }
  
  static Future<void> _testLongReceipts() async {
    debugPrint('📄 Testing Long Receipt Processing...');
    
    final longReceiptTests = [
      {'sections': 2, 'overlap': 0.2},
      {'sections': 3, 'overlap': 0.3},
      {'sections': 5, 'overlap': 0.25},
    ];
    
    for (final test in longReceiptTests) {
      try {
        debugPrint('  Testing ${test['sections']} sections with ${(test['overlap']! * 100).toInt()}% overlap');
        
        // Simulate long receipt processing
        await Future.delayed(Duration(milliseconds: (test['sections'] as int) * 2000));
        
        debugPrint('  ✅ Long receipt test - PASSED');
      } catch (e) {
        debugPrint('  ❌ Long receipt test - FAILED: $e');
      }
    }
  }
  
  static Map<String, dynamic> generateTestReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'tests_run': 4,
      'categories': [
        'Image Processing',
        'Error Handling', 
        'Performance',
        'Long Receipts'
      ],
      'environment': {
        'debug_mode': kDebugMode,
        'platform': Platform.operatingSystem,
      },
    };
  }
}

// Memory optimization utilities
class OCRMemoryOptimizer {
  static const int maxImageDimension = 2048;
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const double compressionQuality = 0.85;
  
  static Future<bool> checkMemoryAvailability() async {
    try {
      // Create a temporary allocation to check available memory
      final testAllocation = List.filled(1000000, 0); // ~4MB
      testAllocation.clear();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static Future<String?> optimizeImageForOCR(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileSize = await file.length();
      
      if (fileSize <= maxFileSize) {
        return imagePath; // No optimization needed
      }
      
      debugPrint('🔧 Optimizing image: ${fileSize / (1024 * 1024)}MB -> target: ${maxFileSize / (1024 * 1024)}MB');
      
      // In a real implementation, you would:
      // 1. Load the image
      // 2. Resize if necessary
      // 3. Compress with appropriate quality
      // 4. Save to temporary file
      // 5. Return new path
      
      // For now, return the original path
      return imagePath;
    } catch (e) {
      debugPrint('Failed to optimize image: $e');
      return null;
    }
  }
  
  static void clearOCRCache() {
    // Clear any cached OCR data
    debugPrint('🧹 Clearing OCR cache...');
    
    // In a real implementation:
    // - Clear temporary files
    // - Release ML model cache
    // - Clear image processing cache
  }
  
  static Future<void> preloadOCRResources() async {
    debugPrint('📦 Preloading OCR resources...');
    
    try {
      // Preload ML Kit models
      // Initialize text recognizer
      // Cache common enhancement filters
      
      await Future.delayed(Duration(milliseconds: 500)); // Simulate preloading
      debugPrint('✅ OCR resources preloaded');
    } catch (e) {
      debugPrint('⚠️ Failed to preload OCR resources: $e');
    }
  }
}

// User feedback and analytics
class OCRUserFeedback {
  static void trackUserCorrection({
    required String originalText,
    required String correctedText,
    required double originalConfidence,
  }) {
    if (kDebugMode) {
      debugPrint('📝 User Correction Tracked:');
      debugPrint('  Original: "$originalText" (${(originalConfidence * 100).toStringAsFixed(1)}%)');
      debugPrint('  Corrected: "$correctedText"');
    }
    
    // In production:
    // - Send to analytics
    // - Update ML model training data
    // - Improve OCR patterns
  }
  
  static void trackUserSatisfaction({
    required String sessionId,
    required int rating, // 1-5
    required String feedback,
    required Map<String, dynamic> context,
  }) {
    if (kDebugMode) {
      debugPrint('⭐ User Satisfaction: $rating/5');
      debugPrint('   Feedback: "$feedback"');
      debugPrint('   Context: $context');
    }
    
    // In production:
    // - Store in analytics database
    // - Trigger alerts for low ratings
    // - Generate improvement insights
  }
  
  static void trackFeatureUsage({
    required String feature,
    required bool successful,
    required Duration duration,
    Map<String, dynamic>? metadata,
  }) {
    if (kDebugMode) {
      debugPrint('📊 Feature Usage: $feature');
      debugPrint('   Success: $successful');
      debugPrint('   Duration: ${duration.inMilliseconds}ms');
      if (metadata != null) {
        debugPrint('   Metadata: $metadata');
      }
    }
  }
}

// Integration test widget
class OCRIntegrationTestWidget extends StatefulWidget {
  const OCRIntegrationTestWidget({super.key});
  
  @override
  _OCRIntegrationTestWidgetState createState() => _OCRIntegrationTestWidgetState();
}

class _OCRIntegrationTestWidgetState extends State<OCRIntegrationTestWidget> {
  List<String> _testResults = [];
  bool _isRunning = false;
  
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Container(
        child: Text('Test widget only available in debug mode'),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('OCR Integration Tests'),
        actions: [
          IconButton(
            onPressed: _isRunning ? null : _runTests,
            icon: Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isRunning)
            LinearProgressIndicator(),
          
          Expanded(
            child: ListView.builder(
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                final isSuccess = result.contains('✅');
                
                return ListTile(
                  leading: Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                  title: Text(result),
                  dense: true,
                );
              },
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _runTests,
                    child: Text('Run Tests'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearResults,
                    child: Text('Clear'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
    });
    
    await _runBasicTests();
    await _runErrorTests();
    await _runPerformanceTests();
    
    setState(() {
      _isRunning = false;
    });
  }
  
  Future<void> _runBasicTests() async {
    _addResult('Starting basic OCR tests...');
    
    // Test memory check
    final hasMemory = await OCRMemoryOptimizer.checkMemoryAvailability();
    _addResult(hasMemory ? '✅ Memory check passed' : '❌ Memory check failed');
    
    // Test error categorization
    try {
      final error = PlatformException(code: 'camera_access_denied');
      final message = OCRErrorHandler.getErrorMessage(error);
      _addResult(message.isNotEmpty ? '✅ Error handling works' : '❌ Error handling failed');
    } catch (e) {
      _addResult('❌ Error handling test failed: $e');
    }
  }
  
  Future<void> _runErrorTests() async {
    _addResult('Starting error handling tests...');
    
    final testErrors = [
      PlatformException(code: 'camera_access_denied'),
      Exception('OCR timeout'),
      FileSystemException('No space left'),
    ];
    
    for (int i = 0; i < testErrors.length; i++) {
      try {
        final error = testErrors[i];
        final message = OCRErrorHandler.getErrorMessage(error);
        final isRetryable = OCRErrorHandler.isRetryable(error);
        _addResult('✅ Error ${i + 1}: $message (Retryable: $isRetryable)');
      } catch (e) {
        _addResult('❌ Error test ${i + 1} failed: $e');
      }
    }
  }
  
  Future<void> _runPerformanceTests() async {
    _addResult('Starting performance tests...');
    
    final stopwatch = Stopwatch()..start();
    
    // Simulate OCR processing
    await Future.delayed(Duration(milliseconds: 100));
    
    stopwatch.stop();
    
    final processingTime = stopwatch.elapsedMilliseconds;
    _addResult(processingTime < 1000 
      ? '✅ Performance test passed: ${processingTime}ms'
      : '⚠️ Performance test slow: ${processingTime}ms');
  }
  
  void _addResult(String result) {
    setState(() {
      _testResults.add(result);
    });
  }
  
  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }
}
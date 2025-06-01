import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:async';

//  OCR Error Types
enum OCRErrorType {
  // Image-related errors
  imageNotFound,
  imageCorrupted,
  imageTooLarge,
  imageTooSmall,
  imageFormatUnsupported,
  
  // OCR processing errors
  ocrTimeout,
  ocrServiceUnavailable,
  lowImageQuality,
  noTextDetected,
  processingFailed,
  
  // Hardware/permissions
  cameraPermissionDenied,
  cameraNotAvailable,
  cameraInitializationFailed,
  
  // System resources
  lowMemory,
  storageInsufficient,
  networkUnavailable,
  
  // Long receipt specific
  longReceiptSectionFailed,
  longReceiptMergeFailed,
  insufficientSections,
  
  // Generic
  unknown,
}

// Error Context for better debugging
class OCRErrorContext {
  final String operation;
  final String? imagePath;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String? deviceInfo;

  OCRErrorContext({
    required this.operation,
    this.imagePath,
    this.metadata = const {},
    DateTime? timestamp,
    this.deviceInfo,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'operation': operation,
      'image_path': imagePath,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'device_info': deviceInfo,
    };
  }
}

//  OCR Error Handler
class OCRErrorHandler {
  static const Map<OCRErrorType, String> _errorMessages = {
    // Image errors
    OCRErrorType.imageNotFound: 'Image file not found. Please try taking a new photo.',
    OCRErrorType.imageCorrupted: 'Image file is corrupted. Please capture a new image.',
    OCRErrorType.imageTooLarge: 'Image file is too large. Please try with lower resolution.',
    OCRErrorType.imageTooSmall: 'Image is too small or has insufficient detail. Please capture a closer image.',
    OCRErrorType.imageFormatUnsupported: 'Image format not supported. Please use JPEG or PNG.',
    
    // OCR processing errors
    OCRErrorType.ocrTimeout: 'Text recognition timed out. Please try with better lighting or clearer image.',
    OCRErrorType.ocrServiceUnavailable: 'Text recognition service temporarily unavailable.',
    OCRErrorType.lowImageQuality: 'Image quality too low for accurate text recognition. Please improve lighting and focus.',
    OCRErrorType.noTextDetected: 'No text detected in image. Please ensure the receipt is clearly visible.',
    OCRErrorType.processingFailed: 'Processing failed. Please try again with a different angle or lighting.',
    
    // Hardware/permissions
    OCRErrorType.cameraPermissionDenied: 'Camera permission required. Please enable in Settings.',
    OCRErrorType.cameraNotAvailable: 'Camera not available on this device.',
    OCRErrorType.cameraInitializationFailed: 'Failed to initialize camera. Please try again.',
    
    // System resources
    OCRErrorType.lowMemory: 'Insufficient memory to process image. Please close other apps and try again.',
    OCRErrorType.storageInsufficient: 'Insufficient storage space. Please free up space and try again.',
    OCRErrorType.networkUnavailable: 'Network connection required for enhanced processing.',
    
    // Long receipt specific
    OCRErrorType.longReceiptSectionFailed: 'Failed to process receipt section. Please try capturing individual sections.',
    OCRErrorType.longReceiptMergeFailed: 'Failed to merge receipt sections. Please try standard capture mode.',
    OCRErrorType.insufficientSections: 'Insufficient sections captured. Please capture more sections for better results.',
    
    // Generic
    OCRErrorType.unknown: 'An unexpected error occurred. Please try again.',
  };

  static const Map<OCRErrorType, List<String>> _suggestedActions = {
    OCRErrorType.imageNotFound: ['Retake Photo', 'Manual Entry'],
    OCRErrorType.imageCorrupted: ['Retake Photo', 'Manual Entry'],
    OCRErrorType.imageTooLarge: ['Retake with Lower Quality', 'Manual Entry'],
    OCRErrorType.imageTooSmall: ['Retake Closer', 'Use Long Receipt Mode'],
    OCRErrorType.lowImageQuality: ['Improve Lighting', 'Retake Photo', 'Manual Entry'],
    OCRErrorType.noTextDetected: ['Retake with Better Angle', 'Manual Entry'],
    OCRErrorType.cameraPermissionDenied: ['Open Settings', 'Manual Entry'],
    OCRErrorType.cameraNotAvailable: ['Manual Entry', 'Gallery Upload'],
    OCRErrorType.lowMemory: ['Close Apps & Retry', 'Manual Entry'],
    OCRErrorType.longReceiptSectionFailed: ['Try Standard Mode', 'Manual Entry'],
    OCRErrorType.longReceiptMergeFailed: ['Retake Sections', 'Try Standard Mode'],
  };

  static const Set<OCRErrorType> _retryableErrors = {
    OCRErrorType.ocrTimeout,
    OCRErrorType.ocrServiceUnavailable,
    OCRErrorType.processingFailed,
    OCRErrorType.cameraInitializationFailed,
    OCRErrorType.lowMemory,
    OCRErrorType.networkUnavailable,
    OCRErrorType.longReceiptSectionFailed,
  };

  static const Set<OCRErrorType> _criticalErrors = {
    OCRErrorType.cameraPermissionDenied,
    OCRErrorType.cameraNotAvailable,
    OCRErrorType.storageInsufficient,
  };

  static OCRErrorType categorizeError(dynamic error, {OCRErrorContext? context}) {
    if (error is OCRException) {
      return _categorizeOCRException(error);
    }
    
    if (error is PlatformException) {
      return _categorizePlatformException(error);
    }
    
    if (error is CameraException) {
      return _categorizeCameraException(error);
    }
    
    if (error is FileSystemException) {
      return _categorizeFileSystemException(error);
    }
    
    if (error is TimeoutException) {
      return OCRErrorType.ocrTimeout;
    }
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('memory') || errorString.contains('heap')) {
      return OCRErrorType.lowMemory;
    }
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return OCRErrorType.networkUnavailable;
    }
    
    if (errorString.contains('corrupted') || errorString.contains('invalid')) {
      return OCRErrorType.imageCorrupted;
    }
    
    if (errorString.contains('timeout')) {
      return OCRErrorType.ocrTimeout;
    }
    
    if (errorString.contains('no text') || errorString.contains('empty')) {
      return OCRErrorType.noTextDetected;
    }
    
    return OCRErrorType.unknown;
  }

  static String getErrorMessage(dynamic error, {OCRErrorContext? context}) {
    final errorType = categorizeError(error, context: context);
    return _errorMessages[errorType] ?? _errorMessages[OCRErrorType.unknown]!;
  }

  static List<String> getSuggestedActions(dynamic error, {OCRErrorContext? context}) {
    final errorType = categorizeError(error, context: context);
    return _suggestedActions[errorType] ?? ['Retry', 'Manual Entry'];
  }

  static bool isRetryable(dynamic error, {OCRErrorContext? context}) {
    final errorType = categorizeError(error, context: context);
    return _retryableErrors.contains(errorType);
  }

  static bool isCritical(dynamic error, {OCRErrorContext? context}) {
    final errorType = categorizeError(error, context: context);
    return _criticalErrors.contains(errorType);
  }

  static OCRErrorType _categorizeOCRException(OCRException error) {
    final message = error.message.toLowerCase();
    
    if (message.contains('not found')) return OCRErrorType.imageNotFound;
    if (message.contains('corrupted')) return OCRErrorType.imageCorrupted;
    if (message.contains('too large')) return OCRErrorType.imageTooLarge;
    if (message.contains('too small')) return OCRErrorType.imageTooSmall;
    if (message.contains('timeout')) return OCRErrorType.ocrTimeout;
    if (message.contains('no text')) return OCRErrorType.noTextDetected;
    
    return OCRErrorType.processingFailed;
  }

  static OCRErrorType _categorizePlatformException(PlatformException error) {
    switch (error.code) {
      case 'camera_access_denied':
      case 'permission_denied':
        return OCRErrorType.cameraPermissionDenied;
      case 'camera_not_found':
        return OCRErrorType.cameraNotAvailable;
      case 'out_of_memory':
        return OCRErrorType.lowMemory;
      default:
        return OCRErrorType.unknown;
    }
  }

  static OCRErrorType _categorizeCameraException(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return OCRErrorType.cameraPermissionDenied;
      case 'CameraNotFound':
        return OCRErrorType.cameraNotAvailable;
      case 'CameraNotInitialized':
      case 'CameraAccessFailed':
        return OCRErrorType.cameraInitializationFailed;
      default:
        return OCRErrorType.unknown;
    }
  }

  static OCRErrorType _categorizeFileSystemException(FileSystemException error) {
    final message = error.message.toLowerCase();
    
    if (message.contains('no space') || message.contains('disk full')) {
      return OCRErrorType.storageInsufficient;
    }
    
    if (message.contains('not found')) {
      return OCRErrorType.imageNotFound;
    }
    
    return OCRErrorType.unknown;
  }

  // Error logging for analytics
  static void logError(
    dynamic error, {
    OCRErrorContext? context,
    StackTrace? stackTrace,
  }) {
    final errorType = categorizeError(error, context: context);
    
    if (kDebugMode) {
      debugPrint('🚨 OCR Error: $errorType');
      debugPrint('   Message: ${getErrorMessage(error, context: context)}');
      debugPrint('   Context: ${context?.toJson()}');
      debugPrint('   Error: $error');
      if (stackTrace != null) {
        debugPrint('   Stack: $stackTrace');
      }
    }
    
    // In production, send to analytics service
    // Analytics.logError(errorType, error, context, stackTrace);
  }
}

//  Error Recovery System
class OCRErrorRecovery {
  static const int maxRetryAttempts = 3;
  static const Duration baseRetryDelay = Duration(seconds: 2);

  static Future<T?> executeWithRecovery<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxAttempts = maxRetryAttempts,
    OCRErrorContext? context,
    Function(dynamic error, int attempt)? onError,
    Function(int attempt)? onRetry,
    Function(T result)? onSuccess,
  }) async {
    int attempt = 0;
    dynamic lastError;

    while (attempt < maxAttempts) {
      try {
        final result = await operation();
        if (onSuccess != null) {
          onSuccess(result);
        }
        return result;
      } catch (error, stackTrace) {
        attempt++;
        lastError = error;

        // Log error
        OCRErrorHandler.logError(
          error,
          context: context,
          stackTrace: stackTrace,
        );

        if (onError != null) {
          onError(error, attempt);
        }

        final errorType = OCRErrorHandler.categorizeError(error, context: context);
        
        // Don't retry critical errors
        if (OCRErrorHandler.isCritical(error, context: context)) {
          break;
        }

        // Don't retry if max attempts reached or error is not retryable
        if (attempt >= maxAttempts || !OCRErrorHandler.isRetryable(error, context: context)) {
          break;
        }

        if (onRetry != null) {
          onRetry(attempt);
        }

        // Apply recovery strategy
        await _applyRecoveryStrategy(error, errorType, attempt);
        
        // Progressive delay
        await Future.delayed(baseRetryDelay * attempt);
      }
    }

    throw lastError ?? Exception('Maximum retry attempts exceeded');
  }

  static Future<void> _applyRecoveryStrategy(
    dynamic error,
    OCRErrorType errorType,
    int attempt,
  ) async {
    switch (errorType) {
      case OCRErrorType.lowMemory:
        await _forceGarbageCollection();
        break;
        
      case OCRErrorType.cameraInitializationFailed:
        await _resetCameraState();
        break;
        
      case OCRErrorType.ocrTimeout:
        // Increase timeout for next attempt
        debugPrint('🔄 Increasing timeout for attempt $attempt');
        break;
        
      case OCRErrorType.networkUnavailable:
        await _waitForNetwork();
        break;
        
      default:
        await Future.delayed(Duration(milliseconds: 500));
        break;
    }
  }

  static Future<void> _forceGarbageCollection() async {
    debugPrint('🧹 Forcing garbage collection...');
    
    // Create memory pressure to trigger GC
    final List<List<int>> memoryPressure = [];
    try {
      for (int i = 0; i < 10; i++) {
        memoryPressure.add(List.filled(100000, i));
      }
    } catch (e) {
      // Expected to fail due to memory pressure
    } finally {
      memoryPressure.clear();
    }
    
    await Future.delayed(Duration(milliseconds: 100));
  }

  static Future<void> _resetCameraState() async {
    debugPrint('🔄 Resetting camera state...');
    await Future.delayed(Duration(milliseconds: 500));
  }

  static Future<void> _waitForNetwork() async {
    debugPrint('🌐 Waiting for network...');
    await Future.delayed(Duration(seconds: 1));
  }
}

// Error UI Components
class OCRErrorDialog extends StatelessWidget {
  final dynamic error;
  final OCRErrorContext? context;
  final VoidCallback? onRetry;
  final VoidCallback? onManualEntry;
  final VoidCallback? onDismiss;

  const OCRErrorDialog({
    super.key,
    required this.error,
    this.context,
    this.onRetry,
    this.onManualEntry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final errorType = OCRErrorHandler.categorizeError(error, context: this.context);
    final message = OCRErrorHandler.getErrorMessage(error, context: this.context);
    final actions = OCRErrorHandler.getSuggestedActions(error, context: this.context);
    final isRetryable = OCRErrorHandler.isRetryable(error, context: this.context);
    final isCritical = OCRErrorHandler.isCritical(error, context: this.context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isCritical ? Icons.error : Icons.warning,
            color: isCritical ? Colors.red : Colors.orange,
          ),
          SizedBox(width: 8),
          Text(isCritical ? 'Critical Error' : 'Processing Error'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (kDebugMode) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Debug: ${errorType.toString()}\n${error.toString()}',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onDismiss != null)
          TextButton(
            onPressed: onDismiss,
            child: Text('Dismiss'),
          ),
        if (onManualEntry != null)
          TextButton(
            onPressed: onManualEntry,
            child: Text('Manual Entry'),
          ),
        if (isRetryable && onRetry != null)
          ElevatedButton(
            onPressed: onRetry,
            child: Text('Retry'),
          ),
      ],
    );
  }
}

class OCRErrorSnackBar {
  static void show(
    BuildContext context,
    dynamic error, {
    OCRErrorContext? errorContext,
    VoidCallback? onRetry,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final message = OCRErrorHandler.getErrorMessage(error, context: errorContext);
    final isRetryable = OCRErrorHandler.isRetryable(error, context: errorContext);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        action: isRetryable && onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                onPressed: onRetry,
                textColor: Colors.white,
              )
            : onAction != null
                ? SnackBarAction(
                    label: actionLabel ?? 'Action',
                    onPressed: onAction,
                    textColor: Colors.white,
                  )
                : null,
      ),
    );
  }
}

// Error Boundary Widget
class OCRErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext, dynamic, StackTrace?)? errorBuilder;
  final Function(dynamic, StackTrace?)? onError;

  const OCRErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  _OCRErrorBoundaryState createState() => _OCRErrorBoundaryState();
}

class _OCRErrorBoundaryState extends State<OCRErrorBoundary> {
  dynamic _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error, _stackTrace);
      }
      
      return _buildDefaultErrorWidget();
    }
    
    return widget.child;
  }

  Widget _buildDefaultErrorWidget() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Error'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                OCRErrorHandler.getErrorMessage(_error),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _stackTrace = null;
                  });
                },
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleError(dynamic error, StackTrace stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });
    
    if (widget.onError != null) {
      widget.onError!(error, stackTrace);
    }
    
    OCRErrorHandler.logError(
      error,
      stackTrace: stackTrace,
    );
  }
}

// Specific OCR Exception Class
class OCRException implements Exception {
  final String message;
  final OCRErrorType? type;
  final Map<String, dynamic>? metadata;

  OCRException(
    this.message, {
    this.type,
    this.metadata,
  });

  @override
  String toString() => 'OCRException: $message';
}

// Extension to add error handling to Future operations
extension FutureErrorHandling<T> on Future<T> {
  Future<T?> handleOCRErrors({
    OCRErrorContext? context,
    bool showSnackBar = false,
    BuildContext? snackBarContext,
  }) async {
    try {
      return await this;
    } catch (error, stackTrace) {
      OCRErrorHandler.logError(
        error,
        context: context,
        stackTrace: stackTrace,
      );
      
      if (showSnackBar && snackBarContext != null) {
        OCRErrorSnackBar.show(snackBarContext, error, errorContext: context);
      }
      
      return null;
    }
  }
}

// Utility functions for common error scenarios
class OCRErrorUtils {
  static Future<void> handleCameraError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    VoidCallback? onManualEntry,
  }) async {
    final errorType = OCRErrorHandler.categorizeError(error);
    
    if (errorType == OCRErrorType.cameraPermissionDenied) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Camera Permission Required'),
          content: Text('Please enable camera access in Settings to scan receipts.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Open app settings
                // In production, use package:permission_handler
              },
              child: Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => OCRErrorDialog(
          error: error,
          onRetry: onRetry,
          onManualEntry: onManualEntry,
          onDismiss: () => Navigator.pop(ctx),
        ),
      );
    }
  }

  static Future<void> handleOCRProcessingError(
    BuildContext context,
    dynamic error, {
    String? imagePath,
    VoidCallback? onRetry,
    VoidCallback? onManualEntry,
  }) async {
    final errorContext = OCRErrorContext(
      operation: 'ocr_processing',
      imagePath: imagePath,
      metadata: {'screen': 'processing'},
    );

    showDialog(
      context: context,
      builder: (ctx) => OCRErrorDialog(
        error: error,
        context: errorContext,
        onRetry: onRetry,
        onManualEntry: onManualEntry,
        onDismiss: () => Navigator.pop(ctx),
      ),
    );
  }
}
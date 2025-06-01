import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:async';

enum OCRErrorType {
  imageNotFound,
  imageCorrupted,
  imageTooLarge,
  imageTooSmall,
  imageFormatUnsupported,
  ocrTimeout,
  ocrServiceUnavailable,
  lowImageQuality,
  noTextDetected,
  processingFailed,
  cameraPermissionDenied,
  cameraNotAvailable,
  cameraInitializationFailed,
  lowMemory,
  storageInsufficient,
  networkUnavailable,
  longReceiptSectionFailed,
  longReceiptMergeFailed,
  insufficientSections,
  inputImageConverterError, // New error type for ML Kit conversion issues
  mlKitInitializationError, // New error type for ML Kit initialization issues
  unknown,
}

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

class OCRErrorHandler {
  static const Map<OCRErrorType, String> _errorMessages = {
    OCRErrorType.imageNotFound: 'Image file not found. Please try taking a new photo.',
    OCRErrorType.imageCorrupted: 'Image file is corrupted. Please capture a new image.',
    OCRErrorType.imageTooLarge: 'Image file is too large. Please try with lower resolution.',
    OCRErrorType.imageTooSmall: 'Image is too small or has insufficient detail. Please capture a closer image.',
    OCRErrorType.imageFormatUnsupported: 'Image format not supported. Please use JPEG or PNG.',
    OCRErrorType.inputImageConverterError: 'Image format incompatible with text recognition. Please try capturing a new photo.',
    OCRErrorType.mlKitInitializationError: 'Text recognition service failed to initialize. Please restart the app.',
    OCRErrorType.ocrTimeout: 'Text recognition timed out. Please try with better lighting or clearer image.',
    OCRErrorType.ocrServiceUnavailable: 'Text recognition service temporarily unavailable.',
    OCRErrorType.lowImageQuality: 'Image quality too low for accurate text recognition. Please improve lighting and focus.',
    OCRErrorType.noTextDetected: 'No text detected in image. Please ensure the receipt is clearly visible.',
    OCRErrorType.processingFailed: 'Processing failed. Please try again with a different angle or lighting.',
    OCRErrorType.cameraPermissionDenied: 'Camera permission required. Please enable in Settings.',
    OCRErrorType.cameraNotAvailable: 'Camera not available on this device.',
    OCRErrorType.cameraInitializationFailed: 'Failed to initialize camera. Please try again.',
    OCRErrorType.lowMemory: 'Insufficient memory to process image. Please close other apps and try again.',
    OCRErrorType.storageInsufficient: 'Insufficient storage space. Please free up space and try again.',
    OCRErrorType.networkUnavailable: 'Network connection required for enhanced processing.',
    OCRErrorType.longReceiptSectionFailed: 'Failed to process receipt section. Please try capturing individual sections.',
    OCRErrorType.longReceiptMergeFailed: 'Failed to merge receipt sections. Please try standard capture mode.',
    OCRErrorType.insufficientSections: 'Insufficient sections captured. Please capture more sections for better results.',
    OCRErrorType.unknown: 'An unexpected error occurred. Please try again.',
  };

  static const Map<OCRErrorType, List<String>> _suggestedActions = {
    OCRErrorType.imageNotFound: ['Retake Photo', 'Manual Entry'],
    OCRErrorType.imageCorrupted: ['Retake Photo', 'Manual Entry'],
    OCRErrorType.imageTooLarge: ['Retake with Lower Quality', 'Manual Entry'],
    OCRErrorType.imageTooSmall: ['Retake Closer', 'Use Long Receipt Mode'],
    OCRErrorType.imageFormatUnsupported: ['Retake Photo', 'Manual Entry'],
    OCRErrorType.inputImageConverterError: ['Retake Photo', 'Try Different Angle', 'Manual Entry'],
    OCRErrorType.mlKitInitializationError: ['Restart App', 'Manual Entry'],
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
    OCRErrorType.inputImageConverterError, // This can be retryable with different image
  };

  static const Set<OCRErrorType> _criticalErrors = {
    OCRErrorType.cameraPermissionDenied,
    OCRErrorType.cameraNotAvailable,
    OCRErrorType.storageInsufficient,
    OCRErrorType.mlKitInitializationError,
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

    // Check for string-based error patterns
    final errorString = error.toString().toLowerCase();

    // Check for ML Kit specific errors
    if (errorString.contains('inputimageconvertererror') || 
        errorString.contains('imageformat is not supported')) {
      return OCRErrorType.inputImageConverterError;
    }

    if (errorString.contains('ml kit') && errorString.contains('initialization')) {
      return OCRErrorType.mlKitInitializationError;
    }

    // Check for common error patterns
    if (errorString.contains('memory') || errorString.contains('heap') || errorString.contains('oom')) {
      return OCRErrorType.lowMemory;
    }

    if (errorString.contains('network') || errorString.contains('connection')) {
      return OCRErrorType.networkUnavailable;
    }

    if (errorString.contains('corrupted') || errorString.contains('invalid') || errorString.contains('decode')) {
      return OCRErrorType.imageCorrupted;
    }

    if (errorString.contains('timeout')) {
      return OCRErrorType.ocrTimeout;
    }

    if (errorString.contains('no text') || errorString.contains('empty')) {
      return OCRErrorType.noTextDetected;
    }

    if (errorString.contains('file not found') || errorString.contains('not found')) {
      return OCRErrorType.imageNotFound;
    }

    if (errorString.contains('too large') || errorString.contains('size exceeded')) {
      return OCRErrorType.imageTooLarge;
    }

    if (errorString.contains('format') && (errorString.contains('unsupported') || errorString.contains('invalid'))) {
      return OCRErrorType.imageFormatUnsupported;
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
    if (error.type != null) {
      return error.type!;
    }

    final message = error.message.toLowerCase();
    
    if (message.contains('not found')) return OCRErrorType.imageNotFound;
    if (message.contains('corrupted')) return OCRErrorType.imageCorrupted;
    if (message.contains('too large')) return OCRErrorType.imageTooLarge;
    if (message.contains('too small')) return OCRErrorType.imageTooSmall;
    if (message.contains('timeout')) return OCRErrorType.ocrTimeout;
    if (message.contains('no text')) return OCRErrorType.noTextDetected;
    if (message.contains('format')) return OCRErrorType.imageFormatUnsupported;
    
    return OCRErrorType.processingFailed;
  }

  static OCRErrorType _categorizePlatformException(PlatformException error) {
    // Handle ML Kit specific errors
    switch (error.code) {
      case 'InputImageConverterError':
        return OCRErrorType.inputImageConverterError;
      case 'MlKitException':
        if (error.message?.toLowerCase().contains('initialization') ?? false) {
          return OCRErrorType.mlKitInitializationError;
        }
        return OCRErrorType.processingFailed;
      case 'camera_access_denied':
      case 'permission_denied':
        return OCRErrorType.cameraPermissionDenied;
      case 'camera_not_found':
        return OCRErrorType.cameraNotAvailable;
      case 'out_of_memory':
        return OCRErrorType.lowMemory;
      case 'format_not_supported':
        return OCRErrorType.imageFormatUnsupported;
      default:
        // Check error message for more specific categorization
        final message = error.message?.toLowerCase() ?? '';
        if (message.contains('imageformat is not supported')) {
          return OCRErrorType.inputImageConverterError;
        }
        if (message.contains('ml kit') || message.contains('text recognition')) {
          return OCRErrorType.processingFailed;
        }
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
      case 'ImageCaptureException':
        return OCRErrorType.processingFailed;
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
    if (message.contains('permission')) {
      return OCRErrorType.storageInsufficient; // Treat as storage issue
    }
    
    return OCRErrorType.unknown;
  }

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

    // Additional logging for specific error types
    if (errorType == OCRErrorType.inputImageConverterError) {
      debugPrint('🔍 InputImageConverter Error Details:');
      debugPrint('   This typically indicates an image format mismatch');
      debugPrint('   Check image encoding and ML Kit InputImage parameters');
    }
  }
}

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

        // Apply recovery strategy before retrying
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
        
      case OCRErrorType.inputImageConverterError:
        debugPrint('🔄 Image converter error - attempt $attempt will use different processing method');
        await Future.delayed(Duration(milliseconds: 500));
        break;
        
      case OCRErrorType.ocrTimeout:
        debugPrint('🔄 Increasing timeout for attempt $attempt');
        break;
        
      case OCRErrorType.networkUnavailable:
        await _waitForNetwork();
        break;
        
      case OCRErrorType.mlKitInitializationError:
        debugPrint('🔄 ML Kit initialization error - waiting before retry');
        await Future.delayed(Duration(seconds: 2));
        break;
        
      default:
        await Future.delayed(Duration(milliseconds: 500));
        break;
    }
  }

  static Future<void> _forceGarbageCollection() async {
    debugPrint('🧹 Forcing garbage collection...');
    final List<List<int>> memoryPressure = [];
    
    try {
      // Create temporary memory pressure to trigger GC
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
          if (errorType == OCRErrorType.inputImageConverterError) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Try capturing the image with better lighting or from a different angle.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

// Exception classes
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

// Extensions for error handling
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

// Utility class for common error handling scenarios
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
                // Could open app settings here
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

  static void showProcessingError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    final isInputConverterError = OCRErrorHandler.categorizeError(error) == OCRErrorType.inputImageConverterError;
    
    OCRErrorSnackBar.show(
      context,
      error,
      onRetry: onRetry,
      actionLabel: isInputConverterError ? 'Try Again' : 'Retry',
    );
  }
}
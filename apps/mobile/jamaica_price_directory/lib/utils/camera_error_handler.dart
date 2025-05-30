import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'dart:async';

class CameraErrorHandler {
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  /// Handle camera errors with automatic recovery
  static Future<T?> handleCameraOperation<T>(
    Future<T> Function() operation, {
    int retryCount = 0,
    Function(String)? onError,
  }) async {
    try {
      return await operation();
    } catch (e) {
      final errorMessage = _getCameraErrorMessage(e);
      debugPrint('Camera operation failed: $errorMessage');
      
      if (onError != null) {
        onError(errorMessage);
      }

      // Retry logic for recoverable errors
      if (retryCount < maxRetryAttempts && _isRecoverableError(e)) {
        debugPrint('Retrying camera operation... Attempt ${retryCount + 1}');
        await Future.delayed(retryDelay);
        return handleCameraOperation(
          operation,
          retryCount: retryCount + 1,
          onError: onError,
        );
      }

      return null;
    }
  }

  /// Safely dispose camera controller
  static Future<void> safeDispose(CameraController? controller) async {
    if (controller == null) return;

    try {
      if (controller.value.isInitialized) {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing camera controller: $e');
    }
  }

  /// Check if the error is recoverable
  static bool _isRecoverableError(dynamic error) {
    // Timeout errors are recoverable
    if (error is TimeoutException) return true;
    
    if (error is CameraException) {
      switch (error.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'CameraAccessRestricted':
          return false; // Permission errors are not recoverable
        case 'CameraAccessFailed':
        case 'AudioAccessDenied':
        case 'AudioAccessRestricted':
          return true; // These might be temporary
        default:
          return true; // Other errors might be recoverable
      }
    }
    return true; // Unknown errors might be recoverable
  }

  /// Get user-friendly error message
  static String _getCameraErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'Camera initialization timed out. Please try again.';
    }
    
    if (error is CameraException) {
      switch (error.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'CameraAccessRestricted':
          return 'Camera access denied. Please grant camera permission in settings.';
        case 'CameraAccessFailed':
          return 'Failed to access camera. Please try again.';
        case 'AudioAccessDenied':
        case 'AudioAccessRestricted':
          return 'Audio access denied. Camera will work without audio.';
        case 'CameraNotFound':
          return 'No camera found on this device.';
        case 'CameraNotInitialized':
          return 'Camera not initialized. Please try again.';
        case 'ImageCaptureException':
          return 'Failed to capture image. Please try again.';
        default:
          return 'Camera error: ${error.description ?? error.code}';
      }
    }
    return 'Unexpected camera error: $error';
  }

  /// Check camera availability
  static Future<bool> isCameraAvailable() async {
    try {
      final cameras = await availableCameras();
      return cameras.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking camera availability: $e');
      return false;
    }
  }

  /// Get optimal camera resolution based on device capabilities
  static ResolutionPreset getOptimalResolution() {
    // Use medium resolution for debug builds to reduce buffer issues
    if (kDebugMode) {
      return ResolutionPreset.medium;
    }
    return ResolutionPreset.high;
  }

  /// Configure camera with optimal settings
  static CameraController createOptimizedController(
    CameraDescription camera,
  ) {
    return CameraController(
      camera,
      getOptimalResolution(),
      enableAudio: false, // Disable audio to reduce resource usage
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
  }
}
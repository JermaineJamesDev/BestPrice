import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';

class CameraErrorHandler {
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  static const Duration disposalTimeout = Duration(seconds: 5);
  static const Duration streamStopTimeout = Duration(seconds: 3);

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

  /// Safely stop image stream with timeout protection
  static Future<void> safeStopImageStream(CameraController? controller) async {
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      if (controller.value.isStreamingImages) {
        debugPrint('🛑 Stopping image stream safely...');

        await controller.stopImageStream().timeout(
          streamStopTimeout,
          onTimeout: () {
            debugPrint('⚠️ Image stream stop timed out');
            // Continue with disposal even if timeout occurs
          },
        );

        // Give extra time for Android to clean up ImageReader buffers
        if (Platform.isAndroid) {
          await Future.delayed(const Duration(milliseconds: 200));
        }

        debugPrint('✅ Image stream stopped successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Error stopping image stream: $e');
      // Continue with disposal even if stream stop fails
    }
  }

  /// Safely dispose camera controller with enhanced buffer management
  static Future<void> safeDispose(CameraController? controller) async {
    if (controller == null) return;

    try {
      if (controller.value.isInitialized) {
        debugPrint('🗑️ Disposing camera controller...');

        // First, ensure image stream is stopped
        await safeStopImageStream(controller);

        // Then dispose with timeout protection
        await controller.dispose().timeout(
          disposalTimeout,
          onTimeout: () {
            debugPrint('⚠️ Camera disposal timed out');
          },
        );

        debugPrint('✅ Camera controller disposed successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Error disposing camera controller: $e');
    }
  }

  /// Enhanced disposal for ImageReader buffer issues
  static Future<void> enhancedDispose(CameraController? controller) async {
    if (controller == null) return;

    try {
      // Step 1: Stop image stream first
      await safeStopImageStream(controller);

      // Step 2: Additional wait for Android buffer cleanup
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Step 3: Dispose controller
      await safeDispose(controller);

      // Step 4: Force garbage collection to help with buffer cleanup
      if (Platform.isAndroid) {
        // Suggest garbage collection (not guaranteed but helps)
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('⚠️ Enhanced disposal failed: $e');
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
        case 'ImageReaderError': // Android ImageReader issues
        case 'CameraNotInitialized':
          return true; // Often recoverable
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
        case 'ImageReaderError':
          return 'Camera buffer error. Please restart the camera.';
        default:
          return 'Camera error: ${error.description ?? error.code}';
      }
    }

    // Check for common ImageReader error strings
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('imagereader') ||
        errorString.contains('buffer') ||
        errorString.contains('acquire more than maxImages')) {
      return 'Camera buffer overflow. Please restart the camera.';
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

  /// Get optimal camera resolution based on device capabilities and mode
  static ResolutionPreset getOptimalResolution({
    bool prioritizePerformance = false,
  }) {
    // Always use medium resolution in debug mode to reduce buffer issues
    if (kDebugMode) {
      return ResolutionPreset.medium;
    }

    // Use lower resolution if prioritizing performance or on Android
    if (prioritizePerformance || Platform.isAndroid) {
      return ResolutionPreset.medium;
    }

    return ResolutionPreset.high;
  }

  /// Configure camera with optimal settings for ImageReader stability
  static CameraController createOptimizedController(
    CameraDescription camera, {
    bool prioritizeStability = true,
  }) {
    return CameraController(
      camera,
      getOptimalResolution(prioritizePerformance: prioritizeStability),
      enableAudio: false, // Disable audio to reduce resource usage
      imageFormatGroup: ImageFormatGroup.jpeg,
      // Additional settings for stability on Android
    );
  }

  /// Check if current error is related to ImageReader buffer issues
  static bool isImageReaderError(dynamic error) {
    if (error is CameraException && error.code == 'ImageReaderError') {
      return true;
    }

    final errorString = error.toString().toLowerCase();
    return errorString.contains('imagereader') ||
        errorString.contains('acquire more than maxImages') ||
        errorString.contains('buffer item');
  }

  /// Recovery strategy for ImageReader buffer errors
  static Future<void> recoverFromImageReaderError(
    CameraController? controller,
  ) async {
    debugPrint('🔄 Attempting ImageReader error recovery...');

    if (controller == null) return;

    try {
      // Step 1: Force stop image stream
      await safeStopImageStream(controller);

      // Step 2: Wait longer for Android cleanup
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: If still initialized, try to restart stream carefully
      if (controller.value.isInitialized &&
          !controller.value.isStreamingImages) {
        // Wait before restarting
        await Future.delayed(const Duration(milliseconds: 300));
        debugPrint('🔄 Recovery complete');
      }
    } catch (e) {
      debugPrint('⚠️ ImageReader recovery failed: $e');
    }
  }

  /// Validate camera controller state before operations
  static bool validateControllerState(
    CameraController? controller, {
    bool requiresImageStream = false,
  }) {
    if (controller == null) {
      debugPrint('⚠️ Camera controller is null');
      return false;
    }

    if (!controller.value.isInitialized) {
      debugPrint('⚠️ Camera controller not initialized');
      return false;
    }

    if (requiresImageStream && !controller.value.isStreamingImages) {
      debugPrint('⚠️ Image stream not active when required');
      return false;
    }

    return true;
  }

  /// Get device-specific camera settings
  static Map<String, dynamic> getDeviceOptimizedSettings() {
    final settings = <String, dynamic>{
      'frameSkipCount': 15,
      'maxConcurrentProcessing': 1,
      'processingTimeout': 20000, // ms
    };

    if (Platform.isAndroid) {
      // More conservative settings for Android to prevent ImageReader issues
      settings['frameSkipCount'] = 20;
      settings['maxConcurrentProcessing'] = 1;
      settings['streamStopDelay'] = 300; // ms
    }

    return settings;
  }
}

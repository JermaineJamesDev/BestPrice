import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:jamaica_price_directory/screens/enhanced_photo_preview_screen.dart';
import '../utils/camera_error_handler.dart';
import '../services/ocr_error_handler.dart';
import '../services/consolidated_ocr_service.dart';

class LongReceiptCaptureScreen extends StatefulWidget {
  const LongReceiptCaptureScreen({super.key});

  @override
  _LongReceiptCaptureScreenState createState() =>
      _LongReceiptCaptureScreenState();
}

class _LongReceiptCaptureScreenState extends State<LongReceiptCaptureScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isCapturing = false;
  bool _isDisposed = false;

  String? _errorMessage;
  OCRErrorType? _currentErrorType;
  CancellationToken? _currentCancellationToken;

  /// Holds filepaths (or URIs) of each captured section
  final List<String> _capturedSections = [];
  int _currentSection = 1;

  late AnimationController _errorAnimationController;
  late Animation<double> _errorFadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupErrorAnimation();
    _initializeWithErrorHandling();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _currentCancellationToken?.cancel();

    // Stop image stream (if any) and dispose controller
    _disposeCamera();
    _errorAnimationController.dispose();
    super.dispose();
  }

  void _setupErrorAnimation() {
    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _errorFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _errorAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _disposeCamera();
        break;
      case AppLifecycleState.resumed:
        if (!_isLoading && !_isCameraInitialized) {
          _initializeWithErrorHandling();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _initializeWithErrorHandling() async {
    await OCRErrorRecovery.executeWithRecovery(
      () => _initializeCamera(),
      'long_receipt_camera_init',
      context: OCRErrorContext(
        operation: 'long_receipt_camera_initialization',
        metadata: {'screen': 'long_receipt_capture'},
      ),
      onError: (error, attempt) {
        debugPrint('LongReceipt init error (attempt $attempt): $error');
        _handleCameraError(error);
      },
      onRetry: (attempt) {
        debugPrint('Retrying LongReceipt camera init (attempt $attempt)');
      },
      onSuccess: (_) {
        _clearError();
      },
    );
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentErrorType = null;
    });

    try {
      // 1. Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw OCRException(
          'Camera permission denied',
          type: OCRErrorType.cameraPermissionDenied,
        );
      }
      _hasPermission = true;

      // 2. Check availability and list cameras
      if (!await CameraErrorHandler.isCameraAvailable()) {
        throw OCRException(
          'No cameras available',
          type: OCRErrorType.cameraNotAvailable,
        );
      }
      _cameras = await CameraErrorHandler.handleCameraOperation<List<CameraDescription>>(
            () => availableCameras(),
            onError: (error) {
              throw OCRException(
                'Failed to list cameras: $error',
                type: OCRErrorType.cameraInitializationFailed,
              );
            },
          ) ??
          [];

      if (_cameras.isEmpty) {
        throw OCRException(
          'No cameras found',
          type: OCRErrorType.cameraNotAvailable,
        );
      }

      // 3. Dispose any existing controller, then create a new one
      await _disposeCamera();
      if (_isDisposed) return;

      _cameraController = CameraErrorHandler.createOptimizedController(
        _cameras.first,
      );
      await _cameraController!.initialize();

      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
        _handleCameraError(e);
      }
      rethrow;
    }
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      try {
        await CameraErrorHandler.safeDispose(_cameraController);
      } catch (_) {
        // ignore
      }
      _cameraController = null;
    }
    if (mounted && !_isDisposed) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  void _handleCameraError(dynamic error) {
    final errorType = OCRErrorHandler.categorizeError(
      error,
      context: OCRErrorContext(
        operation: 'camera_operation',
        metadata: {'screen': 'long_receipt_capture'},
      ),
    );
    final errorMessage = OCRErrorHandler.getErrorMessage(
      error,
      context: OCRErrorContext(
        operation: 'camera_operation',
        metadata: {'screen': 'long_receipt_capture'},
      ),
    );

    setState(() {
      _errorMessage = errorMessage;
      _currentErrorType = errorType;
    });
    _errorAnimationController.forward();
  }

  void _clearError() {
    setState(() {
      _errorMessage = null;
      _currentErrorType = null;
    });
    _errorAnimationController.reverse();
  }

  Future<void> _captureSection() async {
    if (!_isCameraInitialized ||
        _isCapturing ||
        _cameraController == null ||
        _isDisposed) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });
    _currentCancellationToken = CancellationToken();

    try {
      final picture = await OCRErrorRecovery.executeWithRecovery(
        () => _cameraController!.takePicture(),
        'long_receipt_capture_photo',
        context: OCRErrorContext(
          operation: 'capture_section',
          metadata: {
            'section': _currentSection,
          },
        ),
        onError: (error, attempt) {
          debugPrint('Capture error (attempt $attempt): $error');
          OCRErrorSnackBar.show(
            context,
            error,
            errorContext: OCRErrorContext(
              operation: 'capture_section',
              metadata: {'attempt': attempt},
            ),
          );
        },
      );

      if (picture != null && mounted && !_isDisposed) {
        // Push to preview screen for confirmation
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (ctx) => EnhancedPhotoPreviewScreen(
              imagePath: picture.path,
              performanceMetrics: null,
              cancellationToken: _currentCancellationToken,
            ),
          ),
        );

        if (result == true) {
          // User confirmed; store the path and move to next section
          _capturedSections.add(picture.path);
          setState(() {
            _currentSection = _capturedSections.length + 1;
          });
          // Optionally: Immediately reopen camera if needed
        }
      }
    } catch (e) {
      _handleCameraError(e);
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _processAllSections() async {
    if (_capturedSections.length < 2) return;
    // Combine all captured section images into one long receipt OCR pass
    try {
      // Example: pass list of file paths to OCR service
      await ConsolidatedOCRService.instance.processLongReceipt(_capturedSections);
      // On success, pop back or show results
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error processing all sections: $e');
      OCRErrorSnackBar.show(
        context,
        e,
        errorContext: OCRErrorContext(
          operation: 'process_all_sections',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Long Receipt – Section $_currentSection'),
        actions: [
          if (_capturedSections.isNotEmpty)
            TextButton(
              onPressed: _capturedSections.length >= 2
                  ? _processAllSections
                  : null,
              child: Text(
                'Process (${_capturedSections.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _isCameraInitialized ? _buildCameraView() : _buildLoadingView(),
          if (_errorMessage != null) _buildErrorOverlay(),
        ],
      ),
      bottomNavigationBar:
          _isCameraInitialized && !_isCapturing ? _buildControls() : null,
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 12),
          const Text(
            'Initializing camera...',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _initializeWithErrorHandling,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return AnimatedBuilder(
      animation: _errorFadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _errorFadeAnimation.value,
          child: Container(
            width: double.infinity,
            color: Colors.red.withOpacity(0.9),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage ?? 'Unknown error',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearError,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                          ),
                          child: const Text(
                            'Dismiss',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _clearError();
                            _initializeWithErrorHandling();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraView() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    return CameraPreview(_cameraController!);
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: _isCapturing ? null : _captureSection,
              iconSize: 64,
              icon: Icon(
                Icons.camera,
                color: _isCapturing ? Colors.grey : Colors.white,
              ),
            ),
            Text(
              'Section $_currentSection',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height * 0.9,
    );

    const cornerLength = 30.0;

    // Draw corner brackets
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );

    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );

    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );

    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

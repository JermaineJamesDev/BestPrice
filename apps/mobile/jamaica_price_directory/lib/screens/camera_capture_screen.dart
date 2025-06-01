import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:jamaica_price_directory/screens/enhanced_photo_preview_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import '../services/consolidated_ocr_service.dart';
import '../utils/camera_error_handler.dart';
import '../services/ocr_error_handler.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  _CameraCaptureScreenState createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  bool _hasPermission = false;
  int _selectedCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  bool _isDisposed = false;
  String? _errorMessage;
  OCRErrorType? _currentErrorType;
  CancellationToken? _currentCancellationToken;
  SystemPerformanceMetrics? _currentMetrics;

  final bool _isPerformanceMonitoringEnabled = true;
  late AnimationController _errorAnimationController;
  late AnimationController _performanceIndicatorController;
  late Animation<double> _errorFadeAnimation;
  late Animation<double> _performanceScaleAnimation;

  bool _isProcessingFrame = false;
  int _frameSkipCount = 0;
  static const int _skipFrames = 10; // Process every 10th frame
  StreamSubscription<CameraImage>? _imageStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _initializeWithErrorHandling();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _currentCancellationToken?.cancel();
    _stopImageStream().then((_) {
      _disposeCamera();
    });
    _errorAnimationController.dispose();
    _performanceIndicatorController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _errorAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _performanceIndicatorController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _errorFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _errorAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _performanceScaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _performanceIndicatorController,
        curve: Curves.elasticInOut,
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
      'camera_initialization',
      context: OCRErrorContext(
        operation: 'camera_initialization',
        metadata: {'screen': 'camera_capture'},
      ),
      onError: (error, attempt) {
        debugPrint('Camera initialization error (attempt $attempt): $error');
        _handleCameraError(error);
      },
      onRetry: (attempt) {
        debugPrint('Retrying camera initialization (attempt $attempt)');
        _showRetryIndicator();
      },
      onSuccess: (result) {
        _clearError();
        _updatePerformanceMetrics();
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
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission.isDenied) {
        throw OCRException(
          'Camera permission denied',
          type: OCRErrorType.cameraPermissionDenied,
        );
      }

      setState(() {
        _hasPermission = true;
      });

      if (!await CameraErrorHandler.isCameraAvailable()) {
        throw OCRException(
          'No cameras available',
          type: OCRErrorType.cameraNotAvailable,
        );
      }

      _cameras =
          await CameraErrorHandler.handleCameraOperation<
            List<CameraDescription>
          >(
            () => availableCameras(),
            onError: (error) {
              throw OCRException(
                'Failed to get cameras: $error',
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

      await _disposeCamera();
      if (_isDisposed) return;

      _cameraController = CameraErrorHandler.createOptimizedController(
        _cameras[_selectedCameraIndex],
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);

      await _startImageStream();

      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraInitialized = true;
          _isLoading = false;
        });
      }

      await _updatePerformanceMetrics();
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
    await _stopImageStream();
    if (_cameraController != null) {
      await CameraErrorHandler.safeDispose(_cameraController);
      _cameraController = null;
      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _startImageStream() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.startImageStream((CameraImage image) async {
        if (_isProcessingFrame) return; // Skip if still processing

        _frameSkipCount++;
        if (_frameSkipCount % _skipFrames != 0) {
          return; // Skip this frame
        }

        _isProcessingFrame = true;
        try {
          // Process the image here if needed
          // For now, just release it immediately
        } finally {
          _isProcessingFrame = false;
        }
      });
    } catch (e) {
      debugPrint('Error starting image stream: $e');
    }
  }

  Future<void> _stopImageStream() async {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint('Error stopping image stream: $e');
      }
    }
  }

  void _handleCameraError(dynamic error) {
    final errorType = OCRErrorHandler.categorizeError(
      error,
      context: OCRErrorContext(
        operation: 'camera_operation',
        metadata: {'screen': 'camera_capture'},
      ),
    );

    final errorMessage = OCRErrorHandler.getErrorMessage(
      error,
      context: OCRErrorContext(
        operation: 'camera_operation',
        metadata: {'screen': 'camera_capture'},
      ),
    );

    setState(() {
      _errorMessage = errorMessage;
      _currentErrorType = errorType;
    });

    _errorAnimationController.forward();

    if (OCRErrorHandler.isCritical(error)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCriticalErrorDialog(error);
      });
    }
  }

  void _clearError() {
    setState(() {
      _errorMessage = null;
      _currentErrorType = null;
    });
    _errorAnimationController.reverse();
  }

  void _showRetryIndicator() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Retrying camera initialization...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCriticalErrorDialog(dynamic error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OCRErrorDialog(
        error: error,
        context: OCRErrorContext(
          operation: 'camera_initialization',
          metadata: {'screen': 'camera_capture'},
        ),
        onRetry: () {
          Navigator.pop(ctx);
          _initializeWithErrorHandling();
        },
        onManualEntry: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(context, '/manual_entry');
        },
        onDismiss: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized ||
        _isCapturing ||
        _cameraController == null ||
        _isDisposed ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    _currentCancellationToken = CancellationToken();

    try {
      await _updatePerformanceMetrics();

      final image = await OCRErrorRecovery.executeWithRecovery(
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return _cameraController!.takePicture();
        },
        'photo_capture',
        context: OCRErrorContext(
          operation: 'photo_capture',
          metadata: {
            'screen': 'camera_capture',
            'camera_index': _selectedCameraIndex,
            'flash_on': _isFlashOn,
          },
        ),
        onError: (error, attempt) {
          debugPrint('Photo capture error (attempt $attempt): $error');
          OCRErrorSnackBar.show(
            context,
            error,
            errorContext: OCRErrorContext(
              operation: 'photo_capture',
              metadata: {'attempt': attempt},
            ),
          );
        },
        onRetry: (attempt) {
          debugPrint('Retrying photo capture (attempt $attempt)');
        },
      );

      if (mounted && !_isDisposed && image != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedPhotoPreviewScreen(
              imagePath: image.path,
              performanceMetrics: _currentMetrics,
              cancellationToken: _currentCancellationToken,
            ),
          ),
        );

        if (mounted && !_isDisposed) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (!_isCameraInitialized && !_isLoading) {
            _initializeWithErrorHandling();
          }
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

  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized || _cameraController == null || _isDisposed) {
      return;
    }

    await OCRErrorRecovery.executeWithRecovery(
      () async {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
        await _cameraController!.setFlashMode(
          _isFlashOn ? FlashMode.torch : FlashMode.off,
        );
      },
      'flash_toggle',
      onError: (error, attempt) {
        debugPrint('Flash toggle error: $error');
        if (mounted && !_isDisposed) {
          setState(() {
            _isFlashOn = !_isFlashOn;
          });
        }
      },
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isDisposed) return;

    setState(() {
      _isLoading = true;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    await OCRErrorRecovery.executeWithRecovery(
      () async {
        await _disposeCamera();
        _cameraController = CameraErrorHandler.createOptimizedController(
          _cameras[_selectedCameraIndex],
        );
        await _cameraController!.initialize();
        await _cameraController!.setFlashMode(FlashMode.off);
      },
      'camera_switch',
      onError: (error, attempt) {
        debugPrint('Camera switch error: $error');
        _handleCameraError(error);
      },
      onSuccess: (result) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isCameraInitialized = true;
            _isLoading = false;
            _isFlashOn = false;
          });
        }
      },
    );
  }

  Future<void> _updatePerformanceMetrics() async {
    if (!_isPerformanceMonitoringEnabled) return;

    try {
      _currentMetrics = await ConsolidatedOCRService.instance
          .getSystemMetrics();
    } catch (e) {
      debugPrint('Failed to update performance metrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Enhanced Camera'),
        actions: [
          if (_isPerformanceMonitoringEnabled && _currentMetrics != null)
            _buildPerformanceIndicator(),
          if (_isCameraInitialized && !_isCapturing)
            IconButton(
              onPressed: _toggleFlash,
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            ),
          if (_cameras.length > 1 && _isCameraInitialized && !_isCapturing)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.flip_camera_ios),
            ),
          if (_errorMessage != null || _isLoading)
            IconButton(
              onPressed: () async {
                await _disposeCamera();
                await Future.delayed(const Duration(milliseconds: 300));
                _initializeWithErrorHandling();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry Camera',
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_errorMessage != null) _buildErrorOverlay(),
        ],
      ),
      bottomNavigationBar: _isCameraInitialized && !_isCapturing
          ? _buildCameraControls()
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null && _currentErrorType != null) {
      if (OCRErrorHandler.isCritical(_currentErrorType)) {
        return _buildCriticalErrorState();
      }
    }

    if (!_hasPermission) {
      return _buildPermissionState();
    }

    if (_isCameraInitialized) {
      return _buildCameraPreview();
    }

    return _buildLoadingState();
  }

  Widget _buildPerformanceIndicator() {
    if (_currentMetrics == null) return SizedBox.shrink();

    final metrics = _currentMetrics!;
    Color indicatorColor;

    if (metrics.memoryUsageMB > 400 || metrics.cpuUsagePercent > 80) {
      indicatorColor = Colors.red;
    } else if (metrics.memoryUsageMB > 200 || metrics.cpuUsagePercent > 60) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.green;
    }

    return AnimatedBuilder(
      animation: _performanceScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _performanceScaleAnimation.value,
          child: Container(
            width: 12,
            height: 12,
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
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
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearError,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white),
                          ),
                          child: Text(
                            'Dismiss',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
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
                          child: Text('Retry'),
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Initializing enhanced camera...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          if (_currentMetrics != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'System Performance',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Memory: ${_currentMetrics!.memoryUsageMB.toStringAsFixed(0)}MB',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'CPU: ${_currentMetrics!.cpuUsagePercent.toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriticalErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Critical Camera Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/manual_entry'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text(
                      'Manual Entry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _initializeWithErrorHandling,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 80, color: Colors.white70),
            const SizedBox(height: 16),
            const Text(
              'Camera Permission Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'To capture receipt images, please allow camera access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final permission = await Permission.camera.request();
                if (permission.isGranted) {
                  _initializeWithErrorHandling();
                } else if (permission.isPermanentlyDenied) {
                  openAppSettings();
                }
              },
              child: const Text('Allow Camera Access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_cameraController!)),
        _buildCameraOverlay(),
        if (_isCapturing)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Capturing with performance optimization...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCameraOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: CameraOverlayPainter(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const Text(
                      'Position receipt within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_currentMetrics != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'Performance: ${_getPerformanceStatus()}',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: const SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TipWidget(Icons.wb_sunny, 'Good lighting'),
                    _TipWidget(Icons.straighten, 'Keep steady'),
                    _TipWidget(Icons.crop_free, 'Fill frame'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPerformanceStatus() {
    if (_currentMetrics == null) return 'Unknown';

    final metrics = _currentMetrics!;
    if (metrics.memoryUsageMB > 400 || metrics.cpuUsagePercent > 80) {
      return 'Limited';
    } else if (metrics.memoryUsageMB > 200 || metrics.cpuUsagePercent > 60) {
      return 'Good';
    } else {
      return 'Optimal';
    }
  }

  Widget _buildCameraControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gallery picker coming soon!')),
                );
              },
              icon: const Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 32,
              ),
            ),
            GestureDetector(
              onTap: _isCapturing ? null : _capturePhoto,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing ? Colors.red : Colors.white,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/manual_entry');
              },
              icon: const Icon(Icons.edit, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// Supporting Widgets
class _TipWidget extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipWidget(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

class CameraOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final frameWidth = size.width * 0.8;
    final frameHeight = frameWidth * 1.5;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;

    const cornerLength = 30.0;

    // Draw corner brackets
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);

    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top),
      Offset(left + frameWidth, top),
      paint,
    );
    canvas.drawLine(
      Offset(left + frameWidth, top),
      Offset(left + frameWidth, top + cornerLength),
      paint,
    );

    canvas.drawLine(
      Offset(left, top + frameHeight - cornerLength),
      Offset(left, top + frameHeight),
      paint,
    );
    canvas.drawLine(
      Offset(left, top + frameHeight),
      Offset(left + cornerLength, top + frameHeight),
      paint,
    );

    canvas.drawLine(
      Offset(left + frameWidth - cornerLength, top + frameHeight),
      Offset(left + frameWidth, top + frameHeight),
      paint,
    );
    canvas.drawLine(
      Offset(left + frameWidth, top + frameHeight),
      Offset(left + frameWidth, top + frameHeight - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

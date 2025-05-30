import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'long_receipt_capture_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../utils/camera_error_handler.dart';
import 'photo_preview_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  _CameraCaptureScreenState createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _errorMessage;
  int _selectedCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _disposeCamera();
        break;
      case AppLifecycleState.resumed:
        // Always reinitialize camera when app resumes
        if (!_isDisposed) {
          _initializeCamera();
        }
        break;
      default:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reinitialize camera when navigating back to this screen
    if (!_isCameraInitialized && !_isLoading && !_isDisposed) {
      _initializeCamera();
    }
  }

  Future<void> _disposeCamera() async {
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

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Add timeout to prevent infinite loading
      await Future.any([
        _performCameraInitialization(),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException('Camera initialization timed out');
        }),
      ]);
    } catch (e) {
      debugPrint('Camera initialization timeout or error: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage = 'Camera initialization failed. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performCameraInitialization() async {
    // Check camera permission
    final cameraPermission = await Permission.camera.request();
    if (cameraPermission.isDenied) {
      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage = 'Camera permission is required to take photos';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _hasPermission = true;
      });
    }

    // Check camera availability using error handler
    final isAvailable = await CameraErrorHandler.isCameraAvailable();
    if (!isAvailable) {
      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage = 'No cameras found on this device';
          _isLoading = false;
        });
      }
      return;
    }

    // Get cameras with error handling
    final cameras = await CameraErrorHandler.handleCameraOperation<List<CameraDescription>>(
      () => availableCameras(),
      onError: (error) {
        debugPrint('Failed to get cameras: $error');
      },
    );

    if (cameras == null || cameras.isEmpty) {
      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage = 'No cameras found on this device';
          _isLoading = false;
        });
      }
      return;
    }

    _cameras = cameras;

    // Dispose existing controller if any
    await _disposeCamera();

    if (_isDisposed) return;

    // Initialize camera with error handling
    final controller = await CameraErrorHandler.handleCameraOperation<CameraController>(
      () async {
        final controller = CameraErrorHandler.createOptimizedController(_cameras[_selectedCameraIndex]);
        await controller.initialize();
        await controller.setFlashMode(FlashMode.off);
        return controller;
      },
      onError: (error) {
        if (mounted && !_isDisposed) {
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        }
      },
    );

    if (controller != null && !_isDisposed) {
      _cameraController = controller;
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isLoading = false;
        });
      }
    }
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

    // Capture photo with error handling
    final image = await CameraErrorHandler.handleCameraOperation<XFile>(
      () async {
        // Add a small delay to ensure camera is ready
        await Future.delayed(const Duration(milliseconds: 100));
        return _cameraController!.takePicture();
      },
      onError: (error) {
        debugPrint('Failed to capture photo: $error');
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to capture photo: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    if (mounted && !_isDisposed) {
      setState(() {
        _isCapturing = false;
      });

      if (image != null) {
        // Navigate to preview screen and handle return
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(imagePath: image.path),
          ),
        );
        
        // When user comes back from preview, reinitialize camera
        if (mounted && !_isDisposed) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (!_isCameraInitialized && !_isLoading) {
            _initializeCamera();
          }
        }
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized || _cameraController == null || _isDisposed) return;

    final success = await CameraErrorHandler.handleCameraOperation<bool>(
      () async {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
        await _cameraController!.setFlashMode(
          _isFlashOn ? FlashMode.torch : FlashMode.off,
        );
        return true;
      },
      onError: (error) {
        debugPrint('Failed to toggle flash: $error');
        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to toggle flash')),
          );
        }
      },
    );

    if (success == null && mounted && !_isDisposed) {
      // Revert flash state if operation failed
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isDisposed) return;

    setState(() {
      _isLoading = true;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    await _disposeCamera();
    
    if (_isDisposed) return;

    // Switch camera with error handling
    final controller = await CameraErrorHandler.handleCameraOperation<CameraController>(
      () async {
        final controller = CameraErrorHandler.createOptimizedController(_cameras[_selectedCameraIndex]);
        await controller.initialize();
        await controller.setFlashMode(FlashMode.off);
        return controller;
      },
      onError: (error) {
        debugPrint('Failed to switch camera: $error');
        if (mounted && !_isDisposed) {
          setState(() {
            _errorMessage = 'Failed to switch camera';
            _isLoading = false;
          });
        }
      },
    );

    if (controller != null && !_isDisposed) {
      _cameraController = controller;
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isLoading = false;
          _isFlashOn = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    final permission = await Permission.camera.request();
    if (permission.isGranted) {
      _initializeCamera();
    } else if (permission.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Capture Price'),
        actions: [
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
          // Add refresh button for stuck states
          if (_isLoading || _errorMessage != null)
            IconButton(
              onPressed: () async {
                await _disposeCamera();
                await Future.delayed(const Duration(milliseconds: 300));
                _initializeCamera();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry Camera',
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isCameraInitialized && !_isCapturing 
          ? _buildCameraControls() 
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_hasPermission) {
      return _buildPermissionState();
    }

    if (_isCameraInitialized) {
      return _buildCameraPreview();
    }

    return _buildLoadingState();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Initializing camera...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          // Add retry button for stuck initialization
          ElevatedButton(
            onPressed: () async {
              await _disposeCamera();
              await Future.delayed(const Duration(milliseconds: 500));
              _initializeCamera();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            child: const Text('Retry Camera'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Error',
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Retry'),
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
            const Icon(
              Icons.camera_alt,
              size: 80,
              color: Colors.white70,
            ),
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
              'To submit prices by taking photos, please allow camera access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestPermission,
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
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        _buildCameraOverlay(),
        if (_isCapturing)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(),
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
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const SafeArea(
                child: Text(
                  'Position receipt or price tag within the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const SafeArea(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _TipWidget(Icons.wb_sunny, 'Good lighting'),
                        _TipWidget(Icons.straighten, 'Keep steady'),
                        _TipWidget(Icons.crop_free, 'Fill frame'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
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
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Manual entry already available in Camera tab!'),
                  ),
                );
              },
              icon: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 32,
              ),
            ),
            IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LongReceiptCaptureScreen(),
                ),
              );
            },
            icon: Icon(Icons.receipt_long),
            tooltip: 'Long Receipt Mode',
          ),
          ],
        ),
      ),
    );
  }
}

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
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
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
    
    canvas.drawLine(Offset(left + frameWidth - cornerLength, top), 
                   Offset(left + frameWidth, top), paint);
    canvas.drawLine(Offset(left + frameWidth, top), 
                   Offset(left + frameWidth, top + cornerLength), paint);
    
    canvas.drawLine(Offset(left, top + frameHeight - cornerLength), 
                   Offset(left, top + frameHeight), paint);
    canvas.drawLine(Offset(left, top + frameHeight), 
                   Offset(left + cornerLength, top + frameHeight), paint);
    
    canvas.drawLine(Offset(left + frameWidth - cornerLength, top + frameHeight), 
                   Offset(left + frameWidth, top + frameHeight), paint);
    canvas.drawLine(Offset(left + frameWidth, top + frameHeight), 
                   Offset(left + frameWidth, top + frameHeight - cornerLength), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
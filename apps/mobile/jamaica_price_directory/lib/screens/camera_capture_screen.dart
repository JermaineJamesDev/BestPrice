import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'photo_preview_screen.dart';

// Real Camera Implementation - Capture photos for price submission
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  _CameraCaptureScreenState createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  
  // Camera controller and state
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _errorMessage;
  
  // Camera settings
  int _selectedCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }
  
  // Initialize camera with permissions
  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Request camera permission
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission.isDenied) {
        setState(() {
          _errorMessage = 'Camera permission is required to take photos';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _hasPermission = true;
      });
      
      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on this device';
          _isLoading = false;
        });
        return;
      }
      
      // Initialize camera controller
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      
      // Set default flash mode
      await _cameraController!.setFlashMode(FlashMode.auto);
      
      setState(() {
        _isCameraInitialized = true;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // Capture photo
  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized || _isCapturing) return;
    
    try {
      setState(() {
        _isCapturing = true;
      });
      
      // Capture image
      final XFile image = await _cameraController!.takePicture();
      
      // Navigate to preview screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoPreviewScreen(imagePath: image.path),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }
  
  // Toggle flash
  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized) return;
    
    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle flash')),
      );
    }
  }
  
  // Switch camera (front/back)
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    
    try {
      setState(() {
        _isLoading = true;
        _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      });
      
      await _cameraController?.dispose();
      
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.auto);
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to switch camera';
        _isLoading = false;
      });
    }
  }
  
  // Request permission again
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
        title: Text('Capture Price'),
        actions: [
          // Flash toggle
          if (_isCameraInitialized)
            IconButton(
              onPressed: _toggleFlash,
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            ),
          
          // Camera switch
          if (_cameras.length > 1 && _isCameraInitialized)
            IconButton(
              onPressed: _switchCamera,
              icon: Icon(Icons.flip_camera_ios),
            ),
        ],
      ),
      
      body: _buildBody(),
      
      // Camera controls at bottom
      bottomNavigationBar: _isCameraInitialized ? _buildCameraControls() : null,
    );
  }
  
  // Build main body based on state
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
  
  // Loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  // Error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
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
              'Camera Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Permission state
  Widget _buildPermissionState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 80,
              color: Colors.white70,
            ),
            SizedBox(height: 16),
            Text(
              'Camera Permission Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'To submit prices by taking photos, please allow camera access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestPermission,
              child: Text('Allow Camera Access'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Camera preview
  Widget _buildCameraPreview() {
    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        
        // Overlay with capture guidelines
        _buildCameraOverlay(),
        
        // Capture feedback
        if (_isCapturing)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
  
  // Camera overlay with guidelines
  Widget _buildCameraOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: CameraOverlayPainter(),
        child: Column(
          children: [
            // Top instruction
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
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
              child: SafeArea(
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
            
            Spacer(),
            
            // Bottom tips
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
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
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTip(Icons.wb_sunny, 'Good lighting'),
                        _buildTip(Icons.straighten, 'Keep steady'),
                        _buildTip(Icons.crop_free, 'Fill frame'),
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
  
  // Camera tip widget
  Widget _buildTip(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  // Camera controls at bottom
  Widget _buildCameraControls() {
    return Container(
      padding: EdgeInsets.all(20),
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
            // Gallery button
            IconButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Open gallery picker
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gallery picker coming soon!')),
                );
              },
              icon: Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 32,
              ),
            ),
            
            // Capture button
            GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Container(
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing ? Colors.red : Colors.white,
                  ),
                ),
              ),
            ),
            
            // Manual entry button
            IconButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to manual entry
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Manual entry already available in Camera tab!')),
                );
              },
              icon: Icon(
                Icons.edit,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for camera overlay guidelines
class CameraOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    // Calculate frame dimensions (2:3 aspect ratio for receipt)
    final frameWidth = size.width * 0.8;
    final frameHeight = frameWidth * 1.5;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    
    // Draw corner guidelines
    final cornerLength = 30.0;
    
    // Top-left corner
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      paint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      paint,
    );
    
    // Top-right corner
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
    
    // Bottom-left corner
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
    
    // Bottom-right corner
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
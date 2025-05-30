import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'ocr_processing_screen.dart';

// Photo Preview Screen - Review and enhance captured photo before OCR
class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  
  const PhotoPreviewScreen({super.key, required this.imagePath});
  
  @override
  _PhotoPreviewScreenState createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  File? _imageFile;
  img.Image? _processedImage;
  bool _isProcessing = false;
  
  // Image enhancement settings
  double _brightness = 0.0;
  double _contrast = 1.0;
  int _rotation = 0;
  bool _hasChanges = false;
  
  @override
  void initState() {
    super.initState();
    _loadImage();
  }
  
  // Load the captured image
  Future<void> _loadImage() async {
    try {
      _imageFile = File(widget.imagePath);
      final bytes = await _imageFile!.readAsBytes();
      _processedImage = img.decodeImage(bytes);
      setState(() {});
    } catch (e) {
      _showError('Failed to load image: ${e.toString()}');
    }
  }
  
  // Apply image enhancements
  Future<void> _applyEnhancements() async {
    if (_processedImage == null) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      img.Image enhanced = img.copyResize(_processedImage!, 
          maintainAspect: true);
      
      // Apply rotation
      if (_rotation != 0) {
        enhanced = img.copyRotate(enhanced, angle: _rotation.toDouble());
      }
      
      // Apply brightness and contrast
      if (_brightness != 0.0 || _contrast != 1.0) {
        enhanced = img.adjustColor(enhanced, 
            brightness: _brightness, 
            contrast: _contrast);
      }
      
      // Save enhanced image
      final enhancedBytes = img.encodeJpg(enhanced, quality: 90);
      await _imageFile!.writeAsBytes(enhancedBytes);
      
      setState(() {
        _processedImage = enhanced;
        _hasChanges = false;
        _isProcessing = false;
      });
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to enhance image: ${e.toString()}');
    }
  }
  
  // Rotate image
  void _rotateImage() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
      _hasChanges = true;
    });
  }
  
  // Reset all enhancements
  void _resetEnhancements() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
      _rotation = 0;
      _hasChanges = false;
    });
    _loadImage(); // Reload original image
  }
  
  // Proceed to OCR processing
  void _proceedToOCR() async {
    // Apply any pending changes
    if (_hasChanges) {
      await _applyEnhancements();
    }
    
    // Navigate to OCR processing screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OCRProcessingScreen(imagePath: _imageFile!.path),
      ),
    );
  }
  
  // Retake photo
  void _retakePhoto() {
    Navigator.pop(context);
  }
  
  // Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Review Photo'),
        actions: [
          // Reset button
          IconButton(
            onPressed: _hasChanges ? _resetEnhancements : null,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      
      body: _imageFile == null 
          ? _buildLoadingState()
          : _buildPhotoPreview(),
      
      // Bottom controls
      bottomNavigationBar: _imageFile != null ? _buildBottomControls() : null,
    );
  }
  
  // Loading state while image loads
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading image...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  // Photo preview with enhancements
  Widget _buildPhotoPreview() {
    return Column(
      children: [
        // Image display
        Expanded(
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // Main image
                  Center(
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  // Processing overlay
                  if (_isProcessing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Enhancing image...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        
        // Enhancement controls
        _buildEnhancementControls(),
      ],
    );
  }
  
  // Enhancement controls section
  Widget _buildEnhancementControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Quick actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(
                Icons.rotate_right,
                'Rotate',
                _rotateImage,
              ),
              _buildQuickAction(
                Icons.auto_fix_high,
                'Auto Enhance',
                _autoEnhance,
              ),
              _buildQuickAction(
                Icons.crop,
                'Crop',
                _showCropDialog,
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Brightness slider
          _buildSlider(
            'Brightness',
            _brightness,
            -100.0,
            100.0,
            (value) {
              setState(() {
                _brightness = value;
                _hasChanges = true;
              });
            },
          ),
          
          SizedBox(height: 8),
          
          // Contrast slider
          _buildSlider(
            'Contrast',
            _contrast,
            0.5,
            2.0,
            (value) {
              setState(() {
                _contrast = value;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Quick action button
  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  // Slider widget for adjustments
  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 20,
          activeColor: Color(0xFF1E3A8A),
          inactiveColor: Colors.grey[600],
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  // Auto enhance functionality
  void _autoEnhance() {
    setState(() {
      // Apply automatic enhancement values
      _brightness = 10.0; // Slightly brighten
      _contrast = 1.2; // Increase contrast slightly
      _hasChanges = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto enhancement applied'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  // Show crop dialog (placeholder)
  void _showCropDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Crop Image'),
        content: Text('Advanced crop functionality coming soon!\n\nFor now, try to capture the image with good framing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Bottom controls
  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Retake button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retakePhoto,
                icon: Icon(Icons.camera_alt, color: Colors.white),
                label: Text(
                  'Retake',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            SizedBox(width: 16),
            
            // Continue button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _proceedToOCR,
                icon: Icon(Icons.arrow_forward),
                label: Text(
                  _hasChanges ? 'Apply & Continue' : 'Continue',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
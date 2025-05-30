import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'ocr_processing_screen.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  const PhotoPreviewScreen({super.key, required this.imagePath});

  @override
  _PhotoPreviewScreenState createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  File? _imageFile;
  img.Image? _originalImage;
  img.Image? _processedImage;
  bool _isProcessing = false;
  double _brightness = 0.0;
  double _contrast = 1.0;
  int _rotation = 0;
  bool _hasChanges = false;
  String? _errorMessage;

  // Image size constraints
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      _imageFile = File(widget.imagePath);
      
      // Check file size first
      final fileSize = await _imageFile!.length();
      if (fileSize > maxFileSizeBytes) {
        setState(() {
          _errorMessage = 'Image file is too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB). Maximum allowed is ${maxFileSizeBytes ~/ (1024 * 1024)}MB.';
        });
        return;
      }

      final bytes = await _imageFile!.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      
      if (decodedImage == null) {
        setState(() {
          _errorMessage = 'Failed to decode image. The file may be corrupted.';
        });
        return;
      }

      // Resize image if it's too large
      img.Image resizedImage = decodedImage;
      if (decodedImage.width > maxImageWidth || decodedImage.height > maxImageHeight) {
        debugPrint('Resizing image from ${decodedImage.width}x${decodedImage.height}');
        resizedImage = img.copyResize(
          decodedImage,
          width: decodedImage.width > maxImageWidth ? maxImageWidth : null,
          height: decodedImage.height > maxImageHeight ? maxImageHeight : null,
          maintainAspect: true,
        );
        debugPrint('Resized to ${resizedImage.width}x${resizedImage.height}');
        
        // Save the resized image back to file
        final resizedBytes = img.encodeJpg(resizedImage, quality: 85);
        await _imageFile!.writeAsBytes(resizedBytes);
      }

      setState(() {
        _originalImage = resizedImage;
        _processedImage = img.Image.from(resizedImage); // Create a copy
      });
    } catch (e) {
      debugPrint('Error loading image: $e');
      setState(() {
        _errorMessage = 'Failed to load image: ${e.toString()}';
      });
    }
  }

  Future<void> _applyEnhancements() async {
    if (_originalImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Start with a copy of the original image
      img.Image enhanced = img.Image.from(_originalImage!);

      // Apply rotation if needed
      if (_rotation != 0) {
        enhanced = img.copyRotate(enhanced, angle: _rotation.toDouble());
      }

      // Apply brightness and contrast if needed
      if (_brightness != 0.0 || _contrast != 1.0) {
        enhanced = img.adjustColor(
          enhanced, 
          brightness: _brightness, 
          contrast: _contrast,
        );
      }

      // Ensure the enhanced image isn't too large
      if (enhanced.width > maxImageWidth || enhanced.height > maxImageHeight) {
        enhanced = img.copyResize(
          enhanced,
          width: enhanced.width > maxImageWidth ? maxImageWidth : null,
          height: enhanced.height > maxImageHeight ? maxImageHeight : null,
          maintainAspect: true,
        );
      }

      // Save the enhanced image
      final enhancedBytes = img.encodeJpg(enhanced, quality: 85);
      await _imageFile!.writeAsBytes(enhancedBytes);

      setState(() {
        _processedImage = enhanced;
        _hasChanges = false;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('Error enhancing image: $e');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to enhance image: ${e.toString()}';
      });
    }
  }

  void _rotateImage() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
      _hasChanges = true;
    });
  }

  void _resetEnhancements() {
    setState(() {
      _brightness = 0.0;
      _contrast = 1.0;
      _rotation = 0;
      _hasChanges = false;
      _errorMessage = null;
    });
    _loadImage(); // Reload original image
  }

  void _proceedToOCR() async {
    if (_hasChanges) {
      await _applyEnhancements();
      if (_errorMessage != null) return; // Don't proceed if enhancement failed
    }
    
    if (_imageFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OCRProcessingScreen(imagePath: _imageFile!.path),
        ),
      );
    }
  }

  void _retakePhoto() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Review Photo'),
        actions: [
          IconButton(
            onPressed: _hasChanges && !_isProcessing ? _resetEnhancements : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _imageFile != null && _errorMessage == null
          ? _buildBottomControls() 
          : null,
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_imageFile == null || _processedImage == null) {
      return _buildLoadingState();
    }

    return _buildPhotoPreview();
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
              'Image Error',
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _retakePhoto,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text(
                      'Retake Photo',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loadImage,
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

  Widget _buildLoadingState() {
    return const Center(
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

  Widget _buildPhotoPreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Center(
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 64,
                        );
                      },
                    ),
                  ),
                  if (_isProcessing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        child: const Center(
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
        _buildEnhancementControls(),
      ],
    );
  }

  Widget _buildEnhancementControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(
                Icons.rotate_right,
                'Rotate',
                _isProcessing ? null : _rotateImage,
              ),
              _buildQuickAction(
                Icons.auto_fix_high,
                'Auto Enhance',
                _isProcessing ? null : _autoEnhance,
              ),
              _buildQuickAction(
                Icons.crop,
                'Crop',
                _isProcessing ? null : _showCropDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSlider(
            'Brightness',
            _brightness,
            -100.0,
            100.0,
            _isProcessing ? null : (value) {
              setState(() {
                _brightness = value;
                _hasChanges = true;
              });
            },
          ),
          const SizedBox(height: 8),
          _buildSlider(
            'Contrast',
            _contrast,
            0.5,
            2.0,
            _isProcessing ? null : (value) {
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

  Widget _buildQuickAction(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: onTap != null ? Colors.grey[800] : Colors.grey[850],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              icon, 
              color: onTap != null ? Colors.white : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: onTap != null ? Colors.white : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double>? onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: onChanged != null ? Colors.white : Colors.grey[600], 
            fontSize: 14,
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 20,
          activeColor: const Color(0xFF1E3A8A),
          inactiveColor: Colors.grey[600],
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _autoEnhance() {
    setState(() {
      _brightness = 10.0;
      _contrast = 1.2;
      _hasChanges = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto enhancement applied'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showCropDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crop Image'),
        content: const Text('Advanced crop functionality coming soon!\n\nFor now, try to capture the image with good framing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _retakePhoto,
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text(
                  'Retake',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _proceedToOCR,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  _hasChanges ? 'Apply & Continue' : 'Continue',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
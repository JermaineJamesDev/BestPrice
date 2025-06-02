import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import '../services/file_picker_service.dart';
import '../services/consolidated_ocr_service.dart';
import 'gallery_results_screen.dart';
import 'package:path_provider/path_provider.dart';

class GalleryProcessingScreen extends StatefulWidget {
  final FilePickerResult fileResult;
  final ProcessingMode processingMode;

  const GalleryProcessingScreen({
    super.key,
    required this.fileResult,
    required this.processingMode,
  });

  @override
  _GalleryProcessingScreenState createState() => _GalleryProcessingScreenState();
}

class _GalleryProcessingScreenState extends State<GalleryProcessingScreen>
    with TickerProviderStateMixin {
  bool _isProcessing = true;
  String _currentStep = 'Preparing images...';
  double _overallProgress = 0.0;
  int _currentImageIndex = 0;
  String _currentImageName = '';
  List<String> _preparedFilePaths = [];
  BatchOCRResult? _result;
  String? _errorMessage;
  CancellationToken? _cancellationToken;

  late AnimationController _progressController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _processImagesSafely();
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    _cleanupFiles();
    super.dispose();
  }

  void _setupAnimations() {
    _progressController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _processImagesSafely() async {
    _cancellationToken = CancellationToken();
    
    try {
      debugPrint('🔄 Starting safe image processing...');
      debugPrint('📁 File count: ${widget.fileResult.files.length}');
      debugPrint('🎯 Processing mode: ${widget.processingMode}');
      
      await _updateProgress('Validating images...', 0.05);
      
      // Validate images before processing
      final validationResult = await _validateImagesBeforeProcessing();
      if (!validationResult.success) {
        throw Exception(validationResult.error);
      }
      
      await _updateProgress('Preparing images for processing...', 0.1);
      
      // Prepare files with safety checks
      _preparedFilePaths = await _prepareFilesSafely();
      
      if (_preparedFilePaths.isEmpty) {
        throw Exception('No valid images to process after preparation');
      }

      debugPrint('✅ Successfully prepared ${_preparedFilePaths.length} files');

      await _updateProgress('Starting OCR processing...', 0.2);

      // Process with enhanced error handling
      final result = await _processWithSafetyChecks();

      await _updateProgress('Processing complete!', 1.0);
      
      setState(() {
        _result = result;
        _isProcessing = false;
      });

      await Future.delayed(Duration(milliseconds: 500));
      
      if (mounted) {
        _navigateToResults();
      }

    } catch (e, stackTrace) {
      debugPrint('❌ Processing failed: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      setState(() {
        _errorMessage = 'Processing failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<ValidationResult> _validateImagesBeforeProcessing() async {
    try {
      for (int i = 0; i < widget.fileResult.files.length; i++) {
        final file = widget.fileResult.files[i];
        debugPrint('🔍 Validating file ${i + 1}: ${file.name}');
        
        if (file.path == null) {
          return ValidationResult(false, 'File ${file.name} has no path');
        }
        
        final fileObj = File(file.path!);
        if (!await fileObj.exists()) {
          return ValidationResult(false, 'File ${file.name} does not exist');
        }
        
        // Check file size
        final fileSize = await fileObj.length();
        if (fileSize > 15 * 1024 * 1024) { // 15MB limit
          return ValidationResult(false, 'File ${file.name} is too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB)');
        }
        
        // Try to decode the image to check for corruption
        try {
          final bytes = await fileObj.readAsBytes();
          final image = img.decodeImage(bytes);
          if (image == null) {
            return ValidationResult(false, 'File ${file.name} is corrupted or not a valid image');
          }
          
          // Check image dimensions
          if (image.width < 50 || image.height < 50) {
            return ValidationResult(false, 'File ${file.name} is too small (${image.width}x${image.height})');
          }
          
          debugPrint('✅ File ${file.name} validated: ${image.width}x${image.height}, ${(fileSize / 1024).toStringAsFixed(1)}KB');
          
        } catch (e) {
          return ValidationResult(false, 'File ${file.name} cannot be decoded: $e');
        }
      }
      
      return ValidationResult(true, null);
    } catch (e) {
      return ValidationResult(false, 'Validation error: $e');
    }
  }

  Future<List<String>> _prepareFilesSafely() async {
    final processedPaths = <String>[];
    
    try {
      for (int i = 0; i < widget.fileResult.files.length; i++) {
        final file = widget.fileResult.files[i];
        if (file.path == null) continue;

        debugPrint('📦 Preparing file ${i + 1}/${widget.fileResult.files.length}: ${file.name}');

        try {
          final originalFile = File(file.path!);
          final bytes = await originalFile.readAsBytes();
          
          // Decode and validate the image
          final image = img.decodeImage(bytes);
          if (image == null) {
            debugPrint('⚠️ Skipping corrupted file: ${file.name}');
            continue;
          }
          
          // Resize if too large to prevent memory issues
          img.Image processedImage = image;
          if (image.width > 2048 || image.height > 2048) {
            debugPrint('🔄 Resizing large image: ${image.width}x${image.height}');
            final ratio = 2048 / (image.width > image.height ? image.width : image.height);
            processedImage = img.copyResize(
              image,
              width: (image.width * ratio).round(),
              height: (image.height * ratio).round(),
              interpolation: img.Interpolation.cubic,
            );
            debugPrint('✅ Resized to: ${processedImage.width}x${processedImage.height}');
          }
          
          // Save processed image
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = file.name.split('.').last.toLowerCase();
          final newFileName = 'safe_picked_image_${timestamp}_$i.$extension';
          final newPath = '${tempDir.path}/$newFileName';
          
          final processedBytes = extension == 'png' 
            ? img.encodePng(processedImage)
            : img.encodeJpg(processedImage, quality: 85);
          
          await File(newPath).writeAsBytes(processedBytes);
          processedPaths.add(newPath);
          
          debugPrint('✅ Prepared: ${file.name} -> $newFileName (${(processedBytes.length / 1024).toStringAsFixed(1)}KB)');
          
        } catch (e) {
          debugPrint('❌ Failed to prepare file ${file.name}: $e');
          // Continue with other files
        }
      }
      
    } catch (e) {
      debugPrint('❌ File preparation error: $e');
      throw Exception('Failed to prepare files: $e');
    }
    
    return processedPaths;
  }

  Future<BatchOCRResult> _processWithSafetyChecks() async {
    try {
      debugPrint('🧠 Starting OCR processing with ${_preparedFilePaths.length} files');
      
      final result = await ConsolidatedOCRService.instance.processImageList(
        _preparedFilePaths,
        mode: widget.processingMode,
        priority: ProcessingPriority.normal,
        cancellationToken: _cancellationToken,
        onProgress: _onImageProgress,
      );
      
      debugPrint('✅ OCR processing completed');
      debugPrint('📊 Results: ${result.successfulImages}/${result.totalImages} successful');
      debugPrint('💰 Total prices found: ${result.results.fold(0, (sum, r) => sum + r.prices.length)}');
      
      return result;
      
    } catch (e, stackTrace) {
      debugPrint('❌ OCR processing failed: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _onImageProgress(int current, int total, String imagePath) {
    if (mounted) {
      debugPrint('📈 Processing progress: $current/$total - ${imagePath.split('/').last}');
      
      setState(() {
        _currentImageIndex = current;
        _currentImageName = imagePath.split('/').last;
      });

      final imageProgress = 0.2 + (0.7 * (current / total));
      _updateProgress(
        widget.processingMode == ProcessingMode.longReceipt
          ? 'Processing long receipt sections...'
          : 'Processing image $current of $total...',
        imageProgress,
      );
    }
  }

  Future<void> _updateProgress(String step, double progress) async {
    if (mounted) {
      setState(() {
        _currentStep = step;
      });
      
      await _progressController.animateTo(progress);
      
      setState(() {
        _overallProgress = progress;
      });
    }
  }

  void _navigateToResults() {
    if (_result != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GalleryResultsScreen(
            batchResult: _result!,
            processingMode: widget.processingMode,
            originalFileCount: widget.fileResult.files.length,
          ),
        ),
      );
    }
  }

  Future<void> _cleanupFiles() async {
    if (_preparedFilePaths.isNotEmpty) {
      debugPrint('🧹 Cleaning up ${_preparedFilePaths.length} temporary files');
      await FilePickerService.cleanupTempFiles(_preparedFilePaths);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.processingMode == ProcessingMode.longReceipt
            ? 'Processing Long Receipt'
            : 'Processing Images'
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (_isProcessing)
            IconButton(
              onPressed: _cancelProcessing,
              icon: Icon(Icons.close),
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: _errorMessage != null
        ? _buildErrorState()
        : _buildProcessingState(),
    );
  }

  Widget _buildProcessingState() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Processing indicator
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF1E3A8A), width: 3),
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFF1E3A8A).withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Icon(
                      widget.processingMode == ProcessingMode.longReceipt
                        ? Icons.receipt_long
                        : Icons.photo_library,
                      size: 70,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                );
              },
            ),
            
            SizedBox(height: 40),
            
            Text(
              _currentStep,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 32),
            
            // Progress bar
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _overallProgress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            Text(
              '${(_overallProgress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 48),
            
            // Current image info
            if (_currentImageName.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Currently Processing',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _currentImageName,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.processingMode == ProcessingMode.individual)
                      Text(
                        'Image $_currentImageIndex of ${_preparedFilePaths.length}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red),
            SizedBox(height: 24),
            Text(
              'Processing Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Go Back'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _isProcessing = true;
                        _overallProgress = 0.0;
                        _currentImageIndex = 0;
                        _currentImageName = '';
                      });
                      _processImagesSafely();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E3A8A),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _cancelProcessing() {
    _cancellationToken?.cancel();
    Navigator.pop(context);
  }
}

class ValidationResult {
  final bool success;
  final String? error;
  
  ValidationResult(this.success, this.error);
}

class ProcessingStepInfo {
  final int imageIndex;
  final String imageName;
  final DateTime timestamp;
  final ProcessingStatus status;

  ProcessingStepInfo({
    required this.imageIndex,
    required this.imageName,
    required this.timestamp,
    required this.status,
  });
}

enum ProcessingStatus {
  pending,
  processing,
  completed,
  failed,
}
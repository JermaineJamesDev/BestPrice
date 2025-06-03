import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:jamaica_price_directory/screens/enhanced_ocr_results_screen.dart';
import '../utils/camera_error_handler.dart';
import '../services/ocr_error_handler.dart';
import '../services/consolidated_ocr_service.dart';

class LongReceiptCaptureScreen extends StatefulWidget {
  const LongReceiptCaptureScreen({super.key});

  @override
  State<LongReceiptCaptureScreen> createState() =>
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
  bool _isProcessing = false;
  bool _isDisposed = false;
  bool _isImageStreamActive = false;

  String? _errorMessage;
  OCRErrorType? _currentErrorType;
  CancellationToken? _currentCancellationToken;

  // Section management
  final List<ReceiptSection> _capturedSections = [];
  bool _showSectionManager = false;
  int? _previewingSectionIndex;

  // Animations
  late AnimationController _errorAnimationController;
  late AnimationController _sectionManagerController;
  late AnimationController _captureButtonController;
  late Animation<double> _errorFadeAnimation;
  late Animation<Offset> _sectionManagerSlideAnimation;
  late Animation<double> _captureButtonScaleAnimation;

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

    // Cancel any ongoing operations
    _currentCancellationToken?.cancel();

    // Stop and dispose camera resources
    _stopImageStreamAndDispose();

    // Safely dispose animation controllers
    try {
      _errorAnimationController.dispose();
      _sectionManagerController.dispose();
      _captureButtonController.dispose();
    } catch (e) {
      debugPrint('Error disposing animation controllers: $e');
    }

    // Clean up captured section files if needed
    _cleanupSectionFiles();

    super.dispose();
  }

  /// Clean up any temporary section files
  void _cleanupSectionFiles() {
    for (final section in _capturedSections) {
      try {
        final file = File(section.imagePath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        debugPrint('Failed to cleanup section file ${section.imagePath}: $e');
      }
    }
  }

  void _setupAnimations() {
    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sectionManagerController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _captureButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _errorFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _errorAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _sectionManagerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _sectionManagerController,
            curve: Curves.easeOutCubic,
          ),
        );

    _captureButtonScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _captureButtonController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _stopImageStreamAndDispose();
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
        _showRetryIndicator();
      },
      onSuccess: (_) {
        _clearError();
      },
    );
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed || !mounted) return;

    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentErrorType = null;
      });
    }

    try {
      final cameraPermission = await Permission.camera.request();
      if (cameraPermission.isDenied) {
        throw OCRException(
          'Camera permission denied',
          type: OCRErrorType.cameraPermissionDenied,
        );
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _hasPermission = true;
        });
      }

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

      await _stopImageStreamAndDispose();
      if (_isDisposed || !mounted) return;

      _cameraController = CameraErrorHandler.createOptimizedController(
        _cameras.first,
        prioritizeStability: true,
      );
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);

      _startImageStreamSafely();

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

  Future<void> _stopImageStreamAndDispose() async {
    await CameraErrorHandler.safeStopImageStream(_cameraController);

    if (_cameraController != null) {
      await CameraErrorHandler.enhancedDispose(_cameraController);
      _cameraController = null;
      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
    _isImageStreamActive = false;
  }

  void _startImageStreamSafely() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isImageStreamActive ||
        _isDisposed) {
      return;
    }

    try {
      // For long receipts, we don't need image stream processing
      // Just initialize without starting stream to avoid buffer issues
      _isImageStreamActive = false;
      debugPrint('📱 Long receipt camera ready (no image stream)');
    } catch (e) {
      debugPrint('Failed to start camera: $e');
    }
  }

  void _handleCameraError(dynamic error) {
    if (_isDisposed || !mounted) return;

    if (CameraErrorHandler.isImageReaderError(error)) {
      debugPrint('🔍 ImageReader error detected, attempting recovery...');
      _recoverFromImageReaderError();
      return;
    }

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

    if (mounted && !_isDisposed) {
      setState(() {
        _errorMessage = errorMessage;
        _currentErrorType = errorType;
      });
      _errorAnimationController.forward();
    }
  }

  Future<void> _recoverFromImageReaderError() async {
    if (_isDisposed || !mounted) return;

    if (mounted && !_isDisposed) {
      setState(() {
        _errorMessage = 'Camera buffer overflow detected. Restarting...';
      });
    }

    try {
      await CameraErrorHandler.recoverFromImageReaderError(_cameraController);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted && !_isDisposed) {
        _clearError();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera recovered successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('ImageReader recovery failed: $e');
      if (mounted && !_isDisposed) {
        _initializeWithErrorHandling();
      }
    }
  }

  void _clearError() {
    if (mounted && !_isDisposed) {
      setState(() {
        _errorMessage = null;
        _currentErrorType = null;
      });
      _errorAnimationController.reverse();
    }
  }

  void _showRetryIndicator() {
    if (mounted && !_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
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

  Future<void> _captureSection() async {
    if (!_isCameraInitialized ||
        _isCapturing ||
        _cameraController == null ||
        _isDisposed ||
        !mounted) {
      return;
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _isCapturing = true;
      });
    }

    // Animate capture button
    _captureButtonController.forward().then((_) {
      if (mounted && !_isDisposed) {
        _captureButtonController.reverse();
      }
    });

    try {
      // Stop any image processing before capture
      await CameraErrorHandler.safeStopImageStream(_cameraController);
      await Future.delayed(const Duration(milliseconds: 200));

      final picture = await OCRErrorRecovery.executeWithRecovery(
        () => _cameraController!.takePicture(),
        'long_receipt_capture_section',
        context: OCRErrorContext(
          operation: 'capture_section',
          metadata: {
            'section_number': _capturedSections.length + 1,
            'total_sections': _capturedSections.length,
          },
        ),
        onError: (error, attempt) {
          debugPrint('Section capture error (attempt $attempt): $error');
          if (mounted && !_isDisposed) {
            OCRErrorSnackBar.show(
              context,
              error,
              errorContext: OCRErrorContext(
                operation: 'capture_section',
                metadata: {'attempt': attempt},
              ),
            );
          }
        },
      );

      if (picture != null && mounted && !_isDisposed) {
        final section = ReceiptSection(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imagePath: picture.path,
          sectionNumber: _capturedSections.length + 1,
          capturedAt: DateTime.now(),
        );

        if (mounted && !_isDisposed) {
          setState(() {
            _capturedSections.add(section);
            _showSectionManager = true;
          });

          // Show section manager
          _sectionManagerController.forward();

          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Section ${section.sectionNumber} captured!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => _previewSection(_capturedSections.length - 1),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _handleCameraError(e);
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _previewSection(int index) {
    if (mounted && !_isDisposed) {
      setState(() {
        _previewingSectionIndex = index;
      });
    }
  }

  void _closePreview() {
    if (mounted && !_isDisposed) {
      setState(() {
        _previewingSectionIndex = null;
      });
    }
  }

  Future<void> _retakeSection(int index) async {
    final section = _capturedSections[index];

    // Delete the old image file
    try {
      final file = File(section.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete old section image: $e');
    }

    // Remove from list
    if (mounted && !_isDisposed) {
      setState(() {
        _capturedSections.removeAt(index);
        _previewingSectionIndex = null;
      });
    }

    // Update section numbers
    for (int i = index; i < _capturedSections.length; i++) {
      _capturedSections[i] = _capturedSections[i].copyWith(
        sectionNumber: i + 1,
      );
    }

    // Capture new section
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && !_isDisposed) {
      _captureSection();
    }
  }

  void _removeSection(int index) {
    final section = _capturedSections[index];

    // Delete the image file
    try {
      final file = File(section.imagePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('Failed to delete section image: $e');
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _capturedSections.removeAt(index);
        _previewingSectionIndex = null;
      });
    }

    // Update section numbers
    for (int i = index; i < _capturedSections.length; i++) {
      _capturedSections[i] = _capturedSections[i].copyWith(
        sectionNumber: i + 1,
      );
    }

    if (_capturedSections.isEmpty && mounted && !_isDisposed) {
      setState(() {
        _showSectionManager = false;
      });
      _sectionManagerController.reverse();
    }
  }

  Future<void> _processAllSections() async {
    if (_capturedSections.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please capture at least 2 sections'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _isProcessing = true;
      });
    }

    try {
      final sectionPaths = _capturedSections.map((s) => s.imagePath).toList();

      final result = await ConsolidatedOCRService.instance.processLongReceipt(
        sectionPaths,
        cancellationToken: _currentCancellationToken,
      );

      if (mounted && !_isDisposed && result != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedOCRResultsScreen(
              imagePath: _capturedSections.first.imagePath,
              extractedPrices: result.prices,
              fullText: result.fullText,
              isLongReceipt: true,
              bestEnhancement: result.enhancement,
              storeType: result.storeType,
              metadata: {
                ...result.metadata,
                'section_count': _capturedSections.length,
                'section_paths': sectionPaths,
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error processing long receipt: $e');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _toggleSectionManager() {
    if (_capturedSections.isEmpty || !mounted || _isDisposed) return;

    setState(() {
      _showSectionManager = !_showSectionManager;
    });

    if (_showSectionManager) {
      _sectionManagerController.forward();
    } else {
      _sectionManagerController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Long Receipt (${_capturedSections.length} sections)'),
        actions: [
          if (_capturedSections.isNotEmpty)
            IconButton(
              onPressed: _toggleSectionManager,
              icon: Icon(
                _showSectionManager ? Icons.expand_more : Icons.expand_less,
              ),
              tooltip: 'Toggle section manager',
            ),
          if (_capturedSections.length >= 2)
            TextButton(
              onPressed: _isProcessing ? null : _processAllSections,
              child: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Process',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view or loading state
          if (_isCameraInitialized) _buildCameraView() else _buildLoadingView(),

          // Error overlay
          if (_errorMessage != null) _buildErrorOverlay(),

          // Section manager (slides up from bottom)
          if (_capturedSections.isNotEmpty) _buildSectionManager(),

          // Full screen section preview
          if (_previewingSectionIndex != null) _buildSectionPreview(),

          // Camera overlay with instructions
          if (_isCameraInitialized) _buildCameraOverlay(),
        ],
      ),
      bottomNavigationBar: _isCameraInitialized && !_isCapturing
          ? _buildControls()
          : null,
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Initializing camera for long receipts...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initializeWithErrorHandling,
            child: const Text('Retry'),
          ),
        ],
      ),
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

  Widget _buildCameraOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: LongReceiptFramePainter(),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.7 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Section ${_capturedSections.length + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _capturedSections.isEmpty
                            ? 'Start from the top of your receipt'
                            : 'Align with previous section for overlap',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_capturedSections.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.8 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_capturedSections.length} section${_capturedSections.length == 1 ? '' : 's'} captured',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionManager() {
    return SlideTransition(
      position: _sectionManagerSlideAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.3,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Captured Sections',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_capturedSections.length} section${_capturedSections.length == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _capturedSections.length,
                  itemBuilder: (context, index) => _buildSectionItem(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionItem(int index) {
    final section = _capturedSections[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 50,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                File(section.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.error, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          title: Text('Section ${section.sectionNumber}'),
          subtitle: Text(
            'Captured at ${section.capturedAt.hour.toString().padLeft(2, '0')}:${section.capturedAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _previewSection(index),
                icon: const Icon(Icons.visibility, color: Colors.blue),
                tooltip: 'Preview',
              ),
              IconButton(
                onPressed: () => _retakeSection(index),
                icon: const Icon(Icons.camera_alt, color: Colors.orange),
                tooltip: 'Retake',
              ),
              IconButton(
                onPressed: () => _removeSection(index),
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionPreview() {
    final section = _capturedSections[_previewingSectionIndex!];

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _closePreview,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Text(
                    'Section ${section.sectionNumber}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _retakeSection(_previewingSectionIndex!),
                    child: const Text(
                      'Retake',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _removeSection(_previewingSectionIndex!),
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(section.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.white, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
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
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha((0.9 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
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
                          _errorMessage ?? '',
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

  Widget _buildControls() {
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
            // Gallery button (disabled for long receipts)
            IconButton(
              onPressed: null,
              icon: Icon(
                Icons.photo_library,
                color: Colors.grey[600],
                size: 32,
              ),
            ),

            // Capture button
            AnimatedBuilder(
              animation: _captureButtonScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _captureButtonScaleAnimation.value,
                  child: GestureDetector(
                    onTap: _isCapturing ? null : _captureSection,
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
                        child: _isCapturing
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Sections counter/manager toggle
            IconButton(
              onPressed: _capturedSections.isEmpty
                  ? null
                  : _toggleSectionManager,
              icon: Stack(
                children: [
                  Icon(
                    Icons.view_list,
                    color: _capturedSections.isEmpty
                        ? Colors.grey[600]
                        : Colors.white,
                    size: 32,
                  ),
                  if (_capturedSections.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_capturedSections.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
}

// Data model for receipt sections
class ReceiptSection {
  final String id;
  final String imagePath;
  final int sectionNumber;
  final DateTime capturedAt;

  const ReceiptSection({
    required this.id,
    required this.imagePath,
    required this.sectionNumber,
    required this.capturedAt,
  });

  ReceiptSection copyWith({
    String? id,
    String? imagePath,
    int? sectionNumber,
    DateTime? capturedAt,
  }) {
    return ReceiptSection(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      sectionNumber: sectionNumber ?? this.sectionNumber,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }
}

// Custom painter for long receipt frame overlay
class LongReceiptFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final frameWidth = size.width * 0.85;
    final frameHeight = size.height * 0.6;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    const cornerLength = 40.0;

    // Draw corner brackets for receipt frame
    // Top-left
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);

    // Top-right
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

    // Bottom-left
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

    // Bottom-right
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

    // Add center line to show overlap guide
    final centerY = size.height / 2;
    final dashedLinePaint = Paint()
      ..color = Colors.yellow.withAlpha((0.7 * 255).round())
      ..strokeWidth = 2;

    const dashWidth = 10.0;
    const dashSpace = 5.0;
    double startX = left + 20;
    final endX = left + frameWidth - 20;

    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, centerY),
        Offset((startX + dashWidth).clamp(startX, endX), centerY),
        dashedLinePaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

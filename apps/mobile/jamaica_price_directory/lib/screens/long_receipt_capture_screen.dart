import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/consolidated_ocr_service.dart';
import '../utils/camera_error_handler.dart';
import 'long_receipt_results_screen.dart'; // NEW: Separate file

class LongReceiptCaptureScreen extends StatefulWidget {
  const LongReceiptCaptureScreen({super.key});

  @override
  _LongReceiptCaptureScreenState createState() =>
      _LongReceiptCaptureScreenState();
}

class _LongReceiptCaptureScreenState extends State<LongReceiptCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  final List<ReceiptSection> _capturedSections = [];
  int _currentSection = 1;
  bool _isProcessing = false;
  String? _guideText;
  int _currentProcessingSection = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _updateGuideText();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CameraErrorHandler.safeDispose(_cameraController);
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty && mounted) {
        _cameras = cameras;
        _cameraController = CameraErrorHandler.createOptimizedController(
          cameras[0],
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
    }
  }

  void _updateGuideText() {
    setState(() {
      if (_currentSection == 1) {
        _guideText =
            "Capture the TOP section of your receipt\nMake sure all text is clearly visible";
      } else if (_capturedSections.length < 5) {
        _guideText =
            "Capture section $_currentSection\nInclude some overlap with the previous section";
      } else {
        _guideText =
            "Capture the BOTTOM section\nInclude the total and any remaining items";
      }
    });
  }

  Future<void> _captureSection() async {
    if (!_isCameraInitialized || _isCapturing || _cameraController == null) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      final section = ReceiptSection(
        imagePath: image.path,
        sectionNumber: _currentSection,
        timestamp: DateTime.now(),
      );

      setState(() {
        _capturedSections.add(section);
        _currentSection++;
        _isCapturing = false;
      });

      _updateGuideText();
      _showSectionCapturedDialog(section);
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to capture: $e')));
    }
  }

  void _showSectionCapturedDialog(ReceiptSection section) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Section ${section.sectionNumber} Captured'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(section.imagePath), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            Text('Total sections captured: ${_capturedSections.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _removeLastSection();
              Navigator.of(ctx).pop();
            },
            child: const Text('Retake'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue'),
          ),
          if (_capturedSections.length >= 2)
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _processAllSections();
              },
              child: const Text('Process Receipt'),
            ),
        ],
      ),
    );
  }

  void _removeLastSection() {
    if (_capturedSections.isNotEmpty) {
      final removed = _capturedSections.removeLast();
      File(removed.imagePath).delete();
      setState(() {
        _currentSection--;
      });
      _updateGuideText();
    }
  }

  Future<void> _processAllSections() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildProcessingDialog(),
      );

      final sectionPaths = _capturedSections
          .map((section) => section.imagePath)
          .toList();

      setState(() {
        _currentProcessingSection = _capturedSections.length;
      });

      final result = await ConsolidatedOCRService.instance.processLongReceipt(
        sectionPaths,
        priority: ProcessingPriority.normal,
      );

      final mergedResult = MergedReceiptResult(
        prices: result.prices,
        fullText: result.fullText,
        totalSections: _capturedSections.length,
        confidence: result.confidence,
      );

      Navigator.of(context).pop(); // Close progress dialog

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LongReceiptResultsScreen(
            sections: _capturedSections,
            mergedResult: mergedResult,
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Processing failed: $e')));
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }



  Widget _buildProcessingDialog() {
    return AlertDialog(
      title: const Text('Processing Long Receipt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Processing ${_capturedSections.length} sections with advanced OCR...',
          ),
          const SizedBox(height: 16),
          const Text(
            'Using optimized processing with automatic section merging and deduplication.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  MergedReceiptResult _mergeReceiptSections(
    List<ExtractedPrice> allPrices,
    String fullText,
  ) {
    // Enhanced deduplication with semantic similarity
    final uniquePrices = <ExtractedPrice>[];

    for (final price in allPrices) {
      bool isDuplicate = false;

      for (int i = 0; i < uniquePrices.length; i++) {
        final existing = uniquePrices[i];

        if (_areSemanticallySimilar(price, existing)) {
          // Keep the one with higher confidence
          if (price.confidence > existing.confidence) {
            uniquePrices[i] = price;
          }
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        uniquePrices.add(price);
      }
    }

    // Sort by position to maintain receipt order
    uniquePrices.sort((a, b) => a.position.top.compareTo(b.position.top));

    return MergedReceiptResult(
      prices: uniquePrices,
      fullText: fullText,
      totalSections: _capturedSections.length,
      confidence: _calculateMergedConfidence(uniquePrices),
    );
  }

  bool _areSemanticallySimilar(ExtractedPrice price1, ExtractedPrice price2) {
    // Same price within 1 cent
    if ((price1.price - price2.price).abs() < 0.01) {
      return true;
    }

    // Very similar item names with small price difference
    final similarity = _calculateStringSimilarity(
      price1.itemName.toLowerCase(),
      price2.itemName.toLowerCase(),
    );

    if (similarity > 0.85) {
      final priceDiff =
          (price1.price - price2.price).abs() /
          ((price1.price + price2.price) / 2);
      return priceDiff < 0.1; // 10% difference threshold
    }

    return false;
  }

  double _calculateStringSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final words1 = str1.split(' ').toSet();
    final words2 = str2.split(' ').toSet();
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    return intersection.length / union.length;
  }

  double _calculateMergedConfidence(List<ExtractedPrice> prices) {
    if (prices.isEmpty) return 0.0;

    final avgConfidence =
        prices.map((p) => p.confidence).reduce((a, b) => a + b) / prices.length;

    // Bonus for multiple sections
    final sectionBonus = (_capturedSections.length - 1) * 0.05;

    return (avgConfidence + sectionBonus).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Long Receipt - Section $_currentSection'),
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
      body: _isCameraInitialized ? _buildCameraView() : _buildLoadingView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_cameraController!)),
        _buildCameraOverlay(),
        _buildSectionsIndicator(),
        _buildCameraControls(),
      ],
    );
  }

  Widget _buildCameraOverlay() {
    return Positioned.fill(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Text(
                    _guideText ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_capturedSections.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sections captured: ${_capturedSections.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 300),
            painter: ReceiptFramePainter(),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSectionsIndicator() {
    if (_capturedSections.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            const Text(
              'Captured:',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 4),
            ..._capturedSections.asMap().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${entry.key + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
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
                onPressed: _capturedSections.isNotEmpty
                    ? _removeLastSection
                    : null,
                icon: Icon(
                  Icons.undo,
                  color: _capturedSections.isNotEmpty
                      ? Colors.white
                      : Colors.grey,
                  size: 32,
                ),
              ),
              GestureDetector(
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
                  ),
                ),
              ),
              IconButton(
                onPressed: _capturedSections.length >= 2
                    ? _processAllSections
                    : null,
                icon: Icon(
                  Icons.check,
                  color: _capturedSections.length >= 2
                      ? Colors.green
                      : Colors.grey,
                  size: 32,
                ),
              ),
            ],
          ),
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

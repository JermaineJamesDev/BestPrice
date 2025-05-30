// lib/screens/long_receipt_capture_screen.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../utils/camera_error_handler.dart';
import '../services/advanced_ocr_processor.dart';

class LongReceiptCaptureScreen extends StatefulWidget {
  const LongReceiptCaptureScreen({super.key});

  @override
  _LongReceiptCaptureScreenState createState() => _LongReceiptCaptureScreenState();
}

class _LongReceiptCaptureScreenState extends State<LongReceiptCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  
  // Multi-section capture state
  List<ReceiptSection> _capturedSections = [];
  int _currentSection = 1;
  bool _isProcessing = false;
  String? _guideText;

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
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraController = CameraErrorHandler.createOptimizedController(cameras[0]);
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    }
  }

  void _updateGuideText() {
    setState(() {
      if (_currentSection == 1) {
        _guideText = "Capture the TOP section of your receipt\nMake sure all text is clearly visible";
      } else if (_capturedSections.length < 5) {
        _guideText = "Capture section $_currentSection\nInclude some overlap with the previous section";
      } else {
        _guideText = "Capture the BOTTOM section\nInclude the total and any remaining items";
      }
    });
  }

  Future<void> _captureSection() async {
    if (!_isCameraInitialized || _isCapturing || _cameraController == null) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture: $e')),
      );
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
                child: Image.file(
                  File(section.imagePath),
                  fit: BoxFit.cover,
                ),
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
      File(removed.imagePath).delete(); // Clean up file
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
      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildProcessingDialog(),
      );

      // Process each section
      final allPrices = <ExtractedPrice>[];
      final allText = <String>[];

      for (int i = 0; i < _capturedSections.length; i++) {
        final section = _capturedSections[i];
        
        // Update processing status
        setState(() {
          _currentProcessingSection = i + 1;
        });

        final result = await AdvancedOCRProcessor.processReceiptImage(section.imagePath);
        
        // Add section identifier to prices
        final sectionPrices = result.prices.map((price) => ExtractedPrice(
          itemName: price.itemName,
          price: price.price,
          originalText: price.originalText,
          confidence: price.confidence,
          position: price.position,
          category: price.category,
          unit: price.unit,
        )).toList();

        allPrices.addAll(sectionPrices);
        allText.add('--- Section ${section.sectionNumber} ---\n${result.fullText}');
      }

      // Merge and deduplicate results
      final mergedResult = _mergeReceiptSections(allPrices, allText.join('\n\n'));

      Navigator.of(context).pop(); // Close processing dialog
      
      // Navigate to results
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LongReceiptResultsScreen(
            sections: _capturedSections,
            mergedResult: mergedResult,
          ),
        ),
      );

    } catch (e) {
      Navigator.of(context).pop(); // Close processing dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing failed: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  int _currentProcessingSection = 0;

  Widget _buildProcessingDialog() {
    return AlertDialog(
      title: const Text('Processing Receipt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Processing section $_currentProcessingSection of ${_capturedSections.length}'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _currentProcessingSection / _capturedSections.length,
          ),
          const SizedBox(height: 16),
          const Text(
            'This may take a few moments...',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  MergedReceiptResult _mergeReceiptSections(List<ExtractedPrice> allPrices, String fullText) {
    // Remove duplicates that appear across sections
    final uniquePrices = <ExtractedPrice>[];
    
    for (final price in allPrices) {
      bool isDuplicate = false;
      
      for (final existing in uniquePrices) {
        // Check for duplicates with tolerance for OCR variations
        if (_isProbableDuplicate(price, existing)) {
          // Keep the one with higher confidence
          if (price.confidence > existing.confidence) {
            uniquePrices.remove(existing);
            uniquePrices.add(price);
          }
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        uniquePrices.add(price);
      }
    }

    // Sort by section number and position
    uniquePrices.sort((a, b) {
      final sectionCompare = (a.sectionNumber ?? 0).compareTo(b.sectionNumber ?? 0);
      if (sectionCompare != 0) return sectionCompare;
      return a.position.top.compareTo(b.position.top);
    });

    return MergedReceiptResult(
      prices: uniquePrices,
      fullText: fullText,
      totalSections: _capturedSections.length,
      confidence: _calculateMergedConfidence(uniquePrices),
    );
  }

  bool _isProbableDuplicate(ExtractedPrice price1, ExtractedPrice price2) {
    // Same price and similar item name
    if ((price1.price - price2.price).abs() < 0.01) {
      final similarity = _calculateStringSimilarity(
        price1.itemName.toLowerCase(),
        price2.itemName.toLowerCase(),
      );
      return similarity > 0.7;
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
    
    final avgConfidence = prices
        .map((p) => p.confidence)
        .reduce((a, b) => a + b) / prices.length;
    
    // Boost confidence if we have multiple sections (more comprehensive)
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
              onPressed: _capturedSections.length >= 2 ? _processAllSections : null,
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
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        
        // Overlay with guide
        _buildCameraOverlay(),
        
        // Captured sections indicator
        _buildSectionsIndicator(),
        
        // Camera controls
        _buildCameraControls(),
      ],
    );
  }

  Widget _buildCameraOverlay() {
    return Positioned.fill(
      child: Column(
        children: [
          // Top guidance
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
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
          
          // Capture frame overlay
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
          border: Border(
            top: BorderSide(color: Colors.grey[800]!, width: 1),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Remove last section
              IconButton(
                onPressed: _capturedSections.isNotEmpty ? _removeLastSection : null,
                icon: Icon(
                  Icons.undo,
                  color: _capturedSections.isNotEmpty ? Colors.white : Colors.grey,
                  size: 32,
                ),
              ),
              
              // Capture button
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
              
              // Process button
              IconButton(
                onPressed: _capturedSections.length >= 2 ? _processAllSections : null,
                icon: Icon(
                  Icons.check,
                  color: _capturedSections.length >= 2 ? Colors.green : Colors.grey,
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

// Custom painter for receipt frame
class ReceiptFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw receipt-like frame
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height * 0.9,
    );

    // Draw corners
    const cornerLength = 30.0;
    
    // Top left
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
    
    // Top right
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
    
    // Bottom left
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
    
    // Bottom right
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

// Data classes
class ReceiptSection {
  final String imagePath;
  final int sectionNumber;
  final DateTime timestamp;

  ReceiptSection({
    required this.imagePath,
    required this.sectionNumber,
    required this.timestamp,
  });
}

class MergedReceiptResult {
  final List<ExtractedPrice> prices;
  final String fullText;
  final int totalSections;
  final double confidence;

  MergedReceiptResult({
    required this.prices,
    required this.fullText,
    required this.totalSections,
    required this.confidence,
  });
}

// Extended ExtractedPrice to include section info
extension ExtractedPriceExtension on ExtractedPrice {
  int? get sectionNumber => null; // This would be properly implemented
}

// Results screen for long receipts
class LongReceiptResultsScreen extends StatelessWidget {
  final List<ReceiptSection> sections;
  final MergedReceiptResult mergedResult;

  const LongReceiptResultsScreen({
    super.key,
    required this.sections,
    required this.mergedResult,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Long Receipt Results'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt Summary',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Sections processed: ${mergedResult.totalSections}'),
                    Text('Items found: ${mergedResult.prices.length}'),
                    Text('Overall confidence: ${(mergedResult.confidence * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Extracted prices
            Text(
              'Extracted Prices',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            
            ...mergedResult.prices.map((price) => Card(
              child: ListTile(
                title: Text(price.itemName),
                subtitle: Text('${price.category} • Confidence: ${(price.confidence * 100).toStringAsFixed(1)}%'),
                trailing: Text(
                  'J\$${price.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            // Process the results (save, submit, etc.)
            Navigator.popUntil(context, (route) => route.isFirst);
          },
          child: const Text('Submit All Prices'),
        ),
      ),
    );
  }
}
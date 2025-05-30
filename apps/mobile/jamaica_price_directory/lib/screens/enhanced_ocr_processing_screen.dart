// lib/screens/enhanced_ocr_processing_screen.dart
import 'package:flutter/material.dart';
import '../services/advanced_ocr_processor.dart';
import 'ocr_results_screen.dart';

class EnhancedOCRProcessingScreen extends StatefulWidget {
  final String imagePath;
  final bool isLongReceipt;
  final List<String>? sectionPaths; // For long receipts

  const EnhancedOCRProcessingScreen({
    super.key, 
    required this.imagePath,
    this.isLongReceipt = false,
    this.sectionPaths,
  });

  @override
  _EnhancedOCRProcessingScreenState createState() => _EnhancedOCRProcessingScreenState();
}

class _EnhancedOCRProcessingScreenState extends State<EnhancedOCRProcessingScreen>
    with TickerProviderStateMixin {
  bool _isProcessing = true;
  String _currentStep = 'Initializing advanced OCR...';
  double _progress = 0.0;
  List<ExtractedPrice> _extractedPrices = [];
  String _fullText = '';
  String? _errorMessage;
  EnhancementType? _bestEnhancement;
  int _totalEnhancements = 6;
  int _currentEnhancement = 0;

  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _enhancementController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _processImage();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _enhancementController.dispose();
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

    _enhancementController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
  }

  Future<void> _processImage() async {
    try {
      if (widget.isLongReceipt && widget.sectionPaths != null) {
        await _processLongReceipt();
      } else {
        await _processSingleImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Processing failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processSingleImage() async {
    await _updateProgress('Starting advanced OCR analysis...', 0.1);
    
    // Use the advanced OCR processor
    final result = await AdvancedOCRProcessor.processReceiptImage(widget.imagePath);
    
    await _updateProgress('Extracting prices with AI...', 0.9);
    
    setState(() {
      _extractedPrices = result.prices;
      _fullText = result.fullText;
      _bestEnhancement = result.enhancement;
    });

    await _updateProgress('Processing complete!', 1.0);
    await Future.delayed(Duration(milliseconds: 500));
    _navigateToResults();
  }

  Future<void> _processLongReceipt() async {
    if (widget.sectionPaths == null) return;
    
    await _updateProgress('Processing long receipt sections...', 0.1);
    
    final allPrices = <ExtractedPrice>[];
    final allText = <String>[];
    
    for (int i = 0; i < widget.sectionPaths!.length; i++) {
      setState(() {
        _currentStep = 'Processing section ${i + 1} of ${widget.sectionPaths!.length}...';
      });
      
      final progress = 0.1 + (0.7 * (i + 1) / widget.sectionPaths!.length);
      await _updateProgress(_currentStep, progress);
      
      final result = await AdvancedOCRProcessor.processReceiptImage(widget.sectionPaths![i]);
      
      // Add section metadata to prices
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
      allText.add('--- Section ${i + 1} ---\n${result.fullText}');
    }
    
    await _updateProgress('Merging and deduplicating results...', 0.9);
    
    // Merge and deduplicate
    final mergedPrices = _mergeLongReceiptPrices(allPrices);
    
    setState(() {
      _extractedPrices = mergedPrices;
      _fullText = allText.join('\n\n');
    });

    await _updateProgress('Long receipt processing complete!', 1.0);
    await Future.delayed(Duration(milliseconds: 500));
    _navigateToResults();
  }

  List<ExtractedPrice> _mergeLongReceiptPrices(List<ExtractedPrice> allPrices) {
    final uniquePrices = <ExtractedPrice>[];
    
    for (final price in allPrices) {
      bool isDuplicate = false;
      
      for (final existing in uniquePrices) {
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
    
    // Sort by confidence
    uniquePrices.sort((a, b) => b.confidence.compareTo(a.confidence));
    return uniquePrices;
  }

  bool _isProbableDuplicate(ExtractedPrice price1, ExtractedPrice price2) {
    // Same price within 1 cent
    if ((price1.price - price2.price).abs() < 0.01) {
      // Check item name similarity
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

  Future<void> _updateProgress(String step, double progress) async {
    setState(() {
      _currentStep = step;
    });
    await _progressController.animateTo(progress);
    setState(() {
      _progress = progress;
    });
  }

  void _navigateToResults() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OCRResultsScreen(
          imagePath: widget.imagePath,
          extractedPrices: _extractedPrices,
          fullText: _fullText,
          isLongReceipt: widget.isLongReceipt,
        ),
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
        title: Text(widget.isLongReceipt ? 'Processing Long Receipt' : 'Processing Image'),
        automaticallyImplyLeading: false,
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
            // Main processing animation
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
                      border: Border.all(
                        color: Color(0xFF1E3A8A),
                        width: 3,
                      ),
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFF1E3A8A).withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Icon(
                      widget.isLongReceipt ? Icons.receipt_long : Icons.document_scanner,
                      size: 70,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                );
              },
            ),
            
            SizedBox(height: 40),
            
            // Current step
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
                widthFactor: _progress,
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
            
            // Progress percentage
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 48),
            
            // Enhancement techniques info
            _buildEnhancementInfo(),
            
            SizedBox(height: 32),
            
            // Processing tips
            _buildProcessingTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancementInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_high,
                color: Colors.amber,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Advanced OCR Processing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...EnhancementType.values.map((type) {
            int index = EnhancementType.values.indexOf(type);
            bool isActive = index <= _currentEnhancement;
            bool isCurrent = index == _currentEnhancement;
            
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isActive ? Color(0xFF1E3A8A) : Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                    child: isActive ? Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ) : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getEnhancementDescription(type),
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.grey[400],
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProcessingTips() {
    final tips = [
      'Analyzing image quality and orientation',
      'Applying contrast and brightness enhancements',
      'Using machine learning for text recognition',
      'Extracting prices with pattern matching',
      'Validating results with confidence scoring',
      'Finalizing extraction results',
    ];
    
    int tipIndex = (_progress * (tips.length - 1)).round();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900]!.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tips_and_updates,
            color: Colors.blue[300],
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              tips[tipIndex],
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
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
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
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
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
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
                        _progress = 0.0;
                      });
                      _processImage();
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

  String _getEnhancementDescription(EnhancementType type) {
    switch (type) {
      case EnhancementType.original:
        return 'Original image analysis';
      case EnhancementType.contrast:
        return 'Contrast enhancement';
      case EnhancementType.brightness:
        return 'Brightness adjustment';
      case EnhancementType.sharpen:
        return 'Image sharpening';
      case EnhancementType.grayscale:
        return 'Grayscale conversion';
      case EnhancementType.binarize:
        return 'Binary threshold processing';
    }
  }
}

// Extension to add section number to ExtractedPrice
extension ExtractedPriceExtension on ExtractedPrice {
  ExtractedPrice copyWithSection(int sectionNumber) {
    return ExtractedPrice(
      itemName: itemName,
      price: price,
      originalText: originalText,
      confidence: confidence,
      position: position,
      category: category,
      unit: unit,
    );
  }
}
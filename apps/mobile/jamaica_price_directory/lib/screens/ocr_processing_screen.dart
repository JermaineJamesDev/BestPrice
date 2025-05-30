import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'ocr_results_screen.dart';

// OCR Processing Screen - Extract text and prices from captured image
class OCRProcessingScreen extends StatefulWidget {
  final String imagePath;
  
  const OCRProcessingScreen({super.key, required this.imagePath});
  
  @override
  _OCRProcessingScreenState createState() => _OCRProcessingScreenState();
}

class _OCRProcessingScreenState extends State<OCRProcessingScreen>
    with TickerProviderStateMixin {
  
  // OCR processing state
  bool _isProcessing = true;
  String _currentStep = 'Analyzing image...';
  double _progress = 0.0;
  
  // OCR results
  List<ExtractedPrice> _extractedPrices = [];
  String _fullText = '';
  String? _errorMessage;
  
  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _pulseController;
  
  // Text recognizer
  final TextRecognizer _textRecognizer = TextRecognizer();
  
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
    _textRecognizer.close();
    super.dispose();
  }
  
  // Setup animations
  void _setupAnimations() {
    _progressController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }
  
  // Process image with OCR
  Future<void> _processImage() async {
    try {
      // Step 1: Initialize OCR
      await _updateProgress('Initializing OCR engine...', 0.1);
      await Future.delayed(Duration(milliseconds: 800));
      
      // Step 2: Load image
      await _updateProgress('Loading image...', 0.2);
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      await Future.delayed(Duration(milliseconds: 500));
      
      // Step 3: Extract text
      await _updateProgress('Extracting text...', 0.4);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      _fullText = recognizedText.text;
      await Future.delayed(Duration(milliseconds: 1000));
      
      // Step 4: Parse prices
      await _updateProgress('Identifying prices...', 0.6);
      _extractedPrices = _parseprices(recognizedText);
      await Future.delayed(Duration(milliseconds: 800));
      
      // Step 5: Enhance results
      await _updateProgress('Enhancing results...', 0.8);
      _enhanceResults();
      await Future.delayed(Duration(milliseconds: 500));
      
      // Step 6: Complete
      await _updateProgress('Processing complete!', 1.0);
      await Future.delayed(Duration(milliseconds: 500));
      
      // Navigate to results
      _navigateToResults();
      
    } catch (e) {
      setState(() {
        _errorMessage = 'OCR processing failed: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }
  
  // Update progress with animation
  Future<void> _updateProgress(String step, double progress) async {
    setState(() {
      _currentStep = step;
    });
    
    await _progressController.animateTo(progress);
    setState(() {
      _progress = progress;
    });
  }
  
  // Parse prices from recognized text
  List<ExtractedPrice> _parseprices(RecognizedText recognizedText) {
    List<ExtractedPrice> prices = [];
    
    // Price patterns (Jamaican currency)
    final pricePatterns = [
      RegExp(r'J?\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s*JMD', caseSensitive: false),
      RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\.00'), // Common price format
    ];
    
    // Item name patterns (words before prices)
    final itemPatterns = [
      RegExp(r'([A-Za-z\s]+)\s*[-:\s]\s*J?\$'),
      RegExp(r'([A-Za-z\s]{2,})\s+(\d+\.\d{2})'),
    ];
    
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String lineText = line.text;
        
        // Find prices in this line
        for (RegExp pattern in pricePatterns) {
          Iterable<RegExpMatch> matches = pattern.allMatches(lineText);
          
          for (RegExpMatch match in matches) {
            String priceStr = match.group(1) ?? match.group(0)!;
            double? price = _parsePrice(priceStr);
            
            if (price != null && price > 0 && price < 100000) {
              // Try to find item name
              String itemName = _extractItemName(lineText, match);
              
              // Calculate confidence based on context
              double confidence = _calculateConfidence(lineText, price);
              
              prices.add(ExtractedPrice(
                itemName: itemName,
                price: price,
                originalText: lineText,
                confidence: confidence,
                position: Rect.fromLTRB(
                  line.boundingBox.left.toDouble(),
                  line.boundingBox.top.toDouble(),
                  line.boundingBox.right.toDouble(),
                  line.boundingBox.bottom.toDouble(),
                ),
              ));
            }
          }
        }
      }
    }
    
    // Remove duplicates and sort by confidence
    prices = _removeDuplicates(prices);
    prices.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    return prices.take(10).toList(); // Limit to top 10 results
  }
  
  // Parse price string to double
  double? _parsePrice(String priceStr) {
    try {
      // Remove currency symbols and spaces
      String cleaned = priceStr.replaceAll(RegExp(r'[J\$,\s]'), '');
      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }
  
  // Extract item name from line text
  String _extractItemName(String lineText, RegExpMatch priceMatch) {
    // Get text before the price
    String beforePrice = lineText.substring(0, priceMatch.start).trim();
    
    if (beforePrice.isNotEmpty) {
      // Clean up the item name
      beforePrice = beforePrice.replaceAll(RegExp(r'[^\w\s\(\)]'), '').trim();
      
      // Capitalize first letter
      if (beforePrice.isNotEmpty) {
        return beforePrice[0].toUpperCase() + beforePrice.substring(1);
      }
    }
    
    // Fallback: try to get text after price
    String afterPrice = lineText.substring(priceMatch.end).trim();
    if (afterPrice.isNotEmpty && afterPrice.length < 30) {
      return afterPrice.replaceAll(RegExp(r'[^\w\s\(\)]'), '').trim();
    }
    
    return 'Unknown Item';
  }
  
  // Calculate confidence score for extracted price
  double _calculateConfidence(String lineText, double price) {
    double confidence = 0.5; // Base confidence
    
    // Higher confidence for properly formatted prices
    if (lineText.contains('J\$') || lineText.contains('JMD')) {
      confidence += 0.2;
    }
    
    // Higher confidence for reasonable price ranges
    if (price >= 10 && price <= 10000) {
      confidence += 0.1;
    }
    
    // Higher confidence for lines with item names
    if (lineText.split(' ').length >= 2) {
      confidence += 0.1;
    }
    
    // Lower confidence for very long lines (likely paragraph text)
    if (lineText.length > 100) {
      confidence -= 0.2;
    }
    
    return confidence.clamp(0.0, 1.0);
  }
  
  // Remove duplicate prices
  List<ExtractedPrice> _removeDuplicates(List<ExtractedPrice> prices) {
    Map<String, ExtractedPrice> uniquePrices = {};
    
    for (ExtractedPrice price in prices) {
      String key = '${price.price.toStringAsFixed(2)}_${price.itemName}';
      
      if (!uniquePrices.containsKey(key) || 
          uniquePrices[key]!.confidence < price.confidence) {
        uniquePrices[key] = price;
      }
    }
    
    return uniquePrices.values.toList();
  }
  
  // Enhance results with additional processing
  void _enhanceResults() {
    for (ExtractedPrice price in _extractedPrices) {
      // Auto-categorize items
      price.suggestedCategory = _categorizeItem(price.itemName);
      
      // Suggest common units
      price.suggestedUnit = _suggestUnit(price.itemName);
      
      // Format item name
      price.itemName = _formatItemName(price.itemName);
    }
  }
  
  // Auto-categorize items
  String _categorizeItem(String itemName) {
    String lower = itemName.toLowerCase();
    
    if (lower.contains('rice') || lower.contains('bread') || 
        lower.contains('flour') || lower.contains('sugar')) {
      return 'Groceries';
    } else if (lower.contains('chicken') || lower.contains('beef') ||
               lower.contains('pork') || lower.contains('fish')) {
      return 'Meat & Seafood';
    } else if (lower.contains('gas') || lower.contains('fuel') ||
               lower.contains('petrol') || lower.contains('diesel')) {
      return 'Fuel';
    } else if (lower.contains('milk') || lower.contains('cheese') ||
               lower.contains('yogurt') || lower.contains('butter')) {
      return 'Dairy';
    }
    
    return 'Other';
  }
  
  // Suggest unit for item
  String _suggestUnit(String itemName) {
    String lower = itemName.toLowerCase();
    
    if (lower.contains('lb') || lower.contains('pound')) {
      return 'per lb';
    } else if (lower.contains('kg') || lower.contains('kilo')) {
      return 'per kg';
    } else if (lower.contains('gal') || lower.contains('gallon')) {
      return 'per gallon';
    } else if (lower.contains('liter') || lower.contains('litre')) {
      return 'per liter';
    }
    
    return 'each';
  }
  
  // Format item name
  String _formatItemName(String itemName) {
    // Remove extra spaces and clean up
    itemName = itemName.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Capitalize words
    return itemName.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
  
  // Navigate to results screen
  void _navigateToResults() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OCRResultsScreen(
          imagePath: widget.imagePath,
          extractedPrices: _extractedPrices,
          fullText: _fullText,
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
        title: Text('Processing Image'),
        automaticallyImplyLeading: false, // Prevent back during processing
      ),
      
      body: _errorMessage != null 
          ? _buildErrorState() 
          : _buildProcessingState(),
    );
  }
  
  // Processing state UI
  Widget _buildProcessingState() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Processing animation
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color(0xFF1E3A8A),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.document_scanner,
                      size: 60,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                );
              },
            ),
            
            SizedBox(height: 32),
            
            // Progress text
            Text(
              _currentStep,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 24),
            
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
                    color: Color(0xFF1E3A8A),
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
              ),
            ),
            
            SizedBox(height: 48),
            
            // Processing tips
            _buildProcessingTips(),
          ],
        ),
      ),
    );
  }
  
  // Processing tips
  Widget _buildProcessingTips() {
    final tips = [
      'AI is analyzing your image for text',
      'Looking for prices and item names',
      'Identifying the best matches',
      'Almost done processing...',
    ];
    
    int tipIndex = (_progress * (tips.length - 1)).round();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.amber,
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
  
  // Error state UI
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
}

// Extracted Price Data Class
class ExtractedPrice {
  String itemName;
  double price;
  String originalText;
  double confidence;
  Rect position;
  String? suggestedCategory;
  String? suggestedUnit;
  
  ExtractedPrice({
    required this.itemName,
    required this.price,
    required this.originalText,
    required this.confidence,
    required this.position,
    this.suggestedCategory,
    this.suggestedUnit,
  });
}
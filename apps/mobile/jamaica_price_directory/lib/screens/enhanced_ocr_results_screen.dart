// lib/screens/enhanced_ocr_results_screen.dart
import 'package:flutter/material.dart';
import '../services/advanced_ocr_processor.dart';

class EnhancedOCRResultsScreen extends StatefulWidget {
  final String imagePath;
  final List<ExtractedPrice> extractedPrices;
  final String fullText;
  final bool isLongReceipt;
  final EnhancementType? bestEnhancement;
  final String? storeType;
  final Map<String, dynamic>? metadata;

  const EnhancedOCRResultsScreen({
    super.key,
    required this.imagePath,
    required this.extractedPrices,
    required this.fullText,
    this.isLongReceipt = false,
    this.bestEnhancement,
    this.storeType,
    this.metadata,
  });

  @override
  _EnhancedOCRResultsScreenState createState() => _EnhancedOCRResultsScreenState();
}

class _EnhancedOCRResultsScreenState extends State<EnhancedOCRResultsScreen>
    with TickerProviderStateMixin {
  late List<ExtractedPrice> _editablePrices;
  bool _isSubmitting = false;
  String? _selectedStore;
  String? _selectedParish;
  bool _showProcessingDetails = false;
  bool _showConfidenceDetails = false;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;

  final List<String> _stores = [
    'Hi-Lo', 'MegaMart', 'SuperPlus', 'PriceSmart', 'Shoppers Fair',
    'Progressive', 'Loshusan', 'Fontana', 'General Food', 'Other'
  ];

  final List<String> _parishes = [
    'Kingston', 'St. Andrew', 'St. Thomas', 'Portland', 'St. Mary',
    'St. Ann', 'Trelawny', 'St. James', 'Hanover', 'Westmoreland',
    'St. Elizabeth', 'Manchester', 'Clarendon', 'St. Catherine',
  ];

  @override
  void initState() {
    super.initState();
    _editablePrices = List.from(widget.extractedPrices);
    _selectedParish = 'Kingston';
    
    // Auto-detect store if possible
    _selectedStore = _detectStoreFromType(widget.storeType);
    
    _setupAnimations();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeController.forward();
  }

  String? _detectStoreFromType(String? storeType) {
    if (storeType == null) return null;
    
    switch (storeType.toLowerCase()) {
      case 'hi-lo':
        return 'Hi-Lo';
      case 'megamart':
        return 'MegaMart';
      case 'pricesmart':
        return 'PriceSmart';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.isLongReceipt ? 'Long Receipt Results' : 'OCR Results'),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _showProcessingDetails = !_showProcessingDetails),
            icon: Icon(Icons.analytics),
            tooltip: 'Processing Details',
          ),
          IconButton(
            onPressed: _viewFullText,
            icon: Icon(Icons.text_fields),
            tooltip: 'View Full Text',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: Column(
          children: [
            if (_showProcessingDetails) _buildProcessingDetails(),
            _buildStoreSelection(),
            _buildResultsSummary(),
            Expanded(
              child: _buildPricesList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildProcessingDetails() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: _showProcessingDetails ? null : 0,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Processing Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticItem(
                    'Enhancement',
                    _getEnhancementDisplayName(widget.bestEnhancement),
                    Icons.auto_fix_high,
                  ),
                ),
                Expanded(
                  child: _buildAnalyticItem(
                    'Store Type',
                    widget.storeType?.toUpperCase() ?? 'GENERIC',
                    Icons.store,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticItem(
                    'Processing Time',
                    '${widget.metadata?['total_time_ms'] ?? 0}ms',
                    Icons.timer,
                  ),
                ),
                Expanded(
                  child: _buildAnalyticItem(
                    'Attempts',
                    '${widget.metadata?['processing_attempts'] ?? 0}',
                    Icons.refresh,
                  ),
                ),
              ],
            ),
            if (widget.metadata?['orientation_corrected'] == true) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.rotate_right, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Orientation was automatically corrected',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticItem(String label, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getEnhancementDisplayName(EnhancementType? enhancement) {
    switch (enhancement) {
      case EnhancementType.original:
        return 'Original';
      case EnhancementType.contrast:
        return 'High Contrast';
      case EnhancementType.brightness:
        return 'Brightness';
      case EnhancementType.sharpen:
        return 'Edge Enhanced';
      case EnhancementType.grayscale:
        return 'Grayscale';
      case EnhancementType.binarize:
        return 'Binary Threshold';
      default:
        return 'Standard';
    }
  }

  Widget _buildStoreSelection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Text(
                'Store Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              if (_selectedStore != null) ...[
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Auto-detected',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStore,
                  decoration: InputDecoration(
                    labelText: 'Store Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.store),
                  ),
                  items: _stores.map((store) {
                    return DropdownMenuItem(value: store, child: Text(store));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStore = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedParish,
                  decoration: InputDecoration(
                    labelText: 'Parish',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: _parishes.map((parish) {
                    return DropdownMenuItem(value: parish, child: Text(parish));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedParish = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSummary() {
    final avgConfidence = _editablePrices.isNotEmpty
        ? _editablePrices.map((p) => p.confidence).reduce((a, b) => a + b) / _editablePrices.length
        : 0.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _editablePrices.isEmpty ? Colors.red[50] : Colors.green[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _editablePrices.isEmpty ? Icons.warning : Icons.check_circle,
                color: _editablePrices.isEmpty ? Colors.red : Colors.green,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editablePrices.isEmpty 
                        ? 'No prices detected'
                        : '${_editablePrices.length} price${_editablePrices.length == 1 ? '' : 's'} extracted',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _editablePrices.isEmpty ? Colors.red[700] : Colors.green[700],
                      ),
                    ),
                    if (_editablePrices.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        'Average confidence: ${(avgConfidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (widget.isLongReceipt)
                        Text(
                          'Long receipt processed successfully',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showConfidenceDetails = !_showConfidenceDetails),
                    icon: Icon(Icons.analytics, size: 16),
                    label: Text('Details'),
                  ),
                  TextButton.icon(
                    onPressed: _addManualPrice,
                    icon: Icon(Icons.add),
                    label: Text('Add Price'),
                  ),
                ],
              ),
            ],
          ),
          if (_showConfidenceDetails && _editablePrices.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildConfidenceBreakdown(),
          ],
        ],
      ),
    );
  }

  Widget _buildConfidenceBreakdown() {
    final highConfidence = _editablePrices.where((p) => p.confidence >= 0.8).length;
    final mediumConfidence = _editablePrices.where((p) => p.confidence >= 0.6 && p.confidence < 0.8).length;
    final lowConfidence = _editablePrices.where((p) => p.confidence < 0.6).length;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confidence Distribution',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildConfidenceBar('High (80%+)', highConfidence, Colors.green),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildConfidenceBar('Medium (60-80%)', mediumConfidence, Colors.orange),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildConfidenceBar('Low (<60%)', lowConfidence, Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 18,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPricesList() {
    if (_editablePrices.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _editablePrices.length,
      itemBuilder: (context, index) {
        return _buildEnhancedPriceCard(index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No prices detected',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.isLongReceipt 
              ? 'The receipt sections might not contain clear price information.\nTry capturing with better lighting or add prices manually.'
              : 'The image might not contain clear price information.\nYou can add prices manually.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addManualPrice,
            icon: Icon(Icons.add),
            label: Text('Add Price Manually'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPriceCard(int index) {
    ExtractedPrice price = _editablePrices[index];
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(price.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Icon(
                      _getCategoryIcon(price.category),
                      color: _getCategoryColor(price.category),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          price.itemName.isEmpty ? 'Item ${index + 1}' : price.itemName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(price.category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            price.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: _getCategoryColor(price.category),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildEnhancedConfidenceBadge(price.confidence),
                ],
              ),
              
              SizedBox(height: 12),
              
              Row(
                children: [
                  Text(
                    'J\$${price.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  if (price.unit.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        price.unit,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                  Spacer(),
                  _buildPriceActions(index),
                ],
              ),
              
              SizedBox(height: 12),
              
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          'Original Text:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '"${price.originalText}"',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedConfidenceBadge(double confidence) {
    Color color;
    String text;
    IconData icon;
    
    if (confidence >= 0.9) {
      color = Colors.green;
      text = 'Excellent';
      icon = Icons.verified;
    } else if (confidence >= 0.8) {
      color = Colors.lightGreen;
      text = 'High';
      icon = Icons.check_circle;
    } else if (confidence >= 0.6) {
      color = Colors.orange;
      text = 'Medium';
      icon = Icons.warning;
    } else {
      color = Colors.red;
      text = 'Low';
      icon = Icons.error;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 4),
          Column(
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceActions(int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _editPriceItem(index),
          icon: Icon(Icons.edit, size: 20),
          tooltip: 'Edit',
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.withOpacity(0.1),
            foregroundColor: Colors.blue,
          ),
        ),
        SizedBox(width: 8),
        IconButton(
          onPressed: () => _removePriceItem(index),
          icon: Icon(Icons.delete, size: 20),
          tooltip: 'Remove',
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
            foregroundColor: Colors.red,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Colors.green;
      case 'meat':
        return Colors.red;
      case 'beverages':
        return Colors.blue;
      case 'dairy':
        return Colors.orange;
      case 'produce':
        return Colors.lightGreen;
      case 'household':
        return Colors.purple;
      case 'health':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Icons.shopping_basket;
      case 'meat':
        return Icons.set_meal;
      case 'beverages':
        return Icons.local_drink;
      case 'dairy':
        return Icons.local_drink_rounded;
      case 'produce':
        return Icons.eco;
      case 'household':
        return Icons.home;
      case 'health':
        return Icons.medical_services;
      default:
        return Icons.category;
    }
  }

  void _editPriceItem(int index) {
    ExtractedPrice price = _editablePrices[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _buildEditPriceModal(price, index),
    );
  }

  void _removePriceItem(int index) {
    setState(() {
      _editablePrices.removeAt(index);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Price removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Implement undo functionality
          },
        ),
      ),
    );
  }

  void _addManualPrice() {
    ExtractedPrice newPrice = ExtractedPrice(
      itemName: '',
      price: 0.0,
      originalText: 'Manual Entry',
      confidence: 1.0,
      position: Rect.zero,
      category: 'Other',
      unit: 'each',
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _buildEditPriceModal(newPrice, -1),
    );
  }

  Widget _buildEditPriceModal(ExtractedPrice price, int index) {
    final nameController = TextEditingController(text: price.itemName);
    final priceController = TextEditingController(text: price.price.toString());
    String selectedCategory = price.category;
    String selectedUnit = price.unit;
    
    final categories = ['Groceries', 'Meat', 'Beverages', 'Dairy', 'Produce', 'Household', 'Health', 'Other'];
    final units = ['each', 'per lb', 'per kg', 'per gallon', 'per liter', 'per pack'];
    
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      index == -1 ? Icons.add : Icons.edit,
                      color: Color(0xFF1E3A8A),
                    ),
                    SizedBox(width: 12),
                    Text(
                      index == -1 ? 'Add New Price' : 'Edit Price',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.shopping_basket),
                  ),
                ),
                SizedBox(height: 16),
                
                TextFormField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Price (JMD)',
                    prefixText: 'J\$',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat, 
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(cat), size: 16, color: _getCategoryColor(cat)),
                                SizedBox(width: 8),
                                Text(cat),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: Icon(Icons.straighten),
                        ),
                        items: units.map((unit) {
                          return DropdownMenuItem(value: unit, child: Text(unit));
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedUnit = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameController.text.isNotEmpty && 
                              priceController.text.isNotEmpty) {
                            ExtractedPrice updatedPrice = ExtractedPrice(
                              itemName: nameController.text,
                              price: double.tryParse(priceController.text) ?? 0.0,
                              originalText: price.originalText,
                              confidence: index == -1 ? 1.0 : price.confidence,
                              position: price.position,
                              category: selectedCategory,
                              unit: selectedUnit,
                            );
                            
                            setState(() {
                              if (index == -1) {
                                _editablePrices.add(updatedPrice);
                              } else {
                                _editablePrices[index] = updatedPrice;
                              }
                            });
                            
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1E3A8A),
                        ),
                        child: Text(index == -1 ? 'Add' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewFullText() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.text_fields),
            SizedBox(width: 8),
            Text('Extracted Text'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              widget.fullText.isEmpty ? 'No text extracted' : widget.fullText,
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPrices() async {
    if (_editablePrices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No prices to submit')),
      );
      return;
    }
    
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a store')),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Simulate API call
      await Future.delayed(Duration(seconds: 2));
      
      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_editablePrices.length} prices submitted successfully!'),
            SizedBox(height: 8),
            Text(
              'Thank you for contributing to the Jamaica Price Directory.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (widget.isLongReceipt) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Long receipt processed with advanced OCR technology',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isSubmitting || _editablePrices.isEmpty || _selectedStore == null
              ? null
              : _submitPrices,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1E3A8A),
            padding: EdgeInsets.symmetric(vertical: 16),
            minimumSize: Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSubmitting
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Submitting...', style: TextStyle(fontSize: 16)),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 8),
                    Text(
                      'Submit ${_editablePrices.length} Price${_editablePrices.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
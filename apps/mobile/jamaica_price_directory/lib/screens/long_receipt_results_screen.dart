import 'package:flutter/material.dart';
import 'dart:io';

import '../services/consolidated_ocr_service.dart';

class LongReceiptResultsScreen extends StatefulWidget {
  final List<ReceiptSection> sections;
  final MergedReceiptResult mergedResult;

  const LongReceiptResultsScreen({
    super.key,
    required this.sections,
    required this.mergedResult,
  });

  @override
  State<LongReceiptResultsScreen> createState() =>
      _LongReceiptResultsScreenState();
}

class _LongReceiptResultsScreenState extends State<LongReceiptResultsScreen> {
  bool _isSubmitting = false;
  String? _selectedStore;
  String? _selectedParish;

  final List<String> _stores = [
    'Hi-Lo',
    'MegaMart',
    'SuperPlus',
    'PriceSmart',
    'Shoppers Fair',
    'Progressive',
    'Loshusan',
    'Fontana',
    'General Food',
    'Other',
  ];

  final List<String> _parishes = [
    'Kingston',
    'St. Andrew',
    'St. Thomas',
    'Portland',
    'St. Mary',
    'St. Ann',
    'Trelawny',
    'St. James',
    'Hanover',
    'Westmoreland',
    'St. Elizabeth',
    'Manchester',
    'Clarendon',
    'St. Catherine',
  ];

  @override
  void initState() {
    super.initState();
    _selectedParish = 'Kingston';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Long Receipt Results'),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _viewSections,
            icon: Icon(Icons.photo_library),
            tooltip: 'View Sections',
          ),
          IconButton(
            onPressed: _viewFullText,
            icon: Icon(Icons.text_fields),
            tooltip: 'View Full Text',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStoreSelection(),
          _buildReceiptSummary(),
          Expanded(child: _buildPricesList()),
        ],
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildStoreSelection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
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
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedStore,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Store Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      prefixIcon: Icon(Icons.store),
                      isCollapsed: false,
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
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedParish,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Parish',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      prefixIcon: Icon(Icons.location_on),
                      isCollapsed: false,
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptSummary() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(Icons.receipt_long, color: Colors.white, size: 30),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Long Receipt Processed',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Advanced OCR with section merging',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.9 * 255).round()),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.15 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Sections',
                    '${widget.mergedResult.totalSections}',
                    Icons.view_module,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Items Found',
                    '${widget.mergedResult.prices.length}',
                    Icons.list_alt,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withAlpha((0.3 * 255).round()),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Confidence',
                    '${(widget.mergedResult.confidence * 100).toStringAsFixed(1)}%',
                    Icons.verified,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withAlpha((0.9 * 255).round())),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPricesList() {
    if (widget.mergedResult.prices.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: widget.mergedResult.prices.length,
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
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No prices detected',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'The receipt sections might not contain clear price information.\nTry capturing with better lighting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1E3A8A)),
            child: Text('Retake Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPriceCard(int index) {
    ExtractedPrice price = widget.mergedResult.prices[index];

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
                      color: _getCategoryColor(price.category).withAlpha((0.1 * 255).round()),
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
                          price.itemName.isEmpty
                              ? 'Item ${index + 1}'
                              : price.itemName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(
                              price.category,
                            ).withAlpha((0.1 * 255).round()),
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
                  _buildConfidenceBadge(price.confidence),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                  Spacer(),
                  IconButton(
                    onPressed: () => _editPriceItem(index),
                    icon: Icon(Icons.edit, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.withAlpha((0.1 * 255).round()),
                      foregroundColor: Colors.blue,
                    ),
                  ),
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
                        Icon(
                          Icons.format_quote,
                          size: 16,
                          color: Colors.grey[600],
                        ),
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

  Widget _buildConfidenceBadge(double confidence) {
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
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
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
                style: TextStyle(fontSize: 10, color: color),
              ),
            ],
          ),
        ],
      ),
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
    // Implementation similar to the one in enhanced_ocr_results_screen.dart
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _buildEditPriceModal(widget.mergedResult.prices[index], index),
    );
  }

  Widget _buildEditPriceModal(ExtractedPrice price, int index) {
    final nameController = TextEditingController(text: price.itemName);
    final priceController = TextEditingController(text: price.price.toString());
    String selectedCategory = price.category;
    String selectedUnit = price.unit;

    final categories = [
      'Groceries',
      'Meat',
      'Beverages',
      'Dairy',
      'Produce',
      'Household',
      'Health',
      'Other',
    ];
    final units = [
      'each',
      'per lb',
      'per kg',
      'per gallon',
      'per liter',
      'per pack',
    ];

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
                    Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 12),
                    Text(
                      'Edit Price',
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.shopping_basket),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Price (JMD)',
                    prefixText: 'J\$',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(cat),
                                  size: 16,
                                  color: _getCategoryColor(cat),
                                ),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.straighten),
                        ),
                        items: units.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
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
                            // Update the price in the list
                            // In a real implementation, you'd update the actual data
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Price updated successfully'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1E3A8A),
                        ),
                        child: Text('Save'),
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

  void _viewSections() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.photo_library),
            SizedBox(width: 8),
            Text('Receipt Sections'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: widget.sections.length,
            itemBuilder: (context, index) {
              final section = widget.sections[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(section.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.error, color: Colors.red);
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Section ${section.sectionNumber}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Captured: ${_formatTimestamp(section.timestamp)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
              widget.mergedResult.fullText.isEmpty
                  ? 'No text extracted'
                  : widget.mergedResult.fullText,
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _submitPrices() async {
    if (widget.mergedResult.prices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No prices to submit')));
      return;
    }

    if (_selectedStore == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a store')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Simulate submission
      await Future.delayed(Duration(seconds: 2));

      _showSuccessDialog();
    } catch (e) {
      // Before using `context` here, make sure we're still mounted:
      if (!mounted) return;
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
            Text(
              '${widget.mergedResult.prices.length} prices submitted successfully!',
            ),
            SizedBox(height: 8),
            Text(
              'Thank you for contributing to the Jamaica Price Directory.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Long receipt processed with ${widget.mergedResult.totalSections} sections',
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ),
                ],
              ),
            ),
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
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed:
              _isSubmitting ||
                  widget.mergedResult.prices.isEmpty ||
                  _selectedStore == null
              ? null
              : _submitPrices,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF059669),
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
                    Text(
                      'Submitting Long Receipt...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 8),
                    Text(
                      'Submit ${widget.mergedResult.prices.length} Price${widget.mergedResult.prices.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Support classes that should be in your data models
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

import 'package:flutter/material.dart';
import 'package:jamaica_price_directory/services/advanced_ocr_processor.dart';

// OCR Results Screen - Review and submit extracted prices
class OCRResultsScreen extends StatefulWidget {
  final String imagePath;
  final List<ExtractedPrice> extractedPrices;
  final String fullText;
  
  const OCRResultsScreen({super.key, 
    required this.imagePath,
    required this.extractedPrices,
    required this.fullText, required bool isLongReceipt,
  });
  
  @override
  _OCRResultsScreenState createState() => _OCRResultsScreenState();
}

class _OCRResultsScreenState extends State<OCRResultsScreen> {
  late List<ExtractedPrice> _editablePrices;
  bool _isSubmitting = false;
  String? _selectedStore;
  String? _selectedParish;
  
  // Mock store and parish data
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
    _selectedParish = 'Kingston'; // Default
  }
  
  // Submit all prices
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
      // Simulate API submission
      await Future.delayed(Duration(seconds: 2));
      
      // Show success dialog
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
  
  // Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).popUntil((route) => route.isFirst); // Go to main app
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }
  
  // Edit price item
  void _editPriceItem(int index) {
    ExtractedPrice price = _editablePrices[index];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _buildEditPriceModal(price, index),
    );
  }
  
  // Remove price item
  void _removePriceItem(int index) {
    setState(() {
      _editablePrices.removeAt(index);
    });
  }
  
  // Add manual price
  void _addManualPrice() {
    ExtractedPrice newPrice = ExtractedPrice(
      itemName: '',
      price: 0.0,
      originalText: 'Manual Entry',
      confidence: 1.0,
      position: Rect.zero,
      category: '', unit: '',
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _buildEditPriceModal(newPrice, -1), // -1 indicates new item
    );
  }
  
  // View full extracted text
  void _viewFullText() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Extracted Text'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Text(widget.fullText.isEmpty ? 'No text extracted' : widget.fullText),
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      appBar: AppBar(
        title: Text('Review Results'),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _viewFullText,
            icon: Icon(Icons.text_fields),
            tooltip: 'View Full Text',
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Store and location selection
          _buildStoreSelection(),
          
          // Results summary
          _buildResultsSummary(),
          
          // Extracted prices list
          Expanded(
            child: _buildPricesList(),
          ),
        ],
      ),
      
      // Submit button
      bottomNavigationBar: _buildSubmitButton(),
    );
  }
  
  // Store and location selection
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
          Text(
            'Store Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          
          Row(
            children: [
              // Store dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStore,
                  decoration: InputDecoration(
                    labelText: 'Store Name',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              
              // Parish dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedParish,
                  decoration: InputDecoration(
                    labelText: 'Parish',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  
  // Results summary
  Widget _buildResultsSummary() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _editablePrices.isEmpty ? Colors.red[50] : Colors.green[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _editablePrices.isEmpty ? Icons.warning : Icons.check_circle,
            color: _editablePrices.isEmpty ? Colors.red : Colors.green,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editablePrices.isEmpty 
                      ? 'No prices found'
                      : 'Found ${_editablePrices.length} price${_editablePrices.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _editablePrices.isEmpty ? Colors.red[700] : Colors.green[700],
                  ),
                ),
                if (_editablePrices.isNotEmpty)
                  Text(
                    'Review and edit before submitting',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _addManualPrice,
            icon: Icon(Icons.add),
            label: Text('Add Price'),
          ),
        ],
      ),
    );
  }
  
  // Prices list
  Widget _buildPricesList() {
    if (_editablePrices.isEmpty) {
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
              'The image might not contain clear price information.\nYou can add prices manually.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addManualPrice,
              icon: Icon(Icons.add),
              label: Text('Add Price Manually'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _editablePrices.length,
      itemBuilder: (context, index) {
        return _buildPriceCard(index);
      },
    );
  }
  
  // Individual price card
  Widget _buildPriceCard(int index) {
    ExtractedPrice price = _editablePrices[index];
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with confidence
              Row(
                children: [
                  Expanded(
                    child: Text(
                      price.itemName.isEmpty ? 'Item ${index + 1}' : price.itemName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildConfidenceBadge(price.confidence),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Price and details
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
                  Spacer(),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Original text
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Original: "${price.originalText}"',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _removePriceItem(index),
                    icon: Icon(Icons.delete, size: 16),
                    label: Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _editPriceItem(index),
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Confidence badge
  Widget _buildConfidenceBadge(double confidence) {
    Color color;
    String text;
    
    if (confidence >= 0.8) {
      color = Colors.green;
      text = 'High';
    } else if (confidence >= 0.6) {
      color = Colors.orange;
      text = 'Medium';
    } else {
      color = Colors.red;
      text = 'Low';
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  // Edit price modal
  Widget _buildEditPriceModal(ExtractedPrice price, int index) {
    final nameController = TextEditingController(text: price.itemName);
    final priceController = TextEditingController(text: price.price.toString());
    final categories = ['Groceries', 'Meat & Seafood', 'Dairy', 'Fuel', 'Other'];
    final units = ['each', 'per lb', 'per kg', 'per gallon', 'per liter'];
    
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
                Text(
                  index == -1 ? 'Add New Price' : 'Edit Price',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Item name
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Price
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Price (JMD)',
                    prefixText: 'J\$',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                
                SizedBox(height: 16),
                
                // Category and unit
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                      
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            
                          });
                        },
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: units.map((unit) {
                          return DropdownMenuItem(value: unit, child: Text(unit));
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            
                          });
                        },
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                
                // Action buttons
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
                          // Validate and save
                          if (nameController.text.isNotEmpty && 
                              priceController.text.isNotEmpty) {
                            
                            ExtractedPrice updatedPrice = ExtractedPrice(
                              itemName: nameController.text,
                              price: double.tryParse(priceController.text) ?? 0.0,
                              originalText: price.originalText,
                              confidence: index == -1 ? 1.0 : price.confidence,
                              position: price.position, category: price.category, unit: price.unit,
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
  
  // Submit button
  Widget _buildSubmitButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
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
                    Text('Submitting...'),
                  ],
                )
              : Text(
                  'Submit ${_editablePrices.length} Price${_editablePrices.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}
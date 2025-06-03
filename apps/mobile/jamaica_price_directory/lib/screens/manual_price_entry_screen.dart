import 'package:flutter/material.dart';

class ManualPriceEntryScreen extends StatefulWidget {
  const ManualPriceEntryScreen({super.key});

  @override
  State<ManualPriceEntryScreen> createState() => _ManualPriceEntryScreenState();
}

class _ManualPriceEntryScreenState extends State<ManualPriceEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _priceController = TextEditingController();
  final _storeController = TextEditingController();
  
  String? selectedParish = 'Kingston';
  String? selectedCategory = 'Groceries';
  bool _isSubmitting = false;

  final List<String> parishes = [
    'Kingston', 'St. Andrew', 'St. Thomas', 'Portland', 'St. Mary',
    'St. Ann', 'Trelawny', 'St. James', 'Hanover', 'Westmoreland',
    'St. Elizabeth', 'Manchester', 'Clarendon', 'St. Catherine',
  ];

  final List<String> categories = [
    'Groceries', 'Fuel', 'Utilities', 'Electronics', 'Pharmacy',
    'Restaurants', 'Transport', 'Services',
  ];

  void _submitPrice() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Simulate API call
        await Future.delayed(Duration(seconds: 2));
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Price Submitted!'),
                ],
              ),
              content: Text('Thank you for contributing. Your submission is being reviewed.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pop(context);
                  },
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit price. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manual Price Entry'),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Entry',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Add price information directly',
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
              ),
              
              SizedBox(height: 24),
              
              // Form fields
              TextFormField(
                controller: _itemController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., Rice (1 lb)',
                  prefixIcon: Icon(Icons.shopping_basket),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price (JMD)',
                  hintText: 'e.g., 120.00',
                  prefixText: 'J\$',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              TextFormField(
                controller: _storeController,
                decoration: InputDecoration(
                  labelText: 'Store Name',
                  hintText: 'e.g., Hi-Lo',
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter store name';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: selectedParish,
                decoration: InputDecoration(
                  labelText: 'Parish',
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: parishes.map((parish) {
                  return DropdownMenuItem(value: parish, child: Text(parish));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedParish = value;
                  });
                },
              ),
              
              SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(value: category, child: Text(category));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),
              
              SizedBox(height: 32),
              
              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPrice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
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
                        Text('Submitting...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload),
                        SizedBox(width: 8),
                        Text(
                          'Submit Price',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
              ),
              
              SizedBox(height: 16),
              
              // Info section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Manual Entry Guidelines',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Double-check all information for accuracy\n'
                      '• Include unit information in item name if relevant\n'
                      '• Use current prices from recent visits\n'
                      '• Verify store name and location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[600],
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

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    _storeController.dispose();
    super.dispose();
  }
}
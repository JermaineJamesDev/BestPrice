import 'package:flutter/material.dart';
import 'camera_capture_screen.dart';

// Camera Screen - For submitting prices via photos and manual entry
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  
  // Handle taking a photo
  void _takePhoto() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraCaptureScreen(),
      ),
    );
  }
  
  // Handle manual price entry
  void _manualEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualPriceEntryScreen(),
      ),
    );
  }
  
  // Handle uploading from gallery
  void _uploadFromGallery() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gallery upload feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      appBar: AppBar(
        title: Text('Submit Price'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            _buildHeaderSection(),
            
            SizedBox(height: 32),
            
            // Main action buttons
            _buildActionButtons(),
            
            SizedBox(height: 32),
            
            // How it works section
            _buildHowItWorksSection(),
            
            SizedBox(height: 32),
            
            // Recent submissions
            _buildRecentSubmissions(),
          ],
        ),
      ),
    );
  }
  
  // Header section
  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.camera_alt,
                size: 32,
                color: Color(0xFF1E3A8A),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Help Build Jamaica\'s Price Database',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Submit prices to help other Jamaicans save money. Every contribution makes a difference!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('156', 'Your\nSubmissions'),
              _buildStatItem('89%', 'Accuracy\nRate'),
              _buildStatItem('1,247', 'People\nHelped'),
            ],
          ),
        ],
      ),
    );
  }
  
  // Stat item widget
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  // Main action buttons
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Take photo button
        InkWell(
          onTap: _takePhoto,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF1E3A8A).withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 12),
                Text(
                  'Take Photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Scan receipts or price tags automatically',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        // Manual entry and gallery buttons
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                icon: Icons.edit,
                label: 'Manual Entry',
                subtitle: 'Type prices directly',
                onTap: _manualEntry,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                icon: Icons.photo_library,
                label: 'From Gallery',
                subtitle: 'Upload existing photos',
                onTap: _uploadFromGallery,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Secondary button widget
  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: Color(0xFF1E3A8A),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // How it works section
  Widget _buildHowItWorksSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How It Works',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          
          _buildHowItWorksStep(
            '1',
            'Take or Upload Photo',
            'Snap a photo of a receipt, price tag, or product label',
            Icons.camera_alt,
          ),
          
          _buildHowItWorksStep(
            '2',
            'AI Extracts Prices',
            'Our AI automatically reads and extracts price information',
            Icons.auto_awesome,
          ),
          
          _buildHowItWorksStep(
            '3',
            'Verify & Submit',
            'Review the information and submit to help others',
            Icons.check_circle,
          ),
          
          _buildHowItWorksStep(
            '4',
            'Earn Points',
            'Get points for contributions and accurate submissions',
            Icons.stars,
          ),
        ],
      ),
    );
  }
  
  // How it works step widget
  Widget _buildHowItWorksStep(String step, String title, String description, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Icon(
            icon,
            color: Color(0xFF1E3A8A),
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Recent submissions section
  Widget _buildRecentSubmissions() {
    final List<Map<String, dynamic>> recentSubmissions = [
      {
        'item': 'Rice (1 lb)',
        'store': 'Hi-Lo Kingston',
        'price': 'J\$120',
        'status': 'Verified',
        'date': '2 hours ago',
      },
      {
        'item': 'Chicken breast',
        'store': 'MegaMart',
        'price': 'J\$320',
        'status': 'Pending',
        'date': '1 day ago',
      },
      {
        'item': 'Gas (Regular)',
        'store': 'Petcom',
        'price': 'J\$195',
        'status': 'Verified',
        'date': '3 days ago',
      },
    ];
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Recent Submissions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Full submission history coming soon!')),
                  );
                },
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          ...recentSubmissions.map((submission) {
            return Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission['item'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          submission['store'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        submission['price'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: submission['status'] == 'Verified' 
                                  ? Colors.green 
                                  : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            submission['status'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Manual Price Entry Screen (placeholder)
class ManualPriceEntryScreen extends StatefulWidget {
  const ManualPriceEntryScreen({super.key});

  @override
  _ManualPriceEntryScreenState createState() => _ManualPriceEntryScreenState();
}

class _ManualPriceEntryScreenState extends State<ManualPriceEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemController = TextEditingController();
  final _priceController = TextEditingController();
  final _storeController = TextEditingController();
  
  String? selectedParish = 'Kingston';
  String? selectedCategory = 'Groceries';
  
  final List<String> parishes = [
    'Kingston', 'St. Andrew', 'St. Thomas', 'Portland', 'St. Mary',
    'St. Ann', 'Trelawny', 'St. James', 'Hanover', 'Westmoreland',
    'St. Elizabeth', 'Manchester', 'Clarendon', 'St. Catherine',
  ];
  
  final List<String> categories = [
    'Groceries', 'Fuel', 'Utilities', 'Electronics', 'Pharmacy',
    'Restaurants', 'Transport', 'Services',
  ];
  
  void _submitPrice() {
    if (_formKey.currentState!.validate()) {
      // Mock submission
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Price Submitted!'),
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
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manual Price Entry'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _itemController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., Rice (1 lb)',
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
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
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
                decoration: InputDecoration(labelText: 'Parish'),
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
                decoration: InputDecoration(labelText: 'Category'),
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
              
              ElevatedButton(
                onPressed: _submitPrice,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Submit Price'),
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
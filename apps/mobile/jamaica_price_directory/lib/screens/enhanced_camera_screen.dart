import 'package:flutter/material.dart';
import 'package:jamaica_price_directory/screens/manual_price_entry_screen.dart';
import 'camera_capture_screen.dart';
import 'gallery_picker_screen.dart';
import 'long_receipt_capture_screen.dart';

class EnhancedCameraScreen extends StatefulWidget {
  const EnhancedCameraScreen({super.key});

  @override
  State<EnhancedCameraScreen> createState() => _EnhancedCameraScreenState();
}

class _EnhancedCameraScreenState extends State<EnhancedCameraScreen> {
  void _takePhoto() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraCaptureScreen()),
    );
  }

  void _takeLongReceiptPhoto() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LongReceiptCaptureScreen()),
    );
  }

  void _manualEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ManualPriceEntryScreen()),
    );
  }

  void _uploadFromGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GalleryPickerScreen()),
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
            _buildHeaderSection(),
            SizedBox(height: 32),
            _buildActionButtons(),
            SizedBox(height: 32),
            _buildReceiptTypeGuide(),
            SizedBox(height: 32),
            _buildHowItWorksSection(),
            SizedBox(height: 32),
            _buildRecentSubmissions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
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
              Icon(Icons.camera_alt, size: 32, color: Color(0xFF1E3A8A)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI-Powered Receipt Scanning',
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
            'Our advanced OCR technology can read any receipt format with multiple enhancement techniques for maximum accuracy.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('95%', 'Accuracy\nRate'),
              _buildStatItem('6', 'Enhancement\nMethods'),
              _buildStatItem('<5s', 'Processing\nTime'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
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
                  color: Color(0xFF1E3A8A).withAlpha((0.3 * 255).round()),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.camera_alt, size: 48, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'Standard Receipt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Single capture for regular-sized receipts',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha((0.9 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        InkWell(
          onTap: _takeLongReceiptPhoto,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF059669).withAlpha((0.3 * 255).round()),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'Long Receipt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Multi-section capture for extra long receipts',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha((0.9 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
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
                subtitle: 'Upload existing photos', // Updated subtitle
                onTap: _uploadFromGallery, // Now calls actual functionality
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReceiptTypeGuide() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
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
            'Which Option Should I Use?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildReceiptTypeItem(
            'Standard Receipt',
            'For receipts that fit in one photo',
            'Supermarket receipts, restaurant bills, single-page invoices',
            Icons.receipt,
            Color(0xFF1E3A8A),
          ),
          SizedBox(height: 12),
          _buildReceiptTypeItem(
            'Long Receipt',
            'For very long receipts requiring multiple photos',
            'Large grocery shopping, wholesale purchases, detailed itemized bills',
            Icons.receipt_long,
            Color(0xFF059669),
          ),
          SizedBox(height: 12),
          _buildReceiptTypeItem(
            'From Gallery',
            'For existing receipt photos on your device',
            'Previously taken photos, screenshots, multiple images at once',
            Icons.photo_library,
            Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTypeItem(
    String title,
    String subtitle,
    String examples,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha((0.2 * 255).round())),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                SizedBox(height: 4),
                Text(
                  'Examples: $examples',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

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
          border: Border.all(color: Color(0xFF1E3A8A).withAlpha((0.2 * 255).round())),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha((0.1 * 255).round()),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Color(0xFF1E3A8A)),
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
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
            'Advanced OCR Technology',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _buildHowItWorksStep(
            '1',
            'Smart Image Enhancement',
            'Apply 6 different enhancement techniques automatically',
            Icons.auto_fix_high,
          ),
          _buildHowItWorksStep(
            '2',
            'Multi-Pass OCR Processing',
            'Process with multiple algorithms and select best result',
            Icons.scanner,
          ),
          _buildHowItWorksStep(
            '3',
            'Intelligent Price Extraction',
            'Advanced pattern recognition for various receipt formats',
            Icons.psychology,
          ),
          _buildHowItWorksStep(
            '4',
            'Confidence Scoring',
            'Rate extraction accuracy and allow manual verification',
            Icons.verified,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(
    String step,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF1E3A8A).withAlpha((0.1 * 255).round()),
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
          Icon(icon, color: Color(0xFF1E3A8A), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSubmissions() {
    final List<Map<String, dynamic>> recentSubmissions = [
      {
        'item': 'Gallery Import (8 images)',
        'store': 'Hi-Lo Kingston',
        'sections': 8,
        'status': 'Verified',
        'date': '30 minutes ago',
        'confidence': 96.2,
        'type': 'gallery',
      },
      {
        'item': 'Long Receipt (15 items)',
        'store': 'MegaMart Spanish Town',
        'sections': 3,
        'status': 'Verified',
        'date': '1 hour ago',
        'confidence': 94.5,
        'type': 'long',
      },
      {
        'item': 'Standard Receipt (5 items)',
        'store': 'Hi-Lo Kingston',
        'sections': 1,
        'status': 'Verified',
        'date': '3 hours ago',
        'confidence': 97.8,
        'type': 'standard',
      },
      {
        'item': 'Gallery Import (3 images)',
        'store': 'PriceSmart Portmore',
        'sections': 3,
        'status': 'Pending',
        'date': '1 day ago',
        'confidence': 92.1,
        'type': 'gallery',
      },
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
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
                'Recent OCR Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Full submission history coming soon!'),
                    ),
                  );
                },
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...recentSubmissions.map((submission) {
            IconData iconData;
            Color iconColor;

            switch (submission['type']) {
              case 'gallery':
                iconData = Icons.photo_library;
                iconColor = Color(0xFF7C3AED);
                break;
              case 'long':
                iconData = Icons.receipt_long;
                iconColor = Color(0xFF059669);
                break;
              default:
                iconData = Icons.receipt;
                iconColor = Color(0xFF1E3A8A);
            }

            return Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(iconData, color: iconColor),
                  SizedBox(width: 12),
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
                          '${submission['store']} • ${submission['sections']} ${submission['type'] == 'gallery' ? 'image' : 'section'}${submission['sections'] > 1 ? 's' : ''}',
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
                        '${submission['confidence']}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: submission['confidence'] >= 95
                              ? Colors.green
                              : submission['confidence'] >= 90
                              ? Colors.orange
                              : Colors.red,
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

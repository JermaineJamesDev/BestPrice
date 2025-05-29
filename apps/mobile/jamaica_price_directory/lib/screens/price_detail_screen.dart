import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Enhanced Price Detail Screen - Shows comprehensive price information
class PriceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> priceData;
  
  const PriceDetailScreen({super.key, required this.priceData});
  
  @override
  _PriceDetailScreenState createState() => _PriceDetailScreenState();
}

class _PriceDetailScreenState extends State<PriceDetailScreen> {
  bool isLoading = true;
  bool isFavorite = false;
  
  // Mock additional data that would come from API
  Map<String, dynamic> additionalData = {};
  
  @override
  void initState() {
    super.initState();
    _loadAdditionalData();
  }
  
  // Load additional price information (mock)
  Future<void> _loadAdditionalData() async {
    await Future.delayed(Duration(milliseconds: 800));
    
    // Mock additional data
    setState(() {
      additionalData = {
        'priceHistory': _generatePriceHistory(),
        'nearbyPrices': _generateNearbyPrices(),
        'storeInfo': _generateStoreInfo(),
        'lastUpdated': '2 hours ago',
        'submittedBy': 'Community Verified',
        'viewCount': 47,
        'helpfulVotes': 12,
      };
      isLoading = false;
    });
  }
  
  // Generate mock price history
  List<Map<String, dynamic>> _generatePriceHistory() {
    double currentPrice = widget.priceData['price'].toDouble();
    return [
      {'date': '1 week ago', 'price': currentPrice + 10},
      {'date': '3 days ago', 'price': currentPrice + 5},
      {'date': 'Today', 'price': currentPrice},
    ];
  }
  
  // Generate mock nearby prices
  List<Map<String, dynamic>> _generateNearbyPrices() {
    String itemName = widget.priceData['item'];
    double currentPrice = widget.priceData['price'].toDouble();
    
    return [
      {
        'store': 'SuperPlus',
        'location': 'Half Way Tree',
        'price': currentPrice + 15,
        'distance': 3.2,
      },
      {
        'store': 'PriceSmart',
        'location': 'Portmore',
        'price': currentPrice - 8,
        'distance': 8.7,
      },
    ];
  }
  
  // Generate mock store information
  Map<String, dynamic> _generateStoreInfo() {
    return {
      'phone': '876-555-0123',
      'address': '123 Main Street, ${widget.priceData['location']}',
      'hours': 'Mon-Sat: 8AM-10PM, Sun: 9AM-8PM',
      'rating': 4.2,
      'reviewCount': 89,
    };
  }
  
  // Toggle favorite status
  void _toggleFavorite() {
    setState(() {
      isFavorite = !isFavorite;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFavorite ? 'Added to favorites' : 'Removed from favorites'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  // Share price information
  void _sharePrice() {
    // Mock sharing functionality
    Clipboard.setData(ClipboardData(
      text: '${widget.priceData['item']} - J\$${widget.priceData['price']} at ${widget.priceData['store']} (Jamaica Price Directory)',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Price information copied to clipboard!')),
    );
  }
  
  // Report incorrect price
  void _reportPrice() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report Price'),
        content: Text('Thank you for helping keep our prices accurate. Your report has been submitted for review.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Get directions to store
  void _getDirections() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening directions in Maps app...')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      appBar: AppBar(
        title: Text('Price Details'),
        actions: [
          // Favorite button
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : Colors.white,
            ),
          ),
          // Share button
          IconButton(
            onPressed: _sharePrice,
            icon: Icon(Icons.share),
          ),
        ],
      ),
      
      body: isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Main price info
                  _buildMainPriceInfo(),
                  
                  SizedBox(height: 16),
                  
                  // Action buttons
                  _buildActionButtons(),
                  
                  SizedBox(height: 16),
                  
                  // Store information
                  _buildStoreInfo(),
                  
                  SizedBox(height: 16),
                  
                  // Price history
                  _buildPriceHistory(),
                  
                  SizedBox(height: 16),
                  
                  // Nearby prices
                  _buildNearbyPrices(),
                  
                  SizedBox(height: 16),
                  
                  // Additional info
                  _buildAdditionalInfo(),
                  
                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
  
  // Loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E3A8A)),
          SizedBox(height: 16),
          Text('Loading price details...'),
        ],
      ),
    );
  }
  
  // Main price information card
  Widget _buildMainPriceInfo() {
    return Container(
      margin: EdgeInsets.all(16),
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
          // Item name
          Text(
            widget.priceData['item'],
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          
          SizedBox(height: 8),
          
          // Price
          Text(
            'J\$${widget.priceData['price'].toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          
          SizedBox(height: 12),
          
          // Store and location
          Row(
            children: [
              Icon(Icons.store, color: Colors.grey[600], size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.priceData['store']} • ${widget.priceData['location']}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Distance and verification
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey[600], size: 20),
              SizedBox(width: 8),
              Text(
                '${widget.priceData['distance']} km away',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(width: 16),
              if (widget.priceData['verified'])
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
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
          ),
        ],
      ),
    );
  }
  
  // Action buttons
  Widget _buildActionButtons() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _getDirections,
              icon: Icon(Icons.directions),
              label: Text('Directions'),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _reportPrice,
              icon: Icon(Icons.flag),
              label: Text('Report'),
            ),
          ),
        ],
      ),
    );
  }
  
  // Store information section
  Widget _buildStoreInfo() {
    if (!additionalData.containsKey('storeInfo')) return Container();
    
    Map<String, dynamic> storeInfo = additionalData['storeInfo'];
    
    return _buildSection(
      title: 'Store Information',
      icon: Icons.store,
      child: Column(
        children: [
          _buildInfoRow(Icons.phone, 'Phone', storeInfo['phone']),
          _buildInfoRow(Icons.location_on, 'Address', storeInfo['address']),
          _buildInfoRow(Icons.access_time, 'Hours', storeInfo['hours']),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                '${storeInfo['rating']} (${storeInfo['reviewCount']} reviews)',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Price history section
  Widget _buildPriceHistory() {
    if (!additionalData.containsKey('priceHistory')) return Container();
    
    List<Map<String, dynamic>> history = additionalData['priceHistory'];
    
    return _buildSection(
      title: 'Price History',
      icon: Icons.trending_up,
      child: Column(
        children: history.map((entry) {
          double price = entry['price'];
          bool isCurrentPrice = entry['date'] == 'Today';
          
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry['date'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isCurrentPrice ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  'J\$${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isCurrentPrice ? FontWeight.bold : FontWeight.normal,
                    color: isCurrentPrice ? Color(0xFF1E3A8A) : Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  // Nearby prices section
  Widget _buildNearbyPrices() {
    if (!additionalData.containsKey('nearbyPrices')) return Container();
    
    List<Map<String, dynamic>> nearbyPrices = additionalData['nearbyPrices'];
    
    return _buildSection(
      title: 'Compare Nearby',
      icon: Icons.compare_arrows,
      child: Column(
        children: nearbyPrices.map((price) {
          double priceValue = price['price'];
          double currentPrice = widget.priceData['price'].toDouble();
          double difference = priceValue - currentPrice;
          bool isHigher = difference > 0;
          
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
                        price['store'],
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${price['location']} • ${price['distance']} km',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'J\$${priceValue.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${isHigher ? '+' : ''}J\$${difference.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isHigher ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  // Additional information section
  Widget _buildAdditionalInfo() {
    if (additionalData.isEmpty) return Container();
    
    return _buildSection(
      title: 'Additional Information',
      icon: Icons.info,
      child: Column(
        children: [
          _buildInfoRow(Icons.update, 'Last Updated', additionalData['lastUpdated']),
          _buildInfoRow(Icons.person, 'Submitted By', additionalData['submittedBy']),
          _buildInfoRow(Icons.visibility, 'Views', '${additionalData['viewCount']}'),
          _buildInfoRow(Icons.thumb_up, 'Helpful Votes', '${additionalData['helpfulVotes']}'),
        ],
      ),
    );
  }
  
  // Helper method to build sections
  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
            children: [
              Icon(icon, color: Color(0xFF1E3A8A), size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
  
  // Helper method to build info rows
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
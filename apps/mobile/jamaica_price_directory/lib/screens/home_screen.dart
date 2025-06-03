import 'package:flutter/material.dart';
import 'search_results_screen.dart'; // Keep for quick search from home

// Home Screen - Main dashboard after successful login
// Shows overview, quick actions, and recent updates
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controller for quick search
  final _quickSearchController = TextEditingController();
  
  // Mock user data (in real app, this comes from login/user profile)
  final String userName = 'John Doe';
  final String userParish = 'Kingston';
  
  // Mock dashboard stats
  final Map<String, dynamic> dashboardStats = {
    'moneySaved': 1250.0,
    'pricesChecked': 47,
    'submissions': 12,
    'rank': 'Gold',
  };
  
  // Mock trending prices (what's popular right now)
  final List<Map<String, dynamic>> trendingPrices = [
    {
      'item': 'Gas (Regular)',
      'trend': 'up',
      'change': '+3.2%',
      'currentPrice': 195.50,
      'category': 'fuel',
    },
    {
      'item': 'Rice (1 lb)',
      'trend': 'down',
      'change': '-5.1%',
      'currentPrice': 120.00,
      'category': 'groceries',
    },
    {
      'item': 'Chicken Breast',
      'trend': 'stable',
      'change': '0.0%',
      'currentPrice': 320.00,
      'category': 'groceries',
    },
  ];
  
  // Mock price alerts
  final List<Map<String, dynamic>> priceAlerts = [
    {
      'item': 'Rice (1 lb)',
      'store': 'Hi-Lo Kingston',
      'newPrice': 115.00,
      'oldPrice': 125.00,
      'savings': 10.00,
      'time': '2 hours ago',
    },
    {
      'item': 'Cooking Oil',
      'store': 'MegaMart Spanish Town',
      'newPrice': 680.00,
      'oldPrice': 720.00,
      'savings': 40.00,
      'time': '5 hours ago',
    },
  ];
  
  // Quick actions data
  final List<Map<String, dynamic>> quickActions = [
    {
      'title': 'Search Prices',
      'subtitle': 'Find best deals',
      'icon': Icons.search,
      'color': Colors.blue,
      'route': '/search',
    },
    {
      'title': 'Submit Price',
      'subtitle': 'Help others save',
      'icon': Icons.camera_alt,
      'color': Colors.green,
      'route': '/camera',
    },
    {
      'title': 'My Budget',
      'subtitle': 'Track spending',
      'icon': Icons.account_balance_wallet,
      'color': Colors.purple,
      'route': '/budget',
    },
    {
      'title': 'My Profile',
      'subtitle': 'Settings & stats',
      'icon': Icons.person,
      'color': Colors.orange,
      'route': '/profile',
    },
  ];
  
  // Handle quick search from home
  void _handleQuickSearch() {
    String searchTerm = _quickSearchController.text.trim();
    if (searchTerm.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(searchQuery: searchTerm),
        ),
      );
      _quickSearchController.clear();
    }
  }
  
  // Handle quick action tap
  void _handleQuickAction(String route) {
    Navigator.pushNamed(context, route);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      // App bar with user greeting
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${_getTimeOfDayGreeting()}!',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              userName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        automaticallyImplyLeading: false, // Remove back button since this is main tab
        actions: [
          // Notification icon
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notifications coming soon!')),
              );
            },
            icon: Stack(
              children: [
                Icon(Icons.notifications_outlined),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Main content
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick search section
            _buildQuickSearchSection(),
            
            SizedBox(height: 24),
            
            // Dashboard stats
            _buildDashboardStats(),
            
            SizedBox(height: 24),
            
            // Quick actions
            _buildQuickActions(),
            
            SizedBox(height: 24),
            
            // Price alerts
            _buildPriceAlerts(),
            
            SizedBox(height: 24),
            
            // Trending prices
            _buildTrendingPrices(),
            
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  // Quick search section widget
  Widget _buildQuickSearchSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(158, 158, 158, 0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Search',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _quickSearchController,
            decoration: InputDecoration(
              hintText: 'What are you looking for?',
              prefixIcon: Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _handleQuickSearch,
                icon: Icon(Icons.arrow_forward),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (_) => _handleQuickSearch(),
          ),
          SizedBox(height: 8),
          Text(
            'Or use the Search tab for advanced options',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  // Dashboard stats section
  Widget _buildDashboardStats() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(30, 58, 138, 0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Impact This Month',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${dashboardStats['moneySaved'].toStringAsFixed(0)}',
                  'Money Saved',
                  Icons.savings,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '${dashboardStats['pricesChecked']}',
                  'Prices Checked',
                  Icons.search,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${dashboardStats['submissions']}',
                  'Submissions',
                  Icons.camera_alt,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '${dashboardStats['rank']}',
                  'Rank',
                  Icons.star,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Stat card widget
  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(height: 4),
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
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromRGBO(255, 255, 255, 0.9),
            ),
          ),
        ],
      ),
    );
  }
  
  // Quick actions section
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: quickActions.length,
          itemBuilder: (context, index) {
            return _buildQuickActionCard(quickActions[index]);
          },
        ),
      ],
    );
  }
  
  // Quick action card
  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return InkWell(
      onTap: () => _handleQuickAction(action['route']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(158, 158, 158, 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: action['color'].withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                action['icon'],
                color: action['color'],
                size: 20,
              ),
            ),
            SizedBox(height: 8),
            Text(
              action['title'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              action['subtitle'],
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
  
  // Price alerts section
  Widget _buildPriceAlerts() {
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
                'Recent Price Drops',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Icon(Icons.trending_down, color: Colors.green),
            ],
          ),
          SizedBox(height: 12),
          
          ...priceAlerts.map((alert) {
            return Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withAlpha((0.1 * 255).round())),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_downward, color: Colors.green, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['item'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          alert['store'],
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
                        '${alert['newPrice'].toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Save ${alert['savings'].toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
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
  
  // Trending prices section
  Widget _buildTrendingPrices() {
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
                'Market Trends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: () => _handleQuickAction('/search'),
                child: Text('View All'),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          ...trendingPrices.map((price) {
            Color trendColor = price['trend'] == 'up' 
                ? Colors.red 
                : price['trend'] == 'down' 
                    ? Colors.green 
                    : Colors.grey;
            
            IconData trendIcon = price['trend'] == 'up' 
                ? Icons.trending_up 
                : price['trend'] == 'down' 
                    ? Icons.trending_down 
                    : Icons.trending_flat;
            
            return Container(
              margin: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(price['category']),
                    color: Colors.grey[600],
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      price['item'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(trendIcon, color: trendColor, size: 20),
                  SizedBox(width: 4),
                  Text(
                    price['change'],
                    style: TextStyle(
                      color: trendColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${price['currentPrice'].toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
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
  
  // Get category icon
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'fuel':
        return Icons.local_gas_station;
      case 'groceries':
        return Icons.shopping_basket;
      default:
        return Icons.store;
    }
  }
  
  // Get greeting based on time of day
  String _getTimeOfDayGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }
  
  @override
  void dispose() {
    _quickSearchController.dispose();
    super.dispose();
  }
}
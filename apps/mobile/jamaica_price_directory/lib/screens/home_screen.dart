import 'package:flutter/material.dart';
import 'search_results_screen.dart'; // Import our new search results screen

// Home Screen - Main app screen after successful login
// This is where users will search for prices and see main features
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controller for search input
  final _searchController = TextEditingController();
  
  // Mock user data (in real app, this comes from login/user profile)
  final String userName = 'John Doe';
  final String userParish = 'Kingston';
  
  // Mock popular searches (we'll make this dynamic later)
  final List<String> popularSearches = [
    'Rice',
    'Chicken',
    'Gas',
    'Bread',
    'Milk',
    'Phone credit',
  ];
  
  // Mock recent price updates (placeholder data)
  final List<Map<String, dynamic>> recentPrices = [
    {
      'item': 'Rice (1 lb)',
      'price': 'J\$120',
      'store': 'Hi-Lo',
      'location': 'Kingston',
      'change': -5.2, // Negative means price dropped
    },
    {
      'item': 'Gas (1 gallon)',
      'price': 'J\$195',
      'store': 'Petcom',
      'location': 'Spanish Town',
      'change': 2.1, // Positive means price increased
    },
    {
      'item': 'Chicken (1 lb)',
      'price': 'J\$280',
      'store': 'MegaMart',
      'location': 'Montego Bay',
      'change': 0.0, // No change
    },
  ];
  
  // Handle search action
  void _handleSearch() {
    String searchTerm = _searchController.text.trim();
    if (searchTerm.isNotEmpty) {
      // Navigate to search results screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(searchQuery: searchTerm),
        ),
      );
      _searchController.clear();
    }
  }
  
  // Handle popular search tap
  void _handlePopularSearchTap(String searchTerm) {
    // Navigate to search results screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(searchQuery: searchTerm),
      ),
    );
  }
  
  // Handle logout
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Go back to login screen and remove all previous screens
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      // App bar with user greeting and menu
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
        actions: [
          // Notification icon (placeholder)
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notifications coming soon!')),
              );
            },
            icon: Icon(Icons.notifications_outlined),
          ),
          // Menu
          PopupMenuButton(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              } else if (value == 'profile') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profile page coming soon!')),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      
      // Main content
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search section
            _buildSearchSection(),
            
            SizedBox(height: 24),
            
            // Popular searches
            _buildPopularSearchesSection(),
            
            SizedBox(height: 24),
            
            // Recent price updates
            _buildRecentPricesSection(),
            
            SizedBox(height: 24),
            
            // Quick actions
            _buildQuickActionsSection(),
          ],
        ),
      ),
      
      // Bottom navigation (placeholder for now)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        onTap: (index) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigation feature coming soon!')),
          );
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Submit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      
      // Floating action button for quick price submission
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Camera feature coming soon!')),
          );
        },
        tooltip: 'Submit Price',
        child: Icon(Icons.add),
      ),
    );
  }
  
  // Search section widget
  Widget _buildSearchSection() {
    return Container(
      padding: EdgeInsets.all(16),
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
          Text(
            'What are you looking for?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for prices...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _handleSearch,
                icon: Icon(Icons.arrow_forward),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (_) => _handleSearch(),
          ),
        ],
      ),
    );
  }
  
  // Popular searches section
  Widget _buildPopularSearchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Searches',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popularSearches.map((search) {
            return InkWell(
              onTap: () => _handlePopularSearchTap(search),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                ),
                child: Text(
                  search,
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  // Recent prices section
  Widget _buildRecentPricesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Price Updates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('View all prices feature coming soon!')),
                );
              },
              child: Text('View All'),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...recentPrices.map((price) => _buildPriceCard(price)),
      ],
    );
  }
  
  // Individual price card
  Widget _buildPriceCard(Map<String, dynamic> price) {
    Color changeColor = price['change'] > 0 
        ? Colors.red 
        : price['change'] < 0 
            ? Colors.green 
            : Colors.grey;
    
    String changeText = price['change'] > 0 
        ? '+${price['change']}%' 
        : price['change'] < 0 
            ? '${price['change']}%'
            : 'No change';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          // Item icon (placeholder)
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shopping_basket,
              color: Color(0xFF1E3A8A),
            ),
          ),
          
          SizedBox(width: 12),
          
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price['item'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${price['store']} • ${price['location']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Price and change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price['price'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              Text(
                changeText,
                style: TextStyle(
                  fontSize: 12,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Quick actions section
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Submit Price',
                Icons.camera_alt,
                'Take a photo of a receipt or price tag',
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Camera feature coming soon!')),
                  );
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'My Budget',
                Icons.account_balance_wallet,
                'Track your spending and savings',
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Budget feature coming soon!')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Quick action card
  Widget _buildQuickActionCard(String title, IconData icon, String description, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
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
          children: [
            Icon(
              icon,
              size: 32,
              color: Color(0xFF1E3A8A),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
    _searchController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'search_results_screen.dart';

// Dedicated Search Screen - Main search interface with categories and filters
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  
  // Search categories for easy browsing
  final List<Map<String, dynamic>> categories = [
    {'name': 'Groceries', 'icon': Icons.shopping_basket, 'color': Colors.green},
    {'name': 'Fuel', 'icon': Icons.local_gas_station, 'color': Colors.red},
    {'name': 'Utilities', 'icon': Icons.receipt_long, 'color': Colors.blue},
    {'name': 'Electronics', 'icon': Icons.devices, 'color': Colors.purple},
    {'name': 'Pharmacy', 'icon': Icons.medical_services, 'color': Colors.teal},
    {'name': 'Restaurants', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'name': 'Transport', 'icon': Icons.directions_bus, 'color': Colors.indigo},
    {'name': 'Services', 'icon': Icons.home_repair_service, 'color': Colors.brown},
  ];
  
  // Popular search terms
  final List<String> popularSearches = [
    'Rice', 'Chicken', 'Gas', 'Bread', 'Milk', 'Phone credit',
    'Cooking oil', 'Sugar', 'Flour', 'Internet', 'Electricity',
  ];
  
  // Recent searches (mock data - in real app, save to local storage)
  final List<String> recentSearches = [
    'Rice 1 lb', 'Gas prices Kingston', 'Chicken breast',
  ];
  
  // Handle search submission
  void _handleSearch(String query) {
    if (query.trim().isNotEmpty) {
      // Add to recent searches (mock - in real app, save locally)
      if (!recentSearches.contains(query)) {
        setState(() {
          recentSearches.insert(0, query);
          if (recentSearches.length > 10) {
            recentSearches.removeLast();
          }
        });
      }
      
      // Navigate to search results
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(searchQuery: query),
        ),
      );
      
      _searchController.clear();
    }
  }
  
  // Handle category tap
  void _handleCategoryTap(String categoryName) {
    _handleSearch(categoryName);
  }
  
  // Handle popular search tap
  void _handlePopularSearchTap(String searchTerm) {
    _handleSearch(searchTerm);
  }
  
  // Clear recent searches
  void _clearRecentSearches() {
    setState(() {
      recentSearches.clear();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      appBar: AppBar(
        title: Text('Search Prices'),
        automaticallyImplyLeading: false, // Remove back button since this is a main tab
        elevation: 0,
      ),
      
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search input section
            _buildSearchInput(),
            
            SizedBox(height: 24),
            
            // Categories section
            _buildCategoriesSection(),
            
            SizedBox(height: 24),
            
            // Recent searches section
            if (recentSearches.isNotEmpty) ...[
              _buildRecentSearchesSection(),
              SizedBox(height: 24),
            ],
            
            // Popular searches section
            _buildPopularSearchesSection(),
          ],
        ),
      ),
    );
  }
  
  // Search input widget
  Widget _buildSearchInput() {
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
          Text(
            'Find the Best Prices',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Search for any product or service across Jamaica',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'What are you looking for?',
              prefixIcon: Icon(Icons.search, color: Color(0xFF1E3A8A)),
              suffixIcon: IconButton(
                onPressed: () => _handleSearch(_searchController.text),
                icon: Icon(Icons.arrow_forward, color: Color(0xFF1E3A8A)),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF1E3A8A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
              ),
            ),
            onSubmitted: _handleSearch,
          ),
        ],
      ),
    );
  }
  
  // Categories section
  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Browse by Category',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            return _buildCategoryCard(categories[index]);
          },
        ),
      ],
    );
  }
  
  // Individual category card
  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return InkWell(
      onTap: () => _handleCategoryTap(category['name']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: category['color'].withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                category['icon'],
                size: 28,
                color: category['color'],
              ),
            ),
            SizedBox(height: 8),
            Text(
              category['name'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Recent searches section
  Widget _buildRecentSearchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: _clearRecentSearches,
              child: Text(
                'Clear',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
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
            children: recentSearches.map((search) {
              return InkWell(
                onTap: () => _handleSearch(search),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.grey[600], size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          search,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, 
                           color: Colors.grey[400], 
                           size: 16),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popularSearches.map((search) {
            return InkWell(
              onTap: () => _handlePopularSearchTap(search),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFF1E3A8A).withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(0xFF1E3A8A).withAlpha((0.3 * 255).round()),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 16,
                      color: Color(0xFF1E3A8A),
                    ),
                    SizedBox(width: 6),
                    Text(
                      search,
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
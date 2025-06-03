import 'package:flutter/material.dart';
import 'search_filters_screen.dart'; // Import our filters screen
import 'price_detail_screen.dart'; // Import enhanced price detail screen

// Search Results Screen - Shows prices based on user's search
class SearchResultsScreen extends StatefulWidget {
  final String searchQuery; // What the user searched for
  
  // Constructor - receives search query from previous screen
  const SearchResultsScreen({super.key, required this.searchQuery});
  
  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  // Mock search results - in real app, this comes from API
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> filteredResults = [];
  bool isLoading = true;
  
  // Filter settings
  SearchFilters filters = SearchFilters.defaultFilters();
  
  @override
  void initState() {
    super.initState();
    // Load search results when screen opens
    _performSearch();
  }
  
  // Mock search function - simulates API call
  Future<void> _performSearch() async {
    // Simulate network delay
    await Future.delayed(Duration(seconds: 1));
    
    // Mock data based on search query
    List<Map<String, dynamic>> mockResults = _generateMockResults(widget.searchQuery);
    
    setState(() {
      searchResults = mockResults;
      _applyFilters(); // Apply current filters
      isLoading = false;
    });
  }
  
  // Apply filters and sorting to search results
  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(searchResults);
    
    // Apply parish filter
    if (filters.parish != 'All Parishes') {
      filtered = filtered.where((item) => item['parish'] == filters.parish).toList();
    }
    
    // Apply price range filter
    filtered = filtered.where((item) {
      double price = item['price'].toDouble();
      return price >= filters.minPrice && price <= filters.maxPrice;
    }).toList();
    
    // Apply store type filter
    if (filters.storeType != 'All Stores') {
      filtered = filtered.where((item) {
        String storeType = _getStoreType(item['store']);
        return storeType == filters.storeType;
      }).toList();
    }
    
    // Apply verification filter
    if (filters.verifiedOnly) {
      filtered = filtered.where((item) => item['verified'] == true).toList();
    }
    
    // Apply distance filter
    filtered = filtered.where((item) => item['distance'] <= filters.maxDistance).toList();
    
    // Apply sorting
    _sortResults(filtered);
    
    setState(() {
      filteredResults = filtered;
    });
  }
  
  // Sort results based on selected option
  void _sortResults(List<Map<String, dynamic>> results) {
    switch (filters.sortBy) {
      case SortOption.priceAsc:
        results.sort((a, b) => a['price'].compareTo(b['price']));
        break;
      case SortOption.priceDesc:
        results.sort((a, b) => b['price'].compareTo(a['price']));
        break;
      case SortOption.distance:
        results.sort((a, b) => a['distance'].compareTo(b['distance']));
        break;
      case SortOption.dateDesc:
        // Mock sorting by date - in real app, use actual timestamps
        results.shuffle(); // Random for demo
        break;
      case SortOption.relevance:
      default:
        // Keep original order (most relevant first)
        break;
    }
  }
  
  // Get store type for filtering
  String _getStoreType(String storeName) {
    if (storeName.contains('Hi-Lo') || storeName.contains('MegaMart') || storeName.contains('SuperPlus') || storeName.contains('PriceSmart')) {
      return 'Supermarket';
    } else if (storeName.contains('Petcom') || storeName.contains('Shell') || storeName.contains('Texaco')) {
      return 'Gas Station';
    } else {
      return 'Market Vendor';
    }
  }
  
  // Open filters screen
  Future<void> _openFilters() async {
    SearchFilters? newFilters = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchFiltersScreen(currentFilters: filters),
      ),
    );
    
    if (newFilters != null) {
      setState(() {
        filters = newFilters;
        _applyFilters();
      });
    }
  }
  
  // Generate mock search results based on query
  List<Map<String, dynamic>> _generateMockResults(String query) {
    // Convert query to lowercase for comparison
    String lowerQuery = query.toLowerCase();
    
    // All our mock price data
    List<Map<String, dynamic>> allPrices = [
      // Rice prices
      {'item': 'Rice (1 lb)', 'price': 120.00, 'store': 'Hi-Lo', 'location': 'Kingston', 'parish': 'Kingston', 'distance': 2.1, 'verified': true, 'category': 'rice'},
      {'item': 'Rice (2 lb)', 'price': 230.00, 'store': 'MegaMart', 'location': 'Spanish Town', 'parish': 'St. Catherine', 'distance': 12.5, 'verified': true, 'category': 'rice'},
      {'item': 'Rice (5 lb)', 'price': 580.00, 'store': 'PriceSmart', 'location': 'Portmore', 'parish': 'St. Catherine', 'distance': 15.2, 'verified': false, 'category': 'rice'},
      {'item': 'Basmati Rice (1 lb)', 'price': 180.00, 'store': 'SuperPlus', 'location': 'Half Way Tree', 'parish': 'St. Andrew', 'distance': 5.8, 'verified': true, 'category': 'rice'},
      
      // Chicken prices
      {'item': 'Chicken Breast (1 lb)', 'price': 320.00, 'store': 'Hi-Lo', 'location': 'Kingston', 'parish': 'Kingston', 'distance': 2.1, 'verified': true, 'category': 'chicken'},
      {'item': 'Whole Chicken (3 lb)', 'price': 850.00, 'store': 'MegaMart', 'location': 'Montego Bay', 'parish': 'St. James', 'distance': 180.5, 'verified': true, 'category': 'chicken'},
      {'item': 'Chicken Wings (1 lb)', 'price': 280.00, 'store': 'SuperPlus', 'location': 'Mandeville', 'parish': 'Manchester', 'distance': 65.3, 'verified': false, 'category': 'chicken'},
      
      // Gas prices
      {'item': 'Regular Gas (1 gallon)', 'price': 195.50, 'store': 'Petcom', 'location': 'Spanish Town', 'parish': 'St. Catherine', 'distance': 12.5, 'verified': true, 'category': 'gas'},
      {'item': 'Premium Gas (1 gallon)', 'price': 210.00, 'store': 'Shell', 'location': 'Kingston', 'parish': 'Kingston', 'distance': 3.2, 'verified': true, 'category': 'gas'},
      {'item': 'Diesel (1 gallon)', 'price': 185.00, 'store': 'Texaco', 'location': 'Ocho Rios', 'parish': 'St. Ann', 'distance': 95.1, 'verified': true, 'category': 'gas'},
      
      // Bread prices
      {'item': 'Whole Wheat Bread', 'price': 180.00, 'store': 'Purity', 'location': 'Kingston', 'parish': 'Kingston', 'distance': 1.8, 'verified': true, 'category': 'bread'},
      {'item': 'White Bread', 'price': 160.00, 'store': 'National', 'location': 'Spanish Town', 'parish': 'St. Catherine', 'distance': 12.5, 'verified': true, 'category': 'bread'},
      
      // Milk prices
      {'item': 'Fresh Milk (1 liter)', 'price': 220.00, 'store': 'Dairy Industries', 'location': 'Kingston', 'parish': 'Kingston', 'distance': 4.5, 'verified': true, 'category': 'milk'},
      {'item': 'Powdered Milk (400g)', 'price': 850.00, 'store': 'Hi-Lo', 'location': 'Half Way Tree', 'parish': 'St. Andrew', 'distance': 5.8, 'verified': false, 'category': 'milk'},
    ];
    
    // Filter results based on search query
    return allPrices.where((price) {
      return price['item'].toLowerCase().contains(lowerQuery) ||
             price['category'].toLowerCase().contains(lowerQuery) ||
             price['store'].toLowerCase().contains(lowerQuery);
    }).toList();
  }
  
  // Handle tapping on a price result
  void _onPriceTap(Map<String, dynamic> priceData) {
    // Navigate to enhanced price detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PriceDetailScreen(priceData: priceData),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search Results', style: TextStyle(fontSize: 16)),
            Text('"${widget.searchQuery}"', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          // Filter button with active indicator
          Stack(
            children: [
              IconButton(
                onPressed: _openFilters,
                icon: Icon(Icons.filter_list),
              ),
              if (filters.hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
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
        ],
      ),
      
      body: isLoading
          ? _buildLoadingState()
          : filteredResults.isEmpty
              ? _buildEmptyState()
              : _buildResultsList(),
    );
  }
  
  // Loading state while searching
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E3A8A)),
          SizedBox(height: 16),
          Text(
            'Searching for "${widget.searchQuery}"...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  
  // Empty state when no results found
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Results Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'We couldn\'t find any prices for "${widget.searchQuery}". Try searching for something else.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Try Different Search'),
            ),
          ],
        ),
      ),
    );
  }
  
  // List of search results
  Widget _buildResultsList() {
    return Column(
      children: [
        // Results summary with filter info
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${filteredResults.length} ${filteredResults.length == 1 ? 'result' : 'results'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              if (filters.hasActiveFilters) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.filter_list, size: 16, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 4),
                    Text(
                      'Filters applied',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          filters = SearchFilters.defaultFilters();
                          _applyFilters();
                        });
                      },
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        // Results list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: filteredResults.length,
            itemBuilder: (context, index) {
              return _buildPriceCard(filteredResults[index]);
            },
          ),
        ),
      ],
    );
  }
  
  // Individual price card
  Widget _buildPriceCard(Map<String, dynamic> price) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: () => _onPriceTap(price),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Item icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF1E3A8A).withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIconForCategory(price['category']),
                    color: Color(0xFF1E3A8A),
                    size: 30,
                  ),
                ),
                
                SizedBox(width: 16),
                
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item name
                      Text(
                        price['item'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      
                      SizedBox(height: 4),
                      
                      // Store and location
                      Row(
                        children: [
                          Icon(Icons.store, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            '${price['store']} • ${price['location']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 4),
                      
                      // Distance and verification
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            '${price['distance']} km away',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (price['verified'])
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'J\$${price['price'].toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Get icon based on category
  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'rice':
        return Icons.rice_bowl;
      case 'chicken':
        return Icons.set_meal;
      case 'gas':
        return Icons.local_gas_station;
      case 'bread':
        return Icons.bakery_dining;
      case 'milk':
        return Icons.local_drink;
      default:
        return Icons.shopping_basket;
    }
  }
}
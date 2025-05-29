import 'package:flutter/material.dart';

// Search Filters Screen - Advanced filtering options
class SearchFiltersScreen extends StatefulWidget {
  final SearchFilters currentFilters; // Current filter settings
  
  const SearchFiltersScreen({super.key, required this.currentFilters});
  
  @override
  _SearchFiltersScreenState createState() => _SearchFiltersScreenState();
}

class _SearchFiltersScreenState extends State<SearchFiltersScreen> {
  // Filter values (start with current filters)
  late SearchFilters filters;
  
  // Jamaica parishes for location filter
  final List<String> parishes = [
    'All Parishes',
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
  
  // Store types for filtering
  final List<String> storeTypes = [
    'All Stores',
    'Supermarket',
    'Gas Station',
    'Pharmacy',
    'Hardware Store',
    'Market Vendor',
    'Government Office',
  ];
  
  @override
  void initState() {
    super.initState();
    // Copy current filters so we can modify them
    filters = SearchFilters.copy(widget.currentFilters);
  }
  
  // Apply filters and return to search results
  void _applyFilters() {
    Navigator.pop(context, filters);
  }
  
  // Reset all filters to default
  void _resetFilters() {
    setState(() {
      filters = SearchFilters.defaultFilters();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      
      appBar: AppBar(
        title: Text('Filter Results'),
        actions: [
          // Reset button
          TextButton(
            onPressed: _resetFilters,
            child: Text(
              'Reset',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sort by section
            _buildSortSection(),
            
            SizedBox(height: 24),
            
            // Location filter
            _buildLocationSection(),
            
            SizedBox(height: 24),
            
            // Price range filter
            _buildPriceRangeSection(),
            
            SizedBox(height: 24),
            
            // Store type filter
            _buildStoreTypeSection(),
            
            SizedBox(height: 24),
            
            // Verification filter
            _buildVerificationSection(),
            
            SizedBox(height: 24),
            
            // Distance filter
            _buildDistanceSection(),
            
            SizedBox(height: 32),
          ],
        ),
      ),
      
      // Apply filters button
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _applyFilters,
          child: Text(
            'Apply Filters',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
  
  // Sort by section
  Widget _buildSortSection() {
    return _buildSection(
      title: 'Sort By',
      child: Column(
        children: SortOption.values.map((option) {
          return RadioListTile<SortOption>(
            title: Text(_getSortOptionText(option)),
            value: option,
            groupValue: filters.sortBy,
            onChanged: (SortOption? value) {
              setState(() {
                filters.sortBy = value!;
              });
            },
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
      ),
    );
  }
  
  // Location filter section
  Widget _buildLocationSection() {
    return _buildSection(
      title: 'Location',
      child: DropdownButtonFormField<String>(
        value: filters.parish,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.location_on),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: parishes.map((String parish) {
          return DropdownMenuItem<String>(
            value: parish,
            child: Text(parish),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            filters.parish = newValue!;
          });
        },
      ),
    );
  }
  
  // Price range section
  Widget _buildPriceRangeSection() {
    return _buildSection(
      title: 'Price Range',
      child: Column(
        children: [
          // Price range slider
          RangeSlider(
            values: RangeValues(filters.minPrice, filters.maxPrice),
            min: 0,
            max: 2000,
            divisions: 40,
            labels: RangeLabels(
              'J\$${filters.minPrice.round()}',
              'J\$${filters.maxPrice.round()}',
            ),
            onChanged: (RangeValues values) {
              setState(() {
                filters.minPrice = values.start;
                filters.maxPrice = values.end;
              });
            },
          ),
          
          // Price range display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: J\$${filters.minPrice.round()}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Max: J\$${filters.maxPrice.round()}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Store type section
  Widget _buildStoreTypeSection() {
    return _buildSection(
      title: 'Store Type',
      child: DropdownButtonFormField<String>(
        value: filters.storeType,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.store),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: storeTypes.map((String type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            filters.storeType = newValue!;
          });
        },
      ),
    );
  }
  
  // Verification filter section
  Widget _buildVerificationSection() {
    return _buildSection(
      title: 'Verification Status',
      child: Column(
        children: [
          CheckboxListTile(
            title: Text('Show Verified Only'),
            subtitle: Text('Only show prices verified by community or officials'),
            value: filters.verifiedOnly,
            onChanged: (bool? value) {
              setState(() {
                filters.verifiedOnly = value!;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
  
  // Distance filter section
  Widget _buildDistanceSection() {
    return _buildSection(
      title: 'Maximum Distance',
      child: Column(
        children: [
          // Distance slider
          Slider(
            value: filters.maxDistance,
            min: 1,
            max: 100,
            divisions: 99,
            label: '${filters.maxDistance.round()} km',
            onChanged: (double value) {
              setState(() {
                filters.maxDistance = value;
              });
            },
          ),
          
          // Distance display
          Text(
            'Within ${filters.maxDistance.round()} km',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build sections
  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
  
  // Get text for sort options
  String _getSortOptionText(SortOption option) {
    switch (option) {
      case SortOption.relevance:
        return 'Best Match';
      case SortOption.priceAsc:
        return 'Price: Low to High';
      case SortOption.priceDesc:
        return 'Price: High to Low';
      case SortOption.distance:
        return 'Distance: Nearest First';
      case SortOption.dateDesc:
        return 'Date: Newest First';
    }
  }
}

// Search Filters Data Class
class SearchFilters {
  SortOption sortBy;
  String parish;
  double minPrice;
  double maxPrice;
  String storeType;
  bool verifiedOnly;
  double maxDistance;
  
  SearchFilters({
    required this.sortBy,
    required this.parish,
    required this.minPrice,
    required this.maxPrice,
    required this.storeType,
    required this.verifiedOnly,
    required this.maxDistance,
  });
  
  // Default filters
  factory SearchFilters.defaultFilters() {
    return SearchFilters(
      sortBy: SortOption.relevance,
      parish: 'All Parishes',
      minPrice: 0,
      maxPrice: 2000,
      storeType: 'All Stores',
      verifiedOnly: false,
      maxDistance: 50,
    );
  }
  
  // Copy constructor
  factory SearchFilters.copy(SearchFilters other) {
    return SearchFilters(
      sortBy: other.sortBy,
      parish: other.parish,
      minPrice: other.minPrice,
      maxPrice: other.maxPrice,
      storeType: other.storeType,
      verifiedOnly: other.verifiedOnly,
      maxDistance: other.maxDistance,
    );
  }
  
  // Check if filters are applied (not default)
  bool get hasActiveFilters {
    SearchFilters defaults = SearchFilters.defaultFilters();
    return sortBy != defaults.sortBy ||
           parish != defaults.parish ||
           minPrice != defaults.minPrice ||
           maxPrice != defaults.maxPrice ||
           storeType != defaults.storeType ||
           verifiedOnly != defaults.verifiedOnly ||
           maxDistance != defaults.maxDistance;
  }
}

// Sort options enum
enum SortOption {
  relevance,
  priceAsc,
  priceDesc,
  distance,
  dateDesc,
}
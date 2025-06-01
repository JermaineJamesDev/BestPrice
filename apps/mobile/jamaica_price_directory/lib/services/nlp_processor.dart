import 'package:flutter/foundation.dart';
import 'dart:math';

import 'ocr_processor.dart';

/// Enhanced NLP Processor for OCR text understanding and enhancement
class NLPProcessor {
  // Product name patterns and corrections
  static final Map<String, String> _commonMisspellings = {
    'chiken': 'chicken',
    'bred': 'bread',
    'mlk': 'milk',
    'bef': 'beef',
    'pok': 'pork',
    'fsh': 'fish',
    'rce': 'rice',
    'sugr': 'sugar',
    'flur': 'flour',
    'juic': 'juice',
    'sda': 'soda',
    'wtr': 'water',
    'oyl': 'oil',
  };
  
  // Category keywords with weighted scoring
  static final Map<String, Map<String, double>> _categoryKeywords = {
    'Groceries': {
      'rice': 1.0, 'bread': 1.0, 'flour': 1.0, 'sugar': 1.0,
      'salt': 0.9, 'pepper': 0.9, 'oil': 0.9, 'pasta': 0.8,
      'cereal': 0.8, 'sauce': 0.7, 'soup': 0.7, 'noodle': 0.8,
      'bean': 0.8, 'corn': 0.7, 'jam': 0.7, 'butter': 0.8,
    },
    'Meat': {
      'chicken': 1.0, 'beef': 1.0, 'pork': 1.0, 'fish': 1.0,
      'meat': 0.9, 'bacon': 0.9, 'ham': 0.9, 'sausage': 0.8,
      'turkey': 0.8, 'lamb': 0.8, 'steak': 0.9, 'wing': 0.8,
      'thigh': 0.8, 'breast': 0.8, 'ground': 0.7, 'chop': 0.7,
    },
    'Beverages': {
      'juice': 1.0, 'soda': 1.0, 'water': 1.0, 'drink': 0.9,
      'beer': 1.0, 'wine': 1.0, 'coffee': 1.0, 'tea': 1.0,
      'cola': 0.9, 'sprite': 0.9, 'pepsi': 0.9, 'coke': 0.9,
      'fanta': 0.8, 'bottle': 0.7, 'can': 0.6, 'beverage': 0.9,
    },
    'Dairy': {
      'milk': 1.0, 'cheese': 1.0, 'yogurt': 1.0, 'cream': 0.9,
      'butter': 0.9, 'eggs': 1.0, 'dairy': 0.8, 'fresh': 0.6,
      'cottage': 0.8, 'mozzarella': 0.9, 'cheddar': 0.9,
    },
    'Produce': {
      'apple': 1.0, 'banana': 1.0, 'orange': 1.0, 'vegetable': 0.9,
      'fruit': 0.9, 'lettuce': 1.0, 'tomato': 1.0, 'onion': 1.0,
      'carrot': 1.0, 'potato': 1.0, 'fresh': 0.7, 'organic': 0.6,
      'cabbage': 1.0, 'pepper': 0.9, 'cucumber': 1.0,
    },
    'Household': {
      'soap': 1.0, 'detergent': 1.0, 'tissue': 1.0, 'toilet': 0.9,
      'cleaning': 0.9, 'paper': 0.8, 'towel': 0.9, 'bleach': 1.0,
      'dish': 0.8, 'fabric': 0.8, 'freshener': 0.8, 'wash': 0.7,
    },
  };
  
  // Unit patterns with context rules
  static final Map<String, UnitRule> _unitRules = {
    'per lb': UnitRule(
      patterns: [r'\b(lb|lbs|pound|pounds|#)\b'],
      categories: ['Meat', 'Produce'],
      defaultFor: ['chicken', 'beef', 'pork', 'fish'],
    ),
    'per kg': UnitRule(
      patterns: [r'\b(kg|kilo|kilogram|kilograms)\b'],
      categories: ['Meat', 'Produce'],
      defaultFor: [],
    ),
    'per gallon': UnitRule(
      patterns: [r'\b(gal|gallon|gallons)\b'],
      categories: ['Beverages', 'Dairy'],
      defaultFor: ['milk', 'juice', 'water'],
    ),
    'per liter': UnitRule(
      patterns: [r'\b(l|lt|liter|litre|litres)\b'],
      categories: ['Beverages', 'Dairy'],
      defaultFor: ['soda', 'juice'],
    ),
    'per pack': UnitRule(
      patterns: [r'\b(pk|pack|package|pkg)\b'],
      categories: ['Groceries', 'Household'],
      defaultFor: ['tissue', 'paper'],
    ),
  };
  
  // Price validation rules by category
  static final Map<String, PriceRange> _priceRanges = {
    'Groceries': PriceRange(min: 50, max: 2000),
    'Meat': PriceRange(min: 200, max: 3000),
    'Beverages': PriceRange(min: 80, max: 1000),
    'Dairy': PriceRange(min: 150, max: 1500),
    'Produce': PriceRange(min: 50, max: 1000),
    'Household': PriceRange(min: 100, max: 3000),
    'Other': PriceRange(min: 20, max: 10000),
  };
  
  // Jamaican-specific brand names and products
  static final Set<String> _jamaicanBrands = {
    'grace', 'national', 'excelsior', 'lasco', 'bigga', 'ting',
    'tru-juice', 'serge', 'catherine\'s peak', 'blue mountain',
    'walkerswood', 'pick-a-peppa', 'island grill', 'juici',
  };
  
  /// Initialize the NLP processor
  Future<void> initialize() async {
    // Load any additional models or data if needed
    debugPrint('NLP Processor initialized');
  }
  
  /// Clean and normalize item names
  String cleanItemName(String rawName) {
    if (rawName.isEmpty) return 'Unknown Item';
    
    String cleaned = rawName.toLowerCase().trim();
    
    // Remove common OCR artifacts
    cleaned = _removeOCRArtifacts(cleaned);
    
    // Fix common misspellings
    cleaned = _fixMisspellings(cleaned);
    
    // Normalize spacing and capitalization
    cleaned = _normalizeText(cleaned);
    
    // Extract product name from receipt line
    cleaned = _extractProductName(cleaned);
    
    // Apply proper capitalization
    cleaned = _properCapitalization(cleaned);
    
    return cleaned.isNotEmpty ? cleaned : 'Unknown Item';
  }
  
  /// Detect item category using advanced NLP
  String detectCategory(String itemName, String originalText, String storeType) {
    final combinedText = '$itemName $originalText'.toLowerCase();
    
    // Score each category
    final scores = <String, double>{};
    
    for (final category in _categoryKeywords.keys) {
      double score = 0.0;
      final keywords = _categoryKeywords[category]!;
      
      // Check keyword matches with weights
      for (final entry in keywords.entries) {
        if (combinedText.contains(entry.key)) {
          score += entry.value;
          
          // Bonus for exact word match
          if (RegExp(r'\b' + entry.key + r'\b').hasMatch(combinedText)) {
            score += 0.5;
          }
        }
      }
      
      // Store-specific boosts
      score += _getStoreCategoryBoost(category, storeType);
      
      // Position-based scoring (items at top/bottom less likely to be main products)
      score *= _getPositionMultiplier(originalText);
      
      scores[category] = score;
    }
    
    // Find best category
    String bestCategory = 'Other';
    double bestScore = 0.0;
    
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestCategory = entry.key;
      }
    }
    
    // Confidence threshold
    return bestScore >= 0.5 ? bestCategory : 'Other';
  }
  
  /// Extract unit information with context
  String extractUnit(String originalText, String category) {
    final text = originalText.toLowerCase();
    
    // Check explicit unit patterns
    for (final entry in _unitRules.entries) {
      final unit = entry.key;
      final rule = entry.value;
      
      // Check regex patterns
      for (final pattern in rule.patterns) {
        if (RegExp(pattern).hasMatch(text)) {
          return unit;
        }
      }
      
      // Check if item is in default list
      for (final defaultItem in rule.defaultFor) {
        if (text.contains(defaultItem)) {
          return unit;
        }
      }
    }
    
    // Category-based defaults
    final categoryDefault = _getCategoryDefaultUnit(category, text);
    if (categoryDefault != null) {
      return categoryDefault;
    }
    
    // Check for quantity indicators
    if (RegExp(r'\b\d+\s*(pcs?|pieces?|items?)\b').hasMatch(text)) {
      return 'per pack';
    }
    
    return 'each';
  }
  
  /// Validate price based on category and context
  bool validatePrice(double price, String category, String storeType) {
    // Basic sanity checks
    if (price <= 0 || price > 100000) return false;
    
    // Category-based validation
    final range = _priceRanges[category] ?? _priceRanges['Other']!;
    
    // Allow some flexibility for bulk items
    final maxAllowed = range.max * 5; // Allow up to 5x for bulk
    
    if (price < range.min * 0.5 || price > maxAllowed) {
      return false;
    }
    
    // Store-specific validation
    if (storeType == 'pricesmart' && price < 500) {
      // PriceSmart typically has bulk items with higher prices
      return false;
    }
    
    return true;
  }
  
  /// Remove semantic duplicates
  List<ExtractedPrice> removeSemanticDuplicates(List<ExtractedPrice> prices) {
    final unique = <ExtractedPrice>[];
    
    for (final price in prices) {
      bool isDuplicate = false;
      
      for (int i = 0; i < unique.length; i++) {
        final existing = unique[i];
        
        if (_areSemanticallySimilar(price, existing)) {
          // Keep the one with higher confidence
          if (price.confidence > existing.confidence) {
            unique[i] = price;
          }
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        unique.add(price);
      }
    }
    
    return unique;
  }
  
  // Helper methods
  
  String _removeOCRArtifacts(String text) {
    // Remove common OCR artifacts
    text = text.replaceAll(RegExp(r'[^\w\s\-\.\,\(\)]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove item codes at start
    text = text.replaceAll(RegExp(r'^\d{3,}\s*'), '');
    
    // Remove trailing symbols
    text = text.replaceAll(RegExp(r'[\*\#\@\$]+$'), '');
    
    return text.trim();
  }
  
  String _fixMisspellings(String text) {
    String fixed = text;
    
    // Apply known corrections
    for (final entry in _commonMisspellings.entries) {
      fixed = fixed.replaceAll(RegExp(r'\b' + entry.key + r'\b'), entry.value);
    }
    
    // Fix OCR-specific issues
    fixed = fixed.replaceAll(RegExp(r'\bl\s*(\d)'), '1\$1'); // l -> 1
    fixed = fixed.replaceAll(RegExp(r'\bO\s*(\d)'), '0\$1'); // O -> 0
    fixed = fixed.replaceAll(RegExp(r'\bS\s*(\d)'), '5\$1'); // S -> 5
    
    return fixed;
  }
  
  String _normalizeText(String text) {
    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Fix common OCR joining issues
    text = text.replaceAll(RegExp(r'(\w)(\d+\.\d{2})'), '\$1 \$2');
    
    return text;
  }
  
  String _extractProductName(String text) {
    // Remove price patterns
    text = text.replaceAll(RegExp(r'\d+\.\d{2}'), '');
    
    // Remove quantity patterns
    text = text.replaceAll(RegExp(r'\b\d+\s*(pcs?|pieces?|items?|pk|pack)\b'), '');
    
    // Remove store codes
    text = text.replaceAll(RegExp(r'\b[A-Z]{2,}\d{3,}\b'), '');
    
    return text.trim();
  }
  
  String _properCapitalization(String text) {
    if (text.isEmpty) return text;
    
    // Split into words
    final words = text.split(' ');
    final capitalized = <String>[];
    
    for (final word in words) {
      if (word.isEmpty) continue;
      
      // Check if it's a known brand
      if (_jamaicanBrands.contains(word.toLowerCase())) {
        // Brands get title case
        capitalized.add(word[0].toUpperCase() + word.substring(1).toLowerCase());
      }
      // Common words stay lowercase
      else if (['of', 'the', 'in', 'with', 'and', 'or'].contains(word)) {
        capitalized.add(word.toLowerCase());
      }
      // First letter uppercase
      else {
        capitalized.add(word[0].toUpperCase() + word.substring(1).toLowerCase());
      }
    }
    
    // Ensure first word is capitalized
    if (capitalized.isNotEmpty) {
      capitalized[0] = capitalized[0][0].toUpperCase() + 
                       capitalized[0].substring(1).toLowerCase();
    }
    
    return capitalized.join(' ');
  }
  
  double _getStoreCategoryBoost(String category, String storeType) {
    // Store-specific category boosts
    final boosts = {
      'pricesmart': {'Groceries': 0.3, 'Household': 0.2},
      'hi-lo': {'Groceries': 0.2, 'Produce': 0.1},
      'megamart': {'Groceries': 0.2, 'Meat': 0.1},
    };
    
    return boosts[storeType]?[category] ?? 0.0;
  }
  
  double _getPositionMultiplier(String text) {
    // Items containing total, tax, etc. are less likely to be products
    final nonProductKeywords = ['total', 'subtotal', 'tax', 'cash', 'change', 'thank'];
    
    for (final keyword in nonProductKeywords) {
      if (text.toLowerCase().contains(keyword)) {
        return 0.1;
      }
    }
    
    return 1.0;
  }
  
  String? _getCategoryDefaultUnit(String category, String text) {
    switch (category) {
      case 'Meat':
      case 'Produce':
        // Check for pre-packaged indicators
        if (text.contains('pack') || text.contains('tray')) {
          return 'per pack';
        }
        return 'per lb';
        
      case 'Beverages':
        if (text.contains('case') || text.contains('24')) {
          return 'per case';
        }
        if (text.contains('gallon')) {
          return 'per gallon';
        }
        return 'each';
        
      case 'Dairy':
        if (text.contains('dozen')) {
          return 'per dozen';
        }
        return 'each';
        
      default:
        return null;
    }
  }
  
  bool _areSemanticallySimilar(ExtractedPrice price1, ExtractedPrice price2) {
    // Exact price match
    if ((price1.price - price2.price).abs() < 0.01) {
      return true;
    }
    
    // Similar names and prices
    final nameSimilarity = _calculateStringSimilarity(
      price1.itemName.toLowerCase(),
      price2.itemName.toLowerCase(),
    );
    
    if (nameSimilarity > 0.8) {
      final priceDiff = (price1.price - price2.price).abs() / 
                        max(price1.price, price2.price);
      return priceDiff < 0.15; // Within 15% price difference
    }
    
    return false;
  }
  
  double _calculateStringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Levenshtein distance normalized
    final distance = _levenshteinDistance(s1, s2);
    final maxLen = max(s1.length, s2.length);
    
    return 1.0 - (distance / maxLen);
  }
  
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    
    final matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );
    
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,     // deletion
          matrix[i][j - 1] + 1,     // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce(min);
      }
    }
    
    return matrix[len1][len2];
  }
  
  void dispose() {
    // Cleanup any resources
  }
}

// Data classes
class UnitRule {
  final List<String> patterns;
  final List<String> categories;
  final List<String> defaultFor;
  
  UnitRule({
    required this.patterns,
    required this.categories,
    required this.defaultFor,
  });
}

class PriceRange {
  final double min;
  final double max;
  
  PriceRange({required this.min, required this.max});
}
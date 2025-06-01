import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'consolidated_ocr_service.dart';

// Cache Manager Interface for DI
abstract class ICacheManager {
  Future<void> initialize();
  Future<OCRResult?> getCachedResult(String imagePath);
  Future<void> cacheResult(String imagePath, OCRResult result);
  Future<void> clear();
  Future<void> clearExpired();
  Future<int> getCacheSize();
  void dispose();
}

// Default File-based Cache Implementation
class OCRCacheManager implements ICacheManager {
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiration = Duration(days: 7);
  static const String _cacheFileName = 'ocr_cache.json';
  static const String _cacheDirectory = 'ocr_cache';
  
  final Map<String, CachedOCRResult> _memoryCache = {};
  late Directory _cacheDir;
  late File _indexFile;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheDirectory');
      
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
      
      _indexFile = File('${_cacheDir.path}/$_cacheFileName');
      
      await _loadCacheIndex();
      await _cleanExpiredEntries();
      
      _isInitialized = true;
      debugPrint('✅ OCR Cache Manager initialized - ${_memoryCache.length} entries loaded');
    } catch (e) {
      debugPrint('❌ Failed to initialize cache: $e');
      _isInitialized = false;
    }
  }

  @override
  Future<OCRResult?> getCachedResult(String imagePath) async {
    if (!_isInitialized) return null;
    
    try {
      final cacheKey = _generateCacheKey(imagePath);
      final cachedResult = _memoryCache[cacheKey];
      
      if (cachedResult == null) {
        return null;
      }
      
      // Check if expired
      if (DateTime.now().isAfter(cachedResult.expiresAt)) {
        await _removeCacheEntry(cacheKey);
        return null;
      }
      
      // Update access time for LRU
      _memoryCache[cacheKey] = cachedResult.copyWith(
        lastAccessed: DateTime.now(),
      );
      
      debugPrint('✅ Cache hit for: $cacheKey');
      return cachedResult.result;
    } catch (e) {
      debugPrint('❌ Cache retrieval failed: $e');
      return null;
    }
  }

  @override
  Future<void> cacheResult(String imagePath, OCRResult result) async {
    if (!_isInitialized) return;
    
    try {
      final cacheKey = _generateCacheKey(imagePath);
      final now = DateTime.now();
      
      final cachedResult = CachedOCRResult(
        key: cacheKey,
        result: result,
        createdAt: now,
        lastAccessed: now,
        expiresAt: now.add(_cacheExpiration),
        filePath: imagePath,
        fileSize: await _getFileSize(imagePath),
      );
      
      // Add to memory cache
      _memoryCache[cacheKey] = cachedResult;
      
      // Maintain cache size limit
      await _enforceCacheLimit();
      
      // Persist to disk
      await _saveCacheIndex();
      
      debugPrint('✅ Cached result for: $cacheKey');
    } catch (e) {
      debugPrint('❌ Cache storage failed: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      _memoryCache.clear();
      
      if (await _indexFile.exists()) {
        await _indexFile.delete();
      }
      
      // Clear cache directory
      if (await _cacheDir.exists()) {
        await for (final entity in _cacheDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      
      debugPrint('✅ Cache cleared');
    } catch (e) {
      debugPrint('❌ Cache clear failed: $e');
    }
  }

  @override
  Future<void> clearExpired() async {
    if (!_isInitialized) return;
    
    try {
      final now = DateTime.now();
      final expiredKeys = _memoryCache.entries
          .where((entry) => now.isAfter(entry.value.expiresAt))
          .map((entry) => entry.key)
          .toList();
      
      for (final key in expiredKeys) {
        await _removeCacheEntry(key);
      }
      
      if (expiredKeys.isNotEmpty) {
        await _saveCacheIndex();
        debugPrint('✅ Removed ${expiredKeys.length} expired cache entries');
      }
    } catch (e) {
      debugPrint('❌ Cache cleanup failed: $e');
    }
  }

  @override
  Future<int> getCacheSize() async {
    return _memoryCache.length;
  }

  @override
  void dispose() {
    _memoryCache.clear();
    debugPrint('✅ Cache manager disposed');
  }

  // Private Methods
  Future<void> _loadCacheIndex() async {
    try {
      if (!await _indexFile.exists()) {
        return;
      }
      
      final content = await _indexFile.readAsString();
      if (content.trim().isEmpty) {
        return;
      }
      
      final Map<String, dynamic> cacheData = jsonDecode(content);
      final List<dynamic> entries = cacheData['entries'] ?? [];
      
      for (final entryData in entries) {
        try {
          final cachedResult = CachedOCRResult.fromJson(entryData);
          _memoryCache[cachedResult.key] = cachedResult;
        } catch (e) {
          debugPrint('⚠️ Skipping corrupted cache entry: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load cache index: $e');
      // If index is corrupted, start fresh
      _memoryCache.clear();
    }
  }

  Future<void> _saveCacheIndex() async {
    try {
      final cacheData = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'entries': _memoryCache.values.map((e) => e.toJson()).toList(),
      };
      
      await _indexFile.writeAsString(
        jsonEncode(cacheData),
        mode: FileMode.write,
      );
    } catch (e) {
      debugPrint('❌ Failed to save cache index: $e');
    }
  }

  Future<void> _cleanExpiredEntries() async {
    await clearExpired();
  }

  Future<void> _enforceCacheLimit() async {
    if (_memoryCache.length <= _maxCacheSize) return;
    
    // Sort by last accessed time (LRU)
    final sortedEntries = _memoryCache.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    
    // Remove oldest entries
    final toRemove = sortedEntries.length - _maxCacheSize;
    for (int i = 0; i < toRemove; i++) {
      await _removeCacheEntry(sortedEntries[i].key);
    }
    
    debugPrint('✅ Enforced cache limit - removed $toRemove entries');
  }

  Future<void> _removeCacheEntry(String key) async {
    _memoryCache.remove(key);
  }

  String _generateCacheKey(String imagePath) {
    final file = File(imagePath);
    final fileName = file.path.split('/').last;
    final lastModified = file.lastModifiedSync().millisecondsSinceEpoch;
    final keyData = '$fileName-$lastModified';
    return sha256.convert(utf8.encode(keyData)).toString();
  }

  Future<int> _getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      return 0;
    }
  }
}

// Alternative Memory-only Cache Implementation
class MemoryOnlyCacheManager implements ICacheManager {
  static const int _maxCacheSize = 50; // Smaller for memory-only
  static const Duration _cacheExpiration = Duration(hours: 2); // Shorter for memory
  
  final Map<String, CachedOCRResult> _cache = {};

  @override
  Future<void> initialize() async {
    debugPrint('✅ Memory-only cache manager initialized');
  }

  @override
  Future<OCRResult?> getCachedResult(String imagePath) async {
    final cacheKey = _generateCacheKey(imagePath);
    final cached = _cache[cacheKey];
    
    if (cached == null) return null;
    
    if (DateTime.now().isAfter(cached.expiresAt)) {
      _cache.remove(cacheKey);
      return null;
    }
    
    // Update access time
    _cache[cacheKey] = cached.copyWith(lastAccessed: DateTime.now());
    return cached.result;
  }

  @override
  Future<void> cacheResult(String imagePath, OCRResult result) async {
    final cacheKey = _generateCacheKey(imagePath);
    final now = DateTime.now();
    
    _cache[cacheKey] = CachedOCRResult(
      key: cacheKey,
      result: result,
      createdAt: now,
      lastAccessed: now,
      expiresAt: now.add(_cacheExpiration),
      filePath: imagePath,
      fileSize: 0,
    );
    
    await _enforceCacheLimit();
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  @override
  Future<void> clearExpired() async {
    final now = DateTime.now();
    _cache.removeWhere((key, value) => now.isAfter(value.expiresAt));
  }

  @override
  Future<int> getCacheSize() async {
    return _cache.length;
  }

  @override
  void dispose() {
    _cache.clear();
  }

  Future<void> _enforceCacheLimit() async {
    if (_cache.length <= _maxCacheSize) return;
    
    final sortedEntries = _cache.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    
    final toRemove = _cache.length - _maxCacheSize;
    for (int i = 0; i < toRemove; i++) {
      _cache.remove(sortedEntries[i].key);
    }
  }

  String _generateCacheKey(String imagePath) {
    return imagePath.hashCode.toString();
  }
}

// Cached Result Model
class CachedOCRResult {
  final String key;
  final OCRResult result;
  final DateTime createdAt;
  final DateTime lastAccessed;
  final DateTime expiresAt;
  final String filePath;
  final int fileSize;

  CachedOCRResult({
    required this.key,
    required this.result,
    required this.createdAt,
    required this.lastAccessed,
    required this.expiresAt,
    required this.filePath,
    required this.fileSize,
  });

  CachedOCRResult copyWith({
    String? key,
    OCRResult? result,
    DateTime? createdAt,
    DateTime? lastAccessed,
    DateTime? expiresAt,
    String? filePath,
    int? fileSize,
  }) {
    return CachedOCRResult(
      key: key ?? this.key,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      expiresAt: expiresAt ?? this.expiresAt,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'result': _ocrResultToJson(result),
      'created_at': createdAt.toIso8601String(),
      'last_accessed': lastAccessed.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'file_path': filePath,
      'file_size': fileSize,
    };
  }

  factory CachedOCRResult.fromJson(Map<String, dynamic> json) {
    return CachedOCRResult(
      key: json['key'],
      result: _ocrResultFromJson(json['result']),
      createdAt: DateTime.parse(json['created_at']),
      lastAccessed: DateTime.parse(json['last_accessed']),
      expiresAt: DateTime.parse(json['expires_at']),
      filePath: json['file_path'],
      fileSize: json['file_size'],
    );
  }

  static Map<String, dynamic> _ocrResultToJson(OCRResult result) {
    return {
      'full_text': result.fullText,
      'prices': result.prices.map((p) => _priceToJson(p)).toList(),
      'confidence': result.confidence,
      'enhancement': result.enhancement.toString(),
      'store_type': result.storeType,
      'metadata': result.metadata,
    };
  }

  static OCRResult _ocrResultFromJson(Map<String, dynamic> json) {
    return OCRResult(
      fullText: json['full_text'],
      prices: (json['prices'] as List)
          .map((p) => _priceFromJson(p))
          .toList(),
      confidence: json['confidence'].toDouble(),
      enhancement: _enhancementFromString(json['enhancement']),
      storeType: json['store_type'],
      metadata: Map<String, dynamic>.from(json['metadata']),
    );
  }

  static Map<String, dynamic> _priceToJson(ExtractedPrice price) {
    return {
      'item_name': price.itemName,
      'price': price.price,
      'original_text': price.originalText,
      'confidence': price.confidence,
      'position': {
        'left': price.position.left,
        'top': price.position.top,
        'width': price.position.width,
        'height': price.position.height,
      },
      'category': price.category,
      'unit': price.unit,
      'metadata': price.metadata,
    };
  }

  static ExtractedPrice _priceFromJson(Map<String, dynamic> json) {
    final pos = json['position'];
    return ExtractedPrice(
      itemName: json['item_name'],
      price: json['price'].toDouble(),
      originalText: json['original_text'],
      confidence: json['confidence'].toDouble(),
      position: Rect.fromLTWH(
        pos['left'].toDouble(),
        pos['top'].toDouble(),
        pos['width'].toDouble(),
        pos['height'].toDouble(),
      ),
      category: json['category'],
      unit: json['unit'],
      metadata: json['metadata'] != null 
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  static EnhancementType _enhancementFromString(String enhancement) {
    switch (enhancement) {
      case 'EnhancementType.original':
        return EnhancementType.original;
      case 'EnhancementType.contrast':
        return EnhancementType.contrast;
      case 'EnhancementType.brightness':
        return EnhancementType.brightness;
      case 'EnhancementType.sharpen':
        return EnhancementType.sharpen;
      case 'EnhancementType.grayscale':
        return EnhancementType.grayscale;
      case 'EnhancementType.binarize':
        return EnhancementType.binarize;
      case 'EnhancementType.hybrid':
        return EnhancementType.hybrid;
      default:
        return EnhancementType.original;
    }
  }
}

// Cache Statistics for Monitoring
class CacheStatistics {
  final int totalEntries;
  final int hitCount;
  final int missCount;
  final double hitRate;
  final int totalSizeBytes;
  final DateTime oldestEntry;
  final DateTime newestEntry;

  CacheStatistics({
    required this.totalEntries,
    required this.hitCount,
    required this.missCount,
    required this.hitRate,
    required this.totalSizeBytes,
    required this.oldestEntry,
    required this.newestEntry,
  });
}

// Cache Configuration
class CacheConfig {
  final int maxEntries;
  final Duration expiration;
  final bool persistToDisk;
  final String? customCacheDirectory;

  const CacheConfig({
    this.maxEntries = 100,
    this.expiration = const Duration(days: 7),
    this.persistToDisk = true,
    this.customCacheDirectory,
  });
}

// Advanced Cache Manager with Statistics
class AdvancedCacheManager implements ICacheManager {
  final CacheConfig config;
  final ICacheManager _delegate;
  
  int _hitCount = 0;
  int _missCount = 0;

  AdvancedCacheManager({
    required this.config,
    ICacheManager? delegate,
  }) : _delegate = delegate ?? 
    (config.persistToDisk 
        ? OCRCacheManager() 
        : MemoryOnlyCacheManager());

  @override
  Future<void> initialize() async {
    await _delegate.initialize();
  }

  @override
  Future<OCRResult?> getCachedResult(String imagePath) async {
    final result = await _delegate.getCachedResult(imagePath);
    
    if (result != null) {
      _hitCount++;
    } else {
      _missCount++;
    }
    
    return result;
  }

  @override
  Future<void> cacheResult(String imagePath, OCRResult result) async {
    await _delegate.cacheResult(imagePath, result);
  }

  @override
  Future<void> clear() async {
    await _delegate.clear();
    _hitCount = 0;
    _missCount = 0;
  }

  @override
  Future<void> clearExpired() async {
    await _delegate.clearExpired();
  }

  @override
  Future<int> getCacheSize() async {
    return await _delegate.getCacheSize();
  }

  Future<CacheStatistics> getStatistics() async {
    final totalRequests = _hitCount + _missCount;
    final hitRate = totalRequests > 0 ? _hitCount / totalRequests : 0.0;
    
    return CacheStatistics(
      totalEntries: await getCacheSize(),
      hitCount: _hitCount,
      missCount: _missCount,
      hitRate: hitRate,
      totalSizeBytes: 0, // Could be implemented
      oldestEntry: DateTime.now(), // Could be tracked
      newestEntry: DateTime.now(), // Could be tracked
    );
  }

  @override
  void dispose() {
    _delegate.dispose();
  }
}

// Factory for creating cache managers
class CacheManagerFactory {
  static ICacheManager create({CacheConfig? config}) {
    final cacheConfig = config ?? const CacheConfig();
    
    return AdvancedCacheManager(
      config: cacheConfig,
      delegate: cacheConfig.persistToDisk 
          ? OCRCacheManager()
          : MemoryOnlyCacheManager(),
    );
  }

  static ICacheManager createMemoryOnly() {
    return MemoryOnlyCacheManager();
  }

  static ICacheManager createPersistent({
    int maxEntries = 100,
    Duration expiration = const Duration(days: 7),
  }) {
    return OCRCacheManager();
  }
}
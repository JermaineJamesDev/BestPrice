import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ocr_processor.dart';
import 'ocr_error_handler.dart';
import 'ocr_performance_monitor.dart';
import 'ocr_cache_manager.dart';
import 'performance_optimized_ocr_manager.dart';
import 'nlp_processor.dart';

/// Configuration for UnifiedOCRService
class OCRServiceConfig {
  /// Whether to use persistent cache (file-based) or in-memory only
  final bool usePersistentCache;
  
  /// Maximum number of retry attempts for failed operations
  final int maxRetryAttempts;
  
  /// Timeout duration for OCR operations
  final Duration ocrTimeout;
  
  /// Whether to enable performance monitoring
  final bool enablePerformanceMonitoring;
  
  /// Processing priority for resource allocation
  final ProcessingPriority defaultPriority;
  
  const OCRServiceConfig({
    this.usePersistentCache = true,
    this.maxRetryAttempts = 3,
    this.ocrTimeout = const Duration(seconds: 30),
    this.enablePerformanceMonitoring = true,
    this.defaultPriority = ProcessingPriority.normal,
  });
}

/// Unified OCR Service that orchestrates all OCR-related operations
/// This is a thin wrapper that integrates all existing services
class UnifiedOCRService {
  static OCRServiceConfig _config = const OCRServiceConfig();
  static late ICacheManager _cacheManager;
  static late NLPProcessor _nlpProcessor;
  static bool _isInitialized = false;
  
  /// Initialize the service with optional configuration
  static Future<void> initialize({OCRServiceConfig? config}) async {
    if (_isInitialized) {
      debugPrint('UnifiedOCRService: Already initialized');
      return;
    }
    
    try {
      _config = config ?? const OCRServiceConfig();
      
      // Initialize cache based on configuration
      _cacheManager = _config.usePersistentCache
          ? OCRCacheManager()
          : MemoryOnlyCacheManager();
      await _cacheManager.initialize();
      
      // Initialize other services
      await OCRProcessor.initialize();
      await OCRPerformanceMonitor.initialize();
      _nlpProcessor = NLPProcessor();
      await _nlpProcessor.initialize();
      
      _isInitialized = true;
      debugPrint('UnifiedOCRService: Initialized successfully with ${_config.usePersistentCache ? "persistent" : "in-memory"} cache');
    } catch (e) {
      debugPrint('UnifiedOCRService: Failed to initialize - $e');
      rethrow;
    }
  }
  
  /// Process a single receipt image
  static Future<OCRResult> processSingleReceipt(
    String imagePath, {
    CancellationToken? cancellationToken,
    ProcessingPriority? priority,
  }) async {
    _ensureInitialized();
    
    final effectivePriority = priority ?? _config.defaultPriority;
    final token = cancellationToken ?? CancellationToken();
    
    // Create context for error handling
    final errorContext = OCRErrorContext(
      operation: 'process_single_receipt',
      imagePath: imagePath,
      metadata: {
        'priority': effectivePriority.toString(),
        'cache_type': _config.usePersistentCache ? 'persistent' : 'memory',
      },
    );
    
    // Execute with error recovery
    return await OCRErrorRecovery.executeWithRecovery(
      () => _processSingleReceiptInternal(imagePath, effectivePriority, token),
      'process_single_receipt',
      maxAttempts: _config.maxRetryAttempts,
      context: errorContext,
      onError: (error, attempt) {
        debugPrint('UnifiedOCRService: Processing error (attempt $attempt): $error');
      },
      onRetry: (attempt) {
        debugPrint('UnifiedOCRService: Retrying processing (attempt $attempt)');
      },
      onSuccess: (result) {
        debugPrint('UnifiedOCRService: Successfully processed receipt with ${result.prices.length} prices');
      },
    ) ?? _createEmptyResult();
  }
  
  /// Process a long receipt with multiple sections
  static Future<OCRResult> processLongReceipt(
    List<String> sectionPaths, {
    CancellationToken? cancellationToken,
    ProcessingPriority? priority,
  }) async {
    _ensureInitialized();
    
    if (sectionPaths.isEmpty) {
      throw OCRException(
        'No receipt sections provided',
        type: OCRErrorType.insufficientSections,
      );
    }
    
    final effectivePriority = priority ?? _config.defaultPriority;
    final token = cancellationToken ?? CancellationToken();
    
    // Create context for error handling
    final errorContext = OCRErrorContext(
      operation: 'process_long_receipt',
      metadata: {
        'section_count': sectionPaths.length,
        'priority': effectivePriority.toString(),
      },
    );
    
    // Execute with error recovery
    return await OCRErrorRecovery.executeWithRecovery(
      () => _processLongReceiptInternal(sectionPaths, effectivePriority, token),
      'process_long_receipt',
      maxAttempts: _config.maxRetryAttempts,
      context: errorContext,
      onError: (error, attempt) {
        debugPrint('UnifiedOCRService: Long receipt processing error (attempt $attempt): $error');
      },
      onRetry: (attempt) {
        debugPrint('UnifiedOCRService: Retrying long receipt processing (attempt $attempt)');
      },
      onSuccess: (result) {
        debugPrint('UnifiedOCRService: Successfully processed long receipt with ${result.prices.length} prices from ${sectionPaths.length} sections');
      },
    ) ?? _createEmptyResult();
  }
  
  /// Process a receipt (automatically detects if it's long or single)
  static Future<OCRResult> processReceipt(
    dynamic input, {
    CancellationToken? cancellationToken,
    ProcessingPriority? priority,
  }) async {
    if (input is String) {
      return processSingleReceipt(
        input,
        cancellationToken: cancellationToken,
        priority: priority,
      );
    } else if (input is List<String>) {
      return processLongReceipt(
        input,
        cancellationToken: cancellationToken,
        priority: priority,
      );
    } else {
      throw OCRException(
        'Invalid input type. Expected String or List<String>',
        type: OCRErrorType.unknown,
      );
    }
  }
  
  /// Get performance statistics
  static Future<Map<String, dynamic>> getPerformanceStats() async {
    if (!_config.enablePerformanceMonitoring) {
      return {'monitoring_enabled': false};
    }
    
    final report = OCRPerformanceMonitor.generateReport();
    final cacheSize = await _cacheManager.getCacheSize();
    
    return {
      'monitoring_enabled': true,
      'cache_size': cacheSize,
      'cache_type': _config.usePersistentCache ? 'persistent' : 'memory',
      'performance_report': report.toJson(),
    };
  }
  
  /// Clear the cache
  static Future<void> clearCache() async {
    await _cacheManager.clear();
    debugPrint('UnifiedOCRService: Cache cleared');
  }
  
  /// Dispose of resources
  static Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      await _cacheManager.clearExpired();
      _cacheManager.dispose();
      OCRProcessor.dispose();
      _nlpProcessor.dispose();
      PerformanceOptimizedOCRManager.cancelAllOperations();
      
      _isInitialized = false;
      debugPrint('UnifiedOCRService: Disposed successfully');
    } catch (e) {
      debugPrint('UnifiedOCRService: Error during disposal - $e');
    }
  }
  
  // Private implementation methods
  
  static void _ensureInitialized() {
    if (!_isInitialized) {
      throw OCRException(
        'UnifiedOCRService not initialized. Call initialize() first.',
        type: OCRErrorType.unknown,
      );
    }
  }
  
  static Future<OCRResult> _processSingleReceiptInternal(
    String imagePath,
    ProcessingPriority priority,
    CancellationToken token,
  ) async {
    final sessionId = _generateSessionId();
    final stopwatch = Stopwatch()..start();
    
    try {
      // 1. Check cache first
      final cached = await _cacheManager.getCachedResult(imagePath);
      if (cached != null) {
        debugPrint('UnifiedOCRService: Cache hit for $imagePath');
        
        // Log cache hit to performance monitor
        if (_config.enablePerformanceMonitoring) {
          await OCRPerformanceMonitor.logOCRAttempt(
            sessionId: sessionId,
            imagePath: imagePath,
            processingTimeMs: 0,
            extractedPricesCount: cached.prices.length,
            averageConfidence: cached.confidence,
            bestEnhancement: cached.enhancement.toString(),
            storeType: cached.storeType,
            isLongReceipt: false,
            metadata: {'cache_hit': true},
          );
        }
        
        return cached;
      }
      
      // 2. Process with performance optimization
      final result = await PerformanceOptimizedOCRManager.processWithOptimization(
        imagePath,
        priority: priority,
        cancellationToken: token,
      ).timeout(_config.ocrTimeout);
      
      // 3. Apply NLP enhancements
      final enhancedResult = await _applyNLPEnhancements(result);
      
      // 4. Cache the result
      await _cacheManager.cacheResult(imagePath, enhancedResult);
      
      stopwatch.stop();
      
      // 5. Log performance metrics
      if (_config.enablePerformanceMonitoring) {
        await OCRPerformanceMonitor.logOCRAttempt(
          sessionId: sessionId,
          imagePath: imagePath,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          extractedPricesCount: enhancedResult.prices.length,
          averageConfidence: enhancedResult.confidence,
          bestEnhancement: enhancedResult.enhancement.toString(),
          storeType: enhancedResult.storeType,
          isLongReceipt: false,
          metadata: {
            'cache_hit': false,
            'nlp_enhanced': true,
            ...enhancedResult.metadata,
          },
        );
      }
      
      return enhancedResult;
    } catch (e) {
      stopwatch.stop();
      
      // Log failure
      if (_config.enablePerformanceMonitoring) {
        await OCRPerformanceMonitor.logOCRAttempt(
          sessionId: sessionId,
          imagePath: imagePath,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          extractedPricesCount: 0,
          averageConfidence: 0.0,
          bestEnhancement: 'none',
          storeType: 'unknown',
          isLongReceipt: false,
          metadata: {},
          errorMessage: e.toString(),
        );
      }
      
      rethrow;
    }
  }
  
  static Future<OCRResult> _processLongReceiptInternal(
    List<String> sectionPaths,
    ProcessingPriority priority,
    CancellationToken token,
  ) async {
    final sessionId = _generateSessionId();
    final stopwatch = Stopwatch()..start();
    
    try {
      // For long receipts, we'll use a cache key based on the first section path
      final cacheKey = '${sectionPaths.first}_long_${sectionPaths.length}';
      
      // 1. Check cache
      final cached = await _cacheManager.getCachedResult(cacheKey);
      if (cached != null) {
        debugPrint('UnifiedOCRService: Cache hit for long receipt');
        return cached;
      }
      
      // 2. Process each section
      final sectionResults = <OCRResult>[];
      for (int i = 0; i < sectionPaths.length; i++) {
        if (token.isCancelled) {
          throw CancellationException('Long receipt processing cancelled');
        }
        
        debugPrint('UnifiedOCRService: Processing section ${i + 1}/${sectionPaths.length}');
        
        final sectionResult = await PerformanceOptimizedOCRManager.processWithOptimization(
          sectionPaths[i],
          priority: priority,
          cancellationToken: token,
          isLongReceipt: true,
        ).timeout(_config.ocrTimeout);
        
        sectionResults.add(sectionResult);
      }
      
      // 3. Merge results
      final mergedResult = _mergeLongReceiptResults(sectionResults);
      
      // 4. Apply NLP enhancements
      final enhancedResult = await _applyNLPEnhancements(mergedResult);
      
      // 5. Cache the result
      await _cacheManager.cacheResult(cacheKey, enhancedResult);
      
      stopwatch.stop();
      
      // 6. Log performance metrics
      if (_config.enablePerformanceMonitoring) {
        await OCRPerformanceMonitor.logOCRAttempt(
          sessionId: sessionId,
          imagePath: cacheKey,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          extractedPricesCount: enhancedResult.prices.length,
          averageConfidence: enhancedResult.confidence,
          bestEnhancement: enhancedResult.enhancement.toString(),
          storeType: enhancedResult.storeType,
          isLongReceipt: true,
          metadata: {
            'cache_hit': false,
            'section_count': sectionPaths.length,
            'nlp_enhanced': true,
            ...enhancedResult.metadata,
          },
        );
      }
      
      return enhancedResult;
    } catch (e) {
      stopwatch.stop();
      
      // Log failure
      if (_config.enablePerformanceMonitoring) {
        await OCRPerformanceMonitor.logOCRAttempt(
          sessionId: sessionId,
          imagePath: sectionPaths.first,
          processingTimeMs: stopwatch.elapsedMilliseconds,
          extractedPricesCount: 0,
          averageConfidence: 0.0,
          bestEnhancement: 'none',
          storeType: 'unknown',
          isLongReceipt: true,
          metadata: {
            'section_count': sectionPaths.length,
          },
          errorMessage: e.toString(),
        );
      }
      
      rethrow;
    }
  }
  
  static OCRResult _mergeLongReceiptResults(List<OCRResult> sectionResults) {
    if (sectionResults.isEmpty) {
      return _createEmptyResult();
    }
    
    // Merge all prices
    final allPrices = <ExtractedPrice>[];
    final allText = <String>[];
    double totalConfidence = 0.0;
    
    for (int i = 0; i < sectionResults.length; i++) {
      final result = sectionResults[i];
      allPrices.addAll(result.prices);
      allText.add('--- Section ${i + 1} ---\n${result.fullText}');
      totalConfidence += result.confidence;
    }
    
    // Remove duplicates using NLP similarity
    final uniquePrices = _nlpProcessor.removeSemanticDuplicates(allPrices);
    
    // Calculate average confidence
    final avgConfidence = sectionResults.isNotEmpty 
        ? totalConfidence / sectionResults.length 
        : 0.0;
    
    return OCRResult(
      fullText: allText.join('\n\n'),
      prices: uniquePrices,
      confidence: avgConfidence,
      enhancement: EnhancementType.hybrid,
      storeType: sectionResults.first.storeType,
      metadata: {
        'merged_from_sections': sectionResults.length,
        'total_prices_before_dedup': allPrices.length,
        'unique_prices': uniquePrices.length,
      },
    );
  }
  
  static Future<OCRResult> _applyNLPEnhancements(OCRResult result) async {
    try {
      final enhancedPrices = <ExtractedPrice>[];
      
      for (final price in result.prices) {
        // Clean item name
        final cleanedName = _nlpProcessor.cleanItemName(price.itemName);
        
        // Detect category
        final category = _nlpProcessor.detectCategory(
          cleanedName,
          price.originalText,
          result.storeType,
        );
        
        // Extract unit
        final unit = _nlpProcessor.extractUnit(
          price.originalText,
          category,
        );
        
        // Validate price
        final isValid = _nlpProcessor.validatePrice(
          price.price,
          category,
          result.storeType,
        );
        
        if (isValid) {
          enhancedPrices.add(ExtractedPrice(
            itemName: cleanedName,
            price: price.price,
            originalText: price.originalText,
            confidence: (price.confidence * 1.1).clamp(0.0, 1.0),
            position: price.position,
            category: category,
            unit: unit,
            metadata: {
              ...price.metadata ?? {},
              'nlp_enhanced': true,
              'original_name': price.itemName,
            },
          ));
        }
      }
      
      // Remove semantic duplicates
      final uniquePrices = _nlpProcessor.removeSemanticDuplicates(enhancedPrices);
      
      return OCRResult(
        fullText: result.fullText,
        prices: uniquePrices,
        confidence: result.confidence,
        enhancement: result.enhancement,
        storeType: result.storeType,
        metadata: {
          ...result.metadata,
          'nlp_enhanced': true,
          'original_price_count': result.prices.length,
          'enhanced_price_count': uniquePrices.length,
        },
      );
    } catch (e) {
      debugPrint('UnifiedOCRService: NLP enhancement failed - $e');
      // Return original result if enhancement fails
      return result;
    }
  }
  
  static String _generateSessionId() {
    return 'unified_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
  
  static OCRResult _createEmptyResult() {
    return OCRResult(
      fullText: '',
      prices: [],
      confidence: 0.0,
      enhancement: EnhancementType.original,
      storeType: 'unknown',
      metadata: {'empty_result': true},
    );
  }
}

/// Extension to make using the service easier
extension UnifiedOCRServiceExtension on String {
  /// Process this image path as a receipt
  Future<OCRResult> processAsReceipt({
    CancellationToken? cancellationToken,
    ProcessingPriority? priority,
  }) {
    return UnifiedOCRService.processSingleReceipt(
      this,
      cancellationToken: cancellationToken,
      priority: priority,
    );
  }
}

/// Extension for list of paths
extension UnifiedOCRServiceListExtension on List<String> {
  /// Process this list of paths as a long receipt
  Future<OCRResult> processAsLongReceipt({
    CancellationToken? cancellationToken,
    ProcessingPriority? priority,
  }) {
    return UnifiedOCRService.processLongReceipt(
      this,
      cancellationToken: cancellationToken,
      priority: priority,
    );
  }
}
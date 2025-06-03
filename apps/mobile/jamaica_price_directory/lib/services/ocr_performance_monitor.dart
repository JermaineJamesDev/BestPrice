import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class OCRPerformanceMonitor {
  static const String _logFileName = 'ocr_performance.log';
  static const int _maxLogEntries = 1000;
  static final List<OCRPerformanceData> _performanceData = [];
  static File? _logFile;

  static Future<void> initialize() async {
    if (kDebugMode) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/$_logFileName');
        
        // Load existing log data
        if (await _logFile!.exists()) {
          await _loadExistingData();
        }
      } catch (e) {
        debugPrint('Failed to initialize OCR performance monitor: $e');
      }
    }
  }

  static Future<void> _loadExistingData() async {
    try {
      final content = await _logFile!.readAsString();
      final lines = content.split('\n').where((line) => line.isNotEmpty);
      
      for (final line in lines.take(_maxLogEntries ~/ 2)) {
        try {
          final data = OCRPerformanceData.fromJson(jsonDecode(line));
          _performanceData.add(data);
        } catch (e) {
          // Skip invalid entries
        }
      }
    } catch (e) {
      debugPrint('Failed to load existing performance data: $e');
    }
  }

  static Future<void> logOCRAttempt({
    required String sessionId,
    required String imagePath,
    required int processingTimeMs,
    required int extractedPricesCount,
    required double averageConfidence,
    required String bestEnhancement,
    required String storeType,
    required bool isLongReceipt,
    required Map<String, dynamic> metadata,
    String? errorMessage,
  }) async {
    final data = OCRPerformanceData(
      sessionId: sessionId,
      timestamp: DateTime.now(),
      imagePath: imagePath,
      processingTimeMs: processingTimeMs,
      extractedPricesCount: extractedPricesCount,
      averageConfidence: averageConfidence,
      bestEnhancement: bestEnhancement,
      storeType: storeType,
      isLongReceipt: isLongReceipt,
      metadata: metadata,
      errorMessage: errorMessage,
      isSuccess: errorMessage == null,
    );

    _performanceData.add(data);
    
    // Keep only recent entries
    if (_performanceData.length > _maxLogEntries) {
      _performanceData.removeAt(0);
    }

    await _writeToLog(data);

    if (kDebugMode) {
      _printPerformanceStats();
    }
  }

  static Future<void> _writeToLog(OCRPerformanceData data) async {
    if (_logFile != null && kDebugMode) {
      try {
        final jsonString = jsonEncode(data.toJson());
        await _logFile!.writeAsString('$jsonString\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write performance log: $e');
      }
    }
  }

  static void _printPerformanceStats() {
    if (_performanceData.isEmpty) return;

    final recentData = _performanceData.take(50).toList();
    final successfulAttempts = recentData.where((d) => d.isSuccess).toList();
    
    if (successfulAttempts.isEmpty) return;

    final avgProcessingTime = successfulAttempts
        .map((d) => d.processingTimeMs)
        .reduce((a, b) => a + b) / successfulAttempts.length;

    final avgConfidence = successfulAttempts
        .map((d) => d.averageConfidence)
        .reduce((a, b) => a + b) / successfulAttempts.length;

    final avgPricesExtracted = successfulAttempts
        .map((d) => d.extractedPricesCount)
        .reduce((a, b) => a + b) / successfulAttempts.length;

    final successRate = (successfulAttempts.length / recentData.length) * 100;

    debugPrint('🔍 OCR Performance Stats (last 50 attempts):');
    debugPrint('   Success Rate: ${successRate.toStringAsFixed(1)}%');
    debugPrint('   Avg Processing Time: ${avgProcessingTime.toStringAsFixed(0)}ms');
    debugPrint('   Avg Confidence: ${(avgConfidence * 100).toStringAsFixed(1)}%');
    debugPrint('   Avg Prices Extracted: ${avgPricesExtracted.toStringAsFixed(1)}');
  }

  static OCRPerformanceReport generateReport() {
    if (_performanceData.isEmpty) {
      return OCRPerformanceReport.empty();
    }

    final totalAttempts = _performanceData.length;
    final successfulAttempts = _performanceData.where((d) => d.isSuccess).toList();
    final failedAttempts = _performanceData.where((d) => !d.isSuccess).toList();

    // Calculate metrics
    final successRate = (successfulAttempts.length / totalAttempts) * 100;
    
    final avgProcessingTime = successfulAttempts.isNotEmpty
        ? successfulAttempts.map((d) => d.processingTimeMs).reduce((a, b) => a + b) / successfulAttempts.length
        : 0.0;

    final avgConfidence = successfulAttempts.isNotEmpty
        ? successfulAttempts.map((d) => d.averageConfidence).reduce((a, b) => a + b) / successfulAttempts.length
        : 0.0;

    final avgPricesExtracted = successfulAttempts.isNotEmpty
        ? successfulAttempts.map((d) => d.extractedPricesCount).reduce((a, b) => a + b) / successfulAttempts.length
        : 0.0;

    // Enhancement effectiveness
    final enhancementStats = <String, int>{};
    for (final attempt in successfulAttempts) {
      enhancementStats[attempt.bestEnhancement] = 
          (enhancementStats[attempt.bestEnhancement] ?? 0) + 1;
    }

    // Store type performance
    final storeTypeStats = <String, List<OCRPerformanceData>>{};
    for (final attempt in successfulAttempts) {
      storeTypeStats.putIfAbsent(attempt.storeType, () => []).add(attempt);
    }

    // Common errors
    final errorStats = <String, int>{};
    for (final attempt in failedAttempts) {
      if (attempt.errorMessage != null) {
        errorStats[attempt.errorMessage!] = 
            (errorStats[attempt.errorMessage!] ?? 0) + 1;
      }
    }

    return OCRPerformanceReport(
      totalAttempts: totalAttempts,
      successfulAttempts: successfulAttempts.length,
      failedAttempts: failedAttempts.length,
      successRate: successRate,
      averageProcessingTime: avgProcessingTime,
      averageConfidence: avgConfidence,
      averagePricesExtracted: avgPricesExtracted,
      enhancementStats: enhancementStats,
      storeTypeStats: storeTypeStats.map((key, value) => MapEntry(
        key,
        StoreTypePerformance(
          attempts: value.length,
          avgConfidence: value.map((d) => d.averageConfidence).reduce((a, b) => a + b) / value.length,
          avgPricesExtracted: value.map((d) => d.extractedPricesCount).reduce((a, b) => a + b) / value.length,
          avgProcessingTime: value.map((d) => d.processingTimeMs).reduce((a, b) => a + b) / value.length,
        ),
      )),
      errorStats: errorStats,
      longReceiptPerformance: _analyzeLongReceiptPerformance(),
    );
  }

  static LongReceiptPerformance _analyzeLongReceiptPerformance() {
    final longReceiptAttempts = _performanceData.where((d) => d.isLongReceipt).toList();
    final successfulLongReceipts = longReceiptAttempts.where((d) => d.isSuccess).toList();

    if (longReceiptAttempts.isEmpty) {
      return LongReceiptPerformance.empty();
    }

    final avgSections = successfulLongReceipts.isNotEmpty
        ? successfulLongReceipts
            .map((d) => d.metadata['total_sections'] ?? 1)
            .reduce((a, b) => a + b) / successfulLongReceipts.length
        : 0.0;

    final avgProcessingTime = successfulLongReceipts.isNotEmpty
        ? successfulLongReceipts.map((d) => d.processingTimeMs).reduce((a, b) => a + b) / successfulLongReceipts.length
        : 0.0;

    return LongReceiptPerformance(
      totalAttempts: longReceiptAttempts.length,
      successfulAttempts: successfulLongReceipts.length,
      averageSections: avgSections,
      averageProcessingTime: avgProcessingTime,
    );
  }

  static Future<void> exportPerformanceData() async {
    if (kDebugMode && _performanceData.isNotEmpty) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final exportFile = File('${directory.path}/ocr_performance_export_${DateTime.now().millisecondsSinceEpoch}.json');
        
        final exportData = {
          'export_timestamp': DateTime.now().toIso8601String(),
          'total_entries': _performanceData.length,
          'performance_data': _performanceData.map((d) => d.toJson()).toList(),
          'summary': generateReport().toJson(),
        };

        await exportFile.writeAsString(jsonEncode(exportData));
        debugPrint('📊 Performance data exported to: ${exportFile.path}');
      } catch (e) {
        debugPrint('Failed to export performance data: $e');
      }
    }
  }

  static void clearData() {
    _performanceData.clear();
    if (_logFile != null && kDebugMode) {
      _logFile!.writeAsString('');
    }
  }

  static List<OCRPerformanceData> getRecentData({int limit = 100}) {
    return _performanceData.reversed.take(limit).toList();
  }
}

class OCRPerformanceData {
  final String sessionId;
  final DateTime timestamp;
  final String imagePath;
  final int processingTimeMs;
  final int extractedPricesCount;
  final double averageConfidence;
  final String bestEnhancement;
  final String storeType;
  final bool isLongReceipt;
  final Map<String, dynamic> metadata;
  final String? errorMessage;
  final bool isSuccess;

  OCRPerformanceData({
    required this.sessionId,
    required this.timestamp,
    required this.imagePath,
    required this.processingTimeMs,
    required this.extractedPricesCount,
    required this.averageConfidence,
    required this.bestEnhancement,
    required this.storeType,
    required this.isLongReceipt,
    required this.metadata,
    this.errorMessage,
    required this.isSuccess,
  });

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'image_path': imagePath,
      'processing_time_ms': processingTimeMs,
      'extracted_prices_count': extractedPricesCount,
      'average_confidence': averageConfidence,
      'best_enhancement': bestEnhancement,
      'store_type': storeType,
      'is_long_receipt': isLongReceipt,
      'metadata': metadata,
      'error_message': errorMessage,
      'is_success': isSuccess,
    };
  }

  factory OCRPerformanceData.fromJson(Map<String, dynamic> json) {
    return OCRPerformanceData(
      sessionId: json['session_id'],
      timestamp: DateTime.parse(json['timestamp']),
      imagePath: json['image_path'],
      processingTimeMs: json['processing_time_ms'],
      extractedPricesCount: json['extracted_prices_count'],
      averageConfidence: json['average_confidence'].toDouble(),
      bestEnhancement: json['best_enhancement'],
      storeType: json['store_type'],
      isLongReceipt: json['is_long_receipt'],
      metadata: Map<String, dynamic>.from(json['metadata']),
      errorMessage: json['error_message'],
      isSuccess: json['is_success'],
    );
  }
}

class OCRPerformanceReport {
  final int totalAttempts;
  final int successfulAttempts;
  final int failedAttempts;
  final double successRate;
  final double averageProcessingTime;
  final double averageConfidence;
  final double averagePricesExtracted;
  final Map<String, int> enhancementStats;
  final Map<String, StoreTypePerformance> storeTypeStats;
  final Map<String, int> errorStats;
  final LongReceiptPerformance longReceiptPerformance;

  OCRPerformanceReport({
    required this.totalAttempts,
    required this.successfulAttempts,
    required this.failedAttempts,
    required this.successRate,
    required this.averageProcessingTime,
    required this.averageConfidence,
    required this.averagePricesExtracted,
    required this.enhancementStats,
    required this.storeTypeStats,
    required this.errorStats,
    required this.longReceiptPerformance,
  });

  factory OCRPerformanceReport.empty() {
    return OCRPerformanceReport(
      totalAttempts: 0,
      successfulAttempts: 0,
      failedAttempts: 0,
      successRate: 0.0,
      averageProcessingTime: 0.0,
      averageConfidence: 0.0,
      averagePricesExtracted: 0.0,
      enhancementStats: {},
      storeTypeStats: {},
      errorStats: {},
      longReceiptPerformance: LongReceiptPerformance.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_attempts': totalAttempts,
      'successful_attempts': successfulAttempts,
      'failed_attempts': failedAttempts,
      'success_rate': successRate,
      'average_processing_time': averageProcessingTime,
      'average_confidence': averageConfidence,
      'average_prices_extracted': averagePricesExtracted,
      'enhancement_stats': enhancementStats,
      'store_type_stats': storeTypeStats.map((key, value) => MapEntry(key, value.toJson())),
      'error_stats': errorStats,
      'long_receipt_performance': longReceiptPerformance.toJson(),
    };
  }
}

class StoreTypePerformance {
  final int attempts;
  final double avgConfidence;
  final double avgPricesExtracted;
  final double avgProcessingTime;

  StoreTypePerformance({
    required this.attempts,
    required this.avgConfidence,
    required this.avgPricesExtracted,
    required this.avgProcessingTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'attempts': attempts,
      'avg_confidence': avgConfidence,
      'avg_prices_extracted': avgPricesExtracted,
      'avg_processing_time': avgProcessingTime,
    };
  }
}

class LongReceiptPerformance {
  final int totalAttempts;
  final int successfulAttempts;
  final double averageSections;
  final double averageProcessingTime;

  LongReceiptPerformance({
    required this.totalAttempts,
    required this.successfulAttempts,
    required this.averageSections,
    required this.averageProcessingTime,
  });

  factory LongReceiptPerformance.empty() {
    return LongReceiptPerformance(
      totalAttempts: 0,
      successfulAttempts: 0,
      averageSections: 0.0,
      averageProcessingTime: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_attempts': totalAttempts,
      'successful_attempts': successfulAttempts,
      'average_sections': averageSections,
      'average_processing_time': averageProcessingTime,
    };
  }
}

// Debug UI for performance monitoring
class OCRDebugScreen extends StatefulWidget {
  const OCRDebugScreen({super.key});

  @override
  State<OCRDebugScreen> createState() => _OCRDebugScreenState();
}

class _OCRDebugScreenState extends State<OCRDebugScreen> {
  OCRPerformanceReport? _report;
  List<OCRPerformanceData> _recentData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _report = OCRPerformanceMonitor.generateReport();
      _recentData = OCRPerformanceMonitor.getRecentData(limit: 50);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        appBar: AppBar(title: Text('Debug Mode Only')),
        body: Center(
          child: Text('This screen is only available in debug mode'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('OCR Performance Debug'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              await OCRPerformanceMonitor.exportPerformanceData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Performance data exported')),
              );
            },
            icon: Icon(Icons.download),
          ),
        ],
      ),
      body: _report == null 
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(),
                SizedBox(height: 16),
                _buildEnhancementStatsCard(),
                SizedBox(height: 16),
                _buildStoreTypeStatsCard(),
                SizedBox(height: 16),
                _buildLongReceiptStatsCard(),
                SizedBox(height: 16),
                _buildErrorStatsCard(),
                SizedBox(height: 16),
                _buildRecentAttemptsCard(),
              ],
            ),
          ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Attempts',
                    '${_report!.totalAttempts}',
                    Icons.analytics,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Success Rate',
                    '${_report!.successRate.toStringAsFixed(1)}%',
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Avg Processing Time',
                    '${_report!.averageProcessingTime.toStringAsFixed(0)}ms',
                    Icons.timer,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Confidence',
                    '${(_report!.averageConfidence * 100).toStringAsFixed(1)}%',
                    Icons.verified,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancementStatsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enhancement Effectiveness',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ..._report!.enhancementStats.entries.map((entry) {
              final percentage = (_report!.successfulAttempts > 0)
                  ? (entry.value / _report!.successfulAttempts) * 100
                  : 0.0;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text('${entry.value} (${percentage.toStringAsFixed(1)}%)'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreTypeStatsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Type Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ..._report!.storeTypeStats.entries.map((entry) {
              final stats = entry.value;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('Attempts: ${stats.attempts}'),
                    Text('Avg Confidence: ${(stats.avgConfidence * 100).toStringAsFixed(1)}%'),
                    Text('Avg Prices: ${stats.avgPricesExtracted.toStringAsFixed(1)}'),
                    Text('Avg Time: ${stats.avgProcessingTime.toStringAsFixed(0)}ms'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLongReceiptStatsCard() {
    final longStats = _report!.longReceiptPerformance;
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Long Receipt Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            if (longStats.totalAttempts > 0) ...[
              Text('Total Attempts: ${longStats.totalAttempts}'),
              Text('Successful: ${longStats.successfulAttempts}'),
              Text('Success Rate: ${((longStats.successfulAttempts / longStats.totalAttempts) * 100).toStringAsFixed(1)}%'),
              Text('Avg Sections: ${longStats.averageSections.toStringAsFixed(1)}'),
              Text('Avg Processing Time: ${longStats.averageProcessingTime.toStringAsFixed(0)}ms'),
            ] else ...[
              Text('No long receipt attempts recorded'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorStatsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Common Errors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            if (_report!.errorStats.isEmpty) ...[
              Text('No errors recorded'),
            ] else ...[
              ..._report!.errorStats.entries.take(5).map((entry) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Text('${entry.value}x'),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAttemptsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Attempts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ..._recentData.take(10).map((data) {
              return Container(
                margin: EdgeInsets.symmetric(vertical: 4),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.isSuccess ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data.storeType.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${data.processingTimeMs}ms',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '${data.extractedPricesCount} prices, ${(data.averageConfidence * 100).toStringAsFixed(1)}% confidence',
                      style: TextStyle(fontSize: 12),
                    ),
                    if (!data.isSuccess && data.errorMessage != null)
                      Text(
                        'Error: ${data.errorMessage}',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: Color(0xFF1E3A8A)),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
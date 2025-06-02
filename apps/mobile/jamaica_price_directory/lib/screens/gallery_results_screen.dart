import 'package:flutter/material.dart';
import '../services/consolidated_ocr_service.dart';

class GalleryResultsScreen extends StatefulWidget {
  final BatchOCRResult batchResult;
  final ProcessingMode processingMode;
  final int originalFileCount;

  const GalleryResultsScreen({
    super.key,
    required this.batchResult,
    required this.processingMode,
    required this.originalFileCount,
  });

  @override
  _GalleryResultsScreenState createState() => _GalleryResultsScreenState();
}

class _GalleryResultsScreenState extends State<GalleryResultsScreen>
    with TickerProviderStateMixin {
  bool _isSubmitting = false;
  String? _selectedStore;
  String? _selectedParish;
  bool _showBatchDetails = false;
  late List<OCRResult> _editableResults;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _stores = [
    'Hi-Lo', 'MegaMart', 'SuperPlus', 'PriceSmart', 'Shoppers Fair',
    'Progressive', 'Loshusan', 'Fontana', 'General Food', 'Other'
  ];

  final List<String> _parishes = [
    'Kingston', 'St. Andrew', 'St. Thomas', 'Portland', 'St. Mary',
    'St. Ann', 'Trelawny', 'St. James', 'Hanover', 'Westmoreland',
    'St. Elizabeth', 'Manchester', 'Clarendon', 'St. Catherine',
  ];

  @override
  void initState() {
    super.initState();
    _editableResults = List.from(widget.batchResult.results);
    _selectedParish = 'Kingston';
    _setupAnimations();
    _detectStoreFromResults();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  void _detectStoreFromResults() {
    final successfulResults = _editableResults
        .where((r) => !(r.metadata['error'] ?? false))
        .toList();
    
    if (successfulResults.isNotEmpty) {
      final detectedStore = successfulResults.first.storeType;
      switch (detectedStore.toLowerCase()) {
        case 'pricesmart':
          _selectedStore = 'PriceSmart';
          break;
        case 'hi-lo':
        case 'hilo':
          _selectedStore = 'Hi-Lo';
          break;
        case 'megamart':
          _selectedStore = 'MegaMart';
          break;
        default:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.processingMode == ProcessingMode.longReceipt
            ? 'Long Receipt Results'
            : 'Gallery Processing Results'
        ),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _showBatchDetails = !_showBatchDetails),
            icon: Icon(Icons.analytics),
            tooltip: 'Batch Details',
          ),
          IconButton(
            onPressed: _exportResults,
            icon: Icon(Icons.download),
            tooltip: 'Export Results',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            if (_showBatchDetails) _buildBatchDetailsCard(),
            _buildStoreSelection(),
            _buildBatchSummary(),
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
      bottomNavigationBar: _hasValidResults() ? _buildSubmitButton() : null,
    );
  }

  Widget _buildBatchDetailsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Batch Processing Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticItem(
                  'Success Rate',
                  '${(widget.batchResult.successRate * 100).toStringAsFixed(1)}%',
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildAnalyticItem(
                  'Processing Time',
                  '${widget.batchResult.totalProcessingTime.inSeconds}s',
                  Icons.timer,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticItem(
                  'Total Prices',
                  '${_getTotalPricesCount()}',
                  Icons.receipt,
                ),
              ),
              Expanded(
                child: _buildAnalyticItem(
                  'Processing Mode',
                  widget.processingMode == ProcessingMode.longReceipt
                    ? 'Long Receipt'
                    : 'Individual',
                  Icons.settings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticItem(String label, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Text(
                'Store Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              if (_selectedStore != null) ...[
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Auto-detected',
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
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStore,
                  decoration: InputDecoration(
                    labelText: 'Store Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.store),
                  ),
                  items: _stores.map((store) {
                    return DropdownMenuItem(value: store, child: Text(store));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedStore = value),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedParish,
                  decoration: InputDecoration(
                    labelText: 'Parish',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: _parishes.map((parish) {
                    return DropdownMenuItem(value: parish, child: Text(parish));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedParish = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchSummary() {
    final totalPrices = _getTotalPricesCount();
    final avgConfidence = _getAverageConfidence();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.batchResult.hasResults ? Colors.green[50] : Colors.red[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                widget.batchResult.hasResults ? Icons.check_circle : Icons.warning,
                color: widget.batchResult.hasResults ? Colors.green : Colors.red,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.processingMode == ProcessingMode.longReceipt
                        ? 'Long Receipt Processed'
                        : 'Batch Processing Complete',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: widget.batchResult.hasResults 
                          ? Colors.green[700] 
                          : Colors.red[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.processingMode == ProcessingMode.longReceipt
                        ? '${widget.batchResult.results.length} section${widget.batchResult.results.length == 1 ? '' : 's'} merged into unified receipt'
                        : '${widget.batchResult.successfulImages}/${widget.batchResult.totalImages} images processed successfully',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (totalPrices > 0) ...[
                      SizedBox(height: 4),
                      Text(
                        '$totalPrices price${totalPrices == 1 ? '' : 's'} extracted • ${(avgConfidence * 100).toStringAsFixed(1)}% avg confidence',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showBatchDetails = !_showBatchDetails),
                    icon: Icon(Icons.analytics, size: 16),
                    label: Text('Details'),
                  ),
                  if (totalPrices == 0)
                    TextButton.icon(
                      onPressed: _addManualPrice,
                      icon: Icon(Icons.add),
                      label: Text('Add Price'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (!widget.batchResult.hasResults || _editableResults.isEmpty) {
      return _buildEmptyState();
    }

    if (widget.processingMode == ProcessingMode.longReceipt) {
      return _buildLongReceiptResults();
    } else {
      return _buildIndividualResults();
    }
  }

  Widget _buildIndividualResults() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _editableResults.length,
      itemBuilder: (context, index) {
        final result = _editableResults[index];
        final hasError = result.metadata['error'] ?? false;
        
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: hasError 
            ? _buildErrorResultCard(result, index)
            : _buildSuccessResultCard(result, index),
        );
      },
    );
  }

  Widget _buildLongReceiptResults() {
    final result = _editableResults.first;
    final hasError = result.metadata['error'] ?? false;
    
    if (hasError) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: result.prices.length,
      itemBuilder: (context, index) {
        return _buildPriceCard(result.prices[index], index, 0);
      },
    );
  }

  Widget _buildErrorResultCard(OCRResult result, int resultIndex) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Image ${resultIndex + 1} - Processing Failed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            result.metadata['error_message']?.toString() ?? 'Unknown error',
            style: TextStyle(color: Colors.red[600]),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _retryImage(resultIndex),
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addManualPriceForResult(resultIndex),
                  icon: Icon(Icons.edit),
                  label: Text('Manual Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessResultCard(OCRResult result, int resultIndex) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.image, color: Colors.green),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image ${resultIndex + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${result.prices.length} price${result.prices.length == 1 ? '' : 's'} • ${(result.confidence * 100).toStringAsFixed(1)}% confidence',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _addManualPriceForResult(resultIndex),
                icon: Icon(Icons.add),
                tooltip: 'Add Price',
              ),
            ],
          ),
          if (result.prices.isNotEmpty) ...[
            SizedBox(height: 16),
            ...result.prices.asMap().entries.map((entry) {
              return _buildPriceCard(entry.value, entry.key, resultIndex);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceCard(ExtractedPrice price, int priceIndex, int resultIndex) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.itemName.isEmpty ? 'Item ${priceIndex + 1}' : price.itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'J\$${price.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(price.confidence).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(price.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getConfidenceColor(price.confidence),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editPrice(resultIndex, priceIndex),
            icon: Icon(Icons.edit, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.1),
              foregroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No prices detected',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.processingMode == ProcessingMode.longReceipt
              ? 'The receipt sections might not contain clear price information.'
              : 'None of the images contained clear price information.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addManualPrice,
            icon: Icon(Icons.add),
            label: Text('Add Price Manually'),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1E3A8A)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final totalPrices = _getTotalPricesCount();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isSubmitting || totalPrices == 0 || _selectedStore == null
            ? null
            : _submitResults,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.processingMode == ProcessingMode.longReceipt
              ? Color(0xFF059669)
              : Color(0xFF1E3A8A),
            padding: EdgeInsets.symmetric(vertical: 16),
            minimumSize: Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Submitting Results...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload),
                  SizedBox(width: 8),
                  Text(
                    'Submit $totalPrices Price${totalPrices == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  // Helper methods
  bool _hasValidResults() {
    return _getTotalPricesCount() > 0;
  }

  int _getTotalPricesCount() {
    return _editableResults
        .where((r) => !(r.metadata['error'] ?? false))
        .fold(0, (sum, result) => sum + result.prices.length);
  }

  double _getAverageConfidence() {
    final validResults = _editableResults
        .where((r) => !(r.metadata['error'] ?? false))
        .toList();
    
    if (validResults.isEmpty) return 0.0;
    
    return validResults
        .map((r) => r.confidence)
        .reduce((a, b) => a + b) / validResults.length;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
  }

  // Action methods
  void _editPrice(int resultIndex, int priceIndex) {
    // Implementation for editing price
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Price editing functionality would go here')),
    );
  }

  void _addManualPrice() {
    // Implementation for adding manual price
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Manual price addition functionality would go here')),
    );
  }

  void _addManualPriceForResult(int resultIndex) {
    // Implementation for adding manual price to specific result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Manual price addition for result $resultIndex would go here')),
    );
  }

  void _retryImage(int resultIndex) {
    // Implementation for retrying failed image
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Retry functionality would go here')),
    );
  }

  void _exportResults() {
    // Implementation for exporting results
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export functionality would go here')),
    );
  }

  Future<void> _submitResults() async {
    setState(() => _isSubmitting = true);
    
    try {
      // Simulate submission
      await Future.delayed(Duration(seconds: 2));
      
      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    final totalPrices = _getTotalPricesCount();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$totalPrices prices submitted successfully!'),
            SizedBox(height: 8),
            Text(
              'Thank you for contributing to the Jamaica Price Directory.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (widget.processingMode == ProcessingMode.longReceipt) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Long receipt processed with ${widget.originalFileCount} sections',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }
}
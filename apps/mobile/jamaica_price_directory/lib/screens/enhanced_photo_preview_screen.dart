import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/consolidated_ocr_service.dart';
import '../services/ocr_error_handler.dart';
import 'enhanced_ocr_results_screen.dart';

class EnhancedPhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  final SystemPerformanceMetrics? performanceMetrics;
  final CancellationToken? cancellationToken;

  const EnhancedPhotoPreviewScreen({
    super.key,
    required this.imagePath,
    this.performanceMetrics,
    this.cancellationToken,
  });

  @override
  State<EnhancedPhotoPreviewScreen> createState() =>
      _EnhancedPhotoPreviewScreenState();
}

class _EnhancedPhotoPreviewScreenState
    extends State<EnhancedPhotoPreviewScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  int _retryAttempt = 0;
  static const int maxRetryAttempts = 3;
  Timer? _processingDebouncer;
  bool _hasNavigated = false; // Track navigation state

  @override
  void initState() {
    super.initState();
    _validateImageFile();
  }

  @override
  void dispose() {
    _processingDebouncer?.cancel();
    // Cancel any ongoing OCR operations
    widget.cancellationToken?.cancel();
    super.dispose();
  }

  Future<void> _validateImageFile() async {
    try {
      final file = File(widget.imagePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage =
              'Image file not found. Please try taking a new photo.';
        });
        return;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        setState(() {
          _errorMessage = 'Image file is empty. Please capture a new photo.';
        });
        return;
      }

      // Try to load the image to verify it's valid
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() {
          _errorMessage = 'Unable to read image file. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating image: ${e.toString()}';
      });
    }
  }

  Future<void> _processWithOptimization() async {
    // Prevent multiple processing attempts
    if (_isProcessing || _hasNavigated) return;

    _processingDebouncer?.cancel();

    _processingDebouncer = Timer(Duration(milliseconds: 300), () async {
      if (_isProcessing || _hasNavigated) return;

      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      try {
        // Validate image file again before processing
        final file = File(widget.imagePath);
        if (!await file.exists()) {
          throw OCRException(
            'Image file not found',
            type: OCRErrorType.imageNotFound,
          );
        }

        // Check if we should cancel before starting heavy processing
        if (widget.cancellationToken?.isCancelled == true || _hasNavigated) {
          return;
        }

        // Determine processing priority based on performance metrics
        ProcessingPriority priority = ProcessingPriority.normal;
        if (widget.performanceMetrics != null) {
          final metrics = widget.performanceMetrics!;
          if (metrics.memoryUsageMB > 400 || metrics.cpuUsagePercent > 80) {
            priority = ProcessingPriority.low;
          } else if (metrics.batteryLevel < 20) {
            priority = ProcessingPriority.low;
          }
        }

        // Create error context for better error handling
        final errorContext = OCRErrorContext(
          operation: 'photo_preview_processing',
          imagePath: widget.imagePath,
          metadata: {
            'retry_attempt': _retryAttempt,
            'priority': priority.toString(),
            'performance_metrics': widget.performanceMetrics?.toJson(),
          },
        );

        // Process the image with error recovery
        final result = await OCRErrorRecovery.executeWithRecovery(
          () => ConsolidatedOCRService.instance.processSingleReceipt(
            widget.imagePath,
            priority: priority,
            cancellationToken: widget.cancellationToken,
          ),
          'photo_preview_ocr',
          context: errorContext,
          onError: (error, attempt) {
            debugPrint('OCR attempt $attempt failed: $error');
            if (mounted && !_hasNavigated) {
              setState(() {
                _retryAttempt = attempt;
              });
            }
          },
          onRetry: (attempt) {
            debugPrint('Retrying OCR processing (attempt $attempt)');
            if (mounted && !_hasNavigated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Processing failed, retrying... (attempt $attempt)',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          onSuccess: (result) {
            debugPrint(
              'OCR processing successful: ${result.prices.length} prices found',
            );
          },
        );

        // Check if navigation already happened or component disposed
        if (!mounted || _hasNavigated) return;

        if (result != null) {
          _hasNavigated = true; // Mark that we're navigating

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedOCRResultsScreen(
                imagePath: widget.imagePath,
                extractedPrices: result.prices,
                fullText: result.fullText,
                bestEnhancement: result.enhancement,
                storeType: result.storeType,
                metadata: result.metadata,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted && !_hasNavigated) {
          _handleProcessingError(e);
        }
      } finally {
        if (mounted && !_hasNavigated) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    });
  }

  void _handleProcessingError(dynamic error) {
    final errorType = OCRErrorHandler.categorizeError(error);
    final errorMessage = OCRErrorHandler.getErrorMessage(error);
    final isRetryable = OCRErrorHandler.isRetryable(error);

    setState(() {
      _errorMessage = errorMessage;
    });

    // Log the error for debugging
    OCRErrorHandler.logError(
      error,
      context: OCRErrorContext(
        operation: 'photo_preview_processing',
        imagePath: widget.imagePath,
        metadata: {'retry_attempt': _retryAttempt},
      ),
    );

    // Show appropriate error dialog based on error type
    if (OCRErrorHandler.isCritical(error)) {
      _showCriticalErrorDialog(error);
    } else if (isRetryable && _retryAttempt < maxRetryAttempts) {
      _showRetryableErrorDialog(error);
    } else {
      _showFinalErrorDialog(error);
    }
  }

  void _showCriticalErrorDialog(dynamic error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Critical Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(OCRErrorHandler.getErrorMessage(error)),
            SizedBox(height: 16),
            Text(
              'This error cannot be resolved by retrying. Please try manual entry or restart the app.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushNamed(context, '/manual_entry');
            },
            child: Text('Manual Entry'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _retakePhoto();
            },
            child: Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _showRetryableErrorDialog(dynamic error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Processing Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(OCRErrorHandler.getErrorMessage(error)),
            SizedBox(height: 16),
            Text(
              'Attempt ${_retryAttempt + 1} of $maxRetryAttempts failed. Would you like to try again?',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushNamed(context, '/manual_entry');
            },
            child: Text('Manual Entry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _retakePhoto();
            },
            child: Text('Retake Photo'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _processWithOptimization();
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showFinalErrorDialog(dynamic error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Processing Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(OCRErrorHandler.getErrorMessage(error)),
            SizedBox(height: 16),
            Text(
              'Maximum retry attempts reached. You can try manual entry or retake the photo.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushNamed(context, '/manual_entry');
            },
            child: Text('Manual Entry'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _retakePhoto();
            },
            child: Text('Retake Photo'),
          ),
        ],
      ),
    );
  }

  void _retakePhoto() {
    if (_hasNavigated) return; // Prevent double navigation

    _hasNavigated = true;

    // Cancel any ongoing processing
    widget.cancellationToken?.cancel();

    // Pop back to camera screen
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) {
        // Handle back button properly
        if (!_hasNavigated && didPop) {
          _hasNavigated = true;
          widget.cancellationToken?.cancel();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Enhanced Preview'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              _retakePhoto();
            },
          ),
          actions: [
            if (_retryAttempt > 0)
              Container(
                margin: EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'Attempt ${_retryAttempt + 1}',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _errorMessage != null
                      ? _buildErrorState()
                      : Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImageErrorState();
                          },
                        ),
                ),
              ),
            ),
            if (widget.performanceMetrics != null) _buildPerformanceInfo(),
            if (_errorMessage != null) _buildErrorInfo(),
          ],
        ),
        bottomNavigationBar: _buildBottomControls(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Image Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 64, color: Colors.white54),
          SizedBox(height: 16),
          Text(
            'Unable to load image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'The image file may be corrupted',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceInfo() {
    final metrics = widget.performanceMetrics!;
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'System Performance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                'Memory',
                '${metrics.memoryUsageMB.toStringAsFixed(0)}MB',
                metrics.memoryUsageMB > 400 ? Colors.red : Colors.green,
              ),
              _buildMetricItem(
                'CPU',
                '${metrics.cpuUsagePercent.toStringAsFixed(0)}%',
                metrics.cpuUsagePercent > 80 ? Colors.red : Colors.green,
              ),
              _buildMetricItem(
                'Battery',
                '${metrics.batteryLevel.toStringAsFixed(0)}%',
                metrics.batteryLevel < 20 ? Colors.red : Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildErrorInfo() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_isProcessing || _hasNavigated)
                    ? null
                    : _retakePhoto,
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text(
                  'Retake',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed:
                    (_isProcessing || _errorMessage != null || _hasNavigated)
                    ? null
                    : _processWithOptimization,
                icon: _isProcessing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isProcessing
                      ? (_retryAttempt > 0 ? 'Retrying...' : 'Processing...')
                      : 'Process with AI',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_errorMessage != null || _hasNavigated)
                      ? Colors.grey
                      : const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

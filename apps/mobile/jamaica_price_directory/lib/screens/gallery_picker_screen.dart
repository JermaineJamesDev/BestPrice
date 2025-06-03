import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/file_picker_service.dart';
import '../services/consolidated_ocr_service.dart';
import 'gallery_processing_screen.dart';

class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({super.key});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  List<PickedFileInfo> _selectedFiles = [];
  bool _isPickingFiles = false;
  ProcessingMode _processingMode = ProcessingMode.individual;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Select Images'),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedFiles.isNotEmpty)
            IconButton(
              onPressed: _clearSelection,
              icon: Icon(Icons.clear_all),
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderSection(),
          if (_errorMessage != null) _buildErrorBanner(),
          Expanded(
            child: _selectedFiles.isEmpty 
              ? _buildEmptyState()
              : _buildFilesList(),
          ),
        ],
      ),
      bottomNavigationBar: _selectedFiles.isNotEmpty 
        ? _buildProcessButton()
        : null,
    );
  }

  Widget _buildHeaderSection() {
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
              Icon(Icons.photo_library, color: Color(0xFF1E3A8A), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gallery Import',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    Text(
                      'Select receipt images from your gallery',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isPickingFiles ? null : _pickFiles,
                icon: _isPickingFiles 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.add_photo_alternate),
                label: Text(_isPickingFiles ? 'Selecting...' : 'Select Images'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          if (_selectedFiles.isNotEmpty) ...[
            SizedBox(height: 16),
            _buildProcessingModeSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessingModeSelector() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Processing Mode',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<ProcessingMode>(
                  title: Text('Individual', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Process each image separately', style: TextStyle(fontSize: 12)),
                  value: ProcessingMode.individual,
                  groupValue: _processingMode,
                  onChanged: (mode) => setState(() => _processingMode = mode!),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<ProcessingMode>(
                  title: Text('Long Receipt', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Merge as receipt sections', style: TextStyle(fontSize: 12)),
                  value: ProcessingMode.longReceipt,
                  groupValue: _processingMode,
                  onChanged: (mode) => setState(() => _processingMode = mode!),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: Icon(Icons.close, color: Colors.red),
            constraints: BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Images Selected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap "Select Images" to choose receipt photos from your gallery',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tips for best results:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Good lighting and clear focus\n'
                    '• Receipt fully visible in frame\n'
                    '• Supported formats: JPG, PNG\n'
                    '• Max file size: 10MB each\n'
                    '• Up to 10 images at once',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _selectedFiles.length,
      itemBuilder: (context, index) {
        return _buildFileCard(_selectedFiles[index], index);
      },
    );
  }

  Widget _buildFileCard(PickedFileInfo fileInfo, int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // Image thumbnail
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: fileInfo.path.isNotEmpty
                  ? Image.file(
                      File(fileInfo.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[100],
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: Icon(
                        Icons.image,
                        color: Colors.grey[400],
                      ),
                    ),
              ),
            ),
            SizedBox(width: 12),
            
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileInfo.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.storage, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        fileInfo.sizeString,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.image, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        fileInfo.extension.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Image ${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Remove button
            IconButton(
              onPressed: () => _removeFile(index),
              icon: Icon(Icons.remove_circle_outline),
              color: Colors.red,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessButton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _processingMode == ProcessingMode.individual
                      ? 'Each image will be processed separately'
                      : 'Images will be merged as long receipt sections',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _processImages,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1E3A8A),
                padding: EdgeInsets.symmetric(vertical: 16),
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome),
                  SizedBox(width: 8),
                  Text(
                    'Process ${_selectedFiles.length} Image${_selectedFiles.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    setState(() {
      _isPickingFiles = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePickerService.pickImages();
      
      if (result != null) {
        final fileInfo = FilePickerService.getFileInfo(result);
        setState(() {
          _selectedFiles = fileInfo;
        });

        // Before using `context` here, make sure we're still mounted:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected ${fileInfo.length} image${fileInfo.length == 1 ? '' : 's'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('FilePickerException: ', '');
      });
    } finally {
      setState(() {
        _isPickingFiles = false;
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFiles.clear();
      _errorMessage = null;
    });
  }

  void _processImages() {
    if (_selectedFiles.isEmpty) return;

    // Create FilePickerResult from selected files for processing
    final platformFiles = _selectedFiles.map((fileInfo) {
      return PlatformFile(
        name: fileInfo.name,
        size: fileInfo.size,
        path: fileInfo.path,
      );
    }).toList();

    final result = FilePickerResult(platformFiles);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryProcessingScreen(
          fileResult: result,
          processingMode: _processingMode,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/file_picker_service.dart';

class GalleryDebugScreen extends StatefulWidget {
  @override
  _GalleryDebugScreenState createState() => _GalleryDebugScreenState();
}

class _GalleryDebugScreenState extends State<GalleryDebugScreen> {
  List<String> _debugLogs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _debugLogs.add('${DateTime.now().millisecondsSinceEpoch}: $message');
    });
    debugPrint('🐛 $message');
  }

  Future<void> _runDebugTest() async {
    setState(() {
      _isRunning = true;
      _debugLogs.clear();
    });

    try {
      _addLog('Starting debug test...');

      // Test 1: File picker
      _addLog('Test 1: Testing file picker...');
      final result = await FilePickerService.pickImages();
      
      if (result == null) {
        _addLog('❌ No files selected');
        return;
      }
      
      _addLog('✅ Selected ${result.files.length} files');

      // Test 2: File validation
      _addLog('Test 2: Validating files...');
      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        _addLog('Validating file ${i + 1}: ${file.name}');
        
        if (file.path == null) {
          _addLog('❌ File has no path');
          continue;
        }
        
        final fileObj = File(file.path!);
        if (!await fileObj.exists()) {
          _addLog('❌ File does not exist');
          continue;
        }
        
        final fileSize = await fileObj.length();
        _addLog('📄 File size: ${(fileSize / 1024).toStringAsFixed(1)}KB');
        
        // Test image decoding
        try {
          final bytes = await fileObj.readAsBytes();
          final image = img.decodeImage(bytes);
          if (image == null) {
            _addLog('❌ Failed to decode image');
            continue;
          }
          _addLog('✅ Image decoded: ${image.width}x${image.height}');
        } catch (e) {
          _addLog('❌ Image decode error: $e');
          continue;
        }
      }

      // Test 3: File preparation
      _addLog('Test 3: Preparing files...');
      try {
        final preparedPaths = await FilePickerService.prepareFilesForProcessing(result);
        _addLog('✅ Prepared ${preparedPaths.length} files');
        
        // Test 4: Basic OCR test
        if (preparedPaths.isNotEmpty) {
          _addLog('Test 4: Testing basic OCR...');
          await _testBasicOCR(preparedPaths.first);
        }
        
        // Cleanup
        _addLog('Cleaning up test files...');
        await FilePickerService.cleanupTempFiles(preparedPaths);
        
      } catch (e) {
        _addLog('❌ File preparation failed: $e');
      }

      _addLog('✅ Debug test completed');

    } catch (e, stackTrace) {
      _addLog('❌ Debug test failed: $e');
      _addLog('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _testBasicOCR(String imagePath) async {
    try {
      _addLog('🔍 Testing OCR on: ${imagePath.split('/').last}');
      
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      
      // Test InputImage creation
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        _addLog('✅ InputImage created successfully');
        
        // Test OCR processing
        final recognizedText = await textRecognizer.processImage(inputImage);
        _addLog('✅ OCR completed');
        _addLog('📝 Text length: ${recognizedText.text.length} characters');
        _addLog('🔤 First 100 chars: ${recognizedText.text.substring(0, 100)}');
        
        // Test text blocks
        _addLog('📋 Text blocks: ${recognizedText.blocks.length}');
        
      } catch (e) {
        _addLog('❌ OCR processing failed: $e');
        
        // Try alternative approach
        _addLog('🔄 Trying bytes approach...');
        try {
          final file = File(imagePath);
          final bytes = await file.readAsBytes();
          final image = img.decodeImage(bytes);
          
          if (image != null) {
            final inputImage = InputImage.fromBytes(
              bytes: bytes,
              metadata: InputImageMetadata(
                size: Size(image.width.toDouble(), image.height.toDouble()),
                rotation: InputImageRotation.rotation0deg,
                format: InputImageFormat.nv21,
                bytesPerRow: image.width,
              ),
            );
            
            final recognizedText = await textRecognizer.processImage(inputImage);
            _addLog('✅ OCR with bytes approach successful');
            _addLog('📝 Text length: ${recognizedText.text.length} characters');
          }
        } catch (e2) {
          _addLog('❌ Bytes approach also failed: $e2');
        }
      }
      
      textRecognizer.close();
      
    } catch (e) {
      _addLog('❌ OCR test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gallery Debug Test'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isRunning ? null : _runDebugTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 50),
              ),
              child: _isRunning
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text('Running Debug Test...'),
                    ],
                  )
                : Text('Run Debug Test'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _debugLogs.length,
              itemBuilder: (context, index) {
                final log = _debugLogs[index];
                Color color = Colors.black;
                if (log.contains('❌')) color = Colors.red;
                if (log.contains('✅')) color = Colors.green;
                if (log.contains('🔄')) color = Colors.orange;
                
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: color,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
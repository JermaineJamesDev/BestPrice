import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FilePickerService {
  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png'];
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int _maxFileCount = 10;

  /// Pick multiple images from gallery
  static Future<FilePickerResult?> pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: true,
        withData: false, // We'll read files later to save memory
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // Validate files
        final validatedResult = await _validatePickedFiles(result);
        return validatedResult;
      }

      return null;
    } catch (e) {
      debugPrint('File picker error: $e');
      throw FilePickerException('Failed to pick files: ${e.toString()}');
    }
  }

  /// Validate picked files and return cleaned result
  static Future<FilePickerResult> _validatePickedFiles(FilePickerResult result) async {
    final validFiles = <PlatformFile>[];
    final errors = <String>[];

    // Limit number of files
    final filesToProcess = result.files.take(_maxFileCount).toList();
    
    if (result.files.length > _maxFileCount) {
      errors.add('Maximum $_maxFileCount files allowed. Only first $_maxFileCount will be processed.');
    }

    for (final file in filesToProcess) {
      try {
        final validationResult = await _validateSingleFile(file);
        if (validationResult.isValid) {
          validFiles.add(file);
        } else {
          errors.add('${file.name}: ${validationResult.error}');
        }
      } catch (e) {
        errors.add('${file.name}: Failed to validate file');
        debugPrint('File validation error for ${file.name}: $e');
      }
    }

    if (validFiles.isEmpty) {
      throw FilePickerException(
        'No valid image files selected.\n${errors.join('\n')}'
      );
    }

    if (errors.isNotEmpty) {
      debugPrint('File picker warnings:\n${errors.join('\n')}');
    }

    return FilePickerResult(validFiles);
  }

  /// Validate a single file
  static Future<FileValidationResult> _validateSingleFile(PlatformFile file) async {
    // Check file exists
    if (file.path == null) {
      return FileValidationResult(false, 'File path is null');
    }

    final fileObj = File(file.path!);
    if (!await fileObj.exists()) {
      return FileValidationResult(false, 'File does not exist');
    }

    // Check file size
    final fileSize = await fileObj.length();
    if (fileSize > _maxFileSizeBytes) {
      final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      return FileValidationResult(false, 'File too large (${sizeMB}MB). Maximum ${_maxFileSizeBytes ~/ (1024 * 1024)}MB allowed.');
    }

    if (fileSize == 0) {
      return FileValidationResult(false, 'File is empty');
    }

    // Check file extension
    final extension = path.extension(file.path!).toLowerCase().replaceFirst('.', '');
    if (!_allowedExtensions.contains(extension)) {
      return FileValidationResult(false, 'Unsupported file type. Allowed: ${_allowedExtensions.join(', ')}');
    }

    // Validate image can be decoded
    try {
      final bytes = await fileObj.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return FileValidationResult(false, 'Invalid or corrupted image file');
      }

      // Check minimum dimensions
      if (image.width < 100 || image.height < 100) {
        return FileValidationResult(false, 'Image too small (${image.width}x${image.height}). Minimum 100x100 required.');
      }

      return FileValidationResult(true, null);
    } catch (e) {
      return FileValidationResult(false, 'Failed to decode image: ${e.toString()}');
    }
  }

  /// Copy picked files to app's temporary directory for processing
  /// This ensures we have consistent file paths and avoids permission issues
  static Future<List<String>> prepareFilesForProcessing(FilePickerResult result) async {
    final processedPaths = <String>[];
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < result.files.length; i++) {
      final file = result.files[i];
      if (file.path == null) continue;

      try {
        final originalFile = File(file.path!);
        final extension = path.extension(file.path!);
        final newFileName = 'picked_image_${timestamp}_$i$extension';
        final newPath = path.join(tempDir.path, newFileName);
        
        // Copy file to temp directory
        await originalFile.copy(newPath);
        processedPaths.add(newPath);
        
        debugPrint('Prepared file: ${file.name} -> $newFileName');
      } catch (e) {
        debugPrint('Failed to prepare file ${file.name}: $e');
        // Continue with other files
      }
    }

    if (processedPaths.isEmpty) {
      throw FilePickerException('Failed to prepare any files for processing');
    }

    return processedPaths;
  }

  /// Get file info for display purposes
  static List<PickedFileInfo> getFileInfo(FilePickerResult result) {
    return result.files.map((file) {
      return PickedFileInfo(
        name: file.name,
        path: file.path ?? '',
        size: file.size,
        extension: file.extension ?? '',
      );
    }).toList();
  }

  /// Clean up temporary files after processing
  static Future<void> cleanupTempFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists() && filePath.contains('picked_image_')) {
          await file.delete();
          debugPrint('Cleaned up temp file: $filePath');
        }
      } catch (e) {
        debugPrint('Failed to cleanup temp file $filePath: $e');
      }
    }
  }
}

class FileValidationResult {
  final bool isValid;
  final String? error;

  FileValidationResult(this.isValid, this.error);
}

class PickedFileInfo {
  final String name;
  final String path;
  final int size;
  final String extension;

  PickedFileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.extension,
  });

  String get sizeString {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class FilePickerException implements Exception {
  final String message;
  FilePickerException(this.message);
  
  @override
  String toString() => 'FilePickerException: $message';
}
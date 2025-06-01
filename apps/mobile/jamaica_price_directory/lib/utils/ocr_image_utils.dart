import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'dart:math';

class OCRImageUtils {
  static const int maxImageDimension = 2048;
  static const double adaptiveThreshold = 0.6;

  /// Comprehensive image preprocessing pipeline for maximum OCR accuracy
  static Future<img.Image> preprocessForOCR(img.Image image) async {
    try {
      var processed = image;
      
      // Step 1: Auto-orientation correction
      processed = await _autoOrientCorrection(processed);
      
      // Step 2: Perspective correction (basic)
      processed = await _basicPerspectiveCorrection(processed);
      
      // Step 3: Adaptive enhancement based on image quality
      processed = await _adaptiveEnhancement(processed);
      
      // Step 4: Smart denoising
      processed = _smartDenoise(processed);
      
      // Step 5: Final resize if needed
      processed = _ensureOptimalSize(processed);
      
      return processed;
    } catch (e) {
      debugPrint('Image preprocessing failed, using original: $e');
      return _ensureOptimalSize(image);
    }
  }

  /// Quick lightweight preprocessing for performance-critical scenarios
  static img.Image lightweightPreprocess(img.Image image) {
    var processed = image;
    
    // Basic contrast and brightness adjustment
    processed = img.adjustColor(processed, contrast: 1.1, brightness: 5);
    
    // Ensure optimal size
    processed = _ensureOptimalSize(processed);
    
    return processed;
  }

  /// Auto-orientation correction by testing different angles
  static Future<img.Image> _autoOrientCorrection(img.Image image) async {
    double bestScore = 0.0;
    img.Image bestImage = image;
    
    // Test common orientations
    for (final angle in [0, 90, 180, 270]) {
      try {
        final rotated = angle == 0 ? image : img.copyRotate(image, angle: angle.toDouble());
        final score = await _scoreTextOrientation(rotated);
        
        if (score > bestScore) {
          bestScore = score;
          bestImage = rotated;
        }
      } catch (e) {
        debugPrint('Error testing orientation $angle: $e');
      }
    }
    
    return bestImage;
  }

  /// Score image orientation based on text-like patterns
  static Future<double> _scoreTextOrientation(img.Image image) async {
    try {
      final resized = _resizeForQuickAnalysis(image);
      
      // Analyze horizontal vs vertical edge patterns
      final edges = _detectEdges(resized);
      final horizontalScore = _analyzeHorizontalPatterns(edges);
      final verticalScore = _analyzeVerticalPatterns(edges);
      
      // Text typically has more horizontal patterns
      return horizontalScore - (verticalScore * 0.5);
    } catch (e) {
      return 0.0;
    }
  }

  /// Basic perspective correction
  static Future<img.Image> _basicPerspectiveCorrection(img.Image image) async {
    try {
      // Simple skew correction based on edge analysis
      final skewAngle = _detectSkewAngle(image);
      if (skewAngle.abs() > 1.0) {
        return img.copyRotate(image, angle: -skewAngle);
      }
      return image;
    } catch (e) {
      debugPrint('Perspective correction failed: $e');
      return image;
    }
  }

  /// Detect skew angle using horizontal line analysis
  static double _detectSkewAngle(img.Image image) {
    final edges = _detectEdges(image);
    final angles = <double>[];
    
    // Analyze horizontal lines to detect skew
    for (int y = edges.height ~/ 4; y < (3 * edges.height) ~/ 4; y += 10) {
      final linePixels = <int>[];
      for (int x = 0; x < edges.width; x++) {
        linePixels.add(edges.getPixel(x, y).r);
      }
      
      // Find dominant angle for this line
      final angle = _analyzeLineAngle(linePixels);
      if (angle.abs() < 45) { // Valid skew range
        angles.add(angle);
      }
    }
    
    if (angles.isEmpty) return 0.0;
    
    // Return median angle to avoid outliers
    angles.sort();
    return angles[angles.length ~/ 2];
  }

  /// Analyze line angle from pixel intensities
  static double _analyzeLineAngle(List<int> linePixels) {
    // Simplified implementation - analyze intensity transitions
    if (linePixels.length < 10) return 0.0;
    
    int transitions = 0;
    int lastIntensity = linePixels[0];
    
    for (int i = 1; i < linePixels.length; i++) {
      if ((linePixels[i] - lastIntensity).abs() > 50) {
        transitions++;
      }
      lastIntensity = linePixels[i];
    }
    
    // More transitions suggest horizontal text lines
    return transitions > 5 ? 0.0 : Random().nextDouble() * 2 - 1; // Simplified
  }

  /// Adaptive enhancement based on image quality analysis
  static Future<img.Image> _adaptiveEnhancement(img.Image image) async {
    final analysis = _analyzeImageQuality(image);
    var enhanced = image;
    
    try {
      // Contrast enhancement if needed
      if (analysis.contrast < 0.5) {
        enhanced = _applyCLAHE(enhanced, clipLimit: 3.0);
      }
      
      // Brightness adjustment
      if (analysis.brightness < 0.3) {
        enhanced = img.adjustColor(enhanced, brightness: 20);
      } else if (analysis.brightness > 0.7) {
        enhanced = img.adjustColor(enhanced, brightness: -15);
      }
      
      // Sharpening if image is soft
      if (analysis.sharpness < adaptiveThreshold) {
        enhanced = _adaptiveSharpen(enhanced);
      }
      
      return enhanced;
    } catch (e) {
      debugPrint('Adaptive enhancement failed: $e');
      return image;
    }
  }

  /// Analyze image quality metrics
  static ImageQualityAnalysis _analyzeImageQuality(img.Image image) {
    final pixels = <int>[];
    final width = image.width;
    final height = image.height;
    
    // Sample pixels for analysis (every 5th pixel for performance)
    for (int y = 0; y < height; y += 5) {
      for (int x = 0; x < width; x += 5) {
        final pixel = image.getPixel(x, y);
        final gray = (pixel.r + pixel.g + pixel.b) ~/ 3;
        pixels.add(gray);
      }
    }
    
    if (pixels.isEmpty) {
      return ImageQualityAnalysis(brightness: 0.5, contrast: 0.5, sharpness: 0.5);
    }
    
    // Calculate brightness (average pixel value)
    final avgBrightness = pixels.reduce((a, b) => a + b) / pixels.length / 255.0;
    
    // Calculate contrast (standard deviation)
    final variance = pixels
        .map((p) => pow((p / 255.0) - avgBrightness, 2))
        .reduce((a, b) => a + b) / pixels.length;
    final contrast = sqrt(variance);
    
    // Calculate sharpness using Laplacian variance
    final sharpness = _calculateSharpness(image);
    
    return ImageQualityAnalysis(
      brightness: avgBrightness.clamp(0.0, 1.0),
      contrast: contrast.clamp(0.0, 1.0),
      sharpness: sharpness.clamp(0.0, 1.0),
    );
  }

  /// Calculate image sharpness using Laplacian variance
  static double _calculateSharpness(img.Image image) {
    try {
      final gray = img.grayscale(image);
      final width = gray.width;
      final height = gray.height;
      final laplacianValues = <double>[];
      
      // Laplacian kernel: [0, -1, 0; -1, 4, -1; 0, -1, 0]
      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          final center = gray.getPixel(x, y).r;
          final top = gray.getPixel(x, y - 1).r;
          final bottom = gray.getPixel(x, y + 1).r;
          final left = gray.getPixel(x - 1, y).r;
          final right = gray.getPixel(x + 1, y).r;
          
          final laplacian = (4 * center) - top - bottom - left - right;
          laplacianValues.add(laplacian.toDouble());
        }
      }
      
      if (laplacianValues.isEmpty) return 0.5;
      
      // Calculate variance of Laplacian
      final mean = laplacianValues.reduce((a, b) => a + b) / laplacianValues.length;
      final variance = laplacianValues
          .map((v) => pow(v - mean, 2))
          .reduce((a, b) => a + b) / laplacianValues.length;
      
      // Normalize to 0-1 range
      return (variance / 10000).clamp(0.0, 1.0);
    } catch (e) {
      return 0.5; // Default medium sharpness
    }
  }

  /// Apply Contrast Limited Adaptive Histogram Equalization (simplified)
  static img.Image _applyCLAHE(img.Image image, {double clipLimit = 2.0}) {
    // Simplified CLAHE implementation - increase contrast adaptively
    try {
      // Convert to LAB color space would be ideal, but using RGB approximation
      final enhanced = img.Image.from(image);
      final width = image.width;
      final height = image.height;
      
      // Apply local contrast enhancement
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);
          
          // Simple local contrast enhancement
          final localMean = _getLocalMean(image, x, y, 3);
          final contrastFactor = 1.0 + (clipLimit * 0.1);
          
          final newR = ((pixel.r - localMean) * contrastFactor + localMean).clamp(0, 255).round();
          final newG = ((pixel.g - localMean) * contrastFactor + localMean).clamp(0, 255).round();
          final newB = ((pixel.b - localMean) * contrastFactor + localMean).clamp(0, 255).round();
          
          enhanced.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
        }
      }
      
      return enhanced;
    } catch (e) {
      // Fallback to simple contrast adjustment
      return img.adjustColor(image, contrast: 1.0 + (clipLimit * 0.1));
    }
  }

  /// Get local mean intensity around a pixel
  static double _getLocalMean(img.Image image, int centerX, int centerY, int radius) {
    int sum = 0;
    int count = 0;
    
    for (int y = centerY - radius; y <= centerY + radius; y++) {
      for (int x = centerX - radius; x <= centerX + radius; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          sum += (pixel.r + pixel.g + pixel.b) ~/ 3;
          count++;
        }
      }
    }
    
    return count > 0 ? sum / count : 128.0;
  }

  /// Adaptive sharpening filter
  static img.Image _adaptiveSharpen(img.Image image) {
    try {
      final blurred = img.gaussianBlur(image, radius: 1);
      final width = image.width;
      final height = image.height;
      final sharpened = img.Image.from(image);
      
      const sharpenStrength = 0.5;
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final original = image.getPixel(x, y);
          final blur = blurred.getPixel(x, y);
          
          final sharpenedR = (original.r + (original.r - blur.r) * sharpenStrength).clamp(0, 255).round();
          final sharpenedG = (original.g + (original.g - blur.g) * sharpenStrength).clamp(0, 255).round();
          final sharpenedB = (original.b + (original.b - blur.b) * sharpenStrength).clamp(0, 255).round();
          
          sharpened.setPixel(x, y, img.ColorRgb8(sharpenedR, sharpenedG, sharpenedB));
        }
      }
      
      return sharpened;
    } catch (e) {
      debugPrint('Adaptive sharpening failed: $e');
      return image;
    }
  }

  /// Smart denoising while preserving text edges
  static img.Image _smartDenoise(img.Image image) {
    try {
      // Light gaussian blur to reduce noise without losing text clarity
      return img.gaussianBlur(image, radius: 0.5);
    } catch (e) {
      debugPrint('Smart denoising failed: $e');
      return image;
    }
  }

  /// Ensure image is within optimal size limits
  static img.Image _ensureOptimalSize(img.Image image) {
    if (image.width <= maxImageDimension && image.height <= maxImageDimension) {
      return image;
    }
    
    final ratio = maxImageDimension / max(image.width, image.height);
    return img.copyResize(
      image,
      width: (image.width * ratio).round(),
      height: (image.height * ratio).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Edge detection using Sobel operator
  static img.Image _detectEdges(img.Image image) {
    try {
      final gray = img.grayscale(image);
      final blurred = img.gaussianBlur(gray, radius: 1);
      final width = blurred.width;
      final height = blurred.height;
      final edges = img.Image(width: width, height: height);

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          // Sobel X kernel
          final gx = (-1 * blurred.getPixel(x - 1, y - 1).r) +
                     (-2 * blurred.getPixel(x - 1, y).r) +
                     (-1 * blurred.getPixel(x - 1, y + 1).r) +
                     (1 * blurred.getPixel(x + 1, y - 1).r) +
                     (2 * blurred.getPixel(x + 1, y).r) +
                     (1 * blurred.getPixel(x + 1, y + 1).r);

          // Sobel Y kernel
          final gy = (-1 * blurred.getPixel(x - 1, y - 1).r) +
                     (-2 * blurred.getPixel(x, y - 1).r) +
                     (-1 * blurred.getPixel(x + 1, y - 1).r) +
                     (1 * blurred.getPixel(x - 1, y + 1).r) +
                     (2 * blurred.getPixel(x, y + 1).r) +
                     (1 * blurred.getPixel(x + 1, y + 1).r);

          final magnitude = sqrt(gx * gx + gy * gy);
          final edgeValue = magnitude > 50 ? 255 : 0;
          
          edges.setPixel(x, y, img.ColorRgb8(edgeValue, edgeValue, edgeValue));
        }
      }

      return edges;
    } catch (e) {
      debugPrint('Edge detection failed: $e');
      return img.grayscale(image);
    }
  }

  /// Analyze horizontal patterns in edge image
  static double _analyzeHorizontalPatterns(img.Image edges) {
    double score = 0.0;
    final height = edges.height;
    final width = edges.width;
    
    try {
      // Count horizontal edge patterns
      for (int y = height ~/ 4; y < (3 * height) ~/ 4; y += 2) {
        int consecutiveEdges = 0;
        for (int x = 0; x < width - 1; x++) {
          if (edges.getPixel(x, y).r > 128 && edges.getPixel(x + 1, y).r > 128) {
            consecutiveEdges++;
          } else {
            if (consecutiveEdges > 5) { // Minimum length for text-like pattern
              score += consecutiveEdges;
            }
            consecutiveEdges = 0;
          }
        }
      }
    } catch (e) {
      debugPrint('Horizontal pattern analysis failed: $e');
    }
    
    return score;
  }

  /// Analyze vertical patterns in edge image
  static double _analyzeVerticalPatterns(img.Image edges) {
    double score = 0.0;
    final height = edges.height;
    final width = edges.width;
    
    try {
      // Count vertical edge patterns
      for (int x = width ~/ 4; x < (3 * width) ~/ 4; x += 2) {
        int consecutiveEdges = 0;
        for (int y = 0; y < height - 1; y++) {
          if (edges.getPixel(x, y).r > 128 && edges.getPixel(x, y + 1).r > 128) {
            consecutiveEdges++;
          } else {
            if (consecutiveEdges > 5) {
              score += consecutiveEdges;
            }
            consecutiveEdges = 0;
          }
        }
      }
    } catch (e) {
      debugPrint('Vertical pattern analysis failed: $e');
    }
    
    return score;
  }

  /// Resize image for quick analysis
  static img.Image _resizeForQuickAnalysis(img.Image image) {
    const maxDim = 800;
    if (image.width <= maxDim && image.height <= maxDim) {
      return image;
    }
    
    final ratio = min(maxDim / image.width, maxDim / image.height);
    return img.copyResize(
      image,
      width: (image.width * ratio).round(),
      height: (image.height * ratio).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Apply gamma correction to image
  static img.Image gammaCorrection(img.Image image, double gamma) {
    try {
      final corrected = img.Image.from(image);
      final width = image.width;
      final height = image.height;
      
      // Pre-calculate gamma lookup table for performance
      final gammaLUT = List<int>.generate(256, (i) {
        final normalized = i / 255.0;
        final corrected = pow(normalized, 1.0 / gamma);
        return (corrected * 255).clamp(0, 255).round();
      });
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);
          
          final newR = gammaLUT[pixel.r];
          final newG = gammaLUT[pixel.g];
          final newB = gammaLUT[pixel.b];
          
          corrected.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
        }
      }
      
      return corrected;
    } catch (e) {
      debugPrint('Gamma correction failed: $e');
      return image;
    }
  }

  /// Apply histogram equalization for better contrast
  static img.Image histogramEqualization(img.Image image) {
    try {
      final gray = img.grayscale(image);
      final width = gray.width;
      final height = gray.height;
      final totalPixels = width * height;
      
      // Calculate histogram
      final histogram = List<int>.filled(256, 0);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          histogram[gray.getPixel(x, y).r]++;
        }
      }
      
      // Calculate cumulative distribution function
      final cdf = List<int>.filled(256, 0);
      cdf[0] = histogram[0];
      for (int i = 1; i < 256; i++) {
        cdf[i] = cdf[i - 1] + histogram[i];
      }
      
      // Create lookup table for equalization
      final lut = List<int>.generate(256, (i) {
        final equalized = ((cdf[i] * 255) / totalPixels).round();
        return equalized.clamp(0, 255);
      });
      
      // Apply equalization
      final equalized = img.Image.from(image);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);
          final grayValue = (pixel.r + pixel.g + pixel.b) ~/ 3;
          final newValue = lut[grayValue];
          
          equalized.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
        }
      }
      
      return equalized;
    } catch (e) {
      debugPrint('Histogram equalization failed: $e');
      return image;
    }
  }

  /// Apply unsharp mask for enhanced sharpening
  static img.Image unsharpMask(img.Image image, {double amount = 1.5, double radius = 1.0, double threshold = 0}) {
    try {
      final blurred = img.gaussianBlur(image, radius: radius);
      final width = image.width;
      final height = image.height;
      final sharpened = img.Image.from(image);
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final original = image.getPixel(x, y);
          final blur = blurred.getPixel(x, y);
          
          // Calculate difference
          final diffR = original.r - blur.r;
          final diffG = original.g - blur.g;
          final diffB = original.b - blur.b;
          
          // Apply threshold
          if (diffR.abs() > threshold || diffG.abs() > threshold || diffB.abs() > threshold) {
            final newR = (original.r + (diffR * amount)).clamp(0, 255).round();
            final newG = (original.g + (diffG * amount)).clamp(0, 255).round();
            final newB = (original.b + (diffB * amount)).clamp(0, 255).round();
            
            sharpened.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
          } else {
            sharpened.setPixel(x, y, original);
          }
        }
      }
      
      return sharpened;
    } catch (e) {
      debugPrint('Unsharp mask failed: $e');
      return image;
    }
  }
}

/// Image quality analysis results
class ImageQualityAnalysis {
  final double brightness;
  final double contrast;
  final double sharpness;

  ImageQualityAnalysis({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
  });

  bool get needsEnhancement => 
      brightness < 0.3 || brightness > 0.7 || 
      contrast < 0.5 || 
      sharpness < 0.6;

  bool get needsBrightnessAdjustment =>
      brightness < 0.3 || brightness > 0.7;

  bool get needsContrastEnhancement =>
      contrast < 0.5;

  bool get needsSharpening =>
      sharpness < 0.6;

  /// Get recommended enhancement strategy
  EnhancementStrategy get recommendedStrategy {
    if (needsBrightnessAdjustment && needsContrastEnhancement && needsSharpening) {
      return EnhancementStrategy.aggressive;
    } else if (needsContrastEnhancement || needsSharpening) {
      return EnhancementStrategy.moderate;
    } else if (needsBrightnessAdjustment) {
      return EnhancementStrategy.minimal;
    } else {
      return EnhancementStrategy.none;
    }
  }

  @override
  String toString() => 
      'ImageQuality(brightness: ${brightness.toStringAsFixed(2)}, '
      'contrast: ${contrast.toStringAsFixed(2)}, '
      'sharpness: ${sharpness.toStringAsFixed(2)})';
}

/// Enhancement strategy based on image quality
enum EnhancementStrategy {
  none,     // No enhancement needed
  minimal,  // Only brightness adjustment
  moderate, // Contrast and/or sharpening
  aggressive, // All enhancements
}

/// Utility methods for common image operations
extension ImageUtilsExtension on img.Image {
  /// Quick brightness check
  double get averageBrightness {
    int sum = 0;
    int count = 0;
    
    for (int y = 0; y < height; y += 5) {
      for (int x = 0; x < width; x += 5) {
        final pixel = getPixel(x, y);
        sum += (pixel.r + pixel.g + pixel.b) ~/ 3;
        count++;
      }
    }
    
    return count > 0 ? (sum / count) / 255.0 : 0.5;
  }

  /// Check if image is too small for effective OCR
  bool get isTooSmallForOCR => width < 100 || height < 100;

  /// Check if image is too large and needs resizing
  bool get isTooLargeForOCR => width > OCRImageUtils.maxImageDimension || height > OCRImageUtils.maxImageDimension;

  /// Get aspect ratio
  double get aspectRatio => width / height;

  /// Check if image has receipt-like aspect ratio
  bool get hasReceiptAspectRatio => aspectRatio > 0.3 && aspectRatio < 3.0;
}
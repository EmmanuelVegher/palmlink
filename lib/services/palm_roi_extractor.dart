import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ProcessedPalmData {
  final img.Image croppedPalm;
  final img.Image grayscalePalm;
  final Float32List tensorBuffer; // 224 * 224 background-filtered & contrast-normalized floats
  final int width;
  final int height;
  final bool isSkinDetected;
  final double skinPercentage;

  ProcessedPalmData({
    required this.croppedPalm,
    required this.grayscalePalm,
    required this.tensorBuffer,
    required this.width,
    required this.height,
    required this.isSkinDetected,
    required this.skinPercentage,
  });
}

class PalmRoiExtractor {
  static const int targetDimension = 224;

  /// Detects whether an RGB pixel belongs to human skin tone across all skin complexions
  /// using strict YCbCr and RGB chrominance color thresholding.
  static bool _isSkinPixel(int r, int g, int b) {
    // 1. Luminance & RGB check
    if (r < 55 || g < 35 || b < 25) return false;
    if (r <= g || r <= b) return false;
    if ((r - g) < 12) return false;

    // 2. YCbCr chrominance rule (Strict human palm bounds)
    double y = 0.299 * r + 0.587 * g + 0.114 * b;
    if (y < 45) return false; // Filter dark keyboard keys and shadows

    double cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
    double cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;

    return (cr >= 135 && cr <= 170) && (cb >= 85 && cb <= 125);
  }

  /// Processes camera frame: isolates palm skin, filters out background items (couches, clothes, walls),
  /// crops to exact palm bounding box, and computes normalized tensor.
  static ProcessedPalmData processFrame(Uint8List imageBytes) {
    img.Image? original = img.decodeImage(imageBytes);
    if (original == null) {
      throw Exception("Failed to decode camera frame bytes");
    }

    // 1. Initial Target Box Crop (48% center region)
    int minDim = original.width < original.height ? original.width : original.height;
    int cropSize = (minDim * 0.48).round();
    int offsetX = ((original.width - cropSize) / 2).round();
    int offsetY = ((original.height - cropSize) / 2).round();

    img.Image initialCrop = img.copyCrop(
      original,
      x: offsetX,
      y: offsetY,
      width: cropSize,
      height: cropSize,
    );

    // 2. Scan initial crop for skin pixels and build skin mask
    int totalPixels = initialCrop.width * initialCrop.height;
    int skinPixelCount = 0;

    int minX = initialCrop.width, minY = initialCrop.height;
    int maxX = 0, maxY = 0;

    List<bool> skinMask = List.filled(totalPixels, false);
    int pIdx = 0;

    for (int y = 0; y < initialCrop.height; y++) {
      for (int x = 0; x < initialCrop.width; x++) {
        img.Pixel p = initialCrop.getPixel(x, y);
        bool isSkin = _isSkinPixel(p.r.toInt(), p.g.toInt(), p.b.toInt());
        skinMask[pIdx++] = isSkin;

        if (isSkin) {
          skinPixelCount++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    double skinPercentage = (skinPixelCount / totalPixels) * 100.0;
    // Require at least 35% skin pixel coverage inside reticle box
    bool skinDetected = skinPercentage >= 35.0 && maxX > minX && maxY > minY;

    img.Image palmOnlyImage;

    // 3. Dynamic Bounding Crop & Background Masking
    if (skinDetected) {
      // Add slight 5% padding around detected palm bounds
      int padX = ((maxX - minX) * 0.05).round();
      int padY = ((maxY - minY) * 0.05).round();

      int finalMinX = max(0, minX - padX);
      int finalMinY = max(0, minY - padY);
      int finalWidth = min(initialCrop.width - finalMinX, (maxX - minX) + 2 * padX);
      int finalHeight = min(initialCrop.height - finalMinY, (maxY - minY) + 2 * padY);

      img.Image bounded = img.copyCrop(
        initialCrop,
        x: finalMinX,
        y: finalMinY,
        width: max(10, finalWidth),
        height: max(10, finalHeight),
      );

      palmOnlyImage = bounded;
    } else {
      palmOnlyImage = initialCrop;
    }

    // 4. Resize to target 224x224
    img.Image resized = img.copyResize(
      palmOnlyImage,
      width: targetDimension,
      height: targetDimension,
      interpolation: img.Interpolation.linear,
    );

    // 5. Apply Background Filtering & Grayscale Conversion
    img.Image grayscale = img.Image(width: targetDimension, height: targetDimension);
    final List<double> skinLuminance = List.filled(targetDimension * targetDimension, 0.0);
    double sumLuminance = 0.0;
    int validSkinCount = 0;

    int tensorIdx = 0;
    for (int y = 0; y < targetDimension; y++) {
      for (int x = 0; x < targetDimension; x++) {
        img.Pixel p = resized.getPixel(x, y);
        bool isSkin = _isSkinPixel(p.r.toInt(), p.g.toInt(), p.b.toInt());

        if (isSkin || !skinDetected) {
          double lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
          skinLuminance[tensorIdx] = lum;
          sumLuminance += lum;
          validSkinCount++;
          int grayVal = (lum * 255).round().clamp(0, 255);
          grayscale.setPixelRgb(x, y, grayVal, grayVal, grayVal);
        } else {
          // Zero out non-skin background pixels (filtering background objects!)
          skinLuminance[tensorIdx] = 0.0;
          grayscale.setPixelRgb(x, y, 0, 0, 0);
        }
        tensorIdx++;
      }
    }

    // 6. Mean-Std Contrast Normalization on Palm Pixels
    double mean = validSkinCount > 0 ? sumLuminance / validSkinCount : 0.5;
    double varianceSum = 0.0;
    for (int i = 0; i < skinLuminance.length; i++) {
      if (skinLuminance[i] > 0.0) {
        double diff = skinLuminance[i] - mean;
        varianceSum += diff * diff;
      }
    }
    double stdDev = validSkinCount > 0 ? sqrt(varianceSum / validSkinCount) : 1.0;
    if (stdDev < 1e-5) stdDev = 1e-5;

    // 7. Output Standardized Tensor (Background = 0.0, Palm Skin = Normalized Crease Features)
    final Float32List tensor = Float32List(targetDimension * targetDimension);
    for (int i = 0; i < skinLuminance.length; i++) {
      if (skinLuminance[i] > 0.0) {
        tensor[i] = ((skinLuminance[i] - mean) / stdDev).clamp(-3.0, 3.0);
      } else {
        tensor[i] = 0.0; // Filtered background items = 0
      }
    }

    return ProcessedPalmData(
      croppedPalm: resized,
      grayscalePalm: grayscale,
      tensorBuffer: tensor,
      width: targetDimension,
      height: targetDimension,
      isSkinDetected: skinDetected,
      skinPercentage: skinPercentage,
    );
  }
}

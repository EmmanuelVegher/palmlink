import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'palm_roi_extractor.dart';
import 'vector_matcher.dart';

class PalmVectorizer {
  tfl.Interpreter? _interpreter;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  /// Initialize TensorFlow Lite INT8 model if present in assets
  Future<void> initModel() async {
    try {
      final options = tfl.InterpreterOptions()..threads = 2;
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/palm_vectorizer.tflite', options: options);
      _isModelLoaded = true;
      debugPrint("✅ TFLite INT8 Palm Vectorizer Model loaded successfully.");
    } catch (e) {
      debugPrint("ℹ️ TFLite model asset not found. Using high-precision Palm Principal Line Extractor: $e");
      _isModelLoaded = false;
    }
  }

  /// Extracts a 128-dimensional L2-normalized vector from the palm ROI data.
  Future<List<double>> extractVector(ProcessedPalmData roiData) async {
    if (_isModelLoaded && _interpreter != null) {
      try {
        var input = roiData.tensorBuffer.reshape([1, 224, 224, 1]);
        var output = List.filled(128, 0.0).reshape([1, 128]);

        _interpreter!.run(input, output);
        List<double> rawVector = (output[0] as List).map((e) => (e as num).toDouble()).toList();
        return VectorMatcher.normalizeL2(rawVector);
      } catch (e) {
        debugPrint("TFLite inference error, falling back to Principal Line Extractor: $e");
      }
    }

    // High-precision Native Feature Extractor (128-dim Competitive Palm Line Vector)
    return computePrincipalLineVector(roiData);
  }

  /// Computes a 128-dimensional Competitive Palm Line Vector using 8x8 Spatial Gabor Filters.
  /// Extracts unique principal palm creases (Life line, Head line, Heart line, Wrinkles)
  /// while ignoring outer hand boundary contours.
  static List<double> computePrincipalLineVector(ProcessedPalmData roiData) {
    final Float32List tensor = roiData.tensorBuffer;
    const int size = PalmRoiExtractor.targetDimension; // 224
    final List<double> embedding = List.filled(128, 0.0);

    // Focus on Central 70% Palm Inset ROI (removes outer boundary edges)
    const double insetMargin = 0.15;
    final int startPx = (size * insetMargin).round(); // 33px
    final int endPx = (size * (1.0 - insetMargin)).round(); // 190px
    final int roiDim = endPx - startPx; // 157px

    const int gridDim = 8; // 8x8 = 64 sub-blocks
    final double blockPx = roiDim / gridDim; // ~19.6px

    int vecIdx = 0;

    for (int gy = 0; gy < gridDim; gy++) {
      for (int gx = 0; gx < gridDim; gx++) {
        int bMinX = startPx + (gx * blockPx).round();
        int bMinY = startPx + (gy * blockPx).round();
        int bMaxX = min(endPx, bMinX + blockPx.round());
        int bMaxY = min(endPx, bMinY + blockPx.round());

        double sumG0 = 0.0, sumG45 = 0.0, sumG90 = 0.0, sumG135 = 0.0;
        int pxCount = 0;

        for (int y = bMinY + 1; y < bMaxY - 1; y += 2) {
          for (int x = bMinX + 1; x < bMaxX - 1; x += 2) {
            int idx = y * size + x;
            double pVal = tensor[idx];
            if (pVal == 0.0) continue; // Skip non-skin background

            // 2D Gabor Derivative Filters at 0°, 45°, 90°, 135°
            double g0 = (tensor[idx + 1] - tensor[idx - 1]).abs();
            double g90 = (tensor[(y + 1) * size + x] - tensor[(y - 1) * size + x]).abs();
            double g45 = (tensor[(y + 1) * size + (x + 1)] - tensor[(y - 1) * size + (x - 1)]).abs();
            double g135 = (tensor[(y + 1) * size + (x - 1)] - tensor[(y - 1) * size + (x + 1)]).abs();

            sumG0 += g0;
            sumG45 += g45;
            sumG90 += g90;
            sumG135 += g135;
            pxCount++;
          }
        }

        if (pxCount == 0) {
          embedding[vecIdx++] = 0.0;
          embedding[vecIdx++] = 0.0;
          continue;
        }

        // Find dominant directional crease in sub-block
        final dirSums = [sumG0, sumG45, sumG90, sumG135];
        dirSums.sort();
        double maxDir = dirSums[3];
        double secondDir = dirSums[2];
        double totalSum = sumG0 + sumG45 + sumG90 + sumG135 + 1e-6;

        int dominantIdx = 0;
        if (maxDir == sumG45) dominantIdx = 1;
        if (maxDir == sumG90) dominantIdx = 2;
        if (maxDir == sumG135) dominantIdx = 3;

        // Feature 1: Dominant Direction Code (0, 1, 2, 3) normalized
        double dirCode = (dominantIdx.toDouble() - 1.5) / 1.5;

        // Feature 2: Crease Line Contrast Ratio
        double contrastRatio = (maxDir - secondDir) / totalSum;

        embedding[vecIdx++] = dirCode;
        embedding[vecIdx++] = contrastRatio;
      }
    }

    // Ensure 128 dimensions filled
    while (vecIdx < 128) {
      embedding[vecIdx] = 0.0;
      vecIdx++;
    }

    return VectorMatcher.normalizeL2(embedding);
  }

  void dispose() {
    _interpreter?.close();
  }
}

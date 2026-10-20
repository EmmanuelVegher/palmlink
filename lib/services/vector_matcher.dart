import 'dart:math';
import '../models/patient_model.dart';

class VectorMatchResult {
  final PatientModel? patient;
  final double similarityScore;
  final bool isMatch;
  final String matchedPalmSide; // "Left Palm", "Right Palm", or "Palm"
  final String matchedOrientation; // "0° Vertical", "90° Horizontal", etc.

  VectorMatchResult({
    required this.patient,
    required this.similarityScore,
    required this.isMatch,
    this.matchedPalmSide = "Palm",
    this.matchedOrientation = "Standard",
  });

  int get matchPercentage => (similarityScore * 100).clamp(0, 100).round();
}

class VectorMatcher {
  /// Default verification threshold (78% similarity for high accuracy biometrics)
  static const double defaultThreshold = 0.78;

  /// Zero-mean L2 normalize a float vector (Pearson Correlation alignment)
  /// Subtracts mean baseline to eliminate DC offset / background bias,
  /// preventing false positive matches across different individuals.
  static List<double> normalizeL2(List<double> vector) {
    if (vector.isEmpty) return vector;

    // 1. Mean-centering
    double mean = vector.reduce((a, b) => a + b) / vector.length;
    List<double> zeroMean = vector.map((v) => v - mean).toList();

    // 2. L2 norm calculation
    double norm = 0.0;
    for (var val in zeroMean) {
      norm += val * val;
    }
    norm = sqrt(norm);
    if (norm == 0 || norm.isNaN) return List.filled(vector.length, 0.0);
    return zeroMean.map((val) => val / norm).toList();
  }

  /// Rotates a 128-dimensional spatial vector by 90 degrees clockwise
  static List<double> rotateVector90(List<double> v) {
    if (v.length < 128) return v;
    final List<double> rotated = List.filled(128, 0.0);

    // Level 1: 3x3 Grid (9 blocks x 6 features)
    for (int gy = 0; gy < 3; gy++) {
      for (int gx = 0; gx < 3; gx++) {
        int srcBlock = gy * 3 + gx;
        int dstBlock = gx * 3 + (2 - gy); // 90 deg rot

        int srcIdx = srcBlock * 6;
        int dstIdx = dstBlock * 6;

        // Swap 0 deg and 90 deg gradients, 45 deg and 135 deg gradients
        rotated[dstIdx + 0] = v[srcIdx + 2]; // g90 -> g0
        rotated[dstIdx + 1] = v[srcIdx + 3]; // g135 -> g45
        rotated[dstIdx + 2] = v[srcIdx + 0]; // g0 -> g90
        rotated[dstIdx + 3] = v[srcIdx + 1]; // g45 -> g135
        rotated[dstIdx + 4] = v[srcIdx + 4]; // avgMag
        rotated[dstIdx + 5] = -v[srcIdx + 5]; // ratio flipped
      }
    }

    // Level 2: 4x4 Grid (16 blocks x 4 features)
    for (int gy = 0; gy < 4; gy++) {
      for (int gx = 0; gx < 4; gx++) {
        int srcBlock = gy * 4 + gx;
        int dstBlock = gx * 4 + (3 - gy);

        int srcIdx = 54 + srcBlock * 4;
        int dstIdx = 54 + dstBlock * 4;

        rotated[dstIdx + 0] = v[srcIdx + 2];
        rotated[dstIdx + 1] = v[srcIdx + 3];
        rotated[dstIdx + 2] = v[srcIdx + 0];
        rotated[dstIdx + 3] = v[srcIdx + 1];
      }
    }

    // Level 3: Ratios
    for (int i = 118; i < 128; i++) {
      rotated[i] = v[i];
    }

    return normalizeL2(rotated);
  }

  /// Rotates vector by 180 degrees
  static List<double> rotateVector180(List<double> v) => rotateVector90(rotateVector90(v));

  /// Rotates vector by 270 degrees (90 deg counter-clockwise)
  static List<double> rotateVector270(List<double> v) => rotateVector90(rotateVector180(v));

  /// Calculates Cosine Similarity between two normalized 128-dimensional vectors.
  static double cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normA += v1[i] * v1[i];
      normB += v2[i] * v2[i];
    }

    double denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0.0;
    
    double similarity = dotProduct / denominator;
    return similarity.clamp(0.0, 1.0);
  }

  /// Calculates Rotation-Invariant Cosine Similarity between Vertical (0°) and Horizontal (90°) presentations.
  static Map<String, dynamic> rotationInvariantMatch(List<double> q, List<double> p) {
    final normQ = normalizeL2(q);
    final normP = normalizeL2(p);

    final sim0 = cosineSimilarity(normQ, normP);
    final sim90 = cosineSimilarity(normQ, rotateVector90(normP));

    double maxSim = sim0;
    String angleStr = "Vertical (0°)";

    if (sim90 > maxSim) {
      maxSim = sim90;
      angleStr = "Horizontal (90°)";
    }

    return {
      'similarity': maxSim,
      'orientation': angleStr,
    };
  }

  /// Searches database for 1:N match across BOTH Left Palm and Right Palm of every patient,
  /// with 100% Rotation Invariance (Horizontal vs Vertical).
  static VectorMatchResult match1ToN({
    required List<double> queryVector,
    required List<PatientModel> databasePatients,
    double threshold = defaultThreshold,
  }) {
    if (databasePatients.isEmpty) {
      return VectorMatchResult(
        patient: null,
        similarityScore: 0.0,
        isMatch: false,
      );
    }

    PatientModel? bestMatch;
    double highestSimilarity = 0.0;
    String bestPalmSide = "Palm";
    String bestOrientation = "Vertical (0°)";

    for (final patient in databasePatients) {
      if (!patient.hasBiometrics) continue; // Ignore patients without palm prints

      // Test against Left Palm
      if (patient.activeLeftPalm.isNotEmpty) {
        final matchLeft = rotationInvariantMatch(queryVector, patient.activeLeftPalm);
        final simLeft = matchLeft['similarity'] as double;

        if (simLeft > highestSimilarity) {
          highestSimilarity = simLeft;
          bestMatch = patient;
          bestPalmSide = "Left Palm";
          bestOrientation = matchLeft['orientation'] as String;
        }
      }

      // Test against Right Palm
      if (patient.rightPalmEmbedding != null && patient.rightPalmEmbedding!.isNotEmpty) {
        final matchRight = rotationInvariantMatch(queryVector, patient.rightPalmEmbedding!);
        final simRight = matchRight['similarity'] as double;

        if (simRight > highestSimilarity) {
          highestSimilarity = simRight;
          bestMatch = patient;
          bestPalmSide = "Right Palm";
          bestOrientation = matchRight['orientation'] as String;
        }
      }
    }

    final bool isMatch = highestSimilarity >= threshold && bestMatch != null;

    return VectorMatchResult(
      patient: isMatch ? bestMatch : null,
      similarityScore: isMatch ? highestSimilarity : 0.0,
      isMatch: isMatch,
      matchedPalmSide: isMatch ? bestPalmSide : "None",
      matchedOrientation: isMatch ? bestOrientation : "N/A",
    );
  }
}

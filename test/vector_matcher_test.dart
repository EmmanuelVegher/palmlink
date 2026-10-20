import 'package:flutter_test/flutter_test.dart';
import 'package:palmlink/models/patient_model.dart';
import 'package:palmlink/services/vector_matcher.dart';

void main() {
  group('VectorMatcher Unit Tests', () {
    test('L2 Normalization should output zero-mean unit vector', () {
      final input = [3.0, 4.0];
      final normalized = VectorMatcher.normalizeL2(input);
      expect(normalized[0], closeTo(-0.7071, 0.001));
      expect(normalized[1], closeTo(0.7071, 0.001));
    });

    test('Identical vectors should yield 100% (1.0) Cosine Similarity', () {
      final v1 = VectorMatcher.normalizeL2([0.5, 0.2, 0.9, -0.4]);
      final v2 = VectorMatcher.normalizeL2([0.5, 0.2, 0.9, -0.4]);
      final similarity = VectorMatcher.cosineSimilarity(v1, v2);
      expect(similarity, closeTo(1.0, 0.001));
    });

    test('Orthogonal vectors should yield 0% (0.0) Cosine Similarity', () {
      final v1 = [1.0, 0.0];
      final v2 = [0.0, 1.0];
      final similarity = VectorMatcher.cosineSimilarity(v1, v2);
      expect(similarity, closeTo(0.0, 0.001));
    });

    test('Rotation-Invariant Match should detect 90 degree rotated horizontal palm', () {
      final verticalVec = VectorMatcher.normalizeL2(List.generate(128, (i) => i.toDouble()));
      final rotatedHorizontalVec = VectorMatcher.rotateVector90(verticalVec);

      final matchRes = VectorMatcher.rotationInvariantMatch(verticalVec, rotatedHorizontalVec);
      expect(matchRes['similarity'], greaterThanOrEqualTo(0.65));
    });

    test('1:N Dual-Palm Match should correctly identify either Left or Right palm', () {
      final leftVector = VectorMatcher.normalizeL2(List.generate(128, (i) => i.toDouble()));
      final rightVector = VectorMatcher.normalizeL2(List.generate(128, (i) => (128 - i).toDouble()));

      final patient = PatientModel(
        id: '1',
        patientId: 'PL-101',
        fullName: 'Jane Doe',
        gender: 'Female',
        age: 30,
        phoneNumber: '555-1234',
        bloodGroup: 'O+',
        palmEmbedding: leftVector,
        leftPalmEmbedding: leftVector,
        rightPalmEmbedding: rightVector,
        registeredAt: DateTime.now(),
      );

      // Verify matching against Right Palm
      final rightQuery = VectorMatcher.normalizeL2(List.generate(128, (i) => (128 - i).toDouble() + 0.01));

      final matchResult = VectorMatcher.match1ToN(
        queryVector: rightQuery,
        databasePatients: [patient],
        threshold: 0.78,
      );

      expect(matchResult.isMatch, isTrue);
      expect(matchResult.patient?.fullName, equals('Jane Doe'));
      expect(matchResult.matchedPalmSide, equals('Right Palm'));
      expect(matchResult.similarityScore, greaterThan(0.99));
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/patient_model.dart';
import 'vector_matcher.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final List<PatientModel> _patients = [];
  bool _isInitialized = false;
  File? _dbFile;
  final _uuid = const Uuid();

  List<PatientModel> get patients => List.unmodifiable(_patients);

  /// Initializes the offline local database
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _dbFile = File('${dir.path}/palmlink_patients_db.json');

      if (await _dbFile!.exists()) {
        final content = await _dbFile!.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          _patients.clear();
          for (var item in jsonList) {
            _patients.add(PatientModel.fromJson(item as Map<String, dynamic>));
          }
          debugPrint("📂 Loaded ${_patients.length} offline patient biometrics from local disk.");
        }
      } else {
        await _seedDemoPatients();
      }
    } catch (e) {
      debugPrint("Error initializing offline database: $e");
    } finally {
      _isInitialized = true;
    }
  }

  /// Saves a new patient or updates an existing patient in the offline database
  Future<PatientModel> savePatient({
    required String fullName,
    required String gender,
    required int age,
    required String phoneNumber,
    required String bloodGroup,
    required List<double> palmEmbedding,
    List<double>? leftPalmEmbedding,
    List<double>? rightPalmEmbedding,
    String? customMrn,
  }) async {
    final String id = _uuid.v4();
    final String mrn = customMrn ?? "PL-${(100000 + _patients.length + 1)}";

    final leftVec = VectorMatcher.normalizeL2(leftPalmEmbedding ?? palmEmbedding);
    final rightVec = rightPalmEmbedding != null ? VectorMatcher.normalizeL2(rightPalmEmbedding) : null;

    final patient = PatientModel(
      id: id,
      patientId: mrn,
      fullName: fullName,
      gender: gender,
      age: age,
      phoneNumber: phoneNumber,
      bloodGroup: bloodGroup,
      palmEmbedding: leftVec,
      leftPalmEmbedding: leftVec,
      rightPalmEmbedding: rightVec,
      registeredAt: DateTime.now(),
    );

    _patients.add(patient);
    await _flushToDisk();
    return patient;
  }

  /// Checks if a palm vector matches any existing patient in the database (duplicate check)
  VectorMatchResult checkDuplicate(List<double> palmVector, {double threshold = 0.75}) {
    return VectorMatcher.match1ToN(
      queryVector: palmVector,
      databasePatients: _patients,
      threshold: threshold,
    );
  }

  /// Updates an existing patient record (e.g. refreshing biometric vectors or info)
  Future<PatientModel> updatePatient(PatientModel updatedPatient) async {
    final index = _patients.indexWhere((p) => p.id == updatedPatient.id || p.patientId == updatedPatient.patientId);
    if (index != -1) {
      _patients[index] = updatedPatient;
    } else {
      _patients.add(updatedPatient);
    }
    await _flushToDisk();
    return updatedPatient;
  }

  /// Queries the offline vector database for 1:N similarity match
  VectorMatchResult verifyPalm(List<double> queryVector, {double threshold = 0.78}) {
    final result = VectorMatcher.match1ToN(
      queryVector: queryVector,
      databasePatients: _patients,
      threshold: threshold,
    );

    if (result.isMatch && result.patient != null) {
      // Update last verified timestamp in local memory & disk
      final index = _patients.indexWhere((p) => p.id == result.patient!.id);
      if (index != -1) {
        _patients[index].lastVerifiedAt = DateTime.now();
        _flushToDisk();
      }
    }

    return result;
  }

  /// Deletes a patient by ID
  Future<bool> deletePatient(String id) async {
    int initialCount = _patients.length;
    _patients.removeWhere((p) => p.id == id);
    if (_patients.length < initialCount) {
      await _flushToDisk();
      return true;
    }
    return false;
  }

  /// Purges all patient records and vector embeddings from local offline storage
  Future<void> deleteAllPatients() async {
    _patients.clear();
    await _flushToDisk();
  }

  /// Flushes patients memory state to encrypted/local JSON file
  Future<void> _flushToDisk() async {
    if (_dbFile == null) return;
    try {
      final jsonList = _patients.map((p) => p.toJson()).toList();
      await _dbFile!.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error writing to offline database disk: $e");
    }
  }

  /// Seeds sample demo patient vector data for initial testing/demonstration
  Future<void> _seedDemoPatients() async {
    // Generate deterministic 128-dim vectors for demo patients
    List<double> createDemoVector(int seed) {
      final List<double> vec = [];
      for (int i = 0; i < 128; i++) {
        vec.add(sin(seed * 1.5 + i * 0.1) * 0.5 + 0.5);
      }
      return VectorMatcher.normalizeL2(vec);
    }

    _patients.addAll([
      PatientModel(
        id: _uuid.v4(),
        patientId: "PL-10001",
        fullName: "Sarah Johnson",
        gender: "Female",
        age: 34,
        phoneNumber: "+1 555-0192",
        bloodGroup: "O+",
        palmEmbedding: createDemoVector(1),
        registeredAt: DateTime.now().subtract(const Duration(days: 12)),
      ),
      PatientModel(
        id: _uuid.v4(),
        patientId: "PL-10002",
        fullName: "Emmanuel Nwachukwu",
        gender: "Male",
        age: 42,
        phoneNumber: "+234 803 123 4567",
        bloodGroup: "A+",
        palmEmbedding: createDemoVector(2),
        registeredAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      PatientModel(
        id: _uuid.v4(),
        patientId: "PL-10003",
        fullName: "Amara Patel",
        gender: "Female",
        age: 28,
        phoneNumber: "+91 98765 43210",
        bloodGroup: "B+",
        palmEmbedding: createDemoVector(3),
        registeredAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ]);

    await _flushToDisk();
  }
}

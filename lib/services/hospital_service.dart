import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hospital_model.dart';

class HospitalService {
  static final HospitalService _instance = HospitalService._internal();
  factory HospitalService() => _instance;
  HospitalService._internal();

  final List<HospitalModel> _allHospitals = [];
  HospitalModel? _selectedHospital;
  bool _isInitialized = false;
  File? _customDbFile;

  HospitalModel? get selectedHospital => _selectedHospital;
  bool get hasSelectedHospital => _selectedHospital != null;
  List<HospitalModel> get allHospitals => List.unmodifiable(_allHospitals);

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Load Pre-populated Hospitals from JSON Asset
      final String assetString = await rootBundle.loadString('assets/data/hospitals.json');
      final List<dynamic> jsonList = jsonDecode(assetString);
      _allHospitals.clear();

      for (var item in jsonList) {
        _allHospitals.add(HospitalModel.fromJson(item as Map<String, dynamic>));
      }
      debugPrint("🏥 Loaded ${_allHospitals.length} pre-populated hospital facilities.");

      // 2. Load Custom User-Added or Edited Hospitals from local disk
      final dir = await getApplicationDocumentsDirectory();
      _customDbFile = File('${dir.path}/palmlink_custom_hospitals.json');
      if (await _customDbFile!.exists()) {
        final content = await _customDbFile!.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> customList = jsonDecode(content);
          for (var item in customList) {
            final customHosp = HospitalModel.fromJson(item as Map<String, dynamic>);
            int idx = _allHospitals.indexWhere((h) => h.id == customHosp.id);
            if (idx != -1) {
              _allHospitals[idx] = customHosp;
            } else {
              _allHospitals.add(customHosp);
            }
          }
        }
      }

      // 3. Load Active Saved Hospital from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String? savedJson = prefs.getString('palmlink_active_hospital');
      if (savedJson != null && savedJson.isNotEmpty) {
        _selectedHospital = HospitalModel.fromJson(jsonDecode(savedJson));
      }
    } catch (e) {
      debugPrint("Error initializing HospitalService: $e");
    } finally {
      _isInitialized = true;
    }
  }

  static const List<String> _allNigerianStates = [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
    'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu',
    'FCT Abuja', 'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina',
    'Kebbi', 'Kogi', 'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun',
    'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto', 'Taraba',
    'Yobe', 'Zamfara'
  ];

  /// Returns sorted list of unique States
  List<String> getStates() {
    final set = _allHospitals.map((h) => h.state).toSet();
    set.addAll(_allNigerianStates);
    final states = set.toList();
    states.sort();
    return states;
  }

  /// Returns sorted list of LGAs for a selected State
  List<String> getLgas(String state) {
    final lgas = _allHospitals
        .where((h) => h.state.toLowerCase() == state.toLowerCase())
        .map((h) => h.lga)
        .toSet()
        .toList();
    lgas.sort();
    return lgas;
  }

  /// Returns list of Hospitals for a selected State and LGA
  List<HospitalModel> getHospitals(String state, String lga) {
    return _allHospitals.where((h) {
      return h.state.toLowerCase() == state.toLowerCase() &&
          h.lga.toLowerCase() == lga.toLowerCase();
    }).toList();
  }

  /// Saves selected active hospital to persistent SharedPreferences
  Future<void> setSelectedHospital(HospitalModel hospital) async {
    _selectedHospital = hospital;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('palmlink_active_hospital', jsonEncode(hospital.toJson()));
  }

  /// Adds a new custom hospital and saves to local disk
  Future<HospitalModel> addHospital({
    required String state,
    required String lga,
    required String name,
    required String datimCode,
  }) async {
    final String id = "CUSTOM-${DateTime.now().millisecondsSinceEpoch}";
    final hospital = HospitalModel(
      id: id,
      state: state.trim(),
      lga: lga.trim(),
      name: name.trim(),
      datimCode: datimCode.trim(),
      isCustom: true,
    );

    _allHospitals.add(hospital);
    await _saveCustomHospitalsToDisk();
    return hospital;
  }

  /// Edits an existing hospital record (updates name, LGA, or DATIM Code)
  Future<void> updateHospital(HospitalModel updatedHospital) async {
    int idx = _allHospitals.indexWhere((h) => h.id == updatedHospital.id);
    if (idx != -1) {
      _allHospitals[idx] = updatedHospital;
    } else {
      _allHospitals.add(updatedHospital);
    }

    if (_selectedHospital?.id == updatedHospital.id) {
      await setSelectedHospital(updatedHospital);
    }

    await _saveCustomHospitalsToDisk();
  }

  Future<void> _saveCustomHospitalsToDisk() async {
    if (_customDbFile == null) return;
    try {
      final customHospitals = _allHospitals.where((h) => h.isCustom || h.id.startsWith("CUSTOM-")).map((h) => h.toJson()).toList();
      await _customDbFile!.writeAsString(jsonEncode(customHospitals));
    } catch (e) {
      debugPrint("Error writing custom hospitals to disk: $e");
    }
  }
}

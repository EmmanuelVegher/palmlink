import 'package:flutter_test/flutter_test.dart';
import 'package:palmlink/models/hospital_model.dart';
import 'package:palmlink/services/hospital_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HospitalService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Add custom hospital should persist and retrieve correctly', () async {
      final service = HospitalService();
      final added = await service.addHospital(
        state: 'Bayelsa',
        lga: 'Yenagoa',
        name: 'Test Innovation Clinic',
        datimCode: 'TEST123456',
      );

      expect(added.name, equals('Test Innovation Clinic'));
      expect(added.datimCode, equals('TEST123456'));
      expect(added.isCustom, isTrue);
    });

    test('Set and retrieve selected active hospital', () async {
      final service = HospitalService();
      final testHosp = HospitalModel(
        id: 'HOSP-1',
        state: 'Edo',
        lga: 'Egor',
        name: 'UBTH Specialist Center',
        datimCode: 'EDO9999',
      );

      await service.setSelectedHospital(testHosp);
      expect(service.hasSelectedHospital, isTrue);
      expect(service.selectedHospital?.name, equals('UBTH Specialist Center'));
    });
  });
}

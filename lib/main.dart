import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/hospital_onboarding_screen.dart';
import 'screens/scanner_screen.dart';
import 'services/database_service.dart';
import 'services/hospital_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force portrait orientation for optimal low-budget phone camera UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize offline databases and active hospital service
  await DatabaseService().init();
  await HospitalService().init();

  runApp(const PalmLinkApp());
}

class PalmLinkApp extends StatelessWidget {
  const PalmLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool hasHospital = HospitalService().hasSelectedHospital;

    return MaterialApp(
      title: 'PalmLink Offline Biometrics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: hasHospital ? const ScannerScreen() : const HospitalOnboardingScreen(),
    );
  }
}

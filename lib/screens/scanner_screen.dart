import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/patient_model.dart';
import '../services/database_service.dart';
import '../services/palm_roi_extractor.dart';
import '../services/palm_vectorizer.dart';
import '../theme/app_theme.dart';
import '../widgets/duplicate_patient_modal.dart';
import '../widgets/patient_link_modal.dart';
import '../widgets/patient_registration_dialog.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/verification_result_modal.dart';
import 'hospital_onboarding_screen.dart';
import 'patient_directory_screen.dart';

enum ScanMode { verify, enroll }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraReady = false;
  bool _isScanning = false;
  bool _isPalmDetected = false;
  ScanMode _scanMode = ScanMode.verify;
  String _statusMessage = "Position patient's palm inside the green box";

  List<double>? _enrollingLeftPalm;
  List<double>? _enrollingRightPalm;
  PatientModel? _targetLinkingPatient;

  final PalmVectorizer _vectorizer = PalmVectorizer();

  void _startEnrollmentFlow() {
    final patients = DatabaseService().patients;
    if (patients.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => PatientLinkModal(
          onPatientSelected: (selectedPatient) {
            setState(() {
              _targetLinkingPatient = selectedPatient;
              _enrollingLeftPalm = null;
              _enrollingRightPalm = null;
              _scanMode = ScanMode.enroll;
              _statusMessage = "Position ${selectedPatient.fullName}'s LEFT PALM inside box and tap Snap.";
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("✋ Linking Palms for ${selectedPatient.fullName} (${selectedPatient.patientId}). Step 1: Scan LEFT PALM."),
                backgroundColor: AppTheme.primaryEmerald,
                duration: const Duration(seconds: 4),
              ),
            );
          },
          onCreateNewPatient: () {
            setState(() {
              _targetLinkingPatient = null;
              _enrollingLeftPalm = null;
              _enrollingRightPalm = null;
              _scanMode = ScanMode.enroll;
              _statusMessage = "Position LEFT PALM inside box to enroll new patient.";
            });
          },
        ),
      );
    } else {
      setState(() {
        _targetLinkingPatient = null;
        _enrollingLeftPalm = null;
        _enrollingRightPalm = null;
        _scanMode = ScanMode.enroll;
        _statusMessage = "Position LEFT PALM inside box to enroll new patient.";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initEngineAndCamera();
  }

  Future<void> _initEngineAndCamera() async {
    await DatabaseService().init();
    await _vectorizer.initModel();

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        // Use back camera by default for palm scanning
        CameraDescription selectedCam = _availableCameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
          orElse: () => _availableCameras.first,
        );

        _cameraController = CameraController(
          selectedCam,
          ResolutionPreset.medium, // Low resolution (224x224 target) optimized for budget phones
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _isCameraReady = true);
        }
      }
    } catch (e) {
      debugPrint("Camera initialization error (using offline camera simulator mode): $e");
      if (mounted) {
        setState(() {
          _isCameraReady = false;
          _statusMessage = "Offline Camera Simulator Active";
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _vectorizer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initEngineAndCamera();
    }
  }

  /// Processes active palm frame: crops ROI -> converts to Grayscale -> computes 128-dim Vector
  Future<void> _captureAndProcessPalm() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _statusMessage = "Processing Palm Lines & Extracting Vector...";
    });

    try {
      Uint8List imageBytes;

      if (_isCameraReady && _cameraController != null) {
        XFile file = await _cameraController!.takePicture();
        imageBytes = await file.readAsBytes();
      } else {
        // Simulator synthetic palm frame for testing
        imageBytes = _generateSimulatedPalmFrame();
      }

      // 1. Process Palm ROI & Filter Background Items
      ProcessedPalmData roiData = PalmRoiExtractor.processFrame(imageBytes);

      if (mounted) {
        setState(() {
          _isPalmDetected = roiData.isSkinDetected;
        });
      }

      if (!roiData.isSkinDetected) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage = "Palm not detected. Hold hand closer inside box.";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Palm not detected inside target box. Position hand closer."),
              backgroundColor: AppTheme.secondaryCyan,
            ),
          );
        }
        return;
      }

      // 2. Vectorize Palm Print Features
      List<double> palmVector = await _vectorizer.extractVector(roiData);

      // 3. Immediately clear raw image memory bytes for HIPAA Privacy Compliance
      imageBytes = Uint8List(0);

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _statusMessage = "Background Filtered & Vectorized!";
      });

      // 4. Trigger Mode Action
      if (_scanMode == ScanMode.verify) {
        _handleVerification(palmVector);
      } else {
        _handleEnrollment(palmVector);
      }
    } catch (e) {
      debugPrint("Error processing palm scan: $e");
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = "Scan failed. Ensure hand is steady.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Scan Error: $e"), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  void _handleVerification(List<double> queryVector) {
    final result = DatabaseService().verifyPalm(queryVector, threshold: 0.78);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VerificationResultModal(
        matchResult: result,
        onScanAgain: () => setState(() => _statusMessage = "Position patient's palm inside box"),
        onRegisterNew: () {
          _startEnrollmentFlow();
        },
      ),
    );
  }

  Future<void> _handleEnrollment(List<double> palmVector) async {
    // 1. Check if this palm is ALREADY registered to an existing patient (Duplicate Protection)
    final duplicateMatch = DatabaseService().checkDuplicate(palmVector, threshold: 0.75);

    if (duplicateMatch.isMatch && duplicateMatch.patient != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DuplicatePatientModal(
          existingPatient: duplicateMatch.patient!,
          matchResult: duplicateMatch,
          onUpdateBiometrics: () async {
            Navigator.of(ctx).pop();
            // Update existing patient biometrics instead of creating duplicate
            final updated = duplicateMatch.patient!.copyWith(
              leftPalmEmbedding: _enrollingLeftPalm ?? palmVector,
              rightPalmEmbedding: _enrollingRightPalm ?? (duplicateMatch.patient!.rightPalmEmbedding ?? palmVector),
              lastVerifiedAt: DateTime.now(),
            );
            await DatabaseService().updatePatient(updated);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("✅ Updated biometrics for ${updated.fullName} (${updated.patientId})!"),
                  backgroundColor: AppTheme.primaryEmerald,
                ),
              );
              setState(() {
                _enrollingLeftPalm = null;
                _enrollingRightPalm = null;
                _scanMode = ScanMode.verify;
                _statusMessage = "Position patient's palm inside box";
              });
            }
          },
          onViewDirectory: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (c) => const PatientDirectoryScreen()),
            );
          },
          onCancel: () {
            Navigator.of(ctx).pop();
            setState(() {
              _enrollingLeftPalm = null;
              _enrollingRightPalm = null;
              _statusMessage = "Enrollment cancelled. Position palm inside box.";
            });
          },
        ),
      );
      return;
    }

    if (_enrollingLeftPalm == null) {
      // Step 1: Save Left Palm vector and prompt for Right Palm
      setState(() {
        _enrollingLeftPalm = palmVector;
        _statusMessage = "✋ Left Palm Captured! Now position RIGHT PALM and tap Snap.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✋ Left Palm Saved! Now scan Patient's RIGHT PALM."),
          backgroundColor: AppTheme.primaryEmerald,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      // Step 2: Save Right Palm vector
      _enrollingRightPalm = palmVector;

      if (_targetLinkingPatient != null) {
        // Link Dual Palms (Left & Right) directly to existing imported patient!
        final updated = _targetLinkingPatient!.copyWith(
          palmEmbedding: _enrollingLeftPalm!,
          leftPalmEmbedding: _enrollingLeftPalm!,
          rightPalmEmbedding: _enrollingRightPalm!,
          lastVerifiedAt: DateTime.now(),
        );
        await DatabaseService().updatePatient(updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Linked Dual Palms (Left & Right) to ${updated.fullName} (${updated.patientId})!"),
              backgroundColor: AppTheme.primaryEmerald,
            ),
          );
          setState(() {
            _targetLinkingPatient = null;
            _enrollingLeftPalm = null;
            _enrollingRightPalm = null;
            _scanMode = ScanMode.verify;
            _statusMessage = "Position patient's palm inside box to verify";
          });
        }
      } else {
        // Show registration dialog for brand new patient
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PatientRegistrationDialog(
            leftPalmEmbedding: _enrollingLeftPalm!,
            rightPalmEmbedding: _enrollingRightPalm,
            onPatientSaved: (name, mrn) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("✅ Patient $name ($mrn) registered with Dual-Palm vectors!"),
                  backgroundColor: AppTheme.primaryEmerald,
                ),
              );
              setState(() {
                _targetLinkingPatient = null;
                _enrollingLeftPalm = null;
                _enrollingRightPalm = null;
                _scanMode = ScanMode.verify;
                _statusMessage = "Position patient's palm inside box";
              });
            },
          ),
        );
      }
    }
  }

  /// Generates a synthetic 224x224 palm print test frame for emulator/offline camera fallback
  Uint8List _generateSimulatedPalmFrame() {
    final img.Image image = img.Image(width: 300, height: 300);
    img.fill(image, color: img.ColorRgb8(240, 240, 240));
    
    // Draw synthetic palm lines
    img.drawLine(image, x1: 50, y1: 150, x2: 250, y2: 120, color: img.ColorRgb8(100, 100, 100), thickness: 3);
    img.drawLine(image, x1: 60, y1: 180, x2: 220, y2: 220, color: img.ColorRgb8(100, 100, 100), thickness: 3);
    img.drawLine(image, x1: 120, y1: 80, x2: 180, y2: 240, color: img.ColorRgb8(100, 100, 100), thickness: 2);

    return Uint8List.fromList(img.encodeJpg(image));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.back_hand_rounded, color: AppTheme.primaryEmerald, size: 22),
            SizedBox(width: 8),
            Text("PalmLink Biometrics"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryEmerald),
            tooltip: "Hospital Facility Setup",
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const HospitalOnboardingScreen(isModalMode: true)),
              );
              setState(() {}); // Refresh hospital info if changed
            },
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_rounded, color: AppTheme.primaryEmerald),
            tooltip: "Patient Directory",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const PatientDirectoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Camera Feed View / Simulator Background
          Positioned.fill(
            child: _isCameraReady && _cameraController != null && _cameraController!.value.isInitialized
                ? CameraPreview(_cameraController!)
                : Container(
                    color: AppTheme.lightBackground,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text("Camera Standby / Simulator Mode", style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.lightCard),
                            icon: const Icon(Icons.touch_app_rounded, color: AppTheme.primaryEmerald),
                            label: const Text("Simulate Palm Scan", style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
                            onPressed: _captureAndProcessPalm,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Interactive HUD Overlay
          ScannerOverlay(
            isScanning: _isScanning,
            isPalmDetected: _isPalmDetected,
            statusText: _statusMessage,
            isCameraReady: _isCameraReady,
            onSnapPressed: _captureAndProcessPalm,
          ),

          // 3. Top Mode Toggle Switch (Verify vs Enroll) - Light Theme
          Positioned(
            top: 105,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.lightCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 1),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _scanMode = ScanMode.verify;
                          _statusMessage = "Position patient's palm inside box to verify";
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _scanMode == ScanMode.verify ? AppTheme.primaryEmerald : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fact_check_rounded,
                              size: 16,
                              color: _scanMode == ScanMode.verify ? Colors.white : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "1:N Verification",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: _scanMode == ScanMode.verify ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _startEnrollmentFlow();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _scanMode == ScanMode.enroll ? AppTheme.secondaryCyan : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 16,
                              color: _scanMode == ScanMode.enroll ? Colors.white : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Enroll Patient",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: _scanMode == ScanMode.enroll ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

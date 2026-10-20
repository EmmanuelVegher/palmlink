import 'package:flutter/material.dart';
import '../models/patient_model.dart';
import '../services/vector_matcher.dart';
import '../theme/app_theme.dart';

class DuplicatePatientModal extends StatelessWidget {
  final PatientModel existingPatient;
  final VectorMatchResult matchResult;
  final VoidCallback onUpdateBiometrics;
  final VoidCallback onViewDirectory;
  final VoidCallback onCancel;

  const DuplicatePatientModal({
    super.key,
    required this.existingPatient,
    required this.matchResult,
    required this.onUpdateBiometrics,
    required this.onViewDirectory,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.lightCard,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.amberWarning, width: 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Warning Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.amberWarning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppTheme.amberWarning, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Duplicate Palm Detected!",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      Text(
                        "Patient Already Enrolled in DB",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.amberWarning),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Warning Notice Text
            const Text(
              "This palm print vector matches an existing patient in your offline biometric database. Duplicate patient registrations are prevented to protect medical records.",
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),

            // Existing Patient Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        existingPatient.fullName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${matchResult.matchPercentage}% Match",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Medical ID: ${existingPatient.patientId} • ${existingPatient.gender}, ${existingPatient.age} yrs",
                    style: const TextStyle(fontSize: 12, color: AppTheme.secondaryCyan, fontWeight: FontWeight.w600),
                  ),
                  const Divider(color: AppTheme.borderLight, height: 16),
                  Row(
                    children: [
                      const Icon(Icons.front_hand_rounded, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        "Matched Vector: ${matchResult.matchedPalmSide} (${matchResult.matchedOrientation})",
                        style: const TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onUpdateBiometrics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text("Update Existing Patient Biometrics", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onViewDirectory,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.secondaryCyan),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.people_alt_rounded, color: AppTheme.secondaryCyan, size: 16),
                        label: const Text("View Profile", style: TextStyle(color: AppTheme.secondaryCyan, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: onCancel,
                        child: const Text("Cancel Scan", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

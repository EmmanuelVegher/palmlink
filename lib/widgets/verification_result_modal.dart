import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/vector_matcher.dart';
import '../theme/app_theme.dart';

class VerificationResultModal extends StatelessWidget {
  final VectorMatchResult matchResult;
  final VoidCallback onScanAgain;
  final VoidCallback? onRegisterNew;

  const VerificationResultModal({
    super.key,
    required this.matchResult,
    required this.onScanAgain,
    this.onRegisterNew,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMatch = matchResult.isMatch && matchResult.patient != null;
    final patient = matchResult.patient;
    final int scorePercent = matchResult.matchPercentage;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.lightCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Status Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isMatch ? AppTheme.primaryEmerald : AppTheme.errorRed).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMatch ? Icons.verified_user_rounded : Icons.person_off_rounded,
              color: isMatch ? AppTheme.primaryEmerald : AppTheme.errorRed,
              size: 44,
            ),
          ),
          const SizedBox(height: 12),

          // Match Confidence & Orientation Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: (isMatch ? AppTheme.primaryEmerald : AppTheme.errorRed).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isMatch ? AppTheme.primaryEmerald : AppTheme.errorRed,
              ),
            ),
            child: Text(
              isMatch ? "MATCH CONFIRMED: $scorePercent% SIMILARITY" : "NO MATCH FOUND: $scorePercent% SIMILARITY",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isMatch ? AppTheme.primaryEmerald : AppTheme.errorRed,
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (isMatch && patient != null) ...[
            Text(
              patient.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              "Medical ID: ${patient.patientId}",
              style: const TextStyle(fontSize: 13, color: AppTheme.secondaryCyan, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),

            // Info Details Grid
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    Icons.front_hand_rounded,
                    "Matched Palm & View",
                    "${matchResult.matchedPalmSide} • ${matchResult.matchedOrientation}",
                    valueColor: AppTheme.primaryEmerald,
                  ),
                  const Divider(color: AppTheme.borderLight, height: 14),
                  _buildDetailRow(Icons.cake_rounded, "Age & Gender", "${patient.age} yrs • ${patient.gender}"),
                  const Divider(color: AppTheme.borderLight, height: 14),
                  _buildDetailRow(Icons.opacity_rounded, "Blood Group", patient.bloodGroup),
                  const Divider(color: AppTheme.borderLight, height: 14),
                  _buildDetailRow(Icons.phone_rounded, "Contact Phone", patient.phoneNumber.isNotEmpty ? patient.phoneNumber : "N/A"),
                  const Divider(color: AppTheme.borderLight, height: 14),
                  _buildDetailRow(
                    Icons.history_rounded,
                    "Registered Date",
                    DateFormat('MMM dd, yyyy').format(patient.registeredAt),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              "Unrecognized Palm Scan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              "The scanned palm vector similarity score ($scorePercent%) is below the required offline verification threshold (78%).",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 18),

          // Action Buttons - Overflow Safe
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onScanAgain();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.secondaryCyan),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.secondaryCyan, size: 18),
                  label: const Text(
                    "Scan Again",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.secondaryCyan, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (!isMatch && onRegisterNew != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRegisterNew!();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text(
                      "Enroll Patient",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: valueColor ?? AppTheme.textMuted),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}

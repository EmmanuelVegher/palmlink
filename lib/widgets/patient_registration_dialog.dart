import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class PatientRegistrationDialog extends StatefulWidget {
  final List<double> leftPalmEmbedding;
  final List<double>? rightPalmEmbedding;
  final Function(String name, String mrn) onPatientSaved;

  const PatientRegistrationDialog({
    super.key,
    required this.leftPalmEmbedding,
    this.rightPalmEmbedding,
    required this.onPatientSaved,
  });

  @override
  State<PatientRegistrationDialog> createState() => _PatientRegistrationDialogState();
}

class _PatientRegistrationDialogState extends State<PatientRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrnController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  String _gender = "Male";
  String _bloodGroup = "O+";
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    int patientCount = DatabaseService().patients.length + 1;
    _mrnController.text = "PL-1000$patientCount";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrnController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final patient = await DatabaseService().savePatient(
        fullName: _nameController.text.trim(),
        customMrn: _mrnController.text.trim(),
        gender: _gender,
        age: int.tryParse(_ageController.text.trim()) ?? 30,
        phoneNumber: _phoneController.text.trim(),
        bloodGroup: _bloodGroup,
        palmEmbedding: widget.leftPalmEmbedding,
        leftPalmEmbedding: widget.leftPalmEmbedding,
        rightPalmEmbedding: widget.rightPalmEmbedding,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPatientSaved(patient.fullName, patient.patientId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save patient: $e"), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRightPalm = widget.rightPalmEmbedding != null && widget.rightPalmEmbedding!.isNotEmpty;

    return Dialog(
      backgroundColor: AppTheme.lightCard,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_rounded, color: AppTheme.primaryEmerald, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Register Patient",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        Text(
                          "Dual-Palm Biometric Enrollment",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryEmerald),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Dual-Palm Vectors Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.back_hand_rounded, size: 15, color: AppTheme.primaryEmerald),
                        const SizedBox(width: 6),
                        const Text("Left Palm Vector:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text("128 Dims Saved", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.front_hand_rounded,
                          size: 15,
                          color: hasRightPalm ? AppTheme.secondaryCyan : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        const Text("Right Palm Vector:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (hasRightPalm ? AppTheme.secondaryCyan : AppTheme.textMuted).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            hasRightPalm ? "128 Dims Saved" : "Same/Mirrored Vector",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasRightPalm ? AppTheme.secondaryCyan : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Input Fields
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: "Full Name *",
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.textMuted, size: 20),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _mrnController,
                      style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: "Patient ID *",
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? "ID required" : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: "Age *",
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? "Age required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      isExpanded: true,
                      dropdownColor: AppTheme.lightCard,
                      style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: "Gender",
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: ["Male", "Female", "Other"]
                          .map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) => setState(() => _gender = val!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bloodGroup,
                      isExpanded: true,
                      dropdownColor: AppTheme.lightCard,
                      style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: "Blood",
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]
                          .map((bg) => DropdownMenuItem(value: bg, child: Text(bg, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) => setState(() => _bloodGroup = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons - Overflow Safe
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submitForm,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        _isSaving ? "Saving..." : "Save Dual Vectors",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

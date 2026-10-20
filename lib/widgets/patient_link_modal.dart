import 'package:flutter/material.dart';
import '../models/patient_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class PatientLinkModal extends StatefulWidget {
  final Function(PatientModel patient) onPatientSelected;
  final VoidCallback onCreateNewPatient;

  const PatientLinkModal({
    super.key,
    required this.onPatientSelected,
    required this.onCreateNewPatient,
  });

  @override
  State<PatientLinkModal> createState() => _PatientLinkModalState();
}

class _PatientLinkModalState extends State<PatientLinkModal> {
  final TextEditingController _searchController = TextEditingController();
  List<PatientModel> _allPatients = [];
  List<PatientModel> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    _allPatients = DatabaseService().patients;
    _filteredPatients = _allPatients;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = _allPatients;
      } else {
        _filteredPatients = _allPatients.where((p) {
          return p.fullName.toLowerCase().contains(query) ||
              p.patientId.toLowerCase().contains(query) ||
              p.phoneNumber.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 520, maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            const Row(
              children: [
                Icon(Icons.person_search_rounded, color: AppTheme.primaryEmerald, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Link Palm Biometrics",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Select an imported patient from your directory to link their dual (left & right) palm vectors:",
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            // Search input field
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by Name, Patient ID, or Phone...",
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryEmerald, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),

            // Filtered Patient List
            Expanded(
              child: _filteredPatients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_off_rounded, color: AppTheme.textMuted, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            _allPatients.isEmpty
                                ? "No imported patients found.\nImport patients or create a new record."
                                : "No patient matching '${_searchController.text}'",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredPatients.length,
                      itemBuilder: (ctx, idx) {
                        final patient = _filteredPatients[idx];
                        final bool hasBio = patient.hasBiometrics;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: AppTheme.inputFill,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: hasBio ? AppTheme.borderLight : AppTheme.amberWarning.withValues(alpha: 0.5),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: CircleAvatar(
                              backgroundColor: hasBio ? AppTheme.primaryEmerald.withValues(alpha: 0.15) : AppTheme.amberWarning.withValues(alpha: 0.2),
                              child: Icon(
                                hasBio ? Icons.fingerprint_rounded : Icons.person_add_alt_1_rounded,
                                color: hasBio ? AppTheme.primaryEmerald : AppTheme.amberWarning,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              patient.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                            ),
                            subtitle: Text(
                              "ID: ${patient.patientId} • ${patient.gender}, ${patient.age}y",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasBio ? AppTheme.primaryEmerald.withValues(alpha: 0.1) : AppTheme.amberWarning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                hasBio ? "Update Palms" : "Link Palms",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: hasBio ? AppTheme.primaryEmerald : AppTheme.amberWarning,
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              widget.onPatientSelected(patient);
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // Create New Patient Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onCreateNewPatient();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primaryEmerald),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.person_add_rounded, color: AppTheme.primaryEmerald, size: 18),
                label: const Text(
                  "Register Brand New Patient",
                  style: TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

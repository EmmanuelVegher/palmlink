import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/patient_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'patient_import_screen.dart';

class PatientDirectoryScreen extends StatefulWidget {
  const PatientDirectoryScreen({super.key});

  @override
  State<PatientDirectoryScreen> createState() => _PatientDirectoryScreenState();
}

class _PatientDirectoryScreenState extends State<PatientDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PatientModel> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    _filteredPatients = DatabaseService().patients;
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
        _filteredPatients = DatabaseService().patients;
      } else {
        _filteredPatients = DatabaseService().patients.where((p) {
          return p.fullName.toLowerCase().contains(query) ||
              p.patientId.toLowerCase().contains(query) ||
              p.phoneNumber.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _deletePatient(PatientModel patient) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Delete Patient Biometrics?",
                style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete ${patient.fullName} (${patient.patientId})? This will permanently erase their bio-data and 128-dimensional palm vector data from local offline storage.",
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text("Delete Permanently"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService().deletePatient(patient.id);
      _onSearchChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🗑️ Bio-data and vectors for ${patient.fullName} deleted permanently."),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _deleteAllPatients() async {
    final patientCount = DatabaseService().patients.length;
    if (patientCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No patient records to delete.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Delete ALL Patients?",
                style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          "CAUTION: Are you sure you want to purge all $patientCount patient records from your local database? This will permanently delete all bio-data and 128-dimensional vectorized palm prints from disk. This action CANNOT be undone!",
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text("Purge All Records"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService().deleteAllPatients();
      _onSearchChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🗑️ All patient bio-data and palm vectors permanently deleted!"),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPatients = DatabaseService().patients;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Offline Patient Directory"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_rounded, color: AppTheme.primaryEmerald),
            tooltip: "Import Patients (CSV / OpenMRS)",
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const PatientImportScreen()),
              );
              _onSearchChanged(); // Refresh directory upon return
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed),
            tooltip: "Delete All Patients",
            onPressed: _deleteAllPatients,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: "PalmLink Biometrics",
                applicationVersion: "1.0.0 (Offline INT8)",
                children: [
                  const Text("100% Offline Patient Identification System powered by Palm Print Vectorization & Cosine Similarity search."),
                ],
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Database Stats Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: const BoxDecoration(
              color: AppTheme.lightCard,
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatTile(Icons.people_rounded, "${allPatients.length}", "Total Patients"),
                Container(height: 28, width: 1, color: AppTheme.borderLight),
                _buildStatTile(Icons.data_array_rounded, "128-Dim", "Vector Format"),
                Container(height: 28, width: 1, color: AppTheme.borderLight),
                _buildStatTile(Icons.wifi_off_rounded, "100%", "Offline Storage"),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search by Name, Patient ID, or Phone...",
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),

          // Patient List
          Expanded(
            child: _filteredPatients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text("No Patient Records Found", style: TextStyle(color: AppTheme.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _filteredPatients.length,
                    itemBuilder: (context, index) {
                      final patient = _filteredPatients[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.lightCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderLight),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 0, offset: Offset(0, 1)),
                          ],
                        ),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                            child: Text(
                              patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : "?",
                              style: const TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            patient.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark, fontSize: 15),
                          ),
                          subtitle: Text(
                            "ID: ${patient.patientId} • ${patient.gender}, ${patient.age} yrs • Blood: ${patient.bloodGroup}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 22),
                            tooltip: "Delete Patient",
                            onPressed: () => _deletePatient(patient),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(color: AppTheme.borderLight, height: 1),
                                  const SizedBox(height: 10),
                                  if (patient.hasBiometrics) ...[
                                    const Row(
                                      children: [
                                        Icon(Icons.fingerprint_rounded, size: 15, color: AppTheme.primaryEmerald),
                                        SizedBox(width: 6),
                                        Text(
                                          "Palm Vector Data Registered (128 Dims):",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.inputFill,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "[${patient.activeLeftPalm.take(6).map((e) => e.toStringAsFixed(3)).join(', ')}, ...]",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textMuted),
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.amberWarning.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.amberWarning.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: AppTheme.amberWarning, size: 20),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              "Biometrics Not Captured Yet\nImported patient record without palm prints.",
                                              style: TextStyle(fontSize: 11, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryEmerald,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            icon: const Icon(Icons.camera_alt_rounded, size: 14),
                                            label: const Text("Enroll Palms", style: TextStyle(fontSize: 11)),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              // Route to Dual-Palm capture for this patient
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Registered: ${DateFormat('MMM dd, yyyy').format(patient.registeredAt)}",
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
                                        icon: const Icon(Icons.delete_forever_rounded, size: 16),
                                        label: const Text("Delete Record", style: TextStyle(fontSize: 12)),
                                        onPressed: () => _deletePatient(patient),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppTheme.primaryEmerald),
            const SizedBox(width: 5),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }
}

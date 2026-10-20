import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/openmrs_service.dart';
import '../theme/app_theme.dart';

class PatientImportScreen extends StatefulWidget {
  const PatientImportScreen({super.key});

  @override
  State<PatientImportScreen> createState() => _PatientImportScreenState();
}

class _PatientImportScreenState extends State<PatientImportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // CSV Controllers
  final _csvTextController = TextEditingController();

  // OpenMRS Network Controllers
  final _serverUrlController = TextEditingController(text: "http://192.168.1.100:8080/openmrs");
  final _usernameController = TextEditingController(text: "admin");
  final _passwordController = TextEditingController(text: "Admin123");

  bool _isObscurePassword = true;
  bool _isLoading = false;
  String _importStatus = "";

  static const String _sampleCsvData = '''FullName,PatientID,Gender,Age,Phone,BloodGroup
Oluwaseun Adebayo,PL-20001,Male,38,+234 802 123 4567,O+
Chinedu Okeke,PL-20002,Male,45,+234 803 987 6543,A+
Fatima Bello,PL-20003,Female,29,+234 805 444 3322,B+
Chioma Eze,PL-20004,Female,32,+234 807 555 8899,O-
Ibrahim Musa,PL-20005,Male,51,+234 818 000 1122,AB+''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _csvTextController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _importCsvData() async {
    final text = _csvTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please paste or load CSV patient data first."), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _importStatus = "Parsing CSV records...";
    });

    try {
      final patients = OpenMrsService.parseCsvPatients(text);
      if (patients.isEmpty) {
        throw Exception("No valid patient records found in CSV text.");
      }

      int addedCount = 0;
      for (var p in patients) {
        await DatabaseService().savePatient(
          fullName: p.fullName,
          customMrn: p.patientId,
          gender: p.gender,
          age: p.age,
          phoneNumber: p.phoneNumber,
          bloodGroup: p.bloodGroup,
          palmEmbedding: p.palmEmbedding,
        );
        addedCount++;
      }

      if (mounted) {
        _showSuccessDialog("CSV Onboarding Complete", "Successfully imported $addedCount patient records into PalmLink offline database!");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("CSV Import Error: $e"), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncOpenMrs() async {
    final url = _serverUrlController.text.trim();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide OpenMRS URL, Username, and Password."), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _importStatus = "Connecting to OpenMRS REST Server...";
    });

    try {
      final imported = await OpenMrsService.fetchPatientsFromOpenMrs(
        serverUrl: url,
        username: user,
        password: pass,
      );

      int count = 0;
      for (var p in imported) {
        await DatabaseService().savePatient(
          fullName: p.fullName,
          customMrn: p.patientId,
          gender: p.gender,
          age: p.age,
          phoneNumber: p.phoneNumber,
          bloodGroup: p.bloodGroup,
          palmEmbedding: p.palmEmbedding,
        );
        count++;
      }

      if (mounted) {
        _showSuccessDialog("OpenMRS Sync Successful", "Connected to OpenMRS REST API ($url) and imported $count patient profiles into PalmLink!");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OpenMRS Connection Error: $e"), backgroundColor: AppTheme.errorRed, duration: const Duration(seconds: 4)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryEmerald, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Return to Directory
            },
            child: const Text("Done & View Directory"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Onboard Patients (CSV / OpenMRS)"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryEmerald,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.primaryEmerald,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_rounded), text: "CSV Import"),
            Tab(icon: Icon(Icons.lan_rounded), text: "OpenMRS Direct Sync"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCsvImportTab(),
          _buildOpenMrsSyncTab(),
        ],
      ),
    );
  }

  Widget _buildCsvImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.secondaryCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.secondaryCyan.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.secondaryCyan),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Quickly batch onboard patient records by pasting CSV data. Expected headers: FullName, PatientID, Gender, Age, Phone, BloodGroup",
                    style: TextStyle(fontSize: 12, color: AppTheme.textDark, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("CSV Data Input:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              TextButton.icon(
                onPressed: () => setState(() => _csvTextController.text = _sampleCsvData),
                icon: const Icon(Icons.content_paste_rounded, size: 16, color: AppTheme.primaryEmerald),
                label: const Text("Load Sample CSV", style: TextStyle(color: AppTheme.primaryEmerald, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _csvTextController,
            maxLines: 10,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.textDark),
            decoration: const InputDecoration(
              hintText: "FullName,PatientID,Gender,Age,Phone,BloodGroup\nJohn Doe,PL-101,Male,34,+234 800 000 0000,O+",
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _importCsvData,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.file_download_rounded, size: 20),
              label: Text(_isLoading ? _importStatus : "Parse & Import CSV Patients", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenMrsSyncTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // OpenMRS API Specs Header Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storage_rounded, color: AppTheme.primaryEmerald, size: 20),
                    SizedBox(width: 8),
                    Text("OpenMRS / NMRS Integration REST Endpoints", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Endpoints tested: ${OpenMrsService.openMrsRestPatientEndpoint}\nFHIR R4 Endpoint: ${OpenMrsService.openMrsFhirPatientEndpoint}",
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Inputs
          TextFormField(
            controller: _serverUrlController,
            style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
            decoration: const InputDecoration(
              labelText: "OpenMRS Base Server URL *",
              hintText: "http://192.168.1.100:8080/openmrs",
              prefixIcon: Icon(Icons.dns_rounded, color: AppTheme.textMuted, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                  decoration: const InputDecoration(
                    labelText: "Username *",
                    prefixIcon: Icon(Icons.person_rounded, color: AppTheme.textMuted, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscurePassword,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                  decoration: InputDecoration(
                    labelText: "Password *",
                    prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.textMuted, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                      onPressed: () => setState(() => _isObscurePassword = !_isObscurePassword),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _syncOpenMrs,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryEmerald,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_download_rounded, size: 20),
              label: Text(_isLoading ? _importStatus : "Connect & Import OpenMRS Patients", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

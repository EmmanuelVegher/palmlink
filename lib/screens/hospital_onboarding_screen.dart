import 'package:flutter/material.dart';
import '../models/hospital_model.dart';
import '../services/hospital_service.dart';
import '../theme/app_theme.dart';
import 'scanner_screen.dart';

class HospitalOnboardingScreen extends StatefulWidget {
  final bool isModalMode;

  const HospitalOnboardingScreen({super.key, this.isModalMode = false});

  @override
  State<HospitalOnboardingScreen> createState() => _HospitalOnboardingScreenState();
}

class _HospitalOnboardingScreenState extends State<HospitalOnboardingScreen> {
  final HospitalService _hospitalService = HospitalService();

  String? _selectedState;
  String? _selectedLga;
  HospitalModel? _selectedHospital;

  List<String> _states = [];
  List<String> _lgas = [];
  List<HospitalModel> _hospitals = [];

  final TextEditingController _hospitalSearchController = TextEditingController();
  List<HospitalModel> _filteredHospitals = [];

  @override
  void initState() {
    super.initState();
    _states = _hospitalService.getStates();

    // If an active hospital is already saved, pre-populate State, LGA, and Hospital
    if (_hospitalService.hasSelectedHospital) {
      final active = _hospitalService.selectedHospital!;
      _selectedState = active.state;
      _lgas = _hospitalService.getLgas(_selectedState!);
      _selectedLga = active.lga;
      _hospitals = _hospitalService.getHospitals(_selectedState!, _selectedLga!);
      _filteredHospitals = _hospitals;
      _selectedHospital = active;
    } else if (_states.isNotEmpty) {
      _selectedState = _states.first;
      _onStateChanged(_selectedState);
    }

    _hospitalSearchController.addListener(_filterHospitals);
  }

  @override
  void dispose() {
    _hospitalSearchController.removeListener(_filterHospitals);
    _hospitalSearchController.dispose();
    super.dispose();
  }

  void _onStateChanged(String? newState) {
    if (newState == null) return;
    setState(() {
      _selectedState = newState;
      _lgas = _hospitalService.getLgas(newState);
      _selectedLga = _lgas.isNotEmpty ? _lgas.first : null;
      _hospitals = _selectedLga != null ? _hospitalService.getHospitals(newState, _selectedLga!) : [];
      _filteredHospitals = _hospitals;
      _selectedHospital = null; // Require explicit selection
      _hospitalSearchController.clear();
    });
  }

  void _onLgaChanged(String? newLga) {
    if (newLga == null || _selectedState == null) return;
    setState(() {
      _selectedLga = newLga;
      _hospitals = _hospitalService.getHospitals(_selectedState!, newLga);
      _filteredHospitals = _hospitals;
      _selectedHospital = null; // Require explicit selection
      _hospitalSearchController.clear();
    });
  }

  void _filterHospitals() {
    final q = _hospitalSearchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredHospitals = _hospitals;
      } else {
        _filteredHospitals = _hospitals.where((h) {
          return h.name.toLowerCase().contains(q) || h.datimCode.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _saveAndProceed() async {
    if (_selectedHospital == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a hospital facility first."), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    await _hospitalService.setSelectedHospital(_selectedHospital!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Active Facility Set: ${_selectedHospital!.name} (${_selectedHospital!.datimCode})"),
        backgroundColor: AppTheme.primaryEmerald,
      ),
    );

    if (widget.isModalMode) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (ctx) => const ScannerScreen()),
      );
    }
  }

  void _showAddHospitalDialog() {
    final stateController = TextEditingController(text: _selectedState ?? "");
    final lgaController = TextEditingController(text: _selectedLga ?? "");
    final nameController = TextEditingController();
    final datimController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_location_alt_rounded, color: AppTheme.primaryEmerald, size: 24),
                    SizedBox(width: 10),
                    Text("Add New Facility", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: stateController,
                  decoration: const InputDecoration(labelText: "State *"),
                  validator: (v) => v == null || v.trim().isEmpty ? "State is required" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: lgaController,
                  decoration: const InputDecoration(labelText: "Local Government Area (LGA) *"),
                  validator: (v) => v == null || v.trim().isEmpty ? "LGA is required" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Facility / Hospital Name *"),
                  validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: datimController,
                  decoration: const InputDecoration(labelText: "DATIM Code *"),
                  validator: (v) => v == null || v.trim().isEmpty ? "DATIM code required" : null,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final created = await _hospitalService.addHospital(
                          state: stateController.text.trim(),
                          lga: lgaController.text.trim(),
                          name: nameController.text.trim(),
                          datimCode: datimController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {
                          _states = _hospitalService.getStates();
                          _selectedState = created.state;
                          _lgas = _hospitalService.getLgas(created.state);
                          _selectedLga = created.lga;
                          _hospitals = _hospitalService.getHospitals(created.state, created.lga);
                          _filteredHospitals = _hospitals;
                          _selectedHospital = created;
                        });
                      },
                      child: const Text("Add Facility"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditHospitalDialog() {
    if (_selectedHospital == null) return;
    final hosp = _selectedHospital!;

    final stateController = TextEditingController(text: hosp.state);
    final lgaController = TextEditingController(text: hosp.lga);
    final nameController = TextEditingController(text: hosp.name);
    final datimController = TextEditingController(text: hosp.datimCode);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_location_alt_rounded, color: AppTheme.secondaryCyan, size: 24),
                    SizedBox(width: 10),
                    Text("Edit Facility Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: stateController,
                  decoration: const InputDecoration(labelText: "State *"),
                  validator: (v) => v == null || v.trim().isEmpty ? "State required" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: lgaController,
                  decoration: const InputDecoration(labelText: "LGA *"),
                  validator: (v) => v == null || v.trim().isEmpty ? "LGA required" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Facility Name *"),
                  validator: (v) => v == null || v.trim().isEmpty ? "Facility name required" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: datimController,
                  decoration: const InputDecoration(labelText: "DATIM Code *"),
                  validator: (v) => v == null || v.trim().isEmpty ? "DATIM code required" : null,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final updated = hosp.copyWith(
                          state: stateController.text.trim(),
                          lga: lgaController.text.trim(),
                          name: nameController.text.trim(),
                          datimCode: datimController.text.trim(),
                        );
                        await _hospitalService.updateHospital(updated);
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {
                          _selectedState = updated.state;
                          _lgas = _hospitalService.getLgas(updated.state);
                          _selectedLga = updated.lga;
                          _hospitals = _hospitalService.getHospitals(updated.state, updated.lga);
                          _filteredHospitals = _hospitals;
                          _selectedHospital = updated;
                        });
                      },
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Hospital Facility"),
        centerTitle: true,
        automaticallyImplyLeading: widget.isModalMode,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.primaryEmerald),
            tooltip: "Add New Facility",
            onPressed: _showAddHospitalDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_hospital_rounded, color: AppTheme.primaryEmerald, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Facility Setup & Onboarding", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          SizedBox(height: 2),
                          Text("Select State -> LGA -> Facility to initialize biometric scanner.", style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Step 1: Select State
              const Text("1. Select State", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedState,
                isExpanded: true,
                dropdownColor: AppTheme.lightCard,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.map_rounded, color: AppTheme.primaryEmerald, size: 20)),
                items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _onStateChanged,
              ),
              const SizedBox(height: 16),

              // Step 2: Select Local Government Area (LGA)
              const Text("2. Select Local Government Area (LGA)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedLga,
                isExpanded: true,
                dropdownColor: AppTheme.lightCard,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.location_city_rounded, color: AppTheme.secondaryCyan, size: 20)),
                items: _lgas.map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _onLgaChanged,
              ),
              const SizedBox(height: 16),

              // Step 3: Select Facility / Hospital
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("3. Select Facility / Hospital", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  Text("${_filteredHospitals.length} Facilities", style: const TextStyle(fontSize: 12, color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),

              // Hospital Search Bar
              TextFormField(
                controller: _hospitalSearchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Filter facilities in ${_selectedLga ?? ''}...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),

              // Facility Radio Selection List
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: AppTheme.inputFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: _filteredHospitals.isEmpty
                    ? const Center(child: Text("No facilities found for this LGA", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)))
                    : ListView.builder(
                        itemCount: _filteredHospitals.length,
                        itemBuilder: (ctx, i) {
                          final hosp = _filteredHospitals[i];
                          final bool isSelected = _selectedHospital?.id == hosp.id;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            title: Text(hosp.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppTheme.textDark, fontSize: 13)),
                            subtitle: Text("DATIM Code: ${hosp.datimCode}", style: const TextStyle(fontSize: 11, color: AppTheme.secondaryCyan)),
                            leading: Radio<HospitalModel>(
                              value: hosp,
                              groupValue: _selectedHospital,
                              activeColor: AppTheme.primaryEmerald,
                              onChanged: (val) => setState(() => _selectedHospital = val),
                            ),
                            onTap: () => setState(() => _selectedHospital = hosp),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 18),

              // Selected Facility Summary Card
              if (_selectedHospital != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryEmerald, width: 1.5),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 1)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: AppTheme.primaryEmerald, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedHospital!.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: AppTheme.secondaryCyan, size: 20),
                            tooltip: "Edit Facility",
                            onPressed: _showEditHospitalDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("State: ${_selectedHospital!.state} • LGA: ${_selectedHospital!.lga}", style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.primaryEmerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text("DATIM CODE: ${_selectedHospital!.datimCode}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Save & Proceed Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    widget.isModalMode ? "Update Active Facility" : "Confirm & Save Hospital Selection",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

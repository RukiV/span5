import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../models/room.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../core/app_colors.dart';

class AddRoomPage extends StatefulWidget {
  final Building? initialBuilding;

  const AddRoomPage({super.key, this.initialBuilding});

  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _capacityController = TextEditingController();
  String _type = 'other';
  Building? _selectedBuilding;
  bool _isSaving = false;

  final List<Map<String, String>> _types = [
    {'value': 'klas', 'label': 'Klaskamer'},
    {'value': 'laboratorium', 'label': 'Laboratorium'},
    {'value': 'kantoor', 'label': 'Kantoor'},
    {'value': 'konferensie', 'label': 'Konferensiekamer'},
    {'value': 'pakhuis', 'label': 'Pakhuis'},
    {'value': 'badkamer', 'label': 'Badkamer'},
    {'value': 'other', 'label': 'Ander'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialBuilding != null) {
      _selectedBuilding = widget.initialBuilding;
    }
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  List<Building> get _allBuildings => CampusService.campusesNotifier.value
      .expand((Campus c) => c.buildings)
      .toList();

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.navy, fontSize: 14),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gold, width: 2),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBuilding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kies 'n Gebou"),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);

    final room = Room(
      id: 0,
      name: _nameController.text.trim(),
      roomCode: _codeController.text.trim(),
      type: _type,
      capacity: int.tryParse(_capacityController.text),
      buildingId: _selectedBuilding!.id,
    );

    final success = await CampusService.addRoom(room);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie die lokaal byvoeg nie."),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Nuwe Lokaal",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration("Naam"),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Vereis" : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _codeController,
                  decoration: _inputDecoration("Lokaal Kode"),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Vereis";
                    if (v.trim().length > 20) return "Maks 20 karakters";
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SearchableDropdown<Building>(
                  label: "Gebou",
                  hint: "Kies Gebou",
                  value: _selectedBuilding,
                  items: _allBuildings
                      .map((b) => SearchableDropdownItem<Building>(
                          value: b, label: b.name))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBuilding = v),
                  validator: (v) => v == null ? "Vereis" : null,
                ),
                const SizedBox(height: 20),
                SearchableDropdown<String>(
                  label: "Tipe",
                  hint: "Kies Tipe",
                  value: _type,
                  items: _types
                      .map((t) => SearchableDropdownItem(
                            value: t['value']!,
                            label: t['label']!,
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _capacityController,
                  decoration: _inputDecoration("Kapasiteit"),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return int.tryParse(v) == null ? "Nie 'n nommer nie" : null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text("STOOR",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Kanselleer",
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../widgets/searchable_dropdown.dart';

class AddBuildingPage extends StatefulWidget {
  final Campus? campus;
  const AddBuildingPage({super.key, this.campus});

  @override
  State<AddBuildingPage> createState() => _AddBuildingPageState();
}

class _AddBuildingPageState extends State<AddBuildingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _type = 'other';
  bool _isLoading = false;
  Campus? _selectedCampus;

  @override
  void initState() {
    super.initState();
    _selectedCampus = widget.campus;
  }

  final List<Map<String, String>> _types = [
    {'value': 'admin', 'label': 'Administrasie'},
    {'value': 'onderwys', 'label': 'Onderwys'},
    {'value': 'laboratory', 'label': 'Laboratorium'},
    {'value': 'warehouse', 'label': 'Pakhuis'},
    {'value': 'kafeteria', 'label': 'Kafeteria'},
    {'value': 'other', 'label': 'Ander'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gold, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Voeg Nuwe Gebou",
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchableDropdown<Campus>(
                  label: "Terrein",
                  hint: "Kies Terrein",
                  value: _selectedCampus,
                  items: CampusService.campusesNotifier.value
                      .map((c) => SearchableDropdownItem<Campus>(
                          value: c, label: c.name))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCampus = v),
                ),
                const SizedBox(height: 20),
                const Text("Naam",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration(""),
                  validator: (v) => v!.isEmpty ? "Vereis" : null,
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
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              if (_selectedCampus == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Kies 'n Terrein"),
                                      backgroundColor: AppColors.errorRed),
                                );
                                return;
                              }
                              setState(() => _isLoading = true);
                              final building = Building(
                                id: 0,
                                name: _nameController.text,
                                types: [_type],
                                locationId: _selectedCampus!.id,
                              );
                              final success =
                                  await CampusService.addBuilding(building);
                              if (!mounted) return;
                              setState(() => _isLoading = false);
                              if (success) {
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
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
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

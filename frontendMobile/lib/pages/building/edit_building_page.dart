import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/building.dart';
import '../../widgets/searchable_dropdown.dart';

class EditBuildingPage extends StatefulWidget {
  final Building building;
  const EditBuildingPage({super.key, required this.building});

  @override
  State<EditBuildingPage> createState() => _EditBuildingPageState();
}

class _EditBuildingPageState extends State<EditBuildingPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _type;
  bool _isSaving = false;

  final List<Map<String, String>> _types = [
    {'value': 'admin', 'label': 'Administrasie'},
    {'value': 'onderwys', 'label': 'Onderwys'},
    {'value': 'laboratory', 'label': 'Laboratorium'},
    {'value': 'warehouse', 'label': 'Pakhuis'},
    {'value': 'other', 'label': 'Ander'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.building.name);
    _type = widget.building.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 14),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updated = widget.building.copyWith(
      name: _nameController.text,
      type: _type,
    );

    final success = await CampusService.updateBuilding(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gebou suksesvol opgedateer")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kon nie opdateer nie."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Wysig Gebou", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Naam", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    items: _types.map((t) => SearchableDropdownItem(
                      value: t['value']!,
                      label: t['label']!,
                    )).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5E34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Opdateer"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

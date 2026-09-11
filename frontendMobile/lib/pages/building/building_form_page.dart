import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/input_decoration.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../services/campus_service.dart';
import '../../models/user_session.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/view_edit_scaffold.dart';

class BuildingFormPage extends StatefulWidget {
  final Building? building;
  final Campus? campus;

  const BuildingFormPage({super.key, this.building, this.campus});

  @override
  State<BuildingFormPage> createState() => _BuildingFormPageState();
}

class _BuildingFormPageState extends State<BuildingFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _type;
  Campus? _selectedCampus;

  final List<Map<String, String>> _types = [
    {'value': 'admin', 'label': 'Administrasie'},
    {'value': 'onderwys', 'label': 'Onderwys'},
    {'value': 'laboratory', 'label': 'Laboratorium'},
    {'value': 'warehouse', 'label': 'Pakhuis'},
    {'value': 'kafeteria', 'label': 'Kafeteria'},
    {'value': 'other', 'label': 'Ander'},
  ];

  bool get _isCreate => widget.building == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.building?.name ?? "");
    _type = widget.building?.type ?? 'other';
    if (_isCreate) {
      _selectedCampus = widget.campus;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isCreate) {
      if (_selectedCampus == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Kies 'n Terrein"),
              backgroundColor: AppColors.errorRed),
        );
        return;
      }
      final building = Building(
        id: 0,
        name: _nameController.text,
        type: _type,
        locationId: _selectedCampus!.id,
      );
      final success = await CampusService.addBuilding(building);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, true);
      }
      return;
    }

    final updated = widget.building!.copyWith(
      name: _nameController.text,
      type: _type,
    );
    final success = await CampusService.updateBuilding(updated);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gebou suksesvol opgedateer")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Kon nie opdateer nie."),
            backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: appInputDecoration(
          label: "",
          labelStyle: const TextStyle(
              color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 14),
          fillColor: Colors.white,
          radius: 8,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      validator: (v) => v!.isEmpty ? "Vereis" : null,
    );
  }

  Widget _buildTypeField() {
    return SearchableDropdown<String>(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final building = widget.building;

    return ViewEditScaffold(
      alwaysEditable: _isCreate,
      title: _isCreate ? "Voeg Nuwe Gebou" : (building?.name ?? ""),
      editingTitle: _isCreate ? null : "Wysig Gebou",
      saveLabel: _isCreate ? "STOOR" : "OPDATEER",
      canEdit: UserSession.can('buildings.manage'),
      formKey: _formKey,
      onSave: _save,
      child: _isCreate
          ? Column(
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
                _buildNameField(),
                const SizedBox(height: 20),
                _buildTypeField(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Naam",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildNameField(),
                const SizedBox(height: 20),
                _buildTypeField(),
              ],
            ),
    );
  }
}

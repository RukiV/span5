import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/idempotency.dart';
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
  final bool startEditing;

  const BuildingFormPage({
    super.key,
    this.building,
    this.campus,
    this.startEditing = false,
  });

  @override
  State<BuildingFormPage> createState() => _BuildingFormPageState();
}

class _BuildingFormPageState extends State<BuildingFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late List<String> _typesSelected;
  Campus? _selectedCampus;
  String? _idempotencyKey;

  final List<Map<String, String>> _types = [
    {'value': 'admin', 'label': 'Administrasie'},
    {'value': 'onderwys', 'label': 'Onderwys'},
    {'value': 'laboratory', 'label': 'Laboratorium'},
    {'value': 'warehouse', 'label': 'Pakhuis'},
    {'value': 'kafeteria', 'label': 'Kafeteria'},
    {'value': 'residential', 'label': 'Koshuis'},
    {'value': 'other', 'label': 'Ander'},
  ];

  bool get _isCreate => widget.building == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.building?.name ?? "");
    _typesSelected = [...(widget.building?.types ?? const ['other'])];
    if (_isCreate) {
      _selectedCampus = widget.campus;
      _idempotencyKey = Idempotency.generate();
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
        types: _typesSelected,
        locationId: _selectedCampus!.id,
      );
      final success = await CampusService.addBuilding(
          building, idempotencyKey: _idempotencyKey);
      if (!mounted) return;
      if (success) {
        _idempotencyKey = Idempotency.generate();
        Navigator.pop(context, true);
      }
      return;
    }

    final updated = widget.building!.copyWith(
      name: _nameController.text,
      types: _typesSelected,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Tipes", style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: _types.map((type) {
            final value = type['value']!;
            return FilterChip(
              label: Text(type['label']!),
              selected: _typesSelected.contains(value),
              onSelected: (selected) => setState(() {
                if (selected) {
                  _typesSelected.add(value);
                } else if (_typesSelected.length > 1) {
                  _typesSelected.remove(value);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final building = widget.building;

    return ViewEditScaffold(
      alwaysEditable: _isCreate,
      startEditing: widget.startEditing,
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

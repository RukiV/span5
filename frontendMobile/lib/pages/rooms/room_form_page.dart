import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/idempotency.dart';
import '../../core/input_decoration.dart';
import '../../models/building.dart';
import '../../models/campus.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/view_edit_scaffold.dart';
import '../../widgets/confirm_delete.dart';

class RoomFormPage extends StatefulWidget {
  final Room? room;
  final Building? initialBuilding;
  final bool startEditing;

  const RoomFormPage({
    super.key,
    this.room,
    this.initialBuilding,
    this.startEditing = false,
  });

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _capacityController;
  late String _type;
  Building? _selectedBuilding;
  String? _idempotencyKey;

  final List<Map<String, String>> _types = [
    {'value': 'klas', 'label': 'Klaskamer'},
    {'value': 'laboratorium', 'label': 'Laboratorium'},
    {'value': 'kantoor', 'label': 'Kantoor'},
    {'value': 'konferensie', 'label': 'Konferensiekamer'},
    {'value': 'pakhuis', 'label': 'Pakhuis'},
    {'value': 'badkamer', 'label': 'Badkamer'},
    {'value': 'other', 'label': 'Ander'},
  ];

  bool get _isCreate => widget.room == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name ?? "");
    _capacityController =
        TextEditingController(text: widget.room?.capacity?.toString() ?? "");
    _type = widget.room?.type ?? 'other';
    if (_isCreate) {
      _selectedBuilding = widget.initialBuilding;
      _idempotencyKey = Idempotency.generate();
    }
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    if (!_isCreate) {
      CampusService.campusesNotifier.addListener(_onCampusesChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(_resolveBuilding);
        }
      });
    }
  }

  @override
  void dispose() {
    if (!_isCreate) {
      CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    }
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _onCampusesChanged() {
    if (!mounted) return;
    setState(_resolveBuilding);
  }

  void _resolveBuilding() {
    if (_selectedBuilding != null) return;
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        if (b.id == widget.room!.buildingId) {
          _selectedBuilding = b;
          return;
        }
      }
    }
  }

  List<Building> get _allBuildings => CampusService.campusesNotifier.value
      .expand((Campus c) => c.buildings)
      .toList();

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

    if (_isCreate) {
      final room = Room(
        id: 0,
        name: _nameController.text.trim(),
        type: _type,
        capacity: int.tryParse(_capacityController.text),
        buildingId: _selectedBuilding!.id,
      );
      final success =
          await CampusService.addRoom(room, idempotencyKey: _idempotencyKey);
      if (!mounted) return;
      if (success) {
        _idempotencyKey = Idempotency.generate();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kon nie die lokaal byvoeg nie."),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    final updated = widget.room!.copyWith(
      name: _nameController.text.trim(),
      type: _type,
      capacity: int.tryParse(_capacityController.text),
      buildingId: _selectedBuilding!.id,
    );
    final success = await CampusService.updateRoom(updated);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie opdateer nie."),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _confirmDelete() => confirmDeleteAndRun(
        context,
        entityLabel: 'lokaal',
        itemName: widget.room!.name,
        delete: () => CampusService.removeRoom(widget.room!.id),
        onSuccess: () => Navigator.pop(context, true),
      );

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return ViewEditScaffold(
      alwaysEditable: _isCreate,
      startEditing: widget.startEditing,
      title: _isCreate ? "Nuwe Lokaal" : (room?.name ?? ""),
      editingTitle: _isCreate ? null : "Wysig Lokaal",
      saveLabel: _isCreate ? "STOOR" : "OPDATEER",
      canEdit: UserSession.can('rooms.manage'),
      formKey: _formKey,
      onSave: _save,
      deleteButton: _isCreate || !UserSession.can('rooms.manage')
          ? null
          : SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: const Text("VERWYDER LOKAAL",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: appInputDecoration(label: "Naam"),
            validator: (v) => (v == null || v.trim().isEmpty) ? "Vereis" : null,
          ),
          const SizedBox(height: 20),
          SearchableDropdown<Building>(
            label: "Gebou",
            hint: "Kies Gebou",
            value: _selectedBuilding,
            items: _allBuildings
                .map((b) =>
                    SearchableDropdownItem<Building>(value: b, label: b.name))
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
            decoration: appInputDecoration(label: "Kapasiteit"),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return int.tryParse(v) == null ? "Nie 'n nommer nie" : null;
            },
          ),
        ],
      ),
    );
  }
}

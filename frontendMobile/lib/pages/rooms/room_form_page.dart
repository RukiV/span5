import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/idempotency.dart';
import '../../models/building.dart';
import '../../models/campus.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../services/ai_service.dart';
import '../../widgets/inline_searchable_dropdown.dart';
import '../../widgets/view_edit_scaffold.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/ai_suggestions_panel.dart';

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
  late final TextEditingController _codeController;
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
    _codeController = TextEditingController(text: widget.room?.roomCode ?? "");
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
    _codeController.dispose();
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
        roomCode: _codeController.text.trim(),
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
      roomCode: _codeController.text.trim(),
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

  /// Die vorm se huidige veldwaardes vir die AI-konteks.
  Map<String, dynamic> _currentRoomFields() => {
        'room_name': _nameController.text,
        'room_type': _type,
        'room_capacity': _capacityController.text,
        'room_status': 'Operasioneel',
      };

  /// Pas 'n AI-voorstel toe (Tipe/Kapasiteit).
  void _applyRoomGhost(String key, AiSuggestion s) {
    switch (key) {
      case 'room_type':
        final t = Room.normalizeType(s.value);
        if (_types.any((x) => x['value'] == t)) {
          setState(() => _type = t);
        }
        break;
      case 'room_capacity':
        if (int.tryParse(s.value.trim()) != null) {
          setState(() => _capacityController.text = s.value.trim());
        }
        break;
    }
  }

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
      showCancel: false,
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
          AiSuggestionsPanel(
            context: 'room',
            fields: _currentRoomFields(),
            labels: const {
              'room_type': 'Tipe',
              'room_capacity': 'Kapasiteit',
            },
            onUse: (key, s) => _applyRoomGhost(key, s),
          ),
          LabeledFormField(
            label: "Naam",
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            validator: (v) => (v == null || v.trim().isEmpty) ? "Vereis" : null,
          ),
          const SizedBox(height: 20),
          LabeledFormField(
            label: "Lokaal Kode",
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return "Vereis";
              if (v.trim().length > 20) return "Maks 20 karakters";
              return null;
            },
          ),
          const SizedBox(height: 20),
          InlineSearchableDropdown<Building>(
            label: "Gebou",
            hint: "Kies Gebou",
            value: _selectedBuilding,
            items: _allBuildings
                .map((b) => InlineSearchableDropdownItem<Building>(
                    value: b, label: b.name))
                .toList(),
            onChanged: (v) => setState(() => _selectedBuilding = v),
            validator: (v) => v == null ? "Vereis" : null,
          ),
          const SizedBox(height: 20),
          InlineSearchableDropdown<String>(
            label: "Tipe",
            hint: "Kies Tipe",
            value: _type,
            items: _types
                .map((t) => InlineSearchableDropdownItem(
                      value: t['value']!,
                      label: t['label']!,
                    ))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 20),
          LabeledFormField(
            label: "Kapasiteit",
            controller: _capacityController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
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

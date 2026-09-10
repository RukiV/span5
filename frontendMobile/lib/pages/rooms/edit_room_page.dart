import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../models/room.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../core/app_colors.dart';

class EditRoomPage extends StatefulWidget {
  final Room room;
  const EditRoomPage({super.key, required this.room});

  @override
  State<EditRoomPage> createState() => _EditRoomPageState();
}

class _EditRoomPageState extends State<EditRoomPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _capacityController;
  late String _type;
  Building? _selectedBuilding;
  bool _editing = false;
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
    _nameController = TextEditingController(text: widget.room.name);
    _capacityController =
        TextEditingController(text: widget.room.capacity?.toString() ?? "");
    _type = widget.room.type;

    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(_resolveBuilding);
      }
    });
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
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
        if (b.id == widget.room.buildingId) {
          _selectedBuilding = b;
          return;
        }
      }
    }
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

    final updated = widget.room.copyWith(
      name: _nameController.text.trim(),
      type: _type,
      capacity: int.tryParse(_capacityController.text),
      buildingId: _selectedBuilding!.id,
    );

    final success = await CampusService.updateRoom(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder lokaal"),
        content: Text("Is jy seker jy wil '${widget.room.name}' verwyder?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Kanselleer"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Verwyder"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await CampusService.removeRoom(widget.room.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie die lokaal verwyder nie."),
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
        title: Text(
          _editing ? 'Wysig Lokaal' : widget.room.name,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          if (!_editing && UserSession.can('rooms.manage'))
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Wysig',
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnorePointer(
                  ignoring: !_editing,
                  child: Opacity(
                    opacity: _editing ? 1 : 0.6,
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
                        SearchableDropdown<Building>(
                          label: "Gebou",
                          hint: "Kies Gebou",
                          value: _selectedBuilding,
                          items: _allBuildings
                              .map((b) => SearchableDropdownItem<Building>(
                                  value: b, label: b.name))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedBuilding = v),
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
                            return int.tryParse(v) == null
                                ? "Nie 'n nommer nie"
                                : null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (_editing) ...[
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
                          : const Text("OPDATEER",
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
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("KLAAR",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                  ),
                if (UserSession.can('rooms.manage')) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => _confirmDelete(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: const Text("VERWYDER LOKAAL",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import '../../widgets/custom_dropdown.dart';
import '../../widgets/searchable_dropdown.dart';
import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../models/asset_type.dart';
import '../../services/asset_type_service.dart';
import '../../models/campus.dart';
import '../../core/app_colors.dart';
import '../../models/asset.dart';
import '../../services/asset_service.dart';
import '../../models/user_session.dart';

class EditAssetPage extends StatefulWidget {
  final Asset asset;

  const EditAssetPage({super.key, required this.asset});

  @override
  State<EditAssetPage> createState() => _EditAssetPageState();
}

class _EditAssetPageState extends State<EditAssetPage> {
  final _formKey = GlobalKey<FormState>();

  late String name;
  late String serialCode;
  late String brand;
  late bool isFixed;
  late String location;
  late String status;
  late int selectedTypeId;
  late final _serialController = TextEditingController();

  String? selectedCampus;
  String? selectedBuilding;
  String? selectedLocation;

  @override
  void initState() {
    super.initState();
    _serialController.addListener(_enforceSerialPrefix);
    AssetTypeService.fetchTypes();
    final a = widget.asset;
    name = a.name;
    serialCode = a.serialCode;
    _serialController.text = serialCode;
    brand = a.brand;
    isFixed = a.isOutdoor;
    location = a.location;
    selectedTypeId = a.assetTypeId;
    status = a.status;

    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          selectedCampus = CampusService.getCampusNameByRoomId(a.location);
          selectedBuilding = CampusService.getBuildingNameByRoomId(a.location);
          selectedLocation = a.location;
        });
      }
    });
  }

  void _enforceSerialPrefix() {
    final text = _serialController.text;
    if (text.isEmpty) {
      _serialController.text = "AK ";
      _serialController.selection = TextSelection.fromPosition(const TextPosition(offset: 3));
    } else if (!text.startsWith("AK ")) {
      _serialController.text = "AK ";
      _serialController.selection = TextSelection.fromPosition(const TextPosition(offset: 3));
    }
    serialCode = _serialController.text;
  }

  @override
  void dispose() {
    _serialController.removeListener(_enforceSerialPrefix);
    _serialController.dispose();
    super.dispose();
  }

  List<String> get _availableBuildings {
    if (selectedCampus == null) return [];
    final campus = CampusService.getCampusByName(selectedCampus!);
    if (campus == null) return [];
    return campus.buildings.map((b) => b.name).toList();
  }

  List<String> get availableRooms {
    if (selectedBuilding == null) return [];
    final campus = CampusService.getCampusByName(selectedCampus ?? '');
    if (campus == null) return [];
    final building = campus.buildings.where((b) => b.name == selectedBuilding).firstOrNull;
    if (building == null) return [];
    return (building.rooms ?? []).map((r) => '${r.id}:${r.name}').toList();
  }

  Widget _buildCustomTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    bool readOnly = false,
    String? initialValue,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller != null ? null : initialValue,
          readOnly: readOnly,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: "",
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Wysig Bate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  _buildCustomTextField(
                    label: "Naam",
                    hint: "",
                    initialValue: name,
                    onChanged: (v) => name = v,
                    validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),

                  _buildCustomTextField(
                    label: "Serienommer",
                    hint: "",
                    controller: _serialController,
                    onChanged: (v) {
                      serialCode = _serialController.text;
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Vereis";
                      final regex = RegExp(r'^AK [A-Za-z]{2}\d{6}$');
                      if (!regex.hasMatch(v)) {
                        return "Formaat moet AK XX000000 wees (bv. AK MT123456)";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildCustomTextField(
                    label: "Merk",
                    hint: "",
                    initialValue: brand,
                    onChanged: (v) => brand = v,
                  ),
                  const SizedBox(height: 20),

                  ValueListenableBuilder<List<AssetType>>(
                    valueListenable: AssetTypeService.typesNotifier,
                    builder: (context, types, _) {
                      return CustomDropdown<int>(
                        label: "Bate Tipe",
                        hint: "Kies 'n tipe",
                        value: selectedTypeId,
                        items: types.map((t) => DropdownMenuItem<int>(
                          value: t.id,
                          child: Text(t.name),
                        )).toList(),
                        onChanged: (v) => setState(() => selectedTypeId = v ?? selectedTypeId),
                        validator: (v) => v == null ? "Vereis" : null,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  if (UserSession.hasAdminPrivileges)
                    _buildCustomTextField(
                      label: "Bate Kode",
                      hint: "",
                      initialValue: widget.asset.id,
                      readOnly: true,
                      onChanged: (_) {},
                    ),
                  if (UserSession.hasAdminPrivileges)
                    const SizedBox(height: 20),

                  const Text("Buite", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Checkbox(
                    value: isFixed,
                    onChanged: (v) => setState(() => isFixed = v!),
                  ),
                  const SizedBox(height: 20),

                  ValueListenableBuilder<List<Campus>>(
                    valueListenable: CampusService.campusesNotifier,
                    builder: (context, campuses, _) {
                      return SearchableDropdown<String>(
                        label: "Kampus",
                        hint: "Kies 'n kampus",
                        value: selectedCampus,
                        items: campuses
                            .map((c) => SearchableDropdownItem(value: c.name, label: c.name))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedCampus = v;
                            selectedBuilding = null;
                            selectedLocation = null;
                          });
                        },
                        validator: (v) => (v == null) ? "Vereis" : null,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  SearchableDropdown<String>(
                    label: "Gebou",
                    hint: selectedCampus == null ? "Kies eers 'n kampus" : "Kies 'n gebou",
                    value: selectedBuilding,
                    items: _availableBuildings
                        .map((b) => SearchableDropdownItem(value: b, label: b))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedBuilding = v;
                        selectedLocation = null;
                      });
                    },
                    validator: (v) => (v == null) ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),

                  SearchableDropdown<String>(
                    label: "Lokaal",
                    hint: selectedBuilding == null ? "Kies eers 'n gebou" : "Kies 'n lokaal",
                    value: selectedLocation,
                    items: availableRooms.map((r) {
                      final name = r.contains(":") ? r.split(":").last : r;
                      return SearchableDropdownItem(value: r, label: name);
                    }).toList(),
                    onChanged: (v) => setState(() => selectedLocation = v),
                    validator: (v) => (v == null) ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),

                  CustomDropdown<String>(
                    label: "Status",
                    hint: "",
                    value: status,
                    items: [
                      {"value": "active", "label": "Aktief"},
                      {"value": "maintenance", "label": "Onderhoud"},
                      {"value": "retired", "label": "Afgedank"},
                      {"value": "inactive", "label": "Onaktief"},
                    ].map((s) => DropdownMenuItem(
                      value: s["value"] as String,
                      child: Text(s["label"] as String)
                    )).toList(),
                    onChanged: (v) => setState(() => status = v!),
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
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final typeName = AssetTypeService.getTypeName(selectedTypeId);
                            final updated = widget.asset.copyWith(
                              name: name,
                              serialCode: serialCode,
                              brand: brand,
                              category: typeName,
                              assetTypeId: selectedTypeId,
                              location: selectedLocation?.split(":").first ?? "1",
                              status: status,
                              isOutdoor: isFixed,
                              campus: selectedCampus ?? "",
                            );

                            final success = await AssetService.updateAsset(updated);
                            if (!mounted) return;
                            if (success) {
                              if (context.mounted) {
                                Navigator.pop(context, true);
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5E34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Opdateer"),
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

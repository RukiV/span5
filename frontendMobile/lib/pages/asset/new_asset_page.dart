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

class NewAssetPage extends StatefulWidget {
  const NewAssetPage({super.key});

  @override
  State<NewAssetPage> createState() => _NewAssetPageState();
}

class _NewAssetPageState extends State<NewAssetPage> {
  final _formKey = GlobalKey<FormState>();

  // Veranderlikes wat voorheen ontbreek het:
  String name = "";
  String serialCode = "AK ";
  String brand = "";
  final _serialController = TextEditingController(text: "AK ");

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
  String assetCode = "";
  bool isFixed = false;
  String location = "";
  int? selectedTypeId;
  String? selectedCampus;
  String? selectedBuilding;
  String? selectedLocation;
  String status = "active";
  
  @override
  void initState() {
    super.initState();
    _serialController.addListener(_enforceSerialPrefix);
    AssetTypeService.fetchTypes();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    
    // Autofill campus and restrict if not admin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          try {
            selectedCampus = CampusService.campusesNotifier.value
                .firstWhere((c) => c.name == UserSession.userCampus || UserSession.userCampus.contains(c.name))
                .name;
          } catch (_) {
            if (CampusService.campusesNotifier.value.isNotEmpty) {
               selectedCampus = CampusService.campusesNotifier.value.first.name;
            }
          }
        });
      }
    });
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
        title: const Text("Nuwe Bate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        onChanged: (v) => setState(() => selectedTypeId = v),
                        validator: (v) => v == null ? "Vereis" : null,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  if (UserSession.hasAdminPrivileges)
                    _buildCustomTextField(
                      label: "Bate Kode",
                      hint: "Laat leeg vir outomaties",
                      onChanged: (v) => assetCode = v,
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
                            if (selectedTypeId == null) return;
                            final typeName = AssetTypeService.getTypeName(selectedTypeId!);
                            final newAsset = Asset(
                              id: assetCode.isNotEmpty && UserSession.hasAdminPrivileges
                                  ? assetCode
                                  : AssetService.generateUniqueId(typeName, selectedCampus ?? "GEN"),
                              serialCode: serialCode,
                              name: name,
                              brand: brand,
                              category: typeName,
                              assetTypeId: selectedTypeId!,
                              location: selectedLocation?.split(":").first ?? "1",
                              status: status,
                              campus: selectedCampus ?? "",
                            );
                            
                            final success = await AssetService.addAsset(newAsset);
                            if (!mounted) return;
                            if (success) {
                              if (context.mounted) {
                                Navigator.pop(context);
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
                        child: const Text("Stoor"),
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

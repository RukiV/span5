<<<<<<< HEAD
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/location_cascade_picker.dart';
import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../models/asset_type.dart';
import '../../services/asset_type_service.dart';
import '../../models/room.dart';
import '../../core/app_colors.dart';
import '../../models/asset.dart';
import '../../services/asset_service.dart';
import '../../models/user_session.dart';
import '../reporting/scan_page.dart';

class NewAssetPage extends StatefulWidget {
  const NewAssetPage({super.key});

  @override
  State<NewAssetPage> createState() => _NewAssetPageState();
}

class _NewAssetPageState extends State<NewAssetPage> {
  final _formKey = GlobalKey<FormState>();

  // Veranderlikes wat voorheen ontbreek het:
  String name = "";
  String serialCode = "";
  String brand = "";
  final _serialController = TextEditingController();

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }
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

  /// Foutboodskap vir die ligging-kieser, gestel wanneer 'n onvolledige pad
  /// gestoor probeer word.
  String? _locationError;

  int? _campusIdForName(String? name) {
    if (name == null) return null;
    return CampusService.campusesNotifier.value
        .where((c) => c.name == name)
        .firstOrNull
        ?.id;
  }

  /// Die kieser werk met ID's, maar die stoor-logika hieronder verwag steeds die
  /// ou string-vorm (kampusnaam, gebounaam, "lokaalId:lokaalNaam"). Ons vertaal
  /// hier sodat die stoor-pad onveranderd bly.
  void _onLocationChanged(int? campusId, int? buildingId, int? roomId) {
    final campuses = CampusService.campusesNotifier.value;
    final campus = campuses.where((c) => c.id == campusId).firstOrNull;
    final building =
        campus?.buildings.where((b) => b.id == buildingId).firstOrNull;
    final room =
        (building?.rooms ?? const <Room>[]).where((r) => r.id == roomId).firstOrNull;

    setState(() {
      selectedCampus = campus?.name;
      selectedBuilding = building?.name;
      selectedLocation = room == null ? null : '${room.id}:${room.name}';
      if (room != null) _locationError = null;
    });
  }

  /// Skandeer 'n bestaande strepie-/QR-kode op die item en gebruik dit as die
  /// bate se serienommer.
  Future<void> _scanSerial() async {
    final String? code = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    setState(() {
      _serialController.text = code;
      serialCode = code;
    });
  }

  Widget _buildBreadcrumbs() {
    final campuses = CampusService.campusesNotifier.value;
    final campus = campuses.where((c) => c.name == selectedCampus).firstOrNull;
    final building = campus?.buildings.where((b) => b.name == selectedBuilding).firstOrNull;
    final roomName = selectedLocation?.split(":").last;

    String path = campus?.name ?? "Kies Kampus";
    if (building != null) path += " > ${building.name}";
    if (roomName != null) path += " > $roomName";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Nuwe Bate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                _buildBreadcrumbs(),
                const SizedBox(height: 25),
                TextFormField(
                  decoration: _inputDecoration("Naam"),
                  onChanged: (v) => name = v,
                  validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _serialController,
                  decoration: _inputDecoration("Serienommer").copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: AppColors.navy),
                      tooltip: "Skandeer strepie-/QR-kode",
                      onPressed: _scanSerial,
                    ),
                    helperText: "Tik 'n kode (bv. AK MT123456) of skandeer 'n bestaande een.",
                  ),
                  onChanged: (v) => serialCode = v,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Vereis";
                    if (v.trim().length > 20) return "Maks 20 karakters";
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: _inputDecoration("Merk"),
                  onChanged: (v) => brand = v,
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<List<AssetType>>(
                  valueListenable: AssetTypeService.typesNotifier,
                  builder: (context, types, _) {
                    return SearchableDropdown<int>(
                      label: "Bate Tipe",
                      hint: "Kies 'n tipe",
                      value: selectedTypeId,
                      items: types
                          .map((t) => SearchableDropdownItem(value: t.id, label: t.name))
                          .toList(),
                      onChanged: (v) => setState(() => selectedTypeId = v),
                      validator: (v) => v == null ? "Vereis" : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text("Buite", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Checkbox(
                      value: isFixed,
                      activeColor: AppColors.navy,
                      onChanged: (v) => setState(() => isFixed = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LocationCascadePicker(
                  label: "Ligging *",
                  initialCampusId: _campusIdForName(selectedCampus),
                  errorText: _locationError,
                  onChanged: _onLocationChanged,
                ),
                const SizedBox(height: 20),
                SearchableDropdown<String>(
                  label: "Status",
                  hint: "Kies 'n status",
                  value: status,
                  items: const [
                    SearchableDropdownItem(value: "active", label: "Aktief"),
                    SearchableDropdownItem(value: "maintenance", label: "Onderhoud"),
                    SearchableDropdownItem(value: "retired", label: "Afgedank"),
                    SearchableDropdownItem(value: "inactive", label: "Onaktief"),
                  ],
                  onChanged: (v) => setState(() => status = v!),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedLocation == null) {
                        setState(() => _locationError = "Kies 'n volledige ligging");
                        return;
                      }
                      if (_formKey.currentState!.validate()) {
                        if (selectedTypeId == null) return;
                        final typeName = AssetTypeService.getTypeName(selectedTypeId!);
                        final newAsset = Asset(
                          id: AssetService.generateUniqueId(typeName, selectedCampus ?? "GEN"),
                          serialCode: serialCode,
                          name: name,
                          brand: brand,
                          category: typeName,
                          assetTypeId: selectedTypeId!,
                          location: selectedLocation!.split(":").first,
                          status: status,
                          campus: selectedCampus ?? "",
                        );
                        
                        final success = await AssetService.addAsset(newAsset);
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("STOOR BATE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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
=======
import '../../widgets/custom_dropdown.dart';
import '../../widgets/searchable_dropdown.dart';
import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
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
  String serialCode = "";
  String brand = "";
  String assetCode = "";
  bool isFixed = false;
  String location = ""; // Vir handmatige invoer as geen kamers gelaai is nie
  final List<String> categories = ["Meubels", "IT Voorraad", "Elektronika", "Kombuis", "Ander"];

  String? selectedCampus;
  String? selectedBuilding;
  String? selectedLocation;
  String category = "Meubels";
  String status = "active";
  
  @override
  void initState() {
    super.initState();
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
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
                    onChanged: (v) => serialCode = v,
                    validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),

                  _buildCustomTextField(
                    label: "Merk",
                    hint: "",
                    onChanged: (v) => brand = v,
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
                            final newAsset = Asset(
                              id: assetCode.isNotEmpty && UserSession.hasAdminPrivileges
                                  ? assetCode
                                  : AssetService.generateUniqueId(category, selectedCampus ?? "GEN"),
                              serialCode: serialCode,
                              name: name,
                              brand: brand,
                              category: category,
                              assetTypeId: Asset.getCategoryId(category),
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
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

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
                          // Die ligging-kieser is nie 'n FormField nie, so die
                          // volledige pad word hier afsonderlik nagegaan.
                          if (selectedLocation == null) {
                            setState(() => _locationError = "Kies 'n volledige ligging");
                            return;
                          }
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

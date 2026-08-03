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
    CampusService.campusesNotifier.addListener(_onCampusesChanged);

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

  @override
  void dispose() {
    _serialController.removeListener(_enforceSerialPrefix);
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    _serialController.dispose();
    super.dispose();
  }

  /// Wanneer die kampusboom eers ná die eerste bou laai, moet die kieser se
  /// beginligging steeds ingevul word. Moenie die gebruiker se eie keuse
  /// oorskryf as hy reeds 'n nuwe ligging gekies het nie.
  void _onCampusesChanged() {
    if (!mounted) return;
    final original = widget.asset.location;
    final userHasNotChanged = selectedLocation == null || selectedLocation == original;
    setState(() {
      if (userHasNotChanged) {
        selectedCampus = CampusService.getCampusNameByRoomId(original);
        selectedBuilding = CampusService.getBuildingNameByRoomId(original);
        selectedLocation = original;
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

  String? _locationError;

  /// Die bate se `location` is 'n lokaal-ID. Ons soek die pad daarheen op sodat
  /// die kieser met die bestaande ligging oopmaak.
  int? get _initialRoomId => int.tryParse(widget.asset.location);

  int? get _initialBuildingId {
    final roomId = _initialRoomId;
    if (roomId == null) return null;
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        if ((b.rooms ?? const <Room>[]).any((r) => r.id == roomId)) return b.id;
      }
    }
    return null;
  }

  int? get _initialCampusId {
    final roomId = _initialRoomId;
    if (roomId == null) return null;
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        if ((b.rooms ?? const <Room>[]).any((r) => r.id == roomId)) return c.id;
      }
    }
    return null;
  }

  /// Vertaal die kieser se ID's terug na die string-vorm wat die stoor-logika
  /// hieronder steeds verwag.
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
                      return SearchableDropdown<int>(
                        label: "Bate Tipe",
                        hint: "Kies 'n tipe",
                        value: selectedTypeId,
                        items: types
                            .map((t) => SearchableDropdownItem(value: t.id, label: t.name))
                            .toList(),
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

                  LocationCascadePicker(
                    label: "Ligging *",
                    initialCampusId: _initialCampusId,
                    initialBuildingId: _initialBuildingId,
                    initialRoomId: _initialRoomId,
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

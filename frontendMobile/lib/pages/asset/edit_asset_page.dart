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
import '../reporting/scan_page.dart';

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

  Widget _buildBreadcrumbs() {
    final campuses = CampusService.campusesNotifier.value;
    final campus = campuses.where((c) => c.name == selectedCampus).firstOrNull;
    final building = campus?.buildings.where((b) => b.name == selectedBuilding).firstOrNull;
    final roomName = selectedLocation?.contains(":") == true ? selectedLocation?.split(":").last : null;

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
        title: const Text("Wysig Bate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  initialValue: name,
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
                    helperText: "Skandeer 'n bestaande een of tik 'n kode.",
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
                  initialValue: brand,
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
                      onChanged: (v) => setState(() => selectedTypeId = v ?? selectedTypeId),
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
                        final typeName = AssetTypeService.getTypeName(selectedTypeId);
                        final updated = widget.asset.copyWith(
                          name: name,
                          serialCode: serialCode,
                          brand: brand,
                          category: typeName,
                          assetTypeId: selectedTypeId,
                          location: selectedLocation!.split(":").first,
                          status: status,
                          isOutdoor: isFixed,
                          campus: selectedCampus ?? "",
                        );

                        final success = await AssetService.updateAsset(updated);
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context, true);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("OPDATEER BATE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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

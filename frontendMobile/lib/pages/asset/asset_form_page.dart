import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/input_decoration.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import '../../services/asset_service.dart';
import '../../services/asset_type_service.dart';
import '../../services/campus_service.dart';
import '../../widgets/location_breadcrumbs.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/view_edit_scaffold.dart';
import '../reporting/scan_page.dart';

class AssetFormPage extends StatefulWidget {
  final Asset? asset;

  const AssetFormPage({super.key, this.asset});

  @override
  State<AssetFormPage> createState() => _AssetFormPageState();
}

class _AssetFormPageState extends State<AssetFormPage> {
  final _formKey = GlobalKey<FormState>();

  late String name;
  late String serialCode;
  late String brand;
  late bool isOutdoor;
  late String status;
  int? selectedTypeId;
  String? selectedCampus;
  String? selectedBuilding;
  String? selectedLocation;
  String? _locationError;
  late final _serialController = TextEditingController();

  bool get _isCreate => widget.asset == null;

  @override
  void initState() {
    super.initState();
    AssetTypeService.fetchTypes();
    final a = widget.asset;
    name = a?.name ?? "";
    serialCode = a?.serialCode ?? "";
    _serialController.text = serialCode;
    brand = a?.brand ?? "";
    isOutdoor = a?.isOutdoor ?? false;
    status = a?.status ?? "active";
    selectedTypeId = a?.assetTypeId;

    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }

    if (_isCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(_autofillCampus);
        }
      });
    } else {
      CampusService.campusesNotifier.addListener(_onCampusesChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            selectedCampus = CampusService.getCampusNameByRoomId(a!.location);
            selectedBuilding =
                CampusService.getBuildingNameByRoomId(a.location);
            selectedLocation = a.location;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    if (!_isCreate) {
      CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    }
    _serialController.dispose();
    super.dispose();
  }

  void _autofillCampus() {
    if (selectedCampus != null) return;
    try {
      selectedCampus = CampusService.campusesNotifier.value
          .firstWhere((c) =>
              c.name == UserSession.userCampus ||
              UserSession.userCampus.contains(c.name))
          .name;
    } catch (_) {
      if (CampusService.campusesNotifier.value.isNotEmpty) {
        selectedCampus = CampusService.campusesNotifier.value.first.name;
      }
    }
  }

  void _onCampusesChanged() {
    if (!mounted) return;
    final original = widget.asset!.location;
    final userHasNotChanged =
        selectedLocation == null || selectedLocation == original;
    setState(() {
      if (userHasNotChanged) {
        selectedCampus = CampusService.getCampusNameByRoomId(original);
        selectedBuilding = CampusService.getBuildingNameByRoomId(original);
        selectedLocation = original;
      }
    });
  }

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

  int? _campusIdForName(String? name) {
    if (name == null) return null;
    return CampusService.campusesNotifier.value
        .where((c) => c.name == name)
        .firstOrNull
        ?.id;
  }

  int? get _initialRoomId => int.tryParse(widget.asset!.location);

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

  void _onLocationChanged(int? campusId, int? buildingId, int? roomId) {
    final path = CampusService.locationPath(campusId, buildingId, roomId);

    setState(() {
      selectedCampus = path.campus?.name;
      selectedBuilding = path.building?.name;
      selectedLocation =
          path.room == null ? null : '${path.room!.id}:${path.room!.name}';
      if (path.room != null) _locationError = null;
    });
  }

  Widget _breadcrumbs() {
    return LocationBreadcrumbs(path: _breadcrumbPath);
  }

  String get _breadcrumbPath {
    final campuses = CampusService.campusesNotifier.value;
    final campus = campuses.where((c) => c.name == selectedCampus).firstOrNull;
    final building =
        campus?.buildings.where((b) => b.name == selectedBuilding).firstOrNull;
    final roomName = selectedLocation?.contains(":") == true
        ? selectedLocation?.split(":").last
        : null;

    String path = campus?.name ?? "Kies Kampus";
    if (building != null) path += " > ${building.name}";
    if (roomName != null) path += " > $roomName";
    return path;
  }

  Future<void> _save() async {
    if (selectedLocation == null) {
      setState(() => _locationError = "Kies 'n volledige ligging");
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (selectedTypeId == null) return;
    final typeName = AssetTypeService.getTypeName(selectedTypeId!);

    if (_isCreate) {
      final newAsset = Asset(
        id: '',
        serialCode: serialCode,
        name: name,
        brand: brand,
        category: typeName,
        assetTypeId: selectedTypeId!,
        location: selectedLocation!.split(":").first,
        status: status,
        isOutdoor: isOutdoor,
      );
      final success = await AssetService.addAsset(newAsset);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
      }
      return;
    }

    final updated = widget.asset!.copyWith(
      name: name,
      serialCode: serialCode,
      brand: brand,
      category: typeName,
      assetTypeId: selectedTypeId!,
      location: selectedLocation!.split(":").first,
      status: status,
      isOutdoor: isOutdoor,
    );
    final success = await AssetService.updateAsset(updated);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = _isCreate;

    return ViewEditScaffold(
      alwaysEditable: true,
      title: isCreate ? "Nuwe Bate" : "Wysig Bate",
      saveLabel: isCreate ? "STOOR BATE" : "OPDATEER BATE",
      showSaveSpinner: false,
      saveLetterSpacing: 1,
      showCancel: false,
      formKey: _formKey,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _breadcrumbs(),
          const SizedBox(height: 25),
          TextFormField(
            initialValue: isCreate ? null : name,
            decoration: appInputDecoration(label: "Naam"),
            onChanged: (v) => name = v,
            validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _serialController,
            decoration: appInputDecoration(label: "Serienommer").copyWith(
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: AppColors.navy),
                tooltip: "Skandeer strepie-/QR-kode",
                onPressed: _scanSerial,
              ),
              helperText: isCreate
                  ? "Tik 'n kode (bv. AK MT123456) of skandeer 'n bestaande een."
                  : "Skandeer 'n bestaande een of tik 'n kode.",
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
            initialValue: isCreate ? null : brand,
            decoration: appInputDecoration(label: "Handelsmerk"),
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
                    .map((t) =>
                        SearchableDropdownItem(value: t.id, label: t.name))
                    .toList(),
                onChanged: (v) =>
                    setState(() => selectedTypeId = v ?? selectedTypeId),
                validator: (v) => v == null ? "Vereis" : null,
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text("Buite",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Checkbox(
                value: isOutdoor,
                activeColor: AppColors.navy,
                onChanged: (v) => setState(() => isOutdoor = v!),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LocationCascadePicker(
            label: "Ligging *",
            initialCampusId:
                _isCreate ? _campusIdForName(selectedCampus) : _initialCampusId,
            initialBuildingId: _isCreate ? null : _initialBuildingId,
            initialRoomId: _isCreate ? null : _initialRoomId,
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
        ],
      ),
    );
  }
}

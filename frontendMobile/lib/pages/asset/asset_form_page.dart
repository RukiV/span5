import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/asset_code_formatter.dart';
import '../../core/idempotency.dart';
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
import '../../widgets/inline_searchable_dropdown.dart';
import '../../widgets/view_edit_scaffold.dart';
import '../../widgets/ai_suggestions_panel.dart';
import '../../widgets/ghost_overlay.dart';
import '../../core/suggestion_translations.dart';
import '../../services/ai_service.dart';
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
  String? _idempotencyKey;
  late final _serialController = TextEditingController();
  late final _nameController = TextEditingController(text: "");
  late final _brandController = TextEditingController(text: "");

  /// AI-voorstelle (spookteks) wat tans op die vorm van toepassing is.
  Map<String, AiSuggestion> _ghosts = {};

  /// Wanneer 'n gesuggereerde lokaal aangewend word, dryf dit die kieser vroet.
  (int?, int?, int?)? _appliedLocation;

  static const _statusItems = [
    InlineSearchableDropdownItem(value: "active", label: "Aktief"),
    InlineSearchableDropdownItem(value: "maintenance", label: "Onderhoud"),
    InlineSearchableDropdownItem(value: "retired", label: "Afgedank"),
    InlineSearchableDropdownItem(value: "inactive", label: "Onaktief"),
  ];

  bool get _isCreate => widget.asset == null;

  @override
  void initState() {
    super.initState();
    AssetTypeService.fetchTypes();
    final a = widget.asset;
    name = a?.name ?? "";
    _nameController.text = name;
    serialCode = a?.serialCode ?? "";
    _serialController.text = serialCode;
    brand = a?.brand ?? "";
    _brandController.text = brand;
    isOutdoor = a?.isOutdoor ?? false;
    status = a?.status ?? "active";
    selectedTypeId = a?.assetTypeId;

    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }

    if (_isCreate) {
      _idempotencyKey = Idempotency.generate();
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
    _nameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  void _autofillCampus() {
    if (selectedCampus != null) return;
    try {
      selectedCampus = CampusService.campusesNotifier.value
          .firstWhere((c) => c.id == UserSession.locationId)
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

  /// Die vorm se huidige veldwaardes vir die AI-konteks.
  Map<String, String> _currentAssetFields() {
    final typeName = selectedTypeId != null
        ? AssetTypeService.getTypeName(selectedTypeId!)
        : "";
    return {
      'asset_name': name,
      'asset_type': typeName,
      'room': selectedLocation?.split(":").last ?? "",
      'asset_brand': brand,
      'asset_status': _statusLabel(),
    };
  }

  String _statusLabel() => _statusItems
      .firstWhere((i) => i.value == status, orElse: () => _statusItems.first)
      .label;

  String? _statusValueForLabel(String label) {
    final norm = label.trim().toLowerCase();
    for (final item in _statusItems) {
      if (item.label.trim().toLowerCase() == norm || item.value == norm) {
        return item.value;
      }
    }
    return null;
  }

  /// Pas 'n voorstel toe — via 'n spookknoppie ✓ of die paneel se "Gebruik".
  void _applyAssetGhost(String key, AiSuggestion s) {
    switch (key) {
      case 'asset_name':
        _nameController.text = s.value;
        name = s.value;
        break;
      case 'asset_brand':
        _brandController.text = s.value;
        brand = s.value;
        break;
      case 'asset_type':
        if (s.id != null) {
          selectedTypeId = s.id;
        } else {
          final match = AssetTypeService.typesNotifier.value
              .where((t) => t.name.toLowerCase() == s.value.toLowerCase())
              .firstOrNull;
          if (match != null) selectedTypeId = match.id;
        }
        break;
      case 'asset_status':
        final v = _statusValueForLabel(s.value);
        if (v != null) status = v;
        break;
      case 'room':
        _applyRoomGhost(s.value);
        return;
    }
    setState(() {});
  }

  /// Soek die gesuggereerde lokaal op en dryf die kieser daarnatoe.
  void _applyRoomGhost(String roomName) {
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        for (final r in (b.rooms ?? [])) {
          if (r.name.trim().toLowerCase() == roomName.trim().toLowerCase()) {
            setState(() => _appliedLocation = (c.id, b.id, r.id));
            _onLocationChanged(c.id, b.id, r.id);
            return;
          }
        }
      }
    }
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
    final path = CampusService.findLocationPath(campusId, buildingId, roomId);

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
    final campusId = _campusIdForName(selectedCampus);
    final campus = campuses.where((c) => c.id == campusId).firstOrNull;
    final buildingId = campus?.buildings
        .where((b) => b.name == selectedBuilding)
        .firstOrNull
        ?.id;
    final roomId = int.tryParse(selectedLocation?.split(":").first ?? "");

    return LocationBreadcrumbs.buildLocationPath(
        campusId: campusId, buildingId: buildingId, roomId: roomId);
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
      final success = await AssetService.addAsset(newAsset,
          idempotencyKey: _idempotencyKey);
      if (!mounted) return;
      if (success) {
        _idempotencyKey = Idempotency.generate();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kon nie die bate byvoeg nie."),
            backgroundColor: AppColors.errorRed,
          ),
        );
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie opdateer nie."),
          backgroundColor: AppColors.errorRed,
        ),
      );
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Naam",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.navy)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: withSuggestionGhost(
                  appInputDecoration(),
                  ghost: _ghosts['asset_name']?.value,
                  active: name.isEmpty && _ghosts['asset_name'] != null,
                  onAccept: _ghosts['asset_name'] != null
                      ? () =>
                          _applyAssetGhost('asset_name', _ghosts['asset_name']!)
                      : null,
                ),
                onChanged: (v) {
                  name = v;
                  setState(() {});
                },
                validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Serienommer",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.navy)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _serialController,
                decoration: appInputDecoration().copyWith(
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner,
                        color: AppColors.navy),
                    tooltip: "Skandeer strepie-/QR-kode",
                    onPressed: _scanSerial,
                  ),
                ),
                inputFormatters: [AssetCodeFormatter()],
                onChanged: (v) => serialCode = v,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Vereis";
                  if (v.trim().length > 20) return "Maks 20 karakters";
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Handelsmerk",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.navy)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _brandController,
                decoration: withSuggestionGhost(
                  appInputDecoration(),
                  ghost: _ghosts['asset_brand']?.value,
                  active: brand.isEmpty && _ghosts['asset_brand'] != null,
                  onAccept: _ghosts['asset_brand'] != null
                      ? () => _applyAssetGhost(
                          'asset_brand', _ghosts['asset_brand']!)
                      : null,
                ),
                onChanged: (v) {
                  brand = v;
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<List<AssetType>>(
            valueListenable: AssetTypeService.typesNotifier,
            builder: (context, types, _) {
              final typeEmpty = selectedTypeId == null;
              final typeGhost = _ghosts['asset_type'];
              return InlineSearchableDropdown<int>(
                label: "Bate Tipe",
                hint: typeEmpty && typeGhost != null
                    ? translateSuggestion('asset_type', typeGhost.value)
                    : "Kies 'n tipe",
                value: selectedTypeId,
                items: types
                    .map((t) => InlineSearchableDropdownItem(
                        value: t.id, label: t.name))
                    .toList(),
                trailing: typeEmpty && typeGhost != null
                    ? SuggestionAcceptCheck(
                        onTap: () => _applyAssetGhost('asset_type', typeGhost),
                      )
                    : null,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocationCascadePicker(
                label: "Ligging *",
                showBreadcrumb: false,
                trailBar: _breadcrumbs(),
                trailBarSpacing: 0,
                initialCampusId: _appliedLocation?.$1 ??
                    (_isCreate
                        ? _campusIdForName(selectedCampus)
                        : _initialCampusId),
                initialBuildingId: _appliedLocation?.$2 ??
                    (_isCreate ? null : _initialBuildingId),
                initialRoomId:
                    _appliedLocation?.$3 ?? (_isCreate ? null : _initialRoomId),
                errorText: _locationError,
                onChanged: _onLocationChanged,
              ),
              if (selectedLocation == null && _ghosts['room'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Lokaal-voorstel",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy),
                        ),
                      ),
                      Text(
                        _ghosts['room']!.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SuggestionAcceptCheck(
                        onTap: () => _applyRoomGhost(_ghosts['room']!.value),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          InlineSearchableDropdown<String>(
            label: "Status",
            hint: "Kies 'n status",
            value: status,
            items: _statusItems,
            trailing: () {
              final s = _ghosts['asset_status'];
              if (s == null) return null;
              final v = _statusValueForLabel(s.value);
              return v != null && v != status
                  ? SuggestionAcceptCheck(
                      onTap: () => _applyAssetGhost('asset_status', s),
                    )
                  : null;
            }(),
            onChanged: (v) => setState(() => status = v!),
          ),
          const SizedBox(height: 16),
          AiSuggestionsPanel(
            context: 'asset',
            fields: _currentAssetFields(),
            labels: const {
              'asset_name': 'Naam',
              'asset_type': 'Tipe',
              'room': 'Ligging',
              'asset_brand': 'Handelsmerk',
              'asset_status': 'Status',
            },
            onSuggestionsChanged: (s) => setState(() => _ghosts = s),
            onUse: (key, s) => _applyAssetGhost(key, s),
          ),
        ],
      ),
    );
  }
}

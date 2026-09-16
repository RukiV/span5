import '../../widgets/searchable_dropdown.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/ai_suggestions_panel.dart';
import '../../widgets/mobile_ghost_overlay.dart';
import '../../core/suggestion_translations.dart';
import '../../services/ai_service.dart';
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
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();

  /// AI-voorstelle (spookteks) wat tans op die vorm van toepassing is.
  Map<String, AiSuggestion> _ghosts = {};

  /// Wanneer 'n gesuggereerde lokaal aangewend word, dryf dit die kieser vroet.
  (int?, int?, int?)? _appliedLocation;

  @override
  void dispose() {
    _serialController.dispose();
    _nameController.dispose();
    _brandController.dispose();
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

  /// Die vorm se huidige veldwaardes vir die AI-konteks.
  Map<String, String> _currentAssetFields() {
    final typeName = selectedTypeId != null
        ? AssetTypeService.getTypeName(selectedTypeId!)
        : "";
    return {
      'asset_name': name,
      'asset_type': typeName, // backend kies per id, maar "gevul" word hier bepaal
      'room': selectedLocation?.split(":").last ?? "",
      'asset_brand': brand,
      'asset_status': _statusLabel(),
    };
  }

  String _statusLabel() =>
      statusItems.firstWhere((i) => i.value == status,
          orElse: () => statusItems.first).label;

  static const statusItems = [
    SearchableDropdownItem(value: "active", label: "Aktief"),
    SearchableDropdownItem(value: "maintenance", label: "Onderhoud"),
    SearchableDropdownItem(value: "retired", label: "Afgedank"),
    SearchableDropdownItem(value: "inactive", label: "Onaktief"),
  ];

  /// Vertaal 'n backend-statusvoorstel (bv. "Instandhouding") na die vorm se waarde.
  String? _statusValueForLabel(String label) {
    final norm = label.trim().toLowerCase();
    for (final item in statusItems) {
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
      for (final b in (c.buildings ?? [])) {
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
                  controller: _nameController,
                  decoration: withSuggestionGhost(
                    _inputDecoration("Naam"),
                    ghost: _ghosts['asset_name']?.value,
                    active: name.isEmpty,
                    onAccept: () =>
                        _applyAssetGhost('asset_name', _ghosts['asset_name']!),
                  ),
                  onChanged: (v) {
                    name = v;
                    setState(() {});
                  },
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
                  controller: _brandController,
                  decoration: withSuggestionGhost(
                    _inputDecoration("Handelsmerk"),
                    ghost: _ghosts['asset_brand']?.value,
                    active: brand.isEmpty,
                    onAccept: () =>
                        _applyAssetGhost('asset_brand', _ghosts['asset_brand']!),
                  ),
                  onChanged: (v) {
                    brand = v;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<List<AssetType>>(
                  valueListenable: AssetTypeService.typesNotifier,
                  builder: (context, types, _) {
                    final typeEmpty = selectedTypeId == null;
                    final typeGhost = _ghosts['asset_type'];
                    return SearchableDropdown<int>(
                      label: "Bate Tipe",
                      hint: typeEmpty && typeGhost != null
                          ? translateSuggestion('asset_type', typeGhost.value)
                          : "Kies 'n tipe",
                      value: selectedTypeId,
                      items: types
                          .map((t) => SearchableDropdownItem(value: t.id, label: t.name))
                          .toList(),
                      trailing: typeEmpty && typeGhost != null
                          ? SuggestionAcceptCheck(
                              onTap: () => _applyAssetGhost('asset_type', typeGhost),
                            )
                          : null,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocationCascadePicker(
                      initialCampusId: _appliedLocation?.$1 ?? _campusIdForName(selectedCampus),
                      initialBuildingId: _appliedLocation?.$2,
                      initialRoomId: _appliedLocation?.$3,
                      errorText: _locationError,
                      onChanged: _onLocationChanged,
                    ),
                    if (selectedLocation == null &&
                        _ghosts['room'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0E8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE7D9C7)),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Lokaal-voorstel",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                              ),
                            ),
                            Text(
                              _ghosts['room']!.value,
                              style: const TextStyle(
                                fontSize: 13, fontStyle: FontStyle.italic,
                                color: Color(0xFF7B7670),
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
                SearchableDropdown<String>(
                  label: "Status",
                  hint: "Kies 'n status",
                  value: status,
                  items: statusItems,
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
                const SizedBox(height: 24),
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

import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/inline_searchable_dropdown.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/header_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../core/app_colors.dart';
import '../../services/asset_type_service.dart';
import 'scan_page.dart';
import 'location_page.dart';

import '../../services/report_service.dart';
import '../../services/ai_service.dart';
import '../../services/image_service.dart';
import '../../services/camera_service.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../models/campus.dart';
import '../../models/asset.dart';
import '../../services/asset_service.dart';
import '../../services/room_service.dart';

class NewReportPage extends StatefulWidget {
  final String? prefillSerialCode;

  const NewReportPage({super.key, this.prefillSerialCode});

  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  String? selectedCampus;
  String? selectedBuilding;
  String? selectedLocation;
  int? _selectedCampusId;
  int? _selectedBuildingId;
  int? _selectedRoomId;

  /// Kaartligging (opsioneel) wat in die LocationPage of via die foon se GPS
  /// gekies word. Die kieser (terrein/gebou/lokaal) en die koördinate kan
  /// saam bestaan — net een van die twee word vir indiening benodig.
  LatLng? _mapLocation;
  Uint8List? _mapScreenshot;

  /// Of die probleem buite 'n lokaal is (ja: 'n terrein of kaartpunt is
  /// voldoende as ligging; nee: 'n volle terrein/gebou/lokaal-pad word vereis).
  /// Null totdat die gebruiker kies of 'n bate geskandeer word.
  bool? _isOutdoor;

  /// Wanneer die gebruiker die ligging (of werksoort/buite-lokaal) self wil
  /// invul: begin AAN by 'n leë vorm, word AF ná 'n bate-skandering wat die
  /// ligging korrek invul. AAN wys die kieser + Werksoort + Buite Lokaal.
  bool _correctingLocation = true;

  /// Gekandeerde lokaal wat wag op die kampusboom om te laai.
  int? _pendingRoomId;
  String? selectedCategory;
  String? selectedPriority;
  static const int _maxPhotos = 3;
  final List<File> _photoFiles = [];
  bool _isAutoFilling = false;
  bool _isAiCreating = false;

  /// Of die vorm tans 'n geskandeerde/opgesoekte bate se gegewens wys. Wys die
  /// "Verander Foutkaartjie?"-knoppie en die wysig-inskiet op die ligging-
  /// kieser; word teruggestel wanneer die soekveld skoongemaak word.
  bool _assetResolved = false;
  @override
  void initState() {
    super.initState();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    AssetTypeService.fetchTypes();
    if (widget.prefillSerialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        serialController.text = widget.prefillSerialCode!;
        _autoFillFromCode(widget.prefillSerialCode!);
      });
    }
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    serialController.dispose();
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  /// Sodra die kampusboom laai, vul 'n voorheen-gekandeerde lokaal asnog in.
  void _onCampusesChanged() {
    if (!mounted) return;
    if (_pendingRoomId != null) {
      setState(() => _resolveRoomPath(_pendingRoomId));
    }
  }

  bool _isSubmitting = false;
  Asset? _resolvedAsset;

  Future<void> _autoFillFromCode(String serialCode) async {
    setState(() => _isAutoFilling = true);
    final asset = await AssetService.getAssetBySerialCode(serialCode);
    if (!mounted) return;
    if (asset == null) {
      setState(() => _isAutoFilling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Geen bate gevind met hierdie kode nie"),
            backgroundColor: AppColors.warningOrange),
      );
      return;
    }

    setState(() {
      _resolveRoomPath(int.tryParse(asset.location));
      selectedCategory = _mapAssetCategory(asset.category);
      _isOutdoor = asset.isOutdoor;
      _correctingLocation = false;
      _isAutoFilling = false;
      _assetResolved = true;
      _resolvedAsset = asset;
    });
  }

  /// Bepaal die volledige pad (terrein/gebou/lokaal) direk vanaf die
  /// lokaal-ID van die bate — sonder die onbetroubare naam-omkeer wat
  /// "Onbekende Kampus" gegee het as die kampusboom nog nie gelaai was nie.
  void _resolveRoomPath(int? roomId) {
    if (roomId == null) {
      _pendingRoomId = null;
      _selectedCampusId = null;
      _selectedBuildingId = null;
      _selectedRoomId = null;
      selectedCampus = null;
      selectedBuilding = null;
      selectedLocation = null;
      return;
    }
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        for (final r in b.rooms ?? const <Room>[]) {
          if (r.id == roomId) {
            _selectedCampusId = c.id;
            _selectedBuildingId = b.id;
            _selectedRoomId = r.id;
            selectedCampus = c.name;
            selectedBuilding = b.name;
            selectedLocation = '${r.id}:${r.name}';
            _pendingRoomId = null;
            return;
          }
        }
      }
    }
    // Boom nog nie gelaai nie — onthou dit en vul aan sodra Campuses arriveer.
    _pendingRoomId = roomId;
    _selectedRoomId = roomId;
    selectedLocation = '$roomId:${CampusService.getRoomName('$roomId')}';
  }

  String _mapAssetCategory(String assetCategory) {
    switch (assetCategory) {
      case "Meubels":
        return "Onderhoud";
      case "IT Toerusting":
        return "Herstel";
      case "Sekuriteit":
        return "Onderhoud";
      default:
        return "Onderhoud";
    }
  }

  String? _locationError;

  /// Stoor die ID's én die naam-vorm wat die stoor-logika verwag.
  void _onLocationChanged(int? campusId, int? buildingId, int? roomId) {
    final campuses = CampusService.campusesNotifier.value;
    final campus = campuses.where((c) => c.id == campusId).firstOrNull;
    final building =
        campus?.buildings.where((b) => b.id == buildingId).firstOrNull;
    final room = (building?.rooms ?? const <Room>[])
        .where((r) => r.id == roomId)
        .firstOrNull;

    setState(() {
      _selectedCampusId = campusId;
      _selectedBuildingId = buildingId;
      _selectedRoomId = roomId;
      _pendingRoomId = null;
      selectedCampus = campus?.name;
      selectedBuilding = building?.name;
      selectedLocation = room == null ? null : '${room.id}:${room.name}';
      _locationError = null;
    });
  }

  /// Scan 'n lokaal se QR-kode en vul die volle terrein/gebou/lokaal-pad
  /// outomaties in as 'n alternatief vir die handmatige kieser.
  Future<void> _scanRoom() async {
    final String? scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanPage(isLocation: true),
      ),
    );
    if (scannedCode == null || !mounted) return;

    final room = await RoomService.getRoomByCode(scannedCode.trim());
    if (!mounted) return;
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Geen lokaal gevind met hierdie kode nie"),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }

    _onLocationChanged(room.locationId, room.buildingId, room.id);
    setState(() => _isOutdoor = false);
  }

  /// Skep 'n AI-konsep vanaf die huidige beskrywingstek. Die gebruiker bly op
  /// die vorm — die konsep wag daarna in die Voorgestelde-Werksopdragte-goedkeuringsry.
  Future<void> _handleAiDraft() async {
    final desc = descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tik eers 'n beskrywing in om 'n AI-konsep te skep."),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }
    setState(() => _isAiCreating = true);
    final draft = await AiService.createDraft(desc);
    if (!mounted) return;
    setState(() => _isAiCreating = false);
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie AI-konsep skep nie. Probeer weer."),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("AI-konsep geskep — wag op goedkeuring in Voorgestelde Werksopdragte."),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  /// Opsommingsblok bokant die kieser-veld: wys die gekose
  /// terrein/gebou/lokaal as 'n gestapelde lys en bied die opsionele
  /// koördinate (kaart/GPS) aan.
  Widget _buildLocationBlock() {
    final roomName = selectedLocation?.split(':').last;
    final hasCoords = _mapLocation != null;
    final coordsText = hasCoords
        ? '${_mapLocation!.latitude.toStringAsFixed(6)}, ${_mapLocation!.longitude.toStringAsFixed(6)}'
        : null;

    return GestureDetector(
      // Tik op die boks skakel die wysig-modus hieronder aan/af.
      onTap: () => setState(() => _correctingLocation = !_correctingLocation),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (UserSession.can('faults.view')) ...[
              _locationRow(
                  Icons.priority_high_outlined, 'Prioriteit', selectedPriority),
              const SizedBox(height: 6),
            ],
            _locationRow(Icons.school_outlined, 'Terrein', selectedCampus),
            const SizedBox(height: 6),
            _locationRow(Icons.apartment_outlined, 'Gebou', selectedBuilding),
            const SizedBox(height: 6),
            _locationRow(Icons.meeting_room_outlined, 'Lokaal', roomName),
            const SizedBox(height: 6),
            _locationRow(Icons.wb_sunny_outlined, 'Buite Lokaal',
                _isOutdoor == null ? null : (_isOutdoor! ? 'Ja' : 'Nee')),
            const SizedBox(height: 6),
            _locationRow(
                Icons.handyman_outlined, 'Werksoort', selectedCategory),
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey[300], thickness: 1),
            const SizedBox(height: 10),
            if (hasCoords)
              Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 16, color: AppColors.successGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      coordsText!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_location_alt,
                        size: 18, color: AppColors.gold),
                    tooltip: "Verander kaartligging",
                    visualDensity: VisualDensity.compact,
                    onPressed: _pickMapLocation,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: AppColors.errorRed),
                    tooltip: "Verwyder kaartligging",
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _mapLocation = null;
                      _mapScreenshot = null;
                      _locationError = null;
                    }),
                  ),
                ],
              )
            else if (_assetResolved)
              // "Verander Foutkaartjie?" staan alleen (ná 'n bate-skandering
              // of -opsoek); die kaart-kieser is nou 'n "Kies op Kaart"-
              // knoppie langs die Ja/Nee-knoppies in die korreksie-afdeling.
              // By 'n leë vorm is daar niks om te verander nie, dus geen
              // knoppie nie.
              _smallActionButton(
                Icons.edit_location_alt,
                "Verander Foutkaartjie?",
                () =>
                    setState(() => _correctingLocation = !_correctingLocation),
              ),
            if (_locationError != null) ...[
              const SizedBox(height: 8),
              Text(_locationError!,
                  style:
                      const TextStyle(color: AppColors.errorRed, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy)),
        Expanded(
          child: Text(
            value ?? '-',
            style: TextStyle(
                fontSize: 13,
                color: value == null ? Colors.grey[400] : Colors.grey[800]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _smallActionButton(IconData icon, String label, VoidCallback onTap,
      {bool active = false}) {
    final fg = active ? Colors.white : AppColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color:
              active ? AppColors.gold : AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
          ],
        ),
      ),
    );
  }

  /// Opskrif & Beskrywing — staan bo-aan die vorm sodat die gebruiker eers die
  /// fout self beskryf en dan die ligging nasien.
  Widget _buildTitleDescriptionBox() {
    return _TitleDescriptionBox(
      titleController: titleController,
      descController: descController,
      photoFiles: _photoFiles,
      onAddPhoto: _pickPhoto,
      onRemovePhoto: (i) => setState(() => _photoFiles.removeAt(i)),
      titleValidator: (v) {
        if ((v == null || v.trim().isEmpty) &&
            descController.text.trim().isEmpty) {
          return "Voeg 'n opskrif of beskrywing by";
        }
        return null;
      },
      descValidator: (v) {
        if ((v == null || v.trim().isEmpty) &&
            titleController.text.trim().isEmpty) {
          return "Voeg 'n opskrif of beskrywing by";
        }
        if (v != null && v.length > 100) {
          return "Beskrywing mag nie meer as 100 karakters wees nie";
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Nuwe Foutkaartjie",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: serialController,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      final code = serialController.text.trim();
                      if (code.isNotEmpty) _autoFillFromCode(code);
                      // Sluit die sleutelbord outomaties wanneer gesoek word.
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    inputFormatters: [_AssetCodeFormatter()],
                    decoration: InputDecoration(
                      hintText: "AK MT000001",
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 150 / 255),
                          fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.gold),
                      suffixIcon: _isAutoFilling
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : serialController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white70),
                                  onPressed: () => setState(() {
                                    serialController.clear();
                                    _assetResolved = false;
                                  }),
                                )
                              : null,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 30 / 255),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                HeaderIconAction(
                  icon: Icons.search,
                  tooltip: "Soek getikte kode",
                  onTap: () {
                    final code = serialController.text.trim();
                    if (code.isNotEmpty) _autoFillFromCode(code);
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
                HeaderIconAction(
                  icon: Icons.qr_code_scanner,
                  tooltip: "Skandeer QR-kode",
                  onTap: () async {
                    final String? scannedCode = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ScanPage()));
                    if (scannedCode != null) {
                      final trimmed = scannedCode.trim();
                      setState(() => serialController.text = trimmed);
                      await _autoFillFromCode(trimmed);
                    }
                  },
                ),

                if (UserSession.can('ai.use'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: _isAiCreating ? null : _handleAiDraft,
                      icon: _isAiCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: const Text("AI-konsep"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                // Lys-knoppie net vir FK/Admin ('n asset-leesreg) — studente
                // sien slegs Soek + QR en kry nie konfidentiële bate-lysse nie.
                if (UserSession.can('assets.view'))
                  HeaderIconAction(
                    icon: Icons.list_alt_outlined,
                    tooltip: "Kies uit ligging",
                    onTap: _pickAssetFromLocation,
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Foutkaartjie Nasien",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.navy)),
              const SizedBox(height: 8),
              _buildLocationBlock(),
              const SizedBox(height: 24),
              _buildTitleDescriptionBox(),
              if (_correctingLocation) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("Buite Lokaal:",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy)),
                    const SizedBox(width: 2),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text("Nee")),
                        ButtonSegment(value: true, label: Text("Ja")),
                      ],
                      selected: {_isOutdoor ?? false},
                      onSelectionChanged: (s) => setState(() {
                        _isOutdoor = s.first;
                        _locationError = null;
                        // Buite-lokaal = Nee beteken binne: die kaartpunt (en
                        // sy skermgreep) is nie meer van toepassing nie.
                        if (_isOutdoor == false) {
                          _mapLocation = null;
                          _mapScreenshot = null;
                        }
                      }),
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                          visualDensity: VisualDensity.compact),
                    ),
                    _smallActionButton(
                      Icons.map_outlined,
                      "Kies op Kaart",
                      () {
                        setState(() => _isOutdoor = true);
                        _pickMapLocation();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LocationCascadePicker(
                  initialCampusId: _selectedCampusId,
                  initialBuildingId: _selectedBuildingId,
                  initialRoomId: _selectedRoomId,
                  label: "Waargeneemde Ligging",
                  editing: _assetResolved,
                  showBreadcrumb: false,
                  onChanged: _onLocationChanged,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanRoom,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text("Skandeer Lokaal"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InlineSearchableDropdown<String>(
                  label: "Werksoort",
                  hint: "Kies Werksoort",
                  value: selectedCategory,
                  items: ["Onderhoud", "Herstel", "Inspeksie", "Installasie"]
                      .map((e) => SearchableDropdownItem(value: e, label: e))
                      .toList(),
                  onChanged: (v) => setState(() => selectedCategory = v),
                ),
              ],
              if (UserSession.can('faults.view')) ...[
                const SizedBox(height: 24),
                InlineSearchableDropdown<String>(
                  label: "Prioriteit",
                  hint: "Kies Prioriteit",
                  value: selectedPriority,
                  items: ["Laag", "Medium", "Hoog"]
                      .map((e) => SearchableDropdownItem(value: e, label: e))
                      .toList(),
                  onChanged: (v) => setState(() {
                    if (v != null) selectedPriority = v;
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              child: const Text("STUUR FOUTKAARTJIE",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
                // Die ligging-kieser is nie 'n FormField nie, so die
                // ligging word hier afsonderlik nagegaan. 'n Kaartpunt
                // buite enige terrein het reeds 'n spesifieke fout van
                // _resolveCampusFromPoint — moenie dit oorskryf nie.
                // (Met die ALLOW_OFF_CAMPUS-dev-vlag is 'n terreinvrye
                // kaartpunt geldig en word dit hier toegelaat.)
                final hasPath = selectedLocation != null;
                final hasCoords = _mapLocation != null;
                if (hasCoords &&
                    _selectedCampusId == null &&
                    !LocationPage.allowOffCampus) {
                  setState(() => _locationError =
                      "Punt val nie binne 'n terrein nie — kies 'n ander plek");
                  return;
                }
                if (_correctingLocation) {
                  if (_isOutdoor == true) {
                    if (!hasPath && !hasCoords && _selectedCampusId == null) {
                      setState(() => _locationError =
                          "Kies 'n ligging (terrein of kaart)");
                      return;
                    }
                  } else if (!hasPath && !hasCoords) {
                    setState(() => _locationError =
                        "Kies 'n volledige ligging of kies 'n ligging op die kaart");
                    return;
                  }
                } else if (!hasPath && !hasCoords) {
                  // Geen bate is geskandeer (of die ligging is leeg) —
                  // onthul die korreksie-afdeling sodat die gebruiker kan kies.
                  setState(() {
                    _correctingLocation = true;
                    _locationError = "Kies 'n ligging";
                  });
                  return;
                }
                if (!_formKey.currentState!.validate()) {
                  return;
                }

                int? finalAssetIdInt;
                String? finalAssetSerialCode;
                final serial = serialController.text.trim();
                final Asset? asset = (_resolvedAsset != null &&
                        _resolvedAsset!.serialCode == serial)
                    ? _resolvedAsset
                    : (serial.isNotEmpty
                        ? await AssetService.getAssetBySerialCode(serial)
                        : null);
                if (serial.isNotEmpty && asset == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Kon nie bate met kode vind nie — kontroleer die kode"),
                        backgroundColor: AppColors.errorRed),
                    );
                  }
                  return;
                }
                if (asset != null) {
                  finalAssetIdInt = int.tryParse(asset.id);
                  finalAssetSerialCode = asset.serialCode;
                }

                final String finalAssetId = finalAssetIdInt?.toString() ?? "0";

                final String roomId = selectedLocation != null
                    ? selectedLocation!.split(":").first
                    : "";

                int? resolvedLocationId;
                int? resolvedBuildingId;
                if (selectedCampus != null) {
                  final campus = CampusService.getCampusByName(selectedCampus!);
                  if (campus != null) {
                    resolvedLocationId = campus.id;
                    if (selectedBuilding != null) {
                      final building = campus.buildings
                          .where((b) => b.name == selectedBuilding)
                          .firstOrNull;
                      resolvedBuildingId = building?.id;
                    }
                  }
                }

                final newReport = Report(
                  id: "0",
                  assetId: finalAssetId,
                  assetSerialCode: finalAssetSerialCode,
                  location: roomId,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  category: selectedCategory ?? "Onderhoud",
                  priority: UserSession.can('faults.view')
                      ? (selectedPriority ?? "Medium")
                      : "Laag",
                  phase: "Ontvang",
                  user: UserSession.userId.toString(),
                  timestamp: DateTime.now(),
                  locationId: resolvedLocationId,
                  buildingId: resolvedBuildingId,
                  latitude: _mapLocation?.latitude,
                  longitude: _mapLocation?.longitude,
                  isOutdoor: _isOutdoor ?? false,
                  rawStatus: null,
                );

                try {
                  // 1. Skep die kaartjie eers sodat ons sy id het om
                  //    fotos aan te koppel (parent_type 'ticket').
                  final created = await ReportService.addReport(newReport);
                  if (!mounted) return;
                  if (created == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Fout met stoor. Probeer weer."),
                            backgroundColor: AppColors.errorRed),
                      );
                    }
                    return;
                  }

                  // 2. Laai elke foto op, gekoppel aan die nuwe kaartjie.
                  final faultId = int.tryParse(created.id);
                  int failedUploads = 0;
                  if (faultId != null) {
                    // Kaart-skermgreep word as 'n ekstra kaartjiefoto gelaai.
                    if (_mapScreenshot != null) {
                      final screenshotId = await ImageService.uploadImageBytes(
                        _mapScreenshot!,
                        parentId: faultId,
                        parentType: 'ticket',
                        filename: 'kaart_$faultId.png',
                      );
                      if (screenshotId == null) failedUploads++;
                    }
                    for (final photo in _photoFiles) {
                      final imageId = await ImageService.uploadImage(
                        photo,
                        parentId: faultId,
                        parentType: 'ticket',
                      );
                      if (imageId == null) failedUploads++;
                    }
                  }

                  if (!mounted || !context.mounted) return;
                  if (failedUploads > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Kaartjie gestoor, maar $failedUploads foto('s) kon nie oplaai nie."),
                        backgroundColor: AppColors.warningOrange,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Foutkaartjie suksesvol gestuur!"),
                          backgroundColor: AppColors.successGreen),
                    );
                  }
                  Navigator.pop(context, true);
                } catch (e) {
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Netwerkfout: $e"),
                          backgroundColor: AppColors.errorRed),
                    );
                  }
                }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
  Future<void> _pickMapLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const LocationPage()),
    );
    if (result == null || !mounted) return;
    final loc = result['location'] as LatLng?;
    if (loc == null) return;
    setState(() {
      _mapLocation = loc;
      _mapScreenshot = result['screenshot'] as Uint8List?;
    });
    _resolveCampusFromPoint(loc);
  }

  /// Bepaal die naaste terrein (binne sy radius) vir die gekose kaartpunt,
  /// sodat location_id steeds geldig is. 'n Kaartpunt skrap die gekose
  /// bou/lokaal altyd — net die terrein word behou.
  void _resolveCampusFromPoint(LatLng point) {
    Campus? nearest;
    double? bestDistance;
    for (final c in CampusService.campusesNotifier.value) {
      final d = Geolocator.distanceBetween(
        c.location.latitude,
        c.location.longitude,
        point.latitude,
        point.longitude,
      );
      if (d <= c.radius && (bestDistance == null || d < bestDistance)) {
        bestDistance = d;
        nearest = c;
      }
    }
    if (nearest == null) {
      if (LocationPage.allowOffCampus) {
        // Dev-modus: van-kampus is toegelaat — die terrein bly leeg, maar
        // die kaartpunt/skermgreep word behou sonder 'n fout.
        setState(() {
          _selectedCampusId = null;
          selectedCampus = null;
          _locationError = null;
        });
        return;
      }
      setState(() {
        _selectedCampusId = null;
        selectedCampus = null;
        _locationError =
            "Punt val nie binne 'n terrein nie — kies 'n ander plek";
      });
      return;
    }
    final resolved = nearest;
    setState(() {
      _selectedBuildingId = null;
      _selectedRoomId = null;
      selectedBuilding = null;
      selectedLocation = null;
      _selectedCampusId = resolved.id;
      selectedCampus = resolved.name;
      _locationError = null;
    });
  }

  /// "Bate identifiseer uit plek uit": lys die bates wat in die waargeneemde
  /// lokaal geregistreer is, sodat die bate gekies kan word sonder om te
  /// skandeer. Slegs vir gebruikers met 'n asset-leesreg (studente mag nie
  /// konfidentiële bate-lysse sien nie).
  Future<void> _pickAssetFromLocation() async {
    final roomId = int.tryParse(selectedLocation?.split(':').first ?? '');
    if (roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Kies eers 'n waargeneemde ligging (lokaal)"),
            backgroundColor: AppColors.warningOrange),
      );
      return;
    }
    if (AssetService.assetsNotifier.value.isEmpty) {
      await AssetService.fetchAssets();
    }
    if (!mounted) return;
    final assets = AssetService.assetsNotifier.value
        .where((a) => a.location == '$roomId')
        .toList();
    if (assets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Geen bates geregistreer in hierdie lokaal nie"),
            backgroundColor: AppColors.warningOrange),
      );
      return;
    }
    final search = ValueNotifier<String>('');
    final asset = await showModalBottomSheet<Asset>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: search,
        builder: (context, query, _) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? assets
              : assets
                  .where((a) =>
                      a.serialCode.toLowerCase().contains(q) ||
                      a.name.toLowerCase().contains(q))
                  .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Kies 'n bate uit hierdie lokaal",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy)),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        onChanged: (v) => search.value = v,
                        decoration: InputDecoration(
                          hintText: "Soek serial of naam...",
                          hintStyle:
                              TextStyle(color: Colors.grey[500], fontSize: 14),
                          prefixIcon: const Icon(Icons.search,
                              size: 20, color: AppColors.navy),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
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
                            borderSide: const BorderSide(
                                color: AppColors.gold, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text("Geen bates pas by jou soektog nie",
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final a = filtered[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.qr_code_2,
                                  color: AppColors.gold),
                              title: Text(a.serialCode,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              subtitle: Text(a.name),
                              onTap: () => Navigator.pop(context, a),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    search.dispose();
    if (asset == null || !mounted) return;
    setState(() => serialController.text = asset.serialCode);
    await _autoFillFromCode(asset.serialCode);
  }

  /// Voeg 'n foto by: laat die gebruiker eers kies of hy die kamera of die
  /// galery wil gebruik (een kamer-ikoon), en voeg dan die gekose foto by.
  Future<void> _pickPhoto() async {
    if (_photoFiles.length >= _maxPhotos) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.navy),
                title: const Text("Neem foto"),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.navy),
                title: const Text("Kies uit galery"),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final photo = source == ImageSource.camera
        ? await CameraService.takePhoto()
        : await CameraService.pickFromGallery();
    if (photo != null && mounted) {
      setState(() => _photoFiles.add(photo));
    }
  }
}

/// Een boks wat Opskrif en Beskrywing kombineer: 'n enkel-lyn opskrif, 'n dun
/// skeidingslyn, en 'n multi-lyn beskrywing. Enter in die opskrif spring na
/// die beskrywing; die rand word goud wanneer een van die twee gefokus is.
/// Fotos word binne-in die boks vertoon, deur 'n skeidingslyn van die
/// beskrywing geskei, en tik op 'n duimnael maak 'n zoombare popup oop.
class _TitleDescriptionBox extends StatefulWidget {
  final TextEditingController titleController;
  final TextEditingController descController;
  final List<File> photoFiles;

  /// Maak 'n keuse-dialoog oop (kamera of galery) en voeg die foto by.
  final VoidCallback? onAddPhoto;
  final ValueChanged<int>? onRemovePhoto;
  final String? Function(String?)? titleValidator;
  final String? Function(String?)? descValidator;

  const _TitleDescriptionBox({
    required this.titleController,
    required this.descController,
    this.photoFiles = const [],
    this.onAddPhoto,
    this.onRemovePhoto,
    this.titleValidator,
    this.descValidator,
  });

  @override
  State<_TitleDescriptionBox> createState() => _TitleDescriptionBoxState();
}

class _TitleDescriptionBoxState extends State<_TitleDescriptionBox> {
  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_onFocusChanged);
    _descFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    final focused = _titleFocus.hasFocus || _descFocus.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onFocusChanged);
    _titleFocus.dispose();
    _descFocus.removeListener(_onFocusChanged);
    _descFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Opskrif & Beskrywing",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.navy)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? AppColors.gold : Colors.grey[300]!,
              width: _focused ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              TextFormField(
                controller: widget.titleController,
                focusNode: _titleFocus,
                maxLines: 1,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                onFieldSubmitted: (_) => _descFocus.requestFocus(),
                validator: widget.titleValidator,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  hintText: "Opskrif",
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey[300]),
              Stack(
                children: [
                  TextFormField(
                    controller: widget.descController,
                    focusNode: _descFocus,
                    maxLines: 3,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    validator: widget.descValidator,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      hintText: "Beskrywing van probleem...",
                      hintStyle:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                      contentPadding: const EdgeInsets.only(
                          left: 15, right: 145, top: 12, bottom: 12),
                    ),
                  ),
                  if (widget.onAddPhoto != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _photoActionButton(
                        Icons.photo_camera_outlined,
                        "Voeg foto by (kamera/galery)",
                        widget.onAddPhoto!,
                      ),
                    ),
                ],
              ),
              if (widget.photoFiles.isNotEmpty) ...[
                Divider(height: 1, thickness: 1, color: Colors.grey[300]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < widget.photoFiles.length; i++)
                        Stack(
                          children: [
                            InkWell(
                              onTap: () => _viewPhoto(widget.photoFiles[i], i),
                              borderRadius: BorderRadius.circular(6),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(widget.photoFiles[i],
                                    height: 52, width: 52, fit: BoxFit.cover),
                              ),
                            ),
                            if (widget.onRemovePhoto != null)
                              Positioned(
                                right: -5,
                                top: -5,
                                child: InkWell(
                                  onTap: () => widget.onRemovePhoto!(i),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                        color: AppColors.errorRed,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoActionButton(IconData icon, String tooltip, VoidCallback onTap,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color ?? Colors.grey[700], size: 24),
          ),
        ),
      ),
    );
  }

  /// Klein popup om 'n foto te bekyk — zoom in/uit deur te kneep (pinch).
  void _viewPhoto(File file, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Center(child: Image.file(file, fit: BoxFit.contain)),
            ),
            if (widget.onRemovePhoto != null)
              Positioned(
                left: 4,
                bottom: 4,
                child: InkWell(
                  onTap: () {
                    widget.onRemovePhoto!(index);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              top: 4,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formateer 'n batekode terwyl jy tik: hoofletters, en 'n spasie word tussen
/// die 2de en 3de letter ingevoeg wanneer die kode met "AK" begin
/// (bv. `akmt000014` → `AK MT000014`). Ander formate word net ge-uppercase.
class _AssetCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase();
    String text = raw;
    if (raw.length >= 3 &&
        raw.startsWith('AK') &&
        raw[2] != ' ' &&
        raw[2] != '-') {
      text = 'AK ${raw.substring(2)}';
    }
    if (text == newValue.text) return newValue;
    final base = newValue.selection.baseOffset;
    final delta = text.length - newValue.text.length;
    final caret = base > 2 ? base + delta : base;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret.clamp(0, text.length)),
    );
  }
}

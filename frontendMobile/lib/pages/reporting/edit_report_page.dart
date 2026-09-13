import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../core/input_decoration.dart';
import '../../services/campus_service.dart';
import '../../services/report_service.dart';
import '../../services/camera_service.dart';
import '../../services/image_service.dart';
import '../../services/room_service.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/location_breadcrumbs.dart';
import '../../widgets/location_cascade_picker.dart';
import 'scan_page.dart';
import 'location_page.dart';

class EditReportPage extends StatefulWidget {
  final Report report;

  const EditReportPage({super.key, required this.report});

  @override
  State<EditReportPage> createState() => _EditReportPageState();
}

class _EditReportPageState extends State<EditReportPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _category;
  late String _priority;
  late String _status;
  String? _rawStatus;
  String? _selectedCampus;
  String? _selectedBuilding;
  String? _selectedLocation;
  int? _selectedCampusId;
  int? _selectedBuildingId;
  bool _isLoading = false;

  static const int _maxPhotos = 3;
  List<int> _existingImageIds = [];
  final Set<int> _removedImageIds = {};
  final List<File> _newPhotos = [];
  bool _imagesLoading = true;

  LatLng? _mapPoint;

  final List<String> _categories = [
    "Onderhoud",
    "Herstel",
    "Inspeksie",
    "Installasie"
  ];
  final List<String> _priorities = ["Laag", "Medium", "Hoog"];
  final List<String> _statuses = ["Ontvang", "Besig", "Voltooi", "Geweier"];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.report.title);
    _descriptionController =
        TextEditingController(text: widget.report.description);
    _category = _categories.contains(widget.report.category)
        ? widget.report.category
        : "Onderhoud";
    _priority = widget.report.priority;
    _status = widget.report.phase;
    _rawStatus = widget.report.rawStatus;
    _selectedCampus =
        CampusService.getCampusNameByRoomId(widget.report.location);
    _selectedBuilding =
        CampusService.getBuildingNameByRoomId(widget.report.location);
    _selectedCampusId = _initialCampusId;
    _selectedBuildingId = _initialBuildingId;
    _selectedLocation = widget.report.location;
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    _loadImages();
    _loadMapPoint();
  }

  // Map die UI-status (vertoon) terug na die rou backend-status wanneer die
  // gebruiker dit self verander. As dit nie verander word nie, bly die rou
  // status (rawStatus) onaangeraak sodat 'n opdatering nie die status afskaal nie.
  String _displayToRawStatus(String display) {
    switch (display) {
      case 'Ontvang':
        return 'Wag';
      case 'Besig':
        return 'Besig';
      case 'Voltooi':
        return 'Opgelos';
      case 'Geweier':
        return 'Gesluit';
      default:
        return 'Wag';
    }
  }

  // Haal die bestaande kaartligging vir die kaartjie op.
  Future<void> _loadMapPoint() async {
    if (widget.report.latitude != null && widget.report.longitude != null) {
      if (mounted) {
        setState(() => _mapPoint =
            LatLng(widget.report.latitude!, widget.report.longitude!));
      }
      return;
    }
    final mappointId = widget.report.mappointId;
    if (mappointId == null) return;
    try {
      final response = await ApiClient().client.get('/mappoint/$mappointId');
      if (response.statusCode == 200) {
        final lat = (response.data['latitude'] as num?)?.toDouble();
        final lng = (response.data['longitude'] as num?)?.toDouble();
        if (mounted && lat != null && lng != null) {
          setState(() => _mapPoint = LatLng(lat, lng));
        }
      }
    } catch (e) {
      debugPrint("Kon nie kaartligging laai nie: $e");
    }
  }

  Future<void> _pickMapLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPage(
          initialLocation: _mapPoint ?? LocationPage.defaultLocation,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final loc = result['location'] as LatLng?;
    if (loc == null) return;
    setState(() => _mapPoint = loc);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    super.dispose();
  }

  /// Wanneer die kampusboom eers ná die eerste bou laai, moet die kieser se
  /// beginligging steeds ingevul word. Moenie die gebruiker se eie keuse
  /// oorskryf as hy reeds 'n nuwe ligging gekies het nie.
  void _onCampusesChanged() {
    if (!mounted) return;
    final original = widget.report.location;
    final userHasNotChanged =
        _selectedLocation == null || _selectedLocation == original;
    setState(() {
      if (userHasNotChanged) {
        _selectedCampus = CampusService.getCampusNameByRoomId(original);
        _selectedBuilding = CampusService.getBuildingNameByRoomId(original);
        _selectedCampusId = _initialCampusId;
        _selectedBuildingId = _initialBuildingId;
        _selectedLocation = original;
      }
    });
  }

  Future<void> _loadImages() async {
    final faultId = int.tryParse(widget.report.id);
    if (faultId == null) {
      if (mounted) setState(() => _imagesLoading = false);
      return;
    }
    final ids = await ImageService.getImagesForParent('ticket', faultId);
    if (mounted) {
      setState(() {
        _existingImageIds = ids;
        _imagesLoading = false;
      });
    }
  }

  /// Die verslag se `location` is 'n lokaal-ID; ons soek die pad daarheen op
  /// sodat die kieser met die bestaande ligging oopmaak.
  int? get _initialRoomId => int.tryParse(widget.report.location);

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

  /// Vertaal die kieser se ID's na die string-vorm wat [_saveChanges] verwag.
  void _onLocationChanged(int? campusId, int? buildingId, int? roomId) {
    final path = CampusService.findLocationPath(campusId, buildingId, roomId);

    setState(() {
      _selectedCampusId = campusId;
      _selectedBuildingId = buildingId;
      _selectedCampus = path.campus?.name;
      _selectedBuilding = path.building?.name;
      _selectedLocation =
          path.room == null ? null : '${path.room!.id}:${path.room!.name}';
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
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String roomId = _selectedLocation ?? widget.report.location;
    if (roomId.contains(":")) {
      roomId = roomId.split(":").first;
    }

    int? resolvedLocationId = _selectedCampusId;
    int? resolvedBuildingId = _selectedBuildingId;

    final updatedReport = widget.report.copyWith(
      title: _titleController.text,
      description: _descriptionController.text,
      category: _category,
      priority: _priority,
      phase: _status,
      rawStatus: _rawStatus,
      location: roomId,
      locationId: resolvedLocationId,
      buildingId: resolvedBuildingId,
      latitude: _mapPoint?.latitude,
      longitude: _mapPoint?.longitude,
    );

    final success = await ReportService.updateReport(updatedReport);

    // Fotos word apart hanteer (ImageAssetLink, parent_type 'ticket').
    // Slegs nadat die opdatering suksesvol was - enige foto-jaartree word
    // NOOIT uitgevoer as die stoor misluk nie.
    List<String> photoFailures = [];
    if (success) {
      final faultId = int.tryParse(widget.report.id);
      for (final id in _removedImageIds) {
        if (!await ImageService.deleteImage(id)) photoFailures.add('verwyder');
      }
      if (faultId != null) {
        for (final photo in _newPhotos) {
          if (await ImageService.uploadImage(photo,
                  parentId: faultId, parentType: 'ticket') ==
              null) {
            photoFailures.add('opgelaai');
          }
        }
      }
      _removedImageIds.clear();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(photoFailures.isEmpty
                ? "Foutkaartjie suksesvol opgedateer"
                : "Foutkaartjie opgedateer, maar sommige fotos kon nie verwerk word nie"),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Kon nie foutkaartjie opdateer nie"),
              backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Widget _buildBreadcrumbs() {
    final campus = _selectedCampus ?? "Onbekende Kampus";
    final building = _selectedBuilding ?? "Onbekende Gebou";
    String room = "Onbekende Lokaal";

    if (_selectedLocation != null) {
      if (_selectedLocation!.contains(':')) {
        room = _selectedLocation!.split(':').last;
      } else {
        room = CampusService.getRoomName(_selectedLocation!);
      }
    }

    return LocationBreadcrumbs(path: "$campus > $building > $room");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Wysig Kaartjie #${widget.report.id}"),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBreadcrumbs(),
                    _buildTextField("Titel", _titleController),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _buildDropdown(
                                "Werksoort",
                                _category,
                                _categories,
                                (val) => setState(() => _category = val!))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildDropdown(
                                "Prioriteit",
                                _priority,
                                _priorities,
                                (val) => setState(() => _priority = val!))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDropdown(
                        "Status",
                        _status,
                        _statuses,
                        (val) => setState(() {
                              _status = val!;
                              _rawStatus = _displayToRawStatus(val);
                            })),
                    const SizedBox(height: 20),
                    LocationCascadePicker(
                      label: "Ligging *",
                      initialCampusId: _initialCampusId,
                      initialBuildingId: _initialBuildingId,
                      initialRoomId: _initialRoomId,
                      trailing: IconButton(
                        icon: const Icon(Icons.qr_code_scanner,
                            color: AppColors.navy),
                        tooltip: "Skandeer Lokaal",
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.all(10),
                        ),
                        onPressed: _scanRoom,
                      ),
                      onChanged: _onLocationChanged,
                    ),
                    const SizedBox(height: 20),
                    _buildMapSection(),
                    const SizedBox(height: 20),
                    _buildTextField("Beskrywing", _descriptionController,
                        maxLines: 5),
                    const SizedBox(height: 16),
                    _buildPhotoSection(),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("OPDATEER",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Kaartligging (Opsioneel)",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
                fontSize: 13)),
        const SizedBox(height: 8),
        if (_mapPoint == null)
          InkWell(
            onTap: _pickMapLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.map_outlined, color: AppColors.gold),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text("Kies 'n presiese ligging op die kaart",
                          style: TextStyle(fontSize: 14))),
                  Text("KIES OP KAART",
                      style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.successGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${_mapPoint!.latitude.toStringAsFixed(6)}, ${_mapPoint!.longitude.toStringAsFixed(6)}",
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_location_alt,
                      size: 18, color: AppColors.gold),
                  tooltip: "Verander kaartligging",
                  onPressed: _pickMapLocation,
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.errorRed),
                  tooltip: "Verwyder kaartligging",
                  onPressed: () => setState(() => _mapPoint = null),
                ),
              ],
            ),
          ),
      ],
    );
  }

//checkmark for room asset scanning and barcode scanning
  Widget _buildPhotoSection() {
    final baseUrl = ApiClient().client.options.baseUrl;
    final visibleExisting = _existingImageIds
        .where((id) => !_removedImageIds.contains(id))
        .toList();
    final total = visibleExisting.length + _newPhotos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Foto's (maks $_maxPhotos)",
            style:
                TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        if (_imagesLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in visibleExisting)
                _photoThumb(
                  child: Image.network(
                    '$baseUrl/image/$id/file',
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      height: 80,
                      width: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  onRemove: () => setState(() => _removedImageIds.add(id)),
                ),
              for (int i = 0; i < _newPhotos.length; i++)
                _photoThumb(
                  child: Image.file(_newPhotos[i],
                      height: 80, width: 80, fit: BoxFit.cover),
                  onRemove: () => setState(() => _newPhotos.removeAt(i)),
                ),
              if (total < _maxPhotos)
                InkWell(
                  onTap: () async {
                    final photo = await CameraService.takePhoto();
                    if (photo != null) {
                      setState(() => _newPhotos.add(photo));
                    }
                  },
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.grey, size: 30),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _photoThumb({required Widget child, required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
        Positioned(
          right: 0,
          top: 0,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                  color: AppColors.errorRed, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
                fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: appInputDecoration(),
          validator: (value) =>
              value == null || value.isEmpty ? "Verpligtend" : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return SearchableDropdown<String>(
      label: label,
      hint: "Kies $label",
      value: value,
      items:
          items.map((e) => SearchableDropdownItem(value: e, label: e)).toList(),
      onChanged: onChanged,
    );
  }
}

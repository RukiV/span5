import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../services/campus_service.dart';
import '../../services/report_service.dart';
import '../../services/camera_service.dart';
import '../../services/image_service.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/location_cascade_picker.dart';

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
  String? _selectedCampus;
  String? _selectedBuilding;
  String? _selectedLocation;
  bool _isLoading = false;

  static const int _maxPhotos = 3;
  List<int> _existingImageIds = [];
  final Set<int> _removedImageIds = {};
  final List<File> _newPhotos = [];
  bool _imagesLoading = true;

  final List<String> _categories = ["Instandhouding", "Herstelwerk", "Opgradering", "Ander"];
  final List<String> _priorities = ["Laag", "Medium", "Hoog"];
  final List<String> _statuses = ["Ontvang", "Besig", "Voltooi", "Geweier"];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.report.title);
    _descriptionController = TextEditingController(text: widget.report.description);
    _category = _categories.contains(widget.report.category) ? widget.report.category : "Ander";
    _priority = widget.report.priority;
    _status = widget.report.phase;
    _selectedCampus = CampusService.getCampusNameByRoomId(widget.report.location);
    _selectedBuilding = CampusService.getBuildingNameByRoomId(widget.report.location);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    _loadImages();
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
    final userHasNotChanged = _selectedLocation == null || _selectedLocation == original;
    setState(() {
      if (userHasNotChanged) {
        _selectedCampus = CampusService.getCampusNameByRoomId(original);
        _selectedBuilding = CampusService.getBuildingNameByRoomId(original);
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
    final campuses = CampusService.campusesNotifier.value;
    final campus = campuses.where((c) => c.id == campusId).firstOrNull;
    final building =
        campus?.buildings.where((b) => b.id == buildingId).firstOrNull;
    final room =
        (building?.rooms ?? const <Room>[]).where((r) => r.id == roomId).firstOrNull;

    setState(() {
      _selectedCampus = campus?.name;
      _selectedBuilding = building?.name;
      _selectedLocation = room == null ? null : '${room.id}:${room.name}';
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String roomId = _selectedLocation ?? widget.report.location;
    if (roomId.contains(":")) {
      roomId = roomId.split(":").first;
    }

    int? resolvedLocationId;
    int? resolvedBuildingId;
    if (_selectedCampus != null) {
      final campus = CampusService.getCampusByName(_selectedCampus!);
      if (campus != null) {
        resolvedLocationId = campus.id;
        if (_selectedBuilding != null) {
          final building = campus.buildings.where((b) => b.name == _selectedBuilding).firstOrNull;
          resolvedBuildingId = building?.id;
        }
      }
    }

    final updatedReport = widget.report.copyWith(
      title: _titleController.text,
      description: _descriptionController.text,
      category: _category,
      priority: _priority,
      phase: _status,
      location: roomId,
      locationId: resolvedLocationId,
      buildingId: resolvedBuildingId,
    );

    final success = await ReportService.updateReport(updatedReport);

    // Fotos word apart hanteer (ImageAssetLink, parent_type 'ticket'):
    // verwyder gemerkte fotos, laai dan nuwes op teen die bestaande kaartjie.
    final faultId = int.tryParse(widget.report.id);
    for (final id in _removedImageIds) {
      await ImageService.deleteImage(id);
    }
    if (faultId != null) {
      for (final photo in _newPhotos) {
        await ImageService.uploadImage(photo, parentId: faultId, parentType: 'ticket');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foutkaartjie suksesvol opgedateer"), backgroundColor: AppColors.successGreen),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kon nie foutkaartjie opdateer nie"), backgroundColor: AppColors.errorRed),
        );
      }
    }
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
                    _buildTextField("Titel", _titleController),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildDropdown("Kategorie", _category, _categories, (val) => setState(() => _category = val!))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDropdown("Prioriteit", _priority, _priorities, (val) => setState(() => _priority = val!))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDropdown("Status", _status, _statuses, (val) => setState(() => _status = val!)),
                    const SizedBox(height: 20),
                    LocationCascadePicker(
                      label: "Ligging *",
                      initialCampusId: _initialCampusId,
                      initialBuildingId: _initialBuildingId,
                      initialRoomId: _initialRoomId,
                      onChanged: _onLocationChanged,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField("Beskrywing", _descriptionController, maxLines: 5),
                    const SizedBox(height: 16),
                    _buildPhotoSection(),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.terracotta,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("OPDATEER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
//checkmark for room asset scanning and barcode scanning
  Widget _buildPhotoSection() {
    final baseUrl = ApiClient().client.options.baseUrl;
    final visibleExisting = _existingImageIds.where((id) => !_removedImageIds.contains(id)).toList();
    final total = visibleExisting.length + _newPhotos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Foto's (maks $_maxPhotos)", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        if (_imagesLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
                    height: 80, width: 80, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      height: 80, width: 80, color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  onRemove: () => setState(() => _removedImageIds.add(id)),
                ),
              for (int i = 0; i < _newPhotos.length; i++)
                _photoThumb(
                  child: Image.file(_newPhotos[i], height: 80, width: 80, fit: BoxFit.cover),
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
                    height: 80, width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.grey, size: 30),
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
          right: 0, top: 0,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
          validator: (value) => value == null || value.isEmpty ? "Verpligtend" : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return SearchableDropdown<String>(
      label: label,
      hint: "Kies $label",
      value: value,
      items: items.map((e) => SearchableDropdownItem(value: e, label: e)).toList(),
      onChanged: onChanged,
    );
  }
}

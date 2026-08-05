import 'dart:io';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/location_cascade_picker.dart';
import 'package:flutter/material.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../core/app_colors.dart';
import 'scan_page.dart';

import '../../services/report_service.dart';
import '../../services/image_service.dart';
import '../../services/camera_service.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../services/asset_service.dart';

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
  String selectedCategory = "";
  String selectedPriority = "Medium";
  static const int _maxPhotos = 3;
  final List<File> _photoFiles = [];
  bool _isAutoFilling = false;
  @override
  void initState() {
    super.initState();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    if (UserSession.hasAdminPrivileges) {
      selectedCategory = "Instandhouding";
    }
    if (widget.prefillSerialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        serialController.text = widget.prefillSerialCode!;
        _autoFillFromCode(widget.prefillSerialCode!);
      });
    }
  }

  @override
  void dispose() {
    serialController.dispose();
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  Future<void> _autoFillFromCode(String serialCode) async {
    setState(() => _isAutoFilling = true);
    final asset = await AssetService.getAssetBySerialCode(serialCode);
    if (!mounted) return;
    if (asset == null) {
      setState(() => _isAutoFilling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Geen bate gevind met hierdie kode nie"), backgroundColor: AppColors.warningOrange),
      );
      return;
    }

    final campusName = CampusService.getCampusNameByRoomId(asset.location);
    final buildingName = CampusService.getBuildingNameByRoomId(asset.location);
    final roomName = CampusService.getRoomName(asset.location);

    String? formattedRoom;
    if (asset.location.isNotEmpty) {
      formattedRoom = "${asset.location}:$roomName";
    }

    setState(() {
      selectedCampus = campusName;
      selectedBuilding = buildingName;
      selectedLocation = formattedRoom;
      selectedCategory = _mapAssetCategory(asset.category);
      _isAutoFilling = false;
    });
  }

  String _mapAssetCategory(String assetCategory) {
    switch (assetCategory) {
      case "Meubels": return "Instandhouding";
      case "IT Toerusting": return "Herstelwerk";
      case "Sekuriteit": return "Instandhouding";
      default: return "Ander";
    }
  }

  String? _locationError;

  int? _campusIdForName(String? name) {
    if (name == null) return null;
    return CampusService.campusesNotifier.value
        .where((c) => c.name == name)
        .firstOrNull
        ?.id;
  }

  int? _buildingIdForName(String? campusName, String? buildingName) {
    if (campusName == null || buildingName == null) return null;
    final campus = CampusService.getCampusByName(campusName);
    return campus?.buildings.where((b) => b.name == buildingName).firstOrNull?.id;
  }

  /// `selectedLocation` word as "lokaalId:lokaalNaam" gestoor.
  int? _roomIdFromFormatted(String? formatted) {
    if (formatted == null) return null;
    return int.tryParse(formatted.split(':').first);
  }

  /// Vertaal die kieser se ID's na die string-vorm wat die stoor-logika verwag.
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
    if (selectedCampus == null) return const SizedBox.shrink();

    String path = selectedCampus!;
    if (selectedBuilding != null) {
      path += " > $selectedBuilding";
      if (selectedLocation != null) {
        final roomName = selectedLocation!.split(':').last;
        path += " > $roomName";
      }
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text("Nuwe Foutkaartjie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(),
                _buildAssetInput(),
                const SizedBox(height: 20),

                if (UserSession.hasAdminPrivileges)
                  Row(
                    children: [
                      Expanded(
                        child: SearchableDropdown<String>(
                          label: "Kategorie *",
                          hint: "Kies Kategorie",
                          value: selectedCategory.isNotEmpty ? selectedCategory : null,
                          items: ["Instandhouding", "Herstelwerk", "Opgradering", "Ander"]
                              .map((e) => SearchableDropdownItem(value: e, label: e)).toList(),
                          onChanged: (v) => setState(() { if (v != null) selectedCategory = v; }),
                          validator: (v) => v == null ? "Kategorie word vereis" : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSimpleDropdown("Prioriteit *", selectedPriority, ["Laag", "Medium", "Hoog"], (v) => setState(() => selectedPriority = v))),
                    ],
                  )
                else
                  SearchableDropdown<String>(
                    label: "Kategorie *",
                    hint: "Kies Kategorie",
                    value: selectedCategory.isNotEmpty ? selectedCategory : null,
                    items: ["Instandhouding", "Herstelwerk", "Opgradering", "Ander"]
                        .map((e) => SearchableDropdownItem(value: e, label: e)).toList(),
                    onChanged: (v) => setState(() { if (v != null) selectedCategory = v; }),
                    validator: (v) => v == null ? "Kategorie word vereis" : null,
                  ),

                const SizedBox(height: 20),

                LocationCascadePicker(
                  label: "Ligging *",
                  initialCampusId: _campusIdForName(selectedCampus),
                  initialBuildingId: _buildingIdForName(selectedCampus, selectedBuilding),
                  initialRoomId: _roomIdFromFormatted(selectedLocation),
                  errorText: _locationError,
                  onChanged: _onLocationChanged,
                ),

                const SizedBox(height: 20),

                _buildCustomTextField(
                  label: "Opskrif",
                  hint: "Onderwerp (bv. Gebreekte Kraan)",
                  controller: titleController,
                ),
                const SizedBox(height: 20),

                _buildCustomTextField(
                  label: "Beskrywing van Probleem *",
                  hint: "Beskryf die probleem in detail...",
                  controller: descController,
                  maxLines: 3,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Beskrywing word vereis";
                    if (v.length > 100) return "Beskrywing mag nie meer as 100 karakters wees nie";
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                _buildPhotoSection(),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Die ligging-kieser is nie 'n FormField nie, so die
                      // volledige pad word hier afsonderlik nagegaan.
                      if (selectedLocation == null) {
                        setState(() => _locationError = "Kies 'n volledige ligging");
                        return;
                      }
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }

                      int? finalAssetIdInt;
                      String? finalAssetSerialCode;
                      if (serialController.text.isNotEmpty) {
                        final asset = await AssetService.getAssetBySerialCode(serialController.text);
                        if (asset != null) {
                          finalAssetIdInt = int.tryParse(asset.id);
                          finalAssetSerialCode = asset.serialCode;
                        }
                      }

                      final String finalAssetId = finalAssetIdInt?.toString() ?? "0";

                      String roomId = "1";
                      if (selectedLocation != null && selectedLocation!.contains(":")) {
                        roomId = selectedLocation!.split(":").first;
                      }

                      int? resolvedLocationId;
                      int? resolvedBuildingId;
                      if (selectedCampus != null) {
                        final campus = CampusService.getCampusByName(selectedCampus!);
                        if (campus != null) {
                          resolvedLocationId = campus.id;
                          if (selectedBuilding != null) {
                            final building = campus.buildings.where((b) => b.name == selectedBuilding).firstOrNull;
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
                        category: selectedCategory,
                        priority: UserSession.hasAdminPrivileges ? selectedPriority : "Medium",
                        phase: "Ontvang",
                        user: UserSession.userId.toString(),
                        timestamp: DateTime.now(),
                        locationId: resolvedLocationId,
                        buildingId: resolvedBuildingId,
                      );

                      try {
                        // 1. Skep die kaartjie eers sodat ons sy id het om
                        //    fotos aan te koppel (parent_type 'ticket').
                        final created = await ReportService.addReport(newReport);
                        if (!mounted) return;
                        if (created == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Fout met stoor. Probeer weer."), backgroundColor: AppColors.errorRed),
                            );
                          }
                          return;
                        }

                        // 2. Laai elke foto op, gekoppel aan die nuwe kaartjie.
                        final faultId = int.tryParse(created.id);
                        int failedUploads = 0;
                        if (faultId != null) {
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
                              content: Text("Kaartjie gestoor, maar $failedUploads foto('s) kon nie oplaai nie."),
                              backgroundColor: AppColors.warningOrange,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Foutkaartjie suksesvol gestuur!"), backgroundColor: AppColors.successGreen),
                          );
                        }
                        Navigator.pop(context, true);
                      } catch (e) {
                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Netwerkfout: $e"), backgroundColor: AppColors.errorRed),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: const Text("STUUR FOUTKAARTJIE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Kanselleer", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildAssetInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Bate Kode (Opsioneel)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: serialController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: _inputDecoration().copyWith(
                  hintText: "Tik Serial Kode of Skandeer...",
                  suffixIcon: _isAutoFilling
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                final code = serialController.text.trim();
                if (code.isNotEmpty) {
                  _autoFillFromCode(code);
                }
              },
              child: Container(
                height: 45, width: 45,
                decoration: BoxDecoration(color: AppColors.infoBlue, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.search, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                final String? scannedCode = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage()));
                if (scannedCode != null) {
                  setState(() => serialController.text = scannedCode);
                  _autoFillFromCode(scannedCode);
                }
              },
              child: Container(
                height: 45, width: 45,
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleDropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return SearchableDropdown<String>(
      label: label,
      hint: "Kies $label",
      value: value,
      items: items.map((e) => SearchableDropdownItem(value: e, label: e)).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }

  Widget _buildCustomTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        if (label.isNotEmpty) const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecoration().copyWith(hintText: hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[50],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    );
  }


  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Foto's (maks $_maxPhotos)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < _photoFiles.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_photoFiles[i], height: 80, width: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: () => setState(() => _photoFiles.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            if (_photoFiles.length < _maxPhotos)
              InkWell(
                onTap: () async {
                  final photo = await CameraService.takePhoto();
                  if (photo != null) {
                    setState(() => _photoFiles.add(photo));
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
                  child: const Icon(Icons.camera_alt, color: Colors.grey, size: 30),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

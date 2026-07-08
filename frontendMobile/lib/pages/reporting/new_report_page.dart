import 'dart:async';
import 'dart:io';
import '../../widgets/searchable_dropdown.dart';
import 'package:flutter/material.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../core/app_colors.dart';
import 'scan_page.dart';

import '../../services/report_service.dart';
import '../../services/image_service.dart';
import '../../services/camera_service.dart';
import '../../models/report.dart';
import '../../models/campus.dart';
import '../../services/asset_service.dart';

class NewReportPage extends StatefulWidget {
  const NewReportPage({super.key});

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
  File? _photoFile;
  bool _isAutoFilling = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    if (UserSession.hasAdminPrivileges) {
      selectedCategory = "Instandhouding";
    }
    serialController.addListener(_onSerialChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    serialController.removeListener(_onSerialChanged);
    serialController.dispose();
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  void _onSerialChanged() {
    _debounce?.cancel();
    final code = serialController.text.trim();
    if (code.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 600), () => _autoFillFromCode(code));
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

  List<String> get filteredBuildings {
    if (selectedCampus == null) return [];
    final campus = CampusService.getCampusByName(selectedCampus!);
    if (campus == null) return [];
    return campus.buildings.map((b) => b.name).toList();
  }

  List<String> get filteredRooms {
    if (selectedBuilding == null) return [];
    final campus = CampusService.getCampusByName(selectedCampus ?? '');
    if (campus == null) return [];
    final building = campus.buildings.where((b) => b.name == selectedBuilding).firstOrNull;
    if (building == null) return [];
    return (building.rooms ?? []).map((r) => '${r.id}:${r.name}').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Nuwe Foutkaartjie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  _buildAssetInput(),
                  const SizedBox(height: 20),

                  if (UserSession.hasAdminPrivileges)
                    Row(
                      children: [
                        Expanded(child: _buildSimpleDropdown("Kategorie *", selectedCategory.isNotEmpty ? selectedCategory : null, ["Instandhouding", "Herstelwerk", "Opgradering", "Ander"], (v) => setState(() => selectedCategory = v))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSimpleDropdown("Prioriteit *", selectedPriority, ["Laag", "Medium", "Hoog"], (v) => setState(() => selectedPriority = v))),
                      ],
                    )
                  else
                    _buildSimpleDropdown("Kategorie *", selectedCategory.isNotEmpty ? selectedCategory : null, ["Instandhouding", "Herstelwerk", "Opgradering", "Ander"], (v) => setState(() => selectedCategory = v)),

                  const SizedBox(height: 20),

                  ValueListenableBuilder<List<Campus>>(
                    valueListenable: CampusService.campusesNotifier,
                    builder: (context, campuses, _) {
                      return Row(
                        children: [
                          Expanded(
                            child: SearchableDropdown<String>(
                              label: "Kampus *",
                              hint: "Kies Kampus",
                              value: selectedCampus,
                              items: campuses
                                  .map((c) => SearchableDropdownItem(value: c.name, label: c.name))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                selectedCampus = v;
                                selectedBuilding = null;
                                selectedLocation = null;
                              }),
                              validator: (v) => v == null ? "Kampus word vereis" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SearchableDropdown<String>(
                              label: "Gebou *",
                              hint: selectedCampus == null ? "Kies eers kampus" : "Kies Gebou",
                              value: selectedBuilding,
                              items: filteredBuildings
                                  .map((b) => SearchableDropdownItem(value: b, label: b))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                selectedBuilding = v;
                                selectedLocation = null;
                              }),
                              validator: (v) => v == null ? "Gebou word vereis" : null,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildRoomDropdown(),

                  const SizedBox(height: 20),

                  _buildCustomTextField(
                    label: "Beskrywing van Probleem *",
                    hint: "Onderwerp (bv. Gebreekte Kraan)",
                    controller: titleController,
                    validator: (v) => v == null || v.isEmpty ? "Titel word vereis" : null,
                  ),
                  const SizedBox(height: 20),

                  _buildCustomTextField(
                    label: "",
                    hint: "Beskryf die probleem in detail...",
                    controller: descController,
                    maxLines: 3,
                    validator: (v) => v == null || v.trim().length <= 3 ? "Beskrywing moet minstens 4 karakters wees" : null,
                  ),
                  const SizedBox(height: 12),

                  _buildPhotoSection(),

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
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          if (selectedCategory.isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Kies asseblief 'n kategorie"), backgroundColor: AppColors.errorRed),
                              );
                            }
                            return;
                          }

                          int? imageId;
                          if (_photoFile != null) {
                            imageId = await ImageService.uploadImage(_photoFile!);
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
                            imageId: imageId,
                          );

                          try {
                            final success = await ReportService.addReport(newReport);
                            if (!mounted) return;
                            if (success) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Foutkaartjie suksesvol gestuur!"), backgroundColor: AppColors.successGreen),
                                );
                                Navigator.pop(context);
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Fout met stoor. Probeer weer."), backgroundColor: AppColors.errorRed),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Netwerkfout: $e"), backgroundColor: AppColors.errorRed),
                                );
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
                decoration: InputDecoration(
                  hintText: "Tik Serial Kode of Skandeer...",
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
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
              onTap: () async {
                final String? scannedCode = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage()));
                if (scannedCode != null) {
                  setState(() => serialController.text = scannedCode);
                  _autoFillFromCode(scannedCode);
                }
              },
              child: Container(
                height: 48, width: 48,
                decoration: BoxDecoration(color: const Color(0xFF8B5E34), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoomDropdown() {
    return SearchableDropdown<String>(
      label: "Lokaal *",
      hint: selectedCampus == null ? "Kies eers 'n Kampus" : (selectedBuilding == null ? "Kies eers 'n Gebou" : "Kies Lokaal"),
      value: selectedLocation,
      items: filteredRooms.map((r) {
        final name = r.contains(":") ? r.split(":").last : r;
        return SearchableDropdownItem(value: r, label: name);
      }).toList(),
      onChanged: (v) => setState(() => selectedLocation = v),
      validator: (v) => v == null ? "Lokaal word vereis" : null,
    );
  }

  Widget _buildSimpleDropdown(String label, String? value, List<String> items, ValueChanged<String> onChanged) {
    final allItems = [
      if (value == null)
        DropdownMenuItem<String>(
          value: "",
          enabled: false,
          child: Text("Kies Kategorie", style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),
        ),
      ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
    ];
    final currentValue = value ?? "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8B5E34)),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              items: allItems,
              onChanged: (v) { if (v != null && v.isNotEmpty) onChanged(v); },
            ),
          ),
        ),
      ],
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
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
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

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Foto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final photo = await CameraService.takePhoto();
            if (photo != null) {
              setState(() => _photoFile = photo);
            }
          },
          child: Container(
            height: 80, width: 80,
            decoration: BoxDecoration(
              color: _photoFile != null ? AppColors.gold.withValues(alpha: 0.1) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _photoFile != null ? AppColors.gold : Colors.grey[300]!),
            ),
            child: _photoFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(_photoFile!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.camera_alt, color: Colors.grey, size: 30),
          ),
        ),
        if (_photoFile != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() => _photoFile = null),
            child: const Text("Verwyder", style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

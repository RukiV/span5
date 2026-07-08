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

  static DateTime? lastSubmissionTime;

  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  final TextEditingController serialController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  String? selectedCampus;
  String? selectedBuilding;
  String? selectedLocation;
  String selectedCategory = "Instandhouding";
  String selectedPriority = "Medium";
  String selectedStatus = "Ontvang";
  File? _photoFile;
  bool showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  @override
  void dispose() {
    serialController.dispose();
    titleController.dispose();
    descController.dispose();
    super.dispose();
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

  bool get _canSubmit {
    bool hasLocation = selectedLocation != null;
    bool hasDescription = titleController.text.trim().isNotEmpty && descController.text.trim().length > 3;
    return hasLocation && hasDescription;
  }

  @override
  Widget build(BuildContext context) {
    const double sectionGap = 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Nuwe Foutkaartjie"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Bate Kode (Opsioneel)"),
                      const SizedBox(height: 6),
                      _buildAssetInput(),
                      const SizedBox(height: sectionGap),

                      if (UserSession.hasAdminPrivileges)
                        Row(
                          children: [
                            Expanded(child: _buildSimpleDropdown("Kategorie", selectedCategory, ["Instandhouding", "Herstelwerk", "Opgradering", "Ander"], (v) => setState(() => selectedCategory = v))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSimpleDropdown("Prioriteit", selectedPriority, ["Laag", "Medium", "Hoog"], (v) => setState(() => selectedPriority = v))),
                          ],
                        )
                      else
                        _buildSimpleDropdown("Kategorie", selectedCategory, ["Instandhouding", "Herstelwerk", "Opgradering", "Ander"], (v) => setState(() => selectedCategory = v)),

                      const SizedBox(height: sectionGap),

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

                      const SizedBox(height: sectionGap),

                      if (UserSession.hasAdminPrivileges)
                        Row(
                          children: [
                            Expanded(child: _buildRoomDropdown()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSimpleDropdown("Status", selectedStatus, ["Ontvang", "Besig", "Voltooi", "Geweier"], (v) => setState(() => selectedStatus = v))),
                          ],
                        )
                      else
                        _buildRoomDropdown(),

                      const SizedBox(height: sectionGap),

                      _buildLabel("Beskrywing van Probleem *"),
                      const SizedBox(height: 6),
                      _buildEmailStyleDescription(),

                      const Spacer(),
                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!UserSession.hasAdminPrivileges && NewReportPage.lastSubmissionTime != null) {
                              final difference = DateTime.now().difference(NewReportPage.lastSubmissionTime!);
                              if (difference.inMinutes < 10) {
                                final minutesLeft = 10 - difference.inMinutes;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Wag asseblief nog $minutesLeft minute."), backgroundColor: AppColors.warningOrange),
                                );
                                return;
                              }
                            }

                            if (!_canSubmit) {
                              setState(() => showValidationErrors = true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Vul asseblief alle verpligte velde in."), backgroundColor: AppColors.errorRed),
                                );
                              }
                              return;
                            }

                            int? imageId;
                            if (_photoFile != null) {
                              imageId = await ImageService.uploadImage(_photoFile!);
                            }

                            int? finalAssetIdInt;
                            if (serialController.text.isNotEmpty) {
                              final asset = await AssetService.getAssetBySerialCode(serialController.text);
                              if (asset != null) {
                                finalAssetIdInt = int.tryParse(asset.id);
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
                              location: roomId,
                              title: titleController.text.trim(),
                              description: descController.text.trim(),
                              category: selectedCategory,
                              priority: UserSession.hasAdminPrivileges ? selectedPriority : "Medium",
                              phase: UserSession.hasAdminPrivileges ? selectedStatus : "Ontvang",
                              user: UserSession.userId.toString(),
                              timestamp: DateTime.now(),
                              imageId: imageId,
                            );

                            try {
                              final success = await ReportService.addReport(newReport);
                              if (!mounted) return;
                              if (success) {
                                NewReportPage.lastSubmissionTime = DateTime.now();
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
                            backgroundColor: _canSubmit ? AppColors.gold : Colors.grey[400],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("STOOR FOUTKAARTJIE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      if (showValidationErrors && !_canSubmit)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Center(
                            child: Text(
                              "Voltooi asseblief alle verpligte velde (*)",
                              style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssetInput() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFEFBEA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: TextField(
              controller: serialController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: "Tik Serial Kode of Skandeer...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () async {
            final String? scannedCode = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage()));
            if (scannedCode != null) {
              setState(() => serialController.text = scannedCode);
            }
          },
          child: Container(
            height: 48, width: 48,
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.qr_code_scanner, color: Colors.white),
          ),
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

  Widget _buildSimpleDropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEFBEA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.gold),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStyleDescription() {
    bool hasTitleError = showValidationErrors && titleController.text.isEmpty;
    bool hasDescError = showValidationErrors && descController.text.trim().length <= 3;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEFBEA),
        borderRadius: BorderRadius.circular(8),
        border: (hasTitleError || hasDescError)
            ? Border.all(color: Colors.red, width: 1.5)
            : Border.all(color: Colors.grey[400]!),
      ),
      child: Column(
        children: [
          TextField(
            controller: titleController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
            decoration: const InputDecoration(
              hintText: "Onderwerp (bv. Gebreekte Kraan)",
              hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(12, 12, 12, 6),
            ),
          ),
          const Divider(height: 1, color: Colors.black12, indent: 12, endIndent: 12),
          TextField(
            controller: descController,
            onChanged: (_) => setState(() {}),
            maxLines: 3,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black),
            decoration: const InputDecoration(
              hintText: "Beskryf die probleem in detail...",
              hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 10, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () async {
                    final photo = await CameraService.takePhoto();
                    if (photo != null) {
                      setState(() => _photoFile = photo);
                    }
                  },
                  child: Container(
                    height: 40, width: 40,
                    decoration: BoxDecoration(
                      color: _photoFile != null ? AppColors.gold.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _photoFile != null ? AppColors.gold : Colors.grey[300]!),
                    ),
                    child: _photoFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(_photoFile!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.grey, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }
}

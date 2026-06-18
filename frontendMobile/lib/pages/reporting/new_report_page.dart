import '../../widgets/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../models/user_session.dart';
import '../../core/campus_service.dart';
import '../../core/camera_service.dart';
import '../../core/app_colors.dart';
import 'scan_page.dart';

import '../../core/report_service.dart';
import '../../models/report.dart';
import '../../models/campus.dart';
import '../../core/asset_service.dart';

class NewReportPage extends StatefulWidget {
  const NewReportPage({super.key});

  static DateTime? lastSubmissionTime;

  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  final List<File> problemImages = [];
  String? gpsCoords;
  Uint8List? mapScreenshot;
  final TextEditingController serialController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  final TextEditingController internalNotesController = TextEditingController();
  String? selectedCampus;
  String? selectedLocation;
  String? selectedCategory;
  String selectedPriority = "Laag";

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
    internalNotesController.dispose();
    super.dispose();
  }

  List<String> get filteredRooms {
    if (selectedCampus == null) return [];
    try {
      final campus = CampusService.campusesNotifier.value.firstWhere(
        (c) => c.name == selectedCampus,
      );
      return campus.rooms;
    } catch (_) {
      return [];
    }
  }
  bool isInvisibleCode = false;
  bool isUnknownLocation = false;
  bool showValidationErrors = false;

  void _handleScanResult(String? result) {
    if (result == null) return;
    setState(() {
      isInvisibleCode = false;
      serialController.text = result;
    });
  }

  bool get _canSubmit {
    bool hasAsset = isInvisibleCode ? (selectedCategory != null) : serialController.text.isNotEmpty;
    bool hasLocation = isUnknownLocation ? (gpsCoords != null) : (selectedLocation != null);
    bool hasDescription = titleController.text.trim().isNotEmpty && descController.text.trim().length > 3;
    return hasAsset && hasLocation && hasDescription;
  }

  @override
  Widget build(BuildContext context) {
    const double sectionGap = 22.0;
    const double labelGap = 6.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Nuwe Fout Verslag"),
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
                      if (!isInvisibleCode) ...[
                        _buildLabelWithAction(
                            "Bate Serial Kode (Sigbare Kode) *",
                            "Kode Onsigbaar",
                            () => setState(() {
                                  isInvisibleCode = true;
                                  serialController.clear();
                                })),
                        const SizedBox(height: labelGap),
                        _buildAssetInput(),
                      ] else ...[
                        CustomDropdown<String>(
                          label: "Kategorie (Onsigbare Kode) *",
                          hint: "Kies Kategorie",
                          value: selectedCategory,
                          items: ["Instandhouding", "Herstel", "Opgradering", "Ander"]
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => selectedCategory = v),
                          validator: (v) => v == null ? "Kategorie word vereis" : null,
                        ),
                      ],

                      const SizedBox(height: sectionGap),

                      ValueListenableBuilder<List<Campus>>(
                        valueListenable: CampusService.campusesNotifier,
                        builder: (context, campuses, _) {
                          return CustomDropdown<String>(
                            label: "Kampus *",
                            hint: "Kies Kampus",
                            value: selectedCampus,
                            items: campuses
                                .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              selectedCampus = v;
                              selectedLocation = null;
                            }),
                            validator: (v) => v == null ? "Kampus word vereis" : null,
                          );
                        },
                      ),

                      const SizedBox(height: sectionGap),

                      _buildSectionHeader("Lokaal *",
                          actionText: isUnknownLocation ? "Kies Uit Lys" : "Nie Gelys Nie",
                          onAction: () => setState(() {
                                isUnknownLocation = !isUnknownLocation;
                                if (isUnknownLocation) {
                                  selectedLocation = null;
                                } else {
                                  gpsCoords = null;
                                }
                              })),
                      const SizedBox(height: labelGap),
                      if (isUnknownLocation)
                        _buildLocationInput()
                      else
                        CustomDropdown<String>(
                          hint: selectedCampus == null ? "Kies eers 'n Kampus" : "Kies Lokaal",
                          value: selectedLocation,
                          items: filteredRooms.map((r) {
                            final name = r.contains(":") ? r.split(":").last : r;
                            return DropdownMenuItem(value: r, child: Text(name));
                          }).toList(),
                          onChanged: (v) => setState(() => selectedLocation = v),
                          validator: (v) => v == null ? "Lokaal word vereis" : null,
                        ),

                      const SizedBox(height: sectionGap),

                      _buildSectionHeader("Beskrywing van Probleem *"),
                      const SizedBox(height: labelGap),
                      _buildEmailStyleDescription(),

                      if (UserSession.hasAdminPrivileges) ...[
                        const SizedBox(height: sectionGap),
                        _buildLabel("Admin Interne Notas"),
                        const SizedBox(height: labelGap),
                        _buildCustomTextField(
                          controller: internalNotesController,
                          hint: "Notas slegs sigbaar vir personeel...",
                        ),
                        const SizedBox(height: sectionGap),
                        _buildLabel("Prioriteit (Aktiveer na voltooiing)"),
                        const SizedBox(height: labelGap),
                        AbsorbPointer(
                          absorbing: !_canSubmit,
                          child: Opacity(
                            opacity: _canSubmit ? 1.0 : 0.5,
                            child: _buildPrioritySelector(),
                          ),
                        ),
                      ],

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
                                  SnackBar(content: Text("Wag asseblief nog $minutesLeft minute."), backgroundColor: Colors.orange),
                                );
                                return;
                              }
                            }

                            if (!_canSubmit) {
                              setState(() => showValidationErrors = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Vul asseblief alle verpligte velde in."), backgroundColor: Colors.red),
                              );
                              return;
                            }

                            int? finalAssetIdInt;
                            if (!isInvisibleCode) {
                              final asset = await AssetService.getAssetBySerialCode(serialController.text);
                              if (asset == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Bate met hierdie serial kode nie gevind nie."), backgroundColor: Colors.red),
                                );
                                return;
                              }
                              finalAssetIdInt = int.tryParse(asset.id);
                            }

                            final String finalAssetId = finalAssetIdInt?.toString() ?? "0";

                            String roomId = "1";
                            if (selectedLocation != null && selectedLocation!.contains(":")) {
                              roomId = selectedLocation!.split(":").first;
                            }

                            // Map prioriteit (Backend verwag: laag, medium, hoog)
                            String backendPriorityStr = "laag";
                            if (selectedPriority == "Medium") backendPriorityStr = "medium";
                            if (selectedPriority == "Hoog") backendPriorityStr = "hoog";

                            final newReport = Report(
                              id: "0",
                              assetId: finalAssetId,
                              location: isUnknownLocation ? "1" : roomId,
                              title: titleController.text.trim(),
                              description: descController.text.trim(),
                              category: isInvisibleCode ? (selectedCategory ?? "Instandhouding") : "Herstel",
                              priority: backendPriorityStr,
                              phase: "Ontvang",
                              user: UserSession.userId.toString(),
                              timestamp: DateTime.now(),
                              gpsCoords: gpsCoords,
                              adminNotes: UserSession.hasAdminPrivileges ? internalNotesController.text : null,
                            );

                            try {
                              // Support multiple images if backend allows in future, currently service might take one
                              final success = await ReportService.addReport(newReport, problemImages.isNotEmpty ? problemImages.first : null);
                              if (mounted) {
                                if (success) {
                                  NewReportPage.lastSubmissionTime = DateTime.now();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Verslag suksesvol gestuur!"), backgroundColor: Colors.green),
                                  );
                                  Navigator.pop(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Fout met stoor. Probeer weer."), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Netwerkfout: $e"), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canSubmit ? AppColors.gold : Colors.grey[400],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("STOOR VERSLAG", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
          child: _buildCustomTextField(
            controller: serialController,
            hint: "Tik Serial Kode of Skandeer...",
            hasError: showValidationErrors && serialController.text.isEmpty,
          ),
        ),
        const SizedBox(width: 8),
        _buildScanButton(() async {
          final String? scannedCode = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage()));
          if (scannedCode != null) _handleScanResult(scannedCode);
        }),
      ],
    );
  }

  Widget _buildLocationInput() {
    if (isUnknownLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFBEA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: (showValidationErrors && gpsCoords == null) ? Colors.red : Colors.grey[400]!),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: gpsCoords != null ? Colors.green : Colors.grey),
            const SizedBox(width: 10),
            Text(gpsCoords ?? "GPS Koördinate word vereis", style: TextStyle(fontSize: 13, color: gpsCoords != null ? Colors.black : Colors.grey)),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: selectedLocation,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFFEFBEA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      hint: Text(selectedCampus == null ? "Kies eers 'n Kampus" : "Kies Lokaal", style: const TextStyle(fontSize: 14)),
      items: filteredRooms.map((r) {
        final name = r.contains(":") ? r.split(":").last : r;
        return DropdownMenuItem(value: r, child: Text(name));
      }).toList(),
      onChanged: (v) => setState(() => selectedLocation = v),
      validator: (v) => v == null ? "Lokaal word vereis" : null,
    );
  }

  Widget _buildCustomTextField({required TextEditingController controller, required String hint, bool hasError = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEFBEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hasError ? Colors.red : Colors.grey[400]!),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildScanButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48, width: 48,
        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
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
          if (problemImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: problemImages.map((img) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(img, width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => problemImages.remove(img)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 10, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCompactActionButton(
                  icon: Icons.add_a_photo_outlined,
                  onTap: () async {
                    final file = await CameraService.takePhoto();
                    if (file != null) setState(() => problemImages.add(file));
                  },
                ),
                const SizedBox(width: 8),
                _buildCompactActionButton(
                  icon: gpsCoords != null ? Icons.location_on : Icons.location_on_outlined,
                  isActive: gpsCoords != null,
                  isMandatory: isUnknownLocation && gpsCoords == null && showValidationErrors,
                  mapScreenshot: mapScreenshot,
                  onTap: () async {
                    bool isFirstTime = gpsCoords == null;
                    final result = await Navigator.pushNamed(context, '/location', arguments: {'autoConfirm': isFirstTime});
                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        gpsCoords = result['coords'];
                        mapScreenshot = result['screenshot'];
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton({required IconData icon, bool isActive = false, bool isMandatory = false, Uint8List? mapScreenshot, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40, width: 40,
        decoration: BoxDecoration(
          color: (isActive || mapScreenshot != null) ? AppColors.gold.withOpacity(0.1) : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isMandatory ? Colors.red : ((isActive || mapScreenshot != null) ? AppColors.gold : Colors.grey[300]!)),
        ),
        child: mapScreenshot != null
            ? ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.memory(mapScreenshot, fit: BoxFit.cover))
            : Icon(icon, color: isMandatory ? Colors.red : ((isActive || mapScreenshot != null) ? AppColors.gold : Colors.grey[600]), size: 20),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    final priorities = ["Laag", "Medium", "Hoog"];
    return Row(
      children: priorities.map((p) {
        bool isSelected = selectedPriority == p;
        Color pColor = p == "Hoog" ? Colors.red : (p == "Medium" ? Colors.orange : Colors.green);
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedPriority = p),
            child: Container(
              margin: EdgeInsets.only(right: p == "Hoog" ? 0 : 8),
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? pColor.withOpacity(0.1) : const Color(0xFFFEFBEA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? pColor : Colors.grey[400]!),
              ),
              child: Center(
                child: Text(p, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? pColor : Colors.grey[600])),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, {String? actionText, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        if (actionText != null && onAction != null)
          GestureDetector(onTap: onAction, child: Text(actionText, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
  }

  Widget _buildLabelWithAction(String text, String actionText, VoidCallback onAction) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        GestureDetector(onTap: onAction, child: Text(actionText, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
      ],
    );
  }
}

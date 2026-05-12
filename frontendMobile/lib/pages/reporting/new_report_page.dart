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

class NewReportPage extends StatefulWidget {
  const NewReportPage({super.key});

  // Statiese veranderlike om die laaste suksesvolle indieningstyd te stoor
  static DateTime? lastSubmissionTime;

  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  File? problemImage;
  String? gpsCoords;
  Uint8List? mapScreenshot; 
  final TextEditingController idController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  List<String> get availableRooms {
    try {
      final campus = CampusService.campusesNotifier.value.firstWhere(
        (c) => c.name == UserSession.userCampus || UserSession.userCampus.contains(c.name)
      );
      return campus.rooms;
    } catch (_) {
      return ['Algemene Area'];
    }
  }

  String? selectedLocation;
  String? selectedCategory;
  String selectedPriority = "Laag"; // Nuwe prioriteit staat
  bool isInvisibleCode = false;
  bool isUnknownLocation = false;
  bool showValidationErrors = false;

  void _handleScanResult(String? result) {
    if (result == null) return;
    setState(() {
      isInvisibleCode = false;
      idController.text = result;
    });
  }

  bool get _canSubmit {
    bool hasAsset = isInvisibleCode ? (selectedCategory != null) : idController.text.isNotEmpty;
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
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 25), // Aangepas vir 22px gap bo
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- AFDELING 1: BATE ---
                      if (!isInvisibleCode) ...[
                        _buildLabelWithAction(
                          "Bate Kode (Sigbare Kode) *", 
                          "Kode Onsigbaar", 
                          () => setState(() {
                            isInvisibleCode = true;
                            idController.clear();
                          })
                        ),
                        const SizedBox(height: labelGap),
                        _buildAssetInput(),
                      ] else ...[
                        _buildLabelWithAction(
                          "Kategorie (Onsigbare Kode) *", 
                          "Gebruik Kode", 
                          () => setState(() {
                            isInvisibleCode = false;
                          })
                        ),
                        const SizedBox(height: labelGap),
                        _buildCategoryDropdown(),
                      ],

                      const SizedBox(height: sectionGap),

                      // --- AFDELING 2: LOKAAL ---
                      _buildSectionHeader(
                        "Lokaal *", 
                        actionText: isUnknownLocation ? "Kies Uit Lys" : "Nie Gelys Nie", 
                        onAction: () => setState(() {
                          isUnknownLocation = !isUnknownLocation;
                          if (isUnknownLocation) selectedLocation = null; else gpsCoords = null;
                        })
                      ),
                      const SizedBox(height: labelGap), // Verander na labelGap vir konsekwentheid
                      _buildLocationInput(),

                      const SizedBox(height: sectionGap),

                      // --- AFDELING 3: BESKRYWING (E-POS STYL) ---
                      _buildSectionHeader("Beskrywing van Probleem *"),
                      const SizedBox(height: labelGap), // Verander na labelGap vir konsekwentheid
                      _buildEmailStyleDescription(),

                      // --- AFDELING 4: PRIORITEIT (Slegs Admin) ---
                      if (UserSession.hasAdminPrivileges) ...[
                        const SizedBox(height: sectionGap),
                        _buildLabel("Prioriteit"),
                        const SizedBox(height: labelGap),
                        _buildPrioritySelector(),
                      ],

                      const Spacer(), 
                      const SizedBox(height: 30),

                      // --- STOOR KNOPPIE ---
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            // 10-Minute Timer vir nie-Admins
                            if (!UserSession.hasAdminPrivileges && NewReportPage.lastSubmissionTime != null) {
                              final difference = DateTime.now().difference(NewReportPage.lastSubmissionTime!);
                              if (difference.inMinutes < 10) {
                                final minutesLeft = 10 - difference.inMinutes;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Wag asseblief nog $minutesLeft minute voor jou volgende verslag."),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }
                            }

                            if (!_canSubmit) {
                              setState(() => showValidationErrors = true);
                              return;
                            }
                            
                            // Stel die laaste indieningstyd op nou
                            NewReportPage.lastSubmissionTime = DateTime.now();

                            final newReport = Report(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              assetId: isInvisibleCode ? "ONSIGBAAR" : idController.text,
                              location: isUnknownLocation ? "GPS: $gpsCoords" : selectedLocation!,
                              title: titleController.text,
                              description: descController.text,
                              category: isInvisibleCode ? selectedCategory! : "Geskandeer",
                              priority: selectedPriority,
                              phase: "Ontvang",
                              user: UserSession.userName,
                              timestamp: DateTime.now(),
                              gpsCoords: gpsCoords,
                            );

                            ReportService.addReport(newReport, problemImage).then((success) {
                              if (mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Verslag suksesvol gestuur!"),
                                      backgroundColor: Colors.green,
                                      duration: Duration(milliseconds: 1500),
                                    ),
                                  );
                                  Navigator.pop(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Fout met stuur van verslag. Probeer weer."),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canSubmit ? AppColors.gold : Colors.grey[400],
                          ),
                          child: const Text("STOOR VERSLAG", style: TextStyle(fontWeight: FontWeight.bold)),
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

  // --- HELPER WIDGETS ---

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
            maxLines: 3, // Terug na 3 vir die perfekte balans
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
                _buildCompactActionButton(
                  icon: Icons.add_a_photo_outlined,
                  isActive: problemImage != null,
                  imageFile: problemImage, // Stuur die lêer saam vir die thumbnail
                  onTap: () async {
                    final file = await CameraService.takePhoto();
                    if (file != null) setState(() => problemImage = file);
                  },
                ),
                const SizedBox(width: 8),
                _buildCompactActionButton(
                  icon: gpsCoords != null ? Icons.location_on : Icons.location_on_outlined,
                  isActive: gpsCoords != null,
                  isMandatory: isUnknownLocation && gpsCoords == null && showValidationErrors,
                  mapScreenshot: mapScreenshot, 
                  onTap: () async {
                    // As ons nog nie 'n ligging het nie, doen die "Auto-Snap"
                    bool isFirstTime = gpsCoords == null;
                    
                    final result = await Navigator.pushNamed(
                      context, 
                      '/location',
                      arguments: {'autoConfirm': isFirstTime}
                    );

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

  Widget _buildCompactActionButton({
    required IconData icon, 
    bool isActive = false, 
    bool isMandatory = false, 
    File? imageFile, 
    Uint8List? mapScreenshot, // Nuwe parameter
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40, width: 40,
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold.withAlpha(25) : Colors.white.withAlpha(120),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isMandatory ? Colors.red : (isActive ? AppColors.gold : Colors.grey[300]!)),
        ),
        child: imageFile != null 
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(imageFile, fit: BoxFit.cover),
            )
          : mapScreenshot != null 
            ? ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.memory(mapScreenshot, fit: BoxFit.cover),
              )
            : Icon(icon, color: isMandatory ? Colors.red : (isActive ? AppColors.gold : Colors.grey[600]), size: 20),
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
                color: isSelected ? pColor.withAlpha(30) : const Color(0xFFFEFBEA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? pColor : Colors.grey[400]!),
              ),
              child: Center(
                child: Text(
                  p,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? pColor : Colors.grey[600],
                  ),
                ),
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
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText,
              style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            ),
          ),
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
        GestureDetector(
          onTap: onAction,
          child: Text(
            actionText,
            style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetInput() {
    return Row(
      children: [
        Expanded(
          child: _buildCustomTextField(
            controller: idController,
            hint: "Tik Kode of Skandeer...",
            hasError: showValidationErrors && idController.text.isEmpty,
          ),
        ),
        const SizedBox(width: 8),
        _buildScanButton(() async {
          final String? scannedCode = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage()));
          if (scannedCode != null) _handleScanResult(scannedCode);
        }, idController.text.isEmpty && showValidationErrors),
      ],
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hint,
    required bool hasError,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEFBEA),
        borderRadius: BorderRadius.circular(8),
        border: hasError ? Border.all(color: Colors.red, width: 1.5) : Border.all(color: Colors.grey[400]!),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFBEA),
        borderRadius: BorderRadius.circular(8),
        border: (showValidationErrors && selectedCategory == null) ? Border.all(color: Colors.red, width: 1.5) : Border.all(color: Colors.grey[400]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCategory,
          hint: const Text("Kies uit kategorie uit...", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey)),
          isExpanded: true,
          items: ['Meubels', 'IT Toerusting', 'Loodgieterswerk', 'Elektrisiteit', 'Infrastruktuur', 'Ander']
              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black))))
              .toList(),
          onChanged: (val) => setState(() => selectedCategory = val!),
        ),
      ),
    );
  }

  Widget _buildLocationInput() {
    return SizedBox(
      height: 50,
      child: !isUnknownLocation
          ? Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFBEA),
                      borderRadius: BorderRadius.circular(8),
                      border: (showValidationErrors && selectedLocation == null) ? Border.all(color: Colors.red, width: 1.5) : Border.all(color: Colors.grey[400]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedLocation,
                        hint: const Text("Kies lokaal uit lys...", style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey)),
                        isExpanded: true,
                        items: availableRooms
                            .map((loc) => DropdownMenuItem(value: loc, child: Text(loc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black))))
                            .toList(),
                        onChanged: (val) => setState(() => selectedLocation = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildScanButton(() async {
                  final String? scannedLoc = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage(isLocation: true)));
                  if (scannedLoc != null) setState(() => selectedLocation = scannedLoc);
                }, selectedLocation == null && showValidationErrors),
              ],
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: gpsCoords == null && showValidationErrors ? Colors.red.withAlpha(12) : AppColors.gold.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gpsCoords == null && showValidationErrors ? Colors.red : AppColors.gold.withAlpha(76)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: gpsCoords == null && showValidationErrors ? Colors.red : AppColors.gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gpsCoords == null ? "Ligging word vereis vir onbekende lokaal" : "Ligging vasgelê: $gpsCoords",
                      style: TextStyle(fontSize: 12, color: gpsCoords == null && showValidationErrors ? Colors.red : AppColors.navy.withAlpha(200)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildScanButton(VoidCallback onTap, bool hasError) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.gold.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: hasError ? Border.all(color: Colors.red, width: 1.5) : Border.all(color: Colors.grey[400]!),
        ),
        child: const Icon(Icons.qr_code_scanner, color: AppColors.gold),
      ),
    );
  }
}

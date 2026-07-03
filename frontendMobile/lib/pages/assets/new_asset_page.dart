import '../../widgets/custom_dropdown.dart';
import 'package:flutter/material.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../core/app_colors.dart';
import '../../models/asset.dart';
import '../../core/asset_service.dart';
import '../../models/user_session.dart';

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
  bool isFixed = false;
  String location = ""; // Vir handmatige invoer as geen kamers gelaai is nie
  final List<String> categories = ["Meubels", "IT Voorraad", "Elektronika", "Kombuis", "Ander"];

  String? selectedCampus;
  String? selectedLocation;
  String category = "Meubels";
  String status = "active";
  
  @override
  void initState() {
    super.initState();
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

  List<String> get availableRooms {
    if (selectedCampus == null) return [];
    try {
      final c = CampusService.campusesNotifier.value.firstWhere(
              (c) => c.name == selectedCampus
      );
      return c.rooms;
    } catch (_) {
      return [];
    }
  }

  Widget _buildCustomTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    bool readOnly = false,
    String? initialValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          readOnly: readOnly,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: "",
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Nuwe Bate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  _buildCustomTextField(
                    label: "Naam",
                    hint: "",
                    onChanged: (v) => name = v,
                    validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),

                  _buildCustomTextField(
                    label: "Serienommer",
                    hint: "",
                    onChanged: (v) => serialCode = v,
                    validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),

                  const Text("Buite", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Checkbox(
                    value: isFixed,
                    onChanged: (v) => setState(() => isFixed = v!),
                  ),
                  const SizedBox(height: 20),

                  ValueListenableBuilder<List<Campus>>(
                    valueListenable: CampusService.campusesNotifier,
                    builder: (context, campuses, _) {
                      return CustomDropdown<String>(
                        label: "Kampus",
                        hint: "",
                        value: selectedCampus,
                        items: campuses
                            .map((c) => DropdownMenuItem(
                                value: c.name,
                                child: Text(c.name, style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            selectedCampus = v;
                            selectedLocation = null;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  CustomDropdown<String>(
                    label: "Lokaal",
                    hint: "",
                    value: selectedLocation,
                    items: availableRooms.map((r) {
                      final name = r.contains(":") ? r.split(":").last : r;
                      return DropdownMenuItem(
                          value: r,
                          child: Text(name, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (v) => setState(() => selectedLocation = v!),
                  ),
                  const SizedBox(height: 20),

                  CustomDropdown<String>(
                    label: "Status",
                    hint: "",
                    value: status,
                    items: [
                      {"value": "active", "label": "Aktief"},
                      {"value": "maintenance", "label": "Onderhoud"},
                      {"value": "decommissioned", "label": "Afgedank"},
                    ].map((s) => DropdownMenuItem(
                      value: s["value"] as String, 
                      child: Text(s["label"] as String)
                    )).toList(),
                    onChanged: (v) => setState(() => status = v!),
                  ),

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
                          if (_formKey.currentState!.validate()) {
                            final newAsset = Asset(
                              id: AssetService.generateUniqueId(category, selectedCampus ?? "GEN"),
                              serialCode: serialCode,
                              name: name,
                              category: category,
                              location: selectedLocation?.split(":").first ?? "1",
                              status: status,
                              campus: selectedCampus ?? "",
                              purchaseDate: DateTime.now(),
                              campusStartDate: DateTime.now(),
                            );
                            
                            final success = await AssetService.addAsset(newAsset);
                            if (mounted && success) {
                              Navigator.pop(context);
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
}
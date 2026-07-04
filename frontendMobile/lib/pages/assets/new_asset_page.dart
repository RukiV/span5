<<<<<<< HEAD
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
  final List<String> categories = ["Meubels", "IT Toerusting", "Elektronika", "Kombuis", "Ander"];

  String? selectedCampus;
  String? selectedLocation;
  String category = "Meubels";
  
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
            hintText: hint,
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : const Color(0xFFFEFBEA),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("NUWE BATE REGISTRASIE")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomTextField(
                label: "Bate Naam *",
                hint: "bv. Toyota Tafel",
                onChanged: (v) => name = v,
                validator: (v) => (v == null || v.isEmpty) ? "Naam word vereis" : null,
              ),
              const SizedBox(height: 20),

              _buildCustomTextField(
                label: "Serial Kode *",
                hint: "bv. AK-MT000001",
                onChanged: (v) => serialCode = v,
                validator: (v) => (v == null || v.isEmpty) ? "Serial kode word vereis" : null,
              ),
              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomDropdown<String>(
                      label: "Kategorie *",
                      hint: "Kies",
                      value: category,
                      items: categories
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(() => category = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ValueListenableBuilder<List<Campus>>(
                      valueListenable: CampusService.campusesNotifier,
                      builder: (context, campuses, _) {
                        // Filter campuses if FK
                        final filteredCampuses = UserSession.isAdmin 
                            ? campuses 
                            : campuses.where((c) => c.name == UserSession.userCampus || UserSession.userCampus.contains(c.name)).toList();
                        
                        return CustomDropdown<String>(
                          label: "Kampus *",
                          hint: "Kies",
                          value: selectedCampus,
                          items: filteredCampuses
                              .map((c) => DropdownMenuItem(
                                  value: c.name,
                                  child: Text(c.name,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: UserSession.isAdmin ? (v) {
                            setState(() {
                              selectedCampus = v;
                              selectedLocation = null;
                            });
                          } : null, // Disable selection for FK
                          validator: (v) => v == null ? "Vereis" : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              availableRooms.isNotEmpty
                  ? CustomDropdown<String>(
                      label: "Spesifieke Lokaal *",
                      hint: "Kies Lokaal",
                      value: selectedLocation,
                      items: availableRooms.map((r) {
                        final name = r.contains(":") ? r.split(":").last : r;
                        return DropdownMenuItem(
                            value: r,
                            child: Text(name, style: const TextStyle(fontSize: 14)));
                      }).toList(),
                      onChanged: (v) => setState(() => selectedLocation = v!),
                      validator: (v) => v == null ? "Lokaal word vereis" : null,
                    )
                  : _buildCustomTextField(
                      label: "Spesifieke Lokaal *",
                      hint: "bv. Lokaal 4 of Bitterbessie",
                      onChanged: (v) => location = v,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? "Lokaal word vereis" : null,
                    ),

              const SizedBox(height: 25),
              const Text("IDENTIFIKASIE OPSIES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy, letterSpacing: 1.1)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: SwitchListTile(
                  title: Text(isFixed ? "QR Kode (Vaste Item)" : "Barcode (Los Item)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(isFixed ? "Vir Aircons, Ligte, ens." : "Vir stoele, tafels, ens.", style: const TextStyle(fontSize: 12)),
                  value: isFixed,
                  activeThumbColor: AppColors.gold,
                  onChanged: (v) => setState(() => isFixed = v),
                ),
              ),

              if (serialCode != "") ...[
                const SizedBox(height: 25),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Text("BATE SERIAL: ${serialCode.isNotEmpty ? serialCode : 'Voer serial kode in'}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 15)),
                        const SizedBox(height: 15),
                        isFixed
                            ? QrImageView(data: serialCode.isNotEmpty ? serialCode : 'Voer serial kode in', size: 150)
                            : BarcodeWidget(barcode: Barcode.code128(), data: serialCode.isNotEmpty ? serialCode : 'Voer serial kode in', width: 220, height: 80),
                        const SizedBox(height: 12),
                        const Text("Druk hierdie kode uit vir die bate", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Trek Room ID uit
                      String roomId = "1";
                      if (selectedLocation != null && selectedLocation!.contains(":")) {
                        roomId = selectedLocation!.split(":").first;
                      }

                      final newAsset = Asset(
                        campus: selectedCampus ?? "Onbekend",
                        id: '',
                        serialCode: serialCode,
                        name: name,
                        category: category,
                        location: roomId,
                        status: "active",
                        purchaseDate: DateTime.now(),
                        campusStartDate: DateTime.now(),
                      );

                      final success = await AssetService.addAsset(newAsset);
                      if (mounted) {
                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Bate suksesvol geregistreer"),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Fout met registrasie. Probeer weer."),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("REGISTREER BATE", style: TextStyle(letterSpacing: 1.1, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
=======
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
>>>>>>> 3080162a6b51675de2ce74fa53f3bd629f39db17
}
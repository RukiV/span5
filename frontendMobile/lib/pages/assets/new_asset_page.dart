import 'package:flutter/material.dart';
import '../../core/campus_service.dart';
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
  String? generatedId;
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
    } else {
      try {
        selectedCampus = CampusService.campusesNotifier.value
            .firstWhere((c) => c.name == UserSession.userCampus || UserSession.userCampus.contains(c.name))
            .name;
      } catch (_) {}
    }
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

  // Verbeterde ID generasie
  String _generateAndSetId() {
    final newId = AssetService.generateUniqueId(category, selectedCampus ?? "GEN");
    setState(() {
      generatedId = newId;
    });
    return newId;
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

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Kategorie *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: category,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFEFBEA),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) {
                            setState(() {
                              category = v!;
                              // Moenie ID hier genereer nie, wag tot die knoppie gedruk word of genereer net as dit klaar gewys word
                              if (generatedId != null) _generateAndSetId();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Kampus *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
                        const SizedBox(height: 6),
                        ValueListenableBuilder<List<Campus>>(
                          valueListenable: CampusService.campusesNotifier,
                          builder: (context, campuses, _) {
                            return DropdownButtonFormField<String>(
                              value: selectedCampus,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFFEFBEA),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: campuses.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, style: const TextStyle(fontSize: 14)))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  selectedCampus = v;
                                  selectedLocation = null;
                                });
                              },
                              validator: (v) => v == null ? "Kampus word vereis" : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              availableRooms.isNotEmpty
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Spesifieke Lokaal *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
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
                    items: availableRooms.map((r) {
                      final name = r.contains(":") ? r.split(":").last : r;
                      return DropdownMenuItem(value: r, child: Text(name, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (v) => setState(() => selectedLocation = v!),
                    validator: (v) => v == null ? "Lokaal word vereis" : null,
                  ),
                ],
              )
                  : _buildCustomTextField(
                label: "Spesifieke Lokaal *",
                hint: "bv. Lokaal 4 of Bitterbessie",
                onChanged: (v) => location = v,
                validator: (v) => (v == null || v.isEmpty) ? "Lokaal word vereis" : null,
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
                  activeColor: AppColors.gold,
                  onChanged: (v) => setState(() => isFixed = v),
                ),
              ),

              if (generatedId != null) ...[
                const SizedBox(height: 25),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text("BATE ID: $generatedId", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 15)),
                        const SizedBox(height: 15),
                        isFixed
                            ? QrImageView(data: generatedId!, size: 150)
                            : BarcodeWidget(barcode: Barcode.code128(), data: generatedId!, width: 220, height: 80),
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
                      // REGSTELLING: Genereer die ID onmiddellik in 'n plaaslike variable
                      // sodat dit nie NULL is wanneer die Asset gebou word nie.
                      final finalId = _generateAndSetId();

                      // Trek Room ID uit
                      String roomId = "1";
                      if (selectedLocation != null && selectedLocation!.contains(":")) {
                        roomId = selectedLocation!.split(":").first;
                      }

                      final newAsset = Asset(
                        campus: selectedCampus ?? "Onbekend",
                        id: finalId,
                        name: name,
                        category: category,
                        location: roomId,
                        status: "Aktief",
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
}
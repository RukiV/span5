import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';

import '../reporting/select_location_page.dart';

class AddCampusPage extends StatefulWidget {
  const AddCampusPage({super.key});

  @override
  State<AddCampusPage> createState() => _AddCampusPageState();
}

class _AddCampusPageState extends State<AddCampusPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _streetNumController = TextEditingController();
  final _streetNameController = TextEditingController();
  final _suburbController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _countryController = TextEditingController();
  bool _isLoading = false;
  LatLng _selectedLocation = const LatLng(-25.8522, 28.1884);
  final TextEditingController _radiusController =
      TextEditingController(text: "110");

  InputDecoration _inputDecoration(String label) {
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
      suffixIcon: label == "Ligging"
          ? const Icon(Icons.map, color: AppColors.gold)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Voeg Nuwe Terrein",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Naam",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(""),
                  validator: (v) => v!.isEmpty ? "Vereis" : null,
                ),
                const SizedBox(height: 20),
                const Text("Tipe",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _typeController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(""),
                ),
                const SizedBox(height: 20),
                const Text("Ligging op Kaart",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final LatLng? result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectLocationPage(
                            initialLocation: _selectedLocation),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _selectedLocation = result;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.gold),
                        const SizedBox(width: 10),
                        Text(
                          "Lat: ${_selectedLocation.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(4)}",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        const Text("VERANDER",
                            style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Toegelate Radius (meter)",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _radiusController,
                  style: const TextStyle(fontSize: 14),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration(""),
                  validator: (v) {
                    final val = double.tryParse(v ?? "");
                    return (v == null || v.isEmpty || val == null || val <= 0)
                        ? "Geldige radius word vereis"
                        : null;
                  },
                ),
                const SizedBox(height: 20),
                const Text("Straatnommer",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _streetNumController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(""),
                ),
                const SizedBox(height: 20),
                const Text("Straatnaam",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _streetNameController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(""),
                ),
                const SizedBox(height: 20),
                const Text("Suburb",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _suburbController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(""),
                ),
                const SizedBox(height: 20),
                const Text("Stad",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _cityController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(""),
                ),
                const SizedBox(height: 20),
                const Text("Provinsie",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _provinceController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(""),
                ),
                const SizedBox(height: 20),
                const Text("Land",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                        fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _countryController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(""),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _isLoading = true);
                              final campus = Campus(
                                id: 0,
                                name: _nameController.text,
                                code: _typeController.text,
                                streetNum: _streetNumController.text,
                                streetName: _streetNameController.text,
                                suburb: _suburbController.text,
                                city: _cityController.text,
                                province: _provinceController.text,
                                country: _countryController.text,
                                location: _selectedLocation,
                                radius:
                                    double.tryParse(_radiusController.text) ??
                                        110,
                              );
                              final success =
                                  await CampusService.addCampus(campus);
                              if (!mounted) return;
                              setState(() => _isLoading = false);
                              if (success) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text("STOOR",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Kanselleer",
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

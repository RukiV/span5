import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import 'select_location_page.dart';

class AddCampusPage extends StatefulWidget {
  const AddCampusPage({super.key});

  @override
  State<AddCampusPage> createState() => _AddCampusPageState();
}

class _AddCampusPageState extends State<AddCampusPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _addressController = TextEditingController();
  final _roomsController = TextEditingController();
  LatLng _selectedLocation = const LatLng(-25.8522, 28.1884); // Centurion as default

  InputDecoration _buildCustomTextField(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF001F3F)),
      filled: true,
      fillColor: const Color(0xFFFEFBEA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF001F3F), fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Nuwe Kampus"),
        backgroundColor: const Color(0xFF001F3F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Kampus Besonderhede",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001F3F),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: _buildCustomTextField("Kampus Naam", Icons.business, hint: "bv. Centurion"),
                validator: (value) => value!.isEmpty ? "Naam word benodig" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: _buildCustomTextField("Kampus Kode (3 letters)", Icons.tag, hint: "bv. CEN"),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                validator: (value) => (value!.length != 3) ? "Kode moet 3 letters wees" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: _buildCustomTextField("Fisiese Adres", Icons.location_on),
                validator: (value) => value!.isEmpty ? "Adres word benodig" : null,
              ),
              const SizedBox(height: 24),
              const Text(
                "Lokale (Skei met komma)",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF001F3F)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _roomsController,
                decoration: _buildCustomTextField("Lokale", Icons.room_preferences, hint: "bv. K102, K105, Lab 1"),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.map, color: Color(0xFFD4AF37)),
                        SizedBox(width: 8),
                        Text(
                          "Geografiese Ligging",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF001F3F)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SelectLocationPage(initialLocation: _selectedLocation),
                          ),
                        );
                        if (result != null && result is LatLng) {
                          setState(() {
                            _selectedLocation = result;
                          });
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text("Kies op Kaart"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF001F3F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final List<String> rooms = _roomsController.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();

                      final newCampus = Campus(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: _nameController.text,
                        code: _codeController.text.toUpperCase(),
                        address: _addressController.text,
                        location: _selectedLocation,
                        rooms: rooms,
                      );

                      final success = await CampusService.addCampus(newCampus);
                      if (mounted) {
                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Kampus suksesvol bygevoeg"),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Kon nie kampus byvoeg nie. Probeer weer."),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001F3F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: const Text(
                    "REGISTREER KAMPUS",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

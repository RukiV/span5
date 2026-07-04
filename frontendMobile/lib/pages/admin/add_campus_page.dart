<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import '../../models/user_session.dart';
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
  bool _isLoading = false;
  LatLng _selectedLocation = const LatLng(-25.8522, 28.1884);

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
    return Stack(
      children: [
        Scaffold(
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
                  if (UserSession.isAdmin) ...[
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
                  ],
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
                  if (UserSession.isAdmin)
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
                      onPressed: _isLoading ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _isLoading = true);
                          try {
                            final List<String> rooms = _roomsController.text
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();

                            bool success = false;
                            if (UserSession.isAdmin) {
                              final newCampus = Campus(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                name: _nameController.text,
                                code: _codeController.text.toUpperCase(),
                                address: _addressController.text,
                                location: _selectedLocation,
                                rooms: rooms,
                              );

                              success = await CampusService.addCampus(newCampus);
                            } else {
                              final campus = CampusService.getCampusByName(UserSession.userCampus);
                              if (campus != null) {
                                success = await CampusService.updateRooms(campus.id, rooms);
                              }
                            }
                            
                            if (mounted && success) {
                              Navigator.pop(context);
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Fout met registrasie. Probeer weer.")),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001F3F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: Text(
                        UserSession.isAdmin ? "REGISTREER KAMPUS" : "VOEG LOKALE BY",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF001F3F)),
                      SizedBox(height: 16),
                      Text("Besig om te registreer...", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
=======
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import '../../models/user_session.dart';
import 'select_location_page.dart';

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
  final _zipIdController = TextEditingController(text: "1");
  bool _isLoading = false;
  LatLng _selectedLocation = const LatLng(-25.8522, 28.1884);

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.gold, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Voeg Nuwe Terrein", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  const Text("Naam", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration(""),
                    validator: (v) => v!.isEmpty ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),
                  const Text("Tipe", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _typeController,
                    decoration: _inputDecoration(""),
                  ),
                  const SizedBox(height: 20),
                  const Text("Straatnommer", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _streetNumController,
                    decoration: _inputDecoration(""),
                  ),
                  const SizedBox(height: 20),
                  const Text("Straatnaam", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _streetNameController,
                    decoration: _inputDecoration(""),
                  ),
                  const SizedBox(height: 20),
                  const Text("Poskode ID", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _zipIdController,
                    decoration: _inputDecoration(""),
                    keyboardType: TextInputType.number,
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
                        onPressed: _isLoading ? null : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isLoading = true);
                            final campus = Campus(
                              id: "0",
                              name: _nameController.text,
                              code: _typeController.text,
                              address: "${_streetNumController.text} ${_streetNameController.text}".trim(),
                              location: _selectedLocation,
                              rooms: [],
                            );
                            final success = await CampusService.addCampus(campus);
                            if (mounted) {
                              setState(() => _isLoading = false);
                              if (success) Navigator.pop(context);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5E34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Stoor"),
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
>>>>>>> 3080162a6b51675de2ce74fa53f3bd629f39db17

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';

class AddBuildingPage extends StatefulWidget {
  final Campus campus;
  const AddBuildingPage({super.key, required this.campus});

  @override
  State<AddBuildingPage> createState() => _AddBuildingPageState();
}

class _AddBuildingPageState extends State<AddBuildingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _streetNumController = TextEditingController();
  final _streetNameController = TextEditingController();
  String _type = 'other';
  bool _isLoading = false;

  final List<Map<String, String>> _types = [
    {'value': 'admin', 'label': 'Administrasie'},
    {'value': 'onderwys', 'label': 'Onderwys'},
    {'value': 'laboratory', 'label': 'Laboratorium'},
    {'value': 'warehouse', 'label': 'Pakhuis'},
    {'value': 'other', 'label': 'Ander'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _streetNumController.dispose();
    _streetNameController.dispose();
    super.dispose();
  }

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
        title: const Text("Voeg Nuwe Gebou", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  Text("Terrein: ${widget.campus.name}", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),

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
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: _inputDecoration(""),
                    items: _types.map((t) => DropdownMenuItem(
                      value: t['value'],
                      child: Text(t['label']!),
                    )).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 20),

                  const Text("Straatnommer (opsioneel)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _streetNumController,
                    decoration: _inputDecoration(""),
                  ),
                  const SizedBox(height: 20),

                  const Text("Straatnaam (opsioneel)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _streetNameController,
                    decoration: _inputDecoration(""),
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
                            final building = Building(
                              id: 0,
                              name: _nameController.text,
                              type: _type,
                              streetNum: _streetNumController.text,
                              streetName: _streetNameController.text,
                              locationId: widget.campus.id,
                            );
                            final success = await CampusService.addBuilding(building);
                            if (mounted) {
                              setState(() => _isLoading = false);
                              if (success) Navigator.pop(context, true);
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

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';

class EditCampusPage extends StatefulWidget {
  final Campus campus;
  const EditCampusPage({super.key, required this.campus});

  @override
  State<EditCampusPage> createState() => _EditCampusPageState();
}

class _EditCampusPageState extends State<EditCampusPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController _streetNumController;
  late TextEditingController _streetNameController;
  late TextEditingController _zipIdController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final parts = widget.campus.address.split(' ');
    _nameController = TextEditingController(text: widget.campus.name);
    _typeController = TextEditingController(text: widget.campus.code);
    _streetNumController = TextEditingController(text: parts.isNotEmpty ? parts[0] : "");
    _streetNameController = TextEditingController(text: parts.length > 1 ? parts.skip(1).join(' ') : "");
    _zipIdController = TextEditingController(text: "1"); // Default
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _streetNumController.dispose();
    _streetNameController.dispose();
    _zipIdController.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedCampus = widget.campus.copyWith(
      name: _nameController.text,
      code: _typeController.text,
      address: "${_streetNumController.text} ${_streetNameController.text}".trim(),
    );

    final success = await CampusService.updateCampus(updatedCampus);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Terrein suksesvol opgedateer"), backgroundColor: AppColors.successGreen),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kon nie opdateer nie. Probeer weer."), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Donker agtergrond soos in voorbeeld
      appBar: AppBar(
        title: const Text("Wysig Terrein", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold, // Bruinagtige kleur soos in prent
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Opdateer"),
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

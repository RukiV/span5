import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
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
  late TextEditingController _suburbController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _countryController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.campus.name);
    _typeController = TextEditingController(text: widget.campus.code);
    _streetNumController = TextEditingController(text: widget.campus.streetNum);
    _streetNameController = TextEditingController(text: widget.campus.streetName);
    _suburbController = TextEditingController(text: widget.campus.suburb);
    _cityController = TextEditingController(text: widget.campus.city);
    _provinceController = TextEditingController(text: widget.campus.province);
    _countryController = TextEditingController(text: widget.campus.country);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _streetNumController.dispose();
    _streetNameController.dispose();
    _suburbController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration() {
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.navy,
          fontSize: 13,
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedCampus = widget.campus.copyWith(
      name: _nameController.text,
      code: _typeController.text,
      streetNum: _streetNumController.text,
      streetName: _streetNameController.text,
      suburb: _suburbController.text,
      city: _cityController.text,
      province: _provinceController.text,
      country: _countryController.text,
    );

    final success = await CampusService.updateCampus(updatedCampus);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true); // Stuur true terug vir verfrissing
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
      backgroundColor: const Color(0xFF0F172A),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel("Naam"),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(),
                    validator: (v) => v!.isEmpty ? "Vereis" : null,
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("Tipe / Kode"),
                  TextFormField(
                    controller: _typeController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(),
                    validator: (v) => v!.isEmpty ? "Vereis" : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel("Nr"),
                            TextFormField(
                              controller: _streetNumController,
                              style: const TextStyle(fontSize: 14),
                              decoration: _inputDecoration(),
                              validator: (v) => v!.isEmpty ? "Vereis" : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel("Straatnaam"),
                            TextFormField(
                              controller: _streetNameController,
                              style: const TextStyle(fontSize: 14),
                              decoration: _inputDecoration(),
                              validator: (v) => v!.isEmpty ? "Vereis" : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("Suburb"),
                  TextFormField(
                    controller: _suburbController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("Stad"),
                  TextFormField(
                    controller: _cityController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("Provinsie"),
                  TextFormField(
                    controller: _provinceController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel("Land"),
                  TextFormField(
                    controller: _countryController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Kanselleer", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("OPDATEER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
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

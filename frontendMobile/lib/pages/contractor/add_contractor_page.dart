import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/contractor_service.dart';
import '../../models/contractor.dart';

class AddContractorPage extends StatefulWidget {
  const AddContractorPage({super.key});

  @override
  State<AddContractorPage> createState() => _AddContractorPageState();
}

class _AddContractorPageState extends State<AddContractorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _typeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final contractor = Contractor(
      id: 0,
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      type: _typeController.text.trim(),
    );

    final success = await ContractorService.addContractor(contractor);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kontrakteur suksesvol bygevoeg"), backgroundColor: AppColors.successGreen),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kon nie kontrakteur byvoeg nie"), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("VOEG KONTRAKTEUR BY"),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(_nameController, "Naam", Icons.person, true),
                  const SizedBox(height: 15),
                  _buildTextField(_surnameController, "Van", Icons.person_outline, true),
                  const SizedBox(height: 15),
                  _buildTextField(_emailController, "E-pos", Icons.email, true, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  _buildTextField(_phoneController, "Telefoonnommer", Icons.phone, false, keyboardType: TextInputType.phone),
                  const SizedBox(height: 15),
                  _buildTextField(_typeController, "Tipe (bv. Loodgieter)", Icons.build, false),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("STAAR KONTRAKTEUR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool required, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.navy),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return "$label is verpligtend";
        }
        if (label == "E-pos" && value != null && value.isNotEmpty) {
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return "Voer 'n geldige e-pos adres in";
          }
        }
        return null;
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/contractor_service.dart';
import '../../models/contractor.dart';

class EditContractorPage extends StatefulWidget {
  final Contractor contractor;
  const EditContractorPage({super.key, required this.contractor});

  @override
  State<EditContractorPage> createState() => _EditContractorPageState();
}

class _EditContractorPageState extends State<EditContractorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _surnameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _typeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contractor.name);
    _surnameController = TextEditingController(text: widget.contractor.surname);
    _emailController = TextEditingController(text: widget.contractor.email);
    _phoneController = TextEditingController(text: widget.contractor.phone ?? '');
    _typeController = TextEditingController(text: widget.contractor.type ?? '');
  }

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
    
    final updatedContractor = widget.contractor.copyWith(
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      type: _typeController.text.trim(),
    );

    final success = await ContractorService.updateContractor(updatedContractor);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kontrakteur suksesvol opgedateer"), backgroundColor: AppColors.successGreen),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kon nie kontrakteur opdateer nie"), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("WYSIG KONTRAKTEUR"),
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
                      child: const Text("UPDATEER KONTRAKTEUR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

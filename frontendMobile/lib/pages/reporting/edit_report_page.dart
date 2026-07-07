import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../models/report.dart';
import '../../widgets/searchable_dropdown.dart';

class EditReportPage extends StatefulWidget {
  final Report report;

  const EditReportPage({super.key, required this.report});

  @override
  State<EditReportPage> createState() => _EditReportPageState();
}

class _EditReportPageState extends State<EditReportPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _category;
  late String _priority;
  late String _status;
  bool _isLoading = false;

  final List<String> _categories = ["Herstel", "Instandhouding", "Opgradering", "Algemeen"];
  final List<String> _priorities = ["Laag", "Medium", "Hoog"];
  final List<String> _statuses = ["Ontvang", "Besig", "Voltooi", "Geweier", "Oop", "Bevestig", "Opgelos", "Verwerp"];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.report.title);
    _descriptionController = TextEditingController(text: widget.report.description);
    _category = _categories.contains(widget.report.category) ? widget.report.category : "Algemeen";
    _priority = widget.report.priority;
    _status = widget.report.phase;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updatedReport = widget.report.copyWith(
      title: _titleController.text,
      description: _descriptionController.text,
      category: _category,
      priority: _priority,
      phase: _status,
    );

    final success = await ReportService.updateReport(updatedReport);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foutkaartjie suksesvol opgedateer"), backgroundColor: AppColors.successGreen),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kon nie foutkaartjie opdateer nie"), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Wysig Kaartjie #${widget.report.id}"),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField("Titel", _titleController),
                    const SizedBox(height: 20),
                    _buildDropdown("Kategorie", _category, _categories, (val) => setState(() => _category = val!)),
                    const SizedBox(height: 20),
                    _buildDropdown("Prioriteit", _priority, _priorities, (val) => setState(() => _priority = val!)),
                    const SizedBox(height: 20),
                    _buildDropdown("Status", _status, _statuses, (val) => setState(() => _status = val!)),
                    const SizedBox(height: 20),
                    _buildTextField("Beskrywing", _descriptionController, maxLines: 5),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.terracotta,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("OPDATEER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
          validator: (value) => value == null || value.isEmpty ? "Verpligtend" : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return SearchableDropdown<String>(
      label: label,
      hint: "Kies $label",
      value: value,
      items: items.map((e) => SearchableDropdownItem(value: e, label: e)).toList(),
      onChanged: onChanged,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/input_decoration.dart';
import '../../models/campus.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../widgets/view_edit_scaffold.dart';
import '../reporting/select_location_page.dart';

class CampusFormPage extends StatefulWidget {
  final Campus? campus;

  const CampusFormPage({super.key, this.campus});

  @override
  State<CampusFormPage> createState() => _CampusFormPageState();
}

class _CampusFormPageState extends State<CampusFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _streetNumController;
  late final TextEditingController _streetNameController;
  late final TextEditingController _suburbController;
  late final TextEditingController _cityController;
  late final TextEditingController _provinceController;
  late final TextEditingController _countryController;
  late final TextEditingController _radiusController;
  late LatLng _selectedLocation;

  bool get _isCreate => widget.campus == null;

  @override
  void initState() {
    super.initState();
    final campus = widget.campus;
    _nameController = TextEditingController(text: campus?.name ?? "");
    _typeController = TextEditingController(text: campus?.code ?? "");
    _streetNumController = TextEditingController(text: campus?.streetNum ?? "");
    _streetNameController =
        TextEditingController(text: campus?.streetName ?? "");
    _suburbController = TextEditingController(text: campus?.suburb ?? "");
    _cityController = TextEditingController(text: campus?.city ?? "");
    _provinceController = TextEditingController(text: campus?.province ?? "");
    _countryController = TextEditingController(text: campus?.country ?? "");
    _selectedLocation = campus?.location ?? const LatLng(-25.8522, 28.1884);
    _radiusController =
        TextEditingController(text: campus?.radius.toStringAsFixed(0) ?? "110");
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
    _radiusController.dispose();
    super.dispose();
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

  Widget _buildTextField(TextEditingController controller, String label,
      {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 14),
          decoration: appInputDecoration(showErrorBorder: !_isCreate),
          validator: required ? (v) => v!.isEmpty ? "Vereis" : null : null,
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel("Ligging op Kaart"),
        InkWell(
          onTap: () async {
            final LatLng? result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SelectLocationPage(initialLocation: _selectedLocation),
              ),
            );
            if (result != null) {
              setState(() {
                _selectedLocation = result;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Lat: ${_selectedLocation.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(4)}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const Text("VERANDER",
                    style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isCreate) {
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
        radius: double.tryParse(_radiusController.text) ?? 110,
      );
      final success = await CampusService.addCampus(campus);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
      }
      return;
    }

    final updatedCampus = widget.campus!.copyWith(
      name: _nameController.text,
      code: _typeController.text,
      streetNum: _streetNumController.text,
      streetName: _streetNameController.text,
      suburb: _suburbController.text,
      city: _cityController.text,
      province: _provinceController.text,
      country: _countryController.text,
      location: _selectedLocation,
      radius: double.tryParse(_radiusController.text) ?? widget.campus!.radius,
    );

    final success = await CampusService.updateCampus(updatedCampus);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Terrein suksesvol opgedateer"),
            backgroundColor: AppColors.successGreen),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Kon nie opdateer nie. Probeer weer."),
            backgroundColor: AppColors.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final campus = widget.campus;

    return ViewEditScaffold(
      alwaysEditable: _isCreate,
      title: _isCreate ? "Voeg Nuwe Terrein" : (campus?.name ?? ""),
      editingTitle: _isCreate ? null : "Wysig Terrein",
      saveLabel: _isCreate ? "STOOR" : "OPDATEER",
      canEdit: UserSession.can('locations.manage'),
      formKey: _formKey,
      onSave: _save,
      child: Column(
        children: [
          _buildTextField(_nameController, "Naam", required: true),
          const SizedBox(height: 16),
          _buildTextField(_typeController, _isCreate ? "Tipe" : "Tipe / Kode",
              required: true),
          const SizedBox(height: 16),
          _buildLocationPicker(),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel("Toegelate Radius (meter)"),
              TextFormField(
                controller: _radiusController,
                style: const TextStyle(fontSize: 14),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: appInputDecoration(showErrorBorder: !_isCreate),
                validator: (v) {
                  final val = double.tryParse(v ?? "");
                  return (v == null || v.isEmpty || val == null || val <= 0)
                      ? "Geldige radius word vereis"
                      : null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child:
                    _buildTextField(_streetNumController, "Nr", required: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildTextField(_streetNameController, "Straatnaam",
                    required: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(_suburbController, "Suburb"),
          const SizedBox(height: 16),
          _buildTextField(_cityController, "Stad"),
          const SizedBox(height: 16),
          _buildTextField(_provinceController, "Provinsie"),
          const SizedBox(height: 16),
          _buildTextField(_countryController, "Land"),
        ],
      ),
    );
  }
}

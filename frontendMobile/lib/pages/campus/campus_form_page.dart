import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/idempotency.dart';
import '../../models/campus.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../services/ai_service.dart';
import '../../widgets/view_edit_scaffold.dart';
import '../../widgets/labeled_form_field.dart';
import '../../widgets/ai_suggestions_panel.dart';
import '../reporting/select_location_page.dart';

class CampusFormPage extends StatefulWidget {
  final Campus? campus;
  final bool startEditing;

  const CampusFormPage({
    super.key,
    this.campus,
    this.startEditing = false,
  });

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
  String? _idempotencyKey;

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

    if (_isCreate) {
      _idempotencyKey = Idempotency.generate();
    }
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

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ligging op Kaart",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.navy)),
        const SizedBox(height: 8),
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
      final success = await CampusService.addCampus(campus,
          idempotencyKey: _idempotencyKey);
      if (!mounted) return;
      if (success) {
        _idempotencyKey = Idempotency.generate();
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

  /// Die vorm se huidige veldwaardes vir die AI-konteks.
  Map<String, dynamic> _currentCampusFields() => {
        'location_name': _nameController.text,
        'location_type': _typeController.text,
        'location_streetnum': _streetNumController.text,
        'location_streetname': _streetNameController.text,
        'location_suburb': _suburbController.text,
        'location_city': _cityController.text,
        'location_province': _provinceController.text,
        'location_country': _countryController.text,
      };

  /// Pas 'n AI-voorstel (tipe/voorstad/stad/provinsie/land) toe.
  void _applyCampusGhost(String key, AiSuggestion s) {
    final value = s.value;
    setState(() {
      switch (key) {
        case 'location_type':
          _typeController.text = value;
        case 'location_suburb':
          _suburbController.text = value;
        case 'location_city':
          _cityController.text = value;
        case 'location_province':
          _provinceController.text = value;
        case 'location_country':
          _countryController.text = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final campus = widget.campus;

    return ViewEditScaffold(
      alwaysEditable: _isCreate,
      startEditing: widget.startEditing,
      title: _isCreate ? "Nuwe Terrein" : (campus?.name ?? ""),
      editingTitle: _isCreate ? null : "Wysig Terrein",
      saveLabel: _isCreate ? "STOOR" : "OPDATEER",
      canEdit: UserSession.can('locations.manage'),
      formKey: _formKey,
      onSave: _save,
      showCancel: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiSuggestionsPanel(
            context: 'location',
            fields: _currentCampusFields(),
            labels: const {
              'location_type': 'Terrein tipe',
              'location_suburb': 'Voorstad',
              'location_city': 'Stad',
              'location_province': 'Provinsie',
              'location_country': 'Land',
            },
            onUse: (key, s) => _applyCampusGhost(key, s),
          ),
          LabeledFormField(
            label: "Naam",
            controller: _nameController,
            showErrorBorder: !_isCreate,
            onChanged: (_) => setState(() {}),
            validator: (v) => (v == null || v.trim().isEmpty) ? "Vereis" : null,
          ),
          const SizedBox(height: 20),
          LabeledFormField(
            label: _isCreate ? "Tipe" : "Tipe / Kode",
            controller: _typeController,
            showErrorBorder: !_isCreate,
            onChanged: (_) => setState(() {}),
            validator: (v) => (v == null || v.trim().isEmpty) ? "Vereis" : null,
          ),
          const SizedBox(height: 20),
          _buildLocationPicker(),
          const SizedBox(height: 20),
          LabeledFormField(
            label: "Toegelate Radius (meter)",
            controller: _radiusController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            showErrorBorder: !_isCreate,
            validator: (v) {
              final val = double.tryParse(v ?? "");
              return (v == null || v.isEmpty || val == null || val <= 0)
                  ? "Geldige radius word vereis"
                  : null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: LabeledFormField(
                  label: "Nr",
                  controller: _streetNumController,
                  showErrorBorder: !_isCreate,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Vereis" : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: LabeledFormField(
                  label: "Straatnaam",
                  controller: _streetNameController,
                  showErrorBorder: !_isCreate,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Vereis" : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LabeledFormField(
            label: "Suburb",
            controller: _suburbController,
            showErrorBorder: !_isCreate,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          LabeledFormField(
            label: "Stad",
            controller: _cityController,
            showErrorBorder: !_isCreate,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          LabeledFormField(
            label: "Provinsie",
            controller: _provinceController,
            showErrorBorder: !_isCreate,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          LabeledFormField(
            label: "Land",
            controller: _countryController,
            showErrorBorder: !_isCreate,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

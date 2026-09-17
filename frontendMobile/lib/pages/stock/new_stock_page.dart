import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../models/user_session.dart';
import '../../models/stock.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/ai_suggestions_panel.dart';
import '../../widgets/mobile_ghost_overlay.dart';
import '../../services/ai_service.dart';
import '../../core/app_colors.dart';

class NewStockPage extends StatefulWidget {
  const NewStockPage({super.key});

  @override
  State<NewStockPage> createState() => _NewStockPageState();
}

class _NewStockPageState extends State<NewStockPage> {
  final _formKey = GlobalKey<FormState>();

  String brand = "";
  String name = "";
  int amount = 0;
  int minimum = 0;
  int boxTotal = 0;
  String type = "Ander";
  String description = "";
  int? _campusId;
  int? _buildingId;
  int? _roomId;
  String? _locationError;
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _typeController = TextEditingController()..text = "Ander";
  Map<String, AiSuggestion> _ghosts = {};

  Map<String, String> _currentStockFields() => {
        'stock_name': name,
        'stock_type': type,
        'stock_brand': brand,
      };

  void _applyStockGhost(String key, AiSuggestion s) {
    switch (key) {
      case 'stock_name':
        _nameController.text = s.value;
        name = s.value;
        break;
      case 'stock_brand':
        _brandController.text = s.value;
        brand = s.value;
        break;
      case 'stock_type':
        _typeController.text = s.value;
        type = s.value;
        break;
    }
    setState(() {});
  }

  void _onLocationChanged(int? campusId, int? buildingId, int? roomId) {
    setState(() {
      _campusId = campusId;
      _buildingId = buildingId;
      _roomId = roomId;
      if (roomId != null) _locationError = null;
    });
  }

  @override
  void initState() {
    super.initState();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(_autoSelectCampus);
    });
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    _nameController.dispose();
    _brandController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  /// Kies die gebruiker se eie terrein outomaties sodra die kampusdata beskikbaar
  /// is. Hardloop weer deur die notifier-luisteraar as die data laat aankom.
  void _autoSelectCampus() {
    if (_campusId != null) return;
    try {
      _campusId = CampusService.campusesNotifier.value
          .firstWhere((c) =>
              c.name == UserSession.userCampus ||
              UserSession.userCampus.contains(c.name))
          .id;
    } catch (_) {
      if (CampusService.campusesNotifier.value.isNotEmpty) {
        _campusId = CampusService.campusesNotifier.value.first.id;
      }
    }
  }

  void _onCampusesChanged() {
    if (!mounted) return;
    setState(_autoSelectCampus);
  }

  Widget _buildBreadcrumbs() {
    if (_campusId == null) return const SizedBox.shrink();

    final campus = CampusService.campusesNotifier.value
        .where((c) => c.id == _campusId)
        .firstOrNull;
    if (campus == null) return const SizedBox.shrink();

    String path = campus.name;

    if (_buildingId != null) {
      final building =
          campus.buildings.where((b) => b.id == _buildingId).firstOrNull;
      if (building != null) {
        path += " > ${building.name}";
        if (_roomId != null) {
          final room =
              building.rooms?.where((r) => r.id == _roomId).firstOrNull;
          if (room != null) {
            path += " > ${room.name}";
          }
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.navy, fontSize: 14),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
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
    );
  }

  Widget _buildField(String label, Function(String) onSet, {int maxLines = 1}) {
    return TextFormField(
      maxLines: maxLines,
      decoration: _inputDecoration(label),
      onChanged: onSet,
      validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
    );
  }

  Widget _buildNumberField(String label, Function(String) onSet) {
    return TextFormField(
      keyboardType: TextInputType.number,
      decoration: _inputDecoration(label),
      onChanged: onSet,
      validator: (v) =>
          (v == null || int.tryParse(v) == null) ? "Vereis" : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Nuwe Voorraad",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: withSuggestionGhost(
                          _inputDecoration("Naam"),
                          ghost: _ghosts['stock_name']?.value,
                          active: name.isEmpty,
                          onAccept: () => _applyStockGhost(
                              'stock_name', _ghosts['stock_name']!),
                        ),
                        onChanged: (v) {
                          name = v;
                          setState(() {});
                        },
                        validator: (v) =>
                            (v == null || v.isEmpty) ? "Vereis" : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: withSuggestionGhost(
                          _inputDecoration("Handelsmerk"),
                          ghost: _ghosts['stock_brand']?.value,
                          active: brand.isEmpty,
                          onAccept: () => _applyStockGhost(
                              'stock_brand', _ghosts['stock_brand']!),
                        ),
                        onChanged: (v) {
                          brand = v;
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _typeController,
                        decoration: withSuggestionGhost(
                          _inputDecoration("Tipe"),
                          ghost: _ghosts['stock_type']?.value,
                          active: type.isEmpty,
                          onAccept: () => _applyStockGhost(
                              'stock_type', _ghosts['stock_type']!),
                        ),
                        onChanged: (v) {
                          type = v;
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                          "Hoeveelheid", (v) => amount = int.tryParse(v) ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField("Minimum Voorraad",
                          (v) => minimum = int.tryParse(v) ?? 0),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField("Boks Totaal",
                          (v) => boxTotal = int.tryParse(v) ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LocationCascadePicker(
                  initialCampusId: _campusId,
                  initialBuildingId: _buildingId,
                  initialRoomId: _roomId,
                  errorText: _locationError,
                  onChanged: _onLocationChanged,
                ),
                const SizedBox(height: 20),
                _buildField("Beskrywing", (v) => description = v, maxLines: 3),
                const SizedBox(height: 16),
                AiSuggestionsPanel(
                  context: 'stock',
                  fields: _currentStockFields(),
                  labels: const {
                    'stock_name': 'Naam',
                    'stock_type': 'Tipe',
                    'stock_brand': 'Handelsmerk',
                  },
                  onSuggestionsChanged: (s) => setState(() => _ghosts = s),
                  onUse: (key, s) => _applyStockGhost(key, s),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_roomId == null) {
                        setState(
                            () => _locationError = "Kies 'n volledige ligging");
                        return;
                      }
                      if (_formKey.currentState!.validate()) {
                        final newStock = Stock(
                          name: name,
                          brand: brand,
                          amount: amount,
                          minimum: minimum,
                          boxTotal: boxTotal,
                          type: type,
                          description: description,
                          roomId: _roomId,
                        );

                        final success = await StockService.addStock(newStock);
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("STOOR VOORRAAD",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Kanselleer",
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

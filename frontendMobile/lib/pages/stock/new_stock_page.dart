import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../models/user_session.dart';
import '../../models/stock.dart';
import '../../widgets/location_cascade_picker.dart';

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
    super.dispose();
  }

  /// Kies die gebruiker se eie terrein outomaties sodra die kampusdata beskikbaar
  /// is. Hardloop weer deur die notifier-luisteraar as die data laat aankom.
  void _autoSelectCampus() {
    if (_campusId != null) return;
    try {
      _campusId = CampusService.campusesNotifier.value
          .firstWhere((c) => c.name == UserSession.userCampus || UserSession.userCampus.contains(c.name))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Nuwe Voorraad", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildField("Naam", (v) => name = v),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildField("Merk", (v) => brand = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField("Tipe", (v) => type = v),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildNumberField("Hoeveelheid", (v) => amount = int.tryParse(v) ?? 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField("Minimum Voorraad", (v) => minimum = int.tryParse(v) ?? 0),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildNumberField("Boks Totaal", (v) => boxTotal = int.tryParse(v) ?? 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LocationCascadePicker(
                    label: "Ligging *",
                    initialCampusId: _campusId,
                    initialBuildingId: _buildingId,
                    initialRoomId: _roomId,
                    errorText: _locationError,
                    onChanged: _onLocationChanged,
                  ),
                  const SizedBox(height: 20),
                  _buildField("Beskrywing", (v) => description = v, maxLines: 3),
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
                        onPressed: () async {
                          if (_roomId == null) {
                            setState(() => _locationError = "Kies 'n volledige ligging");
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
                             if (!mounted) return;
                             if (success) {
                               if (context.mounted) {
                                 Navigator.pop(context);
                               }
                             }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5E34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Stoor"),
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

  Widget _buildField(String label, Function(String) onSet, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          maxLines: maxLines,
          decoration: _inputDecoration(),
          onChanged: onSet,
          validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, Function(String) onSet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(),
          onChanged: onSet,
          validator: (v) => (v == null || int.tryParse(v) == null) ? "Vereis" : null,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }
}

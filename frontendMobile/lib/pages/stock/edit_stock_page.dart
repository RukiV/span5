import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../models/stock.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../core/app_colors.dart';

class EditStockPage extends StatefulWidget {
  final Stock stock;

  const EditStockPage({super.key, required this.stock});

  @override
  State<EditStockPage> createState() => _EditStockPageState();
}

class _EditStockPageState extends State<EditStockPage> {
  final _formKey = GlobalKey<FormState>();

  late String brand;
  late String name;
  late int amount;
  late int minimum;
  late int boxTotal;
  late String type;
  late String description;
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

  void _resolveRoomPath(int roomId) {
    for (final campus in CampusService.campusesNotifier.value) {
      for (final building in campus.buildings) {
        for (final room in building.rooms ?? const []) {
          if (room.id == roomId) {
            _campusId = campus.id;
            _buildingId = building.id;
            _roomId = room.id;
            return;
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final s = widget.stock;
    brand = s.brand;
    name = s.name;
    amount = s.amount;
    minimum = s.minimum;
    boxTotal = s.boxTotal;
    type = s.type;
    description = s.description ?? "";

    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    CampusService.campusesNotifier.addListener(_onCampusesChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          if (s.roomId != null) {
            _resolveRoomPath(s.roomId!);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    super.dispose();
  }

  void _onCampusesChanged() {
    if (!mounted) return;
    setState(() {
      if (widget.stock.roomId != null && _campusId == null) {
        _resolveRoomPath(widget.stock.roomId!);
      }
    });
  }

  Widget _buildBreadcrumbs() {
    if (_campusId == null) return const SizedBox.shrink();

    final campus = CampusService.campusesNotifier.value
        .where((c) => c.id == _campusId)
        .firstOrNull;
    if (campus == null) return const SizedBox.shrink();

    String path = campus.name;

    if (_buildingId != null) {
      final building = campus.buildings.where((b) => b.id == _buildingId).firstOrNull;
      if (building != null) {
        path += " > ${building.name}";
        if (_roomId != null) {
          final room = building.rooms?.where((r) => r.id == _roomId).firstOrNull;
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
          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.gold),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: const Text("Wysig Voorraad",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(),
                Row(
                  children: [
                    Expanded(
                      child: _buildField("Naam", (v) => name = v, initialValue: name),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField("Merk", (v) => brand = v, initialValue: brand),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildField("Tipe", (v) => type = v, initialValue: type),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField("Hoeveelheid",
                          (v) => amount = int.tryParse(v) ?? 0,
                          initialValue: amount.toString()),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField("Minimum Voorraad",
                          (v) => minimum = int.tryParse(v) ?? 0,
                          initialValue: minimum.toString()),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField("Boks Totaal",
                          (v) => boxTotal = int.tryParse(v) ?? 0,
                          initialValue: boxTotal.toString()),
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
                _buildField("Beskrywing", (v) => description = v,
                    initialValue: description, maxLines: 3),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_roomId == null) {
                        setState(() => _locationError = "Kies 'n volledige ligging");
                        return;
                      }
                      if (_formKey.currentState!.validate()) {
                        final updated = Stock(
                          id: widget.stock.id,
                          name: name,
                          brand: brand,
                          amount: amount,
                          minimum: minimum,
                          boxTotal: boxTotal,
                          type: type,
                          description: description,
                          roomId: _roomId,
                        );

                        final success = await StockService.updateStock(updated);
                        if (!mounted) return;
                        if (success) {
                          Navigator.pop(context, true);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: const Text("OPDATEER VOORRAAD",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Kanselleer",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, Function(String) onSet,
      {int maxLines = 1, String? initialValue}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          maxLines: maxLines,
          decoration: _inputDecoration(),
          onChanged: onSet,
          validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, Function(String) onSet,
      {String? initialValue}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(),
          onChanged: onSet,
          validator: (v) =>
              (v == null || int.tryParse(v) == null) ? "Vereis" : null,
        ),
      ],
    );
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    );
  }
}


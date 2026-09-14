import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';
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

  Widget _buildField(String label, Function(String) onSet,
      {int maxLines = 1, String? initialValue}) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      decoration: _inputDecoration(label),
      onChanged: onSet,
      validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
    );
  }

  Widget _buildNumberField(String label, Function(String) onSet,
      {String? initialValue}) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      decoration: _inputDecoration(label),
      onChanged: onSet,
      validator: (v) =>
          (v == null || int.tryParse(v) == null) ? "Vereis" : null,
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder voorraad"),
        content: Text("Is jy seker jy wil '${widget.stock.name}' verwyder?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Kanselleer"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Verwyder"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final id = widget.stock.id;
    if (id == null) return;
    final success = await StockService.deleteStock(id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie die voorraad verwyder nie."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Wysig Voorraad",
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
                      child: _buildField("Naam", (v) => name = v,
                          initialValue: name),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField("Handelsmerk", (v) => brand = v,
                          initialValue: brand),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildField("Tipe", (v) => type = v,
                          initialValue: type),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                          "Hoeveelheid", (v) => amount = int.tryParse(v) ?? 0,
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
                      child: _buildNumberField(
                          "Boks Totaal", (v) => boxTotal = int.tryParse(v) ?? 0,
                          initialValue: boxTotal.toString()),
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
                _buildField("Beskrywing", (v) => description = v,
                    initialValue: description, maxLines: 3),
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
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context, true);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("OPDATEER VOORRAAD",
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
                const SizedBox(height: 8),
                if (UserSession.can('stock.manage'))
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => _confirmDelete(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: const Text("VERWYDER VOORRAAD",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1)),
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

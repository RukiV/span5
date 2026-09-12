import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/input_decoration.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../widgets/location_breadcrumbs.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/view_edit_scaffold.dart';
import '../../widgets/confirm_delete.dart';

class StockFormPage extends StatefulWidget {
  final Stock? stock;

  const StockFormPage({super.key, this.stock});

  @override
  State<StockFormPage> createState() => _StockFormPageState();
}

class _StockFormPageState extends State<StockFormPage> {
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

  bool get _isCreate => widget.stock == null;

  @override
  void initState() {
    super.initState();
    final s = widget.stock;
    name = s?.name ?? "";
    brand = s?.brand ?? "";
    amount = s?.amount ?? 0;
    minimum = s?.minimum ?? 0;
    boxTotal = s?.boxTotal ?? 0;
    type = s?.type ?? "Ander";
    description = s?.description ?? "";

    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    CampusService.campusesNotifier.addListener(_onCampusesChanged);

    if (_isCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_autoSelectCampus);
      });
    } else {
      final roomId = s!.roomId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            if (roomId != null) {
              _resolveRoomPath(roomId);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    super.dispose();
  }

  void _autoSelectCampus() {
    if (_campusId != null) return;
    try {
      _campusId = CampusService.campusesNotifier.value
          .firstWhere((c) => c.id == UserSession.locationId)
          .id;
    } catch (_) {
      if (CampusService.campusesNotifier.value.isNotEmpty) {
        _campusId = CampusService.campusesNotifier.value.first.id;
      }
    }
  }

  void _onCampusesChanged() {
    if (!mounted) return;
    setState(() {
      if (_isCreate) {
        _autoSelectCampus();
      } else if (widget.stock!.roomId != null && _campusId == null) {
        _resolveRoomPath(widget.stock!.roomId!);
      }
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

  void _onLocationChanged(int? campusId, int? buildingId, int? roomId) {
    setState(() {
      _campusId = campusId;
      _buildingId = buildingId;
      _roomId = roomId;
      if (roomId != null) _locationError = null;
    });
  }

  Widget _breadcrumbs() {
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

    return LocationBreadcrumbs(path: path);
  }

  Widget _buildField(String label, String initial, Function(String) onSet,
      {int maxLines = 1}) {
    return TextFormField(
      initialValue: initial.isEmpty ? null : initial,
      maxLines: maxLines,
      decoration: appInputDecoration(label: label),
      onChanged: onSet,
      validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
    );
  }

  Widget _buildNumberField(
      String label, String initial, Function(String) onSet) {
    return TextFormField(
      initialValue: initial.isEmpty ? null : initial,
      keyboardType: TextInputType.number,
      decoration: appInputDecoration(label: label),
      onChanged: onSet,
      validator: (v) =>
          (v == null || int.tryParse(v) == null) ? "Vereis" : null,
    );
  }

  Future<void> _save() async {
    if (_roomId == null) {
      setState(() => _locationError = "Kies 'n volledige ligging");
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_isCreate) {
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
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kon nie die voorraad byvoeg nie."),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    final updated = Stock(
      id: widget.stock!.id,
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie opdateer nie."),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final id = widget.stock!.id;
    if (id == null) return;
    await confirmDeleteAndRun(
      context,
      entityLabel: 'voorraad',
      itemName: widget.stock!.name,
      delete: () => StockService.deleteStock(id),
      onSuccess: () => Navigator.pop(context, true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stock;
    final isCreate = _isCreate;

    return ViewEditScaffold(
      alwaysEditable: true,
      title: isCreate ? "Nuwe Voorraad" : "Wysig Voorraad",
      saveLabel: isCreate ? "STOOR VOORRAAD" : "OPDATEER VOORRAAD",
      showSaveSpinner: false,
      saveLetterSpacing: 1,
      formKey: _formKey,
      onSave: _save,
      deleteButton: isCreate || !UserSession.can('stock.manage')
          ? null
          : SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: const Text("VERWYDER VOORRAAD",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _breadcrumbs(),
          Row(
            children: [
              Expanded(
                child: _buildField("Naam", s?.name ?? "", (v) => name = v),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildField(
                    "Handelsmerk", s?.brand ?? "", (v) => brand = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildField("Tipe", s?.type ?? "", (v) => type = v),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildNumberField(
                    "Hoeveelheid",
                    s?.amount.toString() ?? '',
                    (v) => amount = int.tryParse(v) ?? 0),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                    "Minimum Voorraad",
                    s?.minimum.toString() ?? '',
                    (v) => minimum = int.tryParse(v) ?? 0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildNumberField(
                    "Boks Totaal",
                    s?.boxTotal.toString() ?? '',
                    (v) => boxTotal = int.tryParse(v) ?? 0),
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
          _buildField(
              "Beskrywing", s?.description ?? "", (v) => description = v,
              maxLines: 3),
        ],
      ),
    );
  }
}

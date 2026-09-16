import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/idempotency.dart';
import '../../core/input_decoration.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../widgets/location_breadcrumbs.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/view_edit_scaffold.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/ai_suggestions_panel.dart';
import '../../widgets/ghost_overlay.dart';
import '../../services/ai_service.dart';

class StockFormPage extends StatefulWidget {
  final Stock? stock;
  final bool startEditing;

  const StockFormPage({super.key, this.stock, this.startEditing = false});

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
  String? _idempotencyKey;

  late final _nameController = TextEditingController(text: "");
  late final _brandController = TextEditingController(text: "");
  late final _typeController = TextEditingController(text: "");

  /// AI-voorstelle (spookteks) wat tans op die vorm van toepassing is.
  Map<String, AiSuggestion> _ghosts = {};

  bool get _isCreate => widget.stock == null;

  @override
  void initState() {
    super.initState();
    final s = widget.stock;
    name = s?.name ?? "";
    _nameController.text = name;
    brand = s?.brand ?? "";
    _brandController.text = brand;
    amount = s?.amount ?? 0;
    minimum = s?.minimum ?? 0;
    boxTotal = s?.boxTotal ?? 0;
    type = s?.type ?? "Ander";
    _typeController.text = type;
    description = s?.description ?? "";

    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    CampusService.campusesNotifier.addListener(_onCampusesChanged);

    if (_isCreate) {
      _idempotencyKey = Idempotency.generate();
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
    _nameController.dispose();
    _brandController.dispose();
    _typeController.dispose();
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
    final path = CampusService.findRoomPath(roomId);
    _campusId = path.campus?.id;
    _buildingId = path.building?.id;
    _roomId = path.room?.id;
  }

  void _onLocationChanged(int? campusId, int? buildingId, int? roomId) {
    setState(() {
      _campusId = campusId;
      _buildingId = buildingId;
      _roomId = roomId;
      if (roomId != null) _locationError = null;
    });
  }

  /// Die vorm se huidige veldwaardes vir die AI-konteks.
  Map<String, String> _currentStockFields() => {
        'stock_name': name,
        'stock_type': type,
        'stock_brand': brand,
      };

  /// Pas 'n voorstel toe — via 'n spookknoppie ✓ of die paneel se "Gebruik".
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

  Widget _breadcrumbs() {
    return LocationBreadcrumbs(
        path: LocationBreadcrumbs.buildLocationPath(
            campusId: _campusId, buildingId: _buildingId, roomId: _roomId));
  }

  Widget _buildField(String label, String initial, Function(String) onSet,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.navy)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initial.isEmpty ? null : initial,
          maxLines: maxLines,
          decoration: appInputDecoration(),
          onChanged: onSet,
          validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
        ),
      ],
    );
  }

  Widget _buildNumberField(
      String label, String initial, Function(String) onSet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.navy)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initial.isEmpty ? null : initial,
          keyboardType: TextInputType.number,
          decoration: appInputDecoration(),
          onChanged: onSet,
          validator: (v) =>
              (v == null || int.tryParse(v) == null) ? "Vereis" : null,
        ),
      ],
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
      final success = await StockService.addStock(newStock,
          idempotencyKey: _idempotencyKey);
      if (!mounted) return;
      if (success) {
        _idempotencyKey = Idempotency.generate();
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
      startEditing: widget.startEditing,
      title: isCreate ? "Nuwe Voorraad" : "Wysig Voorraad",
      saveLabel: isCreate ? "STOOR VOORRAAD" : "OPDATEER VOORRAAD",
      showSaveSpinner: false,
      saveLetterSpacing: 1,
      showCancel: false,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Naam",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.navy)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: withSuggestionGhost(
                  appInputDecoration(),
                  ghost: _ghosts['stock_name']?.value,
                  active: name.isEmpty && _ghosts['stock_name'] != null,
                  onAccept: _ghosts['stock_name'] != null
                      ? () =>
                          _applyStockGhost('stock_name', _ghosts['stock_name']!)
                      : null,
                ),
                onChanged: (v) {
                  name = v;
                  setState(() {});
                },
                validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Handelsmerk",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.navy)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _brandController,
                decoration: withSuggestionGhost(
                  appInputDecoration(),
                  ghost: _ghosts['stock_brand']?.value,
                  active: brand.isEmpty && _ghosts['stock_brand'] != null,
                  onAccept: _ghosts['stock_brand'] != null
                      ? () => _applyStockGhost(
                          'stock_brand', _ghosts['stock_brand']!)
                      : null,
                ),
                onChanged: (v) {
                  brand = v;
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Tipe",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.navy)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _typeController,
                decoration: withSuggestionGhost(
                  appInputDecoration(),
                  ghost: _ghosts['stock_type']?.value,
                  active: type.isEmpty && _ghosts['stock_type'] != null,
                  onAccept: _ghosts['stock_type'] != null
                      ? () =>
                          _applyStockGhost('stock_type', _ghosts['stock_type']!)
                      : null,
                ),
                onChanged: (v) {
                  type = v;
                  setState(() {});
                },
                validator: (v) => (v == null || v.isEmpty) ? "Vereis" : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildNumberField("Hoeveelheid", s?.amount.toString() ?? '',
              (v) => amount = int.tryParse(v) ?? 0),
          const SizedBox(height: 20),
          _buildNumberField("Minimum Voorraad", s?.minimum.toString() ?? '',
              (v) => minimum = int.tryParse(v) ?? 0),
          const SizedBox(height: 20),
          _buildNumberField("Boks Totaal", s?.boxTotal.toString() ?? '',
              (v) => boxTotal = int.tryParse(v) ?? 0),
          const SizedBox(height: 20),
          LocationCascadePicker(
            label: "Ligging *",
            showBreadcrumb: false,
            trailBar: _breadcrumbs(),
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

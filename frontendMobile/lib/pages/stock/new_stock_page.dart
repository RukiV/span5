<<<<<<< HEAD
import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../models/user_session.dart';
import '../../models/stock.dart';
import '../../widgets/location_cascade_picker.dart';
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
        title: const Text("Nuwe Voorraad",
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
                      child: _buildNumberField(
                          "Boks Totaal", (v) => boxTotal = int.tryParse(v) ?? 0),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context);
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
                    child: const Text("STOOR VOORRAAD",
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

  Widget _buildField(String label, Function(String) onSet, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
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

=======
import 'package:flutter/material.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../models/user_session.dart';
import '../../models/stock.dart';
import '../../widgets/searchable_dropdown.dart';

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
  String? selectedCampus;
  String? selectedBuilding;
  String? selectedRoom;

  @override
  void initState() {
    super.initState();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          try {
            selectedCampus = CampusService.campusesNotifier.value
                .firstWhere((c) => c.name == UserSession.userCampus || UserSession.userCampus.contains(c.name))
                .name;
          } catch (_) {
            if (CampusService.campusesNotifier.value.isNotEmpty) {
               selectedCampus = CampusService.campusesNotifier.value.first.name;
            }
          }
        });
      }
    });
  }

  List<String> get _availableBuildings {
    if (selectedCampus == null) return [];
    final campus = CampusService.getCampusByName(selectedCampus!);
    if (campus == null) return [];
    return campus.buildings.map((b) => b.name).toList();
  }

  List<String> get availableRooms {
    if (selectedCampus == null || selectedBuilding == null) return [];
    final campus = CampusService.getCampusByName(selectedCampus!);
    if (campus == null) return [];
    final building = campus.buildings.where((b) => b.name == selectedBuilding).firstOrNull;
    if (building == null) return [];
    return (building.rooms ?? []).map((r) => '${r.id}:${r.name}').toList();
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
                  SearchableDropdown<String>(
                    label: "Kampus",
                    hint: "Kies 'n kampus",
                    value: selectedCampus,
                    items: CampusService.campusesNotifier.value
                        .map((c) => SearchableDropdownItem(value: c.name, label: c.name))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedCampus = v;
                        selectedBuilding = null;
                        selectedRoom = null;
                      });
                    },
                    validator: (v) => (v == null) ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),
                  SearchableDropdown<String>(
                    label: "Gebou",
                    hint: selectedCampus == null ? "Kies eers 'n kampus" : "Kies 'n gebou",
                    value: selectedBuilding,
                    items: _availableBuildings
                        .map((b) => SearchableDropdownItem(value: b, label: b))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        selectedBuilding = v;
                        selectedRoom = null;
                      });
                    },
                    validator: (v) => (v == null) ? "Vereis" : null,
                  ),
                  const SizedBox(height: 20),
                  SearchableDropdown<String>(
                    label: "Lokaal",
                    hint: selectedBuilding == null ? "Kies eers 'n gebou" : "Kies 'n lokaal",
                    value: selectedRoom,
                    items: availableRooms.map((r) {
                      final name = r.contains(":") ? r.split(":").last : r;
                      return SearchableDropdownItem(value: r, label: name);
                    }).toList(),
                    onChanged: (v) => setState(() => selectedRoom = v),
                    validator: (v) => (v == null) ? "Vereis" : null,
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
                          if (_formKey.currentState!.validate()) {
                             int? roomId;
                             if (selectedRoom != null && selectedRoom!.contains(":")) {
                               roomId = int.tryParse(selectedRoom!.split(":").first);
                             }
                             
                              final newStock = Stock(
                                name: name,
                                brand: brand,
                                amount: amount,
                                minimum: minimum,
                                boxTotal: boxTotal,
                                type: type,
                                description: description,
                                roomId: roomId,
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
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

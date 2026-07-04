<<<<<<< HEAD
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../core/stock_service.dart';
import '../../models/campus.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';

class NewStockPage extends StatefulWidget {
  const NewStockPage({super.key});

  @override
  State<NewStockPage> createState() => _NewStockPageState();
}

class _NewStockPageState extends State<NewStockPage> {
  final _formKey = GlobalKey<FormState>();
  
  String brand = "";
  int amount = 0;
  String type = "Verbruikbaar";
  String description = "";
  String? selectedCampus;
  String? selectedRoom;

  final List<String> types = ["Verbruikbaar", "Gereedskap", "Onderdele", "Ander"];

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

  List<String> get availableRooms {
    if (selectedCampus == null) return [];
    try {
      final c = CampusService.campusesNotifier.value.firstWhere((c) => c.name == selectedCampus);
      return c.rooms;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("NUWE TOERUSTING")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField("Handelsmerk / Naam *", (v) => brand = v, "bv. Bosch Boor"),
              const SizedBox(height: 20),
              _buildNumberField("Hoeveelheid *", (v) => amount = int.tryParse(v) ?? 0),
              const SizedBox(height: 20),
              const Text("Tipe *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: _inputDecoration(),
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => type = v!),
              ),
              const SizedBox(height: 20),
              const Text("Kampus", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              ValueListenableBuilder<List<Campus>>(
                valueListenable: CampusService.campusesNotifier,
                builder: (context, campuses, _) {
                  final filteredCampuses = UserSession.isAdmin 
                      ? campuses 
                      : campuses.where((c) => c.name == UserSession.userCampus || UserSession.userCampus.contains(c.name)).toList();

                  return DropdownButtonFormField<String>(
                    initialValue: selectedCampus,
                    decoration: _inputDecoration(),
                    items: filteredCampuses.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: UserSession.isAdmin ? (v) => setState(() {
                      selectedCampus = v;
                      selectedRoom = null;
                    }) : null,
                  );
                },
              ),
              const SizedBox(height: 20),
              if (availableRooms.isNotEmpty) ...[
                const Text("Lokaal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedRoom,
                  decoration: _inputDecoration(),
                  items: availableRooms.map((r) {
                    final name = r.contains(":") ? r.split(":").last : r;
                    return DropdownMenuItem(value: r, child: Text(name));
                  }).toList(),
                  onChanged: (v) => setState(() => selectedRoom = v),
                ),
                const SizedBox(height: 20),
              ],
              _buildField("Beskrywing", (v) => description = v, "Opsionele notas...", maxLines: 3),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      int? roomId;
                      if (selectedRoom != null && selectedRoom!.contains(":")) {
                        roomId = int.tryParse(selectedRoom!.split(":").first);
                      }
                      
                      final newStock = Stock(
                        brand: brand,
                        amount: amount,
                        type: type,
                        description: description,
                        roomId: roomId,
                      );

                      final success = await StockService.addStock(newStock);
                      if (mounted && success) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text("VOEG BY VOORRAAD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, Function(String) onSet, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          maxLines: maxLines,
          decoration: _inputDecoration(hint: hint),
          onChanged: onSet,
          validator: (v) => (v == null || v.isEmpty) ? "Verpligtend" : null,
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
          validator: (v) => (v == null || int.tryParse(v) == null) ? "Geldige getal nodig" : null,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFEFBEA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }
}
=======
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../core/stock_service.dart';
import '../../models/campus.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';

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
  String type = "Ander";
  String description = "";
  String? selectedCampus;
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

  List<String> get availableRooms {
    if (selectedCampus == null) return [];
    try {
      final c = CampusService.campusesNotifier.value.firstWhere((c) => c.name == selectedCampus);
      return c.rooms;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Wysig Voorraad", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  const Text("Lokaal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRoom,
                    decoration: _inputDecoration(),
                    items: availableRooms.map((r) {
                      final name = r.contains(":") ? r.split(":").last : r;
                      return DropdownMenuItem(value: r, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setState(() => selectedRoom = v),
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
                               brand: brand,
                               amount: amount,
                               type: type,
                               description: description,
                               roomId: roomId,
                             );

                             final success = await StockService.addStock(newStock);
                             if (mounted && success) {
                               Navigator.pop(context);
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
>>>>>>> 3080162a6b51675de2ce74fa53f3bd629f39db17

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
                value: type,
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
                    value: selectedCampus,
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
                  value: selectedRoom,
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

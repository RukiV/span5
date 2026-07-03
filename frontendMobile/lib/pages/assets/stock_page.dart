import '../../core/campus_service.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/stock_service.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';
import 'new_stock_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    StockService.fetchStocks();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildStockList()),
        ],
      ),
      floatingActionButton: UserSession.hasAdminPrivileges
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NewStockPage())),
              backgroundColor: AppColors.gold,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      color: AppColors.navy,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Soek voorraad...",
          hintStyle: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.gold),
          fillColor: Colors.white.withAlpha(30),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _showEditStockDialog(BuildContext context, Stock stock) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Wysig Voorraad", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildPopupField("Naam", stock.brand)), // Stock model uses brand as name mostly
                    const SizedBox(width: 16),
                    Expanded(child: _buildPopupField("Merk", stock.brand)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildPopupField("Tipe", stock.type)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPopupField("Hoeveelheid", stock.amount.toString())),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Lokaal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: stock.roomId?.toString(),
                  decoration: _popupInputDecoration(),
                  items: stock.roomId == null ? [] : [DropdownMenuItem(value: stock.roomId.toString(), child: Text(CampusService.getRoomName(stock.roomId.toString())))],
                  onChanged: (v) {},
                ),
                const SizedBox(height: 16),
                _buildPopupField("Beskrywing", stock.description ?? "", maxLines: 3),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kanselleer", style: TextStyle(color: Colors.grey))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5E34),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Opdateer"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupField(String label, String initialValue, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          maxLines: maxLines,
          decoration: _popupInputDecoration(),
        ),
      ],
    );
  }

  InputDecoration _popupInputDecoration() {
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

  Widget _buildStockList() {
    return ValueListenableBuilder<List<Stock>>(
      valueListenable: StockService.stocksNotifier,
      builder: (context, allStocks, _) {
        // ROL-GEBASEERDE DATA FILTRERING
        List<Stock> baseStocks = allStocks;
        if (UserSession.isManager) {
          baseStocks = allStocks.where((s) {
            if (s.roomId == null) return false;
            final stockCampus = CampusService.getCampusNameByRoomId(s.roomId.toString());
            return stockCampus == UserSession.userCampus;
          }).toList();
        }

        final filtered = baseStocks.where((s) {
          return s.brand.toLowerCase().contains(_query) || s.type.toLowerCase().contains(_query);
        }).toList();

        if (filtered.isEmpty) return const Center(child: Text("Geen voorraad gevind nie."));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: AppColors.gold,
              child: const Row(
                children: [
                  Expanded(flex: 1, child: Text("Handelsmerk", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text("Tipe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text("Hvh", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stock = filtered[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Row(
                      children: [
                        Expanded(flex: 1, child: Text(stock.brand, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 3, child: Text(stock.type, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text("${stock.amount}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold))),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                      onPressed: () => _showEditStockDialog(context, stock),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

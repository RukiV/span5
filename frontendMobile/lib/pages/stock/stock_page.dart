import '../../services/campus_service.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/stock_service.dart';
import '../../models/stock.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import 'new_stock_page.dart';
import 'edit_stock_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  String _roomFilter = "Almal";

  @override
  void initState() {
    super.initState();
    StockService.fetchStocks();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
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
          _buildSearchBarWithFilter(),
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

  Widget _buildSearchBarWithFilter() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Soek voorraad...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 150 / 255), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                fillColor: Colors.white.withValues(alpha: 30 / 255),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 30 / 255),
              borderRadius: BorderRadius.circular(30),
            ),
            child: DropdownButtonHideUnderline(
              child: ValueListenableBuilder(
                valueListenable: CampusService.campusesNotifier,
                builder: (context, campuses, __) {
                  final List<Room> allRooms = campuses
                      .expand((c) => c.buildings)
                      .expand((b) => b.rooms ?? <Room>[])
                      .toList();
                  
                  final Set<String> roomNames = allRooms.map((r) => r.name).toSet();
                  final List<String> items = ["Almal", ...roomNames];

                  return DropdownButton<String>(
                    value: _roomFilter,
                    dropdownColor: AppColors.navy,
                    icon: const Icon(Icons.filter_list, color: AppColors.gold),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    items: items.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _roomFilter = val!),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockList() {
    return ValueListenableBuilder<List<Stock>>(
      valueListenable: StockService.stocksNotifier,
      builder: (context, allStocks, _) {
        // ROL-GEBASEERDE DATA FILTRERING - Bestuurders sien nou alles soos Admin
        List<Stock> baseStocks = allStocks;

        final filtered = baseStocks.where((s) {
          // Room filter
          if (_roomFilter != "Almal") {
            final roomName = CampusService.getRoomName(s.roomId?.toString() ?? "");
            if (roomName != _roomFilter) return false;
          }

          // Search query
          return s.name.toLowerCase().contains(_query) ||
              s.brand.toLowerCase().contains(_query) ||
              s.type.toLowerCase().contains(_query) ||
              (s.id?.toString().contains(_query) ?? false);
        }).toList();

        if (filtered.isEmpty) return const Center(child: Text("Geen voorraad gevind nie."));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: AppColors.gold,
              child: const Row(
                children: [
                  Expanded(flex: 1, child: Text("ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text("MERK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text("TIPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text("HOEVEELHEID", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stock = filtered[index];
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditStockPage(stock: stock)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: Text("#${stock.id ?? ''}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text(stock.brand, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text(stock.type, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                          Expanded(flex: 2, child: Text("${stock.amount}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 12))),
                        ],
                      ),
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

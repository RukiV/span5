import 'package:flutter/material.dart';
import '../../widgets/cascading_location_filter.dart';
import '../../core/app_colors.dart';
import '../../services/stock_service.dart';
import '../../services/campus_service.dart';
import '../../models/stock.dart';
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
  int? _selectedCampusId;
  int? _selectedBuildingId;
  int? _selectedRoomId;

  @override
  void initState() {
    super.initState();
    StockService.fetchStocks();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _tryAutoSelectCampus();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  void _tryAutoSelectCampus() {
    if (UserSession.isManager && _selectedCampusId == null && UserSession.locationId != null) {
      final match = CampusService.campusesNotifier.value
          .where((c) => c.id == UserSession.locationId).firstOrNull;
      if (match != null) _selectedCampusId = match.id;
    }
  }

  void _onCampusesChanged() {
    if (mounted) {
      setState(() {
        _tryAutoSelectCampus();
      });
    }
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
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
          _buildCampusFilter(),
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
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
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
    );
  }

  Widget _buildCampusFilter() {
    final campuses = CampusService.campusesNotifier.value;
    if (campuses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CascadingLocationFilter(
        campuses: campuses,
        campusId: _selectedCampusId,
        buildingId: _selectedBuildingId,
        roomId: _selectedRoomId,
        maxLevel: 3,
        onCampusChanged: (id) => setState(() {
          _selectedCampusId = id;
          _selectedBuildingId = null;
          _selectedRoomId = null;
        }),
        onBuildingChanged: (id) => setState(() {
          _selectedBuildingId = id;
          _selectedRoomId = null;
        }),
        onRoomChanged: (id) => setState(() => _selectedRoomId = id),
      ),
    );
  }

  Widget _buildStockList() {
    return ValueListenableBuilder<List<Stock>>(
      valueListenable: StockService.stocksNotifier,
      builder: (context, allStocks, _) {
        // ROL-GEBASEERDE DATA FILTRERING - Bestuurders sien nou alles soos Admin
        List<Stock> baseStocks = allStocks;

        final campuses = CampusService.campusesNotifier.value;

        final campusRoomIds = _selectedCampusId != null
            ? campuses
                .where((c) => c.id == _selectedCampusId)
                .expand((c) => c.buildings)
                .expand((b) => b.rooms ?? [])
                .map((r) => r.id)
                .toSet()
            : null;
        final buildingRoomIds = _selectedBuildingId != null
            ? campuses
                .expand((c) => c.buildings)
                .where((b) => b.id == _selectedBuildingId)
                .expand((b) => b.rooms ?? [])
                .map((r) => r.id)
                .toSet()
            : null;

        final filtered = baseStocks.where((s) {
          // Campus filter
          if (campusRoomIds != null && (s.roomId == null || !campusRoomIds.contains(s.roomId))) return false;

          // Building filter
          if (buildingRoomIds != null && (s.roomId == null || !buildingRoomIds.contains(s.roomId))) return false;

          // Room filter
          if (_selectedRoomId != null && s.roomId != _selectedRoomId) return false;

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
                  Expanded(flex: 2, child: Text("NAAM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text("MERK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text("TIPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text("HVH", textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
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
                          Expanded(flex: 2, child: Text(stock.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text(stock.brand, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
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

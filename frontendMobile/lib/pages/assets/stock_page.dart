import '../../core/campus_service.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/stock_service.dart';
import '../../models/stock.dart';
import '../../models/campus.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import 'new_stock_page.dart';
import '../../widgets/searchable_dropdown.dart';

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
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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

  void _showEditStockDialog(BuildContext context, Stock stock) {
    String tempName = stock.name;
    String tempBrand = stock.brand;
    String tempType = stock.type;
    int tempAmount = stock.amount;
    String? tempDescription = stock.description;
    int? tempRoomId = stock.roomId;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Wysig Voorraad", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogContext)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildPopupField("Naam", tempName, (v) => tempName = v),
                  const SizedBox(height: 16),
                  _buildPopupField("Merk", tempBrand, (v) => tempBrand = v),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildPopupField("Tipe", tempType, (v) => tempType = v)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPopupField("Hoeveelheid", tempAmount.toString(), (v) => tempAmount = int.tryParse(v) ?? tempAmount)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<List<Campus>>(
                    valueListenable: CampusService.campusesNotifier,
                    builder: (context, campuses, _) {
                      final allRooms = campuses
                          .expand((c) => c.buildings)
                          .expand((b) => b.rooms ?? [])
                          .map((r) => SearchableDropdownItem(value: '${r.id}:${r.name}', label: r.name))
                          .toList();
                      
                      final currentValue = allRooms.any((r) => r.value.startsWith("$tempRoomId:")) 
                          ? allRooms.firstWhere((r) => r.value.startsWith("$tempRoomId:")).value
                          : null;

                      return SearchableDropdown<String>(
                        label: "Lokaal",
                        hint: "Kies Lokaal",
                        value: currentValue,
                        items: allRooms,
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => tempRoomId = int.tryParse(v.split(":").first));
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPopupField("Beskrywing", tempDescription ?? "", (v) => tempDescription = v, maxLines: 3),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _confirmDeleteStock(context, stock),
                        child: const Text("Verwyder", style: TextStyle(color: AppColors.errorRed)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final updated = Stock(
                                id: stock.id,
                                name: tempName,
                                brand: tempBrand,
                                type: tempType,
                                amount: tempAmount,
                                description: tempDescription,
                                roomId: tempRoomId,
                              );
                              final success = await StockService.updateStock(updated);
                              if (!mounted) return;
                              if (success) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Opdateer"),
                          ),
                        ],
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

  void _confirmDeleteStock(BuildContext context, Stock stock) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder Voorraad"),
        content: Text("Is jy seker jy wil '${stock.brand} ${stock.type}' verwyder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Kanselleer")),
          TextButton(
            onPressed: () async {
              if (stock.id != null) {
                final success = await StockService.deleteStock(stock.id!);
                if (!mounted) return;
                if (success) {
                  Navigator.of(dialogContext).pop(); // Close confirm
                  Navigator.of(context).pop(); // Close edit dialog
                }
              }
            },
            child: const Text("Verwyder", style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupField(String label, String initialValue, Function(String) onChanged, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          maxLines: maxLines,
          decoration: _popupInputDecoration(),
          onChanged: onChanged,
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
                    onTap: () => _showEditStockDialog(context, stock),
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

import 'package:flutter/material.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../core/app_colors.dart';
import '../../services/stock_service.dart';
import '../../services/campus_service.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';
import 'new_stock_page.dart';
import 'edit_stock_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  /// Returns the flex value for a given column key.
  /// Number columns (amount, minimum, boxTotal) are narrower (flex: 1),
  /// text columns (name, description) are wider (flex: 3).
  int _columnFlex(String key) {
    switch (key) {
      case 'amount':
      case 'minimum':
      case 'boxTotal':
        return 1;
      case 'name':
      case 'description':
        return 3;
      default:
        return 2;
    }
  }

  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('stock', [
    const ColumnDef(key: 'name', label: 'NAAM'),
    const ColumnDef(key: 'brand', label: 'MERK'),
    const ColumnDef(key: 'type', label: 'TIPE'),
    const ColumnDef(key: 'amount', label: 'HVH'),
    const ColumnDef(key: 'minimum', label: 'Minimum', defaultVisible: false),
    const ColumnDef(key: 'boxTotal', label: 'Boks Totaal', defaultVisible: false),
    const ColumnDef(key: 'description', label: 'Beskrywing', defaultVisible: false),
    const ColumnDef(key: 'room', label: 'Lokaal', defaultVisible: false),
  ]);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 4),
      child: LocationCascadePicker(
        initialCampusId: _selectedCampusId,
        initialBuildingId: _selectedBuildingId,
        initialRoomId: _selectedRoomId,
        onChanged: (campusId, buildingId, roomId) => setState(() {
          _selectedCampusId = campusId;
          _selectedBuildingId = buildingId;
          _selectedRoomId = roomId;
        }),
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
          const SizedBox(width: 8),
          ColumnVisibilityButton(controller: _colVis),
        ],
      ),
    );
  }

  Widget _buildCampusFilter() {
    if (CampusService.campusesNotifier.value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 4),
      child: LocationCascadePicker(
        initialCampusId: _selectedCampusId,
        initialBuildingId: _selectedBuildingId,
        initialRoomId: _selectedRoomId,
        onChanged: (campusId, buildingId, roomId) => setState(() {
          _selectedCampusId = campusId;
          _selectedBuildingId = buildingId;
          _selectedRoomId = roomId;
        }),
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

        // Apply sorting
        if (_sortCtrl.isActive) {
          filtered.sort((a, b) {
            final dir = _sortCtrl.direction;
            switch (_sortCtrl.sortKey) {
              case 'name': return a.name.toLowerCase().compareTo(b.name.toLowerCase()) * dir;
              case 'brand': return a.brand.toLowerCase().compareTo(b.brand.toLowerCase()) * dir;
              case 'type': return a.type.toLowerCase().compareTo(b.type.toLowerCase()) * dir;
              case 'amount': return a.amount.compareTo(b.amount) * dir;
              case 'minimum': return a.minimum.compareTo(b.minimum) * dir;
              case 'boxTotal': return a.boxTotal.compareTo(b.boxTotal) * dir;
              case 'description': return (a.description ?? '').compareTo(b.description ?? '') * dir;
              case 'room': return (a.roomName ?? '').compareTo(b.roomName ?? '') * dir;
              default: return 0;
            }
          });
        }

        if (filtered.isEmpty) return const Center(child: Text("Geen voorraad gevind nie."));

        return Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 4),
          child: LocationCascadePicker(
            initialCampusId: _selectedCampusId,
            initialBuildingId: _selectedBuildingId,
            initialRoomId: _selectedRoomId,
            onChanged: (campusId, buildingId, roomId) => setState(() {
              _selectedCampusId = campusId;
              _selectedBuildingId = buildingId;
              _selectedRoomId = roomId;
            }),
          ),
        );
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
                        children: _colVis.visibleColumns.map((col) {
                          Widget child;
                          switch (col.key) {
                            case 'name':
                              child = Text(stock.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
                              break;
                            case 'brand':
                              child = Text(stock.brand, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
                              break;
                            case 'type':
                              child = Text(stock.type, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
                              break;
                            case 'amount':
                              child = Text("${stock.amount}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 12));
                              break;
                            case 'minimum':
                              child = Text("${stock.minimum}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12));
                              break;
                            case 'boxTotal':
                              child = Text("${stock.boxTotal}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12));
                              break;
                            case 'description':
                              child = Text(stock.description ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
                              break;
                            case 'room':
                              child = Text(stock.roomName ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
                              break;
                            default:
                              child = const Text('');
                          }
                          return Expanded(flex: _columnFlex(col.key), child: child);
                        }).toList(),
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

import 'package:flutter/material.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../services/stock_service.dart';
import '../../services/campus_service.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/selection_manager.dart';
import '../../widgets/card_data_row.dart';
import 'new_stock_page.dart';
import 'edit_stock_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCampusId;
  int? _selectedBuildingId;
  int? _selectedRoomId;

  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('stock', [
    const ColumnDef(key: 'name', label: 'NAAM'),
    const ColumnDef(key: 'brand', label: 'HANDELSMERK'),
    const ColumnDef(key: 'type', label: 'TIPE'),
    const ColumnDef(key: 'amount', label: 'HVH'),
    const ColumnDef(key: 'minimum', label: 'Minimum', defaultVisible: false),
    const ColumnDef(key: 'boxTotal', label: 'Boks Totaal', defaultVisible: false),
    const ColumnDef(key: 'description', label: 'Beskrywing', defaultVisible: false),
    const ColumnDef(key: 'room', label: 'Lokaal', defaultVisible: false),
  ]);
  final SelectionController<int> _selection = SelectionController<int>();

  @override
  void initState() {
    super.initState();
    StockService.fetchStocks();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  void _onCampusesChanged() {
    if (mounted) {
      setState(() {});
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
    return ValueListenableBuilder<List<Stock>>(
      valueListenable: StockService.stocksNotifier,
      builder: (context, allStocks, _) {
        final query = _searchController.text.toLowerCase();
        
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

        List<Stock> filtered = allStocks.where((s) {
          // Campus filter
          if (campusRoomIds != null && (s.roomId == null || !campusRoomIds.contains(s.roomId))) return false;

          // Building filter
          if (buildingRoomIds != null && (s.roomId == null || !buildingRoomIds.contains(s.roomId))) return false;

          // Room filter
          if (_selectedRoomId != null && s.roomId != _selectedRoomId) return false;

          return s.name.toLowerCase().contains(query) ||
              s.brand.toLowerCase().contains(query) ||
              s.type.toLowerCase().contains(query) ||
              (s.id?.toString().contains(query) ?? false);
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

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              FixedPageHeader(
                controller: _searchController,
                hintText: "Soek voorraad...",
                onChanged: (v) => setState(() {}),
                actions: _buildHeaderActions(),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => StockService.fetchStocks(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (filtered.isEmpty)
                        const SliverFillRemaining(
                          child: Center(child: Text("Geen voorraad gevind nie.", style: TextStyle(color: Colors.grey))),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final stock = filtered[index];
                              return CardDataRow(
                                leading: _selection.isSelecting && stock.id != null
                                    ? Checkbox(
                                        value: _selection.isSelected(stock.id!),
                                        onChanged: (_) => setState(() => _selection.toggle(stock.id!)),
                                      )
                                    : null,
                                trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
                                onTap: () {
                                  if (_selection.isSelecting) {
                                    if (stock.id != null) {
                                      setState(() => _selection.toggle(stock.id!));
                                    }
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => EditStockPage(stock: stock)),
                                    );
                                  }
                                },
                                onLongPress: () {
                                  if (stock.id != null) {
                                    setState(() {
                                      _selection.enter();
                                      _selection.toggle(stock.id!);
                                    });
                                  }
                                },
                                children: _colVis.visibleColumns.map((col) {
                                  return Expanded(
                                    flex: _columnFlex(col.key),
                                    child: _buildColumnContent(stock, col.key),
                                  );
                                }).toList(),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: UserSession.can('stock.manage')
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.gold,
                  elevation: 4,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Nuwe Voorraad", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NewStockPage()),
                    );
                  },
                )
              : null,
        );
      },
    );
  }

  Future<void> _bulkDeleteStock(BuildContext context, Set<int> ids) async {
    int ok = 0;
    int fail = 0;
    for (final id in ids) {
      if (await StockService.deleteStock(id)) {
        ok++;
      } else {
        fail++;
      }
    }
    await StockService.fetchStocks();
    if (context.mounted) {
      setState(() => _selection.exit());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fail == 0
              ? "$ok voorraad-item(s) verwyder."
              : "$ok verwyder, $fail kon nie verwyder word nie."),
          backgroundColor: fail == 0 ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  List<Widget> _buildHeaderActions() {
    final locationActive = _selectedCampusId != null ||
        _selectedBuildingId != null ||
        _selectedRoomId != null;
    return [
      HeaderIconAction(
        icon: Icons.place_outlined,
        tooltip: "Filter op Ligging",
        activeBadge: locationActive,
        onTap: () => showLocationFilterSheet(
          context,
          depth: LocationDepth.room,
          campusId: _selectedCampusId,
          buildingId: _selectedBuildingId,
          roomId: _selectedRoomId,
          onChanged: (campusId, buildingId, roomId) => setState(() {
            _selectedCampusId = campusId;
            _selectedBuildingId = buildingId;
            _selectedRoomId = roomId;
          }),
        ),
      ),
      if (UserSession.can('stock.manage')) ...[
        BulkDeleteAction<int>(
          controller: _selection,
          confirmTitle: 'Verwyder Voorraad',
          confirmMessage: 'Wil jy ${_selection.count} geselekteerde voorraad-item(s) verwyder?',
          onDelete: _bulkDeleteStock,
        ),
      ],
      ColumnVisibilityButton(controller: _colVis, iconOnly: true),
    ];
  }

  int _columnFlex(String key) {
    switch (key) {
      case 'name': return 3;
      case 'brand': return 2;
      case 'type': return 2;
      case 'amount': return 1;
      default: return 1;
    }
  }

  Widget _buildColumnContent(Stock stock, String key) {
    switch (key) {
      case 'name':
        return Text(stock.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
      case 'brand':
        return Text(stock.brand, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
      case 'type':
        return Text(stock.type, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
      case 'amount':
        return Text("${stock.amount}", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 12));
      case 'minimum':
        return Text("${stock.minimum}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12));
      case 'boxTotal':
        return Text("${stock.boxTotal}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12));
      case 'description':
        return Text(stock.description ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
      case 'room':
        return Text(stock.roomName ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12));
      default:
        return const SizedBox.shrink();
    }
  }

}

import 'package:flutter/material.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../services/stock_service.dart';
import '../../services/campus_service.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';
import '../../widgets/card_data_row.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/list_page_scaffold.dart';
import '../../widgets/selectable_row.dart';
import '../../widgets/selection_manager.dart';
import 'stock_form_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
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
  }

  void _onCampusesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    super.dispose();
  }

  Future<void> _bulkDeleteStock(BuildContext context, Set<int> ids) async {
    await runBulkDelete(
      context,
      ids: ids,
      delete: StockService.deleteStock,
      refresh: StockService.fetchStocks,
      entityLabel: 'voorraad-item(s)',
      onExit: () => setState(() {}),
    );
  }

  int _columnFlex(String key) {
    switch (key) {
      case 'name':
        return 3;
      case 'brand':
        return 2;
      case 'type':
        return 2;
      case 'amount':
        return 1;
      default:
        return 1;
    }
  }

  Widget _buildColumnContent(Stock stock, String key) {
    switch (key) {
      case 'name':
        return Text(stock.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
      case 'brand':
        return Text(stock.brand,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12));
      case 'type':
        return Text(stock.type,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12));
      case 'amount':
        return Text("${stock.amount}",
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
                fontSize: 12));
      case 'minimum':
        return Text("${stock.minimum}",
            textAlign: TextAlign.right, style: const TextStyle(fontSize: 12));
      case 'boxTotal':
        return Text("${stock.boxTotal}",
            textAlign: TextAlign.right, style: const TextStyle(fontSize: 12));
      case 'description':
        return Text(stock.description ?? '-',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12));
      case 'room':
        return Text(stock.roomName ?? '-',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12));
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _stockCells(Stock stock, SearchableListState<int> state) {
    return state.columnVisibility.visibleColumns
        .map((col) => Expanded(
              flex: _columnFlex(col.key),
              child: _buildColumnContent(stock, col.key),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final locationActive = _selectedCampusId != null ||
        _selectedBuildingId != null ||
        _selectedRoomId != null;

    return ValueListenableBuilder<List<Stock>>(
      valueListenable: StockService.stocksNotifier,
      builder: (context, allStocks, _) {
        List<Stock> visibleRowsFor(String query) {
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
          return allStocks.where((s) {
            if (campusRoomIds != null &&
                (s.roomId == null || !campusRoomIds.contains(s.roomId))) {
              return false;
            }
            if (buildingRoomIds != null &&
                (s.roomId == null || !buildingRoomIds.contains(s.roomId))) {
              return false;
            }
            if (_selectedRoomId != null && s.roomId != _selectedRoomId) {
              return false;
            }
            return s.name.toLowerCase().contains(query) ||
                s.brand.toLowerCase().contains(query) ||
                s.type.toLowerCase().contains(query) ||
                (s.id?.toString().contains(query) ?? false);
          }).toList();
        }

        return SearchableListScaffold<int>(
          searchHint: "Soek voorraad...",
          columns: const [
            ColumnDef(key: 'name', label: 'NAAM'),
            ColumnDef(key: 'brand', label: 'HANDELSMERK'),
            ColumnDef(key: 'type', label: 'TIPE'),
            ColumnDef(key: 'amount', label: 'HVH'),
            ColumnDef(key: 'minimum', label: 'Minimum', defaultVisible: false),
            ColumnDef(
                key: 'boxTotal', label: 'Boks Totaal', defaultVisible: false),
            ColumnDef(
                key: 'description', label: 'Beskrywing', defaultVisible: false),
            ColumnDef(key: 'room', label: 'Lokaal', defaultVisible: false),
          ],
          backgroundColor: Colors.white,
          leadingActions: [
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
          ],
          canBulkDelete: UserSession.can('stock.manage'),
          bulkDeleteTitle: 'Verwyder Voorraad',
          bulkDeleteMessage:
              'Wil jy {count} geselekteerde voorraad-item(s) verwyder?',
          visibleIdsProvider: (q) => visibleRowsFor(q)
              .map((s) => s.id)
              .whereType<int>()
              .toSet(),
          onBulkDelete: _bulkDeleteStock,
          onRefresh: () => StockService.fetchStocks(),
          floatingActionButton: UserSession.can('stock.manage')
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.gold,
                  elevation: 4,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Nuwe Voorraad",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const StockFormPage()),
                    );
                  },
                )
              : null,
          content: (context, state) {
            final filtered = visibleRowsFor(state.query);

            return RefreshIndicator(
              onRefresh: () => StockService.fetchStocks(),
              color: AppColors.refreshSpinner,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                          child: Text("Geen voorraad gevind nie.",
                              style: TextStyle(color: Colors.grey))),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final stock = filtered[index];
                          final id = stock.id;
                          if (id != null) {
                            return SelectableRow<int>(
                              id: id,
                              selection: state.selection,
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppColors.gold),
                              onOpen: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        StockFormPage(stock: stock)),
                              ),
                              children: _stockCells(stock, state),
                            );
                          }
                          return CardDataRow(
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.gold),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      StockFormPage(stock: stock)),
                            ),
                            children: _stockCells(stock, state),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

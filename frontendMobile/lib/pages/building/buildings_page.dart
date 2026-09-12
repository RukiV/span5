import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/list_load_error.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/list_page_scaffold.dart';
import '../../widgets/selectable_row.dart';
import '../../widgets/selection_manager.dart';
import 'building_detail_page.dart';
import 'building_form_page.dart';
import '../rooms/rooms_page.dart';

class BuildingsPage extends StatefulWidget {
  final Campus? initialCampus;
  final void Function(Building building)? onBuildingSelected;
  const BuildingsPage({
    super.key,
    this.initialCampus,
    this.onBuildingSelected,
  });

  @override
  State<BuildingsPage> createState() => _BuildingsPageState();
}

class _BuildingsPageState extends State<BuildingsPage> {
  Campus? _selectedCampus;

  @override
  void initState() {
    super.initState();
    if (widget.initialCampus != null) {
      _selectedCampus = widget.initialCampus;
    }
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  List<Widget> _buildBuildingCells(Building b, SearchableListState<int> state) {
    final roomCount = b.rooms?.length ?? 0;
    return state.columnVisibility.visibleColumns.map((col) {
      int flex = 2;
      Widget child;
      switch (col.key) {
        case 'name':
          flex = 3;
          child = Text(
            b.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
                fontSize: 16),
          );
          break;
        case 'rooms':
          flex = 2;
          child = Text(
            "$roomCount Lokale",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.gold,
                fontWeight: FontWeight.bold),
          );
          break;
        case 'address':
          flex = 3;
          child = Text(
            b.address,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          );
          break;
        default:
          child = const SizedBox.shrink();
      }
      return Expanded(flex: flex, child: child);
    }).toList();
  }

  Future<void> _bulkDeleteBuildings(BuildContext context, Set<int> ids) async {
    await runBulkDelete(
      context,
      ids: ids,
      delete: CampusService.removeBuilding,
      refresh: CampusService.fetchCampuses,
      entityLabel: 'gebou/geboue',
    );
  }

  Widget _buildLoadError() {
    return ListLoadError(
      message: CampusService.lastError,
      onRetry: () => CampusService.fetchCampuses(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Campus>>(
      valueListenable: CampusService.campusesNotifier,
      builder: (context, campuses, _) {
        if (campuses.isEmpty) {
          if (CampusService.lastError != null) {
            return _buildLoadError();
          }
          return const Center(child: CircularProgressIndicator());
        }

        // Re-resolve die gekose kampus teen die vars `campuses`-lys (nie die
        // ou objekverwysing nie) sodat byvoeg/wysig/verwyder dadelik wys.
        Campus? selectedCampus = _selectedCampus != null
            ? campuses.where((c) => c.id == _selectedCampus!.id).firstOrNull
            : null;
        _selectedCampus = selectedCampus;

        // Default wys alle geboue oor alle terreine (plat lys), sodat die lys
        // nooit leeg is nie. Die terrein-filter vernou dit dinamies.
        final buildings = selectedCampus?.buildings ??
            campuses.expand((c) => c.buildings).toList();

        List<Building> visibleRowsFor(String query) => buildings
            .where((b) =>
                query.isEmpty ||
                b.name.toLowerCase().contains(query) ||
                b.address.toLowerCase().contains(query))
            .toList();

        return SearchableListScaffold<int>(
          searchHint: "Soek geboue...",
          columns: const [
            ColumnDef(key: 'name', label: 'Naam'),
            ColumnDef(key: 'rooms', label: 'Lokale'),
            ColumnDef(key: 'address', label: 'Adres', defaultVisible: false),
          ],
          leadingActions: [
            HeaderIconAction(
              icon: Icons.place_outlined,
              tooltip: "Filter op Terrein",
              activeBadge: _selectedCampus != null,
              onTap: () => showLocationFilterSheet(
                context,
                depth: LocationDepth.campus,
                campusId: _selectedCampus?.id,
                onChanged: (campusId, _, __) {
                  setState(() {
                    _selectedCampus =
                        campuses.where((c) => c.id == campusId).firstOrNull;
                  });
                },
              ),
            ),
          ],
          canBulkDelete: UserSession.can('buildings.manage'),
          bulkDeleteTitle: 'Verwyder Geboue',
          bulkDeleteMessage:
              'Wil jy {count} geselekteerde gebou/geboue verwyder?',
          bulkDeleteChildWarning:
              'Alle onderliggende lokale, bates, voorraad, foute en take sal ook verwyder word.',
          visibleIdsProvider: (q) =>
              visibleRowsFor(q).map((b) => b.id).toSet(),
          onBulkDelete: _bulkDeleteBuildings,
          floatingActionButton: UserSession.can('buildings.manage')
              ? FloatingActionButton.extended(
                  heroTag: "buildingAddBtn",
                  backgroundColor: AppColors.gold,
                  elevation: 4,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Nuwe Gebou",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BuildingFormPage(campus: _selectedCampus),
                      ),
                    );
                    if (result == true) setState(() {});
                  },
                )
              : null,
          content: (context, state) {
            final filtered = visibleRowsFor(state.query);

            if (filtered.isEmpty) {
              return const Center(
                child: Text("Geen geboue gevind nie.",
                    style: TextStyle(color: Colors.grey)),
              );
            }

            return RefreshIndicator(
              onRefresh: () => CampusService.fetchCampuses(),
              color: AppColors.refreshSpinner,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 90),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final b = filtered[index];
                  return SelectableRow<int>(
                    id: b.id,
                    selection: state.selection,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_right,
                              color: AppColors.gold),
                          tooltip: "Wys lokale in gebou",
                          onPressed: () {
                            if (state.selection.isSelecting) {
                              state.selection.toggle(b.id);
                            } else {
                              final onBuildingSelected =
                                  widget.onBuildingSelected;
                              if (onBuildingSelected != null) {
                                onBuildingSelected(b);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RoomsPage(
                                      initialCampus: _selectedCampus,
                                      initialBuilding: b,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    onOpen: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BuildingDetailPage(building: b),
                        ),
                      );
                    },
                    onLongPress: UserSession.can('buildings.manage')
                        ? null
                        : () {},
                    children: _buildBuildingCells(b, state),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

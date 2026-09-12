import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/list_page_scaffold.dart';
import '../../widgets/selectable_row.dart';
import '../../widgets/selection_manager.dart';
import 'building_form_page.dart';
import '../rooms/manage_rooms_page.dart';

class BuildingsListPage extends StatefulWidget {
  final Campus? initialCampus;
  final void Function(Building building)? onBuildingSelected;
  const BuildingsListPage({
    super.key,
    this.initialCampus,
    this.onBuildingSelected,
  });

  @override
  State<BuildingsListPage> createState() => _BuildingsListPageState();
}

class _BuildingsListPageState extends State<BuildingsListPage> {
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
      onExit: () => setState(() {}),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.errorRed, size: 40),
            const SizedBox(height: 12),
            Text(
              CampusService.lastError ?? "Kon nie die kampuslys laai nie.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.errorRed),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => CampusService.fetchCampuses(),
              child: const Text("Probeer weer"),
            ),
          ],
        ),
      ),
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
          onBulkDelete: _bulkDeleteBuildings,
          onRefresh: () => CampusService.fetchCampuses(),
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
            final filtered = buildings
                .where((b) =>
                    state.query.isEmpty ||
                    b.name.toLowerCase().contains(state.query) ||
                    b.address.toLowerCase().contains(state.query))
                .toList();

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
                                    builder: (context) => ManageRoomsPage(
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
                          builder: (context) => BuildingFormPage(building: b),
                        ),
                      );
                    },
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

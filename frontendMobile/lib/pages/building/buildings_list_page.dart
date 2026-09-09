import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import 'add_building_page.dart';
import 'edit_building_page.dart';
import '../rooms/manage_rooms_page.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/selection_manager.dart';
import '../../widgets/card_data_row.dart';

class BuildingsListPage extends StatefulWidget {
  final Campus? initialCampus;
  const BuildingsListPage({super.key, this.initialCampus});

  @override
  State<BuildingsListPage> createState() => _BuildingsListPageState();
}

class _BuildingsListPageState extends State<BuildingsListPage> {
  Campus? _selectedCampus;
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('buildings', [
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'rooms', label: 'Lokale'),
    const ColumnDef(key: 'address', label: 'Adres', defaultVisible: false),
  ]);
  final SelectionController<int> _selection = SelectionController<int>();

  @override
  void initState() {
    super.initState();
    if (widget.initialCampus != null) {
      _selectedCampus = widget.initialCampus;
    }
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

  List<Widget> _buildBuildingCells(Building b) {
    final roomCount = b.rooms?.length ?? 0;
    return _colVis.visibleColumns.map((col) {
      int flex = 2;
      Widget child;
      switch (col.key) {
        case 'name':
          flex = 3;
          child = Text(
            b.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 16),
          );
          break;
        case 'rooms':
          flex = 2;
          child = Text(
            "$roomCount Lokale",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold),
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
    int ok = 0;
    int fail = 0;
    for (final id in ids) {
      if (await CampusService.removeBuilding(id)) {
        ok++;
      } else {
        fail++;
      }
    }
    await CampusService.fetchCampuses();
    if (context.mounted) {
      setState(() => _selection.exit());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fail == 0
              ? "$ok gebou/geboue verwyder."
              : "$ok verwyder, $fail kon nie verwyder word nie."),
          backgroundColor: fail == 0 ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, campuses, _) {
          if (campuses.isEmpty) {
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

          final filtered = buildings.where((b) =>
              _query.isEmpty ||
              b.name.toLowerCase().contains(_query) ||
              b.address.toLowerCase().contains(_query)).toList();

          if (_sortCtrl.isActive) {
            filtered.sort((a, b) {
              final dir = _sortCtrl.direction;
              switch (_sortCtrl.sortKey) {
                case 'name': return a.name.toLowerCase().compareTo(b.name.toLowerCase()) * dir;
                case 'rooms': return (a.rooms?.length ?? 0).compareTo(b.rooms?.length ?? 0) * dir;
                default: return 0;
              }
            });
          }

          return Column(
            children: [
              FixedPageHeader(
                controller: _searchController,
                hintText: "Soek geboue...",
                onChanged: (_) => setState(() {}),
                actions: [
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
                  if (UserSession.can('buildings.manage')) ...[
                    BulkDeleteAction<int>(
                      controller: _selection,
                      confirmTitle: 'Verwyder Geboue',
                      confirmMessage: 'Wil jy ${_selection.count} geselekteerde gebou/geboue verwyder?',
                      childWarning: 'Alle onderliggende lokale, bates, voorraad, foute en take sal ook verwyder word.',
                      onDelete: _bulkDeleteBuildings,
                    ),
                  ],
                  ColumnVisibilityButton(controller: _colVis, iconOnly: true),
                ],
              ),

              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("Geen geboue gevind nie.", style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: () => CampusService.fetchCampuses(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(15, 15, 15, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final b = filtered[index];
                          return CardDataRow(
                            leading: _selection.isSelecting
                                ? Checkbox(
                                    value: _selection.isSelected(b.id),
                                    onChanged: (_) => setState(() => _selection.toggle(b.id)),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_selection.isSelecting && UserSession.can('buildings.manage'))
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditBuildingPage(building: b),
                                        ),
                                      );
                                      if (result == true) setState(() {});
                                    },
                                  ),
                                const Icon(Icons.chevron_right, color: AppColors.gold),
                              ],
                            ),
                            onTap: () {
                              if (_selection.isSelecting) {
                                setState(() => _selection.toggle(b.id));
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
                            },
                            onLongPress: () {
                              setState(() {
                                _selection.enter();
                                _selection.toggle(b.id);
                              });
                            },
                            children: _buildBuildingCells(b),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
        },
      ),
      floatingActionButton: UserSession.can('buildings.manage')
          ? FloatingActionButton.extended(
              heroTag: "buildingAddBtn",
              backgroundColor: AppColors.gold,
              elevation: 4,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Nuwe Gebou", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddBuildingPage(),
                  ),
                );
                if (result == true) setState(() {});
              },
            )
          : null,
    );
  }
}

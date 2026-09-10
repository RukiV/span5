import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import 'add_campus_page.dart';
import 'edit_campus_page.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/selection_manager.dart';
import '../../widgets/card_data_row.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/fixed_page_header.dart';

class CampusManagementPage extends StatefulWidget {
  final void Function(Campus campus) onCampusSelected;
  const CampusManagementPage({super.key, required this.onCampusSelected});

  @override
  State<CampusManagementPage> createState() => _CampusManagementPageState();
}

class _CampusManagementPageState extends State<CampusManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis =
      ColumnVisibilityController('campuses', [
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'address', label: 'Adres', defaultVisible: false),
    const ColumnDef(key: 'buildings', label: 'Geboue'),
  ]);
  final SelectionController<int> _selection = SelectionController<int>();
  String _query = "";

  @override
  void initState() {
    super.initState();
    CampusService.fetchCampuses();
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

  List<Widget> _buildCampusCells(Campus campus) {
    return _colVis.visibleColumns.map((col) {
      int flex = 2;
      Widget child;
      switch (col.key) {
        case 'name':
          flex = 3;
          child = Text(
            campus.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
                fontSize: 16),
          );
          break;
        case 'address':
          flex = 3;
          child = Text(
            campus.address,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          );
          break;
        case 'buildings':
          flex = 2;
          child = Text(
            "${campus.buildings.length} Geboue",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.gold,
                fontWeight: FontWeight.bold),
          );
          break;
        default:
          child = const SizedBox.shrink();
      }
      return Expanded(flex: flex, child: child);
    }).toList();
  }

  Future<void> _bulkDeleteCampuses(BuildContext context, Set<int> ids) async {
    int ok = 0;
    int fail = 0;
    for (final id in ids) {
      if (await CampusService.removeCampus(id)) {
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
              ? "$ok terrein/terreine verwyder."
              : "$ok verwyder, $fail kon nie verwyder word nie."),
          backgroundColor:
              fail == 0 ? AppColors.successGreen : AppColors.errorRed,
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
        builder: (context, allCampuses, child) {
          List<Campus> campuses = allCampuses;

          if (campuses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_city_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("Geen kampusse gevind nie."),
                  TextButton(
                    onPressed: () => CampusService.fetchCampuses(),
                    child: const Text("HERLAAI"),
                  )
                ],
              ),
            );
          }

          final filtered = campuses
              .where((c) =>
                  c.name.toLowerCase().contains(_query) ||
                  c.address.toLowerCase().contains(_query))
              .toList();

          if (_sortCtrl.isActive) {
            filtered.sort((a, b) {
              final dir = _sortCtrl.direction;
              switch (_sortCtrl.sortKey) {
                case 'name':
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase()) *
                      dir;
                case 'address':
                  return a.address
                          .toLowerCase()
                          .compareTo(b.address.toLowerCase()) *
                      dir;
                case 'buildings':
                  return a.buildings.length.compareTo(b.buildings.length) * dir;
                default:
                  return 0;
              }
            });
          }

          return Column(
            children: [
              FixedPageHeader(
                controller: _searchController,
                hintText: "Soek terreine...",
                onChanged: (_) => setState(() {}),
                actions: [
                  if (UserSession.can('locations.manage')) ...[
                    BulkDeleteAction<int>(
                      controller: _selection,
                      confirmTitle: 'Verwyder Terreine',
                      confirmMessage:
                          'Wil jy ${_selection.count} geselekteerde terrein/terreine verwyder?',
                      childWarning:
                          'Alle onderliggende geboue, lokale, bates, voorraad, foute en take sal ook verwyder word.',
                      onDelete: _bulkDeleteCampuses,
                    ),
                  ],
                  ColumnVisibilityButton(controller: _colVis, iconOnly: true),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => CampusService.fetchCampuses(),
                  color: AppColors.refreshSpinner,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (filtered.isEmpty)
                        const SliverFillRemaining(
                          child:
                              Center(child: Text("Geen terreine gevind nie.")),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.all(15),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final campus = filtered[index];
                                return CardDataRow(
                                  leading: _selection.isSelecting
                                      ? Checkbox(
                                          value:
                                              _selection.isSelected(campus.id),
                                          onChanged: (_) => setState(() =>
                                              _selection.toggle(campus.id)),
                                        )
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right,
                                            color: AppColors.gold),
                                        tooltip: "Wys geboue van terrein",
                                        onPressed: _selection.isSelecting
                                            ? () => setState(() =>
                                                _selection.toggle(campus.id))
                                            : () =>
                                                widget.onCampusSelected(campus),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    if (_selection.isSelecting) {
                                      setState(
                                          () => _selection.toggle(campus.id));
                                    } else {
                                      final edited = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EditCampusPage(campus: campus),
                                        ),
                                      );
                                      if (edited == true) {
                                        CampusService.fetchCampuses();
                                      }
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() {
                                      _selection.enter();
                                      _selection.toggle(campus.id);
                                    });
                                  },
                                  children: _buildCampusCells(campus),
                                );
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: UserSession.can('locations.manage')
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              elevation: 4,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Nuwe Terrein",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCampusPage()),
              ),
            )
          : null,
    );
  }
}

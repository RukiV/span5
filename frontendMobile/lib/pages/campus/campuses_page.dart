import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import 'campus_form_page.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/list_page_scaffold.dart';
import '../../widgets/selectable_row.dart';
import '../../widgets/selection_manager.dart';

class CampusesPage extends StatefulWidget {
  final void Function(Campus campus) onCampusSelected;
  const CampusesPage({super.key, required this.onCampusSelected});

  @override
  State<CampusesPage> createState() => _CampusesPageState();
}

class _CampusesPageState extends State<CampusesPage> {
  @override
  void initState() {
    super.initState();
    CampusService.fetchCampuses();
  }

  List<Widget> _buildCampusCells(
      Campus campus, SearchableListState<int> state) {
    return state.columnVisibility.visibleColumns.map((col) {
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
    await runBulkDelete(
      context,
      ids: ids,
      delete: CampusService.removeCampus,
      refresh: CampusService.fetchCampuses,
      entityLabel: 'terrein/terreine',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Campus>>(
      valueListenable: CampusService.campusesNotifier,
      builder: (context, allCampuses, _) {
        List<Campus> visibleRowsFor(String query) => allCampuses
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.address.toLowerCase().contains(query))
            .toList();

        return SearchableListScaffold<int>(
          searchHint: "Soek terreine...",
          columns: const [
            ColumnDef(key: 'name', label: 'Naam'),
            ColumnDef(key: 'address', label: 'Adres', defaultVisible: false),
            ColumnDef(key: 'buildings', label: 'Geboue'),
          ],
          canBulkDelete: UserSession.can('locations.manage'),
          bulkDeleteTitle: 'Verwyder Terreine',
          bulkDeleteMessage:
              'Wil jy {count} geselekteerde terrein/terreine verwyder?',
          bulkDeleteChildWarning:
              'Alle onderliggende geboue, lokale, bates, voorraad, foute en take sal ook verwyder word.',
          visibleIdsProvider: (q) =>
              visibleRowsFor(q).map((c) => c.id).toSet(),
          onBulkDelete: _bulkDeleteCampuses,
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
                    MaterialPageRoute(builder: (_) => const CampusFormPage()),
                  ),
                )
              : null,
          content: (context, state) {
            final campuses = allCampuses;

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

            final filtered = visibleRowsFor(state.query);

            return RefreshIndicator(
              onRefresh: () => CampusService.fetchCampuses(),
              color: AppColors.refreshSpinner,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text("Geen terreine gevind nie.")),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(15),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final campus = filtered[index];
                            return SelectableRow<int>(
                              id: campus.id,
                              selection: state.selection,
                              trailing: IconButton(
                                icon: const Icon(Icons.chevron_right,
                                    color: AppColors.gold),
                                tooltip: "Wys geboue van terrein",
                                onPressed: () {
                                  if (state.selection.isSelecting) {
                                    state.selection.toggle(campus.id);
                                  } else {
                                    widget.onCampusSelected(campus);
                                  }
                                },
                              ),
                              onOpen: () async {
                                final edited = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CampusFormPage(campus: campus),
                                  ),
                                );
                                if (edited == true) {
                                  CampusService.fetchCampuses();
                                }
                              },
                              children: _buildCampusCells(campus, state),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/campus_service.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/list_page_scaffold.dart';
import '../../widgets/selectable_row.dart';
import '../../widgets/selection_manager.dart';
import 'new_report_page.dart';
import 'report_detail_page.dart';

/// ReportsPage — Foutkaartjie-lys (rapporte).
///
/// Voorgestelde Werksopdragte het na Werksopdragte geskuif (JobcardsPage se tweede tab) —
/// hierdie bladsy is weer 'n skoon foutkaartjie-lys.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // ── Fault list state ──
  String _statusFilter = "Alles";
  int? _selectedCampusId;
  int? _selectedBuildingId;

  @override
  void initState() {
    super.initState();
    ReportService.fetchReports();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    super.dispose();
  }

  void _onCampusesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Lei die kampus-/gebou-ID af vanaf die lokaal-ID wanneer die verslag se
  /// eie location_id/building_id null is (bv. as die skewende gebruiker nie
  /// 'n kampus kon oplos nie). Soek andersins in die gelaai kampusboom.
  int? _campusIdForReport(Report r) {
    if (r.locationId != null) return r.locationId;
    final roomId = int.tryParse(r.location);
    if (roomId == null) return null;
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        if ((b.rooms ?? const <Room>[]).any((room) => room.id == roomId)) {
          return c.id;
        }
      }
    }
    return null;
  }

  int? _buildingIdForReport(Report r) {
    if (r.buildingId != null) return r.buildingId;
    final roomId = int.tryParse(r.location);
    if (roomId == null) return null;
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        if ((b.rooms ?? const <Room>[]).any((room) => room.id == roomId)) {
          return b.id;
        }
      }
    }
    return null;
  }

  Future<void> _bulkDeleteFaults(BuildContext context, Set<String> ids) async {
    await runBulkDelete(
      context,
      ids: ids,
      delete: ReportService.deleteReport,
      refresh: ReportService.fetchReports,
      entityLabel: 'foutkaartjie(s)',
    );
  }

  int _columnFlex(String key) {
    switch (key) {
      case 'id':
        return 1;
      case 'title':
        return 3;
      case 'location':
        return 2;
      case 'phase':
        return 2;
      case 'timestamp':
        return 2;
      default:
        return 1;
    }
  }

  Widget _buildColumnContent(Report r, String key) {
    switch (key) {
      case 'id':
        return Text("#${r.id}",
            style: const TextStyle(color: Colors.black87, fontSize: 13));
      case 'title':
        return Text(r.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
      case 'location':
        return Text(r.location,
            style: const TextStyle(fontSize: 11, color: Colors.grey));
      case 'phase':
        return StatusBadge(status: r.phase);
      case 'timestamp':
        return Text(
          '${r.timestamp.day}/${r.timestamp.month}/${r.timestamp.year}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleNewReport(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewReportPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationActive =
        _selectedCampusId != null || _selectedBuildingId != null;

    return ValueListenableBuilder<List<Report>>(
      valueListenable: ReportService.reportsNotifier,
      builder: (context, allReports, _) {
        List<Report> visibleRowsFor(String query) => allReports.where((r) {
              final matchesSearch = query.isEmpty ||
                  r.id.toLowerCase().contains(query) ||
                  r.title.toLowerCase().contains(query) ||
                  r.location.toLowerCase().contains(query);
              final matchesStatus =
                  _statusFilter == "Alles" || (r.phase == _statusFilter);
              final matchesCampus = _selectedCampusId == null ||
                  _campusIdForReport(r) == _selectedCampusId;
              final matchesBuilding = _selectedBuildingId == null ||
                  _buildingIdForReport(r) == _selectedBuildingId;
              return matchesSearch &&
                  matchesStatus &&
                  matchesCampus &&
                  matchesBuilding;
            }).toList();

        return SearchableListScaffold<String>(
          searchHint: "Soek verslae...",
          columns: const [
            ColumnDef(key: 'id', label: 'ID', defaultVisible: false),
            ColumnDef(key: 'title', label: 'TITEL'),
            ColumnDef(key: 'location', label: 'Ligging', defaultVisible: false),
            ColumnDef(key: 'phase', label: 'FASE'),
            ColumnDef(key: 'timestamp', label: 'Datum', defaultVisible: false),
          ],
          backgroundColor: Colors.white,
          leadingActions: [
            HeaderIconAction(
              icon: Icons.place_outlined,
              tooltip: "Filter op Ligging",
              activeBadge: locationActive,
              onTap: () => showLocationFilterSheet(
                context,
                depth: LocationDepth.building,
                campusId: _selectedCampusId,
                buildingId: _selectedBuildingId,
                onChanged: (campusId, buildingId, _) => setState(() {
                  _selectedCampusId = campusId;
                  _selectedBuildingId = buildingId;
                }),
              ),
            ),
            HeaderIconAction(
              icon: Icons.filter_alt_outlined,
              tooltip: "Status",
              activeBadge: _statusFilter != "Alles",
              onTap: () => showSearchableDialog<String>(
                context: context,
                title: "Status",
                initialValue: _statusFilter,
                items: const ["Alles", "Ontvang", "Besig", "Voltooi", "Geweier"]
                    .map((s) => SearchableDropdownItem(value: s, label: s))
                    .toList(),
                onSelected: (val) =>
                    setState(() => _statusFilter = val ?? _statusFilter),
              ),
            ),
          ],
          canBulkDelete: UserSession.can('faults.manage'),
          bulkDeleteTitle: 'Verwyder Foutkaartjies',
          bulkDeleteMessage:
              'Wil jy {count} geselekteerde foutkaartjie(s) verwyder?',
          visibleIdsProvider: (q) =>
              visibleRowsFor(q).map((r) => r.id).toSet(),
          onBulkDelete: _bulkDeleteFaults,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.gold,
            elevation: 4,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Nuwe Foutkaartjie",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            onPressed: () => _handleNewReport(context),
          ),
          content: (context, state) {
            final filtered = visibleRowsFor(state.query);

            return RefreshIndicator(
              onRefresh: () => ReportService.fetchReports(),
              color: AppColors.refreshSpinner,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                          child: Text("Geen foutkaartjies gevind nie.",
                              style: TextStyle(color: Colors.grey))),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final r = filtered[index];
                          return SelectableRow<String>(
                            id: r.id,
                            selection: state.selection,
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.gold),
                            onOpen: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ReportDetailPage(report: r)),
                              );
                            },
                            children: state.columnVisibility.visibleColumns
                                .map((col) => Expanded(
                                      flex: _columnFlex(col.key),
                                      child: _buildColumnContent(r, col.key),
                                    ))
                                .toList(),
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

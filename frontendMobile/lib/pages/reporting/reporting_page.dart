import 'package:flutter/material.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/filter_utils.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/campus_service.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/sort_button.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/selection_manager.dart';
import '../../widgets/card_data_row.dart';
import 'new_report_page.dart';
import 'report_detail_page.dart';

/// ReportingPage — Foutkaartjie-lys (rapporte).
///
/// Voorgestelde Werksopdragte het na Werksopdragte geskuif (JobCardsPage se tweede tab) —
/// hierdie bladsy is weer 'n skoon foutkaartjie-lys.
class ReportingPage extends StatefulWidget {
  const ReportingPage({super.key});

  @override
  State<ReportingPage> createState() => _ReportingPageState();
}

class _ReportingPageState extends State<ReportingPage> {
  // ── Fault list state ──
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCampusId;
  int? _selectedBuildingId;
  bool _filterOpen = false;
  bool _sortOpen = false;
  final FilterController _filterCtrl = FilterController('reports');
  String _columnFilter = 'all';
  final MultiSortController _sortCtrl =
      MultiSortController('reports', ['id', 'title', 'location', 'phase', 'timestamp']);
  final ColumnVisibilityController _colVis =
      ColumnVisibilityController('reports', [
    const ColumnDef(key: 'id', label: 'ID', defaultVisible: false),
    const ColumnDef(key: 'title', label: 'TITEL'),
    const ColumnDef(key: 'location', label: 'Ligging', defaultVisible: false),
    const ColumnDef(key: 'phase', label: 'FASE'),
    const ColumnDef(key: 'timestamp', label: 'Datum', defaultVisible: false),
  ]);
  final SelectionController<String> _selection = SelectionController<String>();

  @override
  void initState() {
    super.initState();
    _sortCtrl.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _filterCtrl.initialize().then((_) {
      if (!mounted) return;
      _selectedCampusId = _filterCtrl.campusId;
      _selectedBuildingId = _filterCtrl.buildingId;
      _searchController.text = _filterCtrl.search;
      _columnFilter = _filterCtrl.columnKey;
      setState(() {});
    });
    ReportService.fetchReports();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _searchController.addListener(() {
      _filterCtrl.setSearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          FixedPageHeader(
            controller: _searchController,
            hintText: "Soek verslae...",
            onChanged: (v) => setState(() {}),
            actions: _buildFaultHeaderActions(),
          ),
          if (_filterOpen)
            FilterPanel(
              controller: _filterCtrl,
              depth: LocationDepth.building,
              searchController: _searchController,
              searchHint: "Soek verslae...",
              initialCampusId: _selectedCampusId,
              initialBuildingId: _selectedBuildingId,
              columnItems: [
                const SearchableDropdownItem(
                    value: 'all', label: 'Alle kolomme'),
                ..._colVis.allColumns.map((c) => SearchableDropdownItem(
                    value: c.key, label: c.label)),
              ],
              columnValue: _columnFilter,
              onColumnChanged: (v) => setState(() => _columnFilter = v),
              onLocationChanged: (campusId, buildingId, _) => setState(() {
                _selectedCampusId = campusId;
                _selectedBuildingId = buildingId;
              }),
              onReset: () => setState(() {
                _selectedCampusId = null;
                _selectedBuildingId = null;
                _columnFilter = 'all';
              }),
              onClose: () => setState(() => _filterOpen = false),
            ),
          if (_sortOpen)
            SortPanel(
              controller: _sortCtrl,
              columns: _colVis.allColumns,
              onChanged: () => setState(() {}),
            ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closePanels,
              child: _buildFaultList(),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (UserSession.can('faults.manage')) ...[
            BulkDeleteFloatingAction<String>(
              controller: _selection,
              confirmTitle: 'Verwyder Foutkaartjies',
              confirmMessage:
                  'Wil jy ${_selection.count} geselekteerde foutkaartjie(s) verwyder?',
              onDelete: _bulkDeleteFaults,
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
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
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOUTKAARTJIE-LYS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFaultList() {
    return ValueListenableBuilder<List<Report>>(
      valueListenable: ReportService.reportsNotifier,
      builder: (context, allReports, child) {
        final query = _searchController.text.toLowerCase();
        final filtered = _sortCtrl.apply(
          allReports
              .where((r) {
                final searchableColumn = _columnFilter == 'all'
                    ? ''
                    : switch (_columnFilter) {
                        'id' => r.id,
                        'title' => r.title,
                        'location' => r.location,
                        'phase' => r.phase,
                        _ => '',
                      };
                final matchesSearch = query.isEmpty ||
                    (_columnFilter == 'all'
                        ? r.id.toLowerCase().contains(query) ||
                            r.title.toLowerCase().contains(query) ||
                            r.location.toLowerCase().contains(query) ||
                            r.description.toLowerCase().contains(query) ||
                            r.phase.toLowerCase().contains(query) ||
                            r.priority.toLowerCase().contains(query) ||
                            r.assetId.toLowerCase().contains(query) ||
                            (r.assetSerialCode ?? '')
                                .toLowerCase()
                                .contains(query) ||
                            r.category.toLowerCase().contains(query) ||
                            r.user.toLowerCase().contains(query)
                        : searchableColumn.toLowerCase().contains(query));
                final matchesCampus = _selectedCampusId == null ||
                    _campusIdForReport(r) == _selectedCampusId;
                final matchesBuilding = _selectedBuildingId == null ||
                    _buildingIdForReport(r) == _selectedBuildingId;
                return matchesSearch &&
                    matchesCampus &&
                    matchesBuilding;
              })
              .toList(),
          (r, key) {
            switch (key) {
              case 'id':
                return r.id.toLowerCase();
              case 'title':
                return r.title.toLowerCase();
              case 'location':
                return r.location.toLowerCase();
              case 'phase':
                return r.phase.toLowerCase();
              case 'timestamp':
                return r.timestamp;
              default:
                return '';
            }
          },
        );

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
                      return CardDataRow(
                        leading: _selection.isSelecting
                            ? Checkbox(
                                value: _selection.isSelected(r.id),
                                onChanged: (_) =>
                                    setState(() => _selection.toggle(r.id)),
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.gold),
                        onTap: () {
                          if (_selection.isSelecting) {
                            setState(() => _selection.toggle(r.id));
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      ReportDetailPage(report: r)),
                            );
                          }
                        },
onLongPress: () {
                            if (!UserSession.can('faults.manage')) return;
                            setState(() {
                              _selection.enter();
                              _selection.toggle(r.id);
                            });
                          },
                        children: _colVis.visibleColumns.map((col) {
                          return Expanded(
                            flex: _columnFlex(col.key),
                            child: _buildColumnContent(r, col.key),
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
        );
      },
    );
  }

  List<Widget> _buildFaultHeaderActions() {
    return [
      FilterButton(
        controller: _filterCtrl,
        selected: _filterOpen,
        onPressed: () => setState(() {
          _filterOpen = !_filterOpen;
          _sortOpen = false;
        }),
      ),
      if (UserSession.can('faults.manage')) ...[
        SelectionExitAction<String>(
          controller: _selection,
          onExit: () => setState(() => _selection.exit()),
        ),
      ],
      SortButton(
        controller: _sortCtrl,
        selected: _sortOpen,
        onPressed: () => setState(() {
          _sortOpen = !_sortOpen;
          _filterOpen = false;
        }),
      ),
      ColumnVisibilityButton(controller: _colVis, iconOnly: true),
    ];
  }

  void _closePanels() {
    if (_filterOpen || _sortOpen) {
      setState(() {
        _filterOpen = false;
        _sortOpen = false;
      });
    }
  }

  Future<void> _bulkDeleteFaults(BuildContext context, Set<String> ids) async {
    int ok = 0;
    int fail = 0;
    for (final id in ids) {
      if (await ReportService.deleteReport(id)) {
        ok++;
      } else {
        fail++;
      }
    }
    await ReportService.fetchReports();
    if (context.mounted) {
      setState(() => _selection.exit());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fail == 0
              ? "$ok foutkaartjie(s) verwyder."
              : "$ok verwyder, $fail kon nie verwyder word nie."),
          backgroundColor:
              fail == 0 ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

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
}

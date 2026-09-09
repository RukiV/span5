import 'package:flutter/material.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/campus_service.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import '../../widgets/column_visibility.dart';
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
  String _statusFilter = "Alles";
  int? _selectedCampusId;
  int? _selectedBuildingId;
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('reports', [
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

    ReportService.fetchReports();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _tryAutoSelectCampus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    super.dispose();
  }

  // ── Campus auto-select ──

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
          Expanded(
            child: _buildFaultList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        elevation: 4,
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        label: const Text("Nuwe Foutkaartjie",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        onPressed: () => _handleNewReport(context),
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
        List<Report> filtered = allReports.where((r) {
          final matchesSearch = query.isEmpty ||
              r.id.toLowerCase().contains(query) ||
              r.title.toLowerCase().contains(query) ||
              r.location.toLowerCase().contains(query);
          final matchesStatus = _statusFilter == "Alles" || (r.phase == _statusFilter);
          final matchesCampus = _selectedCampusId == null || _campusIdForReport(r) == _selectedCampusId;
          final matchesBuilding = _selectedBuildingId == null || _buildingIdForReport(r) == _selectedBuildingId;
          return matchesSearch && matchesStatus && matchesCampus && matchesBuilding;
        }).toList();

        if (_sortCtrl.isActive) {
          filtered.sort((a, b) {
            final dir = _sortCtrl.direction;
            switch (_sortCtrl.sortKey) {
              case 'id': return a.id.toLowerCase().compareTo(b.id.toLowerCase()) * dir;
              case 'title': return a.title.toLowerCase().compareTo(b.title.toLowerCase()) * dir;
              case 'location': return a.location.toLowerCase().compareTo(b.location.toLowerCase()) * dir;
              case 'phase': return a.phase.toLowerCase().compareTo(b.phase.toLowerCase()) * dir;
              case 'timestamp': return a.timestamp.compareTo(b.timestamp) * dir;
              default: return 0;
            }
          });
        }

        return RefreshIndicator(
          onRefresh: () => ReportService.fetchReports(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text("Geen foutkaartjies gevind nie.", style: TextStyle(color: Colors.grey))),
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
                                onChanged: (_) => setState(() => _selection.toggle(r.id)),
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
                        onTap: () {
                          if (_selection.isSelecting) {
                            setState(() => _selection.toggle(r.id));
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ReportDetailPage(report: r)),
                            );
                          }
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
    final locationActive = _selectedCampusId != null || _selectedBuildingId != null;
    return [
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
          onSelected: (val) => setState(() => _statusFilter = val ?? _statusFilter),
        ),
      ),
      if (UserSession.can('faults.manage')) ...[
        SelectModeButton<String>(
          controller: _selection,
          onToggle: () => setState(() =>
              _selection.isSelecting ? _selection.exit() : _selection.enter()),
        ),
        BulkDeleteAction<String>(
          controller: _selection,
          confirmTitle: 'Verwyder Foutkaartjies',
          confirmMessage: 'Wil jy ${_selection.count} geselekteerde foutkaartjie(s) verwyder?',
          onDelete: _bulkDeleteFaults,
        ),
      ],
      ColumnVisibilityButton(controller: _colVis, iconOnly: true),
    ];
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
          backgroundColor: fail == 0 ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  int _columnFlex(String key) {
    switch (key) {
      case 'id': return 1;
      case 'title': return 3;
      case 'location': return 2;
      case 'phase': return 2;
      case 'timestamp': return 2;
      default: return 1;
    }
  }

  Widget _buildColumnContent(Report r, String key) {
    switch (key) {
      case 'id':
        return Text("#${r.id}", style: const TextStyle(color: Colors.black87, fontSize: 13));
      case 'title':
        return Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
      case 'location':
        return Text(r.location, style: const TextStyle(fontSize: 11, color: Colors.grey));
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

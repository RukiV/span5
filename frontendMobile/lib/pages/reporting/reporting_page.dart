<<<<<<< HEAD
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
import '../../models/user_session.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/sort_utils.dart';
import 'new_report_page.dart';
import 'report_detail_page.dart';

/// ReportingPage — Foutkaartjie-lys (rapporte).
///
/// AI Konsepte het na Werksopdragte geskuif (JobCardsPage se tweede tab) —
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
    const ColumnDef(key: 'id', label: 'ID'),
    const ColumnDef(key: 'title', label: 'TITEL'),
    const ColumnDef(key: 'location', label: 'Ligging', defaultVisible: false),
    const ColumnDef(key: 'phase', label: 'FASE'),
    const ColumnDef(key: 'timestamp', label: 'Datum', defaultVisible: false),
  ]);

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
          final matchesCampus = _selectedCampusId == null || r.locationId == _selectedCampusId;
          final matchesBuilding = _selectedBuildingId == null || r.buildingId == _selectedBuildingId;
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
                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ReportDetailPage(report: r)),
                              );
                            },
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                              child: Row(
                                children: _colVis.visibleColumns.map((col) {
                                  return Expanded(
                                    flex: _columnFlex(col.key),
                                    child: _buildColumnContent(r, col.key),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
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
      ColumnVisibilityButton(controller: _colVis, iconOnly: true),
    ];
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
=======
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../models/report.dart';
import 'new_report_page.dart';
import 'report_detail_page.dart';

class ReportingPage extends StatefulWidget {
  const ReportingPage({super.key});

  @override
  State<ReportingPage> createState() => _ReportingPageState();
}

class _ReportingPageState extends State<ReportingPage> {
  String _searchQuery = "";
  String _statusFilter = "Alles";

  @override
  void initState() {
    super.initState();
    ReportService.fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Report>>(
      valueListenable: ReportService.reportsNotifier,
      builder: (context, allReports, child) {
        // SOEK EN FILTRERING
        List<Report> filtered = allReports.where((r) {
          final matchesSearch = _searchQuery.isEmpty || 
              r.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.location.toLowerCase().contains(_searchQuery.toLowerCase());
          
          final matchesStatus = _statusFilter == "Alles" || (r.phase == _statusFilter);
          
          return matchesSearch && matchesStatus;
        }).toList();

        // Sortering (Nuutste bo)
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildSearchBarWithFilter(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ReportService.fetchReports(),
                  child: _buildReportList(context, filtered),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.gold,
            elevation: 4,
            icon: const Icon(Icons.add_a_photo, color: Colors.white),
            label: const Text("Nuwe Foutkaartjie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: () => _handleNewReport(context),
          ),
        );
      },
    );
  }

  Widget _buildSearchBarWithFilter() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Soek verslae...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 150/255), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                fillColor: Colors.white.withValues(alpha: 30/255),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 30/255),
              borderRadius: BorderRadius.circular(30),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: AppColors.navy,
                icon: const Icon(Icons.filter_list, color: AppColors.gold),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                items: ["Alles", "Ontvang", "Besig", "Voltooi", "Geweier"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _statusFilter = val!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(BuildContext context, List<Report> reports) {
    if (reports.isEmpty) {
      return const Center(child: Text("Geen foutkaartjies gevind nie.", style: TextStyle(color: Colors.grey)));
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          color: AppColors.gold,
          child: const Row(
            children: [
              Expanded(flex: 1, child: Text("ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 3, child: Text("Beskrywing", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text("Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = reports[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ReportDetailPage(report: r)),
                  );
                },
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text("#${r.id}", style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(r.location, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildStatusChip(r.phase),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    switch (status) {
      case 'Ontvang': color = AppColors.infoBlue; break;
      case 'Besig': color = AppColors.warningOrange; break;
      case 'Voltooi': color = AppColors.successGreen; break;
      case 'Geweier': color = AppColors.errorRed; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // _buildStatusText verwyder aangesien ons nou die herbruikbare StatusBadge widget gebruik

  void _handleNewReport(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewReportPage()),
    );
    // Data word nou binne NewReportPage gestoor via ReportService.addReport
  }
}
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

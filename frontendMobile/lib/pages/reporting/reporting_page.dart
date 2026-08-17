import 'package:flutter/material.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/campus_service.dart';
import '../../services/ai_service.dart';
import '../../models/report.dart';
import '../../models/fault_draft.dart';
import '../../models/user_session.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/sort_utils.dart';
import 'new_report_page.dart';
import 'report_detail_page.dart';
import '../ai/ai_draft_review_page.dart';

/// ReportingPage — Foutkaartjie-lys met gedeelde tab-balk vir AI Konsepte
/// (spieël die web se FaultTabs-patroon).
///
/// Tab 1: Foutkaartjies (rapportlys)
/// Tab 2: AI Konsepte (slegs met ai.approve-reg; toon wag-aantal badge)
class ReportingPage extends StatefulWidget {
  const ReportingPage({super.key});

  @override
  State<ReportingPage> createState() => _ReportingPageState();
}

class _ReportingPageState extends State<ReportingPage>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ──
  late final TabController _tabController;
  late final bool _canApprove;
  int _pendingCount = 0;

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

  // ── AI draft queue state ──
  String? _aiStatusFilter = 'draft';

  @override
  void initState() {
    super.initState();
    _canApprove = UserSession.can('ai.approve');
    _tabController = TabController(
      length: _canApprove ? 2 : 1,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);

    ReportService.fetchReports();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _tryAutoSelectCampus();

    if (_canApprove) {
      _fetchPendingCount();
      AiService.fetchDrafts(statusFilter: _aiStatusFilter);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Refresh data when switching tabs
    if (_tabController.index == 0) {
      ReportService.fetchReports();
    } else if (_tabController.index == 1 && _canApprove) {
      AiService.fetchDrafts(statusFilter: _aiStatusFilter);
      _fetchPendingCount();
    }
  }

  Future<void> _fetchPendingCount() async {
    try {
      final result = await AiService.draftsRaw(statusFilter: 'draft');
      if (mounted) setState(() => _pendingCount = result.length);
    } catch (_) {}
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
            hintText: _tabController.index == 0 ? "Soek verslae..." : "Soek AI-konsepte...",
            onChanged: (v) => setState(() {}),
            actions: _tabController.index == 0 ? _buildFaultHeaderActions() : [],
          ),
          if (_canApprove) _buildTabBar(),
          Expanded(
            child: _tabController.index == 0
                ? _buildFaultListTab()
                : _buildAiDraftTab(),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              elevation: 4,
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text("Nuwe Foutkaartjie",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              onPressed: () => _handleNewReport(context),
            )
          : null,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.navy,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppColors.gold,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: [
          const Tab(text: 'Foutkaartjies'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('AI Konsepte'),
                if (_pendingCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_pendingCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — FOUTKAARTJIES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFaultListTab() {
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
  // TAB 2 — AI KONSEPTE (geïntegreerde uit AIDraftQueuePage)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAiDraftTab() {
    return Column(
      children: [
        _buildAiFilterRow(),
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: AiService.isLoadingNotifier,
            builder: (context, isLoading, _) {
              if (isLoading && AiService.draftsNotifier.value.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.gold));
              }
              return ValueListenableBuilder<List<FaultDraft>>(
                valueListenable: AiService.draftsNotifier,
                builder: (context, drafts, _) {
                  if (AiService.lastError != null && drafts.isEmpty) {
                    return _buildAiErrorState();
                  }
                  if (drafts.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refetchAiDrafts,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text("Geen AI-konsepte gevind nie.")),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _refetchAiDrafts,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: drafts.length,
                      itemBuilder: (context, index) => _buildDraftTile(drafts[index]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _refetchAiDrafts() async {
    await AiService.fetchDrafts(statusFilter: _aiStatusFilter);
    _fetchPendingCount();
  }

  void _onAiFilterChanged(String? filter) {
    if (_aiStatusFilter == filter) return;
    setState(() => _aiStatusFilter = filter);
    AiService.fetchDrafts(statusFilter: filter);
  }

  Widget _buildAiFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildAiFilterChip(label: "Alle", value: null),
          const SizedBox(width: 8),
          _buildAiFilterChip(label: "Wag", value: 'draft'),
          const SizedBox(width: 8),
          _buildAiFilterChip(label: "Goedgekeur", value: 'approved'),
          const SizedBox(width: 8),
          _buildAiFilterChip(label: "Verwerp", value: 'rejected'),
        ],
      ),
    );
  }

  Widget _buildAiFilterChip({required String label, required String? value}) {
    final bool isSelected = _aiStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onAiFilterChanged(value),
      selectedColor: AppColors.navy,
      backgroundColor: Colors.white,
      side: BorderSide(color: AppColors.navy.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.navy,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildAiErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.errorRed, size: 40),
            const SizedBox(height: 12),
            Text(
              AiService.lastError ?? "Kon nie AI-konsepte laai nie.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.errorRed),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _refetchAiDrafts,
              child: const Text("Probeer weer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftTile(FaultDraft draft) {
    final String titleText = draft.title.isNotEmpty
        ? draft.title
        : (draft.description.length > 60
            ? '${draft.description.substring(0, 60)}...'
            : draft.description);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => AiDraftReviewPage(draftId: draft.draftId)),
          );
          if (result == true) {
            _refetchAiDrafts();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _AiDraftStatusPill(status: draft.status),
                  _AiDraftTag(label: draft.typeLabel),
                  _AiDraftTag(label: draft.priorityLabel),
                  if (draft.aiStatus == 'ok')
                    const _AiBadge(label: 'AI', color: AppColors.successGreen)
                  else
                    const _AiBadge(label: 'Beperk', color: AppColors.warningOrange),
                  Text(
                    draft.source == 'auto' ? 'Outomaties' : 'Handmatig',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              if (draft.createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatAiDate(draft.createdAt!),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAiDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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

// ════════════════════════════════════════════════════════════════════════════
// AI DRAFT SUB-WIDGETS (herbenoem om konflik met ai_draft_queue_page te vermy)
// ════════════════════════════════════════════════════════════════════════════

class _AiDraftStatusPill extends StatelessWidget {
  final String status;
  const _AiDraftStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (status) {
      case 'approved':
        color = AppColors.successGreen;
        label = 'Goedgekeur';
        break;
      case 'rejected':
        color = AppColors.errorRed;
        label = 'Verwerp';
        break;
      default:
        color = AppColors.infoBlue;
        label = 'Wag';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _AiDraftTag extends StatelessWidget {
  final String label;
  const _AiDraftTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.navy, fontSize: 11)),
    );
  }
}

class _AiBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _AiBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

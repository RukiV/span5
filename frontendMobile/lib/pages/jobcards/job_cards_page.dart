import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/user_session.dart';
import '../../services/jobcard_service.dart';
import '../../services/ai_service.dart';
import '../../models/jobcard.dart';
import '../../models/job_draft.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/selection_manager.dart';
import '../../widgets/card_data_row.dart';
import '../../widgets/fixed_page_header.dart';
import 'jobcard_detail_page.dart';
import '../ai/ai_draft_review_page.dart';

/// JobCardsPage — Werkkaart-lys met gedeelde tab-balk vir Voorgestelde
/// Werksopdragte (spieël die web se JobTabs-patroon).
///
/// Tab 1: Werksopdragte (werkkaartlys)
/// Tab 2: Voorgestelde Werksopdragte (slegs met ai.approve-reg; toon wag-aantal badge)
class JobCardsPage extends StatefulWidget {
  const JobCardsPage({super.key});

  @override
  State<JobCardsPage> createState() => _JobCardsPageState();
}

class _JobCardsPageState extends State<JobCardsPage>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ──
  late final TabController _tabController;
  late final bool _canApprove;
  int _pendingCount = 0;

  // ── Job list state ──
  final TextEditingController _searchController = TextEditingController();
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('jobcards', [
    const ColumnDef(key: 'id', label: 'ID', defaultVisible: false),
    const ColumnDef(key: 'description', label: 'Beskrywing'),
    const ColumnDef(key: 'type', label: 'Tipe', defaultVisible: false),
    const ColumnDef(key: 'status', label: 'Status'),
    const ColumnDef(key: 'date', label: 'Datum', defaultVisible: false),
  ]);
  final SelectionController<int> _selection = SelectionController<int>();
  String _searchQuery = "";

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

    JobcardService.fetchJobs();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

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
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {}); // Force rebuild so content switches between tabs
    // Refresh data when switching tabs
    if (_tabController.index == 0) {
      JobcardService.fetchJobs();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          FixedPageHeader(
            controller: _searchController,
            hintText: _tabController.index == 0 ? "Soek werkkaarte..." : "Soek voorgestelde werksopdragte...",
            onChanged: (v) => setState(() {}),
            actions: _tabController.index == 0 ? _buildJobHeaderActions() : [],
          ),
          if (_canApprove) _buildTabBar(),
          Expanded(
            child: _tabController.index == 0
                ? _buildJobListTab()
                : _buildAiDraftTab(),
          ),
        ],
      ),
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
          const Tab(text: 'Werksopdragte'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Voorgestelde Werksopdragte'),
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
  // TAB 1 — WERKSOPDRAGTE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildJobListTab() {
    return ValueListenableBuilder<List<Jobcard>>(
      valueListenable: JobcardService.jobcardsNotifier,
      builder: (context, jobcards, child) {
        final activeJobs = jobcards
            .where((j) =>
                j.status == "Besig" ||
                j.status == "Geskeduleer" ||
                j.status == "Voltooi" ||
                j.status == "Oop" ||
                j.status == "Wag" ||
                j.status == "Gekanselleer")
            .toList();

        final filtered = activeJobs.where((j) {
          if (_searchQuery.isEmpty) return true;
          return j.description.toLowerCase().contains(_searchQuery) ||
              j.id.toString().contains(_searchQuery) ||
              (j.type?.toLowerCase().contains(_searchQuery) ?? false);
        }).toList();

        if (_sortCtrl.isActive) {
          filtered.sort((a, b) {
            final dir = _sortCtrl.direction;
            switch (_sortCtrl.sortKey) {
              case 'id':
                return a.id.compareTo(b.id) * dir;
              case 'description':
                return a.description
                        .toLowerCase()
                        .compareTo(b.description.toLowerCase()) *
                    dir;
              case 'type':
                return (a.type ?? '')
                        .toLowerCase()
                        .compareTo((b.type ?? '').toLowerCase()) *
                    dir;
              case 'status':
                return a.status.toLowerCase().compareTo(b.status.toLowerCase()) *
                    dir;
              case 'date':
                return (a.createdDatetime ?? DateTime(0))
                        .compareTo(b.createdDatetime ?? DateTime(0)) *
                    dir;
              default:
                return 0;
            }
          });
        }

        return RefreshIndicator(
          onRefresh: () => JobcardService.fetchJobs(),
          color: AppColors.gold,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildJobCard(filtered[index]),
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
  }

  List<Widget> _buildJobHeaderActions() {
    return [
      if (UserSession.can('jobs.manage')) ...[
        SelectModeButton<int>(
          controller: _selection,
          onToggle: () => setState(() =>
              _selection.isSelecting ? _selection.exit() : _selection.enter()),
        ),
        BulkDeleteAction<int>(
          controller: _selection,
          confirmTitle: 'Verwyder Werksopdragte',
          confirmMessage: 'Wil jy ${_selection.count} geselekteerde werksopdrag(te) verwyder?',
          onDelete: _bulkDeleteJobs,
        ),
      ],
      ColumnVisibilityButton(controller: _colVis, iconOnly: true),
    ];
  }

  Future<void> _bulkDeleteJobs(BuildContext context, Set<int> ids) async {
    int ok = 0;
    int fail = 0;
    for (final id in ids) {
      if (await JobcardService.deleteJob(id)) {
        ok++;
      } else {
        fail++;
      }
    }
    await JobcardService.fetchJobs();
    if (context.mounted) {
      setState(() => _selection.exit());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fail == 0
              ? "$ok werksopdrag(te) verwyder."
              : "$ok verwyder, $fail kon nie verwyder word nie."),
          backgroundColor: fail == 0 ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? "Geen werkkaarte gevind nie"
                  : "Geen aktiewe werkkaarte nie",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => JobcardService.fetchJobs(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
              ),
              child: const Text("Herlaai"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Jobcard job) {
    return CardDataRow(
      leading: _selection.isSelecting
          ? Checkbox(
              value: _selection.isSelected(job.id),
              onChanged: (_) => setState(() => _selection.toggle(job.id)),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
      onTap: () {
        if (_selection.isSelecting) {
          setState(() => _selection.toggle(job.id));
        } else {
          _openJob(job);
        }
      },
      children: _buildJobCells(job),
    );
  }

  List<Widget> _buildJobCells(Jobcard job) {
    return _colVis.visibleColumns.map((col) {
      int flex = 2;
      Widget child;
      switch (col.key) {
        case 'id':
          flex = 1;
          child = Text(
            "#${job.id}",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
          );
          break;
        case 'description':
          flex = 3;
          child = Text(
            job.description,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
          );
          break;
        case 'type':
          flex = 2;
          child = Text(
            job.type ?? '',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          );
          break;
        case 'status':
          flex = 2;
          child = _buildStatusChip(job.status);
          break;
        case 'date':
          flex = 2;
          child = Text(
            job.createdDatetime != null ? _formatDate(job.createdDatetime!) : '-',
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

  void _openJob(Jobcard job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobcardDetailPage(job: job)),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Besig':
        return Colors.blue;
      case 'Geskeduleer':
        return Colors.teal;
      case 'Voltooi':
        return Colors.green;
      case 'Oop':
        return Colors.orange;
      case 'Wag':
        return Colors.amber;
      case 'Gekanselleer':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — VOORGESTELDE WERKSOPDRAGTE (geïntegreer, spieël web se JobTabs-badge)
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
              return ValueListenableBuilder<List<JobDraft>>(
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
                          Center(child: Text("Geen voorgestelde werksopdragte gevind nie.")),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
              AiService.lastError ?? "Kon nie voorgestelde werksopdragte laai nie.",
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

  Widget _buildDraftTile(JobDraft draft) {
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
}

// ════════════════════════════════════════════════════════════════════════════
// AI DRAFT SUB-WIDGETS
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


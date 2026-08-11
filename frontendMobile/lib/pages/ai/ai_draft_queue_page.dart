import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/fault_draft.dart';
import '../../services/ai_service.dart';
import 'ai_draft_review_page.dart';

/// AIDraftQueuePage: Die goedkeurings-ry vir AI-foutkonsepte. FK/Admin sien
/// alle konsepte (Wag/Goedgekeur/Verwerp) en tik om 'n konsep te hersien.
class AIDraftQueuePage extends StatefulWidget {
  const AIDraftQueuePage({super.key});

  @override
  State<AIDraftQueuePage> createState() => _AIDraftQueuePageState();
}

class _AIDraftQueuePageState extends State<AIDraftQueuePage> {
  String? _statusFilter = 'draft';

  @override
  void initState() {
    super.initState();
    AiService.fetchDrafts(statusFilter: _statusFilter);
  }

  Future<void> _refetch() async {
    await AiService.fetchDrafts(statusFilter: _statusFilter);
  }

  void _onFilterChanged(String? filter) {
    if (_statusFilter == filter) return;
    setState(() => _statusFilter = filter);
    AiService.fetchDrafts(statusFilter: filter);
  }

  Future<void> _openReview(int draftId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AiDraftReviewPage(draftId: draftId)),
    );
    if (result == true) {
      _refetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("AI Konsepte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildFilterRow(),
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
                      return _buildErrorState();
                    }
                    if (drafts.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _refetch,
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
                      onRefresh: _refetch,
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
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(label: "Alle", value: null),
          const SizedBox(width: 8),
          _buildFilterChip(label: "Wag", value: 'draft'),
          const SizedBox(width: 8),
          _buildFilterChip(label: "Goedgekeur", value: 'approved'),
          const SizedBox(width: 8),
          _buildFilterChip(label: "Verwerp", value: 'rejected'),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String? value}) {
    final bool isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(value),
      selectedColor: AppColors.navy,
      backgroundColor: Colors.white,
      side: BorderSide(color: AppColors.navy.withValues(alpha: 0.3)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.navy,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildErrorState() {
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
              onPressed: _refetch,
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
        onTap: () => _openReview(draft.draftId),
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
                  _DraftStatusPill(status: draft.status),
                  _DraftTag(label: draft.typeLabel),
                  _DraftTag(label: draft.priorityLabel),
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
                    _formatDate(draft.createdAt!),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Formaat: dd/MM/yyyy
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

/// Klein status-kapsule: groen Goedgekeur, blou Wag, rooi Verwerp.
class _DraftStatusPill extends StatelessWidget {
  final String status;

  const _DraftStatusPill({required this.status});

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
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Neutrale klein tipe/prioriteit-etiket.
class _DraftTag extends StatelessWidget {
  final String label;

  const _DraftTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.navy, fontSize: 11),
      ),
    );
  }
}

/// AI-status-kapsule: groen "AI" of oranje "Beperk".
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
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

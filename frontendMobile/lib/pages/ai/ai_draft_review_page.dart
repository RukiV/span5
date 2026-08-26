import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/job_draft.dart';
import '../../services/ai_service.dart';
import '../../widgets/ai_suggestions_panel.dart';

/// AiDraftReviewPage: Laat die FK/Admin 'n AI-konsep lees, wysig en goedkeur
/// of verwerp. Net hier word 'n konsep 'n werklike foutkaartjie.
class AiDraftReviewPage extends StatefulWidget {
  final int draftId;

  const AiDraftReviewPage({super.key, required this.draftId});

  @override
  State<AiDraftReviewPage> createState() => _AiDraftReviewPageState();
}

class _AiDraftReviewPageState extends State<AiDraftReviewPage> {
  JobDraftDetail? _detail;
  String? _loadError;
  bool _submitting = false;

  final _titleController = TextEditingController();
  final _cleanedController = TextEditingController();

  String? _selectedType;
  String? _selectedPriority;
  int? _selectedAssetId;
  int? _selectedRoomId;

  // Afrikaanse verduidelikings per werksoort (spieël web se JOB_TYPE_HELP).
  static const _typeHelp = {
    'REPAIR': "Herstelwerk: daar is 'n fout — vind die probleem en maak dit reg sodat alles weer werk.",
    'MAINTENANCE': 'Onderhoud: roetinewerk om afbreek te voorkom — dienseer, skoonmaak of vervang van verbruiksonderdele.',
    'INSPECTION': 'Kyk of alles met die bate werk en ondersoek die bate fisies vir enige probleme.',
    'INSTALLATION': "Installasie: 'n nuwe toestel of onderdeel word opgesit en in werking gestel.",
  };
  static const _typeFallbackHelp =
      'Kies die soort werk: Herstel (iets is gebreek), Onderhoud (roetine-diens), Inspeksie (kyk of alles werk) of Installasie (nuwe toestel opsit).';

  // (backend-enum, Afrikaanse etiket)
  static const _types = [
    ('REPAIR', 'Herstel'),
    ('MAINTENANCE', 'Onderhoud'),
    ('INSPECTION', 'Inspeksie'),
    ('INSTALLATION', 'Installasie'),
  ];

  static const _priorities = [
    ('LOW', 'Laag'),
    ('MEDIUM', 'Medium'),
    ('HIGH', 'Hoog'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cleanedController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final detail = await AiService.fetchDraftDetail(widget.draftId);
    if (!mounted) return;
    if (detail == null) {
      setState(() => _loadError = "Kon nie die konsep laai nie. Probeer weer.");
      return;
    }
    setState(() {
      _detail = detail;
      _titleController.text = detail.title;
      _cleanedController.text = detail.cleanedDescription;
      // Val terug na die eerste geldige opsie as die AI 'n vreemde waarde gee.
      _selectedType = _types.any((t) => t.$1 == detail.suggestedType)
          ? detail.suggestedType
          : _types.first.$1;
      _selectedPriority = _priorities.any((p) => p.$1 == detail.suggestedPriority)
          ? detail.suggestedPriority
          : _priorities.first.$1;
      _selectedAssetId = detail.assetCandidates.any((c) => c.id == detail.resolvedAssetId)
          ? detail.resolvedAssetId
          : null;
      _selectedRoomId = detail.roomCandidates.any((c) => c.id == detail.resolvedRoomId)
          ? detail.resolvedRoomId
          : null;
    });
  }

  Future<void> _handleApprove() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final result = await AiService.approveDraft(
      widget.draftId,
      cleanedDescription: _cleanedController.text.trim().isEmpty
          ? null
          : _cleanedController.text.trim(),
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      faultType: _selectedType,
      faultPriority: _selectedPriority,
      assetId: _selectedAssetId,
      roomId: _selectedRoomId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Konsep goedgekeur as foutkaartjie"),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    } else if (result.statusCode == 409) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Konsep is reeds hersien"),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Kon nie die konsep goedkeur nie: ${result.error ?? 'Onbekende fout'}"),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _handleReject() async {
    if (_submitting) return;
    final reason = await _showRejectDialog();
    if (reason == null || !mounted) return;
    setState(() => _submitting = true);
    final result = await AiService.rejectDraft(widget.draftId, reason);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Konsep verwerp"),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    } else if (result.statusCode == 409) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Konsep is reeds hersien"),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Kon nie die konsep verwerp nie: ${result.error ?? 'Onbekende fout'}"),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Verwerp konsep"),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Rede",
              hintText: "Hoekom word hierdie konsep verwerp?",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().length < 2) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text("Tik 'n rede van minstens 2 karakters."),
                      backgroundColor: AppColors.warningOrange,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
              ),
              child: const Text("Verwerp", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Konsep #${widget.draftId}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, style: const TextStyle(color: AppColors.errorRed)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _load,
                child: const Text("Probeer weer"),
              ),
            ],
          ),
        ),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: "OORSPRONKLIKE BESKRYWING",
            child: Text(
              detail.description,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
          _buildSectionCard(
            title: "WYSIG",
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration("Opskrif"),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _cleanedController,
                  maxLines: 3,
                  decoration: _inputDecoration("Geskande beskrywing").copyWith(
                    suffixIcon: Tooltip(
                      message:
                          "Die oorspronklike foutbeskrywing, netjies herskryf: spelfoute en herhaling reggemaak en die kernprobleem duidelik gestate — sonder om inligting by te voeg of te versin. Dit word die werkkaart se beskrywing by goedkeuring.",
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 6),
                      child: const Icon(Icons.help_outline, size: 20, color: AppColors.gold),
                    ),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: _inputDecoration("Werksoort").copyWith(
                    suffixIcon: Tooltip(
                      message: _typeHelp[_selectedType] ?? _typeFallbackHelp,
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 6),
                      child: const Icon(Icons.help_outline, size: 20, color: AppColors.gold),
                    ),
                  ),
                  items: _types
                      .map((t) => DropdownMenuItem<String>(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: _submitting ? null : (v) => setState(() => _selectedType = v),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPriority,
                  decoration: _inputDecoration("Prioriteit"),
                  items: _priorities
                      .map((p) => DropdownMenuItem<String>(value: p.$1, child: Text(p.$2)))
                      .toList(),
                  onChanged: _submitting ? null : (v) => setState(() => _selectedPriority = v),
                ),
              ],
            ),
          ),
          AiSuggestionsPanel(
            context: 'draft',
            fields: {
              'description': detail.description,
              'title': _titleController.text,
              'cleaned_description': _cleanedController.text,
              'fault_type': _selectedType,
              'fault_priority': _selectedPriority,
            },
            labels: const {
              'title': 'Titel',
              'suggested_type': 'Werksoort',
              'suggested_priority': 'Prioriteit',
            },
            onUse: (key, s) {
              setState(() {
                switch (key) {
                  case 'title':
                    _titleController.text = s.value;
                    break;
                  case 'suggested_type':
                    if (_types.any((t) => t.$1 == s.value)) _selectedType = s.value;
                    break;
                  case 'suggested_priority':
                    if (_priorities.any((p) => p.$1 == s.value)) _selectedPriority = s.value;
                    break;
                }
              });
            },
          ),
          _buildSectionCard(
            title: "ONTLOPING",
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedAssetId,
                  decoration: _inputDecoration("Bate"),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text("Geen bate")),
                    ...detail.assetCandidates.map(
                      (c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text('${c.name} — ${c.detail}', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _selectedAssetId = v),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  initialValue: _selectedRoomId,
                  decoration: _inputDecoration("Lokaal"),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text("Geen lokaal")),
                    ...detail.roomCandidates.map(
                      (c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text('${c.name} — ${c.detail}', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _selectedRoomId = v),
                ),
              ],
            ),
          ),
          _buildSectionCard(
            title: "STELSELINLIGTING",
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ReviewBadge(
                  label: detail.aiStatus == 'ok' ? 'AI' : 'Beperk',
                  color: detail.aiStatus == 'ok' ? AppColors.successGreen : AppColors.warningOrange,
                ),
                _ReviewBadge(
                  label: detail.source == 'auto' ? 'Outomaties' : 'Handmatig',
                  color: AppColors.infoBlue,
                ),
                _ReviewBadge(
                  label: detail.statusLabel,
                  color: _statusColor(detail.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "GOEDKEUR",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: OutlinedButton(
              onPressed: _submitting ? null : _handleReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.errorRed,
                side: const BorderSide(color: AppColors.errorRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "VERWERP",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.successGreen;
      case 'rejected':
        return AppColors.errorRed;
      default:
        return AppColors.infoBlue;
    }
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.1),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gold, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    );
  }
}

/// Klein stelselinligting-kapsule.
class _ReviewBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ReviewBadge({required this.label, required this.color});

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

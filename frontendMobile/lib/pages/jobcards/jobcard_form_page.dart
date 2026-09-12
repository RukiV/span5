import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/idempotency.dart';
import '../../core/datetime_utils.dart';
import '../../models/jobcard.dart';
import '../../models/quote.dart';
import '../../models/report.dart';
import '../../models/user.dart';
import '../../models/user_session.dart';
import '../../services/asset_service.dart';
import '../../services/camera_service.dart';
import '../../services/campus_service.dart';
import '../../services/document_service.dart';
import '../../services/image_service.dart';
import '../../services/jobcard_service.dart';
import '../../services/quote_service.dart';
import '../../services/outlook_service.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/inline_searchable_dropdown.dart';
import '../../widgets/searchable_dropdown.dart' show SearchableDropdownItem;
import '../../widgets/app_snack_bar.dart';

/// 'n Tydelike kwotasie-draft in die vorm — word eers aan die backend gestoor
/// wanneer die hele werksopdrag gestoor word (of wanneer die kwotasie-keuse
/// met die "Stoor Keuse"-knoppie bevestig word).
class _QuoteDraft {
  int? quoteId;
  final int tempId;
  int? contractorId;
  String? contractorName;
  File? pdfFile;
  final List<QuoteDocument> existingDocs = [];
  String? selectionReason;
  bool selectionSaved = false;
  String? idempotencyKey;

  _QuoteDraft(this.tempId);

  bool get hasPdf => pdfFile != null || existingDocs.isNotEmpty;

  bool get hasContractor =>
      contractorId != null || (contractorName ?? '').trim().isNotEmpty;
}

class _QuoteDialogResult {
  final int? contractorId;
  final String? contractorName;
  final File pdfFile;

  const _QuoteDialogResult({
    required this.contractorId,
    required this.contractorName,
    required this.pdfFile,
  });
}

class _AddQuoteDialog extends StatefulWidget {
  final List<User> contractors;

  const _AddQuoteDialog({required this.contractors});

  @override
  State<_AddQuoteDialog> createState() => _AddQuoteDialogState();
}

class _AddQuoteDialogState extends State<_AddQuoteDialog> {
  int? _contractorId;
  String _contractorName = '';
  File? _pdfFile;
  bool _isNewContractor = false;

  Future<void> _pickQuotePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _pdfFile = File(path));
  }

  void _submit() {
    if (!_isNewContractor && _contractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kies 'n kontrakteur vir die kwotasie."),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    if (_pdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Laai 'n PDF op vir die kwotasie (verpligtend)."),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    final selectedUser =
        widget.contractors.where((u) => u.id == _contractorId).firstOrNull;
    Navigator.pop(
      context,
      _QuoteDialogResult(
        contractorId: _isNewContractor ? null : _contractorId,
        contractorName:
            _isNewContractor ? _contractorName.trim() : selectedUser?.displayName,
        pdfFile: _pdfFile!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Voeg Kwotasie By",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Kontrakteur",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: const Text("Bestaande kontrakteur", style: TextStyle(fontSize: 12)),
                  selected: !_isNewContractor,
                  onSelected: (_) =>
                      setState(() => _isNewContractor = false),
                ),
                ChoiceChip(
                  label: const Text("Nuwe kontrakteur", style: TextStyle(fontSize: 12)),
                  selected: _isNewContractor,
                  onSelected: (_) => setState(() => _isNewContractor = true),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isNewContractor)
              TextFormField(
                key: const ValueKey('new_contractor_name'),
                initialValue: _contractorName,
                decoration: const InputDecoration(
                  labelText: "Kontrakteur Naam",
                  hintText: "Tik die kontrakteur se naam",
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _contractorName = v,
              )
            else
              InlineSearchableDropdown<int?>(
                label: "Kies kontrakteur",
                hint: "Kies Kontrakteur",
                value: _contractorId,
                items: widget.contractors
                    .map((u) => SearchableDropdownItem<int?>(
                        value: u.id, label: u.displayName))
                    .toList(),
                onChanged: (v) => setState(() => _contractorId = v),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickQuotePdf,
                    icon: const Icon(Icons.picture_as_pdf, color: AppColors.errorRed),
                    label: Text(
                      _pdfFile != null
                          ? _pdfFile!.path.split('/').last
                          : "Laai PDF op (verpligtend)",
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_pdfFile != null)
                  IconButton(
                    onPressed: () => setState(() => _pdfFile = null),
                    icon: const Icon(Icons.close, color: AppColors.errorRed),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _submit,
                  child: const Text("Voeg By", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JobcardFormPage extends StatefulWidget {
  /// Foutkaartjie waaruit die werksopdrag geskep word (opsioneel).
  final Report? report;

  /// Bestaande werksopdrag wat gewysig word (opsioneel).
  final Jobcard? jobcard;

  const JobcardFormPage({super.key, this.report, this.jobcard});

  bool get isEditing => jobcard != null;

  @override
  State<JobcardFormPage> createState() => _JobcardFormPageState();
}

class _JobcardFormPageState extends State<JobcardFormPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _briefController = TextEditingController();
  final _notesController = TextEditingController();

  final List<String> _statuses = ["Wag", "Oop", "Geskeduleer", "Besig", "Voltooi", "Gekanselleer"];
  final List<String> _priorities = ["Laag", "Normal", "Hoog", "Dringend"];
  final List<String> _workTypes = ["Onderhoud", "Herstel", "Inspeksie", "Installasie"];
  final List<String> _natures = ["Elektries", "Meganies", "Siviel", "Buite", "Algemeen"];
  final List<String> _scheduleTypes = ["enkel", "weekliks", "maandeliks", "jaarliks"];

  late String _status;
  late String _priority;
  late String _workType;
  late String _nature;
  late String _scheduleType;

  int? _selectedCampusId;
  int? _selectedBuildingId;
  int? _selectedRoomId;
  String? _selectedAssetId;
  int? _faultId;

  DateTime? _scheduledDatetime;
  DateTime? _scheduledEndDatetime;

  int? _assignedToId;
  int? _selectedContractorId;
  final List<int> _ccUserIds = [];

  final List<_QuoteDraft> _quotes = [];
  int? _selectedQuoteTempId;
  int _quoteCounter = 0;
  bool _quotesLoading = false;
  final Set<int> _removedQuoteIds = {};

  final List<int> _existingImageIds = [];
  final Set<int> _removedImageIds = {};
  final List<File> _newJobImages = [];
  final List<int> _faultImageIds = [];
  bool _imagesLoading = true;

  bool _saving = false;
  bool _savingQuoteSelection = false;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    if (!widget.isEditing) {
      _idempotencyKey = Idempotency.generate();
    }

    _status = widget.jobcard?.status ?? "Oop";
    _priority = widget.jobcard?.priority ?? "Normal";
    _workType = widget.jobcard?.type ?? "";
    _nature = widget.jobcard?.nature ?? "";
    _scheduleType = widget.jobcard?.scheduleType ?? "enkel";

    _loadContextData();
    _prefill();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _briefController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadContextData() async {
    if (CampusService.campusesNotifier.value.isEmpty) {
      await CampusService.fetchCampuses();
    }
    if (AssetService.assetsNotifier.value.isEmpty) {
      await AssetService.fetchAssets();
    }
    if (UserService.users.isEmpty) {
      await UserService.fetchAssignableUsers();
    }
    if (ReportService.reportsNotifier.value.isEmpty) {
      await ReportService.fetchReports();
    }
    if (widget.isEditing) {
      await _loadJobImages();
    } else if (widget.report != null) {
      final faultId = int.tryParse(widget.report!.id);
      if (faultId != null) await _loadFaultImages(faultId);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadJobImages() async {
    final jobId = widget.jobcard!.id;
    final ids = await ImageService.getImagesForParent('job', jobId);
    final faultId = widget.jobcard!.faultId;
    final fault = faultId != null
        ? await ImageService.getImagesForParent('ticket', faultId)
        : <int>[];
    if (mounted) {
      setState(() {
        _existingImageIds.addAll(ids);
        _faultImageIds
          ..clear()
          ..addAll(fault);
        _imagesLoading = false;
      });
    }
  }

  Future<void> _loadFaultImages(int faultId) async {
    final fault = await ImageService.getImagesForParent('ticket', faultId);
    if (mounted) {
      setState(() {
        _faultImageIds
          ..clear()
          ..addAll(fault);
      });
    }
  }

  void _prefill() {
    final report = widget.report;
    if (widget.isEditing) {
      final job = widget.jobcard!;
      _briefController.text = job.description;
      final notes = job.fullDescription;
      if (notes.isNotEmpty && notes != job.description) {
        _notesController.text = notes;
      }
      _selectedCampusId = job.locationId;
      _selectedBuildingId = job.buildingId;
      _selectedRoomId = job.roomId;
      _selectedAssetId = job.assetId?.toString();
      _faultId = job.faultId;
      _scheduledDatetime = job.scheduledDatetime;
      _scheduledEndDatetime = job.scheduledEndDatetime;
      _assignedToId = job.assignedTo;
      _selectedContractorId = job.contractorId;
      final cc = (job.ccUsers ?? '')
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
      _ccUserIds.addAll(cc);
      _scheduleType = job.scheduleType ?? "enkel";
      _loadQuotesForJob();
    } else if (report != null) {
      _applyReport(report);
      _assignedToId = UserSession.userId;
    } else {
      _assignedToId = UserSession.userId;
    }
  }

  /// Vorm die velde aan uit 'n foutkaartjie — dieselfde outomatiese uitvul wat
  /// gebruik word wanneer 'n werksopdrag vanuit 'n foutkaartjie geskep word.
  /// Die foutkaartjie-beskrywing word in die werknotas-veld gelaai sodat die
  /// kontrakteur dit onder werknotas sien (nie as 'n aparte volle beskrywing nie).
  void _applyReport(Report report) {
    _briefController.text = report.title;
    if (report.description.isNotEmpty) {
      _notesController.text = report.description;
    }
    _workType = _normalizeWorkTypeValue(report.category);
    _priority = _normalizePriorityValue(report.priority);
    _selectedCampusId = report.locationId;
    _selectedBuildingId = report.buildingId;
    _selectedRoomId = int.tryParse(report.location);
    final assetId = int.tryParse(report.assetId);
    _selectedAssetId = (assetId != null && assetId > 0) ? assetId.toString() : null;
    _faultId = int.tryParse(report.id);
    final creatorId = int.tryParse(report.user);
    if (creatorId != null &&
        creatorId > 0 &&
        creatorId != UserSession.userId &&
        !_ccUserIds.contains(creatorId)) {
      _ccUserIds.add(creatorId);
    }
  }

  Future<void> _loadQuotesForJob() async {
    _quotesLoading = true;
    try {
      for (final qid in widget.jobcard!.quoteIds) {
        final quote = await QuoteService.fetchQuoteById(qid);
        if (quote == null) continue;
        final draft = _QuoteDraft(_newTempId())
          ..quoteId = quote.id
          ..contractorId = quote.contractorId
          ..contractorName = quote.contractorName
          ..selectionReason = quote.selectionReason
          ..selectionSaved =
              (quote.selectionReason ?? '').trim().isNotEmpty;
        draft.existingDocs.addAll(await DocumentService.listQuoteDocuments(qid));
        if (mounted) {
          setState(() {
            _quotes.add(draft);
            if (widget.jobcard!.quoteId == qid) {
              _selectedQuoteTempId = draft.tempId;
            }
          });
        }
      }
    } finally {
      if (mounted) setState(() => _quotesLoading = false);
    }
  }

  int _newTempId() => ++_quoteCounter + DateTime.now().millisecondsSinceEpoch;

  /// Wanneer 'n gekose kwotasie met 'n rede gestoor/gekies is, is die
  /// kontrakteur vasgesluit — nie veranderbaar in Skedulering & Toewysing nie.
  int? get _lockedContractorId {
    final selected = _quotes.where((q) => q.tempId == _selectedQuoteTempId).firstOrNull;
    if (selected != null &&
        selected.selectionSaved &&
        selected.contractorId != null) {
      return selected.contractorId;
    }
    return null;
  }

  // ===== Normering =====

  String _normalizeWorkTypeValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (["maintenance", "onderhoud", "instandhouding"].contains(normalized)) return "Onderhoud";
    if (["repair", "herstel", "herstelwerk"].contains(normalized)) return "Herstel";
    if (["inspection", "inspeksie"].contains(normalized)) return "Inspeksie";
    if (["installation", "installasie"].contains(normalized)) return "Installasie";
    return value.trim();
  }

  String _normalizePriorityValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (["laag", "low"].contains(normalized)) return "Laag";
    if (["normal", "medium", "normaal"].contains(normalized)) return "Normal";
    if (["hoog", "high"].contains(normalized)) return "Hoog";
    if (["dringend", "urgent"].contains(normalized)) return "Dringend";
    return value.trim().isEmpty ? "Normal" : value.trim();
  }

  // ===== Bou =====

  static const _tabLabels = ["Besonderhede", "Kwotasies", "Skedulering", "Werknotas"];
  static const _tabIcons = [
    Icons.info_outline,
    Icons.request_quote_outlined,
    Icons.calendar_month_outlined,
    Icons.note_alt_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isEditing
            ? "Wysig Werksopdrag #${widget.jobcard!.id}"
            : "Nuwe Werksopdrag"),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTabRoster(),
          Expanded(
            child: IndexedStack(
              index: _tabController.index,
              children: [
                _buildBesonderhedeTab(),
                _buildKwotasiesTab(),
                _buildSkeduleringTab(),
                _buildWerknotasTab(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildTabRoster() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTabButton(0)),
              const SizedBox(width: 8),
              Expanded(child: _buildTabButton(1)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTabButton(2)),
              const SizedBox(width: 8),
              Expanded(child: _buildTabButton(3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.index = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _tabIcons[index],
              size: 16,
              color: isSelected ? AppColors.gold : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              _tabLabels[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.gold : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: (_saving || _quotesLoading) ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text("STOOR WERKSOPDRAG",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
      ),
    );
  }

  // ===== Tabel 1: Besonderhede =====

  Widget _buildBesonderhedeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildDropdown("Status", _status, _statuses, _onStatusSelected,
                  required: true, error: !_statuses.contains(_status))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown("Prioriteit", _priority, _priorities, (v) => setState(() => _priority = v!))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  "Werksoort", _workType, _workTypes, (v) => setState(() => _workType = v!),
                  required: true, error: _workType.isEmpty,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown("Aard", _nature, _natures, (v) => setState(() => _nature = v!))),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField("Hoofbeskrywing", _briefController),
          const SizedBox(height: 20),
          LocationCascadePicker(
            label: "Ligging",
            error: _selectedCampusId == null,
            initialCampusId: _selectedCampusId,
            initialBuildingId: _selectedBuildingId,
            initialRoomId: _selectedRoomId,
            onChanged: (campusId, buildingId, roomId) => setState(() {
              _selectedCampusId = campusId;
              _selectedBuildingId = buildingId;
              _selectedRoomId = roomId;
              _selectedAssetId = null;
            }),
          ),
          const SizedBox(height: 14),
          _buildAssetDropdown(),
          const SizedBox(height: 14),
          ValueListenableBuilder<List<Report>>(
            valueListenable: ReportService.reportsNotifier,
            builder: (context, reports, _) {
              return InlineSearchableDropdown<String>(
                label: "Koppel foutkaartjie (opsioneel)",
                hint: "Soek & kies foutkaartjie",
                value: _faultId?.toString(),
                items: reports
                    .map((r) => SearchableDropdownItem(
                        value: r.id, label: "#${r.id} - ${r.title}"))
                    .toList(),
                trailing: _faultId != null
                    ? IconButton(
                        tooltip: "Ontkoppel foutkaartjie",
                        onPressed: () => setState(() => _faultId = null),
                        icon: const Icon(Icons.close, size: 18, color: AppColors.errorRed),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
                onChanged: (v) {
                  if (v == null) return;
                  final report = reports.where((r) => r.id == v).firstOrNull;
                  if (report != null) {
                    setState(() => _applyReport(report));
                  }
                },
              );
            },
          ),
          if (_faultId != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.link, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  "Gekoppel aan Foutkaartjie #$_faultId",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssetDropdown() {
    final assets = AssetService.assetsNotifier.value.where((a) {
      if (_selectedRoomId == null) return false;
      return int.tryParse(a.location) == _selectedRoomId;
    }).toList();

    return InlineSearchableDropdown<String>(
      label: "Bate",
      hint: "Kies Bate (opsioneel)",
      value: _selectedAssetId,
      items: assets
          .map((a) => SearchableDropdownItem(value: a.id, label: a.name))
          .toList(),
      onChanged: (v) => setState(() => _selectedAssetId = v),
    );
  }

  // ===== Tabel 2: Kwotasies =====

  Widget _buildKwotasiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<List<User>>(
            valueListenable: UserService.usersNotifier,
            builder: (context, users, _) {
              final contractors = users.where((u) => u.roleId == 4).toList();
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddQuoteDialog(contractors),
                  icon: const Icon(Icons.add),
                  label: const Text("Voeg Kwotasie By"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle("Kwotasies"),
          const SizedBox(height: 12),
          if (_quotesLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_quotes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(
                child: Text("Geen kwotasies bygevoeg nie", style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._quotes.map(_buildQuoteCard),
        ],
      ),
    );
  }

  Future<void> _showAddQuoteDialog(List<User> contractors) async {
    final result = await showDialog<_QuoteDialogResult>(
      context: context,
      builder: (dialogContext) =>
          _AddQuoteDialog(contractors: contractors),
    );
    if (result == null || !mounted) return;
    setState(() {
      _quotes.add(_QuoteDraft(_newTempId())
        ..contractorId = result.contractorId
        ..contractorName = result.contractorName
        ..pdfFile = result.pdfFile);
    });
  }

  Widget _buildQuoteCard(_QuoteDraft quote) {
    final isSelected = quote.tempId == _selectedQuoteTempId;
    final contractorName = (quote.contractorName ?? '').trim().isNotEmpty
        ? quote.contractorName!.trim()
        : UserService.nameFor(quote.contractorId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.lightGold.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? AppColors.gold : Colors.grey.shade300, width: isSelected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  contractorName.isEmpty ? "Kwotasie #${quote.tempId}" : contractorName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              if (quote.quoteId != null)
                Text("#${quote.quoteId}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('quote_contractor_${quote.tempId}'),
            decoration: const InputDecoration(
              labelText: "Kontrakteur Naam",
              hintText: "Tik die kontrakteur se naam",
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: quote.contractorName ?? "",
            onChanged: (v) => quote.contractorName = v,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, size: 16, color: AppColors.errorRed),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  quote.pdfFile != null
                      ? quote.pdfFile!.path.split('/').last
                      : (quote.existingDocs.isNotEmpty ? quote.existingDocs.first.filename : "Geen PDF"),
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (quote.pdfFile != null)
                TextButton(
                  onPressed: () => setState(() {
                    quote.pdfFile = null;
                    quote.existingDocs.clear();
                  }),
                  child: const Text("Verwyder", style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
                ),
              if (quote.existingDocs.isNotEmpty)
                TextButton(
                  onPressed: () => _viewPdf(quote.existingDocs.first.documentId),
                  child: const Text("Bekyk", style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const Divider(height: 20),
          RadioGroup<int>(
            groupValue: _selectedQuoteTempId,
            onChanged: (v) => setState(() => _selectedQuoteTempId = v),
            child: Row(
              children: [
                Expanded(
                  child: Radio<int>(value: quote.tempId),
                ),
                const Expanded(
                  flex: 4,
                  child: Text("Kies as gekose kwotasie", style: TextStyle(fontSize: 13)),
                ),
                IconButton(
                  tooltip: "Verwyder kwotasie",
                  onPressed: () => setState(() {
                    if (quote.quoteId != null) _removedQuoteIds.add(quote.quoteId!);
                    _quotes.remove(quote);
                    if (_selectedQuoteTempId == quote.tempId) _selectedQuoteTempId = null;
                  }),
                  icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                ),
              ],
            ),
          ),
          if (_selectedQuoteTempId == quote.tempId) ...[
            const Divider(height: 20),
            TextFormField(
              key: ValueKey('quote_reason_${quote.tempId}'),
              decoration: const InputDecoration(
                labelText: "Rede waarom hierdie kwotasie gekies is",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              initialValue: quote.selectionReason ?? "",
              onChanged: (v) => quote.selectionReason = v,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _savingQuoteSelection ? null : () => _saveQuoteSelection(quote),
                icon: _savingQuoteSelection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_alt, size: 18, color: Colors.white),
                label: const Text("STOOR KEUSE",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      quote.selectionSaved ? AppColors.successGreen : AppColors.navy,
                ),
              ),
            ),
            if (quote.selectionSaved) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.successGreen, size: 14),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Hierdie kwotasie is as gekose kwotasie gestoor.",
                      style: TextStyle(color: AppColors.successGreen, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _viewPdf(int documentId) async {
    try {
      final bytes = await DocumentService.downloadQuotePdf(documentId);
      if (bytes == null) {
        if (!mounted) return;
        showAppSnackBar(context, "Kon nie PDF laai nie.", error: true);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kwotasie_$documentId.pdf');
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (result.type != ResultType.done && result.type != ResultType.noAppToOpen) {
        showAppSnackBar(context, "Kon nie PDF oopmaak nie.", error: true);
      }
    } catch (e) {
      debugPrint("PDF viewing error: $e");
      if (!mounted) return;
      showAppSnackBar(context, "Kon nie PDF oopmaak nie.", error: true);
    }
  }

  /// Stoor die kwotasie-keuse dadelik aan die backend: skep die kwotasie
  /// (indien nog 'n konsep), laai die PDF op, stoor die seleksierede en koppel
  /// die gekose kwotasie aan die werksopdrag (as dit al bestaan).
  Future<void> _saveQuoteSelection(_QuoteDraft quote) async {
    if (!quote.hasContractor || !quote.hasPdf) {
      showAppSnackBar(context, "Gee 'n kontrakteur en laai 'n PDF-dokument op.", error: true);
      return;
    }
    final reason = (quote.selectionReason ?? '').trim();
    if (reason.isEmpty) {
      showAppSnackBar(context, "Gee asseblief 'n rede waarom hierdie kwotasie gekies is.", error: true);
      return;
    }
    setState(() => _savingQuoteSelection = true);
    try {
      if (quote.quoteId == null) {
        quote.idempotencyKey ??= Idempotency.generate();
        final created = await QuoteService.addQuote(Quote(
          contractorId: quote.contractorId,
          contractorName: quote.contractorName,
          date: DateTime.now(),
          status: 'Pending',
          selectionReason: reason,
        ), idempotencyKey: quote.idempotencyKey);
        if (created == null) {
          _failQuoteSelection("Kon nie kwotasie stoor nie.");
          return;
        }
        quote.quoteId = created.id;
      } else {
        final updated = await QuoteService.updateQuote(
          quote.quoteId!,
          Quote(
            id: quote.quoteId!,
            contractorId: quote.contractorId,
            contractorName: quote.contractorName,
            date: DateTime.now(),
            status: 'Pending',
            selectionReason: reason,
          ),
        );
        if (updated == null) {
          _failQuoteSelection("Kon nie kwotasie stoor nie.");
          return;
        }
      }

      if (quote.pdfFile != null) {
        final doc = await DocumentService.uploadQuotePdf(quote.quoteId!, quote.pdfFile!);
        if (doc != null) quote.existingDocs.add(doc);
        // Die PDF is nou op die backend gestoor — verwyder die plaaslike lêer
        // sodat 'n herstoor (of die finale stoor van die werksopdrag) nie 'n
        // duplikaat-dokument oplaai nie.
        quote.pdfFile = null;
      }

      if (widget.isEditing && quote.quoteId != null) {
        final ok = await JobcardService.updateJob(widget.jobcard!.id, {
          'quote_id': quote.quoteId,
        });
        if (ok == null) {
          _failQuoteSelection("Kon nie die kwotasie-keuse aan die werksopdrag koppel nie.");
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        quote.selectionSaved = true;
        _savingQuoteSelection = false;
      });
      showAppSnackBar(context, "Kwotasie-keuse gestoor");
    } catch (e) {
      debugPrint("Fout by stoor van kwotasie-keuse: $e");
      _failQuoteSelection("Fout tydens besparing van die kwotasie-keuse.");
    }
  }

  void _failQuoteSelection(String message) {
    if (!mounted) return;
    setState(() => _savingQuoteSelection = false);
    showAppSnackBar(context, message, error: true);
  }

  // ===== Tabel 3: Skedulering & Toewysing =====

  Widget _buildSkeduleringTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Skedulering"),
          const SizedBox(height: 12),
          _buildDateTimePicker("Begin Datum & Tyd", _scheduledDatetime, (v) {
            setState(() => _scheduledDatetime = v);
          }),
          const SizedBox(height: 14),
          _buildDateTimePicker("Einddatum & Tyd", _scheduledEndDatetime, (v) {
            setState(() => _scheduledEndDatetime = v);
          }),
          const SizedBox(height: 14),
          _buildDropdown("Herhaling", _scheduleType, _scheduleTypes, (v) {
            if (v == null) return;
            setState(() => _scheduleType = v);
          }),
          const SizedBox(height: 24),
          _sectionTitle("Toewysing"),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<User>>(
            valueListenable: UserService.usersNotifier,
            builder: (context, users, _) {
              final staff = users
                  .where((u) =>
                      u.roleId == 2 || u.roleId == 3 || u.id == _assignedToId)
                  .toList();
              final contractors = users.where((u) => u.roleId == 4).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InlineSearchableDropdown<int?>(
                    label: "Personeel lid",
                    hint: "Kies personeel lid",
                    value: _assignedToId,
                    required: true,
                    error: _assignedToId == null,
                    items: staff
                        .map((u) => SearchableDropdownItem<int?>(value: u.id, label: u.displayName))
                        .toList(),
                    onChanged: (v) => setState(() => _assignedToId = v),
                  ),
                  const SizedBox(height: 14),
                  InlineSearchableDropdown<int?>(
                    label: "Kontrakteur (opsioneel)",
                    hint: "Kies kontrakteur",
                    enabled: _lockedContractorId == null,
                    value: _lockedContractorId ?? _selectedContractorId,
                    items: contractors
                        .map((u) => SearchableDropdownItem<int?>(value: u.id, label: u.displayName))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedContractorId = v),
                  ),
                  const SizedBox(height: 20),
                  const Text("CC Gebruikers",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final id in _ccUserIds)
                        InputChip(
                          label: Text(UserService.nameFor(id)),
                          onDeleted: () => setState(() => _ccUserIds.remove(id)),
                          backgroundColor: Colors.white,
                          deleteIconColor: AppColors.errorRed,
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text("Voeg CC by"),
                        onPressed: () => _pickCcUsers(users),
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _pickCcUsers(List<User> users) async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (context) => _CcUserDialog(users: users, preselected: _ccUserIds.toSet()),
    );
    if (selected != null) {
      setState(() {
        _ccUserIds
          ..clear()
          ..addAll(selected);
      });
    }
  }

  Widget _buildDateTimePicker(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDateTime(value, onChanged),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.event, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value == null ? "Kies datum & tyd" : formatDateTime(value),
                    style: TextStyle(color: value == null ? Colors.grey[600] : Colors.black, fontSize: 14),
                  ),
                ),
                if (value != null)
                  IconButton(
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.close, size: 18, color: AppColors.errorRed),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateTime(DateTime? current, ValueChanged<DateTime?> onChanged) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (time == null) return;

    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  // ===== Tabel 4: Kontrakteur Werknotas =====

  Widget _buildWerknotasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFaultPhotos(),
          const SizedBox(height: 24),
          _sectionTitle("Werknotas"),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 6,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: "Gedetailleerde beskrywing van werk wat gedoen moet word...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle("Beelde"),
          const SizedBox(height: 12),
          _buildImageSection(),
        ],
      ),
    );
  }

  /// Foutkaartjie se fotos (parent_type 'ticket') — leesbaar vir enigeen wat
  /// die werksopdrag kan sien, dieselfde as die kontrakteur-detail-aansig.
  Widget _buildFaultPhotos() {
    if (_faultImageIds.isEmpty) return const SizedBox.shrink();
    final baseUrl = ApiClient().client.options.baseUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Foto van Fout"),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in _faultImageIds)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  '$baseUrl/image/$id/file',
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    height: 80,
                    width: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final baseUrl = ApiClient().client.options.baseUrl;
    final visibleExisting = _existingImageIds.where((id) => !_removedImageIds.contains(id)).toList();
    final total = visibleExisting.length + _newJobImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_imagesLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in visibleExisting)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '$baseUrl/image/$id/file',
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          height: 80,
                          width: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        onTap: () => setState(() => _removedImageIds.add(id)),
                        child: Container(
                          decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              for (int i = 0; i < _newJobImages.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_newJobImages[i], height: 80, width: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        onTap: () => setState(() => _newJobImages.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              if (total < 5)
                InkWell(
                  onTap: () => _addJobImage(),
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.grey, size: 30),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _addJobImage() async {
    final photo = await CameraService.takePhoto();
    if (photo != null) {
      setState(() => _newJobImages.add(photo));
    }
  }

  // ===== Stoor =====

  Future<void> _save() async {
    if (_selectedCampusId == null) {
      showAppSnackBar(context, "Kies asseblief 'n terrein (location_id is verpligtend).", error: true);
      setState(() => _tabController.index = 0);
      return;
    }
    if (_workType.isEmpty) {
      showAppSnackBar(context, "Kies asseblief 'n werksoort.", error: true);
      setState(() => _tabController.index = 0);
      return;
    }
    if (_assignedToId == null) {
      showAppSnackBar(context, "Kies asseblief 'n personeel lid (verantwoordelik vir die werksopdrag).", error: true);
      setState(() => _tabController.index = 2);
      return;
    }
    for (final q in _quotes) {
      if (!q.hasPdf) {
        showAppSnackBar(context, "Elke kwotasie moet 'n PDF-dokument hê.", error: true);
        setState(() => _tabController.index = 1);
        return;
      }
    }
    if (_selectedQuoteTempId != null) {
      final selected = _quotes.where((q) => q.tempId == _selectedQuoteTempId).firstOrNull;
      if (selected != null && !selected.hasContractor) {
        showAppSnackBar(context, "Gee asseblief 'n kontrakteur (naam) vir die gekose kwotasie.", error: true);
        setState(() => _tabController.index = 1);
        return;
      }
      if (selected != null && (selected.selectionReason == null || selected.selectionReason!.trim().isEmpty)) {
        showAppSnackBar(context, "Gee asseblief 'n rede waarom die gekose kwotasie gekies is.", error: true);
        setState(() => _tabController.index = 1);
        return;
      }
    }

    setState(() => _saving = true);

    final brief = _briefController.text.trim();
    final notes = _notesController.text.trim();
    final String desc;
    if (brief.isNotEmpty && notes.isNotEmpty) {
      desc = '$brief: $notes';
    } else if (brief.isNotEmpty) {
      desc = brief;
    } else if (notes.isNotEmpty) {
      desc = notes;
    } else {
      desc = _workType.isEmpty ? 'Werksopdrag' : _workType;
    }
    final payload = <String, dynamic>{
      'job_desc': desc,
      'job_type': _workType,
      'job_status': Jobcard.toBackendStatus(_status),
      'job_priority': _priority,
      'nature': _nature,
      'job_notes': notes,
      'job_createddatetime': widget.jobcard?.createdDatetime?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'job_scheduled_datetime': _scheduledDatetime?.toIso8601String(),
      'job_scheduled_end_datetime': _scheduledEndDatetime?.toIso8601String(),
      'job_schedule_type': _scheduleType,
      'asset_id': int.tryParse(_selectedAssetId ?? ''),
      'room_id': _selectedRoomId,
      'building_id': _selectedBuildingId,
      'location_id': _selectedCampusId,
      'fault_id': _faultId,
      'assigned_to': _assignedToId,
      'contractor_id': _lockedContractorId ?? _selectedContractorId,
      'cc_users': _ccUserIds.isEmpty ? null : _ccUserIds.join(','),
    };

    try {
      // 1. Stoor/dateer die werksopdrag self.
      final saved = widget.isEditing
          ? await JobcardService.updateJob(widget.jobcard!.id, payload)
          : await JobcardService.createJob(payload,
              idempotencyKey: _idempotencyKey);
      if (saved == null) {
        _failSave("Kon nie werksopdrag stoor nie.");
        return;
      }
      if (!widget.isEditing) {
        _idempotencyKey = Idempotency.generate();
      }
      final jobId = saved.id;

      // 2. Stoor kwotasies en laai PDF's op.
      int? selectedQuoteId;
      final selectedDraft = _selectedQuoteTempId != null
          ? _quotes.where((q) => q.tempId == _selectedQuoteTempId).firstOrNull
          : null;
      if (selectedDraft?.quoteId != null) selectedQuoteId = selectedDraft!.quoteId;
      for (final q in List<_QuoteDraft>.from(_quotes)) {
        try {
          final quoteToSave = Quote(
            id: q.quoteId ?? 0,
            contractorId: q.contractorId,
            contractorName: q.contractorName,
            date: DateTime.now(),
            status: 'Pending',
            selectionReason:
                (q.tempId == _selectedQuoteTempId) ? (q.selectionReason ?? '') : q.selectionReason,
          );
          final quote = q.quoteId != null
              ? await QuoteService.updateQuote(q.quoteId!, quoteToSave)
              : await QuoteService.addQuote(quoteToSave,
                  idempotencyKey: (q.idempotencyKey ??=
                      Idempotency.generate()));
          if (quote == null) continue;
          q.quoteId = quote.id;
          if (q.tempId == _selectedQuoteTempId) selectedQuoteId = quote.id;

          if (q.pdfFile != null) {
            await DocumentService.uploadQuotePdf(quote.id, q.pdfFile!);
          }
        } catch (e) {
          debugPrint("Fout by stoor van kwotasie: $e");
        }
      }

      // 3. Koppel kwotasies aan die werksopdrag. Bou die lys uit die
      //    bestaande quote_ids en pas slegs die gebruiker se werklike
      //    veranderinge toe (verwyderings + nuutskeppings), sodat 'n
      //    kwotasie wat nie gelaai kon word nie nie stilweg ontkoppel
      //    word nie. Slaan die PATCH oor as niks aan kwotasies verander
      //    is nie.
      if (jobId > 0) {
        final existingQuoteIds = widget.jobcard?.quoteIds ?? const <int>[];
        final keptExisting = existingQuoteIds
            .where((id) => !_removedQuoteIds.contains(id))
            .toSet();
        final draftQuoteIds =
            _quotes.map((q) => q.quoteId).whereType<int>().toSet();
        final newQuoteIds = <int>[
          ...keptExisting,
          ...draftQuoteIds.where((id) => !keptExisting.contains(id)),
        ];
        final oldQuoteIdSet = existingQuoteIds.toSet();
        final newQuoteIdSet = newQuoteIds.toSet();
        final quoteIdsChanged =
            oldQuoteIdSet.difference(newQuoteIdSet).isNotEmpty ||
                newQuoteIdSet.difference(oldQuoteIdSet).isNotEmpty;
        final quoteIdChanged = selectedQuoteId != widget.jobcard?.quoteId;

        if (quoteIdsChanged || quoteIdChanged) {
          await JobcardService.updateJob(jobId, {
            'quote_id': selectedQuoteId,
            'quote_ids': newQuoteIds.isEmpty ? null : newQuoteIds.join(','),
          });
        }
      }

      // 4. Beelde: verwyder gemerkte, laai nuwes op.
      for (final id in _removedImageIds) {
        await ImageService.deleteImage(id);
      }
      for (final image in _newJobImages) {
        await ImageService.uploadImage(image, parentId: jobId, parentType: 'job');
      }

      // 5. Die backend skakel die foutkaartjie self na 'Besig' wanneer die
      //    werksopdrag geskep word; verfris hier net die verslaglys.
      await ReportService.fetchReports();

      await JobcardService.fetchJobs();

      // 6. Sinkroniseer die geskeduleerde werksopdrag na Outlook (dieselfde
      //    FBS-WO-merker as die web). Word nie-onderskeidend hanteer — 'n
      //    fout hier moet nooit die stoor van die werksopdrag blokkeer nie.
      await _syncScheduledOutlookEvent(
        jobId,
        scheduledDatetime: _scheduledDatetime,
        scheduleType: _scheduleType,
        description: desc,
      );

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Werksopdrag suksesvol gestoor"),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Fout by besparing: $e");
      _failSave("Fout tydens besparing. Probeer asseblief weer.");
    }
  }

  void _failSave(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    showAppSnackBar(context, message, error: true);
  }

  /// Skep (of vervang) die Outlook-afspraak vir 'n geskeduleerde werksopdrag,
  /// met dieselfde `FBS-WO-<id>`-merker as die web se WorkOrderPage. As die
  /// werksopdrag nie meer geskeduleer is nie, word bestaande merker-afsprake
  /// verwyder.
  Future<void> _syncScheduledOutlookEvent(
    int jobId, {
    required DateTime? scheduledDatetime,
    required String scheduleType,
    required String description,
  }) async {
    try {
      await OutlookService.instance.deleteWorkOrderEvents(jobId);
      if (scheduledDatetime == null) return;
      await OutlookService.instance.createWorkOrderEvent(
        jobId: jobId,
        description: description,
        scheduledDatetime: scheduledDatetime,
        scheduleType: scheduleType,
      );
    } catch (e) {
      debugPrint("Outlook-sinkronisering vir werksopdrag misluk: $e");
    }
  }

  // ===== Hulp-widgets =====

  Widget _sectionTitle(String title) {
    return Text(title.toUpperCase(),
        style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2));
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// Status-keuse: "Voltooi" vereis 'n bevestiging — kanselleer keer terug
  /// sonder om die status te verander.
  Future<void> _onStatusSelected(String? v) async {
    if (v == null || v == _status) return;
    if (v == "Voltooi") {
      // Wag tot die soekdialoog eers afgespring het: die soekdialoog se
      // Navigator.pop verwyder die boonste roete — as die bevestigingsdialoog
      // reeds gestoot is, word dit onmiddellik weer weggepop en raak niks gekies nie.
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Werksopdrag Voltooi?"),
          content: const Text(
              "Is jy seker jy wil hierdie werksopdrag as voltooi merk?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("NEE"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("JA", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _status = v);
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged,
      {bool required = false, bool error = false}) {
    return InlineSearchableDropdown<String>(
      label: label,
      hint: "Kies $label",
      value: value,
      items: items.map((e) => SearchableDropdownItem(value: e, label: e)).toList(),
      onChanged: onChanged,
      required: required,
      error: error,
    );
  }

  }

class _CcUserDialog extends StatefulWidget {
  final List<User> users;
  final Set<int> preselected;

  const _CcUserDialog({required this.users, required this.preselected});

  @override
  State<_CcUserDialog> createState() => _CcUserDialogState();
}

class _CcUserDialogState extends State<_CcUserDialog> {
  late final Set<int> _selected;
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  /// Slegs FK (2) en Admin (3) mag CC gekies word. Reeds-gekose gebruikers
  /// (bv. die foutkaartjie-skepper, selfs 'n student) bly sigbaar én
  /// vasgesluit — hulle kan nie uit die CC-lys verwyder word nie.
  bool _isSelectable(User u) => u.roleId == 2 || u.roleId == 3;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.preselected};
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eligibleIds = widget.users.where(_isSelectable).map((u) => u.id).toSet();
    final visibleUsers = widget.users
        .where((u) =>
            eligibleIds.contains(u.id) || _selected.contains(u.id))
        .where((u) {
      if (_query.isEmpty) return true;
      return u.displayName.toLowerCase().contains(_query) ||
          u.email.toLowerCase().contains(_query);
    }).toList()
      ..sort((a, b) {
        final aSel = _selected.contains(a.id);
        final bSel = _selected.contains(b.id);
        if (aSel != bSel) return aSel ? -1 : 1;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

    return AlertDialog(
      title: const Text("Kies CC Gebruikers"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Soek gebruikers...",
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: visibleUsers.map((u) {
                  final selectable = eligibleIds.contains(u.id);
                  final checked = _selected.contains(u.id);
                  return CheckboxListTile(
                    dense: true,
                    title: Text(u.displayName),
                    subtitle: Text(u.email, style: const TextStyle(fontSize: 11)),
                    value: checked,
                    onChanged: selectable
                        ? (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(u.id!);
                              } else {
                                _selected.remove(u.id);
                              }
                            })
                        : null,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("KANSELLEER"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text("KIES", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}


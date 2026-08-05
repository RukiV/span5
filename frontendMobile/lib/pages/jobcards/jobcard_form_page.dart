import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../models/building.dart';
import '../../models/campus.dart';
import '../../models/jobcard.dart';
import '../../models/quote.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../models/user.dart';
import '../../models/user_session.dart';
import '../../services/asset_service.dart';
import '../../services/camera_service.dart';
import '../../services/campus_service.dart';
import '../../services/document_service.dart';
import '../../services/image_service.dart';
import '../../services/jobcard_service.dart';
import '../../services/quote_service.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../widgets/searchable_dropdown.dart';

/// 'n Tydelike kwotasie-draft in die vorm — word eers aan die backend gestoor
/// wanneer die hele werksopdrag gestoor word.
class _QuoteDraft {
  int? quoteId;
  final int tempId;
  int? contractorId;
  File? pdfFile;
  final List<QuoteDocument> existingDocs = [];
  String? selectionReason;

  _QuoteDraft(this.tempId);

  bool get hasPdf => pdfFile != null || existingDocs.isNotEmpty;
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

  final List<String> _statuses = ["Wag", "Oop", "Besig", "Voltooi", "Gekanselleer"];
  final List<String> _priorities = ["Laag", "Normal", "Hoog", "Dringend"];
  final List<String> _workTypes = ["Onderhoud", "Herstel", "Inspeksie", "Installasie"];
  final List<String> _natures = ["Instandhouding", "Herstelwerk", "Opgradering", "Ander"];
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

  final List<int> _existingImageIds = [];
  final Set<int> _removedImageIds = {};
  final List<File> _newJobImages = [];
  bool _imagesLoading = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

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
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadJobImages() async {
    final jobId = widget.jobcard!.id;
    final ids = await ImageService.getImagesForParent('job', jobId);
    if (mounted) {
      setState(() {
        _existingImageIds.addAll(ids);
        _imagesLoading = false;
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
      _scheduledDatetime = DateTime.now();
      _assignedToId = UserSession.userId;
    } else {
      _scheduledDatetime = DateTime.now();
      _assignedToId = UserSession.userId;
    }
  }

  /// Vorm die velde aan uit 'n foutkaartjie — dieselfde outomatiese uitvul wat
  /// gebruik word wanneer 'n werksopdrag vanuit 'n foutkaartjie geskep word.
  /// Notas word nie oorgedra nie (soos voorheen versoek).
  void _applyReport(Report report) {
    _briefController.text = report.title;
    _nature = report.category;
    _workType = _normalizeWorkTypeValue(report.category);
    _priority = _normalizePriorityValue(report.priority);
    _selectedCampusId = report.locationId;
    _selectedBuildingId = report.buildingId;
    _selectedRoomId = int.tryParse(report.location);
    final assetId = int.tryParse(report.assetId);
    _selectedAssetId = (assetId != null && assetId > 0) ? assetId.toString() : null;
    _faultId = int.tryParse(report.id);
  }

  Future<void> _loadQuotesForJob() async {
    for (final qid in widget.jobcard!.quoteIds) {
      final quote = await QuoteService.fetchQuoteById(qid);
      if (quote == null) continue;
      final draft = _QuoteDraft(_newTempId())
        ..quoteId = quote.id
        ..contractorId = quote.contractorId
        ..selectionReason = quote.selectionReason;
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
  }

  int _newTempId() => ++_quoteCounter + DateTime.now().millisecondsSinceEpoch;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing
            ? "Wysig Werksopdrag #${widget.jobcard!.id}"
            : "Nuwe Werksopdrag"),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.gold,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(text: "Besonderhede"),
            Tab(text: "Kwotasies"),
            Tab(text: "Skedulering & Toewysing"),
            Tab(text: "Kontrakteur Werknotas"),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
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
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.terracotta,
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
          _sectionTitle("Status"),
          Row(
            children: [
              Expanded(child: _buildDropdown("Status", _status, _statuses, (v) => setState(() => _status = v!))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown("Prioriteit", _priority, _priorities, (v) => setState(() => _priority = v!))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildDropdown("Werksoort", _workType, _workTypes, (v) => setState(() => _workType = v!))),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown("Aard", _nature, _natures, (v) => setState(() => _nature = v!))),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField("Hoofbeskrywing (Kort Beskrywing)", _briefController),
          const SizedBox(height: 20),
          _sectionTitle("Ligging & Koppeling"),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<Campus>>(
            valueListenable: CampusService.campusesNotifier,
            builder: (context, campuses, _) {
              return Column(
                children: [
                  SearchableDropdown<int>(
                    label: "Terrein",
                    hint: "Kies Terrein",
                    value: _selectedCampusId,
                    items: campuses
                        .map((c) => SearchableDropdownItem(value: c.id, label: c.name))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedCampusId = v;
                      _selectedBuildingId = null;
                      _selectedRoomId = null;
                      _selectedAssetId = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  SearchableDropdown<int>(
                    label: "Gebou",
                    hint: "Kies Gebou",
                    value: _selectedBuildingId,
                    items: _filteredBuildings(campuses)
                        .map((b) => SearchableDropdownItem(value: b.id, label: b.name))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedBuildingId = v;
                      _selectedRoomId = null;
                      _selectedAssetId = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  SearchableDropdown<int>(
                    label: "Lokaal",
                    hint: "Kies Lokaal",
                    value: _selectedRoomId,
                    items: _filteredRooms(campuses)
                        .map((r) => SearchableDropdownItem(value: r.id, label: r.name))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedRoomId = v;
                      _selectedAssetId = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  _buildAssetDropdown(),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<List<Report>>(
            valueListenable: ReportService.reportsNotifier,
            builder: (context, reports, _) {
              return SearchableDropdown<String>(
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

  List<Building> _filteredBuildings(List<Campus> campuses) {
    if (_selectedCampusId == null) return [];
    final campus = campuses.where((c) => c.id == _selectedCampusId).firstOrNull;
    return campus?.buildings ?? [];
  }

  List<Room> _filteredRooms(List<Campus> campuses) {
    if (_selectedBuildingId == null) return [];
    for (final campus in campuses) {
      for (final building in campus.buildings) {
        if (building.id == _selectedBuildingId) {
          return building.rooms ?? [];
        }
      }
    }
    return [];
  }

  Widget _buildAssetDropdown() {
    final assets = AssetService.assetsNotifier.value.where((a) {
      if (_selectedRoomId == null) return false;
      return int.tryParse(a.location) == _selectedRoomId;
    }).toList();

    return SearchableDropdown<String>(
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
          _sectionTitle("Voeg Nuwe Kwotasie By"),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<User>>(
            valueListenable: UserService.usersNotifier,
            builder: (context, users, _) {
              final contractors = users.where((u) => u.roleId == 4).toList();
              return _buildAddQuoteForm(contractors);
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle("Kwotasies"),
          const SizedBox(height: 12),
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

  Widget _buildAddQuoteForm(List<User> contractors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchableDropdown<int?>(
            label: "Kontrakteur",
            hint: "Kies Kontrakteur",
            value: _quoteContractorId,
            items: contractors
                .map((u) => SearchableDropdownItem<int?>(value: u.id, label: u.displayName))
                .toList(),
            onChanged: (v) => setState(() => _quoteContractorId = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickQuotePdf,
                  icon: const Icon(Icons.picture_as_pdf, color: AppColors.errorRed),
                  label: Text(
                    _quotePdfFile != null ? _quotePdfFile!.path.split('/').last : "Laai PDF op (verpligtend)",
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_quotePdfFile != null)
                IconButton(
                  onPressed: () => setState(() => _quotePdfFile = null),
                  icon: const Icon(Icons.close, color: AppColors.errorRed),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addQuote,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              child: const Text("Voeg Kwotasie By",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  int? _quoteContractorId;
  File? _quotePdfFile;

  Future<void> _pickQuotePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _quotePdfFile = File(path));
  }

  void _addQuote() {
    if (_quoteContractorId == null) {
      _showSnack("Kies 'n kontrakteur vir die kwotasie.", error: true);
      return;
    }
    if (_quotePdfFile == null) {
      _showSnack("Laai 'n PDF op vir die kwotasie (verpligtend).", error: true);
      return;
    }
    setState(() {
      _quotes.add(_QuoteDraft(_newTempId())
        ..contractorId = _quoteContractorId
        ..pdfFile = _quotePdfFile);
      _quoteContractorId = null;
      _quotePdfFile = null;
    });
  }

  Widget _buildQuoteCard(_QuoteDraft quote) {
    final isSelected = quote.tempId == _selectedQuoteTempId;
    final contractorName = UserService.nameFor(quote.contractorId);

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
          ],
        ],
      ),
    );
  }

  Future<void> _viewPdf(int documentId) async {
    try {
      final bytes = await DocumentService.downloadQuotePdf(documentId);
      if (bytes == null) {
        _showSnack("Kon nie PDF laai nie.", error: true);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kwotasie_$documentId.pdf');
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (result.type != ResultType.done && result.type != ResultType.noAppToOpen) {
        _showSnack("Kon nie PDF oopmaak nie.", error: true);
      }
    } catch (e) {
      debugPrint("PDF viewing error: $e");
      if (!mounted) return;
      _showSnack("Kon nie PDF oopmaak nie.", error: true);
    }
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
          _buildDateTimePicker("Beplande Datum & Tyd", _scheduledDatetime, (v) {
            setState(() => _scheduledDatetime = v);
          }),
          const SizedBox(height: 14),
          _buildDateTimePicker("Eind Datum & Tyd (opsioneel)", _scheduledEndDatetime, (v) {
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
              final staff = users.where((u) => u.roleId != 4).toList();
              final contractors = users.where((u) => u.roleId == 4).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchableDropdown<int?>(
                    label: "Personeel lid (Assigneer aan)",
                    hint: "Kies personeel lid",
                    value: _assignedToId,
                    items: staff
                        .map((u) => SearchableDropdownItem<int?>(value: u.id, label: u.displayName))
                        .toList(),
                    onChanged: (v) => setState(() => _assignedToId = v),
                  ),
                  const SizedBox(height: 14),
                  SearchableDropdown<int?>(
                    label: "Kontrakteur",
                    hint: "Kies kontrakteur",
                    value: _selectedContractorId,
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
                    value == null ? "Kies datum & tyd" : _formatDateTime(value),
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
      firstDate: DateTime(now.year - 1),
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
          _sectionTitle("Werknotas"),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 6,
            decoration: InputDecoration(
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
      _showSnack("Kies asseblief 'n terrein (location_id is verpligtend).", error: true);
      _tabController.animateTo(0);
      return;
    }
    if (_workType.isEmpty) {
      _showSnack("Kies asseblief 'n werksoort.", error: true);
      _tabController.animateTo(0);
      return;
    }
    if (_assignedToId == null) {
      _showSnack("Kies asseblief 'n personeel lid (verantwoordelik vir die werksopdrag).", error: true);
      _tabController.animateTo(2);
      return;
    }
    if (_selectedContractorId == null) {
      _showSnack("Kies asseblief 'n kontrakteur vir die werksopdrag.", error: true);
      _tabController.animateTo(2);
      return;
    }
    for (final q in _quotes) {
      if (q.contractorId == null || !q.hasPdf) {
        _showSnack("Elke kwotasie moet 'n kontrakteur en 'n PDF-dokument hê.", error: true);
        _tabController.animateTo(1);
        return;
      }
    }
    if (_selectedQuoteTempId != null) {
      final selected = _quotes.where((q) => q.tempId == _selectedQuoteTempId).firstOrNull;
      if (selected != null && (selected.selectionReason == null || selected.selectionReason!.trim().isEmpty)) {
        _showSnack("Gee asseblief 'n rede waarom die gekose kwotasie gekies is.", error: true);
        _tabController.animateTo(1);
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
      'contractor_id': _selectedContractorId,
      'cc_users': _ccUserIds.isEmpty ? null : _ccUserIds.join(','),
    };

    try {
      // 1. Stoor/dateer die werksopdrag self.
      final saved = widget.isEditing
          ? await JobcardService.updateJob(widget.jobcard!.id, payload)
          : await JobcardService.createJob(payload);
      if (saved == null) {
        _failSave("Kon nie werksopdrag stoor nie.");
        return;
      }
      final jobId = saved.id;

      // 2. Stoor kwotasies en laai PDF's op.
      final createdQuoteIds = <int>[];
      int? selectedCreatedQuoteId;
      for (final q in _quotes) {
        try {
          final quoteToSave = Quote(
            id: q.quoteId ?? 0,
            contractorId: q.contractorId,
            date: DateTime.now(),
            status: 'Pending',
            selectionReason:
                (q.tempId == _selectedQuoteTempId) ? (q.selectionReason ?? '') : q.selectionReason,
          );
          final quote = q.quoteId != null
              ? await QuoteService.updateQuote(q.quoteId!, quoteToSave)
              : await QuoteService.addQuote(quoteToSave);
          if (quote == null) continue;
          createdQuoteIds.add(quote.id);
          if (q.tempId == _selectedQuoteTempId) selectedCreatedQuoteId = quote.id;

          if (q.pdfFile != null) {
            await DocumentService.uploadQuotePdf(quote.id, q.pdfFile!);
          }
        } catch (e) {
          debugPrint("Fout by stoor van kwotasie: $e");
        }
      }

      // 3. Koppel kwotasies aan die werksopdrag.
      if (jobId > 0) {
        await JobcardService.updateJob(jobId, {
          'quote_id': selectedCreatedQuoteId,
          'quote_ids': createdQuoteIds.isEmpty ? null : createdQuoteIds.join(','),
        });
      }

      // 4. Beelde: verwyder gemerkte, laai nuwes op.
      for (final id in _removedImageIds) {
        await ImageService.deleteImage(id);
      }
      for (final image in _newJobImages) {
        await ImageService.uploadImage(image, parentId: jobId, parentType: 'job');
      }

      // 5. Skakel die foutkaartjie na 'Besig' wanneer 'n werksopdrag geskep word.
      final report = widget.report;
      if (!widget.isEditing && report != null) {
        await ReportService.updateReportStatus(report.id, "Besig");
      }

      await JobcardService.fetchJobs();

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
    _showSnack(message, error: true);
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.errorRed : AppColors.successGreen,
      ),
    );
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return SearchableDropdown<String>(
      label: label,
      hint: "Kies $label",
      value: value,
      items: items.map((e) => SearchableDropdownItem(value: e, label: e)).toList(),
      onChanged: onChanged,
    );
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
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

  @override
  void initState() {
    super.initState();
    _selected = {...widget.preselected};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Kies CC Gebruikers"),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.users.map((u) {
            return CheckboxListTile(
              dense: true,
              title: Text(u.displayName),
              subtitle: Text(u.email, style: const TextStyle(fontSize: 11)),
              value: u.id != null && _selected.contains(u.id!),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selected.add(u.id!);
                } else {
                  _selected.remove(u.id);
                }
              }),
            );
          }).toList(),
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

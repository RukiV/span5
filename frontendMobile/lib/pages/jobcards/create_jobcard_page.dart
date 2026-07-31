import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/asset.dart';
import '../../models/building.dart';
import '../../models/campus.dart';
import '../../models/jobcard.dart';
import '../../models/report.dart';
import '../../models/room.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../services/jobcard_service.dart';
import '../../services/report_service.dart';

/// Skerm om 'n nuwe werksopdrag (jobcard) te skep.
/// Slegs Admin/FK (jobs.manage) bereik hierdie skerm — die enigste rol
/// wat werksopdragte mag skep. Die skep self gebruik 'n pending
/// X-Idempotency-Key sodat spam-taps nooit duplikaat-werksopdragte maak nie.
class CreateJobcardPage extends StatefulWidget {
  const CreateJobcardPage({super.key});

  @override
  State<CreateJobcardPage> createState() => _CreateJobcardPageState();
}

class _CreateJobcardPageState extends State<CreateJobcardPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _briefController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _type;
  String _priority = 'Normal';
  String _status = 'Oop';

  int? _campusId;
  int? _buildingId;
  int? _roomId;

  String? _assetId;
  String? _faultId;

  DateTime? _scheduledDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    if (AssetService.assetsNotifier.value.isEmpty) {
      AssetService.fetchAssets();
    }
    if (ReportService.reportsNotifier.value.isEmpty) {
      ReportService.fetchReports();
    }
  }

  @override
  void dispose() {
    _briefController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.gold),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final brief = _briefController.text.trim();
    final notes = _notesController.text.trim();
    final payload = <String, dynamic>{
      'job_desc': notes.isEmpty ? brief : '$brief: $notes',
      'job_status': Jobcard.toBackendStatus(_status),
      'job_type': _type,
      'job_priority': _priority,
      'nature': _type,
      'job_createddatetime': DateTime.now().toIso8601String(),
      'job_schedule_type': 'enkel',
      if (_scheduledDate != null)
        'job_scheduled_datetime': _scheduledDate!.toIso8601String(),
      if (_campusId != null) 'location_id': _campusId,
      if (_buildingId != null) 'building_id': _buildingId,
      if (_roomId != null) 'room_id': _roomId,
      if (_assetId != null) 'asset_id': _assetId,
      if (_faultId != null) 'fault_id': _faultId,
    };

    final jobId = await JobcardService.createJobcard(payload);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (jobId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Werksopdrag geskep"),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie werksopdrag skep nie. Probeer weer."),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text("Nuwe Werksopdrag"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBeschrywingCard(),
            _buildTipePrioriteitStatusCard(),
            _buildLiggingCard(),
            _buildBateCard(),
            _buildFoutkaartjieCard(),
            _buildDatumCard(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text("Stoor Werksopdrag"),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildBeschrywingCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _briefController,
            decoration: const InputDecoration(
              labelText: "Kort beskrywing",
              hintText: "Wat moet gedoen word?",
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "Kort beskrywing word vereis"
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Notas (opsioneel)",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipePrioriteitStatusCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: "Tipe",
              border: OutlineInputBorder(),
            ),
            hint: const Text("Kies tipe"),
            items: const ["Onderhoud", "Herstel", "Inspeksie", "Installasie"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(
              labelText: "Prioriteit",
              border: OutlineInputBorder(),
            ),
            items: const ["Laag", "Normal", "Hoog", "Dringend"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _priority = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: "Status",
              border: OutlineInputBorder(),
            ),
            items: const ["Oop", "Wag", "Besig"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _status = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiggingCard() {
    return _buildCard(
      child: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, campuses, _) {
          Campus? selectedCampus;
          for (final c in campuses) {
            if (_campusId != null && c.id == _campusId) {
              selectedCampus = c;
              break;
            }
          }
          final buildings = selectedCampus?.buildings ?? <Building>[];

          Building? selectedBuilding;
          for (final b in buildings) {
            if (_buildingId != null && b.id == _buildingId) {
              selectedBuilding = b;
              break;
            }
          }
          final rooms = selectedBuilding?.rooms ?? <Room>[];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _campusId,
                decoration: const InputDecoration(
                  labelText: "Terrein",
                  border: OutlineInputBorder(),
                ),
                hint: const Text("Kies Terrein"),
                items: campuses
                    .map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _campusId = v;
                  _buildingId = null;
                  _roomId = null;
                  _assetId = null;
                }),
              ),
              if (_campusId != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _buildingId,
                  decoration: const InputDecoration(
                    labelText: "Gebou",
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text("Kies Gebou"),
                  items: buildings
                      .map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _buildingId = v;
                    _roomId = null;
                    _assetId = null;
                  }),
                ),
              ],
              if (_buildingId != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _roomId,
                  decoration: const InputDecoration(
                    labelText: "Lokaal",
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text("Kies Lokaal"),
                  items: rooms
                      .map((r) =>
                          DropdownMenuItem(value: r.id, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _roomId = v;
                    _assetId = null;
                  }),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBateCard() {
    return _buildCard(
      child: ValueListenableBuilder<List<Asset>>(
        valueListenable: AssetService.assetsNotifier,
        builder: (context, assets, _) {
          final roomAssets = _roomId != null
              ? assets.where((a) => a.location == _roomId.toString()).toList()
              : assets;
          final hasSelection =
              _assetId != null && roomAssets.any((a) => a.id == _assetId);
          return DropdownButtonFormField<String>(
            initialValue: hasSelection ? _assetId : null,
            decoration: const InputDecoration(
              labelText: "Bate (opsioneel)",
              border: OutlineInputBorder(),
            ),
            hint: const Text("Kies bate"),
            items: roomAssets
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => setState(() => _assetId = v),
          );
        },
      ),
    );
  }

  Widget _buildFoutkaartjieCard() {
    return _buildCard(
      child: ValueListenableBuilder<List<Report>>(
        valueListenable: ReportService.reportsNotifier,
        builder: (context, reports, _) {
          final hasSelection =
              _faultId != null && reports.any((r) => r.id == _faultId);
          return DropdownButtonFormField<String>(
            initialValue: hasSelection ? _faultId : null,
            decoration: const InputDecoration(
              labelText: "Koppel foutkaartjie (opsioneel)",
              border: OutlineInputBorder(),
            ),
            hint: const Text("Kies foutkaartjie"),
            items: reports
                .map((r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(r.title, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _faultId = v),
          );
        },
      ),
    );
  }

  Widget _buildDatumCard() {
    final formatted = _scheduledDate != null
        ? "${_scheduledDate!.year}-${_scheduledDate!.month.toString().padLeft(2, '0')}-${_scheduledDate!.day.toString().padLeft(2, '0')}"
        : null;
    return _buildCard(
      child: InkWell(
        onTap: _pickScheduledDate,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: "Geskeduleerde datum (opsioneel)",
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today, color: AppColors.gold),
            hintText: formatted == null ? "Kies datum" : null,
          ),
          child: formatted == null
              ? null
              : Text(formatted, style: const TextStyle(color: Colors.black87)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../models/jobcard.dart';
import '../../models/user_session.dart';
import '../../services/camera_service.dart';
import '../../services/image_service.dart';
import '../../services/jobcard_service.dart';
import '../../services/user_service.dart';

/// Kontrakteur-aansig van 'n werksopdrag: leesbare Besonderhede (insluitend die
/// foutkaartjie se fotos) plus 'n Kontrakteur Werknotas-blad waar werknotas en
/// eie fotos (tot 3) bygevoeg kan word, en 'n voltooiingsversoek gestuur word
/// aan die verantwoordelike personeellid.
class JobcardDetailPage extends StatefulWidget {
  final Jobcard job;

  const JobcardDetailPage({super.key, required this.job});

  @override
  State<JobcardDetailPage> createState() => _JobcardDetailPageState();
}

class _JobcardDetailPageState extends State<JobcardDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _notesController;

  final List<int> _ownImageIds = [];
  final List<int> _faultImageIds = [];
  bool _imagesLoading = true;

  bool _savingNotes = false;
  bool _requesting = false;

  int get _maxOwnPhotos => 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notesController = TextEditingController(text: widget.job.jobNotes ?? '');
    _loadImages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    final own = await ImageService.getImagesForParent('job', widget.job.id);
    final fault = widget.job.faultId != null
        ? await ImageService.getImagesForParent('ticket', widget.job.faultId!)
        : <int>[];
    if (!mounted) return;
    setState(() {
      _ownImageIds
        ..clear()
        ..addAll(own);
      _faultImageIds
        ..clear()
        ..addAll(fault);
      _imagesLoading = false;
    });
  }

  Future<void> _addPhoto() async {
    if (_ownImageIds.length >= _maxOwnPhotos) return;
    final photo = await CameraService.takePhoto();
    if (photo == null) return;
    final imageId = await ImageService.uploadImage(
      photo,
      parentId: widget.job.id,
      parentType: 'job',
    );
    if (imageId == null) {
      _showSnack("Kon nie foto oplaai nie.", error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _ownImageIds.add(imageId));
    _showSnack("Foto bygevoeg");
  }

  Future<void> _removePhoto(int imageId) async {
    final ok = await ImageService.deleteImage(imageId);
    if (!mounted) return;
    if (ok) {
      setState(() => _ownImageIds.remove(imageId));
    } else {
      _showSnack("Kon nie foto verwyder nie.", error: true);
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    final ok = await JobcardService.updateJobNotes(
      widget.job.id,
      _notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _savingNotes = false);
    _showSnack(ok ? "Werknotas gestoor" : "Kon nie werknotas stoor nie.",
        error: !ok);
  }

  String get _assignedLabel {
    if (widget.job.assignedTo == null) return "Nie toegewys nie";
    final backendName = widget.job.assignedName;
    if (backendName != null && backendName.isNotEmpty) return backendName;
    final name = UserService.nameFor(widget.job.assignedTo);
    return name.isNotEmpty ? name : "Personeellid #${widget.job.assignedTo}";
  }

  String get _contractorLabel {
    final contractorId = widget.job.contractorId;
    if (contractorId == null) return "Nie toegewys nie";
    final backendName = widget.job.contractorName;
    if (backendName != null && backendName.isNotEmpty) return backendName;
    final name = UserService.nameFor(contractorId);
    return name.isNotEmpty ? name : "Kontrakteur #$contractorId";
  }

  Future<void> _requestCompletion() async {
    final name = widget.job.assignedName ?? UserService.nameFor(widget.job.assignedTo);
    final target = name.isNotEmpty ? name : "die verantwoordelike personeellid";

    final jaNee = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Werksopdrag Voltooi?"),
        content: Text(
          "Stuur 'n voltooiingsversoek aan $target om hierdie werksopdrag te voltooi?",
        ),
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
    if (jaNee != true) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Bevestig"),
        content: const Text("Is jy seker jy wil die voltooiingsversoek stuur?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("KANSELLEER"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("STUUR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _requesting = true);
    final ok = await JobcardService.requestCompletion(widget.job.id);
    if (!mounted) return;
    setState(() => _requesting = false);
    _showSnack(
      ok ? "Voltooiingsversoek aan $target gestuur" : "Kon nie voltooiingsversoek stuur nie.",
      error: !ok,
    );
  }

  bool get _isTerminal =>
      widget.job.status == "Voltooi" || widget.job.status == "Gekanselleer";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Werksopdrag #${widget.job.id}"),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.gold,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(text: "Besonderhede"),
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
                _buildKontrakteurTab(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    // Slegs die toegewysde kontrakteur (met jobs.update_own_status) kan 'n
    // voltooiingsversoek stuur — selfde reël as die backend se eindpunt.
    final canRequest = UserSession.can('jobs.update_own_status') &&
        widget.job.contractorId == UserSession.userId;
    if (!canRequest) return const SizedBox.shrink();

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
          onPressed:
              (_isTerminal || _requesting) ? null : _requestCompletion,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
          child: _requesting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text("WERKSOPDRAG VOLTOOI?",
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildBesonderhedeTab() {
    final job = widget.job;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Besonderhede"),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "#${job.id}",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                    _buildStatusChip(job.status),
                  ],
                ),
                const Divider(height: 20),
                _infoRow("Beskrywing", job.description),
                if (job.fullDescription.isNotEmpty &&
                    job.fullDescription != job.description)
                  _infoRow("Volle beskrywing", job.fullDescription),
                if (job.type != null) _infoRow("Tipe", job.type!),
                _infoRow("Prioriteit", job.priority ?? "-"),
                if (job.nature != null) _infoRow("Natuur", job.nature!),
                if (job.createdDatetime != null && UserSession.can('jobs.manage'))
                  _infoRow("Geskep", _formatDateTime(job.createdDatetime!)),
                if (job.scheduledDatetime != null)
                  _infoRow("Begin datum en tyd", _formatDateTime(job.scheduledDatetime!)),
                if (job.scheduledEndDatetime != null)
                  _infoRow("Einddatum en tyd", _formatDateTime(job.scheduledEndDatetime!)),
                if (job.finishedDatetime != null)
                  _infoRow("Voltooi op", _formatDateTime(job.finishedDatetime!)),
                _infoRow("Verantwoordelike personeellid", _assignedLabel),
                if (job.contractorId != null) _infoRow("Kontrakteur", _contractorLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKontrakteurTab() {
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
              hintText: "Tik werknotas hier...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingNotes ? null : _saveNotes,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              child: _savingNotes
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("STOOR WERKNOTAS",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle("Jou Fotos"),
          const SizedBox(height: 12),
          _buildOwnPhotos(),
        ],
      ),
    );
  }

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

  Widget _buildOwnPhotos() {
    final baseUrl = ApiClient().client.options.baseUrl;

    if (_imagesLoading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_ownImageIds.isEmpty)
          const Text("Nog geen fotos nie.", style: TextStyle(color: Colors.grey)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in _ownImageIds)
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
                      onTap: () => _removePhoto(id),
                      child: Container(
                        decoration: const BoxDecoration(
                            color: AppColors.errorRed, shape: BoxShape.circle),
                        child:
                            const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            if (_ownImageIds.length < _maxOwnPhotos)
              InkWell(
                onTap: _addPhoto,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.grey, size: 28),
                ),
              ),
          ],
        ),
      ],
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
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.navy, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title.toUpperCase(),
        style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.2));
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
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
}

import '../../services/campus_service.dart';
import 'edit_report_page.dart';
import '../jobcards/jobcard_form_page.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../services/report_service.dart';
import '../../services/image_service.dart';
import '../../models/user_session.dart';
import '../../models/report.dart';
import '../../widgets/detail_row.dart';

class ReportDetailPage extends StatefulWidget {
  final Report report;

  const ReportDetailPage({super.key, required this.report});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Report _currentReport;
  List<int> _imageIds = [];
  bool _imagesLoading = true;
  LatLng? _mapPoint;

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
    _loadImages();
    _loadMapPoint();
  }

  // Haal die kaartligging (Mappoint) vir die kaartjie op.
  Future<void> _loadMapPoint() async {
    final mappointId = _currentReport.mappointId;
    if (mappointId == null) return;
    try {
      final response = await ApiClient().client.get('/mappoint/$mappointId');
      if (response.statusCode == 200) {
        final lat = (response.data['latitude'] as num?)?.toDouble();
        final lng = (response.data['longitude'] as num?)?.toDouble();
        if (mounted && lat != null && lng != null) {
          setState(() => _mapPoint = LatLng(lat, lng));
        }
      }
    } catch (e) {
      debugPrint("Kon nie kaartligging laai nie: $e");
    }
  }

  // Haal die kaartjie se fotos (ImageAssetLink met parent_type 'ticket').
  Future<void> _loadImages() async {
    final faultId = int.tryParse(_currentReport.id);
    if (faultId == null) {
      if (mounted) setState(() => _imagesLoading = false);
      return;
    }
    final ids = await ImageService.getImagesForParent('ticket', faultId);
    if (mounted) {
      setState(() {
        _imageIds = ids;
        _imagesLoading = false;
      });
    }
  }

  // Herlaai data vanaf die diens om nuutste status te wys
  Future<void> _refreshData() async {
    await ReportService.fetchReports();
    if (!mounted) return;
    final updated = ReportService.reportsNotifier.value
        .where((r) => r.id == _currentReport.id)
        .firstOrNull;
    if (updated == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Verslag nie meer gevind nie"),
              backgroundColor: AppColors.warningOrange),
        );
      }
      return;
    }
    setState(() {
      _currentReport = updated;
    });
    _loadImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("FBS FOUTKAARTJIE #${_currentReport.id}"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(context),
            const SizedBox(height: 25),
            _buildSectionHeader("Besonderhede"),
            const SizedBox(height: 12),
            DetailRow(label: "Kampus",
                value: CampusService.getCampusNameByRoomId(_currentReport.location)),
            DetailRow(label: "Gebou",
                value: CampusService.getBuildingNameByRoomId(_currentReport.location)),
            DetailRow(label: "Lokaal",
                value: CampusService.getRoomName(_currentReport.location)),
            if (_currentReport.isOutdoor)
              const DetailRow(label: "Buite Lokaal", value: "Ja"),
            if (_mapPoint != null) ...[
              const SizedBox(height: 12),
              _buildMapCard(),
            ],
            if (UserSession.can('faults.view'))
              DetailRow(label: "Bate ID",
                  value: _currentReport.assetSerialCode ?? _currentReport.assetId),
            DetailRow(label: "Werksoort", value: _currentReport.category),
            DetailRow(label: "Opskrif", value: _currentReport.title),
            if (_currentReport.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _currentReport.description,
                  style: TextStyle(
                      color: Colors.grey[700], fontSize: 14, height: 1.5),
                ),
              ),

            // LET WEL: Admin Notas is hier verwyder totdat backend dit ondersteun.

            const SizedBox(height: 25),
            _buildImageSection(),
            const SizedBox(height: 25),
            _buildSectionHeader("Tydlyn (Audit Log)"),
            const SizedBox(height: 15),
            _buildTimeline(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    if (_imagesLoading || _imageIds.isEmpty) return const SizedBox.shrink();

    final baseUrl = ApiClient().client.options.baseUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Foto's"),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _imageIds.map((id) {
            final imageUrl = '$baseUrl/image/$id/file';
            return InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: InteractiveViewer(
                        child: Image.network(imageUrl, fit: BoxFit.contain)),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    width: 120,
                    color: Colors.grey[200],
                    child: const Center(
                        child: Text("Foto nie\nbeskikbaar",
                            textAlign: TextAlign.center)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    String phase = _currentReport.phase;

    // Sinkroniseer kleure met Paneelbord: Besig/Voltooi = Groen, Geweier = Rooi, Ontvang = Goud
    Color statusColor =
        (phase == "Voltooi" || phase == "Opgelos" || phase == "Besig")
            ? AppColors.successGreen
            : (phase == "Geweier" || phase == "Verwerp"
                ? AppColors.errorRed
                : AppColors.gold);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  phase == "Voltooi" || phase == "Opgelos"
                      ? Icons.check_circle
                      : (phase == "Besig" ||
                              phase == "Bevestig" ||
                              phase == "Oop"
                          ? Icons.pending
                          : (phase == "Geweier" || phase == "Verwerp"
                              ? Icons.cancel
                              : Icons.mark_as_unread)),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Huidige Status",
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    Text(phase.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          if (UserSession.can('jobs.manage')) ...[
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          JobcardFormPage(report: _currentReport),
                    ),
                  );
                  if (created == true) _refreshData();
                },
                icon: const Icon(Icons.assignment_add,
                    color: Colors.white, size: 18),
                label: const Text("SKEP WERKSOPDRAG",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
          if (UserSession.can('faults.manage')) ...[
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                EditReportPage(report: _currentReport)),
                      );
                      if (result == true) _refreshData();
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text("WYSIG",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteDialog(context),
                    icon: const Icon(Icons.delete,
                        color: AppColors.errorRed, size: 18),
                    label: const Text("VERWYDER",
                        style: TextStyle(
                            color: AppColors.errorRed,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.errorRed),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder Foutkaartjie",
            style: TextStyle(
                color: AppColors.errorRed, fontWeight: FontWeight.bold)),
        content: const Text(
            "Is jy seker jy wil hierdie foutkaartjie permanent verwyder? Hierdie aksie kan nie ongedaan gemaak word nie."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("KANSELLEER")),
          StatefulBuilder(
            builder: (builderContext, setInnerState) => ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: isDeleting
                  ? null
                  : () async {
                      setInnerState(() => isDeleting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final success =
                          await ReportService.deleteReport(_currentReport.id);
                      if (!mounted) return;
                      if (success) {
                        Navigator.pop(dialogContext); // Maak dialoog toe
                        Navigator.pop(context); // Gaan terug na lys
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text("Foutkaartjie verwyder"),
                              backgroundColor: AppColors.errorRed),
                        );
                      } else {
                        setInnerState(() => isDeleting = false);
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Kon nie foutkaartjie verwyder nie. Probeer weer."),
                              backgroundColor: AppColors.errorRed),
                        );
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("VERWYDER",
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(),
        style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.2));
  }

  Widget _buildMapCard() {
    final point = _mapPoint!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Kaartligging"),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IgnorePointer(
            child: SizedBox(
              height: 180,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: point, zoom: 17),
                markers: {
                  Marker(
                      markerId: const MarkerId("fault_point"), position: point),
                },
                zoomControlsEnabled: false,
                myLocationEnabled: false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    // LET WEL: Die backend hou 'n werklike audit-log (fault_service._create_audit_log),
    // maar die mobiele kliënt het nog nie 'n endpoint om dit te lees nie. Tot
    // dan word 'n gefabriseerde tydlyn vermy en eerder 'n duidelike nota gewys.
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Audits is tans nie op die mobiele app beskikbaar nie.",
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}

<<<<<<< HEAD
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
import 'dart:typed_data';

class ReportDetailPage extends StatefulWidget {
  final Report report;
  final Uint8List? screenshot;

  const ReportDetailPage({super.key, required this.report, this.screenshot});

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
  void _refreshData() async {
    await ReportService.fetchReports();
    try {
      final updated = ReportService.reportsNotifier.value.firstWhere((r) => r.id == _currentReport.id);
      setState(() {
        _currentReport = updated;
      });
      _loadImages();
    } catch (e) {
      debugPrint("Kon nie verslag verfris nie: $e");
    }
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
            _buildDetailRow("Kampus", CampusService.getCampusNameByRoomId(_currentReport.location)),
            _buildDetailRow("Gebou", CampusService.getBuildingNameByRoomId(_currentReport.location)),
            _buildDetailRow("Lokaal", CampusService.getRoomName(_currentReport.location)),
            if (_currentReport.isOutdoor)
              _buildDetailRow("Buite Lokaal", "Ja"),
            if (_mapPoint != null) ...[
              const SizedBox(height: 12),
              _buildMapCard(),
            ],
            if (UserSession.can('faults.view'))
              _buildDetailRow("Bate ID", _currentReport.assetSerialCode ?? _currentReport.assetId),
            _buildDetailRow("Werksoort", _currentReport.category),
            _buildDetailRow("Opskrif", _currentReport.title),
            if (_currentReport.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _currentReport.description,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
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
                    child: InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain)),
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
                    child: const Center(child: Text("Foto nie\nbeskikbaar", textAlign: TextAlign.center)),
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
    Color statusColor = (phase == "Voltooi" || phase == "Opgelos" || phase == "Besig") 
        ? AppColors.successGreen 
        : (phase == "Geweier" || phase == "Verwerp" ? AppColors.errorRed : AppColors.gold);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
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
                  phase == "Voltooi" || phase == "Opgelos" ? Icons.check_circle : (phase == "Besig" || phase == "Bevestig" || phase == "Oop" ? Icons.pending : (phase == "Geweier" || phase == "Verwerp" ? Icons.cancel : Icons.mark_as_unread)),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Huidige Status", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(phase.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          if (UserSession.can('jobs.manage')) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobcardFormPage(report: _currentReport),
                    ),
                  );
                  if (created == true) _refreshData();
                },
                icon: const Icon(Icons.assignment_add, color: Colors.white, size: 18),
                label: const Text("SKEP WERKSOPDRAG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
          if (UserSession.can('faults.manage')) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditReportPage(report: _currentReport)),
                      );
                      if (result == true) _refreshData();
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text("WYSIG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.terracotta, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteDialog(context),
                    icon: const Icon(Icons.delete, color: AppColors.errorRed, size: 18),
                    label: const Text("VERWYDER", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.errorRed), padding: const EdgeInsets.symmetric(vertical: 12)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verwyder Foutkaartjie", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
        content: const Text("Is jy seker jy wil hierdie foutkaartjie permanent verwyder? Hierdie aksie kan nie ongedaan gemaak word nie."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KANSELLEER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () async {
              final success = await ReportService.deleteReport(_currentReport.id);
              if (!mounted) return;
              if (success) {
                if (context.mounted) {
                  Navigator.pop(context); // Maak dialoog toe
                  Navigator.pop(context); // Gaan terug na lys
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Foutkaartjie verwyder"), backgroundColor: AppColors.errorRed),
                  );
                }
              }
            },
            child: const Text("VERWYDER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(), style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2));
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
                  Marker(markerId: const MarkerId("fault_point"), position: point),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    List<Map<String, String>> logs = [{"event": "Verslag Ontvang", "time": _currentReport.timestamp.toString().split('.')[0]}];
    if (_currentReport.phase == "Besig" || _currentReport.phase == "Voltooi") logs.add({"event": "In Vordering", "time": "Hanteer"});
    if (_currentReport.phase == "Voltooi") logs.add({"event": "Voltooi", "time": "Opgelos"});
    if (_currentReport.phase == "Geweier") logs.add({"event": "Verwerp", "time": "Geweier"});

    return Column(
        children: logs.map((log) => _buildTimelineItem(log['event']!, log['time']!, isLast: logs.last == log, isCompleted: true)).toList()
    );
  }

  Widget _buildTimelineItem(String title, String time, {bool isLast = false, bool isCompleted = false}) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: isCompleted ? AppColors.gold : Colors.grey[300], shape: BoxShape.circle)),
            if (!isLast) Container(width: 2, height: 40, color: isCompleted ? AppColors.gold.withValues(alpha: 0.5) : Colors.grey[200]),
          ]),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            const SizedBox(height: 20),
          ])),
        ]
    );
  }
}
=======
import '../../services/campus_service.dart';
import 'edit_report_page.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../services/report_service.dart';
import '../../models/user_session.dart';
import '../../models/report.dart';
import 'dart:typed_data';

class ReportDetailPage extends StatefulWidget {
  final Report report;
  final Uint8List? screenshot;

  const ReportDetailPage({super.key, required this.report, this.screenshot});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Report _currentReport;

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
  }

  // Herlaai data vanaf die diens om nuutste status te wys
  void _refreshData() async {
    await ReportService.fetchReports();
    try {
      final updated = ReportService.reportsNotifier.value.firstWhere((r) => r.id == _currentReport.id);
      setState(() {
        _currentReport = updated;
      });
    } catch (e) {
      debugPrint("Kon nie verslag verfris nie: $e");
    }
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
            _buildDetailRow("Kampus", CampusService.getCampusNameByRoomId(_currentReport.location)),
            _buildDetailRow("Gebou", CampusService.getBuildingNameByRoomId(_currentReport.location)),
            _buildDetailRow("Lokaal", CampusService.getRoomName(_currentReport.location)),
            if (UserSession.hasAdminPrivileges)
              _buildDetailRow("Bate ID", _currentReport.assetSerialCode ?? _currentReport.assetId),
            _buildDetailRow("Kategorie", _currentReport.category),
            _buildDetailRow("Opskrif", _currentReport.title),
            if (_currentReport.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _currentReport.description,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
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
    if (_currentReport.imageId == null) return const SizedBox.shrink();

    final imageUrl = '${ApiClient().client.options.baseUrl}/image/${_currentReport.imageId}/file';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Foto"),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain)),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: Text("Foto nie beskikbaar")),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    String phase = _currentReport.phase;
    
    // Sinkroniseer kleure met Paneelbord: Besig/Voltooi = Groen, Geweier = Rooi, Ontvang = Goud
    Color statusColor = (phase == "Voltooi" || phase == "Opgelos" || phase == "Besig") 
        ? AppColors.successGreen 
        : (phase == "Geweier" || phase == "Verwerp" ? AppColors.errorRed : AppColors.gold);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
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
                  phase == "Voltooi" || phase == "Opgelos" ? Icons.check_circle : (phase == "Besig" || phase == "Bevestig" || phase == "Oop" ? Icons.pending : (phase == "Geweier" || phase == "Verwerp" ? Icons.cancel : Icons.mark_as_unread)),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Huidige Status", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(phase.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          if (UserSession.hasAdminPrivileges) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditReportPage(report: _currentReport)),
                      );
                      if (result == true) _refreshData();
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text("WYSIG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.terracotta, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteDialog(context),
                    icon: const Icon(Icons.delete, color: AppColors.errorRed, size: 18),
                    label: const Text("VERWYDER", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.errorRed), padding: const EdgeInsets.symmetric(vertical: 12)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verwyder Foutkaartjie", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
        content: const Text("Is jy seker jy wil hierdie foutkaartjie permanent verwyder? Hierdie aksie kan nie ongedaan gemaak word nie."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KANSELLEER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () async {
              final success = await ReportService.deleteReport(_currentReport.id);
              if (!mounted) return;
              if (success) {
                if (context.mounted) {
                  Navigator.pop(context); // Maak dialoog toe
                  Navigator.pop(context); // Gaan terug na lys
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Foutkaartjie verwyder"), backgroundColor: AppColors.errorRed),
                  );
                }
              }
            },
            child: const Text("VERWYDER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(), style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2));
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    List<Map<String, String>> logs = [{"event": "Verslag Ontvang", "time": _currentReport.timestamp.toString().split('.')[0]}];
    if (_currentReport.phase == "Besig" || _currentReport.phase == "Voltooi") logs.add({"event": "In Vordering", "time": "Hanteer"});
    if (_currentReport.phase == "Voltooi") logs.add({"event": "Voltooi", "time": "Opgelos"});
    if (_currentReport.phase == "Geweier") logs.add({"event": "Verwerp", "time": "Geweier"});

    return Column(
        children: logs.map((log) => _buildTimelineItem(log['event']!, log['time']!, isLast: logs.last == log, isCompleted: true)).toList()
    );
  }

  Widget _buildTimelineItem(String title, String time, {bool isLast = false, bool isCompleted = false}) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: isCompleted ? AppColors.gold : Colors.grey[300], shape: BoxShape.circle)),
            if (!isLast) Container(width: 2, height: 40, color: isCompleted ? AppColors.gold.withValues(alpha: 0.5) : Colors.grey[200]),
          ]),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            const SizedBox(height: 20),
          ])),
        ]
    );
  }
}
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

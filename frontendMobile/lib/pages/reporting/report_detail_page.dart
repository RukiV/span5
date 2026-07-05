import 'edit_report_page.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
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
        title: Text("FBS VERSLAG #${_currentReport.id}"),
        actions: [
          if (UserSession.hasAdminPrivileges)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteDialog(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(context),
            const SizedBox(height: 25),
            _buildImageSection(),
            const SizedBox(height: 25),
            _buildSectionHeader("Besonderhede"),
            const SizedBox(height: 12),
            _buildDetailRow("Lokaal", _currentReport.location),
            _buildDetailRow("Bate ID", _currentReport.assetId),
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
    if (widget.screenshot == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Ligging Kaart"),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: InteractiveViewer(child: Image.memory(widget.screenshot!, fit: BoxFit.contain)),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(widget.screenshot!, fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    String phase = _currentReport.phase;
    String priority = _currentReport.priority;
    Color statusColor = phase == "Voltooi" || phase == "Opgelos" ? Colors.green : (phase == "Besig" || phase == "Bevestig" || phase == "Oop" ? Colors.blue : (phase == "Geweier" || phase == "Verwerp" ? Colors.red : Colors.orange));

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
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    label: const Text("VERWYDER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ] else ...[
            if (priority != "Geen")
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Prioriteit:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    _buildPriorityBadge(priority),
                  ],
                ),
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
        title: const Text("Verwyder Foutkaartjie", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("Is jy seker jy wil hierdie foutkaartjie permanent verwyder? Hierdie aksie kan nie ongedaan gemaak word nie."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KANSELLEER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ReportService.deleteReport(_currentReport.id);
              if (mounted) {
                Navigator.pop(context); // Maak dialoog toe
                if (success) {
                  Navigator.pop(context); // Gaan terug na lys
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Foutkaartjie verwyder"), backgroundColor: Colors.red),
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

  Widget _buildPriorityBadge(String priority) {
    Color col = priority == 'Hoog' ? Colors.red : (priority == 'Medium' ? Colors.orange : Colors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(priority, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 11)),
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
import 'handle_report_page.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../models/user_session.dart';
import '../../models/report.dart';
import 'scan_page.dart';
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

  // Hierdie funksie herlaai die data as ons terugkom van die hanteer-blad
  void _refreshData() async {
    await ReportService.fetchReports();
    final updated = ReportService.reportsNotifier.value.firstWhere((r) => r.id == _currentReport.id);
    setState(() {
      _currentReport = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("FBS VERSLAG #${_currentReport.id}"),
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
            _buildDetailRow("Opskrif", _currentReport.title),
            if (_currentReport.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _currentReport.description,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
                ),
              ),
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
    if (widget.screenshot == null) {
      return const SizedBox.shrink();
    }

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

  Widget _imagePlaceholder() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40),
          SizedBox(height: 8),
          Text("Geen foto beskikbaar", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    String phase = _currentReport.phase;
    String priority = _currentReport.priority;
    Color statusColor = phase == "Voltooi" ? Colors.green : (phase == "Besig" ? Colors.blue : (phase == "Geweier" ? Colors.red : Colors.orange));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  phase == "Voltooi" ? Icons.check_circle : (phase == "Besig" ? Icons.pending : (phase == "Geweier" ? Icons.cancel : Icons.mark_as_unread)),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Huidige Status",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      phase.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (UserSession.hasAdminPrivileges) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(),
            ),
            const Text(
              "ADMIN: VERSLAG BESTUUR",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navy, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),
            if (phase == "Ontvang") ...[
              Text(
                "Hierdie verslag is nuut. Klik op 'Hanteer Verslag' om 'n prioriteit toe te ken en die herstelproses te begin.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => HandleReportPage(report: _currentReport))
                    );
                    if (result == true) _refreshData();
                  },
                  icon: const Icon(Icons.assignment_turned_in, color: Colors.white),
                  label: const Text("HANTEER VERSLAG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showDisapproveDialog(context),
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text("VERWERP VERSLAG", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ),
            ] else ...[
              const Text(
                "Prioriteit Bestuur",
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPriorityButton(context, "Laag", Colors.green),
                  _buildPriorityButton(context, "Medium", Colors.orange),
                  _buildPriorityButton(context, "Hoog", Colors.red),
                ],
              ),
              const SizedBox(height: 15),
              if (phase != "Voltooi" && phase != "Geweier")
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markAsComplete(),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text("MERK AS VOLTOOI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
            ],
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

  void _showDisapproveDialog(BuildContext context) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verwerp Verslag", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Gee asseblief 'n rede hoekom hierdie verslag verwerp word."),
            const SizedBox(height: 15),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Rede vir verwerping...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KANSELLEER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ReportService.disapproveReport(_currentReport.id, notesController.text);
              if (mounted) {
                Navigator.pop(context);
                _refreshData();
              }
            },
            child: const Text("VERWERP", style: TextStyle(color: Colors.white)),
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
        color: col.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority,
        style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Future<void> _markAsComplete() async {
    final success = await ReportService.updateReportStatus(_currentReport.id, "Voltooi");
    if (success && mounted) {
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verslag gemerk as Voltooi"), backgroundColor: Colors.green)
      );
    }
  }

  Widget _buildPriorityButton(BuildContext context, String label, Color color) {
    bool isSelected = _currentReport.priority == label;
    return InkWell(
      onTap: () {
        _updatePriorityOnly(label, color);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color, 
            fontWeight: FontWeight.bold, 
            fontSize: 12
          ),
        ),
      ),
    );
  }

  Future<void> _updatePriorityOnly(String priority, Color color) async {
    final success = await ReportService.updateReportPriority(_currentReport.id, priority);
    if (success && mounted) {
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Prioriteit verander na $priority"), backgroundColor: color)
      );
    }
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
    if (_currentReport.phase == "Besig" || _currentReport.phase == "Voltooi") {
      logs.add({"event": "In Vordering / Goedgekeur", "time": "Hanteer"});
    }
    if (_currentReport.phase == "Voltooi") {
      logs.add({"event": "Herstelwerk voltooi", "time": "Opgelos"});
    }
    if (_currentReport.phase == "Geweier") {
      logs.add({"event": "Verslag Verwerp", "time": "Geweier"});
    }
    return Column(children: logs.map((log) => _buildTimelineItem(log['event']!, log['time']!, isLast: logs.last == log, isCompleted: true)).toList());
  }

  Widget _buildTimelineItem(String title, String time, {bool isLast = false, bool isCompleted = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: isCompleted ? AppColors.gold : Colors.grey[300], shape: BoxShape.circle)),
        if (!isLast) Container(width: 2, height: 40, color: isCompleted ? AppColors.gold.withOpacity(0.5) : Colors.grey[200]),
      ]),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 20),
      ])),
    ]);
  }
}

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
            if (_currentReport.imageUrl != null || widget.screenshot != null) ...[
              _buildSectionHeader("Foto van Probleem"),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _currentReport.imageUrl != null 
                  ? Image.network(
                      _currentReport.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => _imagePlaceholder(),
                    )
                  : Image.memory(
                      widget.screenshot!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
              ),
              const SizedBox(height: 25),
            ],
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

  Widget _buildStatusCard(BuildContext context) {
    String phase = _currentReport.phase;
    String priority = _currentReport.priority;
    Color statusColor = phase == "Voltooi" ? Colors.green : (phase == "Besig" ? Colors.blue : Colors.orange);
    
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
                  color: statusColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  phase == "Voltooi" ? Icons.check_circle : (phase == "Besig" ? Icons.pending : Icons.mark_as_unread),
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
          if (UserSession.hasAdminPrivileges && phase == "Ontvang") ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(),
            ),
            const Text(
              "ADMIN: VERSLAG GOEDKEURING",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navy, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              "Stel die prioriteit nadat jy die bate fisies nagesien het om die herstelproses te begin.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildApprovalAction(context, "Laag", Colors.green),
                _buildApprovalAction(context, "Medium", Colors.orange),
                _buildApprovalAction(context, "Hoog", Colors.red),
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

  Widget _buildPriorityBadge(String priority) {
    Color col = priority == 'Hoog' ? Colors.red : (priority == 'Medium' ? Colors.orange : Colors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority,
        style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildApprovalAction(BuildContext context, String label, Color color) {
    return InkWell(
      onTap: () => _showApprovalDialog(context, label, color),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, String priority, Color color) {
    final notesController = TextEditingController();
    final titleController = TextEditingController(text: _currentReport.title);
    final descController = TextEditingController(text: _currentReport.description);
    final manualIdController = TextEditingController();
    
    String? geverifiseerdeKode;
    bool kodeOnsigbaar = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isVerified = (geverifiseerdeKode != null) || 
                           (manualIdController.text.isNotEmpty) || 
                           kodeOnsigbaar;
          
          return AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text("Goedkeuring as $priority", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sertifiseer die bate deur te skandeer of die ID handmatig in te voer.", style: TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage(isLocation: false)));
                          if (result != null) setDialogState(() => geverifiseerdeKode = result);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: geverifiseerdeKode != null ? Colors.green.withValues(alpha: 0.2) : AppColors.navy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: geverifiseerdeKode != null ? Colors.green : AppColors.navy.withValues(alpha: 0.3)),
                          ),
                          child: Icon(geverifiseerdeKode != null ? Icons.check_circle : Icons.qr_code_scanner, color: geverifiseerdeKode != null ? Colors.green : AppColors.navy),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: manualIdController,
                        onChanged: (v) => setDialogState(() {}),
                        decoration: InputDecoration(hintText: "Handmatige ID...", hintStyle: const TextStyle(fontSize: 12), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(value: kodeOnsigbaar, activeColor: AppColors.navy, onChanged: (v) => setDialogState(() => kodeOnsigbaar = v ?? false)),
                    const Text("Kode Onsigbaar / Beskadig", style: TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                ),
                const Divider(height: 30),
                const Text("KAARTJIE RESTELLINGS (Opsioneel)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: "Nuwe Opskrif", labelStyle: TextStyle(fontSize: 12), isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(labelText: "Nuwe Beskrywing", labelStyle: TextStyle(fontSize: 12), isDense: true, border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: notesController, maxLines: 2, decoration: InputDecoration(hintText: "Admin interne notas...", hintStyle: const TextStyle(fontSize: 12), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("KANSELLEER", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isVerified ? color : Colors.grey[400], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: isVerified ? () async {
                  await ReportService.approveReport(_currentReport.id, priority, notesController.text);
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {
                      _currentReport = _currentReport.copyWith(priority: priority, phase: 'Besig', adminNotes: notesController.text);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verslag goedgekeur as $priority"), backgroundColor: color));
                  }
                } : null,
                child: const Text("GOEDKEUR & BEGIN"),
              ),
            ],
          );
        }),
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
    List<Map<String, String>> logs = [{"event": "Verslag Ontvang", "time": _currentReport.timestamp.toString()}];
    if (_currentReport.phase == "Besig" || _currentReport.phase == "Voltooi") {
      logs.add({"event": "Toegewys aan Tegnikus", "time": "Onlangs"});
    }
    if (_currentReport.phase == "Voltooi") {
      logs.add({"event": "Herstelwerk voltooi", "time": "Nou"});
    }
    return Column(children: logs.map((log) => _buildTimelineItem(log['event']!, log['time']!, isLast: logs.last == log, isCompleted: true)).toList());
  }

  Widget _buildTimelineItem(String title, String time, {bool isLast = false, bool isCompleted = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: isCompleted ? AppColors.gold : Colors.grey[300], shape: BoxShape.circle)),
        if (!isLast) Container(width: 2, height: 40, color: isCompleted ? AppColors.gold.withValues(alpha: 100/255) : Colors.grey[200]),
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

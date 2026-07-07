import '../../core/campus_service.dart';
import 'edit_report_page.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../core/quote_service.dart';
import '../../models/user_session.dart';
import '../../models/report.dart';
import '../../models/quote.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

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
    QuoteService.fetchQuotes();
  }

  // Herlaai data vanaf die diens om nuutste status te wys
  void _refreshData() async {
    await ReportService.fetchReports();
    await QuoteService.fetchQuotes();
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
              icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
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
            _buildDetailRow("Kampus", CampusService.getCampusNameByRoomId(_currentReport.location)),
            _buildDetailRow("Gebou", CampusService.getBuildingNameByRoomId(_currentReport.location)),
            _buildDetailRow("Lokaal", CampusService.getRoomName(_currentReport.location)),
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
            const SizedBox(height: 25),
            _buildQuoteSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteSection() {
    return ValueListenableBuilder<List<Quote>>(
      valueListenable: QuoteService.quotesNotifier,
      builder: (context, allQuotes, child) {
        final jobId = int.tryParse(_currentReport.id) ?? 0;
        final jobQuotes = allQuotes.where((q) => q.jobId == jobId).toList();

        if (!UserSession.isContractor && !UserSession.hasAdminPrivileges) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader("Kwotasies"),
                if (UserSession.isContractor)
                  TextButton.icon(
                    onPressed: () => _showAddQuoteDialog(context),
                    icon: const Icon(Icons.add, size: 18, color: AppColors.gold),
                    label: const Text("NUWE KWOTASIE", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (jobQuotes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  "Geen kwotasies nog ingedien nie.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...jobQuotes.map((quote) => _buildQuoteCard(quote)),
          ],
        );
      },
    );
  }

  Widget _buildQuoteCard(Quote quote) {
    bool isAdmin = UserSession.hasAdminPrivileges;
    bool isOwnQuote = quote.contractorId == UserSession.userId;
    bool isPending = quote.status.toLowerCase() == 'pending' || quote.status.toLowerCase() == 'wag';
    bool isAccepted = quote.status.toLowerCase() == 'accepted' || quote.status.toLowerCase() == 'aanvaar';

    // Handle Afrikaans/English status
    String statusDisplay = quote.status;
    Color statusColor = Colors.grey;
    if (quote.status.toLowerCase() == 'pending' || quote.status.toLowerCase() == 'wag') {
      statusDisplay = "Wagtend";
      statusColor = AppColors.warningOrange;
    } else if (quote.status.toLowerCase() == 'accepted' || quote.status.toLowerCase() == 'aanvaar') {
      statusDisplay = "Aanvaar";
      statusColor = AppColors.successGreen;
    } else if (quote.status.toLowerCase() == 'rejected' || quote.status.toLowerCase() == 'geweier') {
      statusDisplay = "Geweier";
      statusColor = AppColors.errorRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAccepted ? AppColors.successGreen : Colors.grey[300]!, width: isAccepted ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "R ${quote.price.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusDisplay.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quote.description,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(quote.date),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                if (isAdmin && isPending)
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _handleQuoteAction(quote, 'rejected'),
                        child: const Text("WEIER", style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
                      ),
                      ElevatedButton(
                        onPressed: () => _handleQuoteAction(quote, 'accepted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(60, 30),
                        ),
                        child: const Text("AANVAAR", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  )
                else if (isOwnQuote && isPending)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 20),
                    onPressed: () => _deleteQuote(quote.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQuoteDialog(BuildContext context) {
    final priceController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nuwe Kwotasie", style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Prys (R)", prefixText: "R "),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Beskrywing / Notas"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KANSELLEER")),
          ElevatedButton(
            onPressed: () async {
              double? price = double.tryParse(priceController.text);
              if (price == null || descController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vul asseblief alle velde korrek in")));
                return;
              }

              final newQuote = Quote(
                id: 0,
                jobId: int.parse(_currentReport.id),
                contractorId: UserSession.userId,
                price: price,
                description: descController.text,
                date: DateTime.now(),
                status: 'pending',
              );

              final success = await QuoteService.addQuote(newQuote);
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  _refreshData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kwotasie suksesvol ingedien"), backgroundColor: AppColors.successGreen));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            child: const Text("DIEN IN", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQuoteAction(Quote quote, String newStatus) async {
    final updatedQuote = quote.copyWith(status: newStatus);
    final success = await QuoteService.updateQuote(updatedQuote);
    if (success && mounted) {
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'accepted' ? "Kwotasie aanvaar" : "Kwotasie geweier"),
          backgroundColor: newStatus == 'accepted' ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _deleteQuote(int quoteId) async {
    final success = await QuoteService.deleteQuote(quoteId);
    if (success && mounted) {
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kwotasie verwyder")));
    }
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
        title: const Text("Verwyder Foutkaartjie", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
        content: const Text("Is jy seker jy wil hierdie foutkaartjie permanent verwyder? Hierdie aksie kan nie ongedaan gemaak word nie."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KANSELLEER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () async {
              final success = await ReportService.deleteReport(_currentReport.id);
              if (mounted) {
                Navigator.pop(context); // Maak dialoog toe
                if (success) {
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

  Widget _buildPriorityBadge(String priority) {
    Color col = priority == 'Hoog' ? AppColors.errorRed : (priority == 'Medium' ? AppColors.warningOrange : AppColors.successGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(priority, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Future<void> _updatePriorityOnly(String priority, Color color) async {
    final success = await ReportService.updateReportPriority(_currentReport.id, priority);
    if (success && mounted) {
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Prioriteit verander na $priority"), backgroundColor: color));
      }
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
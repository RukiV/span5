import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../models/report.dart';
import '../reporting/report_detail_page.dart';

class JobCardsPage extends StatefulWidget {
  const JobCardsPage({super.key});

  @override
  State<JobCardsPage> createState() => _JobCardsPageState();
}

class _JobCardsPageState extends State<JobCardsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<List<Report>>(
        valueListenable: ReportService.reportsNotifier,
        builder: (context, reports, child) {
          // Vir kontrakteurs wys ons net take wat "Besig" is
          final jobCards = reports.where((r) => r.phase == "Besig" || r.phase == "Voltooi").toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Werkkaarte",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Bestuur jou toegewysde take en herstelwerk.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: jobCards.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: jobCards.length,
                          itemBuilder: (context, index) {
                            final report = jobCards[index];
                            return _buildJobCard(report);
                          },
                        ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "Geen aktiewe werkkaarte nie",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => ReportService.fetchReports(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
            child: const Text("Herlaai"),
          )
        ],
      ),
    );
  }

  Widget _buildJobCard(Report report) {
    bool isCompleted = report.phase == "Voltooi";
    Color priorityColor = report.priority == "Hoog" ? Colors.red : (report.priority == "Medium" ? Colors.orange : Colors.green);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReportDetailPage(report: report)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "#${report.id}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      report.priority.toUpperCase(),
                      style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(report.location, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(report.phase),
                  if (!isCompleted)
                    ElevatedButton(
                      onPressed: () => _markAsCompleted(report),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text("VOLTOOI", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String phase) {
    Color color = phase == "Voltooi" ? Colors.green : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            phase.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsCompleted(Report report) async {
    // Ons verander die fase na "Voltooi". 
    // Die Report.toJson() sal dit outomaties map na 'fault_status': 'opgelos' vir die backend.
    final updatedReport = report.copyWith(phase: "Voltooi");
    
    try {
      await ReportService.updateReport(updatedReport);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Werkkaart suksesvol opgedateer in databasis"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kon nie status opdateer nie. Is die backend aan?"), backgroundColor: Colors.red),
        );
      }
    }
  }
}

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

import '../../services/report_service.dart';
import '../../models/report.dart';
import '../reporting/report_detail_page.dart';

class WorksAssignmentsPage extends StatelessWidget {
  const WorksAssignmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<List<Report>>(
        valueListenable: ReportService.reportsNotifier,
        builder: (context, reports, child) {
          if (reports.isEmpty) {
            return const Center(
              child: Text(
                "Geen werksopdragte beskikbaar nie.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(report.phase).withValues(alpha: 0.2),
                    child: Icon(Icons.assignment, color: _getStatusColor(report.phase)),
                  ),
                  title: Text(
                    report.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Lokaal: ${report.location}", style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      _buildStatusBadge(report.phase),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ReportDetailPage(report: report)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Wag':
      case 'Ontvang':
        return Colors.orange;
      case 'Besig':
      case 'Oop':
      case 'Bevestig':
        return Colors.blue;
      case 'Voltooi':
      case 'Opgelos':
        return Colors.green;
      case 'Geweier':
      case 'Verwerp':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../models/report.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Opsomming",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<List<Report>>(
            valueListenable: ReportService.reportsNotifier,
            builder: (context, reports, child) {
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard("Totaal", reports.length.toString(), Icons.assignment),
                  _buildStatCard("Hangende", ReportService.pendingCount.toString(), Icons.pending_actions, color: Colors.orange),
                  _buildStatCard("Hoog", ReportService.highPriorityCount.toString(), Icons.priority_high, color: Colors.red),
                  _buildStatCard("Voltooi", (reports.length - ReportService.pendingCount).toString(), Icons.check_circle, color: Colors.green),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          const Text(
            "Onlangse Aktiwiteit",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<List<Report>>(
            valueListenable: ReportService.reportsNotifier,
            builder: (context, reports, child) {
              final recent = reports.take(5).toList();
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recent.length,
                itemBuilder: (context, index) {
                  final r = recent[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.1),
                        child: const Icon(Icons.report, color: AppColors.gold),
                      ),
                      title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${r.location} - ${r.phase}"),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {Color color = AppColors.navy}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

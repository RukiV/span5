import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/jobcard_service.dart';
import '../../models/jobcard.dart';

class WorksAssignmentsPage extends StatelessWidget {
  const WorksAssignmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<List<Jobcard>>(
        valueListenable: JobcardService.jobcardsNotifier,
        builder: (context, jobcards, child) {
          if (jobcards.isEmpty) {
            return const Center(
              child: Text(
                "Geen werksopdragte beskikbaar nie.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: jobcards.length,
            itemBuilder: (context, index) {
              final job = jobcards[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(job.status).withValues(alpha: 0.2),
                    child: Icon(Icons.assignment, color: _getStatusColor(job.status)),
                  ),
                  title: Text(
                    job.description,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (job.type != null) Text(job.type!, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      _buildStatusBadge(job.status),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
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
        return Colors.orange;
      case 'Oop':
        return Colors.blue;
      case 'Besig':
        return Colors.blue;
      case 'Voltooi':
        return Colors.green;
      case 'Gekanselleer':
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

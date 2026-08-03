import 'package:flutter/material.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../core/app_colors.dart';
import '../../services/jobcard_service.dart';
import '../../services/campus_service.dart';
import '../../models/jobcard.dart';
import '../../models/user_session.dart';

class WorksAssignmentsPage extends StatefulWidget {
  const WorksAssignmentsPage({super.key});

  @override
  State<WorksAssignmentsPage> createState() => _WorksAssignmentsPageState();
}

class _WorksAssignmentsPageState extends State<WorksAssignmentsPage> {
  int? _selectedCampusId;
  int? _selectedBuildingId;
  int? _selectedRoomId;

  @override
  void initState() {
    super.initState();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _tryAutoSelectCampus();
  }

  void _tryAutoSelectCampus() {
    if (UserSession.isManager && _selectedCampusId == null && UserSession.locationId != null) {
      final match = CampusService.campusesNotifier.value
          .where((c) => c.id == UserSession.locationId).firstOrNull;
      if (match != null) _selectedCampusId = match.id;
    }
  }

  void _onCampusesChanged() {
    if (mounted) {
      setState(() {
        _tryAutoSelectCampus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildCampusFilter(),
          Expanded(
            child: ValueListenableBuilder<List<Jobcard>>(
              valueListenable: JobcardService.jobcardsNotifier,
              builder: (context, jobcards, child) {
                final filtered = jobcards.where((job) {
                  if (_selectedCampusId != null && job.locationId != _selectedCampusId) return false;
                  if (_selectedBuildingId != null && job.buildingId != _selectedBuildingId) return false;
                  if (_selectedRoomId != null && job.roomId != _selectedRoomId) return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "Geen werksopdragte beskikbaar nie.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final job = filtered[index];
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
          ),
        ],
      ),
    );
  }

  Widget _buildCampusFilter() {
    if (CampusService.campusesNotifier.value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 4),
      child: LocationCascadePicker(
        initialCampusId: _selectedCampusId,
        initialBuildingId: _selectedBuildingId,
        initialRoomId: _selectedRoomId,
        onChanged: (campusId, buildingId, roomId) => setState(() {
          _selectedCampusId = campusId;
          _selectedBuildingId = buildingId;
          _selectedRoomId = roomId;
        }),
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

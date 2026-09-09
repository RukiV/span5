import 'package:flutter/material.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../services/jobcard_service.dart';
import '../../services/campus_service.dart';
import '../../models/jobcard.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';
import '../jobcards/jobcard_form_page.dart';

class WorksAssignmentsPage extends StatefulWidget {
  const WorksAssignmentsPage({super.key});

  @override
  State<WorksAssignmentsPage> createState() => _WorksAssignmentsPageState();
}

class _WorksAssignmentsPageState extends State<WorksAssignmentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('works-assignments', [
    const ColumnDef(key: 'description', label: 'Beskrywing'),
    const ColumnDef(key: 'type', label: 'Tipe', defaultVisible: false),
    const ColumnDef(key: 'status', label: 'Status'),
  ]);
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
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onCampusesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const JobcardFormPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Nuwe Werksopdrag", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
      body: Column(
        children: [
          FixedPageHeader(
            controller: _searchController,
            hintText: "Soek werksopdragte...",
            onChanged: (_) => setState(() {}),
            actions: [
              HeaderIconAction(
                icon: Icons.place_outlined,
                tooltip: "Filter op Ligging",
                activeBadge: _selectedCampusId != null ||
                    _selectedBuildingId != null ||
                    _selectedRoomId != null,
                onTap: () => showLocationFilterSheet(
                  context,
                  depth: LocationDepth.room,
                  campusId: _selectedCampusId,
                  buildingId: _selectedBuildingId,
                  roomId: _selectedRoomId,
                  onChanged: (campusId, buildingId, roomId) => setState(() {
                    _selectedCampusId = campusId;
                    _selectedBuildingId = buildingId;
                    _selectedRoomId = roomId;
                  }),
                ),
              ),
              ColumnVisibilityButton(controller: _colVis, iconOnly: true),
            ],
          ),
          Expanded(
            child: ValueListenableBuilder<List<Jobcard>>(
              valueListenable: JobcardService.jobcardsNotifier,
              builder: (context, jobcards, child) {
                final filtered = jobcards.where((job) {
                  if (_selectedCampusId != null && job.locationId != _selectedCampusId) return false;
                  if (_selectedBuildingId != null && job.buildingId != _selectedBuildingId) return false;
                  if (_selectedRoomId != null && job.roomId != _selectedRoomId) return false;
                  if (_query.isNotEmpty &&
                      !job.description.toLowerCase().contains(_query) &&
                      !(job.type?.toLowerCase().contains(_query) ?? false) &&
                      !job.status.toLowerCase().contains(_query)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (_sortCtrl.isActive) {
                  filtered.sort((a, b) {
                    final dir = _sortCtrl.direction;
                    switch (_sortCtrl.sortKey) {
                      case 'description':
                        return a.description.toLowerCase().compareTo(b.description.toLowerCase()) * dir;
                      case 'type':
                        return (a.type ?? '').toLowerCase().compareTo((b.type ?? '').toLowerCase()) * dir;
                      case 'status':
                        return a.status.toLowerCase().compareTo(b.status.toLowerCase()) * dir;
                      default:
                        return 0;
                    }
                  });
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "Geen werksopdragte beskikbaar nie.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 90.0),
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
                        onTap: () async {
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => JobcardFormPage(jobcard: job),
                            ),
                          );
                          if (changed == true) {
                            await JobcardService.fetchJobs();
                          }
                        },
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Wag':
        return Colors.orange;
      case 'Oop':
        return Colors.blue;
      case 'Geskeduleer':
        return Colors.teal;
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

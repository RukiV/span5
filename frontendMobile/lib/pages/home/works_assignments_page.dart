import 'package:flutter/material.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../core/status_colors.dart';
import '../../models/user_session.dart';
import '../../services/jobcard_service.dart';
import '../../services/campus_service.dart';
import '../../models/jobcard.dart';
import '../../widgets/selection_manager.dart';
import '../jobcards/jobcard_detail_page.dart';
import '../jobcards/jobcard_form_page.dart';

class WorksAssignmentsPage extends StatefulWidget {
  const WorksAssignmentsPage({super.key});

  @override
  State<WorksAssignmentsPage> createState() => _WorksAssignmentsPageState();
}

class _WorksAssignmentsPageState extends State<WorksAssignmentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  final SelectionController<int> _selection = SelectionController<int>();
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

  bool get _canManage => UserSession.can('jobs.manage');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_canManage)
            BulkDeleteFloatingAction<int>(
              controller: _selection,
              confirmTitle: 'Verwyder Werksopdragte',
              confirmMessage:
                  'Wil jy ${_selection.count} geselekteerde werksopdrag(te) verwyder?',
              onDelete: _bulkDeleteJobs,
            ),
          if (_canManage) const SizedBox(height: 12),
          FloatingActionButton.extended(
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
            label: const Text("Nuwe Werksopdrag",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
          ),
        ],
      ),
      body: Column(
        children: [
          FixedPageHeader(
            controller: _searchController,
            hintText: "Soek werksopdragte...",
            onChanged: (_) => setState(() {}),
            actions: [
              if (_canManage)
                SelectionExitAction<int>(
                  controller: _selection,
                  onExit: () => setState(() => _selection.exit()),
                ),
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
            ],
          ),
          Expanded(
            child: ValueListenableBuilder<List<Jobcard>>(
              valueListenable: JobcardService.jobcardsNotifier,
              builder: (context, jobcards, child) {
                final filtered = jobcards.where((job) {
                  if (_selectedCampusId != null &&
                      job.locationId != _selectedCampusId) {
                    return false;
                  }
                  if (_selectedBuildingId != null &&
                      job.buildingId != _selectedBuildingId) {
                    return false;
                  }
                  if (_selectedRoomId != null &&
                      job.roomId != _selectedRoomId) {
                    return false;
                  }
                  if (_query.isNotEmpty &&
                      !job.description.toLowerCase().contains(_query) &&
                      !(job.type?.toLowerCase().contains(_query) ?? false) &&
                      !job.status.toLowerCase().contains(_query)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => JobcardService.fetchJobs(),
                    color: AppColors.refreshSpinner,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.3),
                        const Center(
                          child: Text(
                            "Geen werksopdragte beskikbaar nie.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => JobcardService.fetchJobs(),
                  color: AppColors.refreshSpinner,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 90.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final job = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        color: _selection.isSelected(job.id)
                            ? AppColors.lavender
                            : null,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
leading: _selection.isSelecting
                              ? Checkbox(
                                  value: _selection.isSelected(job.id),
                                  onChanged: (_) => setState(
                                      () => _selection.toggle(job.id)),
                                )
                              : CircleAvatar(
                                  backgroundColor:
                                      jobStatusColor(job.status)
                                          .withValues(alpha: 0.2),
                                  child: Icon(Icons.assignment,
                                      color: jobStatusColor(job.status)),
                                ),
                          title: Text(
                            job.description,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (job.type != null)
                                Text(job.type!,
                                    style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              _buildStatusBadge(job.status),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.gold),
                          onTap: () async {
                            if (_selection.isSelecting) {
                              setState(() => _selection.toggle(job.id));
                              return;
                            }
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    JobcardDetailPage(job: job),
                              ),
                            );
                            if (changed == true) {
                              await JobcardService.fetchJobs();
                            }
                          },
                          onLongPress: () {
                            if (!_canManage) return;
                            setState(() {
                              _selection.enter();
                              _selection.toggle(job.id);
                            });
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = jobStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _bulkDeleteJobs(BuildContext context, Set<int> ids) async {
    int ok = 0;
    int fail = 0;
    for (final id in ids) {
      try {
        if (await JobcardService.deleteJob(id)) {
          ok++;
        } else {
          fail++;
        }
      } catch (e) {
        fail++;
      }
    }
    await JobcardService.fetchJobs();
    if (context.mounted) {
      setState(() => _selection.exit());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fail == 0
              ? "$ok werksopdrag(te) verwyder."
              : "$ok verwyder, $fail kon nie verwyder word nie."),
          backgroundColor:
              fail == 0 ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }
}

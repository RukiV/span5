import 'package:flutter/material.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/filter_utils.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../core/status_colors.dart';
import '../../models/user_session.dart';
import '../../services/jobcard_service.dart';
import '../../services/campus_service.dart';
import '../../models/jobcard.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/sort_button.dart';
import '../../widgets/column_visibility.dart';
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
  String _columnFilter = 'all';
  final MultiSortController _sortCtrl =
      MultiSortController('works-assignments', ['description', 'type', 'status']);
  final SelectionController<int> _selection = SelectionController<int>();
  final ColumnVisibilityController _colVis =
      ColumnVisibilityController('works-assignments', [
    const ColumnDef(key: 'description', label: 'Beskrywing'),
    const ColumnDef(key: 'type', label: 'Tipe', defaultVisible: false),
    const ColumnDef(key: 'status', label: 'Status'),
  ]);
  int? _selectedCampusId;
  int? _selectedBuildingId;
  int? _selectedRoomId;
  bool _filterOpen = false;
  bool _sortOpen = false;
  final FilterController _filterCtrl = FilterController('works-assignments');

  @override
  void initState() {
    super.initState();
    _sortCtrl.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _filterCtrl.initialize().then((_) {
      if (!mounted) return;
      _selectedCampusId = _filterCtrl.campusId;
      _selectedBuildingId = _filterCtrl.buildingId;
      _selectedRoomId = _filterCtrl.roomId;
      _searchController.text = _filterCtrl.search;
      _columnFilter = _filterCtrl.columnKey;
      setState(() {});
    });
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _searchController.addListener(() {
      _filterCtrl.setSearch(_searchController.text);
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
              FilterButton(
                controller: _filterCtrl,
                selected: _filterOpen,
                onPressed: () => setState(() {
                  _filterOpen = !_filterOpen;
                  _sortOpen = false;
                }),
              ),
              SortButton(
                controller: _sortCtrl,
                selected: _sortOpen,
                onPressed: () => setState(() {
                  _sortOpen = !_sortOpen;
                  _filterOpen = false;
                }),
              ),
              ColumnVisibilityButton(controller: _colVis, iconOnly: true),
            ],
          ),
          if (_filterOpen)
            FilterPanel(
              controller: _filterCtrl,
              depth: LocationDepth.room,
              searchController: _searchController,
              searchHint: "Soek werksopdragte...",
              initialCampusId: _selectedCampusId,
              initialBuildingId: _selectedBuildingId,
              initialRoomId: _selectedRoomId,
              onLocationChanged: (campusId, buildingId, roomId) =>
                  setState(() {
                _selectedCampusId = campusId;
                _selectedBuildingId = buildingId;
                _selectedRoomId = roomId;
              }),
              columnItems: [
                const SearchableDropdownItem(
                    value: 'all', label: 'Alle kolomme'),
                ..._colVis.allColumns.map((c) => SearchableDropdownItem(
                    value: c.key, label: c.label)),
              ],
              columnValue: _columnFilter,
              onColumnChanged: (v) => setState(() => _columnFilter = v),
              onReset: () => setState(() {
                _selectedCampusId = null;
                _selectedBuildingId = null;
                _selectedRoomId = null;
                _columnFilter = 'all';
              }),
              onClose: () => setState(() => _filterOpen = false),
            ),
          if (_sortOpen)
            SortPanel(
              controller: _sortCtrl,
              columns: _colVis.allColumns,
              onChanged: () => setState(() {}),
            ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closePanels,
              child: ValueListenableBuilder<List<Jobcard>>(
              valueListenable: JobcardService.jobcardsNotifier,
              builder: (context, jobcards, child) {
final filtered = _sortCtrl.apply(
              jobcards.where((job) {
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
                if (_query.isNotEmpty) {
                  final searchable = _columnFilter == 'all'
                      ? [
                          job.description,
                          job.type ?? '',
                          job.status,
                          job.id.toString(),
                          job.fullDescription,
                        ].join(' ')
                      : switch (_columnFilter) {
                          'description' => job.description,
                          'type' => job.type ?? '',
                          'status' => job.status,
                          _ => '',
                        };
                  if (!searchable.toLowerCase().contains(_query)) {
                    return false;
                  }
                }
                return true;
              }).toList(),
              (job, key) {
                switch (key) {
                  case 'description':
                    return job.description.toLowerCase();
                  case 'type':
                    return (job.type ?? '').toLowerCase();
                  case 'status':
                    return job.status.toLowerCase();
                  default:
                    return '';
                }
              },
            );

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
                                  backgroundColor: jobStatusColor(job.status)
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

);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _closePanels() {
    if (_filterOpen || _sortOpen) {
      setState(() {
        _filterOpen = false;
        _sortOpen = false;
      });
    }
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
}
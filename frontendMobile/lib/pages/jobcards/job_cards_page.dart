import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/jobcard_service.dart';
import '../../models/jobcard.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';

class JobCardsPage extends StatefulWidget {
  const JobCardsPage({super.key});

  @override
  State<JobCardsPage> createState() => _JobCardsPageState();
}

class _JobCardsPageState extends State<JobCardsPage> {
  final TextEditingController _searchController = TextEditingController();
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('jobcards', [
    const ColumnDef(key: 'id', label: 'ID'),
    const ColumnDef(key: 'description', label: 'Beskrywing'),
    const ColumnDef(key: 'type', label: 'Tipe', defaultVisible: false),
    const ColumnDef(key: 'status', label: 'Status'),
    const ColumnDef(key: 'date', label: 'Datum', defaultVisible: false),
  ]);
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    JobcardService.fetchJobs();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<List<Jobcard>>(
        valueListenable: JobcardService.jobcardsNotifier,
        builder: (context, jobcards, child) {
          final activeJobs = jobcards.where((j) =>
              j.status == "Besig" ||
              j.status == "Voltooi" ||
              j.status == "Oop" ||
              j.status == "Wag").toList();

          final filtered = activeJobs.where((j) {
            if (_searchQuery.isEmpty) return true;
            return j.description.toLowerCase().contains(_searchQuery) ||
                j.id.toString().contains(_searchQuery) ||
                (j.type?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();

          if (_sortCtrl.isActive) {
            filtered.sort((a, b) {
              final dir = _sortCtrl.direction;
              switch (_sortCtrl.sortKey) {
                case 'id':
                  return a.id.compareTo(b.id) * dir;
                case 'description':
                  return a.description.toLowerCase().compareTo(b.description.toLowerCase()) * dir;
                case 'type':
                  return (a.type ?? '').toLowerCase().compareTo((b.type ?? '').toLowerCase()) * dir;
                case 'status':
                  return a.status.toLowerCase().compareTo(b.status.toLowerCase()) * dir;
                case 'date':
                  return (a.createdDatetime ?? DateTime(0)).compareTo(b.createdDatetime ?? DateTime(0)) * dir;
                default:
                  return 0;
              }
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => JobcardService.fetchJobs(),
                  color: AppColors.gold,
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                            _buildEmptyState(),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final job = filtered[index];
                            return _buildJobCard(job);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Soek werkkaarte...",
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 150 / 255), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                fillColor: Colors.white.withValues(alpha: 30 / 255),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ColumnVisibilityButton(controller: _colVis),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? "Geen werkkaarte gevind nie"
                  : "Geen aktiewe werkkaarte nie",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => JobcardService.fetchJobs(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
              ),
              child: const Text("Herlaai"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(Jobcard job) {
    bool isCompleted = job.status == "Voltooi";
    Color statusColor = _getStatusColor(job.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "#${job.id}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    job.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job.description,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            if (job.type != null) ...[
              const SizedBox(height: 4),
              Text(job.type!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
            if (job.createdDatetime != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("Geskep: ${_formatDate(job.createdDatetime!)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip(job.status),
                if (!isCompleted)
                  ElevatedButton(
                    onPressed: () => _markAsCompleted(job),
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
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = _getStatusColor(status);
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
            status.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Besig':
        return Colors.blue;
      case 'Voltooi':
        return Colors.green;
      case 'Oop':
        return Colors.orange;
      case 'Wag':
        return Colors.amber;
      case 'Gekanselleer':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Future<void> _markAsCompleted(Jobcard job) async {
    final success = await JobcardService.updateJobStatus(job.id, "Voltooi");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Werkkaart suksesvol opgedateer" : "Kon nie status opdateer nie"),
          backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }
}

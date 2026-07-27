import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/campus_service.dart';
import '../../models/report.dart';
import '../../models/user_session.dart';
import 'new_report_page.dart';
import 'report_detail_page.dart';

class ReportingPage extends StatefulWidget {
  const ReportingPage({super.key});

  @override
  State<ReportingPage> createState() => _ReportingPageState();
}

class _ReportingPageState extends State<ReportingPage> {
  String _searchQuery = "";
  String _statusFilter = "Alles";
  int? _selectedCampusId;
  int? _selectedBuildingId;

  @override
  void initState() {
    super.initState();
    ReportService.fetchReports();
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
    return ValueListenableBuilder<List<Report>>(
      valueListenable: ReportService.reportsNotifier,
      builder: (context, allReports, child) {
        // SOEK EN FILTRERING
        List<Report> filtered = allReports.where((r) {
          final matchesSearch = _searchQuery.isEmpty || 
              r.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.location.toLowerCase().contains(_searchQuery.toLowerCase());

          final matchesStatus = _statusFilter == "Alles" || (r.phase == _statusFilter);

          final matchesCampus = _selectedCampusId == null || r.locationId == _selectedCampusId;
          final matchesBuilding = _selectedBuildingId == null || r.buildingId == _selectedBuildingId;

          return matchesSearch && matchesStatus && matchesCampus && matchesBuilding;
        }).toList();

        // Sortering (Nuutste bo)
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildSearchBarWithFilter(),
              _buildCampusFilter(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ReportService.fetchReports(),
                  child: _buildReportList(context, filtered),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.gold,
            elevation: 4,
            icon: const Icon(Icons.add_a_photo, color: Colors.white),
            label: const Text("Nuwe Foutkaartjie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: () => _handleNewReport(context),
          ),
        );
      },
    );
  }

  Widget _buildCampusFilter() {
    final campuses = CampusService.campusesNotifier.value;
    if (campuses.isEmpty) return const SizedBox.shrink();

    final selectedCampus = _selectedCampusId != null
        ? campuses.where((c) => c.id == _selectedCampusId).firstOrNull
        : null;
    final buildings = selectedCampus?.buildings ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _selectedCampusId,
                hint: const Text("Kies Terrein", style: TextStyle(fontSize: 13)),
                items: campuses.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (val) => setState(() {
                  _selectedCampusId = val;
                  _selectedBuildingId = null;
                }),
              ),
            ),
          ),
        ),
        if (_selectedCampusId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedBuildingId,
                  hint: const Text("Kies Gebou", style: TextStyle(fontSize: 13)),
                  items: buildings.map((b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(b.name, style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedBuildingId = val),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBarWithFilter() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Soek verslae...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 150/255), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                fillColor: Colors.white.withValues(alpha: 30/255),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 30/255),
              borderRadius: BorderRadius.circular(30),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: AppColors.navy,
                icon: const Icon(Icons.filter_list, color: AppColors.gold),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                items: ["Alles", "Ontvang", "Besig", "Voltooi", "Geweier"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _statusFilter = val!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(BuildContext context, List<Report> reports) {
    if (reports.isEmpty) {
      return const Center(child: Text("Geen foutkaartjies gevind nie.", style: TextStyle(color: Colors.grey)));
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          color: AppColors.gold,
          child: const Row(
            children: [
              Expanded(flex: 1, child: Text("ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 3, child: Text("Beskrywing", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text("Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = reports[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ReportDetailPage(report: r)),
                  );
                },
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text("#${r.id}", style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(r.location, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildStatusChip(r.phase),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    switch (status) {
      case 'Ontvang': color = AppColors.infoBlue; break;
      case 'Besig': color = AppColors.warningOrange; break;
      case 'Voltooi': color = AppColors.successGreen; break;
      case 'Geweier': color = AppColors.errorRed; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // _buildStatusText verwyder aangesien ons nou die herbruikbare StatusBadge widget gebruik

  void _handleNewReport(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewReportPage()),
    );
    // Data word nou binne NewReportPage gestoor via ReportService.addReport
  }
}

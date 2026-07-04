<<<<<<< HEAD
import '../../widgets/status_badge.dart';
import 'package:flutter/material.dart';
import '../../models/user_session.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../models/report.dart';
import 'new_report_page.dart';
import 'report_detail_page.dart';

class ReportingPage extends StatefulWidget {
  const ReportingPage({super.key});

  @override
  State<ReportingPage> createState() => _ReportingPageState();
}

class _ReportingPageState extends State<ReportingPage> {
  String _searchQuery = "";
  final String _priorityFilter = "Alles";

  @override
  void initState() {
    super.initState();
    // Laai vars data van die backend af wanneer die bladsy oopmaak
    ReportService.fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Report>>(
      valueListenable: ReportService.reportsNotifier,
      builder: (context, allReports, child) {
        // FILTER LOGIKA
        List<Report> filtered = allReports.where((r) {
          final matchesSearch = _searchQuery.isEmpty || 
              r.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.location.toLowerCase().contains(_searchQuery.toLowerCase());
          
          final matchesPriority = _priorityFilter == "Alles" || 
              (r.priority == _priorityFilter);
          
          return matchesSearch && matchesPriority;
        }).toList();

        // Sortering
        if (_priorityFilter == "Hoog -> Laag") {
          filtered.sort((a, b) {
            int getPrioValue(String p) => p == "Hoog" ? 3 : (p == "Medium" ? 2 : 1);
            return getPrioValue(b.priority).compareTo(getPrioValue(a.priority));
          });
        } else if (_priorityFilter == "Laag -> Hoog") {
          filtered.sort((a, b) {
            int getPrioValue(String p) => p == "Hoog" ? 3 : (p == "Medium" ? 2 : 1);
            return getPrioValue(a.priority).compareTo(getPrioValue(b.priority));
          });
        } else {
          // Standaard: Nuutste bo
          filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }

        if (UserSession.hasAdminPrivileges) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  _buildSearchBar(),
                  Container(
                    color: AppColors.navy,
                    child: const TabBar(
                      indicatorColor: AppColors.gold,
                      indicatorWeight: 4,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.gold,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                      tabs: [
                        Tab(text: "NUWE AANVRAE"),
                        Tab(text: "IN VORDERING"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildReportList(context, filtered.where((r) => r.phase == 'Ontvang').toList()),
                        _buildReportList(context, filtered.where((r) => r.phase != 'Ontvang').toList()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              elevation: 4,
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text("Nuwe Verslag", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              onPressed: () => _handleNewReport(context),
            ),
          );
        }

        // Studente sien net hul eie lys (GEEN TABS)
        final studentReports = allReports.where((r) {
          // Vergelyk as strings om seker te maak dit match
          return r.user.toString() == UserSession.userId.toString();
        }).toList();
        
        final filteredStudentReports = studentReports.where((r) {
          final matchesSearch = _searchQuery.isEmpty || 
              r.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.location.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesSearch;
        }).toList();

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildReportList(context, filteredStudentReports)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.gold,
            elevation: 4,
            icon: const Icon(Icons.add_a_photo, color: Colors.white),
            label: const Text("Nuwe Verslag", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: () => _handleNewReport(context),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Soek verslae (Lokaal, ID of Titel)...",
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
    );
  }

  Widget _buildReportList(BuildContext context, List<Report> reports) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          color: AppColors.gold,
          child: const Row(
            children: [
              Expanded(flex: 1, child: Text("ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 3, child: Text("Asset Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
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
                        child: Text("#${r.id}", style: const TextStyle(color: Colors.black87)),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(r.location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: StatusBadge(status: r.phase, fontSize: 12),
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

  // _buildStatusText verwyder aangesien ons nou die herbruikbare StatusBadge widget gebruik

  void _handleNewReport(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewReportPage()),
    );
    // Data word nou binne NewReportPage gestoor via ReportService.addReport
  }
}
=======
import '../../core/campus_service.dart';
import '../../widgets/status_badge.dart';
import 'package:flutter/material.dart';
import '../../models/user_session.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../models/report.dart';
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
  final String _priorityFilter = "Alles";

  @override
  void initState() {
    super.initState();
    ReportService.fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Report>>(
      valueListenable: ReportService.reportsNotifier,
      builder: (context, allReports, child) {
        // ROL-GEBASEERDE DATA FILTRERING
        List<Report> baseReports = allReports;
        if (UserSession.isManager) {
          baseReports = allReports.where((r) {
            final reportCampus = CampusService.getCampusNameByRoomId(r.location);
            return reportCampus == UserSession.userCampus;
          }).toList();
        } else if (UserSession.isStudent) {
          baseReports = allReports.where((r) => r.user.toString() == UserSession.userId.toString()).toList();
        }

        // SOEK EN FILTRERING
        List<Report> filtered = baseReports.where((r) {
          final matchesSearch = _searchQuery.isEmpty || 
              r.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.location.toLowerCase().contains(_searchQuery.toLowerCase());
          
          final matchesStatus = _statusFilter == "Alles" || (r.phase == _statusFilter);
          
          return matchesSearch && matchesStatus;
        }).toList();

        // Sortering (Nuutste bo)
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildSearchBarWithFilter(),
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
            label: const Text("Rapporteer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: () => _handleNewReport(context),
          ),
        );
      },
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
                items: ["Alles", "Wag", "Oop", "Bevestig", "Besig", "Opgelos", "Verwerp"]
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
      case 'Wag': color = Colors.blue; break;
      case 'Oop': color = Colors.orange; break;
      case 'Bevestig': color = Colors.purple; break;
      case 'Besig': color = Colors.blueAccent; break;
      case 'Opgelos': color = Colors.green; break;
      case 'Verwerp': color = Colors.red; break;
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
>>>>>>> 3080162a6b51675de2ce74fa53f3bd629f39db17

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

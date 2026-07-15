import 'package:flutter/material.dart';
import '../reporting/reporting_page.dart';
import '../asset/asset_page.dart';
import '../stock/stock_page.dart';
import '../campus/campus_management_page.dart';
import '../rooms/manage_rooms_page.dart';
import '../building/buildings_list_page.dart';
import '../contractor/contractor_management_page.dart';
import '../contractor/job_cards_page.dart';
import 'dashboard_page.dart';
import 'calendar_page.dart';
import 'works_assignments_page.dart';
import '../../models/user_session.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../services/report_service.dart';
import '../../services/contractor_service.dart';
import '../../services/quote_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedTitle = "Paneelbord";
  final Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _initialDataSync();
  }

  Future<void> _initialDataSync() async {
    try {
      await Future.wait([
        CampusService.fetchCampuses(),
        AssetService.fetchAssets(),
        ReportService.fetchReports(),
        ContractorService.fetchContractors(),
        QuoteService.fetchQuotes(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kon nie data vanaf die bediener sinkroniseer nie."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getVisibleMenu() {
    // 1. STUDENTE: Slegs foutkaartjies
    if (UserSession.isStudent) {
      return [
        {
          'title': 'Foutkaartjies',
          'icon': Icons.report_gmailerrorred_outlined,
          'page': const ReportingPage(),
        }
      ];
    }

    // 2. KONTRAKTEURS: Slegs take en kalender
    if (UserSession.isContractor) {
      return [
        {
          'title': 'Werksopdragte',
          'icon': Icons.engineering_outlined,
          'page': const JobCardsPage(),
        },
        {
          'title': 'Kalender',
          'icon': Icons.calendar_today_outlined,
          'page': const CalendarPage(),
        },
      ];
    }

    // 3. ADMIN & BESTUURDERS: Volle navigasie
    if (UserSession.isAdmin || UserSession.isManager) {
      return [
        {
          'title': 'Paneelbord',
          'icon': Icons.dashboard_outlined,
          'page': DashboardPage(onTabRequested: (index) {
            final titles = [
              "Paneelbord", "Bates", "Voorraad", "Terreine", "Geboue", "Lokale", 
              "Foutkaartjies", "Kontrakteurs", "Werksopdragte", "Kalender"
            ];
            if (index >= 0 && index < titles.length) {
              setState(() => _selectedTitle = titles[index]);
            }
          }),
        },
        {
          'title': 'Bates & Voorraad',
          'icon': Icons.inventory_2_outlined,
          'isExpandable': true,
          'children': [
            {
              'title': 'Bates',
              'icon': Icons.inventory_2_outlined,
              'page': const AssetsPage(),
            },
            {
              'title': 'Voorraad',
              'icon': Icons.construction_outlined,
              'page': const StockPage(),
            },
          ],
        },
        {
          'title': 'Lokale & Terreine',
          'icon': Icons.map_outlined,
          'isExpandable': true,
          'children': [
            {
              'title': 'Terreine',
              'icon': Icons.map_outlined,
              'page': const CampusManagementPage(),
            },
            {
              'title': 'Geboue',
              'icon': Icons.business_outlined,
              'page': const BuildingsListPage(),
            },
            {
              'title': 'Lokale',
              'icon': Icons.room_outlined,
              'page': const ManageRoomsPage(),
            },
          ],
        },
        {
          'title': 'Foutkaartjies',
          'icon': Icons.report_gmailerrorred_outlined,
          'page': const ReportingPage(),
        },
        {
          'title': 'Kontrakteurs',
          'icon': Icons.engineering_outlined,
          'page': const ContractorManagementPage(),
        },
        {
          'title': 'Werksopdragte',
          'icon': Icons.assignment_outlined,
          'page': const WorksAssignmentsPage(),
        },
        {
          'title': 'Kalender',
          'icon': Icons.calendar_today_outlined,
          'page': const CalendarPage(),
        },
      ];
    }

    return []; // Beveiliging as geen rol pas nie
  }

  List<Map<String, dynamic>> _getFlatMenu() {
    final menu = _getVisibleMenu();
    final List<Map<String, dynamic>> flat = [];
    for (var item in menu) {
      if (item['isExpandable'] == true) {
        for (var child in item['children']) {
          flat.add(child);
        }
      } else {
        flat.add(item);
      }
    }
    return flat;
  }

  @override
  Widget build(BuildContext context) {
    final flatMenu = _getFlatMenu();
    final activeItem = flatMenu.firstWhere(
      (item) => item['title'] == _selectedTitle,
      orElse: () => flatMenu.first,
    );

    String roleTitle = "";
    if (UserSession.isAdmin) {
      roleTitle = "Admin Mode";
    } else if (UserSession.isManager) {
      roleTitle = "Bestuurder: ${UserSession.userCampus}";
    } else if (UserSession.isContractor) {
      roleTitle = "Kontrakteur";
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
            "FBS - ${activeItem['title']}",
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.white)
        ),
        centerTitle: false,
        actions: [
          if (roleTitle.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Text(roleTitle, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: Column(
          children: [
            const DrawerHeader(
              child: Center(
                child: Text(
                    "FBS",
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: _getVisibleMenu().map((item) {
                  if (item['isExpandable'] == true) {
                    return _buildExpandableItem(item);
                  }
                  return _drawerItem(item['icon'], item['title']);
                }).toList(),
              ),
            ),

            const Divider(color: Colors.white24),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Teken Uit", style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await ApiClient().clearToken();
                UserSession.clear();
                if (!mounted) return;
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      body: activeItem['page'],
    );
  }

  Widget _buildExpandableItem(Map<String, dynamic> item) {
    bool isExpanded = _expandedStates[item['title']] ?? false;
    bool containsSelected = (item['children'] as List).any((child) => child['title'] == _selectedTitle);
    
    return Column(
      children: [
        ListTile(
          leading: Icon(item['icon'], color: containsSelected ? AppColors.gold : Colors.white70),
          title: Text(item['title'], 
            style: TextStyle(color: containsSelected ? AppColors.gold : Colors.white, fontWeight: containsSelected ? FontWeight.bold : FontWeight.normal)),
          trailing: Icon(
            isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
            color: Colors.white54,
          ),
          onTap: () {
            setState(() {
              _expandedStates[item['title']] = !isExpanded;
            });
          },
        ),
        if (isExpanded)
          ...item['children'].map<Widget>((child) {
            return _drawerItem(child['icon'], child['title'], isSubItem: true);
          }).toList(),
      ],
    );
  }

  Widget _drawerItem(IconData icon, String title, {bool isSubItem = false}) {
    bool isSelected = _selectedTitle == title;

    return ListTile(
      contentPadding: EdgeInsets.only(left: isSubItem ? 40.0 : 16.0),
      // Verwyder die background highlight soos versoek
      selected: false, 
      leading: Icon(
          icon,
          color: isSelected ? AppColors.gold : (isSubItem ? Colors.white54 : Colors.white70),
          size: isSubItem ? 20 : 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.gold : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: isSubItem ? 14 : 16,
        ),
      ),
      onTap: () {
        setState(() => _selectedTitle = title);
        Navigator.pop(context);
      },
    );
  }
}

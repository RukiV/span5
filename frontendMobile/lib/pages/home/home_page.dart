import 'package:flutter/material.dart';
import '../reporting/reporting_page.dart';
import '../assets/assets_page.dart';
import '../assets/stock_page.dart';
import '../admin/campus_management_page.dart';
import '../admin/manage_rooms_page.dart';
import '../admin/buildings_list_page.dart';
import '../admin/contractor_management_page.dart';
import '../contractor/job_cards_page.dart';
import 'dashboard_page.dart';
import 'calendar_page.dart';
import 'works_assignments_page.dart';
import 'reports_page.dart';
import '../../models/user_session.dart';
import '../../core/app_colors.dart';

import '../../core/api_client.dart';
import '../../core/asset_service.dart';
import '../../core/campus_service.dart';
import '../../core/report_service.dart';
import '../../core/contractor_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialDataSync();
  }

  Future<void> _initialDataSync() async {
    try {
      // Laai data van die backend af wanneer die app oopmaak
      await Future.wait([
        CampusService.fetchCampuses(),
        AssetService.fetchAssets(),
        ReportService.fetchReports(),
        ContractorService.fetchContractors(),
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

  // Bereken die beskikbare items op grond van rol
  List<Map<String, dynamic>> _getVisibleMenu() {
    if (UserSession.isStudent) {
      return [
        {
          'title': 'Foutkaartjies',
          'icon': Icons.report_gmailerrorred_outlined,
          'page': const ReportingPage(),
        }
      ];
    }

    return [
      {
        'title': 'Paneelbord',
        'icon': Icons.dashboard_outlined,
        'page': DashboardPage(onTabRequested: (index) {
          setState(() => _selectedIndex = index);
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
      if (UserSession.hasAdminPrivileges)
        {
          'title': 'Kontrakteurs',
          'icon': Icons.engineering_outlined,
          'page': const ContractorManagementPage(),
        }
      else if (UserSession.isContractor)
        {
          'title': 'Kontrakteurs',
          'icon': Icons.engineering_outlined,
          'page': const JobCardsPage(),
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
      {
        'title': 'Verslae',
        'icon': Icons.analytics_outlined,
        'page': const ReportsPage(),
      },
    ];
  }

  // Ons stoor watter dropdowns oop is
  final Map<String, bool> _expandedStates = {};

  @override
  Widget build(BuildContext context) {
    final menu = _getVisibleMenu();

    // Lys van alle plat items (insluitend kinders as hulle oop is)
    final List<Map<String, dynamic>> flatMenu = [];
    final List<int> parentIndices = [];

    for (var item in menu) {
      flatMenu.add(item);
      parentIndices.add(flatMenu.length - 1);
      
      if (item['isExpandable'] == true && (_expandedStates[item['title']] ?? false)) {
        for (var child in item['children']) {
          var childCopy = Map<String, dynamic>.from(child);
          childCopy['isSubItem'] = true;
          flatMenu.add(childCopy);
        }
      }
    }
    
    if (_selectedIndex >= flatMenu.length) {
      _selectedIndex = 0;
    }

    String roleTitle = "";
    if (UserSession.isAdmin) {
      roleTitle = "Admin Mode";
    } else if (UserSession.isManager) roleTitle = "Bestuurder: ${UserSession.userCampus}";
    else if (UserSession.isContractor) roleTitle = "Kontrakteur";

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
            "FBS - ${flatMenu[_selectedIndex]['title']}",
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
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: menu.length,
                itemBuilder: (context, index) {
                  final item = menu[index];
                  if (item['isExpandable'] == true) {
                    return _buildExpandableItem(item);
                  }
                  return _drawerItem(
                    item['icon'], 
                    item['title'], 
                    _getFlatIndex(flatMenu, item['title']),
                  );
                },
              ),
            ),

            const Divider(color: Colors.white24),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Teken Uit", style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await ApiClient().clearToken();
                UserSession.clear();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      body: flatMenu[_selectedIndex]['page'],
    );
  }

  int _getFlatIndex(List<Map<String, dynamic>> flatMenu, String title) {
    return flatMenu.indexWhere((element) => element['title'] == title);
  }

  Widget _buildExpandableItem(Map<String, dynamic> item) {
    bool isExpanded = _expandedStates[item['title']] ?? false;
    
    return Column(
      children: [
        ListTile(
          leading: Icon(item['icon'], color: Colors.white70),
          title: Text(item['title'], style: const TextStyle(color: Colors.white)),
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
            final flatMenu = _getFlatMenu();
            int idx = flatMenu.indexWhere((e) => e['title'] == child['title']);
            return _drawerItem(child['icon'], child['title'], idx, isSubItem: true);
          }).toList(),
      ],
    );
  }

  List<Map<String, dynamic>> _getFlatMenu() {
    final menu = _getVisibleMenu();
    final List<Map<String, dynamic>> flatMenu = [];
    for (var item in menu) {
      flatMenu.add(item);
      if (item['isExpandable'] == true && (_expandedStates[item['title']] ?? false)) {
        for (var child in item['children']) {
          var childCopy = Map<String, dynamic>.from(child);
          childCopy['isSubItem'] = true;
          flatMenu.add(childCopy);
        }
      }
    }
    return flatMenu;
  }

  // Helper om spyskaart items te bou met die regte kleure
  Widget _drawerItem(IconData icon, String title, int index, {bool isSubItem = false}) {
    bool isSelected = _selectedIndex == index;

    return ListTile(
      contentPadding: EdgeInsets.only(left: isSubItem ? 40.0 : 16.0),
      selected: isSelected,
      selectedTileColor: AppColors.gold.withValues(alpha: 0.2),
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
        setState(() => _selectedIndex = index);
        Navigator.pop(context); // Maak drawer toe
      },
    );
  }

}
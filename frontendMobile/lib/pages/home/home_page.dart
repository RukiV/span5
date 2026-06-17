import 'package:flutter/material.dart';
import '../reporting/reporting_page.dart';
import '../assets/assets_page.dart';
import '../assets/stock_page.dart';
import '../admin/campus_management_page.dart';
import '../admin/manage_rooms_page.dart';
import '../contractor/job_cards_page.dart';
import 'dashboard_page.dart';
import '../../models/user_session.dart';
import '../../core/app_colors.dart';

import '../../core/asset_service.dart';
import '../../core/campus_service.dart';
import '../../core/report_service.dart';

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
    final List<Map<String, dynamic>> allItems = [
      {
        'title': 'Paneelbord',
        'icon': Icons.dashboard_outlined,
        'page': const DashboardPage(),
        'roles': [UserRole.admin, UserRole.manager]
      },
      {
        'title': 'Werkkaarte',
        'icon': Icons.assignment_outlined,
        'page': const JobCardsPage(),
        'roles': [UserRole.contractor]
      },
      {
        'title': 'Rapportering',
        'icon': Icons.report_gmailerrorred_outlined,
        'page': const ReportingPage(),
        'roles': [UserRole.admin, UserRole.manager, UserRole.student]
      },
      {
        'title': 'Bate',
        'icon': Icons.inventory_2_outlined,
        'page': const AssetsPage(),
        'roles': [UserRole.admin, UserRole.manager]
      },
      {
        'title': 'Toerusting',
        'icon': Icons.construction_outlined,
        'page': const StockPage(),
        'roles': [UserRole.admin, UserRole.manager],
        'isSubItem': true
      },
      {
        'title': 'Lokaal',
        'icon': Icons.room_outlined,
        'page': const ManageRoomsPage(),
        'roles': [UserRole.admin, UserRole.manager]
      },
      {
        'title': 'Kampus',
        'icon': Icons.map_outlined,
        'page': const CampusManagementPage(),
        'roles': [UserRole.admin, UserRole.manager]
      },
    ];

    return allItems.where((item) => (item['roles'] as List<UserRole>).contains(UserSession.role)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final menu = _getVisibleMenu();
    
    if (_selectedIndex >= menu.length) {
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
            "FBS - ${menu[_selectedIndex]['title']}",
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

            // Genereer slegs die toegelate menu items
            ...List.generate(menu.length, (index) {
              return _drawerItem(
                menu[index]['icon'], 
                menu[index]['title'], 
                index,
                isSubItem: menu[index]['isSubItem'] ?? false
              );
            }),

            const Spacer(),

            const Divider(color: Colors.white24),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Teken Uit", style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                UserSession.role = UserRole.student;
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      body: menu[_selectedIndex]['page'],
    );
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
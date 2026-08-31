<<<<<<< HEAD
import 'package:flutter/material.dart';

import '../reporting/reporting_page.dart';
import '../asset/asset_page.dart';
import '../stock/stock_page.dart';
import '../campus/campus_management_page.dart';
import '../rooms/manage_rooms_page.dart';
import '../building/buildings_list_page.dart';
import '../jobcards/job_cards_page.dart';
import 'dashboard_page.dart';
import 'calendar_page.dart';
import 'works_assignments_page.dart';
import '../users/users_page.dart';
import '../notifications/notification_list_page.dart';
import '../../models/user_session.dart';
import '../../services/notification_service.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../services/report_service.dart';
import '../../services/quote_service.dart';
import '../../services/jobcard_service.dart';
import '../../services/outlook_token_manager.dart';
import '../room_checklist/room_check_session_page.dart';

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
    NotificationService.startPolling();
  }

  @override
  void dispose() {
    NotificationService.stopPolling();
    super.dispose();
  }

  Future<void> _initialDataSync() async {
    try {
      await Future.wait([
        CampusService.fetchCampuses(),
        AssetService.fetchAssets(),
        ReportService.fetchReports(),
        JobcardService.fetchJobs(),
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

  // Bou die sigbare menu deur elke inskrywing te filter op die gebruiker se
  // regte (UserSession.rights vanaf /auth/me), NIE meer op die rol-enum nie. So
  // bepaal 'n permissie-verandering aan die agterkant onmiddellik wat sigbaar
  // is, sonder 'n app-herbou. Die enum bly slegs vir vertoon (bv. roleTitle).
  List<Map<String, dynamic>> _getVisibleMenu() {
    bool can(String right) => UserSession.can(right);

    final List<Map<String, dynamic>> menu = [];

    // Paneelbord — personeel-oorsig (Admin/FK). Gegrond op 'n bestuursreg wat
    // hulle deel; studente/kontrakteurs het nie een van hierdie nie.
    if (can('assets.manage') || can('stock.manage') || can('jobs.manage')) {
      menu.add({
        'title': 'Paneelbord',
        'icon': Icons.dashboard_outlined,
        // Die paneelbord se statistiek-kaarte vra 'n bladsy aan op naam. Vroeër
        // was dit 'n indeks in 'n hardgekodeerde lys, wat stilweg verkeerd
        // geloop het sodra 'n gebruiker nie al die regte gehad het nie.
        'page': DashboardPage(onTabRequested: (title) {
          if (_getFlatMenu().any((item) => item['title'] == title)) {
            setState(() => _selectedTitle = title);
          }
        }),
      });
    }

    // Kontrole Skedules — FK/Admin bestuur skedules; Dosent sien eie.
    if (can('room_checks.manage')) {
      menu.add({
        'title': 'Kontrole Skedules',
        'icon': Icons.event_available_outlined,
        'page': const RoomCheckSessionPage(manageMode: true),
      });
    } else if (can('roomchecks.execute')) {
      menu.add({
        'title': 'My Kontroles',
        'icon': Icons.event_available_outlined,
        'page': const RoomCheckSessionPage(manageMode: false),
      });
    }

    // Fasiliteite — bates, voorraad en die ligging-hiërargie onder een groep.
    final facilitiesChildren = <Map<String, dynamic>>[];
    if (can('assets.view')) {
      facilitiesChildren.add({'title': 'Bates', 'icon': Icons.inventory_2_outlined, 'page': const AssetsPage()});
    }
    if (can('stock.view')) {
      facilitiesChildren.add({'title': 'Voorraad', 'icon': Icons.construction_outlined, 'page': const StockPage()});
    }
    if (can('locations.view')) {
      facilitiesChildren.add({'title': 'Terreine', 'icon': Icons.map_outlined, 'page': const CampusManagementPage()});
    }
    if (can('buildings.view')) {
      facilitiesChildren.add({'title': 'Geboue', 'icon': Icons.business_outlined, 'page': const BuildingsListPage()});
    }
    if (can('rooms.view')) {
      facilitiesChildren.add({'title': 'Lokale', 'icon': Icons.room_outlined, 'page': const ManageRoomsPage()});
    }
    if (facilitiesChildren.isNotEmpty) {
      menu.add({
        'title': 'Fasiliteite',
        'icon': Icons.business_outlined,
        'isExpandable': true,
        'children': facilitiesChildren,
      });
    }

    // Foutkaartjies / Rapportering — Student (net eie kaartjies) en Admin/FK.
    if (can('faults.create') || can('faults.view_own') || can('faults.view')) {
      menu.add({'title': 'Foutkaartjies', 'icon': Icons.report_gmailerrorred_outlined, 'page': const ReportingPage()});
    }

    // AI Konsepte is nou 'n tab binne Foutkaartjies (sien ReportingPage).
    // Werksopdragte — Admin/FK sien alle take (WorksAssignmentsPage); kontrakteurs
    // sien net hul eie toegewysde take (JobCardsPage). 'n Gebruiker het net een
    // van hierdie regte, so net die toepaslike inskrywing verskyn.
    if (can('jobs.manage') || can('jobs.view')) {
      menu.add({'title': 'Werksopdragte', 'icon': Icons.assignment_outlined, 'page': const WorksAssignmentsPage()});
    } else if (can('jobs.view_own')) {
      menu.add({'title': 'Werksopdragte', 'icon': Icons.engineering_outlined, 'page': const JobCardsPage()});
    }

    // Kalender — Admin/FK/Kontrakteur (calendar.view).
    if (can('calendar.view')) {
      menu.add({'title': 'Kalender', 'icon': Icons.calendar_today_outlined, 'page': const CalendarPage()});
    }

    // Gebruikers — Admin slegs (users.manage), laaste item in die navigasie.
    if (can('users.manage')) {
      menu.add({'title': 'Gebruikers', 'icon': Icons.group_outlined, 'page': const UsersPage()});
    }

    return menu; // Kan leeg wees as geen reg pas nie (gebruiker moet weer aanmeld).
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

    // Verdediging: as die gebruiker geen regte het nie (bv. verouderde sessie),
    // vertoon 'n boodskap eerder as om op 'n leë lys te crash.
    if (flatMenu.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.navy, elevation: 0),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Geen toegang beskikbaar nie. Teken asseblief weer aan.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final activeItem = flatMenu.firstWhere(
      (item) => item['title'] == _selectedTitle,
      orElse: () => flatMenu.first,
    );

    String roleTitle = "";
    if (UserSession.isAdmin) {
      roleTitle = "Admin Mode";
    } else if (UserSession.isManager) {
      roleTitle = UserSession.userCampus.isEmpty
          ? "Bestuurder"
          : "Bestuurder: ${UserSession.userCampus}";
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
          if (UserSession.rights.contains('notifications.view'))
            ValueListenableBuilder<int>(
              valueListenable: NotificationService.unreadCountNotifier,
              builder: (context, count, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () async {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationListPage(),
                            ),
                          );
                        }
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
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
                await OutlookTokenManager.instance.signOut();
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
=======
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
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

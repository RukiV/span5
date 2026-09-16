import 'dart:async';

import 'package:flutter/material.dart';

import '../reporting/reporting_page.dart';
import '../asset/asset_page.dart';
import '../stock/stock_page.dart';
import '../campus/campus_management_page.dart';
import '../rooms/manage_rooms_page.dart';
import '../building/buildings_list_page.dart';
import '../jobcards/job_cards_page.dart';
import 'dashboard_page.dart';
import 'voorspellings_page.dart';
import 'works_assignments_page.dart';
import '../users/users_page.dart';
import '../notifications/notification_list_page.dart';
import '../../models/user_session.dart';
import '../../services/notification_service.dart';
import '../../widgets/count_badge.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../services/report_service.dart';
import '../../services/quote_service.dart';
import '../../services/jobcard_service.dart';
import '../../services/outlook_token_manager.dart';
import '../room_checklist/room_check_session_page.dart';
import '../settings/server_config_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedTitle = "Paneelbord";
  final Map<String, bool> _expandedStates = {};
  Campus? _pendingCampus;
  Building? _pendingBuilding;
  String? _pendingRoomId;

  /// Eenmalige filters wat die fasiliteite-bladse toepas na 'n intrek
  /// (Terreine › Geboue › Lokale › Bates). 'n Terug-pyltjie bly tot die
  /// diepste vlak dadelik wys, net soos die web.
  Campus? _drillCampus;
  Building? _drillBuilding;
  String? _drillRoomId;

  /// Navigasie-stapel vir die fasiliteite-hiërargie: elke inskrywing is die
  /// OUER-vlak (titel + sy filter) wat herstel word met die terug-pyltjie.
  final List<
      ({String title, Campus? campus, Building? building, String? roomId})>
      _navStack = [];

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
    // Die fasiliteite-data (terrein → gebou → lokaal) is nie vir die Paneelbord
    // nodig nie; laai dit op die agtergrond sodat die Paneelbord nie daarvoor
    // hoef te wag nie. Fasiliteite-bladse haal dit self aan wanneer hulle
    // oopgemaak word.
    unawaited(CampusService.fetchCampuses());
    try {
      await Future.wait([
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
            setState(() {
              _clearDrillNavigation();
              _selectedTitle = title;
            });
          }
        }),
      });
    }

    // Lokaal Kontrole — FK/Admin bestuur skedules; Dosent sien eie.
    if (can('room_checks.manage')) {
      menu.add({
        'title': 'Lokaal Kontrole',
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
      facilitiesChildren.add({
        'title': 'Bates',
        'icon': Icons.inventory_2_outlined,
        'page': AssetsPage(
          filterRoomId: _pendingRoomId,
          inShell: true,
        ),
      });
    }
    if (can('stock.view')) {
      facilitiesChildren.add({
        'title': 'Voorraad',
        'icon': Icons.construction_outlined,
        'page': const StockPage(),
      });
    }
    if (can('rooms.view')) {
      facilitiesChildren.add({
        'title': 'Lokale',
        'icon': Icons.room_outlined,
        'page': ManageRoomsPage(
          initialBuilding: _pendingBuilding,
          onRoomSelected: (room) {
            setState(() {
              _navStack.add(_currentFrame());
              _selectedTitle = 'Bates';
              _drillRoomId = room.id.toString();
              _pendingRoomId = room.id.toString();
            });
            // Skakel die eenmalige lokaal-filter uit sodra die Bates-bladsy dit
            // opgetel het; 'n latere handmatige keuse van Bates wys weer alles.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _pendingRoomId = null);
            });
          },
        ),
      });
    }
    if (can('buildings.view')) {
      facilitiesChildren.add({
        'title': 'Geboue',
        'icon': Icons.business_outlined,
        'page': BuildingsListPage(
          initialCampus: _pendingCampus,
          onBuildingSelected: (building) {
            setState(() {
              _navStack.add(_currentFrame());
              _selectedTitle = 'Lokale';
              _drillBuilding = building;
              _pendingBuilding = building;
            });
            // Skakel die eenmalige gebou-filter uit sodra die Lokale-bladsy dit
            // opgetel het; 'n latere handmatige keuse van Lokale wys weer alles.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _pendingBuilding = null);
            });
          },
        ),
      });
    }
    if (can('locations.view')) {
      facilitiesChildren.add({
        'title': 'Terreine',
        'icon': Icons.map_outlined,
        'page': CampusManagementPage(onCampusSelected: (campus) {
          setState(() {
            _navStack.add(_currentFrame());
            _selectedTitle = 'Geboue';
            _drillCampus = campus;
            _pendingCampus = campus;
          });
          // Skakel die eenmalige kampus-filter uit sodra die Geboue-bladsy dit
          // opgetel het; 'n latere handmatige keuse van Geboue wys weer die
          // verstek-kampus.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _pendingCampus = null);
          });
        })
      });
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
      menu.add({
        'title': 'Foutkaartjies',
        'icon': Icons.report_gmailerrorred_outlined,
        'page': const ReportingPage(),
      });
    }

    // Voorgestelde Werksopdragte is nou 'n tab binne Foutkaartjies (sien ReportingPage).
    // Werksopdragte — Admin/FK sien alle take (WorksAssignmentsPage); kontrakteurs
    // sien net hul eie toegewysde take (JobCardsPage). 'n Gebruiker het net een
    // van hierdie regte, so net die toepaslike inskrywing verskyn.
    if (can('jobs.manage') || can('jobs.view')) {
      menu.add({
        'title': 'Werksopdragte',
        'icon': Icons.assignment_outlined,
        'page': const WorksAssignmentsPage(),
      });
    } else if (can('jobs.view_own')) {
      menu.add({
        'title': 'Werksopdragte',
        'icon': Icons.engineering_outlined,
        'page': const JobCardsPage(),
      });
    }

    // Voorspellings — analise/grafieke-verdeling (predictions.view).
    if (can('predictions.view')) {
      menu.add({
        'title': 'Voorspellings',
        'icon': Icons.show_chart_outlined,
        'page': const VoorspellingsPage(),
      });
    }

    // Gebruikers — Admin slegs (users.manage), laaste item in die navigasie.
    if (can('users.manage')) {
      menu.add({
        'title': 'Gebruikers',
        'icon': Icons.group_outlined,
        'page': const UsersPage(),
      });
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

  /// Die huidige bladsy-vlak as 'n stampbare raam (titel + sy filter), sodat
  /// die terug-pyltjie presies weet hoe om die ouer te herstel.
  ({String title, Campus? campus, Building? building, String? roomId})
      _currentFrame() {
    return (
      title: _selectedTitle,
      campus: _selectedTitle == 'Geboue' ? _drillCampus : null,
      building: _selectedTitle == 'Lokale' ? _drillBuilding : null,
      roomId: _selectedTitle == 'Bates' ? _drillRoomId : null,
    );
  }

  /// Herstel 'n opgestapelde ouer-vlak (Terreine › Geboue › Lokale › Bates).
  void _goBack() {
    if (_navStack.isEmpty) return;
    final frame = _navStack.removeLast();
    setState(() {
      _selectedTitle = frame.title;
      _drillCampus = frame.campus;
      _drillBuilding = frame.building;
      _drillRoomId = frame.roomId;
      _pendingCampus = frame.title == 'Geboue' ? frame.campus : null;
      _pendingBuilding = frame.title == 'Lokale' ? frame.building : null;
      _pendingRoomId = frame.title == 'Bates' ? frame.roomId : null;
    });
    // Skakel die eenmalige filter uit sodra die herstelde bladsy dit opgetel het.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _pendingCampus = null;
          _pendingBuilding = null;
          _pendingRoomId = null;
        });
      }
    });
  }

  /// Stel die intrek-navigasie terug (gewone kieslys-/paneelbord-navigasie).
  void _clearDrillNavigation() {
    _navStack.clear();
    _drillCampus = null;
    _drillBuilding = null;
    _drillRoomId = null;
    _pendingCampus = null;
    _pendingBuilding = null;
    _pendingRoomId = null;
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
        leading: _navStack.isEmpty
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: "Terug na vorige vlak",
                onPressed: _goBack,
              ),
        title: Text("FBS - ${activeItem['title']}",
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Colors.white)),
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
                      icon: const Icon(Icons.notifications_outlined,
                          color: Colors.white),
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
                        child: CountBadge(count,
                            color: Colors.red,
                            shape: BoxShape.circle,
                            padding: const EdgeInsets.all(4),
                            fontSize: 10,
                            minSize: const Size(18, 18),
                            maxCount: 99),
                      ),
                  ],
                );
              },
            ),
          if (roleTitle.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Text(roleTitle,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 10)),
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
                child: Text("FBS",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
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
              leading: const Icon(Icons.dns, color: Colors.white70),
              title: const Text("Bediener-instellings",
                  style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServerConfigPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Teken Uit",
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await ApiClient().clearToken();
                await OutlookTokenManager.instance.signOut();
                UserSession.clear();
                if (!mounted) return;
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
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
    bool containsSelected = (item['children'] as List)
        .any((child) => child['title'] == _selectedTitle);

    return Column(
      children: [
        ListTile(
          leading: Icon(item['icon'],
              color: containsSelected ? AppColors.gold : Colors.white70),
          title: Text(item['title'],
              style: TextStyle(
                  color: containsSelected ? AppColors.gold : Colors.white,
                  fontWeight:
                      containsSelected ? FontWeight.bold : FontWeight.normal)),
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
        color: isSelected
            ? AppColors.gold
            : (isSubItem ? Colors.white54 : Colors.white70),
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
        setState(() {
          _clearDrillNavigation();
          _selectedTitle = title;
        });
        Navigator.pop(context);
      },
    );
  }
}

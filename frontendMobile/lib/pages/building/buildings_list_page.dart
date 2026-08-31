import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import 'add_building_page.dart';
import 'edit_building_page.dart';
import '../rooms/manage_rooms_page.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';

class BuildingsListPage extends StatefulWidget {
  final Campus? initialCampus;
  const BuildingsListPage({super.key, this.initialCampus});

  @override
  State<BuildingsListPage> createState() => _BuildingsListPageState();
}

class _BuildingsListPageState extends State<BuildingsListPage> {
  Campus? _selectedCampus;
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('buildings', [
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'rooms', label: 'Lokale'),
    const ColumnDef(key: 'address', label: 'Adres', defaultVisible: false),
  ]);

  @override
  void initState() {
    super.initState();
    if (widget.initialCampus != null) {
      _selectedCampus = widget.initialCampus;
    } else {
      _loadInitialCampus();
    }
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadInitialCampus() {
    final campuses = CampusService.campusesNotifier.value;
    if (UserSession.isManager && UserSession.locationId != null) {
      _selectedCampus = campuses.where((c) => c.id == UserSession.locationId).firstOrNull;
    }
    if (_selectedCampus == null) {
      if (UserSession.hasAdminPrivileges) {
        if (campuses.isNotEmpty) {
          _selectedCampus = campuses.first;
        }
      } else {
        _selectedCampus = CampusService.getCampusByName(UserSession.userCampus);
      }
    }
    setState(() {});
  }

  Future<void> _deleteBuilding(Building building) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verwyder Gebou"),
        content: Text("Is jy seker jy wil '${building.name}' verwyder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("KANSELLEER")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("VERWYDER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final success = await CampusService.removeBuilding(building.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Gebou verwyder." : "Kon nie die gebou verwyder nie."),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, campuses, _) {
          if (campuses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Re-resolve die gekose kampus teen die vars `campuses`-lys (nie die
          // ou objekverwysing nie) sodat byvoeg/wysig/verwyder dadelik wys.
          Campus? selectedCampus = _selectedCampus != null
              ? campuses.where((c) => c.id == _selectedCampus!.id).firstOrNull
              : null;
          if (selectedCampus == null) {
            if (UserSession.isManager && UserSession.locationId != null) {
              selectedCampus = campuses.where((c) => c.id == UserSession.locationId).firstOrNull;
            }
            if (selectedCampus == null && UserSession.hasAdminPrivileges) {
              selectedCampus = campuses.isNotEmpty ? campuses.first : null;
            }
          }
          _selectedCampus = selectedCampus;

          final buildings = selectedCampus?.buildings ?? <Building>[];

          final filtered = buildings.where((b) =>
              _query.isEmpty ||
              b.name.toLowerCase().contains(_query) ||
              b.address.toLowerCase().contains(_query)).toList();

          if (_sortCtrl.isActive) {
            filtered.sort((a, b) {
              final dir = _sortCtrl.direction;
              switch (_sortCtrl.sortKey) {
                case 'name': return a.name.toLowerCase().compareTo(b.name.toLowerCase()) * dir;
                case 'rooms': return (a.rooms?.length ?? 0).compareTo(b.rooms?.length ?? 0) * dir;
                default: return 0;
              }
            });
          }

          return Column(
            children: [
              FixedPageHeader(
                controller: _searchController,
                hintText: "Soek geboue...",
                onChanged: (_) => setState(() {}),
                actions: [
                  HeaderIconAction(
                    icon: Icons.place_outlined,
                    tooltip: "Filter op Terrein",
                    activeBadge: _selectedCampus != null,
                    onTap: () => showLocationFilterSheet(
                      context,
                      depth: LocationDepth.campus,
                      campusId: _selectedCampus?.id,
                      onChanged: (campusId, _, __) {
                        setState(() {
                          _selectedCampus =
                              campuses.where((c) => c.id == campusId).firstOrNull;
                        });
                      },
                    ),
                  ),
                  ColumnVisibilityButton(controller: _colVis, iconOnly: true),
                ],
              ),

              if (UserSession.can('buildings.manage'))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (_selectedCampus == null) return;
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddBuildingPage(campus: _selectedCampus!),
                          ),
                        );
                        if (result == true) setState(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("VOEG NUWE GEBOU BY"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("Geen geboue gevind nie.", style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: () => CampusService.fetchCampuses(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final b = filtered[index];
                            final roomCount = b.rooms?.length ?? 0;
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.all(15),
                                  title: Text(
                                    b.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (b.address.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(b.address, style: const TextStyle(fontSize: 13)),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        "$roomCount Lokale",
                                        style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (UserSession.can('buildings.manage')) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EditBuildingPage(building: b),
                                              ),
                                            );
                                            if (result == true) setState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                          onPressed: () => _deleteBuilding(b),
                                        ),
                                      ],
                                      const Icon(Icons.chevron_right, color: AppColors.gold),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ManageRoomsPage(
                                          initialCampus: _selectedCampus,
                                          initialBuilding: b,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (roomCount > 0 && UserSession.can('buildings.manage'))
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ManageRoomsPage(
                                                initialCampus: _selectedCampus,
                                                initialBuilding: b,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "BESIGTIG LOKALE",
                                          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            );
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
}

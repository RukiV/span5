import '../../models/user_session.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import 'add_building_page.dart';
import 'edit_building_page.dart';
import 'manage_rooms_page.dart';

class BuildingsListPage extends StatefulWidget {
  final Campus? initialCampus;
  const BuildingsListPage({super.key, this.initialCampus});

  @override
  State<BuildingsListPage> createState() => _BuildingsListPageState();
}

class _BuildingsListPageState extends State<BuildingsListPage> {
  Campus? _selectedCampus;

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
  }

  void _loadInitialCampus() {
    if (UserSession.isAdmin) {
      if (CampusService.campusesNotifier.value.isNotEmpty) {
        _selectedCampus = CampusService.campusesNotifier.value.first;
      }
    } else {
      _selectedCampus = CampusService.getCampusByName(UserSession.userCampus);
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
    if (confirm == true) {
      await CampusService.removeBuilding(building.id);
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

          if (UserSession.isAdmin && _selectedCampus == null) {
            _selectedCampus = campuses.first;
          }

          List<Building> buildings = [];
          if (_selectedCampus != null) {
            buildings = _selectedCampus!.buildings;
          }

          return Column(
            children: [
              if (UserSession.isAdmin) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Campus>(
                        isExpanded: true,
                        value: campuses.any((c) => c.id == _selectedCampus?.id)
                            ? campuses.firstWhere((c) => c.id == _selectedCampus?.id)
                            : null,
                        hint: const Text("Kies 'n terrein"),
                        items: campuses.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        )).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCampus = val);
                        },
                      ),
                    ),
                  ),
                ),
              ] else if (_selectedCampus != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text(
                    "Terrein: ${_selectedCampus!.name}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 16),
                  ),
                ),
              ],

              if (UserSession.isAdmin)
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

              const SizedBox(height: 10),

              Expanded(
                child: buildings.isEmpty
                    ? const Center(child: Text("Geen geboue geregistreer nie.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        itemCount: buildings.length,
                        itemBuilder: (context, index) {
                          final b = buildings[index];
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
                                      if (UserSession.isAdmin) ...[
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
                                if (roomCount > 0 && UserSession.isAdmin)
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
            ],
          );
        },
      ),
    );
  }
}

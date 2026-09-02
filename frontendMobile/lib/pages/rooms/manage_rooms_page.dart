import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../models/room.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';
import '../asset/asset_page.dart';
import '../room_checklist/room_checklist_page.dart';

class ManageRoomsPage extends StatefulWidget {
  final Campus? initialCampus;
  final Building? initialBuilding;

  const ManageRoomsPage({super.key, this.initialCampus, this.initialBuilding});

  @override
  State<ManageRoomsPage> createState() => _ManageRoomsPageState();
}

class _ManageRoomsPageState extends State<ManageRoomsPage> {
  Campus? _selectedCampus;
  Building? _selectedBuilding;
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('rooms', [
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'type', label: 'Tipe'),
    const ColumnDef(key: 'capacity', label: 'Kapasiteit'),
  ]);

  @override
  void initState() {
    super.initState();
    if (widget.initialCampus != null) {
      _selectedCampus = widget.initialCampus;
    }
    if (widget.initialBuilding != null) {
      _selectedBuilding = widget.initialBuilding;
    }
    if (_selectedCampus == null) {
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

  List<Room> get _availableRooms {
    if (_selectedBuilding == null) return [];
    return _selectedBuilding!.rooms ?? [];
  }

  void _showAddRoomDialog(BuildContext context) {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: "30");
    String type = "other";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Nuwe lokaal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Naam", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  decoration: _popupInputDecoration(),
                ),
                const SizedBox(height: 16),
                const Text("Gebou", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Text(_selectedBuilding?.name ?? "", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 16),
                const Text("Kapasiteit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: capacityController,
                  decoration: _popupInputDecoration(),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SearchableDropdown<String>(
                  label: "Tipe",
                  hint: "Kies Tipe",
                  value: type,
                  items: ["klas", "laboratorium", "kantoor", "other"]
                      .map((t) => SearchableDropdownItem(value: t, label: t))
                      .toList(),
                  onChanged: (v) => type = v ?? "other",
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty || _selectedBuilding == null) return;
                        final room = Room(
                          id: 0,
                          name: nameController.text.trim(),
                          type: type,
                          capacity: int.tryParse(capacityController.text),
                          buildingId: _selectedBuilding!.id,
                        );
                        await CampusService.addRoom(room);
                        if (!mounted) return;
                        if (context.mounted) {
                          Navigator.pop(context);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("'${room.name}' is bygevoeg"), backgroundColor: Colors.green),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5E34),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Stoor"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditRoomDialog(BuildContext context, Room room) {
    final nameController = TextEditingController(text: room.name);
    final capacityController = TextEditingController(text: room.capacity?.toString() ?? "");
    String type = room.type;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Wysig lokaal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Naam", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  decoration: _popupInputDecoration(),
                ),
                const SizedBox(height: 16),
                const Text("Kapasiteit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: capacityController,
                  decoration: _popupInputDecoration(),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SearchableDropdown<String>(
                  label: "Tipe",
                  hint: "Kies Tipe",
                  value: type,
                  items: ["klas", "laboratorium", "kantoor", "other"]
                      .map((t) => SearchableDropdownItem(value: t, label: t))
                      .toList(),
                  onChanged: (v) => type = v ?? "other",
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty) return;
                        final updatedRoom = room.copyWith(
                          name: nameController.text.trim(),
                          type: type,
                          capacity: int.tryParse(capacityController.text),
                        );
                        await CampusService.updateRoom(updatedRoom);
                        if (!mounted) return;
                        if (context.mounted) {
                          Navigator.pop(context);
                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Stoor"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRoom(Room room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verwyder Lokaal"),
        content: Text("Is jy seker jy wil '${room.name}' verwyder?"),
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
      final success = await CampusService.removeRoom(room.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Lokaal verwyder." : "Kon nie die lokaal verwyder nie."),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  InputDecoration _popupInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: Navigator.of(context).canPop()
          ? AppBar(title: const Text("Lokale"))
          : null,
      body: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, campuses, _) {
          if (campuses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Re-resolve die gekose kampus/gebou teen die vars `campuses`-lys (nie
          // die ou objekverwysings nie) sodat byvoeg/wysig/verwyder dadelik wys.
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

          Building? selectedBuilding;
          if (_selectedBuilding != null && selectedCampus != null) {
            selectedBuilding = selectedCampus.buildings
                .where((b) => b.id == _selectedBuilding!.id)
                .firstOrNull;
          }
          _selectedBuilding = selectedBuilding;

          return Column(
            children: [
              FixedPageHeader(
                controller: _searchController,
                hintText: "Soek lokale...",
                onChanged: (_) => setState(() {}),
                actions: [
                  HeaderIconAction(
                    icon: Icons.place_outlined,
                    tooltip: "Filter op Ligging",
                    activeBadge: _selectedBuilding != null,
                    onTap: () => showLocationFilterSheet(
                      context,
                      depth: LocationDepth.building,
                      campusId: _selectedCampus?.id,
                      buildingId: _selectedBuilding?.id,
                      onChanged: (campusId, buildingId, _) {
                        setState(() {
                          _selectedCampus = campuses.where((c) => c.id == campusId).firstOrNull;
                          _selectedBuilding = _selectedCampus?.buildings.where((b) => b.id == buildingId).firstOrNull;
                        });
                      },
                    ),
                  ),
                  ColumnVisibilityButton(controller: _colVis, iconOnly: true),
                ],
              ),

              if (_selectedBuilding != null && UserSession.can('rooms.manage'))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddRoomDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text("NUWE LOKAAL"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _selectedBuilding == null
                      ? const Center(
                          child: Text("Kies 'n gebou om lokale te sien.", style: TextStyle(color: Colors.grey)),
                        )
                      : Builder(builder: (context) {
                          final filtered = List<Room>.from(_availableRooms)
                              .where((r) =>
                                  _query.isEmpty ||
                                  r.name.toLowerCase().contains(_query) ||
                                  r.type.toLowerCase().contains(_query))
                              .toList();
                          if (_sortCtrl.isActive) {
                            filtered.sort((a, b) {
                              final dir = _sortCtrl.direction;
                              switch (_sortCtrl.sortKey) {
                                case 'name':
                                  return a.name.toLowerCase().compareTo(b.name.toLowerCase()) * dir;
                                case 'type':
                                  return a.type.toLowerCase().compareTo(b.type.toLowerCase()) * dir;
                                case 'capacity':
                                  return (a.capacity ?? 0).compareTo(b.capacity ?? 0) * dir;
                                default:
                                  return 0;
                              }
                            });
                          }
                          if (filtered.isEmpty) {
                            return const Center(child: Text("Geen lokale geregistreer nie.", style: TextStyle(color: Colors.grey)));
                          }
                          return RefreshIndicator(
                            onRefresh: () => CampusService.fetchCampuses(),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final room = filtered[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    subtitle: Text("ID: ${room.id} | ${room.type}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (UserSession.can('rooms.manage')) ...[
                                          IconButton(
                                            icon: const Icon(Icons.checklist, color: Colors.grey, size: 20),
                                            tooltip: "Kontroleer bates",
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => RoomChecklistPage(roomId: room.id),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                            onPressed: () => _showEditRoomDialog(context, room),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                            onPressed: () => _deleteRoom(room),
                                          ),
                                        ],
                                        const Icon(Icons.chevron_right, color: AppColors.gold),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AssetsPage(filterRoomId: room.id.toString()),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

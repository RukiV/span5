import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../models/room.dart';
import '../asset/asset_page.dart';
import '../room_checklist/room_checklist_page.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';

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
    if (confirm == true) {
      await CampusService.removeRoom(room.id);
      if (mounted) setState(() {});
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
      body: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, campuses, _) {
          if (campuses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_selectedCampus == null) {
            if (UserSession.isManager && UserSession.locationId != null) {
              _selectedCampus = campuses.where((c) => c.id == UserSession.locationId).firstOrNull;
            }
            if (_selectedCampus == null && UserSession.hasAdminPrivileges) {
              _selectedCampus = campuses.first;
            }
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationCascadePicker(
                  depth: LocationDepth.building,
                  initialCampusId: _selectedCampus?.id,
                  initialBuildingId: _selectedBuilding?.id,
                  onChanged: (campusId, buildingId, _) {
                    setState(() {
                      _selectedCampus =
                          campuses.where((c) => c.id == campusId).firstOrNull;
                      _selectedBuilding = _selectedCampus?.buildings
                          .where((b) => b.id == buildingId)
                          .firstOrNull;
                    });
                  },
                ),
                const SizedBox(height: 20),

                if (_selectedBuilding == null)
                  const Expanded(child: Center(child: Text("Kies 'n gebou om lokale te sien.", style: TextStyle(color: Colors.grey))))
                else ...[
                  if (UserSession.hasAdminPrivileges)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showAddRoomDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text("NUWE LOKAAL"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "BESTAANDE LOKALE (Klik om bates te sien)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy, letterSpacing: 1.1),
                      ),
                      ColumnVisibilityButton(controller: _colVis),
                    ],
                  ),
                  const SizedBox(height: 10),
                  () {
                    final filtered = List<Room>.from(_availableRooms);
                    if (_sortCtrl.isActive) {
                      filtered.sort((a, b) {
                        final dir = _sortCtrl.direction;
                        switch (_sortCtrl.sortKey) {
                          case 'name': return a.name.toLowerCase().compareTo(b.name.toLowerCase()) * dir;
                          case 'type': return a.type.toLowerCase().compareTo(b.type.toLowerCase()) * dir;
                          case 'capacity': return (a.capacity ?? 0).compareTo(b.capacity ?? 0) * dir;
                          default: return 0;
                        }
                      });
                    }
                    return Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("Geen lokale geregistreer nie.", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
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
                                      if (UserSession.hasAdminPrivileges) ...[
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
                  }(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

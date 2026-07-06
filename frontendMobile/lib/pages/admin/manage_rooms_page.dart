import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../models/room.dart';
import '../assets/assets_page.dart';
import '../../widgets/searchable_dropdown.dart';

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
    if (UserSession.hasAdminPrivileges) {
      if (CampusService.campusesNotifier.value.isNotEmpty) {
        _selectedCampus = CampusService.campusesNotifier.value.first;
      }
    } else {
      _selectedCampus = CampusService.getCampusByName(UserSession.userCampus);
    }
    setState(() {});
  }

  List<Building> get _availableBuildings {
    if (_selectedCampus == null) return [];
    return _selectedCampus!.buildings;
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
                        Navigator.pop(context);
                        if (mounted) {
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
                        Navigator.pop(context);
                        if (mounted) {
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

          if (UserSession.hasAdminPrivileges && _selectedCampus == null) {
            _selectedCampus = campuses.first;
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (UserSession.hasAdminPrivileges && widget.initialCampus == null) ...[
                  const Text("KIES TERREIN:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
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
                          setState(() {
                            _selectedCampus = val;
                            _selectedBuilding = null;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (_selectedCampus != null) ...[
                  Text(
                    "Terrein: ${_selectedCampus!.name}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                ],

                if (_selectedCampus != null) ...[
                  const Text("KIES GEBOU:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Building>(
                        isExpanded: true,
                        value: _availableBuildings.any((b) => b.id == _selectedBuilding?.id)
                            ? _availableBuildings.firstWhere((b) => b.id == _selectedBuilding?.id)
                            : null,
                        hint: const Text("Kies 'n gebou"),
                        items: _availableBuildings.map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.name),
                        )).toList(),
                        onChanged: (val) {
                          setState(() => _selectedBuilding = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

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
                  const Text(
                    "BESTAANDE LOKALE (Klik om bates te sien)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _availableRooms.isEmpty
                        ? const Center(child: Text("Geen lokale geregistreer nie.", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _availableRooms.length,
                            itemBuilder: (context, index) {
                              final room = _availableRooms[index];
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
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

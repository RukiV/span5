import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';

class ManageRoomsPage extends StatefulWidget {
  const ManageRoomsPage({super.key});

  @override
  State<ManageRoomsPage> createState() => _ManageRoomsPageState();
}

class _ManageRoomsPageState extends State<ManageRoomsPage> {
  final TextEditingController _roomController = TextEditingController();
  Campus? _myCampus;

  @override
  void initState() {
    super.initState();
    _loadCampus();
  }

  void _loadCampus() {
    final campus = CampusService.getCampusByName(UserSession.userCampus);
    setState(() {
      _myCampus = campus;
    });
  }

  Future<void> _addRoom() async {
    if (_roomController.text.isEmpty || _myCampus == null) return;

    final newRoom = _roomController.text.trim();
    final updatedRooms = List<String>.from(_myCampus!.rooms)..add(newRoom);

    await CampusService.updateRooms(_myCampus!.id, updatedRooms);
    _roomController.clear();
    _loadCampus(); // Refresh local state

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'$newRoom' is bygevoeg"), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _removeRoom(String room) async {
    if (_myCampus == null) return;

    final updatedRooms = List<String>.from(_myCampus!.rooms)..remove(room);
    await CampusService.updateRooms(_myCampus!.id, updatedRooms);
    _loadCampus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("BESTUUR LOKALE"),
      ),
      body: _myCampus == null
          ? const Center(child: Text("Geen kampus gevind vir jou profiel nie."))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Kampus: ${_myCampus!.name}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _roomController,
                          decoration: InputDecoration(
                            hintText: "Nuwe lokaal naam...",
                            filled: true,
                            fillColor: const Color(0xFFFEFBEA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addRoom,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "BESTAANDE LOKALE",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _myCampus!.rooms.isEmpty
                        ? const Center(child: Text("Geen lokale geregistreer nie.", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _myCampus!.rooms.length,
                            itemBuilder: (context, index) {
                              final room = _myCampus!.rooms[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  title: Text(room, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _removeRoom(room),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

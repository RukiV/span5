<<<<<<< HEAD
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../assets/assets_page.dart';

class ManageRoomsPage extends StatefulWidget {
  const ManageRoomsPage({super.key});

  @override
  State<ManageRoomsPage> createState() => _ManageRoomsPageState();
}

class _ManageRoomsPageState extends State<ManageRoomsPage> {
  final TextEditingController _roomController = TextEditingController();
  Campus? _selectedCampus;

  @override
  void initState() {
    super.initState();
    _loadInitialCampus();
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

  Future<void> _addRoom() async {
    if (_roomController.text.isEmpty || _selectedCampus == null) return;

    final newRoom = _roomController.text.trim();
    // Die backend verwag dalk die ID van die plek
    final updatedRooms = List<String>.from(_selectedCampus!.rooms)..add(newRoom);

    await CampusService.updateRooms(_selectedCampus!.id, updatedRooms);
    _roomController.clear();
    
    // Herlaai data
    await CampusService.fetchCampuses();
    if (UserSession.isAdmin) {
      _selectedCampus = CampusService.campusesNotifier.value.firstWhere((c) => c.id == _selectedCampus!.id);
    } else {
      _selectedCampus = CampusService.getCampusByName(UserSession.userCampus);
    }

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'$newRoom' is bygevoeg"), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("BESTUUR LOKALE"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (UserSession.isAdmin) ...[
              const Text("KIES KAMPUS:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<Campus>>(
                valueListenable: CampusService.campusesNotifier,
                builder: (context, campuses, _) {
                  return Container(
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
                        hint: const Text("Kies 'n kampus"),
                        items: campuses.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        )).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCampus = val);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ] else if (_selectedCampus != null) ...[
              Text(
                "Kampus: ${_selectedCampus!.name}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 16),
              ),
              const SizedBox(height: 20),
            ],

            if (_selectedCampus == null)
              const Center(child: Text("Geen kampus geselekteer nie."))
            else ...[
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
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                    child: const Icon(Icons.add),
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
                child: _selectedCampus!.rooms.isEmpty
                    ? const Center(child: Text("Geen lokale geregistreer nie.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _selectedCampus!.rooms.length,
                        itemBuilder: (context, index) {
                          final room = _selectedCampus!.rooms[index];
                          final roomDisplay = room.contains(':') ? room.split(':').last : room;
                          final roomId = room.contains(':') ? room.split(':').first : room;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              title: Text(roomDisplay, style: const TextStyle(fontWeight: FontWeight.w500)),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AssetsPage(filterRoomId: roomId),
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
      ),
    );
  }
}
=======
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../assets/assets_page.dart';

class ManageRoomsPage extends StatefulWidget {
  const ManageRoomsPage({super.key});

  @override
  State<ManageRoomsPage> createState() => _ManageRoomsPageState();
}

class _ManageRoomsPageState extends State<ManageRoomsPage> {
  final TextEditingController _roomController = TextEditingController();
  Campus? _selectedCampus;

  @override
  void initState() {
    super.initState();
    _loadInitialCampus();
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

  void _showEditRoomDialog(BuildContext context, String roomName) {
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
                  initialValue: roomName,
                  decoration: _popupInputDecoration(),
                ),
                const SizedBox(height: 16),
                const Text("Terrein", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<Campus>(
                  value: _selectedCampus,
                  decoration: _popupInputDecoration(),
                  items: CampusService.campusesNotifier.value.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _selectedCampus = v),
                ),
                const SizedBox(height: 16),
                const Text("Kapasiteit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: "30",
                  decoration: _popupInputDecoration(),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text("Tipe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: "Ander",
                  decoration: _popupInputDecoration(),
                  items: ["Klas", "Laboratorium", "Kantoor", "Ander"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) {},
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kanselleer", style: TextStyle(color: Colors.grey))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5E34),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Opdateer"),
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

  void _showAddRoomDialog(BuildContext context) {
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
                  controller: _roomController,
                  decoration: _popupInputDecoration(),
                ),
                const SizedBox(height: 16),
                const Text("Terrein", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<Campus>(
                  value: _selectedCampus,
                  decoration: _popupInputDecoration(),
                  items: CampusService.campusesNotifier.value.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _selectedCampus = v),
                ),
                const SizedBox(height: 16),
                const Text("Kapasiteit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  decoration: _popupInputDecoration(),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text("Tipe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: "Ander",
                  decoration: _popupInputDecoration(),
                  items: ["Klas", "Laboratorium", "Kantoor", "Ander"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) {},
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kanselleer", style: TextStyle(color: Colors.grey))),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        _addRoom();
                        Navigator.pop(context);
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

  Future<void> _addRoom() async {
    if (_roomController.text.isEmpty || _selectedCampus == null) return;

    final newRoom = _roomController.text.trim();
    // Die backend verwag dalk die ID van die plek
    final updatedRooms = List<String>.from(_selectedCampus!.rooms)..add(newRoom);

    await CampusService.updateRooms(_selectedCampus!.id, updatedRooms);
    _roomController.clear();
    
    // Herlaai data
    await CampusService.fetchCampuses();
    if (UserSession.isAdmin) {
      _selectedCampus = CampusService.campusesNotifier.value.firstWhere((c) => c.id == _selectedCampus!.id);
    } else {
      _selectedCampus = CampusService.getCampusByName(UserSession.userCampus);
    }

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'$newRoom' is bygevoeg"), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (UserSession.isAdmin) ...[
              const Text("KIES KAMPUS:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<Campus>>(
                valueListenable: CampusService.campusesNotifier,
                builder: (context, campuses, _) {
                  return Container(
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
                        hint: const Text("Kies 'n kampus"),
                        items: campuses.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        )).toList(),
                        onChanged: (val) {
                          setState(() => _selectedCampus = val);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ] else if (_selectedCampus != null) ...[
              Text(
                "Kampus: ${_selectedCampus!.name}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 16),
              ),
              const SizedBox(height: 20),
            ],

            if (_selectedCampus == null)
              const Center(child: Text("Geen kampus geselekteer nie."))
            else ...[
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
                child: _selectedCampus!.rooms.isEmpty
                    ? const Center(child: Text("Geen lokale geregistreer nie.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _selectedCampus!.rooms.length,
                        itemBuilder: (context, index) {
                          final room = _selectedCampus!.rooms[index];
                          final roomDisplay = room.contains(':') ? room.split(':').last : room;
                          final roomId = room.contains(':') ? room.split(':').first : room;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              title: Text(roomDisplay, style: const TextStyle(fontWeight: FontWeight.w500)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.grey),
                                    onPressed: () => _showEditRoomDialog(context, roomDisplay),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.gold),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AssetsPage(filterRoomId: roomId),
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
      ),
    );
  }
}
>>>>>>> 3080162a6b51675de2ce74fa53f3bd629f39db17

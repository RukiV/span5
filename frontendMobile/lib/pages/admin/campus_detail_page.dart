import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/campus_service.dart';
import '../../models/campus.dart';
import '../../models/user_session.dart';
import '../assets/assets_page.dart';
import 'edit_campus_page.dart';

class CampusDetailPage extends StatefulWidget {
  final Campus campus;
  const CampusDetailPage({super.key, required this.campus});

  @override
  State<CampusDetailPage> createState() => _CampusDetailPageState();
}

class _CampusDetailPageState extends State<CampusDetailPage> {
  late Campus _currentCampus;

  @override
  void initState() {
    super.initState();
    _currentCampus = widget.campus;
    // Sinkroniseer as daar updates was
    CampusService.campusesNotifier.addListener(_updateLocalState);
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_updateLocalState);
    super.dispose();
  }

  void _updateLocalState() {
    if (!mounted) return;
    try {
      final updated = CampusService.campusesNotifier.value.firstWhere((c) => c.id == _currentCampus.id);
      setState(() => _currentCampus = updated);
    } catch (_) {
      // Campus is moontlik verwyder
    }
  }

  Future<void> _deleteCampus() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verwyder Terrein"),
        content: Text("Is jy seker jy wil '${_currentCampus.name}' verwyder? Hierdie aksie kan nie ongedaan gemaak word nie."),
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
      final success = await CampusService.removeCampus(_currentCampus.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Terrein suksesvol verwyder"), backgroundColor: AppColors.successGreen),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kon nie terrein verwyder nie."), backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_currentCampus.name),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          if (UserSession.isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.gold),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditCampusPage(campus: _currentCampus)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteCampus,
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          _buildInfoSection(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Icon(Icons.meeting_room, color: AppColors.gold, size: 20),
                SizedBox(width: 10),
                Text(
                  "LOKALE",
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
          Expanded(child: _buildRoomsList()),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentCampus.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.gold, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _currentCampus.address,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              _currentCampus.code,
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList() {
    if (_currentCampus.rooms.isEmpty) {
      return const Center(child: Text("Geen lokale geregistreer nie.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: _currentCampus.rooms.length,
      itemBuilder: (context, index) {
        final room = _currentCampus.rooms[index];
        final roomDisplay = room.contains(':') ? room.split(':').last : room;
        final roomId = room.contains(':') ? room.split(':').first : room;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            title: Text(roomDisplay, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text("ID: $roomId", style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_colors.dart';
import '../../models/room.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import 'edit_room_page.dart';

class RoomDetailPage extends StatefulWidget {
  final Room room;
  const RoomDetailPage({super.key, required this.room});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late Room _currentRoom;
  String _buildingName = '-';
  String _campusName = '-';

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _resolveLocation();
  }

  void _resolveLocation() {
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        if (b.id == _currentRoom.buildingId) {
          _buildingName = b.name;
          _campusName = c.name;
          return;
        }
      }
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'klas':
        return 'Klaskamer';
      case 'laboratorium':
        return 'Laboratorium';
      case 'kantoor':
        return 'Kantoor';
      case 'konferensie':
        return 'Konferensiekamer';
      case 'pakhuis':
        return 'Pakhuis';
      case 'badkamer':
        return 'Badkamer';
      default:
        return 'Ander';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(_currentRoom.name.toUpperCase()),
        actions: [
          if (UserSession.can('rooms.manage'))
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Wysig',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditRoomPage(room: _currentRoom),
                  ),
                );
                if (result == true && mounted) {
                  await CampusService.fetchCampuses();
                  // Herresolwe die kamer
                  for (final c in CampusService.campusesNotifier.value) {
                    for (final b in c.buildings) {
                      for (final r in (b.rooms ?? const <dynamic>[])) {
                        if (r.id == _currentRoom.id) {
                          setState(() {
                            _currentRoom = r;
                            _buildingName = b.name;
                            _campusName = c.name;
                          });
                          return;
                        }
                      }
                    }
                  }
                }
              },
            ),
          if (UserSession.can('rooms.manage'))
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              tooltip: 'Verwyder',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Besonderhede"),
            const SizedBox(height: 12),
            _buildInfoCard(),
            if (_currentRoom.roomCode != null &&
                _currentRoom.roomCode!.isNotEmpty) ...[
              const SizedBox(height: 25),
              _buildSectionHeader("QR Kode"),
              const SizedBox(height: 12),
              _buildQRCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(
              "Naam",
              Text(_currentRoom.name,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Tipe",
              Text(_typeLabel(_currentRoom.type),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Gebou",
              Text(_buildingName,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Terrein",
              Text(_campusName,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Kapasiteit",
              Text(_currentRoom.capacity?.toString() ?? "-",
                  style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(width: 16),
        Flexible(child: value),
      ],
    );
  }

  Widget _buildQRCard() {
    final code = _currentRoom.roomCode!;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            Text(code,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                    fontSize: 16,
                    letterSpacing: 1.5)),
            const SizedBox(height: 16),
            QrImageView(
              data: code,
              size: 160,
              version: QrVersions.auto,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder Lokaal"),
        content:
            Text("Is jy seker jy wil '${_currentRoom.name}' verwyder?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Kanselleer"),
          ),
          TextButton(
            onPressed: () async {
              final success =
                  await CampusService.removeRoom(_currentRoom.id);
              if (!mounted) return;
              if (success) {
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Verwyder",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

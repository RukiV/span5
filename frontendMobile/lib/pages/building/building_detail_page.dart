import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/building.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/detail_row.dart';
import 'building_form_page.dart';

class BuildingDetailPage extends StatefulWidget {
  final Building building;
  const BuildingDetailPage({super.key, required this.building});

  @override
  State<BuildingDetailPage> createState() => _BuildingDetailPageState();
}

class _BuildingDetailPageState extends State<BuildingDetailPage> {
  late Building _currentBuilding;

  @override
  void initState() {
    super.initState();
    _currentBuilding = widget.building;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'admin':
        return 'Administrasie';
      case 'onderwys':
        return 'Onderwys';
      case 'laboratory':
        return 'Laboratorium';
      case 'warehouse':
        return 'Pakhuis';
      case 'kafeteria':
        return 'Kafeteria';
      case 'residential':
        return 'Koshuis';
      default:
        return 'Ander';
    }
  }

  String get _campusName {
    for (final c in CampusService.campusesNotifier.value) {
      if (c.id == _currentBuilding.locationId) return c.name;
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final roomCount = _currentBuilding.rooms?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(_currentBuilding.name.toUpperCase()),
        actions: [
          if (UserSession.can('buildings.manage'))
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Wysig',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BuildingFormPage(building: _currentBuilding, startEditing: true),
                  ),
                );
                if (result == true && mounted) {
                  // Herlaai data vanaf service
                  await CampusService.fetchCampuses();
                  if (!mounted) return;
                  final updated = CampusService.campusesNotifier.value
                      .expand((c) => c.buildings)
                      .where((b) => b.id == _currentBuilding.id)
                      .firstOrNull;
                  if (updated != null) {
                    setState(() => _currentBuilding = updated);
                  }
                }
              },
            ),
          if (UserSession.can('buildings.manage'))
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
            _buildInfoCard(roomCount),
            const SizedBox(height: 25),
            _buildSectionHeader("Lokale ($roomCount)"),
            const SizedBox(height: 12),
            (_currentBuilding.rooms == null || _currentBuilding.rooms!.isEmpty)
                ? _buildEmptyState("Geen lokale geregistreer nie.")
                : _buildRoomsList(),
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

  Widget _buildInfoCard(int roomCount) {
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
          DetailRow(
              label: "Naam",
              valueWidget: Flexible(
                child: Text(_currentBuilding.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Tipe",
              valueWidget: Flexible(
                child: Text(
                    _currentBuilding.types.map(_typeLabel).join(", "),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Terrein",
              valueWidget: Flexible(
                child: Text(_campusName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Adres",
              valueWidget: Flexible(
                child: Text(_currentBuilding.address.isEmpty
                    ? "-"
                    : _currentBuilding.address,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Aantal Lokale",
              valueWidget: Flexible(
                child: Text("$roomCount",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
        ],
      ),
    );
  }

  Widget _buildRoomsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _currentBuilding.rooms!.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final room = _currentBuilding.rooms![index];
          return ListTile(
            leading: const Icon(Icons.door_front_door,
                color: AppColors.navy, size: 28),
            title: Text(room.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(room.type,
                style: const TextStyle(fontSize: 12)),
            trailing: room.capacity != null
                ? Text("${room.capacity} plekke",
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold))
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message,
          style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontStyle: FontStyle.italic)),
    );
  }

  Future<void> _confirmDelete() => confirmDeleteAndRun(
      context,
      entityLabel: 'gebou',
      itemName: _currentBuilding.name,
      delete: () => CampusService.removeBuilding(_currentBuilding.id),
      onSuccess: () => Navigator.pop(context),
    );
}

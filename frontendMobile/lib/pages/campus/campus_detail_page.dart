import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/campus.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/detail_row.dart';
import 'campus_form_page.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(_currentCampus.name.toUpperCase()),
        actions: [
          if (UserSession.can('locations.manage'))
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Wysig',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CampusFormPage(campus: _currentCampus, startEditing: true),
                  ),
                );
                if (result == true && mounted) {
                  final updated = CampusService.campusesNotifier.value
                      .where((c) => c.id == _currentCampus.id)
                      .firstOrNull;
                  if (updated != null) {
                    setState(() => _currentCampus = updated);
                  }
                }
              },
            ),
          if (UserSession.can('locations.manage'))
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
            const SizedBox(height: 25),
            _buildSectionHeader("Ligging op Kaart"),
            const SizedBox(height: 12),
            _buildMapCard(),
            const SizedBox(height: 25),
            _buildSectionHeader("Geboue (${_currentCampus.buildings.length})"),
            const SizedBox(height: 12),
            _currentCampus.buildings.isEmpty
                ? _buildEmptyState("Geen geboue geregistreer nie.")
                : _buildBuildingsList(),
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
          DetailRow(
              label: "Naam",
              valueWidget: Flexible(
                child: Text(_currentCampus.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Tipe / Kode",
              valueWidget: Flexible(
                child: Text(_currentCampus.code,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Straatnommer",
              valueWidget: Flexible(
                child: Text(
                    _currentCampus.streetNum.isEmpty
                        ? "-"
                        : _currentCampus.streetNum,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Straatnaam",
              valueWidget: Flexible(
                child: Text(
                    _currentCampus.streetName.isEmpty
                        ? "-"
                        : _currentCampus.streetName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Voorstad",
              valueWidget: Flexible(
                child: Text(
                    _currentCampus.suburb.isEmpty
                        ? "-"
                        : _currentCampus.suburb,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Stad",
              valueWidget: Flexible(
                child: Text(
                    _currentCampus.city.isEmpty ? "-" : _currentCampus.city,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Provinsie",
              valueWidget: Flexible(
                child: Text(
                    _currentCampus.province.isEmpty
                        ? "-"
                        : _currentCampus.province,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Land",
              valueWidget: Flexible(
                child: Text(
                    _currentCampus.country.isEmpty
                        ? "-"
                        : _currentCampus.country,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Radius",
              valueWidget: Flexible(
                child: Text(
                    "${_currentCampus.radius.toStringAsFixed(0)} m",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    final loc = _currentCampus.location;
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
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Lat: ${loc.latitude.toStringAsFixed(6)}, Lng: ${loc.longitude.toStringAsFixed(6)}",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.radio_button_checked,
                  color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                "Radius: ${_currentCampus.radius.toStringAsFixed(0)} m",
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingsList() {
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
        itemCount: _currentCampus.buildings.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final b = _currentCampus.buildings[index];
          return ListTile(
            leading: const Icon(Icons.location_city,
                color: AppColors.navy, size: 28),
            title: Text(b.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("${b.rooms?.length ?? 0} lokale",
                style: const TextStyle(fontSize: 12)),
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
      entityLabel: 'terrein',
      itemName: _currentCampus.name,
      delete: () => CampusService.removeCampus(_currentCampus.id),
      onSuccess: () => Navigator.pop(context),
    );
}

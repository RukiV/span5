import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/campus.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
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
          _buildDetailRow("Naam",
              Text(_currentCampus.name, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Tipe / Kode",
              Text(_currentCampus.code, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Straatnommer",
              Text(_currentCampus.streetNum.isEmpty ? "-" : _currentCampus.streetNum, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Straatnaam",
              Text(_currentCampus.streetName.isEmpty ? "-" : _currentCampus.streetName, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Voorstad",
              Text(_currentCampus.suburb.isEmpty ? "-" : _currentCampus.suburb, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Stad",
              Text(_currentCampus.city.isEmpty ? "-" : _currentCampus.city, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Provinsie",
              Text(_currentCampus.province.isEmpty ? "-" : _currentCampus.province, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Land",
              Text(_currentCampus.country.isEmpty ? "-" : _currentCampus.country, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Radius",
              Text("${_currentCampus.radius.toStringAsFixed(0)} m", style: const TextStyle(fontWeight: FontWeight.bold))),
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder Terrein"),
        content:
            Text("Is jy seker jy wil '${_currentCampus.name}' verwyder? Alle geboue, lokale en bates onder hierdie terrein sal ook verwyder word."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Kanselleer"),
          ),
          TextButton(
            onPressed: () async {
              final success =
                  await CampusService.removeCampus(_currentCampus.id);
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

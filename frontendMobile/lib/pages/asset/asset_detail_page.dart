import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/campus_service.dart';
import '../../widgets/status_badge.dart';
import '../../core/app_colors.dart';
import '../../models/asset.dart';
import '../../services/asset_service.dart';
import '../../services/report_service.dart';
import '../../models/user_session.dart';
import '../reporting/report_detail_page.dart';
import 'asset_form_page.dart';
import '../room_checklist/room_checklist_page.dart';

class AssetDetailPage extends StatefulWidget {
  final Asset asset;

  const AssetDetailPage({super.key, required this.asset});

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  late Asset _currentAsset;

  @override
  void initState() {
    super.initState();
    _currentAsset = widget.asset;
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final relatedReports = ReportService.reportsNotifier.value
        .where((r) =>
            r.assetId == _currentAsset.id ||
            r.assetId == _currentAsset.serialCode)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(_currentAsset.name.toUpperCase()),
        actions: [
          if (UserSession.can('assets.manage') && _currentAsset.location != '1')
            IconButton(
              icon: const Icon(Icons.checklist, color: Colors.white),
              tooltip: "Kontroleer lokaal",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomChecklistPage(
                      roomId: int.parse(_currentAsset.location)),
                ),
              ),
            ),
          if (UserSession.can('assets.manage'))
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          AssetFormPage(asset: _currentAsset)),
                );
                if (result == true && mounted) {
                  setState(() {
                    final updated =
                        AssetService.assetsNotifier.value.firstWhere(
                      (a) => a.id == _currentAsset.id,
                      orElse: () => _currentAsset,
                    );
                    _currentAsset = updated;
                  });
                }
              },
            ),
          if (UserSession.can('assets.manage'))
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Besonderhede Seksie
            _buildSectionHeader("Besonderhede"),
            const SizedBox(height: 12),
            _buildInfoCard(),

            const SizedBox(height: 25),

            // Identifikasie Seksie
            _buildSectionHeader("Identifikasie"),
            const SizedBox(height: 12),
            _buildQRCard(),

            const SizedBox(height: 25),

            // Verslag Geskiedenis
            _buildSectionHeader("Verslag Geskiedenis"),
            const SizedBox(height: 12),
            relatedReports.isEmpty
                ? _buildEmptyState("Geen rapporterings vir hierdie bate nie.")
                : _buildReportList(relatedReports),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(
              "Kampus",
              Text(CampusService.getCampusNameByRoomId(_currentAsset.location),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Gebou",
              Text(
                  CampusService.getBuildingNameByRoomId(_currentAsset.location),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Lokaal",
              Text(CampusService.getRoomName(_currentAsset.location),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Plasing",
              Text(_currentAsset.isOutdoor ? "Buite" : "Binne",
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Kategorie",
              Text(_currentAsset.category,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow(
              "Handelsmerk",
              Text(_currentAsset.brand.isEmpty ? "-" : _currentAsset.brand,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Status", StatusBadge(status: _currentAsset.status)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        value,
      ],
    );
  }

  Widget _buildQRCard() {
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
            Text(_currentAsset.serialCode,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                    fontSize: 18,
                    letterSpacing: 1.5)),
            const SizedBox(height: 20),
            QrImageView(
              data: _currentAsset.serialCode,
              size: 160,
              version: QrVersions.auto,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList(List relatedReports) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: relatedReports.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final r = relatedReports[index];
          return ListTile(
            title: Text(r.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(r.timestamp.toString().split('.')[0],
                style: const TextStyle(fontSize: 12)),
            trailing: StatusBadge(status: r.phase),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ReportDetailPage(report: r))),
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder Bate"),
        content: Text("Is jy seker jy wil '${_currentAsset.name}' verwyder?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Kanselleer")),
          TextButton(
            onPressed: () async {
              final success = await AssetService.deleteAsset(_currentAsset.id);
              if (!mounted) return;
              if (success) {
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
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

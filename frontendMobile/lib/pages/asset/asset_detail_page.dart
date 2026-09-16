import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/campus_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/detail_row.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/idempotency.dart';
import '../../models/asset.dart';
import '../../models/room.dart';
import '../../services/asset_service.dart';
import '../../services/report_service.dart';
import '../../services/wrong_room_service.dart';
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
  AssetState? _assetState;
  bool _savingFound = false;

  @override
  void initState() {
    super.initState();
    _currentAsset = widget.asset;
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _loadAssetState();
  }

  Future<void> _loadAssetState() async {
    final state = await WrongRoomService.getAssetState(_currentAsset.id);
    if (mounted) {
      setState(() => _assetState = state);
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
            if (_assetState != null && !_assetState!.isClear) ...[
              _buildWrongRoomBanner(),
              const SizedBox(height: 20),
            ],
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

  Widget _buildWrongRoomBanner() {
    final state = _assetState!;
    final isWrongRoom = state.isWrongRoom;
    final color = isWrongRoom ? AppColors.warningOrange : AppColors.errorRed;
    final foundRoom = state.foundRoomName ?? 'onbekende lokaal';
    String message;
    if (isWrongRoom) {
      message = "Gevind in $foundRoom — wag om terug te skuif";
    } else {
      message = "Vermis in $foundRoom (laaste kontrole)";
    }
    final canMarkFound = UserSession.can('room_checks.manage') ||
        UserSession.can('roomchecks.execute');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(isWrongRoom ? Icons.place : Icons.highlight_off, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWrongRoom
                      ? "BATE GEVIND IN VERKEERDE LOKAAL"
                      : "BATE VERMIS",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 13)),
                if (canMarkFound) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _savingFound
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: _showMarkFoundSheet,
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text("Merk as gevind"),
                            style: TextButton.styleFrom(
                              foregroundColor: color,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMarkFoundSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "BATE GEVIND",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text("Gevind in sy aangewese lokaal"),
              subtitle: Text(CampusService.getRoomName(_currentAsset.location)),
              onTap: () {
                Navigator.pop(sheetContext);
                _markFoundInOwnRoom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text("Gevind in 'n ander lokaal"),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFoundRoom();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _markFoundInOwnRoom() async {
    setState(() => _savingFound = true);
    try {
      await ApiClient().client.post(
            '/room-checks',
            data: {
              'room_id': int.tryParse(_currentAsset.location) ?? 0,
              'summary': jsonEncode([
                {
                  'asset_id': int.tryParse(_currentAsset.id) ?? 0,
                  'status': 'confirmed'
                }
              ]),
            },
            options:
                Options(headers: {'X-Idempotency-Key': Idempotency.generate()}),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bate is in sy aangewese lokaal as gevind aangeteken."),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _loadAssetState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Kon nie die bate as gevind aanteken nie: $e"),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingFound = false);
    }
  }

  Future<void> _pickFoundRoom() async {
    final campuses = CampusService.campusesNotifier.value;
    if (campuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Geen kampusinligting beskikbaar nie."),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }
    final room = await showDialog<Room>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Kies lokaal"),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final campus in campuses)
                ExpansionTile(
                  title: Text(campus.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: [
                    for (final building in campus.buildings)
                      ...building.rooms?.isNotEmpty == true
                          ? [
                              ExpansionTile(
                                title: Text(building.name,
                                    style: const TextStyle(fontSize: 14)),
                                children: [
                                  for (final r in building.rooms!)
                                    ListTile(
                                      dense: true,
                                      title: Text(r.name,
                                          style: const TextStyle(fontSize: 14)),
                                      onTap: () =>
                                          Navigator.pop(dialogContext, r),
                                    ),
                                ],
                              ),
                            ]
                          : [],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    if (room == null || !mounted) return;
    setState(() => _savingFound = true);
    final originalFaultId = int.tryParse(_assetState?.faultId ?? '');
    final fault = await WrongRoomService.markFoundInRoom(
      _currentAsset.id,
      room.id,
      originalFaultId: originalFaultId,
    );
    if (!mounted) return;
    setState(() => _savingFound = false);
    if (fault != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Bate is in ${room.name} as gevind aangeteken."),
          backgroundColor: AppColors.successGreen,
        ),
      );
      _loadAssetState();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie die gevind-status stoor nie."),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
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
DetailRow(
              label: "Kampus",
              valueWidget: Text(
                  CampusService.getCampusNameByRoomId(_currentAsset.location),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          DetailRow(
              label: "Gebou",
              valueWidget: Text(
                  CampusService.getBuildingNameByRoomId(_currentAsset.location),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          DetailRow(
              label: "Lokaal",
              valueWidget: Text(CampusService.getRoomName(_currentAsset.location),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          DetailRow(
              label: "Plasing",
              valueWidget: Text(_currentAsset.isOutdoor ? "Buite" : "Binne",
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          DetailRow(
              label: "Kategorie",
              valueWidget: Text(_currentAsset.category,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          DetailRow(
              label: "Handelsmerk",
              valueWidget: Text(_currentAsset.brand.isEmpty ? "-" : _currentAsset.brand,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          DetailRow(label: "Status", valueWidget: StatusBadge(status: _currentAsset.status)),
        ],
      ),
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

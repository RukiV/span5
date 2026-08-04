import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../core/idempotency.dart';
import '../../models/asset.dart';
import '../../models/user_session.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../services/report_service.dart';
import '../../models/report.dart';
import '../../widgets/status_badge.dart';
import '../reporting/new_report_page.dart';
import '../reporting/scan_page.dart';

enum _CheckStatus { pending, confirmed, faultReported, missing }

class _CheckItem {
  final Asset asset;
  _CheckStatus status = _CheckStatus.pending;
  int? faultId;

  _CheckItem({required this.asset});
}

class RoomChecklistPage extends StatefulWidget {
  final int roomId;

  const RoomChecklistPage({super.key, required this.roomId});

  @override
  State<RoomChecklistPage> createState() => _RoomChecklistPageState();
}

class _RoomChecklistPageState extends State<RoomChecklistPage> {
  List<_CheckItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (AssetService.assetsNotifier.value.isEmpty) {
      AssetService.fetchAssets().then((_) => _filterAssets());
    } else {
      _filterAssets();
    }
  }

  void _filterAssets() {
    final roomIdStr = widget.roomId.toString();
    final allAssets = AssetService.assetsNotifier.value;
    setState(() {
      _items = allAssets
          .where((a) => a.location == roomIdStr)
          .map((a) => _CheckItem(asset: a))
          .toList();
      _isLoading = false;
    });
  }

  int get _confirmedCount => _items.where((i) => i.status == _CheckStatus.confirmed).length;
  int get _faultReportedCount => _items.where((i) => i.status == _CheckStatus.faultReported).length;
  int get _missingCount => _items.where((i) => i.status == _CheckStatus.missing).length;
  int get _pendingCount => _items.where((i) => i.status == _CheckStatus.pending).length;

  int? _buildingIdForRoom() {
    final campuses = CampusService.campusesNotifier.value;
    for (final c in campuses) {
      for (final b in c.buildings) {
        if (b.rooms?.any((r) => r.id == widget.roomId) == true) return b.id;
      }
    }
    return null;
  }

  int? _locationIdForRoom() {
    final campuses = CampusService.campusesNotifier.value;
    for (final c in campuses) {
      for (final b in c.buildings) {
        if (b.rooms?.any((r) => r.id == widget.roomId) == true) return c.id;
      }
    }
    return null;
  }

  String get _roomName {
    return CampusService.getRoomName(widget.roomId.toString());
  }

  String get _buildingName {
    return CampusService.getBuildingNameByRoomId(widget.roomId.toString());
  }

  String get _campusName {
    return CampusService.getCampusNameByRoomId(widget.roomId.toString());
  }

  Future<void> _handleScanResult(String code) async {
    final asset = await AssetService.getAssetBySerialCode(code);
    if (!mounted) return;
    if (asset == null) {
      _showSnack("Geen bate gevind met hierdie kode nie", AppColors.warningOrange);
      return;
    }
    if (asset.location != widget.roomId.toString()) {
      _showSnack("Bate is nie in hierdie lokaal nie", AppColors.warningOrange);
      return;
    }
    final match = _items.where((i) => i.asset.id == asset.id).firstOrNull;
    if (match == null) {
      _showSnack("Bate is nie in die kontrolelys nie", AppColors.warningOrange);
      return;
    }
    if (match.status == _CheckStatus.confirmed) {
      _showSnack("${asset.name} is reeds bevestig", AppColors.successGreen);
      return;
    }
    setState(() => match.status = _CheckStatus.confirmed);
    _showSnack("${asset.name} bevestig", AppColors.successGreen);
  }

  void _openScanner() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (code != null && mounted) _handleScanResult(code);
  }

  void _openManualEntry() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tik Bate Kode"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Kode (bv. AK XX000000)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kanselleer")),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                _handleScanResult(code);
              }
            },
            child: const Text("Bevestig"),
          ),
        ],
      ),
    );
  }

  Future<void> _markMissing(_CheckItem item) async {
    final fault = await _createFaultReport(item.asset, "Bate is nie in lokaal gevind tydens roetine kontrole nie");
    if (!mounted) return;
    if (fault != null) {
      setState(() {
        item.status = _CheckStatus.missing;
        item.faultId = int.tryParse(fault.id);
      });
      _showSnack("${item.asset.name} as vermis gemerk", AppColors.warningOrange);
    } else {
      _showSnack("Kon nie foutkaartjie skep nie", AppColors.errorRed);
    }
  }

  Future<Report?> _createFaultReport(Asset asset, String description) async {
    final report = Report(
      id: "0",
      assetId: asset.id,
      assetSerialCode: asset.serialCode,
      location: widget.roomId.toString(),
      title: "Bate vermis: ${asset.name}",
      description: description,
      category: "Instandhouding",
      priority: "Medium",
      phase: "Ontvang",
      user: UserSession.userId.toString(),
      timestamp: DateTime.now(),
      locationId: _locationIdForRoom(),
      buildingId: _buildingIdForRoom(),
    );
    return ReportService.addReport(report);
  }

  void _showAssetActions(_CheckItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.asset.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                "Kode: ${item.asset.serialCode}",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Divider(height: 24),
              if (item.status == _CheckStatus.pending) ...[
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner, color: AppColors.navy),
                  title: const Text("Skandeer kode"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openScanner();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.keyboard, color: AppColors.navy),
                  title: const Text("Tik kode"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openManualEntry();
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.report_problem, color: AppColors.warningOrange),
                title: const Text("Meld fout (beskadigde kode / ander probleem)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportFault(item);
                },
              ),
              if (item.status == _CheckStatus.pending)
                ListTile(
                  leading: const Icon(Icons.highlight_off, color: AppColors.errorRed),
                  title: const Text("Merk as vermis"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _markMissing(item);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reportFault(_CheckItem item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewReportPage(prefillSerialCode: item.asset.serialCode),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() {
        item.status = _CheckStatus.faultReported;
      });
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _complete() async {
    _idempotencyKey ??= Idempotency.generate();
    if (_pendingCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Hangende bates"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Die volgende bates is nie nagegaan nie. Foutkaartjies sal outomaties geskep word:"),
              const SizedBox(height: 12),
              ..._items
                  .where((i) => i.status == _CheckStatus.pending)
                  .map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.warningOrange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(i.asset.name, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Kanselleer")),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Skep foutkaartjies & voltooi"),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSaving = true);

    for (final item in _items.where((i) => i.status == _CheckStatus.pending)) {
      final fault = await _createFaultReport(item.asset, "Bate is nie in lokaal gevind tydens roetine kontrole nie");
      if (fault != null) {
        item.status = _CheckStatus.missing;
        item.faultId = int.tryParse(fault.id);
      }
    }

    final summary = _items.map((i) {
      String status;
      if (i.status == _CheckStatus.confirmed) {
        status = "confirmed";
      } else if (i.status == _CheckStatus.missing || i.status == _CheckStatus.pending) {
        status = "missing";
      } else {
        status = "fault_reported";
      }
      final entry = <String, dynamic>{'asset_id': int.tryParse(i.asset.id) ?? 0, 'status': status};
      final fid = i.faultId;
      if (fid != null) entry['fault_id'] = fid;
      return entry;
    }).toList();

    try {
      await ApiClient().client.post(
        '/room-checks',
        data: {
          'room_id': widget.roomId,
          'summary': jsonEncode(summary),
        },
        options: Options(headers: {'X-Idempotency-Key': _idempotencyKey!}),
      );
      if (!mounted) return;
      _idempotencyKey = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Kontrole voltooi: $_confirmedCount bevestig, $_faultReportedCount foute, $_missingCount vermis"),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack("Fout met stoor: $e", AppColors.errorRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text("KONTROLE LOKAAL"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text("Geen bates in hierdie lokaal nie."))
              : Column(
                  children: [
                    _buildHeader(),
                    _buildProgressBar(),
                    const Divider(height: 1),
                    Expanded(child: _buildAssetList()),
                  ],
                ),
      floatingActionButton: (_items.isEmpty || _isSaving)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: "scanChecklist",
                  backgroundColor: AppColors.navy,
                  onPressed: _openScanner,
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "typeCode",
                  backgroundColor: AppColors.gold,
                  onPressed: _openManualEntry,
                  child: const Icon(Icons.keyboard, color: Colors.white),
                ),
              ],
            ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _complete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5E34),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("VOLTOOI ($_confirmedCount / ${_items.length} bevestig)"),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_roomName.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
          if (_buildingName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text("$_buildingName → $_campusName",
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _progressChip("Bevestig", _confirmedCount, AppColors.successGreen),
            const SizedBox(width: 8),
            _progressChip("Foute", _faultReportedCount, AppColors.warningOrange),
            const SizedBox(width: 8),
            _progressChip("Vermis", _missingCount, AppColors.errorRed),
            if (_pendingCount > 0) ...[
              const SizedBox(width: 8),
              _progressChip("Hangend", _pendingCount, Colors.grey),
            ],
          ],
        ),
      ),
    );
  }

  Widget _progressChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text("$label: $count",
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildAssetList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            title: Text(item.asset.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              "Kode: ${item.asset.serialCode}",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: StatusBadge(status: item.asset.status, fontSize: 12),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey[300],
                ),
                const SizedBox(width: 8),
                _statusIcon(item.status),
              ],
            ),
            onTap: item.status == _CheckStatus.pending
                ? () => _showAssetActions(item)
                : null,
          ),
        );
      },
    );
  }

  Widget _statusIcon(_CheckStatus status) {
    switch (status) {
      case _CheckStatus.confirmed:
        return const Icon(Icons.check_circle, color: AppColors.successGreen, size: 28);
      case _CheckStatus.faultReported:
        return const Icon(Icons.warning, color: AppColors.warningOrange, size: 28);
      case _CheckStatus.missing:
        return const Icon(Icons.highlight_off, color: AppColors.errorRed, size: 28);
      case _CheckStatus.pending:
        return const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 28);
    }
  }
}

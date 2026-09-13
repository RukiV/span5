import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../core/idempotency.dart';
import '../../models/asset.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../services/report_service.dart';
import '../../services/wrong_room_service.dart';
import '../../models/report.dart';
import '../../widgets/status_badge.dart';
import '../reporting/new_report_page.dart';
import '../reporting/scan_page.dart';
import 'room_check_history_page.dart';

enum _CheckStatus { pending, confirmed, faultReported, missing }

class _CheckItem {
  final Asset asset;
  _CheckStatus status = _CheckStatus.pending;
  int? faultId;
  bool previouslyMissing = false;

  _CheckItem({required this.asset});
}

class RoomChecklistPage extends StatefulWidget {
  final int? roomId;

  const RoomChecklistPage({super.key, this.roomId});

  @override
  State<RoomChecklistPage> createState() => _RoomChecklistPageState();
}

class _RoomChecklistPageState extends State<RoomChecklistPage> {
  List<_CheckItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _idempotencyKey;

  // Cascade selection state (used when widget.roomId is null)
  int? _selectedCampusId;
  int? _selectedBuildingId;

  @override
  void initState() {
    super.initState();
    if (widget.roomId != null) {
      _load();
    }
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  void _load() {
    if (AssetService.assetsNotifier.value.isEmpty) {
      AssetService.fetchAssets().then((_) => _filterAssets());
    } else {
      _filterAssets();
    }
    _populatePrevious(widget.roomId!);
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

  Future<void> _populatePrevious(int roomId) async {
    final missingIds = await _fetchPreviousMissing(roomId);
    if (!mounted || missingIds.isEmpty) return;
    setState(() {
      for (final item in _items) {
        if (missingIds.contains(item.asset.id)) {
          item.status = _CheckStatus.missing;
          item.previouslyMissing = true;
        }
      }
    });
  }

  Future<Set<String>> _fetchPreviousMissing(int roomId) async {
    try {
      final response = await ApiClient().client.get('/room-checks',
          queryParameters: {'room_id': roomId, 'limit': 1});
      final List data = response.data as List;
      if (data.isEmpty) return {};
      final summary = jsonDecode(data[0]['summary']) as List;
      return summary
          .where((e) => e['status'] == 'missing')
          .map((e) => e['asset_id'].toString())
          .toSet();
    } catch (_) {
      return {};
    }
  }

  int get _confirmedCount =>
      _items.where((i) => i.status == _CheckStatus.confirmed).length;
  int get _faultReportedCount =>
      _items.where((i) => i.status == _CheckStatus.faultReported).length;
  int get _missingCount =>
      _items.where((i) => i.status == _CheckStatus.missing).length;
  int get _pendingCount =>
      _items.where((i) => i.status == _CheckStatus.pending).length;
  int get _activeRoomId => widget.roomId ?? 0;

  String get _roomName {
    return CampusService.getRoomName(_activeRoomId.toString());
  }

  String get _buildingName {
    return CampusService.getBuildingNameByRoomId(_activeRoomId.toString());
  }

  String get _campusName {
    return CampusService.getCampusNameByRoomId(_activeRoomId.toString());
  }

  int? _buildingIdForRoom() {
    final campuses = CampusService.campusesNotifier.value;
    for (final c in campuses) {
      for (final b in c.buildings) {
        if (b.rooms?.any((r) => r.id == _activeRoomId) == true) return b.id;
      }
    }
    return null;
  }

  int? _locationIdForRoom() {
    final campuses = CampusService.campusesNotifier.value;
    for (final c in campuses) {
      for (final b in c.buildings) {
        if (b.rooms?.any((r) => r.id == _activeRoomId) == true) return c.id;
      }
    }
    return null;
  }

  Future<void> _handleScanResult(String code) async {
    final asset = await AssetService.getAssetBySerialCode(code);
    if (!mounted) return;
    if (asset == null) {
      _showSnack(
          "Geen bate gevind met hierdie kode nie", AppColors.warningOrange);
      return;
    }
    if (asset.location != _activeRoomId.toString()) {
      await _handleScanNotInRoom(asset);
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
    if (match.status == _CheckStatus.missing && match.previouslyMissing) {
      setState(() => match.status = _CheckStatus.confirmed);
      _showSnack("${asset.name} gevind en as teenwoordig gemerk (was vermis)",
          AppColors.successGreen);
      return;
    }
    setState(() => match.status = _CheckStatus.confirmed);
    _showSnack("${asset.name} bevestig", AppColors.successGreen);
  }

  Future<void> _handleScanNotInRoom(Asset asset) async {
    final state = await WrongRoomService.getAssetState(asset.id);
    if (!mounted) return;
    if (state == null) {
      _showSnack("Bate is nie in hierdie lokaal nie", AppColors.warningOrange);
      return;
    }
    final bool wasMissing = state.isMissing || state.isWrongRoom;
    if (!wasMissing) {
      _showSnack("Bate is nie in hierdie lokaal nie", AppColors.warningOrange);
      return;
    }
    final foundRoom = state.foundRoomName ?? 'onbekende lokaal';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Bate in verkeerde lokaal"),
        content: Text(
          "${asset.name} is as vermis gemerk (in $foundRoom). Word dit hier gevind? "
          "Skuif na die toegewese lokaal en meld as gevind.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Kanselleer")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ja, hier gevind"),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final fault = await WrongRoomService.markFoundInRoom(
      asset.id,
      _activeRoomId,
      originalFaultId: int.tryParse(state.faultId ?? ''),
    );
    if (!mounted) return;
    if (fault != null) {
      _showSnack("${asset.name} gemeld as gevind in hierdie lokaal",
          AppColors.successGreen);
    } else {
      _showSnack("Kon nie die gevind-status stoor nie", AppColors.errorRed);
    }
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Kanselleer")),
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
    final fault = await _createFaultReport(
        item.asset, "Bate is nie in lokaal gevind tydens roetine kontrole nie");
    if (!mounted) return;
    if (fault != null) {
      setState(() {
        item.status = _CheckStatus.missing;
        item.faultId = int.tryParse(fault.id);
      });
      _showSnack(
          "${item.asset.name} as vermis gemerk", AppColors.warningOrange);
    } else {
      _showSnack("Kon nie foutkaartjie skep nie", AppColors.errorRed);
    }
  }

  Future<Report?> _createFaultReport(Asset asset, String description) async {
    final report = Report(
      id: "0",
      assetId: asset.id,
      assetSerialCode: asset.serialCode,
      location: _activeRoomId.toString(),
      title: "Bate vermis: ${asset.name}",
      description: description,
      category: "Onderhoud",
      priority: "Medium",
      phase: "Ontvang",
      user: UserSession.userId.toString(),
      timestamp: DateTime.now(),
      locationId: _locationIdForRoom(),
      buildingId: _buildingIdForRoom(),
      isOutdoor: true,
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                "Kode: ${item.asset.serialCode}",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              if (item.previouslyMissing)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("Vermis in vorige kontrole",
                      style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ),
              const Divider(height: 24),
              if (item.status == _CheckStatus.pending ||
                  item.previouslyMissing) ...[
                ListTile(
                  leading:
                      const Icon(Icons.qr_code_scanner, color: AppColors.navy),
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
                leading: const Icon(Icons.report_problem,
                    color: AppColors.warningOrange),
                title:
                    const Text("Meld fout (beskadigde kode / ander probleem)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportFault(item);
                },
              ),
              if (item.status == _CheckStatus.pending)
                ListTile(
                  leading: const Icon(Icons.highlight_off,
                      color: AppColors.errorRed),
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

  void _uncheckItem(_CheckItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Herroep"),
        content: Text(
            "Herroep ${item.asset.name}? Dit sal die status terugstel na hangend."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Kanselleer")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                item.status = _CheckStatus.pending;
                item.previouslyMissing = false;
              });
            },
            child: const Text("Herroep"),
          ),
        ],
      ),
    );
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
              const Text(
                  "Die volgende bates is nie nagegaan nie. Foutkaartjies sal outomaties geskep word:"),
              const SizedBox(height: 12),
              ..._items
                  .where((i) => i.status == _CheckStatus.pending)
                  .map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.warningOrange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(i.asset.name,
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Kanselleer")),
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
      final fault = await _createFaultReport(item.asset,
          "Bate is nie in lokaal gevind tydens roetine kontrole nie");
      if (fault != null) {
        item.status = _CheckStatus.missing;
        item.faultId = int.tryParse(fault.id);
      }
    }

    final summary = _items.map((i) {
      String status;
      if (i.status == _CheckStatus.confirmed) {
        status = "confirmed";
      } else if (i.status == _CheckStatus.missing ||
          i.status == _CheckStatus.pending) {
        status = "missing";
      } else {
        status = "fault_reported";
      }
      final entry = <String, dynamic>{
        'asset_id': int.tryParse(i.asset.id) ?? 0,
        'status': status
      };
      final fid = i.faultId;
      if (fid != null) entry['fault_id'] = fid;
      return entry;
    }).toList();

    try {
      await ApiClient().client.post(
            '/room-checks',
            data: {
              'room_id': _activeRoomId,
              'summary': jsonEncode(summary),
            },
            options: Options(headers: {'X-Idempotency-Key': _idempotencyKey!}),
          );
      if (!mounted) return;
      _idempotencyKey = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Kontrole voltooi: $_confirmedCount bevestig, $_faultReportedCount foute, $_missingCount vermis"),
          backgroundColor: AppColors.successGreen,
        ),
      );
      if (widget.roomId != null) {
        Navigator.pop(context, true);
      }
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
        title: Text(widget.roomId != null && _items.isNotEmpty
            ? "KONTROLE LOKAAL"
            : "Lokaal Kontrole"),
        actions: [
          if (widget.roomId != null && _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              tooltip: "Geskiedenis",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomCheckHistoryPage(roomId: _activeRoomId),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton:
          widget.roomId != null && _items.isNotEmpty && !_isSaving
              ? _buildFab()
              : null,
      bottomNavigationBar:
          widget.roomId != null && _items.isNotEmpty ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (widget.roomId == null) {
      return _buildSelectionView();
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text("Geen bates in hierdie lokaal nie."),
      );
    }
    return Column(
      children: [
        _buildHeader(),
        _buildProgressBar(),
        const Divider(height: 1),
        Expanded(child: _buildAssetList()),
      ],
    );
  }

  Widget _buildSelectionView() {
    return ValueListenableBuilder<List<Campus>>(
      valueListenable: CampusService.campusesNotifier,
      builder: (context, campuses, _) {
        if (campuses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final selectedCampus = _selectedCampusId != null
            ? campuses.where((c) => c.id == _selectedCampusId).firstOrNull
            : null;
        final buildings = selectedCampus?.buildings ?? [];
        final selectedBuilding = _selectedBuildingId != null
            ? buildings.where((b) => b.id == _selectedBuildingId).firstOrNull
            : null;
        final rooms = selectedBuilding?.rooms ??
            selectedCampus?.buildings.expand((b) => b.rooms ?? []).toList() ??
            [];
        final roomBuildingNames = <int, String>{
          for (final b in buildings)
            for (final r in (b.rooms ?? [])) r.id: b.name,
        };

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("KIES LOKAAL OM TE KONTROLEER",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.navy)),
                  const SizedBox(height: 20),
                  const Text("Terrein",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  _buildDropdown<int>(
                    value: _selectedCampusId,
                    hint: "Kies terrein",
                    items: campuses
                        .map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _selectedCampusId = val;
                      _selectedBuildingId = null;
                    }),
                  ),
                  if (_selectedCampusId != null) ...[
                    const SizedBox(height: 16),
                    const Text("Gebou",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    _buildDropdown<int>(
                      value: _selectedBuildingId,
                      hint: "Kies gebou",
                      items: buildings
                          .map((b) => DropdownMenuItem(
                              value: b.id, child: Text(b.name)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedBuildingId = val),
                    ),
                  ],
                  if (_selectedCampusId != null) ...[
                    const SizedBox(height: 20),
                    const Text("LOKALE",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 10),
                    if (rooms.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                            child: Text("Geen lokale op hierdie terrein nie.",
                                style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...rooms.map((room) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(room.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        Text(
                                          _selectedBuildingId != null
                                              ? "${room.type} | Kap: ${room.capacity ?? '-'}"
                                              : "${room.type} | Kap: ${room.capacity ?? '-'} | ${roomBuildingNames[room.id] ?? ''}",
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final done = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RoomChecklistPage(
                                              roomId: room.id),
                                        ),
                                      );
                                      if (done == true && mounted) {
                                        // ignore: use_build_context_synchronously
                                        Navigator.pop(context, true);
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF8B5E34)),
                                    child: const Text("Begin Kontrole",
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RoomCheckHistoryPage(
                                            roomId: room.id),
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey),
                                    child: const Text("Geskiedenis",
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          )),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget? _buildFab() {
    return Column(
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
    );
  }

  Widget? _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _complete,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5E34),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text("VOLTOOI ($_confirmedCount / ${_items.length} bevestig)"),
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.navy)),
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
            _progressChip(
                "Foute", _faultReportedCount, AppColors.warningOrange),
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
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            title: Text(item.asset.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Kode: ${item.asset.serialCode}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (item.previouslyMissing &&
                    item.status == _CheckStatus.missing)
                  Text("Vermis in vorige kontrole",
                      style:
                          TextStyle(fontSize: 10, color: Colors.orange[700])),
              ],
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
                _statusIcon(item),
              ],
            ),
            onTap: () {
              if (item.status == _CheckStatus.pending ||
                  item.previouslyMissing) {
                _showAssetActions(item);
              } else {
                _uncheckItem(item);
              }
            },
          ),
        );
      },
    );
  }

  Widget _statusIcon(_CheckItem item) {
    switch (item.status) {
      case _CheckStatus.confirmed:
        return const Icon(Icons.check_circle,
            color: AppColors.successGreen, size: 28);
      case _CheckStatus.faultReported:
        return const Icon(Icons.warning,
            color: AppColors.warningOrange, size: 28);
      case _CheckStatus.missing:
        if (item.previouslyMissing) {
          return const Icon(Icons.schedule, color: Colors.orange, size: 28);
        }
        return const Icon(Icons.highlight_off,
            color: AppColors.errorRed, size: 28);
      case _CheckStatus.pending:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.grey, size: 28);
    }
  }
}

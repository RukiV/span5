import 'package:flutter/material.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/inline_searchable_dropdown.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../models/asset.dart';
import 'asset_detail_page.dart';
import 'asset_form_page.dart';
import 'manage_asset_types_page.dart';
import '../../models/user_session.dart';
import '../reporting/scan_page.dart';
import '../room_checklist/room_check_history_page.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/selection_manager.dart';
import '../../widgets/card_data_row.dart';

class AssetsPage extends StatefulWidget {
  final String? filterRoomId;
  final bool inShell;
  const AssetsPage({
    super.key,
    this.filterRoomId,
    this.inShell = false,
  });

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = "Almal";
  int? _selectedCampusId;
  int? _selectedBuildingId;
  int? _selectedRoomId;
  final ColumnVisibilityController _colVis = ColumnVisibilityController([
    const ColumnDef(key: 'id', label: '#ID', defaultVisible: false),
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'brand', label: 'Handelsmerk', defaultVisible: false),
    const ColumnDef(key: 'serial', label: 'Serienommer', defaultVisible: false),
    const ColumnDef(key: 'type', label: 'Tipe', defaultVisible: false),
    const ColumnDef(key: 'isOutdoor', label: 'Buite', defaultVisible: false),
    const ColumnDef(key: 'status', label: 'Status'),
    const ColumnDef(key: 'created', label: 'Geskep', defaultVisible: false),
  ]);
  final SelectionController<String> _selection = SelectionController<String>();
  late String? _activeRoomFilter;

  @override
  void initState() {
    super.initState();
    _colVis.addListener(_onColumnVisibilityChanged);
    _activeRoomFilter = widget.filterRoomId;
    AssetService.fetchAssets();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant AssetsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterRoomId != null &&
        widget.filterRoomId != _activeRoomFilter) {
      _activeRoomFilter = widget.filterRoomId;
    }
  }

  void _onCampusesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onColumnVisibilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
    _colVis.removeListener(_onColumnVisibilityChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _scanToIdentify() async {
    final String? scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );

    if (scannedCode != null) {
      final asset = await AssetService.getAssetBySerialCode(scannedCode);
      if (mounted) {
        if (asset != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AssetDetailPage(asset: asset)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Bate nie gevind nie."),
                backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: !widget.inShell && _activeRoomFilter != null
          ? AppBar(
              title: const Text("Bates in Lokaal"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: "Geskiedenis",
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomCheckHistoryPage(
                          roomId: int.parse(widget.filterRoomId!)),
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          FixedPageHeader(
            controller: _searchController,
            hintText: "Soek bates...",
            onChanged: (v) => setState(() {}),
            actions: _buildHeaderActions(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => AssetService.fetchAssets(),
              color: AppColors.refreshSpinner,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAssetListSliver(),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  List<Widget> _buildHeaderActions() {
    final locationActive = _selectedCampusId != null ||
        _selectedBuildingId != null ||
        _selectedRoomId != null;
    return [
      HeaderIconAction(
        icon: Icons.place_outlined,
        tooltip: "Filter op Ligging",
        activeBadge: locationActive,
        onTap: () => showLocationFilterSheet(
          context,
          depth: LocationDepth.room,
          campusId: _selectedCampusId,
          buildingId: _selectedBuildingId,
          roomId: _selectedRoomId,
          onChanged: (campusId, buildingId, roomId) => setState(() {
            _selectedCampusId = campusId;
            _selectedBuildingId = buildingId;
            _selectedRoomId = roomId;
          }),
        ),
      ),
      HeaderIconAction(
        icon: Icons.filter_alt_outlined,
        tooltip: "Status",
        activeBadge: _statusFilter != "Almal",
        onTap: () => showSearchableDialog<String>(
          context: context,
          title: "Status",
          initialValue: _statusFilter,
          items: const ["Almal", "Aktief", "Onderhoud", "Afgedank", "Onaktief"]
              .map((s) => InlineSearchableDropdownItem(value: s, label: s))
              .toList(),
          onSelected: (val) =>
              setState(() => _statusFilter = val ?? _statusFilter),
        ),
      ),
      if (UserSession.can('assets.manage'))
        HeaderIconAction(
          icon: Icons.settings_outlined,
          tooltip: "Bate Tipes",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageAssetTypesPage()),
          ),
        ),
      if (UserSession.can('assets.manage')) ...[
        SelectionExitAction<String>(
          controller: _selection,
          onExit: () => setState(() => _selection.exit()),
        ),
      ],
      ColumnVisibilityButton(controller: _colVis),
    ];
  }

  List<Asset> _visibleAssets(String query) {
    final campuses = CampusService.campusesNotifier.value;

    final campusRoomIds = _selectedCampusId != null
        ? campuses
            .where((c) => c.id == _selectedCampusId)
            .expand((c) => c.buildings)
            .expand((b) => b.rooms ?? [])
            .map((r) => r.id.toString())
            .toSet()
        : null;
    final buildingRoomIds = _selectedBuildingId != null
        ? campuses
            .expand((c) => c.buildings)
            .where((b) => b.id == _selectedBuildingId)
            .expand((b) => b.rooms ?? [])
            .map((r) => r.id.toString())
            .toSet()
        : null;

    return AssetService.assetsNotifier.value.where((a) {
      if (_activeRoomFilter != null && a.location != _activeRoomFilter) {
        return false;
      }

      if (campusRoomIds != null && !campusRoomIds.contains(a.location)) {
        return false;
      }

      if (buildingRoomIds != null && !buildingRoomIds.contains(a.location)) {
        return false;
      }

      if (_selectedRoomId != null && a.location != _selectedRoomId.toString()) {
        return false;
      }

      if (_statusFilter != "Almal") {
        String mapped = "active";
        if (_statusFilter == "Onderhoud") mapped = "maintenance";
        if (_statusFilter == "Afgedank") mapped = "retired";
        if (_statusFilter == "Onaktief") mapped = "inactive";
        if (a.status.toLowerCase() != mapped) return false;
      }

      return a.name.toLowerCase().contains(query) ||
          a.serialCode.toLowerCase().contains(query) ||
          a.id.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildAssetListSliver() {
    return ValueListenableBuilder<List<Asset>>(
      valueListenable: AssetService.assetsNotifier,
      builder: (context, allAssets, _) {
        final filtered = _visibleAssets(_searchController.text.toLowerCase());

        if (filtered.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: Text("Geen bates gevind nie.")),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final asset = filtered[index];
              return Column(
                children: [
                  _buildAssetRow(asset),
                ],
              );
            },
            childCount: filtered.length,
          ),
        );
      },
    );
  }

  Widget _buildAssetRow(Asset asset) {
    return CardDataRow(
      leading: _selection.isSelecting
          ? Checkbox(
              value: _selection.isSelected(asset.id),
              onChanged: (_) => setState(() => _selection.toggle(asset.id)),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
      onTap: () {
        if (_selection.isSelecting) {
          setState(() => _selection.toggle(asset.id));
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AssetDetailPage(asset: asset)));
        }
      },
      onLongPress: () {
        if (!UserSession.can('assets.manage')) return;
        setState(() {
          _selection.enter();
          _selection.toggle(asset.id);
        });
      },
      children: _colVis.visibleColumns.map((col) {
        int flex = 2;
        Widget child;
        switch (col.key) {
          case 'id':
            flex = 1;
            child = Text("#${asset.id}",
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold));
            break;
          case 'name':
            flex = 3;
            child = Text(asset.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold));
            break;
          case 'brand':
            child = Text(asset.brand,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12));
            break;
          case 'serial':
            child = Text(asset.serialCode,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12));
            break;
          case 'type':
            child = Text(asset.category,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12));
            break;
          case 'isOutdoor':
            child = Text(asset.isOutdoor ? 'Ja' : 'Nee',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12));
            break;
          case 'status':
            child = StatusBadge(status: asset.status, fontSize: 13);
            break;
          case 'created':
            child = Text('-',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12));
            break;
          default:
            child = const Text('');
            break;
        }
        return Expanded(flex: flex, child: child);
      }).toList(),
    );
  }

  Future<void> _bulkDeleteAssets(BuildContext context, Set<String> ids) async {
    await runBulkDelete(
      context,
      ids: ids,
      delete: AssetService.deleteAsset,
      refresh: AssetService.fetchAssets,
      entityLabel: 'bate/bates',
      onExit: () => setState(() => _selection.exit()),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (UserSession.can('assets.manage')) ...[
          BulkDeleteFloatingAction<String>(
            controller: _selection,
            confirmTitle: 'Verwyder Bates',
            confirmMessage:
                'Wil jy ${_selection.count} geselekteerde bate/bates verwyder?',
            hiddenSelectedCount: () {
              final visible =
                  _visibleAssets(_searchController.text.toLowerCase())
                      .map((a) => a.id)
                      .toSet();
              return _selection.selectedIds
                  .where((id) => !visible.contains(id))
                  .length;
            },
            onDelete: _bulkDeleteAssets,
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: "scanBtn",
          onPressed: _scanToIdentify,
          backgroundColor: AppColors.navy,
          child: const Icon(Icons.qr_code_scanner, color: Colors.white),
        ),
        if (UserSession.can('assets.manage')) ...[
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "addBtn",
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const AssetFormPage())),
            backgroundColor: AppColors.gold,
            elevation: 4,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Nuwe Bate",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
          ),
        ],
      ],
    );
  }
}

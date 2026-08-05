import 'package:flutter/material.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../core/app_colors.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../models/asset.dart';
import 'asset_detail_page.dart';
import 'new_asset_page.dart';
import 'manage_asset_types_page.dart';
import '../../models/user_session.dart';
import '../reporting/scan_page.dart';
import '../room_checklist/room_check_history_page.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';

class AssetsPage extends StatefulWidget {
  final String? filterRoomId;
  const AssetsPage({super.key, this.filterRoomId});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = "Almal";
  int? _selectedCampusId;
  int? _selectedBuildingId;
  int? _selectedRoomId;
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('assets', [
    const ColumnDef(key: 'id', label: '#ID'),
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'brand', label: 'Merk', defaultVisible: false),
    const ColumnDef(key: 'serial', label: 'Serienommer', defaultVisible: false),
    const ColumnDef(key: 'type', label: 'Tipe', defaultVisible: false),
    const ColumnDef(key: 'isOutdoor', label: 'Buite', defaultVisible: false),
    const ColumnDef(key: 'status', label: 'Status'),
    const ColumnDef(key: 'created', label: 'Geskep', defaultVisible: false),
  ]);

  @override
  void initState() {
    super.initState();
    AssetService.fetchAssets();
    CampusService.campusesNotifier.addListener(_onCampusesChanged);
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _tryAutoSelectCampus();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  void _tryAutoSelectCampus() {
    if (UserSession.isManager && _selectedCampusId == null && UserSession.locationId != null) {
      final match = CampusService.campusesNotifier.value
          .where((c) => c.id == UserSession.locationId).firstOrNull;
      if (match != null) _selectedCampusId = match.id;
    }
  }

  void _onCampusesChanged() {
    if (mounted) {
      setState(() {
        _tryAutoSelectCampus();
      });
    }
  }

  @override
  void dispose() {
    CampusService.campusesNotifier.removeListener(_onCampusesChanged);
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
            MaterialPageRoute(builder: (context) => AssetDetailPage(asset: asset)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bate nie gevind nie."), backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.filterRoomId != null
          ? AppBar(
              title: const Text("Bates in Lokaal"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: "Geskiedenis",
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomCheckHistoryPage(roomId: int.parse(widget.filterRoomId!)),
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
              .map((s) => SearchableDropdownItem(value: s, label: s))
              .toList(),
          onSelected: (val) => setState(() => _statusFilter = val ?? _statusFilter),
        ),
      ),
      if (UserSession.hasAdminPrivileges)
        HeaderIconAction(
          icon: Icons.settings_outlined,
          tooltip: "Bate Tipes",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageAssetTypesPage()),
          ),
        ),
      ColumnVisibilityButton(controller: _colVis, iconOnly: true),
    ];
  }

  Widget _buildAssetListSliver() {
    return ValueListenableBuilder<List<Asset>>(
      valueListenable: AssetService.assetsNotifier,
      builder: (context, allAssets, _) {
        final campuses = CampusService.campusesNotifier.value;

        // Build valid room ID sets for cascade filter
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

        final filtered = allAssets.where((a) {
          // Room filter from constructor
          if (widget.filterRoomId != null && a.location != widget.filterRoomId) return false;

          // Campus filter
          if (campusRoomIds != null && !campusRoomIds.contains(a.location)) return false;

          // Building filter
          if (buildingRoomIds != null && !buildingRoomIds.contains(a.location)) return false;

          // Room filter
          if (_selectedRoomId != null && a.location != _selectedRoomId.toString()) return false;

          // Status filter
          if (_statusFilter != "Almal") {
             String mapped = "active";
             if (_statusFilter == "Onderhoud") mapped = "maintenance";
             if (_statusFilter == "Afgedank") mapped = "retired";
             if (_statusFilter == "Onaktief") mapped = "inactive";
             if (a.status.toLowerCase() != mapped) return false;
          }

          // Search query
          final q = _searchController.text.toLowerCase();
          return a.name.toLowerCase().contains(q) || 
                 a.serialCode.toLowerCase().contains(q) ||
                 a.id.toLowerCase().contains(q);
        }).toList();

        // Apply sorting
        if (_sortCtrl.isActive) {
          filtered.sort((a, b) {
            final dir = _sortCtrl.direction;
            switch (_sortCtrl.sortKey) {
              case 'id': return a.id.compareTo(b.id) * dir;
              case 'name': return a.name.toLowerCase().compareTo(b.name.toLowerCase()) * dir;
              case 'brand': return a.brand.toLowerCase().compareTo(b.brand.toLowerCase()) * dir;
              case 'serial': return a.serialCode.toLowerCase().compareTo(b.serialCode.toLowerCase()) * dir;
              case 'type': return a.category.toLowerCase().compareTo(b.category.toLowerCase()) * dir;
              case 'isOutdoor': return (a.isOutdoor ? 1 : 0).compareTo(b.isOutdoor ? 1 : 0) * dir;
              case 'status': return a.status.toLowerCase().compareTo(b.status.toLowerCase()) * dir;
              case 'created': return 0;
              default: return 0;
            }
          });
        }

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
                  const Divider(height: 1),
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
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AssetDetailPage(asset: asset))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        child: Row(
          children: _colVis.visibleColumns.map((col) {
            int flex = 2;
            Widget child;
            switch (col.key) {
              case 'id': flex = 1; child = Text("#${asset.id}", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)); break;
              case 'name': flex = 3; child = Text(asset.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)); break;
              case 'brand': child = Text(asset.brand, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)); break;
              case 'serial': child = Text(asset.serialCode, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)); break;
              case 'type': child = Text(asset.category, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)); break;
              case 'isOutdoor': child = Text(asset.isOutdoor ? 'Ja' : 'Nee', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)); break;
              case 'status': child = StatusBadge(status: asset.status, fontSize: 13); break;
              case 'created': child = const Text('-', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)); break;
              default: child = const Text(''); break;
            }
            return Expanded(flex: flex, child: child);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: "scanBtn",
          onPressed: _scanToIdentify,
          backgroundColor: AppColors.navy,
          child: const Icon(Icons.qr_code_scanner, color: Colors.white),
        ),
        if (UserSession.hasAdminPrivileges) ...[
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "addBtn",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NewAssetPage())),
            backgroundColor: AppColors.gold,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ],
    );
  }
}

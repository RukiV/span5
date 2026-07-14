import 'package:flutter/material.dart';
import '../../widgets/status_badge.dart';
import '../../core/app_colors.dart';
import '../../services/asset_service.dart';
import '../../models/asset.dart';
import 'asset_detail_page.dart';
import 'new_asset_page.dart';
import 'manage_asset_types_page.dart';
import '../../models/user_session.dart';
import '../reporting/scan_page.dart';

class AssetsPage extends StatefulWidget {
  final String? filterRoomId;
  const AssetsPage({super.key, this.filterRoomId});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  String _statusFilter = "Almal";

  @override
  void initState() {
    super.initState();
    AssetService.fetchAssets();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
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
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: canPop ? AppBar(
        title: Text(widget.filterRoomId != null ? "Lokaal: ${widget.filterRoomId}" : "Bates"),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ) : null,
      body: Column(
        children: [
          _buildSearchBarWithFilter(),
          Expanded(child: _buildAssetList()),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildSearchBarWithFilter() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Soek bates...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 150/255), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                fillColor: Colors.white.withValues(alpha: 30/255),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (UserSession.hasAdminPrivileges) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAssetTypesPage())),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 30/255),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text("Bate Tipes", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 30/255),
              borderRadius: BorderRadius.circular(30),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: AppColors.navy,
                icon: const Icon(Icons.filter_list, color: AppColors.gold),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                items: ["Almal", "Aktief", "Onderhoud", "Afgedank", "Onaktief"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _statusFilter = val!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetList() {
    return ValueListenableBuilder<List<Asset>>(
      valueListenable: AssetService.assetsNotifier,
      builder: (context, allAssets, _) {
        final filtered = allAssets.where((a) {
          // Room filter from constructor
          if (widget.filterRoomId != null && a.location != widget.filterRoomId) return false;
          
          // Status filter
          if (_statusFilter != "Almal") {
             String mapped = "active";
             if (_statusFilter == "Onderhoud") mapped = "maintenance";
             if (_statusFilter == "Afgedank") mapped = "retired";
             if (_statusFilter == "Onaktief") mapped = "inactive";
             if (a.status.toLowerCase() != mapped) return false;
          }

          // Search query
          return a.name.toLowerCase().contains(_query) || 
                 a.serialCode.toLowerCase().contains(_query) ||
                 a.id.toLowerCase().contains(_query);
        }).toList();

        if (filtered.isEmpty) return const Center(child: Text("Geen bates gevind nie."));

return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: AppColors.gold,
              child: const Row(
                children: [
                  Expanded(flex: 1, child: Text("ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text("NAAM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text("STATUS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ...filtered.map((asset) => _buildAssetRow(asset)),
                  const Divider(height: 1),
                ],
              ),
            ),
          ],
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
          children: [
            Expanded(flex: 1, child: Text("#${asset.id}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: StatusBadge(status: asset.status, fontSize: 13)),
          ],
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

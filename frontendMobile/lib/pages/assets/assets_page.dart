import 'package:flutter/material.dart';
import '../../widgets/status_badge.dart';
import '../../core/app_colors.dart';
import '../../core/asset_service.dart';
import '../../models/asset.dart';
import 'asset_detail_page.dart';
import 'new_asset_page.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.filterRoomId != null) {
      _query = "room:${widget.filterRoomId}";
    }
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
          if (!canPop) _buildSearchBar(),
          if (widget.filterRoomId != null && !canPop)
            Container(
              padding: const EdgeInsets.all(10),
              color: AppColors.gold.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Text("Filter: Lokaal ID ${widget.filterRoomId}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AssetsPage()));
                    },
                  )
                ],
              ),
            ),
          Expanded(child: _buildAssetList()),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      color: AppColors.navy,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Soek bates...",
          hintStyle: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.gold),
          fillColor: Colors.white.withAlpha(30),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildAssetList() {
    return ValueListenableBuilder<List<Asset>>(
      valueListenable: AssetService.assetsNotifier,
      builder: (context, allAssets, _) {
        // ROL-GEBASEERDE DATA FILTRERING: Bestuurders kan alles sien, maar slegs hul eie kampus wysig (word in detail hanteer)
        List<Asset> baseAssets = allAssets;

        final filtered = baseAssets.where((a) {
          if (_query.startsWith("room:")) {
            final targetRoomId = _query.replaceFirst("room:", "");
            return a.location == targetRoomId;
          }
          return a.name.toLowerCase().contains(_query) || a.id.toLowerCase().contains(_query);
        }).toList();

        if (filtered.isEmpty) return const Center(child: Text("Geen bates gevind nie."));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: AppColors.gold,
              child: const Row(
                children: [
                  Expanded(flex: 1, child: Text("ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text("Naam", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text("Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final asset = filtered[index];
                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AssetDetailPage(asset: asset))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: Text("#${asset.id}", style: const TextStyle(fontSize: 12))),
                          Expanded(flex: 3, child: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: StatusBadge(status: asset.status, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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

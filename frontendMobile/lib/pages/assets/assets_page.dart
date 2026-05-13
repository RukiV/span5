import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/asset_service.dart';
import '../../models/asset.dart';
import 'asset_detail_page.dart';
import 'new_asset_page.dart';
import '../../models/user_session.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    // Laai vars bates van die backend af
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ValueListenableBuilder<List<Asset>>(
        valueListenable: AssetService.assetsNotifier,
        builder: (context, allAssets, child) {
          final filteredAssets = allAssets.where((asset) {
            bool matchesCampus = true;
            if (UserSession.isManager) {
              matchesCampus = asset.campus == UserSession.userCampus;
            }

            final matchesSearch = asset.name.toLowerCase().contains(_query) ||
                asset.id.toLowerCase().contains(_query) ||
                asset.location.toLowerCase().contains(_query);

            return matchesCampus && matchesSearch;
          }).toList();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
                color: AppColors.navy,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Soek bates (Naam, ID of Lokaal)...",
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
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                color: AppColors.gold,
                child: const Row(
                  children: [
                    Expanded(flex: 1, child: Text("ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 3, child: Text("Asset Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    Expanded(flex: 2, child: Text("Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),
              Expanded(
                child: filteredAssets.isEmpty 
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: filteredAssets.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final asset = filteredAssets[index];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AssetDetailPage(asset: asset)),
                          );
                        },
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text("#${asset.id}")),
                              Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(asset.location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  )
                              ),
                              Expanded(
                                flex: 2,
                                child: _statusBadge(asset.status),
                              ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewAssetPage()),
          );
        },
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text("Geen bates gevind vir \"${_searchController.text}\"", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case "Aktief": color = Colors.green; break;
      case "Onderhoud": color = Colors.orange; break;
      case "In gebruik": color = Colors.blue; break;
      case "Beskikbaar": color = Colors.teal; break;
      default: color = Colors.grey;
    }
    return Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13));
  }
}

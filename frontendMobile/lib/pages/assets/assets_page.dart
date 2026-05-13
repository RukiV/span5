import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/asset_service.dart';
import '../../core/stock_service.dart';
import '../../models/asset.dart';
import '../../models/stock.dart';
import 'asset_detail_page.dart';
import 'new_asset_page.dart';
import 'new_stock_page.dart';
import '../../models/user_session.dart';
import '../reporting/scan_page.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    // Laai vars data
    AssetService.fetchAssets();
    StockService.fetchStocks();
    
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scanToIdentify() async {
    final String? scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanPage()),
    );

    if (scannedCode != null) {
      final asset = AssetService.getAssetById(scannedCode);
      if (mounted) {
        if (asset != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AssetDetailPage(asset: asset)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bate nie gevind nie."), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: AppColors.navy,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: "BATES"),
              Tab(text: "TOERUSTING"),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAssetTab(),
                _buildStockTab(),
              ],
            ),
          ),
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
          hintText: "Soek...",
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

  Widget _buildAssetTab() {
    return ValueListenableBuilder<List<Asset>>(
      valueListenable: AssetService.assetsNotifier,
      builder: (context, allAssets, _) {
        final filtered = allAssets.where((a) {
          final matchesSearch = a.name.toLowerCase().contains(_query) || a.id.toLowerCase().contains(_query);
          return matchesSearch;
        }).toList();

        return _buildList(
          items: filtered,
          header: ["ID", "Naam", "Status"],
          itemBuilder: (asset) => _buildAssetRow(asset as Asset),
        );
      },
    );
  }

  Widget _buildStockTab() {
    return ValueListenableBuilder<List<Stock>>(
      valueListenable: StockService.stocksNotifier,
      builder: (context, allStocks, _) {
        final filtered = allStocks.where((s) {
          final matchesSearch = s.brand.toLowerCase().contains(_query) || s.type.toLowerCase().contains(_query);
          return matchesSearch;
        }).toList();

        return _buildList(
          items: filtered,
          header: ["Naam", "Tipe", "Hvh"],
          itemBuilder: (stock) => _buildStockRow(stock as Stock),
        );
      },
    );
  }

  Widget _buildList({required List items, required List<String> header, required Widget Function(dynamic) itemBuilder}) {
    if (items.isEmpty) return const Center(child: Text("Geen items gevind nie."));
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          color: AppColors.gold,
          child: Row(
            children: [
              Expanded(flex: 1, child: Text(header[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 3, child: Text(header[1], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text(header[2], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => itemBuilder(items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetRow(Asset asset) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AssetDetailPage(asset: asset))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        child: Row(
          children: [
            Expanded(flex: 1, child: Text("#${asset.id}", style: const TextStyle(fontSize: 12))),
            Expanded(flex: 3, child: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: _statusBadge(asset.status)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockRow(Stock stock) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(stock.brand, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text(stock.type, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text("${stock.amount}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold))),
        ],
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
            onPressed: () {
              if (_tabController.index == 0) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NewAssetPage()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NewStockPage()));
              }
            },
            backgroundColor: AppColors.gold,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.green;
    if (status == "Onderhoud") color = Colors.orange;
    return Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13));
  }
}

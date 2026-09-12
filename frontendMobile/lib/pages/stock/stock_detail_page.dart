import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/stock.dart';
import '../../models/user_session.dart';
import '../../services/campus_service.dart';
import '../../services/stock_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/detail_row.dart';
import 'stock_form_page.dart';

class StockDetailPage extends StatefulWidget {
  final Stock stock;
  const StockDetailPage({super.key, required this.stock});

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  late Stock _currentStock;

  @override
  void initState() {
    super.initState();
    _currentStock = widget.stock;
  }

  String get _locationPath {
    if (_currentStock.roomId == null) return "Nie toegewys nie";
    final campus =
        CampusService.campusesNotifier.value
            .expand((c) => c.buildings)
            .expand((b) => b.rooms ?? const <dynamic>[])
            .where((r) => r.id == _currentStock.roomId)
            .firstOrNull;
    if (campus == null) return "Lokaal #${_currentStock.roomId}";

    // Vind die gebou en kampus
    for (final c in CampusService.campusesNotifier.value) {
      for (final b in c.buildings) {
        for (final r in (b.rooms ?? const <dynamic>[])) {
          if (r.id == _currentStock.roomId) {
            final parts = <String>[c.name, b.name, r.name];
            return parts.join(" > ");
          }
        }
      }
    }
    return "Lokaal #${_currentStock.roomId}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(_currentStock.name.toUpperCase()),
        actions: [
          if (UserSession.can('stock.manage'))
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Wysig',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        StockFormPage(stock: _currentStock, startEditing: true),
                  ),
                );
                if (result == true && mounted) {
                  await StockService.fetchStocks();
                  if (!mounted) return;
                  final updated = StockService.stocksNotifier.value
                      .where((s) => s.id == _currentStock.id)
                      .firstOrNull;
                  if (updated != null) {
                    setState(() => _currentStock = updated);
                  }
                }
              },
            ),
          if (UserSession.can('stock.manage'))
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              tooltip: 'Verwyder',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Besonderhede"),
            const SizedBox(height: 12),
            _buildInfoCard(),
            const SizedBox(height: 25),
            _buildSectionHeader("Ligging"),
            const SizedBox(height: 12),
            _buildLocationCard(),
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
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          DetailRow(
              label: "Naam",
              valueWidget: Flexible(
                child: Text(_currentStock.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Handelsmerk",
              valueWidget: Flexible(
                child: Text(
                    _currentStock.brand.isEmpty ? "-" : _currentStock.brand,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Tipe",
              valueWidget: Flexible(
                child: Text(
                    _currentStock.type.isEmpty ? "-" : _currentStock.type,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Hoeveelheid",
              valueWidget: Flexible(
                child: Text(_currentStock.amount.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Minimum Voorraad",
              valueWidget: Flexible(
                child: Text(_currentStock.minimum.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          const Divider(height: 24),
          DetailRow(
              label: "Boks Totaal",
              valueWidget: Flexible(
                child: Text(_currentStock.boxTotal.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          if (_currentStock.description != null &&
              _currentStock.description!.isNotEmpty) ...[
            const Divider(height: 24),
            DetailRow(
                label: "Beskrywing",
                valueWidget: Flexible(
                  child: Text(_currentStock.description!,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 20, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _locationPath,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() => confirmDeleteAndRun(
      context,
      entityLabel: 'voorraad',
      itemName: _currentStock.name,
      delete: () async {
        final id = _currentStock.id;
        if (id == null) return false;
        return StockService.deleteStock(id);
      },
      onSuccess: () => Navigator.pop(context),
    );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/asset_service.dart';
import '../../models/report.dart';
import '../../models/asset.dart';
import '../../models/user_session.dart';

class DashboardPage extends StatefulWidget {
  /// Vra 'n bladsy aan op naam (bv. "Werksopdragte"). Die naam moet ooreenstem
  /// met 'n inskrywing in HomePage se menu, anders word die versoek geïgnoreer.
  final void Function(String title)? onTabRequested;

  const DashboardPage({super.key, this.onTabRequested});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Outomatiese verfrissing elke 5 minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Future.wait([
      ReportService.fetchReports(),
      AssetService.fetchAssets(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat("EEEE, d MMMM yyyy", 'af_ZA');
    final dateString = formatter.format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.gold,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Naam en Datum
            Text(
              "Goeiedag, ${UserSession.userName}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              dateString,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 25),

            // Seksie: Rapportering Opsomming
            _buildSectionHeader("Rapportering"),
            const SizedBox(height: 12),
            
            // Drie kaarte langs mekaar (Foutkaartjies, Werksopdragte, Verslae)
            ValueListenableBuilder<List<Report>>(
              valueListenable: ReportService.reportsNotifier,
              builder: (context, reports, _) {
                final nuwe = reports.where((r) => r.phase == "Ontvang").length;
                final voltooi = reports.where((r) => r.phase == "Voltooi").length;
                final werksopdragteTotaal = reports.length;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    double cardWidth = (constraints.maxWidth - 20) / 3;
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniStatCard(
                              context,
                              "Foutkaartjies",
                              nuwe.toString(),
                              "(-3%)",
                              AppColors.gold,
                              "Foutkaartjies",
                              cardWidth,
                            ),
                            _buildMiniStatCard(
                              context,
                              "Werksopdragte",
                              werksopdragteTotaal.toString(),
                              "",
                              AppColors.successGreen, // Werksopdragte is nou Groen
                              "Werksopdragte",
                              cardWidth,
                            ),
                            _buildMiniStatCard(
                              context,
                              "Verslae",
                              voltooi.toString(),
                              "(+10%)",
                              AppColors.infoBlue,
                              "Foutkaartjies",
                              cardWidth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildPriorityDistributionLine(reports.where((r) => r.phase == "Ontvang").toList()),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 30),

            // Seksie: Bates
            _buildSectionHeader("Bates"),
            const SizedBox(height: 12),

            ValueListenableBuilder<List<Asset>>(
              valueListenable: AssetService.assetsNotifier,
              builder: (context, assets, _) {
                return Column(
                  children: [
                    // Totale Bates Kaart
                    _buildWideStatCard(
                      context,
                      "Totale Bates",
                      assets.length.toString(),
                      "+5%",
                      AppColors.navy,
                      "Bates",
                    ),
                    const SizedBox(height: 20),
                    
                    // Bate Status Verspreiding (Die lyn-grafiek)
                    _buildAssetDistributionLine(assets),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 30),
            
            // Opsioneel: Onlangse Herstelwerk (Minimalistiese lys)
            _buildSectionHeader("Onlangse Herstelwerk"),
            const SizedBox(height: 12),
            ValueListenableBuilder<List<Report>>(
              valueListenable: ReportService.reportsNotifier,
              builder: (context, reports, _) {
                final recent = reports.take(3).toList();
                if (recent.isEmpty) return const Text("Geen data beskikbaar", style: TextStyle(fontSize: 12, color: Colors.grey));
                return Column(
                  children: recent.map((r) => _buildMinimalActivityRow(context, r)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.navy,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildMiniStatCard(BuildContext context, String title, String value, String trend, Color color, String targetTitle, double width) {
    bool isPositive = trend.contains('+');
    return InkWell(
      onTap: () => widget.onTabRequested?.call(targetTitle),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          border: Border(bottom: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey), maxLines: 1),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 2),
            Text(
              trend,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isPositive ? AppColors.successGreen : AppColors.errorRed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideStatCard(BuildContext context, String title, String value, String trend, Color color, String targetTitle) {
    return InkWell(
      onTap: () => widget.onTabRequested?.call(targetTitle),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.successGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(trend, style: const TextStyle(color: AppColors.successGreen, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAssetDistributionLine(List<Asset> assets) {
    if (assets.isEmpty) return const SizedBox();
    
    int active = assets.where((a) => a.status.toLowerCase() == 'active').length;
    int maintenance = assets.where((a) => a.status.toLowerCase() == 'maintenance').length;
    int retired = assets.where((a) => a.status.toLowerCase() == 'retired' || a.status.toLowerCase() == 'disposed').length;
    int total = assets.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Bate Status Verspreiding", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            width: double.infinity,
            child: Row(
              children: [
                if (active > 0) Expanded(flex: active, child: Container(color: AppColors.successGreen)),
                if (maintenance > 0) Expanded(flex: maintenance, child: Container(color: AppColors.warningOrange)),
                if (retired > 0) Expanded(flex: retired, child: Container(color: AppColors.errorRed)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLegendItem("Aktief", AppColors.successGreen, (active/total*100).toStringAsFixed(0)),
            _buildLegendItem("Onderhoud", AppColors.warningOrange, (maintenance/total*100).toStringAsFixed(0)),
            _buildLegendItem("Afgedank", AppColors.errorRed, (retired/total*100).toStringAsFixed(0)),
          ],
        )
      ],
    );
  }

  Widget _buildPriorityDistributionLine(List<Report> reports) {
    if (reports.isEmpty) return const SizedBox();
    
    int high = reports.where((r) => r.priority == 'Hoog').length;
    int medium = reports.where((r) => r.priority == 'Medium').length;
    int low = reports.where((r) => r.priority == 'Laag').length;
    int total = reports.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Prioriteit Verspreiding", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            width: double.infinity,
            child: Row(
              children: [
                if (high > 0) Expanded(flex: high, child: Container(color: AppColors.errorRed)),
                if (medium > 0) Expanded(flex: medium, child: Container(color: AppColors.warningOrange)),
                if (low > 0) Expanded(flex: low, child: Container(color: AppColors.successGreen)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLegendItem("Hoog", AppColors.errorRed, (high/total*100).toStringAsFixed(0)),
            _buildLegendItem("Medium", AppColors.warningOrange, (medium/total*100).toStringAsFixed(0)),
            _buildLegendItem("Laag", AppColors.successGreen, (low/total*100).toStringAsFixed(0)),
          ],
        )
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, String percentage) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text("$label ($percentage%)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMinimalActivityRow(BuildContext context, Report r) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(DateFormat("yyyy-MM-dd").format(r.timestamp), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          _buildMinimalStatusChip(r.phase),
        ],
      ),
    );
  }

  Widget _buildMinimalStatusChip(String phase) {
    Color color = AppColors.infoBlue;
    if (phase == "Voltooi") color = AppColors.successGreen;
    return Text(
      phase.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/asset_service.dart';
import '../../models/report.dart';
import '../../models/asset.dart';
import '../../models/user_session.dart';
import 'calendar_page.dart';

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
      color: AppColors.refreshSpinner,
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
                final voltooi =
                    reports.where((r) => r.phase == "Voltooi").length;
                final werksopdragteTotaal = reports.length;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    double cardWidth = (constraints.maxWidth - 20) / 3;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStatCard(
                          context,
                          "Foutkaartjies",
                          nuwe.toString(),
                          "",
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
                          "",
                          AppColors.infoBlue,
                          "Foutkaartjies",
                          cardWidth,
                        ),
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
                // Totale Bates Kaart
                return _buildWideStatCard(
                  context,
                  "Totale Bates",
                  assets.length.toString(),
                  "",
                  AppColors.navy,
                  "Bates",
                );
              },
            ),

            const SizedBox(height: 30),

            // Seksie: Kalender (ingebed)
            _buildSectionHeader("Kalender"),
            const SizedBox(height: 12),
            const CalendarPage(),
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

  Widget _buildMiniStatCard(BuildContext context, String title, String value,
      String trend, Color color, String targetTitle, double width) {
    return InkWell(
      onTap: () => widget.onTabRequested?.call(targetTitle),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
          border: Border(bottom: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey),
                maxLines: 1),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy)),
            if (trend.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                trend,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: trend.contains('+')
                        ? AppColors.successGreen
                        : AppColors.errorRed),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWideStatCard(BuildContext context, String title, String value,
      String trend, Color color, String targetTitle) {
    return InkWell(
      onTap: () => widget.onTabRequested?.call(targetTitle),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy)),
              ],
            ),
            if (trend.isEmpty)
              const SizedBox.shrink()
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(trend,
                    style: const TextStyle(
                        color: AppColors.successGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              )
          ],
        ),
      ),
    );
  }
}

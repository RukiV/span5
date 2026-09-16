import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/asset_service.dart';
import '../../services/jobcard_service.dart';
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
      JobcardService.fetchJobs(),
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

            // Seksie: Opsomming — al die KPI-kaarte in een ry (baie kompak)
            _buildSectionHeader("Opsomming"),
            const SizedBox(height: 12),

            // Vier kaarte langs mekaar (Foutkaartjies, Werksopdragte, Verslae,
            // Totale Bates). Terwyl die eerste laai nog besig is, wys 'n klein
            // spinner in plaas van 'n misleidende "0".
            AnimatedBuilder(
              animation: Listenable.merge([
                ReportService.reportsNotifier,
                ReportService.isLoadingNotifier,
              ]),
              builder: (context, _) {
                final reports = ReportService.reportsNotifier.value;
                final reportsBusy =
                    reports.isEmpty && ReportService.isLoadingNotifier.value;
                final nuwe =
                    reports.where((r) => r.phase == "Ontvang").length;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    double cardWidth = (constraints.maxWidth - 24) / 4;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStatCard(
                          context,
                          "Foutkaartjies",
                          reportsBusy ? null : nuwe.toString(),
                          "",
                          AppColors.gold,
                          "Foutkaartjies",
                          cardWidth,
                        ),
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            JobcardService.jobcardsNotifier,
                            JobcardService.isLoadingNotifier,
                          ]),
                          builder: (context, _) {
                            final jobcards =
                                JobcardService.jobcardsNotifier.value;
                            final busy = jobcards.isEmpty &&
                                JobcardService.isLoadingNotifier.value;
                            return _buildMiniStatCard(
                              context,
                              "Werksopdragte",
                              busy ? null : jobcards.length.toString(),
                              "",
                              AppColors.successGreen,
                              "Werksopdragte",
                              cardWidth,
                            );
                          },
                        ),
                        _buildMiniStatCard(
                          context,
                          "Verslae",
                          reportsBusy ? null : reports.length.toString(),
                          "",
                          AppColors.infoBlue,
                          "Verslae",
                          cardWidth,
                        ),
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            AssetService.assetsNotifier,
                            AssetService.isLoadingNotifier,
                          ]),
                          builder: (context, _) {
                            final assets = AssetService.assetsNotifier.value;
                            final busy = assets.isEmpty &&
                                AssetService.isLoadingNotifier.value;
                            return _buildMiniStatCard(
                              context,
                              "Totale Bates",
                              busy ? null : assets.length.toString(),
                              "",
                              AppColors.navy,
                              "Bates",
                              cardWidth,
                            );
                          },
                        ),
                      ],
                    );
                  },
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

Widget _buildMiniStatCard(BuildContext context, String title, String? value,
    String trend, Color color, String targetTitle, double width) {
  return InkWell(
    onTap: () => widget.onTabRequested?.call(targetTitle),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
        border: Border(bottom: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          if (value != null)
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy))
          else
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.navy),
            ),
          if (trend.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              trend,
              style: TextStyle(
                  fontSize: 8,
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
}

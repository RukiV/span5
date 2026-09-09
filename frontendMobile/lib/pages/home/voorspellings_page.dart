import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/report_service.dart';
import '../../services/asset_service.dart';
import '../../models/report.dart';
import '../../models/asset.dart';
import '../../widgets/distribution_bar.dart';

/// Voorspellings-tab: huisves die analise/verspreiding-grafieke wat vroeër op
/// die Paneelbord was (Bate Status- en Prioriteit-verdeling).
class VoorspellingsPage extends StatefulWidget {
  const VoorspellingsPage({super.key});

  @override
  State<VoorspellingsPage> createState() => _VoorspellingsPageState();
}

class _VoorspellingsPageState extends State<VoorspellingsPage> {
  Future<void> _refreshData() async {
    await Future.wait([
      ReportService.fetchReports(),
      AssetService.fetchAssets(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.refreshSpinner,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Bate Status Verspreiding"),
            const SizedBox(height: 12),
            ValueListenableBuilder<List<Asset>>(
              valueListenable: AssetService.assetsNotifier,
              builder: (context, assets, _) {
                if (assets.isEmpty) {
                  return const Text("Geen data beskikbaar",
                      style: TextStyle(fontSize: 12, color: Colors.grey));
                }
                int active = assets
                    .where((a) => a.status.toLowerCase() == 'active')
                    .length;
                int maintenance = assets
                    .where((a) => a.status.toLowerCase() == 'maintenance')
                    .length;
                int retired = assets
                    .where((a) =>
                        a.status.toLowerCase() == 'retired' ||
                        a.status.toLowerCase() == 'disposed')
                    .length;

                return DistributionBar(
                  segments: [
                    DistributionSegment(
                        label: 'Aktief',
                        color: AppColors.successGreen,
                        flex: active),
                    DistributionSegment(
                        label: 'Onderhoud',
                        color: AppColors.warningOrange,
                        flex: maintenance),
                    DistributionSegment(
                        label: 'Afgedank',
                        color: AppColors.errorRed,
                        flex: retired),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
            _buildSectionHeader("Prioriteit Verspreiding"),
            const SizedBox(height: 12),
            ValueListenableBuilder<List<Report>>(
              valueListenable: ReportService.reportsNotifier,
              builder: (context, reports, _) {
                final received =
                    reports.where((r) => r.phase == "Ontvang").toList();
                if (received.isEmpty) {
                  return const Text("Geen data beskikbaar",
                      style: TextStyle(fontSize: 12, color: Colors.grey));
                }
                int high = received.where((r) => r.priority == 'Hoog').length;
                int medium =
                    received.where((r) => r.priority == 'Medium').length;
                int low = received.where((r) => r.priority == 'Laag').length;

                return DistributionBar(
                  segments: [
                    DistributionSegment(
                        label: 'Hoog', color: AppColors.errorRed, flex: high),
                    DistributionSegment(
                        label: 'Medium',
                        color: AppColors.warningOrange,
                        flex: medium),
                    DistributionSegment(
                        label: 'Laag',
                        color: AppColors.successGreen,
                        flex: low),
                  ],
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
}

import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/campus_service.dart';

/// Gedeelde krummelpad-aanwyser vir ligging op bate-/voorraadvorms.
class LocationBreadcrumbs extends StatelessWidget {
  final String path;

  const LocationBreadcrumbs({super.key, required this.path});

  /// Bou die "kampus > gebou > lokaal"-padstring vanaf ID's.
  static String buildLocationPath({
    int? campusId,
    int? buildingId,
    int? roomId,
    String fallback = 'Kies Kampus',
  }) {
    final p = CampusService.findLocationPath(campusId, buildingId, roomId);
    if (p.campus == null) return fallback;
    var result = p.campus!.name;
    if (p.building != null) {
      result += " > ${p.building!.name}";
      if (p.room != null) result += " > ${p.room!.name}";
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

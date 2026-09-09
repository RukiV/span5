import 'package:flutter/material.dart';

class DistributionSegment {
  final String label;
  final Color color;
  final int flex;
  const DistributionSegment({required this.label, required this.color, required this.flex});
}

/// Horisontale gestapelde staaf-grafiek met 'n legende, gebruik vir status- en
/// prioriteit-verdeling (bv. op die Voorspellings-tab).
class DistributionBar extends StatelessWidget {
  final List<DistributionSegment> segments;
  final double barHeight;

  const DistributionBar({super.key, required this.segments, this.barHeight = 10});

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, s) => sum + s.flex);
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: barHeight,
            width: double.infinity,
            child: Row(
              children: [
                for (final s in segments)
                  if (s.flex > 0)
                    Expanded(flex: s.flex, child: Container(color: s.color)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in segments)
              if (s.flex > 0)
                _legendItem(s.label, s.color, ((s.flex / total) * 100).toStringAsFixed(0)),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color, String percentage) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text("$label ($percentage%)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String displayStatus = status;

    switch (status.toLowerCase()) {
      case 'active':
      case 'aktief':
      case 'voltooi':
      case 'opgelos':
        color = Colors.green;
        displayStatus = status == 'active' ? 'Aktief' : status;
        break;
      case 'onderhoud':
      case 'besig':
      case 'open':
      case 'bevestig':
        color = Colors.orange;
        break;
      case 'geweier':
      case 'verwerp':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

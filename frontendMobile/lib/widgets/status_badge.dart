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
    Color color = Colors.grey;
    String displayStatus = status;

    switch (status.toLowerCase()) {
      // Asset specific statuses
      case 'active':
      case 'aktief':
        color = Colors.green;
        displayStatus = 'Aktief';
        break;
      case 'inactive':
      case 'onaktief':
        color = Colors.grey;
        displayStatus = 'Onaktief';
        break;
      case 'maintenance':
      case 'onderhoud':
        color = Colors.blueAccent;
        displayStatus = 'Onderhoud';
        break;
      case 'retired':
      case 'afgedank':
        color = Colors.red;
        displayStatus = 'Afgedank';
        break;

      // Report specific statuses
      case 'opgelos':
      case 'voltooi':
        color = Colors.green;
        displayStatus = 'Opgelos';
        break;
      case 'besig':
        color = Colors.blueAccent;
        displayStatus = 'Besig';
        break;
      case 'open':
      case 'oop':
        color = Colors.orange;
        displayStatus = 'Oop';
        break;
      case 'bevestig':
        color = Colors.purple;
        displayStatus = 'Bevestig';
        break;
      case 'geweier':
      case 'verwerp':
        color = Colors.red;
        displayStatus = 'Verwerp';
        break;
      case 'wag':
        color = Colors.blue;
        displayStatus = 'Wag';
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        displayStatus.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: fontSize - 1,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

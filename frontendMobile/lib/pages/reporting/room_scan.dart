import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/room.dart';
import '../../services/room_service.dart';
import 'scan_page.dart';

/// Scan 'n lokaal se QR-kode en los dit op na die volle
/// terrein/gebou/lokaal-pad. Gee die gevonde [Room] terug, of null wanneer die
/// gebruiker kanselleer of die kode nie met 'n lokaal ooreenstem nie (dan wys
/// dit 'n waarskuwings-snackbar).
Future<Room?> scanLocationToRoom(BuildContext context) async {
  final String? scannedCode = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ScanPage(isLocation: true)),
  );
  if (scannedCode == null || !context.mounted) return null;

  final room = await RoomService.getRoomByCode(scannedCode.trim());
  if (!context.mounted) return null;
  if (room == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Geen lokaal gevind met hierdie kode nie"),
        backgroundColor: AppColors.warningOrange,
      ),
    );
  }
  return room;
}

/// Kompakte QR-ikoonknoppie regs langs die ligging-kieser om 'n lokaal se
/// kode te skandeer — in plaas van 'n vol-breedte knoppie.
Widget buildScanRoomIconButton(VoidCallback onPressed) {
  return IconButton(
    icon: const Icon(Icons.qr_code_scanner, color: AppColors.navy),
    tooltip: "Skandeer Lokaal",
    style: IconButton.styleFrom(
      backgroundColor: Colors.grey[100],
      side: BorderSide(color: Colors.grey[300]!),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(10),
    ),
    onPressed: onPressed,
  );
}
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Toon die gestandaardiseerde "Verwyder <label>"-bevestigingsdialoog en gee
/// `true` terug as die gebruiker bevestig het.
Future<bool> confirmDelete(
  BuildContext context, {
  required String entityLabel,
  required String itemName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text("Verwyder $entityLabel"),
      content: Text("Is jy seker jy wil '$itemName' verwyder?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Kanselleer"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text("Verwyder"),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Bevestig 'n verwydering, voer [delete] uit, en hanteer die uitkoms: sukses
/// roep [onSuccess] aan (gewoonlik `Navigator.pop(context, true)`), mislukking
/// wys 'n foutboodskap. [entityLabel] verskyn in die dialoog-titel en die
/// foutboodskap ("Kon nie die <label> verwyder nie.").
Future<void> confirmDeleteAndRun(
  BuildContext context, {
  required String entityLabel,
  required String itemName,
  required Future<bool> Function() delete,
  required VoidCallback onSuccess,
}) async {
  final ok = await confirmDelete(context,
      entityLabel: entityLabel, itemName: itemName);
  if (!ok || !context.mounted) return;
  final success = await delete();
  if (!context.mounted) return;
  if (success) {
    onSuccess();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Kon nie die $entityLabel verwyder nie."),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }
}

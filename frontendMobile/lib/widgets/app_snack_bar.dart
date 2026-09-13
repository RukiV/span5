import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Wys 'n SnackBar; rooi vir foute, groen vir sukses, of 'n eie kleur.
void showAppSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  bool error = false,
  bool floating = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ??
          (error ? AppColors.errorRed : AppColors.successGreen),
      behavior: floating ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
    ),
  );
}
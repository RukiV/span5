import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Kleintjie ✓-knoppie om 'n AI-voorstel toe te pas.
class SuggestionAcceptCheck extends StatelessWidget {
  final VoidCallback? onTap;
  final String? tooltip;

  const SuggestionAcceptCheck({super.key, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? "Pas voorstel toe",
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.check, size: 18, color: AppColors.gold),
        ),
      ),
    );
  }
}

/// Wrap [InputDecoration] om AI-voorstelle te toon as spookteks (hint) met
/// 'n ✓-knoppie om die voorstel toe te pas.
///
/// Wanneer `ghost` gevul is, `active` waar is, en `onAccept` verskaf is,
/// wys dit die aanvaardknoppie in die `suffixIcon`. Indien die
/// bestaande `decoration` reeds 'n `suffixIcon` het, word die twee in 'n
/// `Row` saamgevoeg. Andersins dien die ghost as `hintText` terwyl die veld
/// leeg is.
InputDecoration withSuggestionGhost(
  InputDecoration base, {
  String? ghost,
  bool active = false,
  VoidCallback? onAccept,
}) {
  if (ghost == null || ghost.trim().isEmpty || !active || onAccept == null) {
    return base;
  }

  final acceptWidget = SuggestionAcceptCheck(onTap: onAccept);
  final existingSuffix = base.suffixIcon;

  Widget mergedSuffix;
  if (existingSuffix != null) {
    mergedSuffix = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        acceptWidget,
        const SizedBox(width: 4),
        existingSuffix,
      ],
    );
  } else {
    mergedSuffix = acceptWidget;
  }

  return base.copyWith(
    suffixIcon: mergedSuffix,
    hintText: base.hintText ?? ghost,
  );
}
import 'package:flutter/material.dart';

/// Klein ✓-knoppie regs in 'n veld wat 'n AI-voorstel aanneem — die mobiele
/// eweknie van die web se `.ghost-suggestion-check`.
class SuggestionAcceptCheck extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;

  const SuggestionAcceptCheck({super.key, this.onTap, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Aanvaar voorstel',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 12, minHeight: size + 8),
      icon: Icon(Icons.check_circle, color: const Color(0xFF7A9E5A), size: size),
    );
  }
}

/// Wanneer 'n voorstel vir 'n teksveld bestaan en die veld leeg is, wys die
/// spookteks (grijs kursief) as die veld se hlpteks en 'n ✓-knoppie regs.
/// Die etiket dryf bo sodat die spook nie oor die etiket lê nie.
InputDecoration withSuggestionGhost(
  InputDecoration decoration, {
  required String? ghost,
  required bool active,
  required VoidCallback onAccept,
}) {
  if (!active || ghost == null || ghost.trim().isEmpty) return decoration;
  return decoration.copyWith(
    floatingLabelBehavior: FloatingLabelBehavior.always,
    hintText: ghost,
    hintStyle: const TextStyle(
      color: Color(0xFFA8A29E),
      fontStyle: FontStyle.italic,
      fontSize: 14,
    ),
    suffixIcon: SuggestionAcceptCheck(onTap: onAccept),
  );
}

/// Vir keuseliste: gee die spookwaarde as hlpteks terug (en 'n ✓) slegs as die
/// veld leeg is en 'n voorstel bestaan.
String? ghostHint({required String? ghost, required bool fieldEmpty}) =>
    fieldEmpty && ghost != null && ghost.trim().isNotEmpty ? ghost : null;
import 'package:flutter/material.dart';

/// Open 'n oorvleuelende dropdown wat onder die veld anker wat aan
/// [layerLink] gekoppel is. Die paneel sweef bo-inhoud (selfs oor ander
/// bedekkings) en 'n deursigtige barrier maak dit toe by enige buite-tik.
///
/// Gebruik dit saam met `CompositedTransformTarget` wat die gegewe
/// [layerLink] op die veld plaas.
OverlayEntry openAnchoredDropdown({
  required BuildContext context,
  required LayerLink layerLink,
  required Widget child,
  required VoidCallback onDismiss,
}) {
  final entry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          offset: const Offset(0, 8),
          showWhenUnlinked: false,
          child: child,
        ),
      ],
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return entry;
}

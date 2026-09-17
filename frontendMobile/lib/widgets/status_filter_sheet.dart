import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'inline_searchable_dropdown.dart';

/// Maak 'n status-filter-lysie op teen die bokant van die skerm (as 'n
/// afgly-paneel) — dieselfde meganisme as die ligging-filter, maar vir 'n
/// gewone geselekteerde opsie eerder as 'n ligging-kaskade.
///
/// Tik 'n opsie: [onSelected] word dadelik geroep en die paneel maak toe.
/// "Klaar", die ×-knoppie of 'n tik buite die paneel sluit dit sonder om iets
/// te verander.
Future<void> showStatusFilterSheet<T>({
  required BuildContext context,
  required String title,
  required List<InlineSearchableDropdownItem<T>> items,
  required ValueChanged<T?> onSelected,
  T? selected,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Sluit',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, __) {
      return Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: Colors.white,
              elevation: 8,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            color: Colors.grey,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final item in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(item.label),
                          trailing: item.value == selected
                              ? const Icon(Icons.check,
                                  color: AppColors.gold, size: 20)
                              : null,
                          onTap: () {
                            onSelected(item.value);
                            Navigator.pop(ctx);
                          },
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Klaar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
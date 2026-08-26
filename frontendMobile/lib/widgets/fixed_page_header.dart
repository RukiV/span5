import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Vaste bladsy-opskaper: 'n navy balk direk onder die "FBS - [BLADSY]" AppBar
/// met 'n soekveld en kompakte ikoon-aksies langsaan. Die kop bly vas terwyl
/// die lysinhoud daarbuite skuif — dieselfde patroon as die Gebruikers-bladsy.
class FixedPageHeader extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final List<Widget>? actions;
  final ValueChanged<String>? onChanged;

  const FixedPageHeader({
    super.key,
    required this.controller,
    required this.hintText,
    this.actions,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (v) {
                onChanged?.call(v);
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 150 / 255),
                    fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          controller.clear();
                          onChanged?.call('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 30 / 255),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

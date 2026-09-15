import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'column_visibility.dart';
import 'header_action_button.dart';
import 'sort_utils.dart';

/// Die sorteer-knoppie vir [FixedPageHeader]: 'n ikoon wat die inlyn
/// [SortPanel] aan- en afskakel. NIE 'n popup nie — die paneel word deur die
/// bladsy self onder die kop gewys en bly oop totdat jy daaraf klik.
class SortButton extends StatelessWidget {
  final MultiSortController controller;

  /// Wys of die paneel tans oop is (gou ikoon as aanduiding).
  final bool selected;

  final VoidCallback onPressed;

  const SortButton({
    super.key,
    required this.controller,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return HeaderIconAction(
      icon: Icons.swap_vert,
      tooltip: 'Sorteer kolomme',
      iconColor: selected ? AppColors.gold : Colors.white,
      activeBadge: controller.isActive,
      badgeCount: controller.sorts.length,
      onTap: onPressed,
    );
  }
}

/// Inlyn-sorteerpaneel wat onder [FixedPageHeader] uitvou. Bou 'n geordende
/// multi-kolom sortering met dieselfde logika as die web `SortPicker`, maar bly
/// oop totdat die bladsy dit toemaak.
class SortPanel extends StatefulWidget {
  final MultiSortController controller;
  final List<ColumnDef> columns;

  /// Geroep ná elke verandering sodat die eienaar-bladsy sy lys kan herbou.
  final VoidCallback? onChanged;

  const SortPanel({
    super.key,
    required this.controller,
    required this.columns,
    this.onChanged,
  });

  @override
  State<SortPanel> createState() => _SortPanelState();
}

class _SortPanelState extends State<SortPanel> {
  void _mutate(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final columns = widget.columns;
    final addable = columns.where((c) => !controller.hasSort(c.key)).toList();
    final sortCount = controller.sorts.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sorteer volgens',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (sortCount == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nog geen sortering gekies nie.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          for (final sort in controller.sorts)
            _buildCriterionRow(sortCount, sort, columns),
          if (addable.isNotEmpty) ...[
            const Divider(height: 20),
            const Text(
              'Voeg kolom by',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            for (final col in addable)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                leading: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.gold,
                  size: 20,
                ),
                title: Text(
                  col.label,
                  style: const TextStyle(fontSize: 13),
                ),
                onTap: () => _mutate(() => controller.add(col.key)),
              ),
          ],
          const Divider(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _mutate(() => controller.clear()),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Maak skoon'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriterionRow(
    int sortCount,
    SortCriterion sort,
    List<ColumnDef> columns,
  ) {
    final controller = widget.controller;
    final index = controller.sorts.indexWhere((s) => s.key == sort.key);
    final label =
        columns.where((c) => c.key == sort.key).firstOrNull?.label ?? sort.key;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          _MiniIconButton(
            icon: sort.isDesc ? Icons.south : Icons.north,
            tooltip: sort.isDesc ? 'Aflopend (Z–A)' : 'Oplopend (A–Z)',
            onPressed: () =>
                _mutate(() => controller.toggleDirection(sort.key)),
          ),
          _MiniIconButton(
            icon: Icons.arrow_upward,
            tooltip: 'Beweeg hoër prioriteit',
            disabled: index == 0,
            onPressed: () => _mutate(() => controller.move(sort.key, -1)),
          ),
          _MiniIconButton(
            icon: Icons.arrow_downward,
            tooltip: 'Beweeg laer prioriteit',
            disabled: index == sortCount - 1,
            onPressed: () => _mutate(() => controller.move(sort.key, 1)),
          ),
          _MiniIconButton(
            icon: Icons.close,
            tooltip: 'Verwyder kolom',
            danger: true,
            onPressed: () => _mutate(() => controller.remove(sort.key)),
          ),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool disabled;
  final bool danger;
  final VoidCallback? onPressed;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    this.disabled = false,
    this.danger = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: disabled ? null : onPressed,
      color: disabled
          ? Colors.grey.shade300
          : (danger ? Colors.red.shade400 : AppColors.gold),
    );
  }
}
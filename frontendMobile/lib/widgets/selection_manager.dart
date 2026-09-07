import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Page-agnostic selection state for the universal "select mode" + bulk-delete
/// flow. `T` is the row id type (int for most pages, String for Assets/Faults).
/// The owning page calls `setState` whenever it mutates this controller so the
/// rows and header actions rebuild.
class SelectionController<T> {
  bool isSelecting = false;
  final Set<T> selectedIds = {};

  void enter() => isSelecting = true;

  void exit() {
    isSelecting = false;
    selectedIds.clear();
  }

  void toggle(T id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  bool isSelected(T id) => selectedIds.contains(id);

  int get count => selectedIds.length;

  void toggleAll(List<T> allIds) {
    if (selectedIds.length == allIds.length) {
      selectedIds.clear();
    } else {
      selectedIds
        ..clear()
        ..addAll(allIds);
    }
  }
}

/// Icon-only button that enters/exits select mode. Placed next to the existing
/// column-visibility button on every list page so placement matches exactly.
class SelectModeButton<T> extends StatelessWidget {
  final SelectionController<T> controller;
  final VoidCallback onToggle;
  final bool enabled;

  const SelectModeButton({
    super.key,
    required this.controller,
    required this.onToggle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = controller.isSelecting;
    return IconButton(
      tooltip: active ? 'Kies modus af' : 'Kies modus',
      icon: Icon(
        active ? Icons.check_circle : Icons.checklist,
        color: active ? AppColors.gold : Colors.white,
        size: 20,
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 30 / 255),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: enabled ? onToggle : null,
    );
  }
}

/// Trash action that appears (with a count badge) only while select mode is
/// active and at least one row is chosen. Shows a confirmation dialog that can
/// warn the user that child rows will be removed too (hierarchy pages).
class BulkDeleteAction<T> extends StatelessWidget {
  final SelectionController<T> controller;
  final Future<void> Function(BuildContext context, Set<T> ids) onDelete;
  final String confirmTitle;
  final String confirmMessage;
  final String? childWarning;

  const BulkDeleteAction({
    super.key,
    required this.controller,
    required this.onDelete,
    required this.confirmTitle,
    required this.confirmMessage,
    this.childWarning,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isSelecting || controller.count == 0) {
      return const SizedBox.shrink();
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Verwyder geselekteer',
          icon: const Icon(Icons.delete, color: Colors.white, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 60 / 255),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _confirm(context),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              '${controller.count}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ids = {...controller.selectedIds};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(confirmMessage),
            if (childWarning != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 20 / 255),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        childWarning!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('KANSELLEER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('VERWYDER', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await onDelete(context, ids);
    }
  }
}

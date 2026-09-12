import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'count_badge.dart';

/// Page-agnostic selection state for the universal "select mode" + bulk-delete
/// flow. `T` is the row id type (int for most pages, String for Assets/Faults).
/// A [ChangeNotifier] so the owning page (or its list scaffold) can rebuild on
/// mutation; callers may still wrap mutations in `setState` if they prefer.
class SelectionController<T> extends ChangeNotifier {
  bool isSelecting = false;
  final Set<T> selectedIds = {};

  void enter() {
    isSelecting = true;
    notifyListeners();
  }

  void exit() {
    isSelecting = false;
    selectedIds.clear();
    notifyListeners();
  }

  void toggle(T id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    notifyListeners();
  }

  bool isSelected(T id) => selectedIds.contains(id);

  int get count => selectedIds.length;
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

  /// Returner die aantal geselekteerde rye wat tans deur die soektog/filters
  /// versteek is. Wanneer dit > 0 is, wys die bevestiging 'n waarskuwing.
  /// Null skakel die waarskuwing af.
  final int Function()? hiddenSelectedCount;

  const BulkDeleteAction({
    super.key,
    required this.controller,
    required this.onDelete,
    required this.confirmTitle,
    required this.confirmMessage,
    this.childWarning,
    this.hiddenSelectedCount,
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _confirm(context),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: CountBadge(controller.count),
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
            if (hiddenSelectedCount != null && hiddenSelectedCount!() > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 25 / 255),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_off,
                        color: AppColors.warningOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${hiddenSelectedCount!()} van die geselekteerde rye is tans deur die soektog/filters versteek — hulle sal steeds verwyder word.",
                        style: const TextStyle(
                          color: Color(0xFF935E28),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    const Icon(Icons.warning_amber,
                        color: Colors.redAccent, size: 18),
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

Future<void> runBulkDelete<T>(
  BuildContext context, {
  required Set<T> ids,
  required Future<bool> Function(T id) delete,
  required Future<void> Function() refresh,
  required String entityLabel,
  VoidCallback? onExit,
}) async {
  var ok = 0;
  var fail = 0;
  for (final id in ids) {
    if (await delete(id)) {
      ok++;
    } else {
      fail++;
    }
  }
  await refresh();
  if (context.mounted) {
    onExit?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fail == 0
            ? "$ok $entityLabel verwyder."
            : "$ok verwyder, $fail kon nie verwyder word nie."),
        backgroundColor:
            fail == 0 ? AppColors.successGreen : AppColors.errorRed,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'count_badge.dart';
import 'header_action_button.dart';

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

/// Gedeelde bevestigingsdialoog vir beide die header- en FAB-variant van die
/// vullis-aksie. Waarsku die gebruiker wanneer 'n aantal geselekteerde rye tans
/// deur die soektog/filters versteek is, en dat kind-rye saam verwyder word
/// (hiërargie-bladsye).
Future<void> confirmBulkDelete<T>(
  BuildContext context,
  SelectionController<T> controller, {
  required String confirmTitle,
  required String confirmMessage,
  required Future<void> Function(BuildContext context, Set<T> ids) onDelete,
  String? childWarning,
  int Function()? hiddenSelectedCount,
}) async {
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
          if (hiddenSelectedCount != null && hiddenSelectedCount() > 0) ...[
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
                      "${hiddenSelectedCount()} van die geselekteerde rye is tans deur die soektog/filters versteek — hulle sal steeds verwyder word.",
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
                        childWarning,
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

/// Staan-aansig van die vullis-aksie vir [FixedPageHeader].
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
          onPressed: () => confirmBulkDelete(
            context,
            controller,
            confirmTitle: confirmTitle,
            confirmMessage: confirmMessage,
            onDelete: onDelete,
            childWarning: childWarning,
            hiddenSelectedCount: hiddenSelectedCount,
          ),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: CountBadge(controller.count),
        ),
      ],
    );
  }
}

/// Rooi vullis FloatingActionButton wat onder-regs verskyn terwyl kies-modus
/// aktief is en ten minste een ry gekies is. Blaai na die web se delete-knoppie
/// (rooi agtergrond met 'n vullis-ikoon — IoTrashOutline).
class BulkDeleteFloatingAction<T> extends StatelessWidget {
  final SelectionController<T> controller;
  final Future<void> Function(BuildContext context, Set<T> ids) onDelete;
  final String confirmTitle;
  final String confirmMessage;
  final String? childWarning;

  /// Returner die aantal geselekteerde rye wat tans deur die soektog/filters
  /// versteek is. Wanneer dit > 0 is, wys die bevestiging 'n waarskuwing.
  /// Null skakel die waarskuwing af.
  final int Function()? hiddenSelectedCount;

  const BulkDeleteFloatingAction({
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
    return FloatingActionButton(
      heroTag: null,
      tooltip: 'Verwyder geselekteer',
      backgroundColor: AppColors.errorRed,
      foregroundColor: Colors.white,
      elevation: 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.delete_outline, size: 24),
          Positioned(
            right: -8,
            top: -8,
            child: CountBadge(controller.count),
          ),
        ],
      ),
      onPressed: () => confirmBulkDelete(
        context,
        controller,
        confirmTitle: confirmTitle,
        confirmMessage: confirmMessage,
        onDelete: onDelete,
        childWarning: childWarning,
        hiddenSelectedCount: hiddenSelectedCount,
      ),
    );
  }
}

/// Header-"X"-knoppie wat net in kies-modus verskyn sodat die gebruiker kan
/// ontsnap sonder om iets te verwyder.
class SelectionExitAction<T> extends StatelessWidget {
  final SelectionController<T> controller;
  final VoidCallback onExit;

  const SelectionExitAction({
    super.key,
    required this.controller,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isSelecting) {
      return const SizedBox.shrink();
    }
    return HeaderIconAction(
      icon: Icons.close,
      tooltip: "Kanselleer keuse",
      onTap: onExit,
    );
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
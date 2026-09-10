import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'header_action_button.dart';

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

/// Gedeelde bevestigingsdialoog vir beide die header- en FAB-variant van die
/// vullis-aksie. Warning die gebruiker dat kind-rye saam verwyder word
/// (hiërargie-bladsye).
Future<void> confirmBulkDelete<T>(
  BuildContext context,
  SelectionController<T> controller, {
  required String confirmTitle,
  required String confirmMessage,
  required Future<void> Function(BuildContext context, Set<T> ids) onDelete,
  String? childWarning,
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

/// Staan-aansig van die vullis-aksie vir [FixedPageHeader].
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
          onPressed: () => confirmBulkDelete(
            context,
            controller,
            confirmTitle: confirmTitle,
            confirmMessage: confirmMessage,
            onDelete: onDelete,
            childWarning: childWarning,
          ),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: _CountBadge(
            count: controller.count,
            background: AppColors.gold,
          ),
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

  const BulkDeleteFloatingAction({
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
            child: _CountBadge(count: controller.count),
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

class _CountBadge extends StatelessWidget {
  final int count;
  final Color? background;

  const _CountBadge({required this.count, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background ?? AppColors.gold,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

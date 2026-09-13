import 'package:flutter/material.dart';
import 'card_data_row.dart';
import 'selection_manager.dart';

/// 'n [CardDataRow] wat die universele kies-modus hanteer: wanneer
/// [selection.isSelecting] waar is, word 'n kiesvak aan die linkerkant gewys
/// en tik/lankdruk kies/toe-vee die ry; andersins word [onOpen] op 'n tik
/// uitgevoer en lankdruk begin kies-modus.
class SelectableRow<T> extends StatelessWidget {
  final T id;
  final SelectionController<T> selection;
  final List<Widget> children;
  final Widget? trailing;
  final VoidCallback onOpen;

  /// Oorheers die standaard lankdruk (wat kies-modus begin). Bladsye wat 'n
  /// reg-toets op lankdruk toepas, gee hier 'n bewaakte handler om verby te gee.
  final VoidCallback? onLongPress;

  const SelectableRow({
    super.key,
    required this.id,
    required this.selection,
    required this.children,
    required this.onOpen,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final selecting = selection.isSelecting;
    return CardDataRow(
      leading: selecting
          ? Checkbox(
              value: selection.isSelected(id),
              onChanged: (_) => selection.toggle(id),
            )
          : null,
      trailing: trailing,
      onTap: selecting ? () => selection.toggle(id) : onOpen,
      onLongPress: onLongPress ??
          () {
            selection.enter();
            selection.toggle(id);
          },
      children: children,
    );
  }
}

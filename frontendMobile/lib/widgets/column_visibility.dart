import 'package:flutter/material.dart';
import 'count_badge.dart';

/// Defines a single column in a list/table.
class ColumnDef {
  final String key;
  final String label;
  final bool defaultVisible;

  const ColumnDef({
    required this.key,
    required this.label,
    this.defaultVisible = true,
  });
}

/// Manages which columns are shown/hidden.
class ColumnVisibilityController extends ChangeNotifier {
  final List<ColumnDef> _allColumns;
  final Set<String> _hidden = {};

  ColumnVisibilityController(this._allColumns) {
    // Start with all default-visible columns shown
    for (final col in _allColumns) {
      if (!col.defaultVisible) _hidden.add(col.key);
    }
  }

  /// Columns that should be rendered.
  List<ColumnDef> get visibleColumns =>
      _allColumns.where((c) => !_hidden.contains(c.key)).toList();

  bool isVisible(String key) => !_hidden.contains(key);

  void toggle(String key) {
    if (_hidden.contains(key)) {
      _hidden.remove(key);
    } else {
      _hidden.add(key);
    }
    notifyListeners();
  }

  void reset() {
    _hidden.clear();
    for (final col in _allColumns) {
      if (!col.defaultVisible) _hidden.add(col.key);
    }
    notifyListeners();
  }

  int get hiddenCount => _hidden.length;
  List<ColumnDef> get allColumns => _allColumns;
}

/// Button widget that opens a column visibility popup next to the button.
class ColumnVisibilityButton extends StatefulWidget {
  final ColumnVisibilityController controller;

  const ColumnVisibilityButton({
    super.key,
    required this.controller,
  });

  @override
  State<ColumnVisibilityButton> createState() => _ColumnVisibilityButtonState();
}

class _ColumnVisibilityButtonState extends State<ColumnVisibilityButton> {
  final GlobalKey _buttonKey = GlobalKey();

  void _showPopup() async {
    final RenderBox? button =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'Wys kolomme',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0E1E3B),
            ),
          ),
        ),
        ...widget.controller.allColumns.map(
          (col) => CheckedPopupMenuItem<String>(
            value: col.key,
            checked: widget.controller.isVisible(col.key),
            child: Text(col.label, style: const TextStyle(fontSize: 13)),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__reset__',
          child: Text(
            'Reset',
            style: TextStyle(color: Color(0xFF935E28)),
          ),
        ),
      ],
    );

    if (result != null && mounted) {
      setState(() {
        if (result == '__reset__') {
          widget.controller.reset();
        } else {
          widget.controller.toggle(result);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.controller.hiddenCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: _buttonKey,
          tooltip: 'Wys kolomme',
          icon: const Icon(Icons.view_column, color: Colors.white, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 30 / 255),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _showPopup,
        ),
        if (hidden > 0)
          Positioned(
            right: -4,
            top: -4,
            child: CountBadge(hidden),
          ),
      ],
    );
  }
}

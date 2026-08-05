import 'package:flutter/material.dart';

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
class ColumnVisibilityController {
  final String storageKey;
  final List<ColumnDef> _allColumns;
  final Set<String> _hidden = {};

  ColumnVisibilityController(this.storageKey, this._allColumns) {
    // Start with all default-visible columns shown
    for (final col in _allColumns) {
      if (!col.defaultVisible) _hidden.add(col.key);
    }
  }

  /// Columns that should be rendered.
  List<ColumnDef> get visibleColumns =>
      _allColumns.where((c) => !_hidden.contains(c.key)).toList();

  bool isVisible(String key) => !_hidden.contains(key);
  bool isHidden(String key) => _hidden.contains(key);

  void toggle(String key) {
    if (_hidden.contains(key)) {
      _hidden.remove(key);
    } else {
      _hidden.add(key);
    }
  }

  void reset() {
    _hidden.clear();
    for (final col in _allColumns) {
      if (!col.defaultVisible) _hidden.add(col.key);
    }
  }

  int get hiddenCount => _hidden.length;
  List<ColumnDef> get allColumns => _allColumns;
}

/// Button widget that opens a column visibility popup next to the button.
class ColumnVisibilityButton extends StatefulWidget {
  final ColumnVisibilityController controller;

  /// In [FixedPageHeader] word slegs die ikoon gewys om spasie te spaar.
  final bool iconOnly;

  const ColumnVisibilityButton({
    super.key,
    required this.controller,
    this.iconOnly = false,
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
        Navigator.of(context).overlay?.context.findRenderObject()
            as RenderBox?;
    if (button == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero), ancestor: overlay),
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
    if (widget.iconOnly) {
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(
                  color: Color(0xFF935E28),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$hidden',
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
    return InkWell(
      key: _buttonKey,
      onTap: _showPopup,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 30 / 255),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_column, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            const Text(
              'Kolomme',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (hidden > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: const BoxDecoration(
                  color: Color(0xFF935E28),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  '$hidden',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

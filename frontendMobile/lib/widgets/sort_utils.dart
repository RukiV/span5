import 'package:flutter/material.dart';

/// Manages click-to-sort state for one list.
class SortController {
  String? _sortKey;
  bool _ascending = true;

  String? get sortKey => _sortKey;
  bool get ascending => _ascending;
  bool get isActive => _sortKey != null;

  int get direction => _ascending ? 1 : -1;

  /// Toggle: if same key → reverse direction; else → ascending for [key].
  void toggle(String key) {
    if (_sortKey == key) {
      _ascending = !_ascending;
    } else {
      _sortKey = key;
      _ascending = true;
    }
  }

  void clear() {
    _sortKey = null;
    _ascending = true;
  }

  /// Call this after toggling when using [setState].
  SortController copy() {
    final c = SortController();
    c._sortKey = _sortKey;
    c._ascending = _ascending;
    return c;
  }

  /// Sort arrow indicator for a given key.
  /// Returns ' ▲' if ascending, ' ▼' if descending, '' if not active.
  String indicator(String key) {
    if (_sortKey != key) return '';
    return _ascending ? ' ▲' : ' ▼';
  }
}

/// Tappable column header widget for the "header row" pattern.
///
/// Usage:
///   SortableHeader(label: "Naam", sortKey: "name", controller: sortCtrl, onPressed: () => setState(() => sortCtrl.toggle("name")))
class SortableHeader extends StatelessWidget {
  final String label;
  final String sortKey;
  final SortController controller;
  final VoidCallback onPressed;
  final int flex;
  final TextAlign textAlign;

  const SortableHeader({
    super.key,
    required this.label,
    required this.sortKey,
    required this.controller,
    required this.onPressed,
    this.flex = 2,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = controller.sortKey == sortKey;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: textAlign == TextAlign.right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.bold,
                fontSize: 11,
                decoration: isActive ? TextDecoration.underline : null,
                decorationColor: const Color(0xFF935E28),
                decorationThickness: 2,
              ),
            ),
            if (isActive)
              Text(
                controller.ascending ? ' ▲' : ' ▼',
                style: const TextStyle(
                  color: Color(0xFF935E28),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

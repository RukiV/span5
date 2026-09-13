import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Sort direction for a single [SortCriterion].
enum SortDirection { asc, desc }

/// One active sort criterion (column + direction), in priority order.
class SortCriterion {
  final String key;
  SortDirection direction;

  SortCriterion({required this.key, this.direction = SortDirection.asc});

  bool get isDesc => direction == SortDirection.desc;

  Map<String, dynamic> toJson() =>
      {'key': key, 'direction': direction.name};
}

/// Manages an ordered list of sort criteria for one list, persisted between
/// app restarts and cleared on logout.
///
/// Persistence lives in `SharedPreferences` under keys prefixed with
/// `sort_` so [clearAll] can wipe every list's sorts in one go.
class MultiSortController {
  static const String _prefix = 'sort_';

  final String storageKey;
  final List<String> _columnKeys;
  final List<SortCriterion> _sorts = [];
  bool _loaded = false;

  /// Optionally seed a default sort (e.g. first load) before the user changes it.
  MultiSortController(
    this.storageKey,
    List<String> columnKeys, {
    List<SortCriterion> defaultSorts = const [],
  }) : _columnKeys = List.of(columnKeys) {
    for (final criterion in defaultSorts) {
      if (_columnKeys.contains(criterion.key)) {
        _sorts.add(criterion);
      }
    }
  }

  /// Loads persisted sorts (validated against the known column keys).
  Future<void> initialize() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      _sorts.clear();
      for (final item in decoded) {
        final map = item as Map<String, dynamic>;
        final key = map['key'] as String?;
        if (key != null && _columnKeys.contains(key)) {
          _sorts.add(SortCriterion(
            key: key,
            direction: map['direction'] == 'desc'
                ? SortDirection.desc
                : SortDirection.asc,
          ));
        }
      }
    } catch (_) {
      // Corrupt or unreadable prefs — fall back to defaults.
    }
    _dedupe();
  }

  /// Persists the current criteria for this list.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode(_sorts.map((s) => s.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort; never block a UI interaction on a write failure.
    }
  }

  String get _prefKey => '$_prefix$storageKey';

  List<SortCriterion> get sorts => List.unmodifiable(_sorts);
  bool get isActive => _sorts.isNotEmpty;
  List<String> get columnKeys => List.unmodifiable(_columnKeys);
  bool hasSort(String key) => _sorts.any((s) => s.key == key);

  /// Appends a column at the lowest priority.
  void add(String key) {
    if (!_columnKeys.contains(key) || hasSort(key)) return;
    _sorts.add(SortCriterion(key: key));
    _persist();
  }

  void remove(String key) {
    _sorts.removeWhere((s) => s.key == key);
    _persist();
  }

  void toggleDirection(String key) {
    final criterion = _sorts.where((s) => s.key == key).firstOrNull;
    if (criterion == null) return;
    criterion.direction = criterion.isDesc
        ? SortDirection.asc
        : SortDirection.desc;
    _persist();
  }

  /// Moves a criterion up (-1) or down (+1) in priority order.
  void move(String key, int delta) {
    final index = _sorts.indexWhere((s) => s.key == key);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= _sorts.length) return;
    final criterion = _sorts.removeAt(index);
    _sorts.insert(target, criterion);
    _persist();
  }

  void clear() {
    _sorts.clear();
    _persist();
  }

  void _dedupe() {
    final seen = <String>{};
    _sorts.removeWhere((s) => !seen.add(s.key));
  }

  /// Returns a new, multi-key-sorted list. `valueOf` extracts the comparable
  /// value (String/num/DateTime) for a column key from each item.
  List<T> apply<T>(List<T> items, dynamic Function(T item, String key) valueOf) {
    if (_sorts.isEmpty) return List.of(items);
    final result = List.of(items);
    result.sort((a, b) {
      for (final criterion in _sorts) {
        final cmp = _compare(valueOf(a, criterion.key), valueOf(b, criterion.key));
        if (cmp != 0) return criterion.isDesc ? -cmp : cmp;
      }
      return 0;
    });
    return result;
  }

  int _compare(dynamic a, dynamic b) {
    if (a is num && b is num) {
      return a.compareTo(b);
    }
    if (a is DateTime && b is DateTime) {
      return a.compareTo(b);
    }
    return '${a ?? ''}'.toLowerCase().compareTo('${b ?? ''}'.toLowerCase());
  }

  /// Removes every persisted sort (called on logout so one user's preferences
  /// never leak into the next session).
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
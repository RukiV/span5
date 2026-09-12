import 'package:flutter/foundation.dart';

/// Algemene kelder vir 'n gelyste, in-geheue kas van API-entities.
///
/// Vervang die herhaalde patroon van
///   `static final List<T> _x = [];`
///   `static final ValueNotifier<List<T>> xNotifier = ValueNotifier(_x);`
///   `static Future<void> fetchX() async { ... _x.clear(); ...notifier.value = List.from(_x); ... }`
///
/// Die kas word slegs ná 'n suksesvolle [fetch] vervang. As die netwerk-/parse
/// stap misluk, bly die vorige items en notifier onaangeraak en word [lastError]
/// gevul.
class CachedListManager<T> {
  CachedListManager({required Future<List<T>> Function() load}) : _load = load;

  final Future<List<T>> Function() _load;
  final List<T> _items = [];
  final ValueNotifier<List<T>> notifier = ValueNotifier(List<T>.empty());

  Future<void>? _inFlight;

  String? lastError;

  @visibleForTesting
  bool get isLoaded => _items.isNotEmpty;

  List<T> get values => List.unmodifiable(_items);

  /// Vervang die kas-inhoud en stel die notifier met 'n vars momentopname.
  void replaceAll(List<T> items) {
    _items
      ..clear()
      ..addAll(items);
    notifier.value = List.from(items);
  }

  /// Laai die lys na die kas.
  ///
  /// Gelyktydige oproepe terwyl 'n laai aan die gang is, deel dieselfde
  /// in-vlug-versoek (hulle wag op die lopende [Future]) in plaas van om 'n
  /// tweede parallelle versoek te begin. So kan 'n ouer respons nie ná 'n
  /// nuwer een 'n pas-verwyderde ry terug bring nie en word die data net een
  /// keer gedupliseer.
  Future<void> fetch() {
    final current = _inFlight;
    if (current != null) return current;

    final future = _runFetch();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _runFetch() async {
    try {
      final result = await _load();
      lastError = null;
      replaceAll(result);
    } catch (e) {
      lastError = e.toString();
      debugPrint("CachedListManager fetch error: $e");
    }
  }

  @visibleForTesting
  Future<void> ensureLoaded() async {
    if (_items.isEmpty) {
      await fetch();
    }
  }

  /// Maak die kas skoon (toets-nutsitem).
  @visibleForTesting
  void reset() {
    replaceAll(List<T>.empty());
    lastError = null;
  }
}

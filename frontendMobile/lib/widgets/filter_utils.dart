import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Die aktiewe filterwaardes vir een lys: soekteks, die ligging-kaskade
/// (terrein › gebou › lokaal), 'n opsionele status en watter kolom die soektog
/// moet bypas ('all' = soek oor alle kolomme).
class FilterValues {
  final String search;
  final int? campusId;
  final int? buildingId;
  final int? roomId;
  final String status;

  /// Sleutel van die kolom waaroor gesoek word; 'all' = oor alle kolomme.
  final String columnKey;

  const FilterValues({
    this.search = '',
    this.campusId,
    this.buildingId,
    this.roomId,
    this.status = '',
    this.columnKey = 'all',
  });

  bool get isActive =>
      search.isNotEmpty ||
      campusId != null ||
      buildingId != null ||
      roomId != null ||
      status.isNotEmpty ||
      columnKey != 'all';

  /// Hoeveel afsonderlike filtervelde tans gevul is (vir die badge-telling).
  int get activeCount =>
      (search.isNotEmpty ? 1 : 0) +
      (campusId != null ? 1 : 0) +
      (buildingId != null ? 1 : 0) +
      (roomId != null ? 1 : 0) +
      (status.isNotEmpty ? 1 : 0) +
      (columnKey != 'all' ? 1 : 0);

  Map<String, dynamic> toJson() => {
        'search': search,
        'campus_id': campusId,
        'building_id': buildingId,
        'room_id': roomId,
        'status': status,
        'column_key': columnKey,
      };

  @override
  bool operator ==(Object other) =>
      other is FilterValues &&
      other.search == search &&
      other.campusId == campusId &&
      other.buildingId == buildingId &&
      other.roomId == roomId &&
      other.status == status &&
      other.columnKey == columnKey;

  @override
  int get hashCode =>
      Object.hash(search, campusId, buildingId, roomId, status, columnKey);
}

/// Bestuur die verenigde filter vir een lys, gehou tussen app-herstarts en
/// uitgevee op uitlog. Tuis in `SharedPreferences` onder sleutels wat met
/// `fil_` begin sodat [clearAll] elke lys se filter in een slag kan uitvee.
///
/// Die bladsy bly self verantwoordelik vir sy vertoonstaat; hierdie objek is
/// die persistensie-kanaal en die badge-/aktief-agtige bron vir [FilterButton].
class FilterController {
  static const String _prefix = 'fil_';

  final String storageKey;
  FilterValues _value = const FilterValues();
  bool _loaded = false;

  FilterController(this.storageKey);

  String get _prefKey => '$_prefix$storageKey';

  FilterValues get value => _value;
  bool get isActive => _value.isActive;
  int get activeCount => _value.activeCount;
  String get search => _value.search;
  int? get campusId => _value.campusId;
  int? get buildingId => _value.buildingId;
  int? get roomId => _value.roomId;
  String get status => _value.status;
  String get columnKey => _value.columnKey;

  /// Laai die gehoue filter (indien enige) in. Roep dit een keer aan, gewoonlik
  /// in `initState`, en seed dan die bladsy se staat daarmee.
  Future<void> initialize() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _value = FilterValues(
        search: map['search'] is String ? map['search'] as String : '',
        campusId: map['campus_id'] is int ? map['campus_id'] as int : null,
        buildingId: map['building_id'] is int
            ? map['building_id'] as int
            : null,
        roomId: map['room_id'] is int ? map['room_id'] as int : null,
        status: map['status'] is String ? map['status'] as String : '',
        columnKey: map['column_key'] is String
            ? map['column_key'] as String
            : 'all',
      );
    } catch (_) {
      // Korrupte of onleesbare voorkeure — keer terug na geen filter nie.
    }
  }

  /// Stoor die soekteks. Iteratief op elke aanslag gekoppel aan die bladsy se
  /// soekveld sodat die kop- en filterpaneel-soek dieselfde teks deel.
  void setSearch(String text) {
    if (_value.search == text) return;
    _value = FilterValues(
      search: text,
      campusId: _value.campusId,
      buildingId: _value.buildingId,
      roomId: _value.roomId,
      status: _value.status,
      columnKey: _value.columnKey,
    );
    _persist();
  }

  /// Stoor die kolom waaroor die soektog moet werk ('all' = alle kolomme).
  void setColumnKey(String columnKey) {
    if (_value.columnKey == columnKey) return;
    _value = FilterValues(
      search: _value.search,
      campusId: _value.campusId,
      buildingId: _value.buildingId,
      roomId: _value.roomId,
      status: _value.status,
      columnKey: columnKey,
    );
    _persist();
  }

  /// Stoor die volle ligging-kaskade-pad.
  void setLocation(int? campusId, int? buildingId, int? roomId) {
    if (_value.campusId == campusId &&
        _value.buildingId == buildingId &&
        _value.roomId == roomId) {
      return;
    }
    _value = FilterValues(
      search: _value.search,
      campusId: campusId,
      buildingId: buildingId,
      roomId: roomId,
      status: _value.status,
      columnKey: _value.columnKey,
    );
    _persist();
  }

  /// Stoor die statusfilter ('n leë string beteken "geen statusfilter nie").
  void setStatus(String status) {
    if (_value.status == status) return;
    _value = FilterValues(
      search: _value.search,
      campusId: _value.campusId,
      buildingId: _value.buildingId,
      roomId: _value.roomId,
      status: status,
      columnKey: _value.columnKey,
    );
    _persist();
  }

  /// Vee alle filtervelde vir dié lys uit.
  void clear() {
    if (!_value.isActive) return;
    _value = const FilterValues();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_value.toJson()));
    } catch (_) {
      // Best-effort; blokkeer nooit 'n UI-interaksie op 'n skryffout nie.
    }
  }

  /// Verwyder elke gehoude filter (op uitlog geroep sodat een gebruiker se
  /// voorkeure nooit in die volgende sessie deurlek nie).
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Best-effort skoonmaak.
    }
  }
}
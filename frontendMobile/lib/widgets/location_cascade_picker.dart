import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/campus.dart';
import '../models/building.dart';
import '../models/room.dart';
import '../services/campus_service.dart';
import 'searchable_dropdown.dart';

/// Hoe diep die kieser mag gaan.
enum LocationDepth { campus, building, room }

/// Progressiewe ligging-kieser: Terreine › Gebou › Lokaal.
///
/// Vervang die ou stapel van drie afsonderlike keuselyste met een veld wat
/// aanbeweeg soos jy kies, plus 'n broodkrummel wat wys waar jy is. Tik op 'n
/// broodkrummel om na daardie vlak terug te keer.
///
/// Die data kom heeltemal uit [CampusService] se bestaande boom
/// (Terrein → Geboue → Lokale) — geen nuwe diens of eindpunt nie.
class LocationCascadePicker extends StatefulWidget {
  final LocationDepth depth;
  final int? initialCampusId;
  final int? initialBuildingId;
  final int? initialRoomId;

  /// Vuur na elke keuse of terugstelling met die volle pad.
  final void Function(int? campusId, int? buildingId, int? roomId) onChanged;

  final String? label;
  final String? errorText;

  const LocationCascadePicker({
    super.key,
    this.depth = LocationDepth.room,
    this.initialCampusId,
    this.initialBuildingId,
    this.initialRoomId,
    required this.onChanged,
    this.label,
    this.errorText,
  });

  @override
  State<LocationCascadePicker> createState() => _LocationCascadePickerState();
}

class _LocationCascadePickerState extends State<LocationCascadePicker> {
  int? _campusId;
  int? _buildingId;
  int? _roomId;

  @override
  void initState() {
    super.initState();
    _campusId = widget.initialCampusId;
    _buildingId = widget.initialBuildingId;
    _roomId = widget.initialRoomId;
  }

  @override
  void didUpdateWidget(LocationCascadePicker old) {
    super.didUpdateWidget(old);
    // Die ouer kan die ligging van buite af stel (bv. ná 'n QR-skandering of
    // sodra die kampusdata gelaai is). Volg dit sonder om die gebruiker se eie
    // keuse te oorskryf.
    if (widget.initialCampusId != old.initialCampusId ||
        widget.initialBuildingId != old.initialBuildingId ||
        widget.initialRoomId != old.initialRoomId) {
      setState(() {
        _campusId = widget.initialCampusId;
        _buildingId = widget.initialBuildingId;
        _roomId = widget.initialRoomId;
      });
    }
  }

  /// Hoeveel vlakke die kieser in totaal mag vul.
  int get _targetLevels => widget.depth.index + 1;

  /// Hoeveel vlakke reeds gekies is.
  int get _filledLevels {
    if (_roomId != null) return 3;
    if (_buildingId != null) return 2;
    if (_campusId != null) return 1;
    return 0;
  }

  bool get _isComplete => _filledLevels >= _targetLevels;

  /// Maak alles vanaf [level] skoon (0 = terrein, 1 = gebou, 2 = lokaal).
  void _clearFromLevel(int level) {
    setState(() {
      if (level <= 0) {
        _campusId = null;
        _buildingId = null;
        _roomId = null;
      } else if (level == 1) {
        _buildingId = null;
        _roomId = null;
      } else if (level == 2) {
        _roomId = null;
      }
    });
    widget.onChanged(_campusId, _buildingId, _roomId);
  }

  void _select(int level, int id, String labelName) {
    setState(() {
      if (level == 0) {
        _campusId = id;
        _buildingId = null;
        _roomId = null;
      } else if (level == 1) {
        _buildingId = id;
        _roomId = null;
      } else {
        _roomId = id;
      }
    });
    widget.onChanged(_campusId, _buildingId, _roomId);

    const levelNames = ['Terrein', 'Gebou', 'Lokaal'];
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('✓ ${levelNames[level]} gekies: $labelName'),
          duration: const Duration(milliseconds: 1200),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Campus? _campusOf(List<Campus> campuses) {
    for (final c in campuses) {
      if (c.id == _campusId) return c;
    }
    return null;
  }

  Building? _buildingOf(List<Campus> campuses) {
    final campus = _campusOf(campuses);
    if (campus == null) return null;
    for (final b in campus.buildings) {
      if (b.id == _buildingId) return b;
    }
    return null;
  }

  Room? _roomOf(List<Campus> campuses) {
    final building = _buildingOf(campuses);
    if (building == null) return null;
    for (final r in building.rooms ?? const <Room>[]) {
      if (r.id == _roomId) return r;
    }
    return null;
  }

  Widget _buildBreadcrumb(List<Campus> campuses) {
    // Wortel is altyd sigbaar; daarna een krummel per gemaakte keuse.
    final crumbs = <({int level, String name})>[(level: -1, name: 'Terreine')];

    final campus = _campusOf(campuses);
    if (campus != null) crumbs.add((level: 0, name: campus.name));

    final building = _buildingOf(campuses);
    if (building != null) crumbs.add((level: 1, name: building.name));

    final room = _roomOf(campuses);
    if (room != null) crumbs.add((level: 2, name: room.name));

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          InkWell(
            onTap: () => _clearFromLevel(crumbs[i].level + 1),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: i == crumbs.length - 1
                    ? AppColors.lavender
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                crumbs[i].name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: i == crumbs.length - 1
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          // Die laaste pyltjie verdwyn sodra die pad klaar is.
          if (i < crumbs.length - 1 || !_isComplete)
            const Text('›', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ],
    );
  }

  List<SearchableDropdownItem<int>> _currentOptions(List<Campus> campuses) {
    switch (_filledLevels) {
      case 0:
        return [
          for (final c in campuses)
            SearchableDropdownItem(value: c.id, label: '${c.id} - ${c.name}'),
        ];
      case 1:
        final campus = _campusOf(campuses);
        return [
          for (final b in campus?.buildings ?? const <Building>[])
            SearchableDropdownItem(value: b.id, label: '${b.id} - ${b.name}'),
        ];
      case 2:
        final building = _buildingOf(campuses);
        return [
          for (final r in building?.rooms ?? const <Room>[])
            SearchableDropdownItem(value: r.id, label: '${r.id} - ${r.name}'),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Campus>>(
      valueListenable: CampusService.campusesNotifier,
      builder: (context, campuses, _) {
        const hints = ['Kies Terrein...', 'Kies Gebou...', 'Kies Lokaal...'];
        final level = _filledLevels;
        final hint = _isComplete ? 'Ligging voltooi' : hints[level];
        final options =
            _isComplete ? <SearchableDropdownItem<int>>[] : _currentOptions(campuses);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
            ],
            _buildBreadcrumb(campuses),
            const SizedBox(height: 6),
            SearchableDropdown<int>(
              hint: hint,
              items: options,
              enabled: !_isComplete,
              // Altyd leeg: die keuse self word in die broodkrummel gewys, en
              // die veld beweeg aan na die volgende vlak.
              value: null,
              onChanged: (id) {
                if (id == null) return;
                final picked = options.where((o) => o.value == id).firstOrNull;
                _select(level, id, picked?.label ?? '$id');
              },
              trailing: level > 0
                  ? IconButton(
                      icon: const Icon(Icons.keyboard_return, size: 20),
                      color: AppColors.gold,
                      tooltip: 'Terug na vorige vlak',
                      onPressed: () => _clearFromLevel(level - 1),
                    )
                  : null,
            ),
            if (widget.errorText != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.errorText!,
                style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }
}

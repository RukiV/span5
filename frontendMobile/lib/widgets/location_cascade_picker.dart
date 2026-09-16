import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/campus.dart';
import '../models/building.dart';
import '../models/room.dart';
import '../services/campus_service.dart';
import 'inline_searchable_dropdown.dart';
import 'searchable_dropdown.dart' show SearchableDropdownItem;

/// Hoe diep die kieser mag gaan.
enum LocationDepth { campus, building, room }

/// Progressiewe ligging-kieser: Terreine › Gebou › Lokaal.
///
/// Vervang die ou stapel van drie afsonderlike keuselyste met een veld wat
/// aanbeweeg soos jy kies, plus 'n broodkrummel wat wys waar jy is. Tik op 'n
/// broodkrummel om na daardie vlak terug te keer.
///
/// By die terrein-opsies is daar twee ekstra sprong-opsies ("Kies Gebou" en
/// "Kies Lokaal") en by die gebou-opsies een ("Kies Lokaal"). Die spronge wys
/// die volledige lys van daardie vlak oor al die terreine, sodat 'n gebou of
/// lokaal direk gekies kan word — die terrein (en gebou) word dan outomaties
/// terug herlei vanuit die gekose gebou/lokaal. Die data kom heeltemal uit
/// [CampusService] se bestaande boom (Terrein → Geboue → Lokale) — geen nuwe
/// diens of eindpunt nie.
class LocationCascadePicker extends StatefulWidget {
  final LocationDepth depth;
  final int? initialCampusId;
  final int? initialBuildingId;
  final int? initialRoomId;

  /// Vuur na elke keuse of terugstelling met die volle pad.
  final void Function(int? campusId, int? buildingId, int? roomId) onChanged;

  final String? label;
  final String? errorText;

  /// Maak die etiket (en veldraam) rooi — gebruik vir vereiste liggings wat
  /// nog nie gekies is nie.
  final bool error;

  /// Wys die krummelpad bo die kieser-veld. Skakel af (false) wanneer die
  /// ouder self 'n opsommingsblok bokant die veld wys.
  final bool showBreadcrumb;

  /// Wys 'n wysig-inskiet by vlak 0 wanneer 'n geskandeerde/opgesoekte bate
  /// se bestaande ligging verander word ("Verander ... van ...").
  final bool editing;

  /// Opsionele knoppie (bv. 'n QR-skandering-ikoon) wat regs langs die
  /// keuse-veld vertoon word. Bly in plek ongeag die geselekteerde waarde.
  final Widget? trailing;

  /// Maksimum hoogte vir die opsie-lys. Laat weg (null) sodat die lys met sy
  /// natuurlike hoogte verleng in plaas van 'n skuifwiel te word.
  final double? dropdownMaxHeight;

  const LocationCascadePicker({
    super.key,
    this.depth = LocationDepth.room,
    this.initialCampusId,
    this.initialBuildingId,
    this.initialRoomId,
    required this.onChanged,
    this.label,
    this.errorText,
    this.error = false,
    this.showBreadcrumb = true,
    this.editing = false,
    this.trailing,
    this.dropdownMaxHeight,
  });

  @override
  State<LocationCascadePicker> createState() => _LocationCascadePickerState();
}

/// Watter soort opsie 'n [_LocationChoice] is.
enum _ChoiceType {
  /// 'n Normale terrein-, gebou- of lokaal-keuse.
  campus,
  building,
  room,

  /// "Kies Gebou"-sprong by die terrein-vlak: wys al die geboue oor al die
  /// terreine; die terrein word terug herlei wanneer 'n gebou gekies word.
  jumpGebou,

  /// "Kies Lokaal"-sprong: wys die lokale direk; die gebou en terrein word
  /// terug herlei wanneer 'n lokaal gekies word.
  jumpLokaal,
}

/// 'n Keuse in die kieser: 'n normale vlak-item of een van die spronge.
class _LocationChoice {
  final _ChoiceType type;
  final int? campusId;
  final int? buildingId;
  final int? roomId;
  final String label;
  const _LocationChoice({
    required this.type,
    this.campusId,
    this.buildingId,
    this.roomId,
    required this.label,
  });
}

class _LocationCascadePickerState extends State<LocationCascadePicker> {
  int? _campusId;
  int? _buildingId;
  int? _roomId;

  /// Die terrein-vlak is oorgeslaan ("Kies Gebou"/"Kies Lokaal"): die gebou-
  /// lys wys alle geboue oor alle terreine en die terrein word terug herlei.
  bool _jumpCampus = false;

  /// Die gebou-vlak is oorgeslaan ("Kies Lokaal"): die lokaal-lys wys die
  /// lokale direk en die gebou/terrein word terug herlei.
  bool _jumpBuilding = false;

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
      _jumpCampus = false;
      _jumpBuilding = false;
    });
    widget.onChanged(_campusId, _buildingId, _roomId);
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

  /// Vind die terrein waarin gebou [buildingId] woon.
  int? _campusIdOfBuilding(int buildingId, List<Campus> campuses) {
    for (final c in campuses) {
      for (final b in c.buildings) {
        if (b.id == buildingId) return c.id;
      }
    }
    return null;
  }

  /// Vind die gebou- en terrein-ID waarin lokaal [roomId] woon.
  ({int? campusId, int? buildingId}) _pathOfRoom(
      int roomId, List<Campus> campuses) {
    for (final c in campuses) {
      for (final b in c.buildings) {
        for (final r in b.rooms ?? const <Room>[]) {
          if (r.id == roomId) {
            return (campusId: c.id, buildingId: b.id);
          }
        }
      }
    }
    return (campusId: null, buildingId: null);
  }

  /// Kies die keuse. 'n Normale keuse stel die huidige vlak en vorder; die
  /// spronge ("Kies Gebou"/"Kies Lokaal") slaan vlakke oor, waarna die
  /// oorgelate terrein/gebou terug herlei word sodra 'n gebou/lokaal gekies is.
  void _pick(_LocationChoice choice) {
    final campuses = CampusService.campusesNotifier.value;
    switch (choice.type) {
      case _ChoiceType.campus:
        _campusId = choice.campusId;
        _buildingId = null;
        _roomId = null;
        _jumpCampus = false;
        _jumpBuilding = false;
      case _ChoiceType.jumpGebou:
        _campusId = null;
        _buildingId = null;
        _roomId = null;
        _jumpCampus = true;
        _jumpBuilding = false;
      case _ChoiceType.jumpLokaal:
        if (_campusId != null) {
          // Gebou-vlak: slaan die gebou oor en wys die terrein se lokale.
          _buildingId = null;
          _roomId = null;
          _jumpBuilding = true;
        } else {
          // Terrein-vlak: slaan beide oor en wys alle lokale oor alle terreine.
          _campusId = null;
          _buildingId = null;
          _roomId = null;
          _jumpCampus = true;
          _jumpBuilding = true;
        }
      case _ChoiceType.building:
        _buildingId = choice.buildingId;
        _roomId = null;
        if (_jumpCampus || _campusId == null) {
          _campusId =
              _campusIdOfBuilding(choice.buildingId!, campuses) ?? _campusId;
        }
        _jumpCampus = false;
        _jumpBuilding = false;
      case _ChoiceType.room:
        _roomId = choice.roomId;
        if (_jumpBuilding || _jumpCampus || _campusId == null) {
          final path = _pathOfRoom(choice.roomId!, campuses);
          _campusId = path.campusId ?? _campusId;
          _buildingId = path.buildingId ?? _buildingId;
        }
        _jumpCampus = false;
        _jumpBuilding = false;
    }
    widget.onChanged(_campusId, _buildingId, _roomId);
    setState(() {});
    // Sodra die ligging voltooi is, sluit die sleutelbord outomaties.
    if (_isComplete) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  List<SearchableDropdownItem<_LocationChoice>> _buildOptions(
      List<Campus> campuses) {
    final choices = <_LocationChoice>[];

    if (_roomId != null) {
      // Volledig — geen opsies nie.
      return const [];
    }

    if (_buildingId != null) {
      // Lokaal-vlak: die gebou se lokale.
      final building = _buildingOf(campuses);
      for (final r in building?.rooms ?? const <Room>[]) {
        choices.add(_LocationChoice(
          type: _ChoiceType.room,
          campusId: _campusId,
          buildingId: _buildingId,
          roomId: r.id,
          label: '${r.id} - ${r.name}',
        ));
      }
    } else if (_campusId != null) {
      if (_jumpBuilding) {
        // "Kies Lokaal" by die gebou-vlak: die terrein se lokale.
        final campus = _campusOf(campuses);
        for (final b in campus?.buildings ?? const <Building>[]) {
          for (final r in b.rooms ?? const <Room>[]) {
            choices.add(_LocationChoice(
              type: _ChoiceType.room,
              campusId: _campusId,
              buildingId: b.id,
              roomId: r.id,
              label: '${r.id} - ${r.name} (${b.name})',
            ));
          }
        }
      } else {
        // Gebou-vlak: die terrein se geboue + "Kies Lokaal"-sprong.
        final campus = _campusOf(campuses);
        for (final b in campus?.buildings ?? const <Building>[]) {
          choices.add(_LocationChoice(
            type: _ChoiceType.building,
            campusId: _campusId,
            buildingId: b.id,
            label: '${b.id} - ${b.name}',
          ));
        }
        if (_targetLevels >= 3) {
          choices.add(const _LocationChoice(
            type: _ChoiceType.jumpLokaal,
            label: 'Kies Lokaal',
          ));
        }
      }
    } else if (_jumpCampus) {
      if (_jumpBuilding) {
        // "Kies Lokaal" by die terrein-vlak: alle lokale oor alle terreine.
        for (final c in campuses) {
          for (final b in c.buildings) {
            for (final r in b.rooms ?? const <Room>[]) {
              choices.add(_LocationChoice(
                type: _ChoiceType.room,
                campusId: c.id,
                buildingId: b.id,
                roomId: r.id,
                label: '${r.id} - ${r.name} (${c.name} › ${b.name})',
              ));
            }
          }
        }
      } else {
        // "Kies Gebou" by die terrein-vlak: alle geboue oor alle terreine.
        for (final c in campuses) {
          for (final b in c.buildings) {
            choices.add(_LocationChoice(
              type: _ChoiceType.building,
              campusId: c.id,
              buildingId: b.id,
              label: '${b.id} - ${b.name} (${c.name})',
            ));
          }
        }
        if (_targetLevels >= 3) {
          choices.add(const _LocationChoice(
            type: _ChoiceType.jumpLokaal,
            label: 'Kies Lokaal',
          ));
        }
      }
    } else {
      // Terrein-vlak: die terreine + die twee sprong-opsies.
      for (final c in campuses) {
        choices.add(_LocationChoice(
          type: _ChoiceType.campus,
          campusId: c.id,
          label: '${c.id} - ${c.name}',
        ));
      }
      if (_targetLevels >= 2) {
        choices.add(const _LocationChoice(
          type: _ChoiceType.jumpGebou,
          label: 'Kies Gebou',
        ));
      }
      if (_targetLevels >= 3) {
        choices.add(const _LocationChoice(
          type: _ChoiceType.jumpLokaal,
          label: 'Kies Lokaal',
        ));
      }
    }

    return [
      for (final c in choices) SearchableDropdownItem(value: c, label: c.label),
    ];
  }

  Widget _buildBreadcrumb(List<Campus> campuses) {
    // Een krummel per gemaakte keuse (sonder 'n statiese "Terrein"-wortel).
    // Die eerste krummel tree as wortel op en stel alles terug.
    final crumbs = <({int level, String name})>[];

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
            onTap: () => _clearFromLevel(i == 0 ? 0 : crumbs[i].level + 1),
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

  /// Terug-knoppie soos die web se `cascade-back-btn`: bruin knoppie heel
  /// regs in die veld wat een vlak teruggaan.
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => _clearFromLevel(_filledLevels - 1),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF935E28),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Campus>>(
      valueListenable: CampusService.campusesNotifier,
      builder: (context, campuses, _) {
        const browseHints = [
          'Kies Terrein, Gebou en Lokaal',
          'Kies Gebou...',
          'Kies Lokaal...',
        ];
        final int hintIndex;
        if (_roomId != null) {
          hintIndex = 2;
        } else if (_buildingId != null) {
          hintIndex = 2;
        } else if (_campusId != null) {
          hintIndex = 1;
        } else if (_jumpCampus && _jumpBuilding) {
          hintIndex = 2;
        } else if (_jumpCampus) {
          hintIndex = 1;
        } else {
          hintIndex = 0;
        }
        final String hint;
        if (_isComplete) {
          hint = 'Ligging voltooi — tik om te verander';
        } else if (hintIndex == 0 && widget.editing) {
          hint = 'Verander Terrein, Gebou of Lokaal';
        } else {
          hint = browseHints[hintIndex];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null) ...[
              Text(
                widget.label!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: widget.error ? AppColors.errorRed : AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (widget.showBreadcrumb) ...[
              _buildBreadcrumb(campuses),
              const SizedBox(height: 6),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InlineSearchableDropdown<_LocationChoice>(
                    hint: hint,
                    items: _isComplete ? const [] : _buildOptions(campuses),
                    value: null,
                    enabled: true,
                    error: widget.error,
                    closeOnSelect: false,
                    restoreOnBlur: false,
                    showClear: _filledLevels > 0,
                    onClear: () => _clearFromLevel(0),
                    browseSuffixAction:
                        _filledLevels > 0 ? _buildBackButton() : null,
                    onFocus: () {
                      // "Tik om te verander": 'n voltooide kaskade spring terug
                      // na vlak 0 sodat die hele pad oor gekies kan word.
                      if (_isComplete) _clearFromLevel(0);
                    },
                    onChanged: (v) {
                      if (v != null) _pick(v);
                    },
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
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

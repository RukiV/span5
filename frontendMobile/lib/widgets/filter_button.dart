import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'filter_utils.dart';
import 'header_action_button.dart';
import 'inline_searchable_dropdown.dart';
import 'location_cascade_picker.dart';
import 'searchable_dropdown.dart' show SearchableDropdownItem;

export 'location_cascade_picker.dart' show LocationDepth;
export 'searchable_dropdown.dart' show SearchableDropdownItem;

/// Die verenigde filter-knoppie vir [FixedPageHeader]: 'n ikoon wat die
/// inlyn [FilterPanel] aan- en afskakel. NIE 'n popup nie — die paneel word
/// deur die bladsy self onder die kop gewys en bly oop totdat jy daaraf klik.
class FilterButton extends StatelessWidget {
  final FilterController controller;

  /// Wys of die paneel tans oop is (gou ikoon as aanduiding).
  final bool selected;

  final VoidCallback onPressed;

  /// Dwing die aktiewe-gonser aan ongeag die houer (bv. 'n terrein wat via
  /// navigasie ingebring is eerder as deur die filter gekies).
  final bool? activeOverride;

  const FilterButton({
    super.key,
    required this.controller,
    required this.selected,
    required this.onPressed,
    this.activeOverride,
  });

  @override
  Widget build(BuildContext context) {
    return HeaderIconAction(
      icon: Icons.filter_alt_outlined,
      tooltip: "Filtreer",
      iconColor: selected ? AppColors.gold : Colors.white,
      activeBadge: activeOverride ?? controller.isActive,
      badgeCount: controller.activeCount,
      onTap: onPressed,
    );
  }
}

/// Inlyn-filterpaneel wat onder [FixedPageHeader] uitvou: soekteks, "Soek per
/// kolom" en die ligging-kaskade (terrein › gebou › lokaal) wat met sy volle
/// lys verleng. Bly oop totdat die bladsy dit toemaak.
class FilterPanel extends StatefulWidget {
  /// Persistensie-kanaal vir die bladsy se filter.
  final FilterController controller;

  /// Hoe diep die ligging-kaskade mag gaan (terrein / gebou / lokaal).
  final LocationDepth depth;

  /// Die bladsy se soekveld. Die paneel se soekveld bind direk hieraan sodat
  /// die kop- en paneel-soek altyd dieselfde teks wys.
  final TextEditingController searchController;

  /// Gee die ligging-pad deur sodat die bladsy sy eie staat kan opdateer.
  final void Function(int? campusId, int? buildingId, int? roomId)
      onLocationChanged;

  /// Bladsy vee sy eie filterstaat uit (naas die skoonmaak wat die paneel reeds
  /// via [controller] en die soekveld doen).
  final VoidCallback onReset;

  /// Word geroep wanneer die "Klaar"-knoppie gedruk word.
  final VoidCallback onClose;

  /// Waar die paneel mee oopmaak — die bladsy se huidige ligging (kan verskil
  /// van die gehoude een bv. ná navigasie met 'n `initialCampus`).
  final int? initialCampusId;
  final int? initialBuildingId;
  final int? initialRoomId;

  /// "Soek per kolom"-opsies (bv. "Alle kolomme" + elke kolom). Laat weg om die
  /// kolom-keuselys weg te steek.
  final List<SearchableDropdownItem<String>>? columnItems;

  /// Die huidige kolom-sleutel ('all' = oor alle kolomme).
  final String columnValue;

  /// Word geroep met die gekose kolom-sleutel.
  final ValueChanged<String>? onColumnChanged;

  final String? searchHint;

  const FilterPanel({
    super.key,
    required this.controller,
    required this.depth,
    required this.searchController,
    required this.onLocationChanged,
    required this.onReset,
    required this.onClose,
    this.initialCampusId,
    this.initialBuildingId,
    this.initialRoomId,
    this.columnItems,
    this.columnValue = 'all',
    this.onColumnChanged,
    this.searchHint,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  int? _campusId;
  int? _buildingId;
  int? _roomId;
  late String _column;

  /// Verhoog elke "Maak skoon" sodat die kaskade-kieser hermonteer word met
  /// nul-aanvangs — 'n nuwe sleutel dwing 'n vars interne staat af.
  int _resetToken = 0;

  @override
  void initState() {
    super.initState();
    _campusId = widget.initialCampusId;
    _buildingId = widget.initialBuildingId;
    _roomId = widget.initialRoomId;
    _column = widget.columnValue;
  }

  @override
  void didUpdateWidget(FilterPanel old) {
    super.didUpdateWidget(old);
    // Volg eksterne veranderinge (bv. seeding ná campuses laai).
    if (widget.initialCampusId != old.initialCampusId ||
        widget.initialBuildingId != old.initialBuildingId ||
        widget.initialRoomId != old.initialRoomId) {
      _campusId = widget.initialCampusId;
      _buildingId = widget.initialBuildingId;
      _roomId = widget.initialRoomId;
    }
    if (widget.columnValue != old.columnValue) {
      _column = widget.columnValue;
    }
  }

  /// Hoogte-kap vir die uitvloeibare opsie-lys: die lys verleng so ver as die
  /// spasie op die skerm dit toelaat, dan skuif dit eers as laaste uitweg.
  double _dropdownCapHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height * 0.6;
  }

  void _handleLocation(int? campusId, int? buildingId, int? roomId) {
    setState(() {
      _campusId = campusId;
      _buildingId = buildingId;
      _roomId = roomId;
    });
    widget.controller.setLocation(campusId, buildingId, roomId);
    widget.onLocationChanged(campusId, buildingId, roomId);
  }

  void _handleColumn(String columnKey) {
    setState(() => _column = columnKey);
    widget.controller.setColumnKey(columnKey);
    widget.onColumnChanged?.call(columnKey);
  }

  void _reset() {
    widget.controller.clear();
    widget.searchController.clear();
    setState(() {
      _campusId = null;
      _buildingId = null;
      _roomId = null;
      _column = 'all';
      _resetToken++;
    });
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final cap = _dropdownCapHeight(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.searchController,
            decoration: InputDecoration(
              hintText: widget.searchHint ?? 'Soek...',
              hintStyle: TextStyle(
                  color: Colors.grey.withValues(alpha: 150 / 255),
                  fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.gold),
              isDense: true,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.columnItems != null && widget.columnItems!.isNotEmpty) ...[
            InlineSearchableDropdown<String>(
              label: 'Soek per kolom',
              hint: 'Alle kolomme',
              value: _column == 'all' ? null : _column,
              items: widget.columnItems!,
              closeOnSelect: false,
              restoreOnBlur: true,
              maxHeight: cap,
              onChanged: (v) {
                if (v == null) {
                  _handleColumn('all');
                } else {
                  _handleColumn(v);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
          KeyedSubtree(
            key: ValueKey<int>(_resetToken),
            child: LocationCascadePicker(
              depth: widget.depth,
              initialCampusId: _campusId,
              initialBuildingId: _buildingId,
              initialRoomId: _roomId,
              dropdownMaxHeight: cap,
              onChanged: _handleLocation,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Maak skoon'),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: widget.onClose,
                child: const Text('Klaar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/campus.dart';
import '../models/building.dart';
import '../models/room.dart';

class CascadingLocationFilter extends StatefulWidget {
  final List<Campus> campuses;
  final int? campusId;
  final int? buildingId;
  final int? roomId;
  final int maxLevel;
  final ValueChanged<int?> onCampusChanged;
  final ValueChanged<int?> onBuildingChanged;
  final ValueChanged<int?> onRoomChanged;

  const CascadingLocationFilter({
    super.key,
    required this.campuses,
    this.campusId,
    this.buildingId,
    this.roomId,
    this.maxLevel = 3,
    required this.onCampusChanged,
    required this.onBuildingChanged,
    required this.onRoomChanged,
  });

  @override
  State<CascadingLocationFilter> createState() => _CascadingLocationFilterState();
}

class _CascadingLocationFilterState extends State<CascadingLocationFilter> {
  Campus? get _selectedCampus =>
      widget.campuses.where((c) => c.id == widget.campusId).firstOrNull;

  Building? get _selectedBuilding {
    final campus = _selectedCampus;
    if (campus == null || widget.buildingId == null) return null;
    return campus.buildings.where((b) => b.id == widget.buildingId).firstOrNull;
  }

  Room? get _selectedRoom {
    final building = _selectedBuilding;
    if (building == null || building.rooms == null || widget.roomId == null) return null;
    return building.rooms!.where((r) => r.id == widget.roomId).firstOrNull;
  }

  int get _cascadeLevel {
    if (widget.roomId != null && widget.maxLevel >= 3) return 3;
    if (widget.buildingId != null && widget.maxLevel >= 2) return 2;
    if (widget.campusId != null) return 1;
    return 0;
  }

  String get _placeholder {
    switch (_cascadeLevel) {
      case 0: return "Kies Terrein...";
      case 1: return "Kies Gebou...";
      case 2: return "Kies Lokaal...";
      case 3: return "Ligging voltooi";
      default: return "Kies...";
    }
  }

  bool get _isComplete => _cascadeLevel >= widget.maxLevel;

  void _clearFromLevel(int level) {
    if (level <= 0) {
      widget.onCampusChanged(null);
      widget.onBuildingChanged(null);
      widget.onRoomChanged(null);
    } else if (level == 1) {
      widget.onBuildingChanged(null);
      widget.onRoomChanged(null);
    } else if (level == 2) {
      widget.onRoomChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final breadcrumbItems = <_BreadcrumbItem>[];
    breadcrumbItems.add(_BreadcrumbItem(name: "Terreine", level: -1));
    if (widget.campusId != null && _selectedCampus != null) {
      breadcrumbItems.add(_BreadcrumbItem(name: _selectedCampus!.name, level: 0));
    }
    if (widget.buildingId != null && _selectedBuilding != null) {
      breadcrumbItems.add(_BreadcrumbItem(name: _selectedBuilding!.name, level: 1));
    }
    if (widget.roomId != null && _selectedRoom != null) {
      breadcrumbItems.add(_BreadcrumbItem(name: _selectedRoom!.name, level: 2));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumb(breadcrumbItems),
        const SizedBox(height: 4),
        _buildCascadeControl(),
      ],
    );
  }

  Widget _buildBreadcrumb(List<_BreadcrumbItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          for (int i = 0; i < items.length; i++)
            _buildBreadcrumbItem(items[i], i == items.length - 1),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbItem(_BreadcrumbItem item, bool isLast) {
    final showArrow = !isLast || _cascadeLevel < widget.maxLevel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _clearFromLevel(item.level + 1),
          child: Text(
            item.name,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontWeight: isLast ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        if (showArrow)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              "›",
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildCascadeControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
      child: InkWell(
        onTap: _isComplete ? null : () => _showSearchDialog(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _isComplete ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _placeholder,
                  style: TextStyle(
                    color: _isComplete ? Colors.grey : const Color(0xFF111827),
                    fontSize: 14,
                  ),
                ),
              ),
              if (!_isComplete)
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              if (_cascadeLevel > 0 && !_isComplete)
                const SizedBox(width: 8),
              if (_cascadeLevel > 0 && !_isComplete)
                GestureDetector(
                  onTap: () => _clearFromLevel(_cascadeLevel - 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          "Terug",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CascadeSearchDialog(
        title: _placeholder.replaceAll("...", ""),
        level: _cascadeLevel,
        selectedCampus: _selectedCampus,
        selectedBuilding: _selectedBuilding,
        campuses: widget.campuses,
        onSelected: (id) {
          if (_cascadeLevel == 0) {
            widget.onCampusChanged(id);
            widget.onBuildingChanged(null);
            widget.onRoomChanged(null);
          } else if (_cascadeLevel == 1) {
            widget.onBuildingChanged(id);
            widget.onRoomChanged(null);
          } else if (_cascadeLevel == 2) {
            widget.onRoomChanged(id);
          }
        },
      ),
    );
  }
}

class _BreadcrumbItem {
  final String name;
  final int level;
  _BreadcrumbItem({required this.name, required this.level});
}

class _CascadeSearchDialog extends StatefulWidget {
  final String title;
  final int level;
  final Campus? selectedCampus;
  final Building? selectedBuilding;
  final List<Campus> campuses;
  final ValueChanged<int?> onSelected;

  const _CascadeSearchDialog({
    required this.title,
    required this.level,
    this.selectedCampus,
    this.selectedBuilding,
    required this.campuses,
    required this.onSelected,
  });

  @override
  State<_CascadeSearchDialog> createState() => _CascadeSearchDialogState();
}

class _CascadeSearchDialogState extends State<_CascadeSearchDialog> {
  late List<_DialogItem> allItems;
  late List<_DialogItem> filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    allItems = _buildItems();
    filteredItems = allItems;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_DialogItem> _buildItems() {
    if (widget.level == 0) {
      return widget.campuses.map((c) => _DialogItem(id: c.id, label: c.name)).toList();
    } else if (widget.level == 1) {
      if (widget.selectedCampus == null) return [];
      return widget.selectedCampus!.buildings
          .map((b) => _DialogItem(id: b.id, label: b.name))
          .toList();
    } else if (widget.level == 2) {
      if (widget.selectedBuilding?.rooms == null) return [];
      return widget.selectedBuilding!.rooms!
          .map((r) => _DialogItem(id: r.id, label: r.name))
          .toList();
    }
    return [];
  }

  void _filter(String query) {
    setState(() {
      filteredItems = allItems
          .where((item) => item.label.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Kies ${widget.title}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Soek...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text("Geen resultate nie."))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ListTile(
                          title: Text(item.label),
                          onTap: () {
                            widget.onSelected(item.id);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogItem {
  final int id;
  final String label;
  _DialogItem({required this.id, required this.label});
}

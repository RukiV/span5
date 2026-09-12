import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../services/room_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../models/room.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/filter_button.dart';
import '../../widgets/filter_utils.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/sort_button.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/selection_manager.dart';
import '../../widgets/card_data_row.dart';
import '../asset/asset_page.dart';
import '../reporting/scan_page.dart';
import '../room_checklist/room_checklist_page.dart';
import 'room_detail_page.dart';
import 'add_room_page.dart';

class ManageRoomsPage extends StatefulWidget {
  final Campus? initialCampus;
  final Building? initialBuilding;
  final void Function(Room room)? onRoomSelected;

  const ManageRoomsPage({
    super.key,
    this.initialCampus,
    this.initialBuilding,
    this.onRoomSelected,
  });

  @override
  State<ManageRoomsPage> createState() => _ManageRoomsPageState();
}

class _ManageRoomsPageState extends State<ManageRoomsPage> {
  Campus? _selectedCampus;
  Building? _selectedBuilding;
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  String _columnFilter = 'all';
  bool _filterOpen = false;
  bool _sortOpen = false;
  final FilterController _filterCtrl = FilterController('rooms');
  final MultiSortController _sortCtrl = MultiSortController('rooms', ['name', 'type', 'capacity']);
  final ColumnVisibilityController _colVis =
      ColumnVisibilityController('rooms', [
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'type', label: 'Tipe'),
    const ColumnDef(key: 'capacity', label: 'Kapasiteit'),
  ]);
  final SelectionController<int> _selection = SelectionController<int>();

  @override
  void initState() {
    super.initState();
    _sortCtrl.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _filterCtrl.initialize().then((_) {
      if (!mounted) return;
      _searchController.text = _filterCtrl.search;
      _columnFilter = _filterCtrl.columnKey;
      if (widget.initialCampus == null && _filterCtrl.campusId != null) {
        final campuses = CampusService.campusesNotifier.value;
        final campus =
            campuses.where((c) => c.id == _filterCtrl.campusId).firstOrNull;
        _selectedCampus = campus;
        if (campus != null) {
          _selectedBuilding = campus.buildings
              .where((b) => b.id == _filterCtrl.buildingId)
              .firstOrNull;
        }
      }
      setState(() {});
    });
    if (widget.initialCampus != null) {
      _selectedCampus = widget.initialCampus;
    }
    if (widget.initialBuilding != null) {
      _selectedBuilding = widget.initialBuilding;
    }
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
    _searchController.addListener(() {
      _filterCtrl.setSearch(_searchController.text);
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ManageRoomsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCampus != null) {
      _selectedCampus = widget.initialCampus;
    }
    if (widget.initialBuilding != null) {
      _selectedBuilding = widget.initialBuilding;
    }
  }

  List<Widget> _buildRoomCells(Room room) {
    return _colVis.visibleColumns.map((col) {
      int flex = 2;
      Widget child;
      switch (col.key) {
        case 'name':
          flex = 3;
          child = Text(
            room.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
                fontSize: 16),
          );
          break;
        case 'type':
          flex = 2;
          child = Text(
            room.type,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          );
          break;
        case 'capacity':
          flex = 1;
          child = Text(
            room.capacity?.toString() ?? '-',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          );
          break;
        default:
          child = const SizedBox.shrink();
      }
      return Expanded(flex: flex, child: child);
    }).toList();
  }

  void _closePanels() {
    if (_filterOpen || _sortOpen) {
      setState(() {
        _filterOpen = false;
        _sortOpen = false;
      });
    }
  }

  Future<void> _bulkDeleteRooms(BuildContext context, Set<int> ids) async {
    int ok = 0;
    int fail = 0;
    for (final id in ids) {
      if (await CampusService.removeRoom(id)) {
        ok++;
      } else {
        fail++;
      }
    }
    await CampusService.fetchCampuses();
    if (context.mounted) {
      setState(() => _selection.exit());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fail == 0
              ? "$ok lokaal/lokale verwyder."
              : "$ok verwyder, $fail kon nie verwyder word nie."),
          backgroundColor:
              fail == 0 ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  /// Skandeer 'n lokaal se QR-kode en gaan direk na daardie lokaal se bates.
  Future<void> _scanRoomToViewAssets() async {
    final String? scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanPage(isLocation: true),
      ),
    );
    if (scannedCode == null || !mounted) return;

    final room = await RoomService.getRoomByCode(scannedCode.trim());
    if (!mounted) return;
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Geen lokaal gevind met hierdie kode nie"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (context.mounted) {
      final onRoomSelected = widget.onRoomSelected;
      if (onRoomSelected != null) {
        onRoomSelected(room);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssetsPage(filterRoomId: room.id.toString()),
          ),
        );
      }
    }
  }

  /// Wys die lokaal se skandeerbare QR-kode. Genereer een indien nodig.
  Future<void> _showRoomQrDialog(Room room) async {
    Room displayRoom = room;
    if (room.roomCode == null || room.roomCode!.isEmpty) {
      final generated = await RoomService.ensureRoomCode(room.id);
      if (generated != null && mounted) {
        displayRoom = generated;
        setState(() {});
      }
    }
    if (!mounted) return;

    final code = displayRoom.roomCode;
    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kon nie 'n kode vir hierdie lokaal genereer nie."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayRoom.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text("Lokaal QR-kode",
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Sluit"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<List<Campus>>(
        valueListenable: CampusService.campusesNotifier,
        builder: (context, campuses, _) {
          if (campuses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Re-resolve die gekose kampus/gebou teen die vars `campuses`-lys (nie
          // die ou objekverwysings nie) sodat byvoeg/wysig/verwyder dadelik wys.
          // 'n Gehoude filter word eers toegepas wanneer niks via navigasie
          // (initialCampus/initialBuilding) ingebring is nie.
          Campus? selectedCampus = _selectedCampus != null
              ? campuses.where((c) => c.id == _selectedCampus!.id).firstOrNull
              : (widget.initialCampus == null && _filterCtrl.campusId != null
                  ? campuses
                      .where((c) => c.id == _filterCtrl.campusId)
                      .firstOrNull
                  : null);
          _selectedCampus = selectedCampus;

          Building? selectedBuilding;
          if (_selectedBuilding != null) {
            for (final c in campuses) {
              final match = c.buildings
                  .where((b) => b.id == _selectedBuilding!.id)
                  .firstOrNull;
              if (match != null) {
                selectedBuilding = match;
                break;
              }
            }
          } else if (widget.initialBuilding == null &&
              _filterCtrl.buildingId != null) {
            for (final c in campuses) {
              final match = c.buildings
                  .where((b) => b.id == _filterCtrl.buildingId)
                  .firstOrNull;
              if (match != null) {
                selectedBuilding = match;
                break;
              }
            }
          }
          _selectedBuilding = selectedBuilding;

          return Column(
            children: [
              FixedPageHeader(
                controller: _searchController,
                hintText: "Soek lokale...",
                onChanged: (_) => setState(() {}),
                actions: [
                  FilterButton(
                    controller: _filterCtrl,
                    selected: _filterOpen,
                    activeOverride: _selectedBuilding != null,
                    onPressed: () => setState(() {
                      _filterOpen = !_filterOpen;
                      _sortOpen = false;
                    }),
                  ),
                  if (UserSession.can('rooms.manage')) ...[
                    SelectionExitAction<int>(
                      controller: _selection,
                      onExit: () => setState(() => _selection.exit()),
                    ),
                  ],
                  SortButton(
                    controller: _sortCtrl,
                    selected: _sortOpen,
                    onPressed: () => setState(() {
                      _sortOpen = !_sortOpen;
                      _filterOpen = false;
                    }),
                  ),
                  ColumnVisibilityButton(controller: _colVis, iconOnly: true),
                ],
              ),
              if (_filterOpen)
                FilterPanel(
                  controller: _filterCtrl,
                  depth: LocationDepth.building,
                  searchController: _searchController,
                  searchHint: "Soek lokale...",
                  initialCampusId: _selectedCampus?.id,
                  initialBuildingId: _selectedBuilding?.id,
                  onLocationChanged: (campusId, buildingId, _) =>
                      setState(() {
                    _selectedCampus = campuses
                        .where((c) => c.id == campusId)
                        .firstOrNull;
                    _selectedBuilding = _selectedCampus?.buildings
                        .where((b) => b.id == buildingId)
                        .firstOrNull;
                  }),
                  columnItems: [
                    const SearchableDropdownItem(
                        value: 'all', label: 'Alle kolomme'),
                    ..._colVis.allColumns.map((c) => SearchableDropdownItem(
                        value: c.key, label: c.label)),
                  ],
                  columnValue: _columnFilter,
                  onColumnChanged: (v) => setState(() => _columnFilter = v),
                  onReset: () => setState(() {
                    _selectedCampus = null;
                    _selectedBuilding = null;
                    _columnFilter = 'all';
                  }),
                  onClose: () => setState(() => _filterOpen = false),
                ),
              if (_sortOpen)
                SortPanel(
                  controller: _sortCtrl,
                  columns: _colVis.allColumns,
                  onChanged: () => setState(() {}),
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closePanels,
                  child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Builder(builder: (context) {
                    final baseRooms = _selectedBuilding != null
                        ? (_selectedBuilding!.rooms ?? <Room>[])
                        : campuses
                            .expand((c) => c.buildings)
                            .expand((b) => b.rooms ?? const <Room>[])
                            .toList();
                    final filtered = _sortCtrl.apply(
                      baseRooms
                          .where((r) {
                            if (_query.isEmpty) return true;
                            final searchable = _columnFilter == 'all'
                                ? [
                                    r.name,
                                    r.type,
                                    r.id.toString(),
                                    r.capacity?.toString() ?? '',
                                    r.roomCode ?? '',
                                  ].join(' ')
                                : switch (_columnFilter) {
                                    'name' => r.name,
                                    'type' => r.type,
                                    'capacity' => r.capacity?.toString() ?? '',
                                    _ => '',
                                  };
                            return searchable.toLowerCase().contains(_query);
                          })
                          .toList(),
                      (r, key) {
                        switch (key) {
                          case 'name':
                            return r.name.toLowerCase();
                          case 'type':
                            return r.type.toLowerCase();
                          case 'capacity':
                            return r.capacity ?? 0;
                          default:
                            return '';
                        }
                      },
                    );
                    if (filtered.isEmpty) {
                      return const Center(
                          child: Text("Geen lokale geregistreer nie.",
                              style: TextStyle(color: Colors.grey)));
                    }
                    return RefreshIndicator(
                      onRefresh: () => CampusService.fetchCampuses(),
                      color: AppColors.refreshSpinner,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final room = filtered[index];
                          return CardDataRow(
                            leading: _selection.isSelecting
                                ? Checkbox(
                                    value: _selection.isSelected(room.id),
                                    onChanged: (_) => setState(
                                        () => _selection.toggle(room.id)),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_selection.isSelecting &&
                                    UserSession.can('rooms.manage')) ...[
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_2,
                                        color: Colors.grey, size: 20),
                                    tooltip: "Wys QR-kode",
                                    onPressed: () => _showRoomQrDialog(room),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.checklist,
                                        color: Colors.grey, size: 20),
                                    tooltip: "Kontroleer bates",
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            RoomChecklistPage(roomId: room.id),
                                      ),
                                    ),
                                  ),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.chevron_right,
                                      color: AppColors.gold),
                                  tooltip: "Wys bates in lokaal",
                                  onPressed: _selection.isSelecting
                                      ? () => setState(
                                          () => _selection.toggle(room.id))
                                      : () {
                                          final onRoomSelected =
                                              widget.onRoomSelected;
                                          if (onRoomSelected != null) {
                                            onRoomSelected(room);
                                          } else {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AssetsPage(
                                                        filterRoomId:
                                                            room.id.toString()),
                                              ),
                                            );
                                          }
                                        },
                                ),
                              ],
                            ),
                            onTap: () {
                              if (_selection.isSelecting) {
                                setState(() => _selection.toggle(room.id));
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RoomDetailPage(room: room),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
                              if (!UserSession.can('rooms.manage')) return;
                              setState(() {
                                _selection.enter();
                                _selection.toggle(room.id);
                              });
                            },
                            children: _buildRoomCells(room),
                          );
                        },
                      ),
                    );
                  }),
                ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (UserSession.can('rooms.manage')) ...[
            BulkDeleteFloatingAction<int>(
              controller: _selection,
              confirmTitle: 'Verwyder Lokale',
              confirmMessage:
                  'Wil jy ${_selection.count} geselekteerde lokaal/lokale verwyder?',
              childWarning:
                  'Alle onderliggende bates, voorraad, foute en take sal ook verwyder word.',
              onDelete: _bulkDeleteRooms,
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            heroTag: "roomScanBtn",
            onPressed: _scanRoomToViewAssets,
            backgroundColor: AppColors.navy,
            child: const Icon(Icons.qr_code_scanner, color: Colors.white),
          ),
          if (UserSession.can('rooms.manage')) ...[
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: "roomAddBtn",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddRoomPage(initialBuilding: _selectedBuilding),
                ),
              ),
              backgroundColor: AppColors.gold,
              elevation: 4,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Nuwe Lokaal",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          ],
        ],
      ),
    );
  }
}

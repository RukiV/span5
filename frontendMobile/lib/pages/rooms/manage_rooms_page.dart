import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../services/room_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../models/room.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/fixed_page_header.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/selection_manager.dart';
import '../../widgets/card_data_row.dart';
import '../asset/asset_page.dart';
import '../reporting/scan_page.dart';
import '../room_checklist/room_checklist_page.dart';

class ManageRoomsPage extends StatefulWidget {
  final Campus? initialCampus;
  final Building? initialBuilding;

  const ManageRoomsPage({super.key, this.initialCampus, this.initialBuilding});

  @override
  State<ManageRoomsPage> createState() => _ManageRoomsPageState();
}

class _ManageRoomsPageState extends State<ManageRoomsPage> {
  Campus? _selectedCampus;
  Building? _selectedBuilding;
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('rooms', [
    const ColumnDef(key: 'name', label: 'Naam'),
    const ColumnDef(key: 'type', label: 'Tipe'),
    const ColumnDef(key: 'capacity', label: 'Kapasiteit'),
  ]);
  final SelectionController<int> _selection = SelectionController<int>();

  @override
  void initState() {
    super.initState();
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

  void _showAddRoomDialog(BuildContext context) {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: "30");
    String type = "other";
    final allBuildings = CampusService.campusesNotifier.value
        .expand((c) => c.buildings)
        .toList();
    Building? selectedBuilding;
    if (_selectedBuilding != null) {
      selectedBuilding = allBuildings
          .where((b) => b.id == _selectedBuilding!.id)
          .firstOrNull;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Nuwe lokaal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Naam", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  decoration: _popupInputDecoration(),
                ),
                const SizedBox(height: 16),
                SearchableDropdown<Building>(
                  label: "Gebou",
                  hint: "Kies Gebou",
                  value: selectedBuilding,
                  items: allBuildings
                      .map((b) => SearchableDropdownItem<Building>(value: b, label: b.name))
                      .toList(),
                  onChanged: (v) => selectedBuilding = v,
                ),
                const SizedBox(height: 16),
                const Text("Kapasiteit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: capacityController,
                  decoration: _popupInputDecoration(),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SearchableDropdown<String>(
                  label: "Tipe",
                  hint: "Kies Tipe",
                  value: type,
                  items: ["klas", "laboratorium", "kantoor", "other"]
                      .map((t) => SearchableDropdownItem(value: t, label: t))
                      .toList(),
                  onChanged: (v) => type = v ?? "other",
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty || selectedBuilding == null) return;
                        final room = Room(
                          id: 0,
                          name: nameController.text.trim(),
                          type: type,
                          capacity: int.tryParse(capacityController.text),
                          buildingId: selectedBuilding!.id,
                        );
                        await CampusService.addRoom(room);
                        if (!mounted) return;
                        if (context.mounted) {
                          Navigator.pop(context);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("'${room.name}' is bygevoeg"), backgroundColor: Colors.green),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5E34),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Stoor"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditRoomDialog(BuildContext context, Room room) {
    final nameController = TextEditingController(text: room.name);
    final capacityController = TextEditingController(text: room.capacity?.toString() ?? "");
    String type = room.type;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Wysig lokaal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Naam", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  decoration: _popupInputDecoration(),
                ),
                const SizedBox(height: 16),
                const Text("Kapasiteit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: capacityController,
                  decoration: _popupInputDecoration(),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SearchableDropdown<String>(
                  label: "Tipe",
                  hint: "Kies Tipe",
                  value: type,
                  items: ["klas", "laboratorium", "kantoor", "other"]
                      .map((t) => SearchableDropdownItem(value: t, label: t))
                      .toList(),
                  onChanged: (v) => type = v ?? "other",
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Kanselleer", style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty) return;
                        final updatedRoom = room.copyWith(
                          name: nameController.text.trim(),
                          type: type,
                          capacity: int.tryParse(capacityController.text),
                        );
                        await CampusService.updateRoom(updatedRoom);
                        if (!mounted) return;
                        if (context.mounted) {
                          Navigator.pop(context);
                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Stoor"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 16),
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
          backgroundColor: fail == 0 ? AppColors.successGreen : AppColors.errorRed,
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssetsPage(filterRoomId: room.id.toString()),
        ),
      );
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text("Lokaal QR-kode", style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1),
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

  InputDecoration _popupInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
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
          Campus? selectedCampus = _selectedCampus != null
              ? campuses.where((c) => c.id == _selectedCampus!.id).firstOrNull
              : null;
          _selectedCampus = selectedCampus;

          Building? selectedBuilding;
          if (_selectedBuilding != null) {
            for (final c in campuses) {
              final match = c.buildings.where((b) => b.id == _selectedBuilding!.id).firstOrNull;
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
                  HeaderIconAction(
                    icon: Icons.place_outlined,
                    tooltip: "Filter op Ligging",
                    activeBadge: _selectedBuilding != null,
                    onTap: () => showLocationFilterSheet(
                      context,
                      depth: LocationDepth.building,
                      campusId: _selectedCampus?.id,
                      buildingId: _selectedBuilding?.id,
                      onChanged: (campusId, buildingId, _) {
                        setState(() {
                          _selectedCampus = campuses.where((c) => c.id == campusId).firstOrNull;
                          _selectedBuilding = _selectedCampus?.buildings.where((b) => b.id == buildingId).firstOrNull;
                        });
                      },
                    ),
                  ),
                  if (UserSession.can('rooms.manage')) ...[
                    BulkDeleteAction<int>(
                      controller: _selection,
                      confirmTitle: 'Verwyder Lokale',
                      confirmMessage: 'Wil jy ${_selection.count} geselekteerde lokaal/lokale verwyder?',
                      childWarning: 'Alle onderliggende bates, voorraad, foute en take sal ook verwyder word.',
                      onDelete: _bulkDeleteRooms,
                    ),
                  ],
                  ColumnVisibilityButton(controller: _colVis, iconOnly: true),
                ],
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Builder(builder: (context) {
                    final baseRooms = _selectedBuilding != null
                        ? (_selectedBuilding!.rooms ?? <Room>[])
                        : campuses
                            .expand((c) => c.buildings)
                            .expand((b) => b.rooms ?? const <Room>[])
                            .toList();
                    final filtered = baseRooms
                        .where((r) =>
                            _query.isEmpty ||
                            r.name.toLowerCase().contains(_query) ||
                            r.type.toLowerCase().contains(_query))
                        .toList();
                    if (_sortCtrl.isActive) {
                      filtered.sort((a, b) {
                        final dir = _sortCtrl.direction;
                        switch (_sortCtrl.sortKey) {
                          case 'name':
                            return a.name.toLowerCase().compareTo(b.name.toLowerCase()) * dir;
                          case 'type':
                            return a.type.toLowerCase().compareTo(b.type.toLowerCase()) * dir;
                          case 'capacity':
                            return (a.capacity ?? 0).compareTo(b.capacity ?? 0) * dir;
                          default:
                            return 0;
                        }
                      });
                    }
                    if (filtered.isEmpty) {
                      return const Center(child: Text("Geen lokale geregistreer nie.", style: TextStyle(color: Colors.grey)));
                    }
                    return RefreshIndicator(
                      onRefresh: () => CampusService.fetchCampuses(),
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
                                    onChanged: (_) => setState(() => _selection.toggle(room.id)),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_selection.isSelecting && UserSession.can('rooms.manage')) ...[
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_2, color: Colors.grey, size: 20),
                                    tooltip: "Wys QR-kode",
                                    onPressed: () => _showRoomQrDialog(room),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.checklist, color: Colors.grey, size: 20),
                                    tooltip: "Kontroleer bates",
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RoomChecklistPage(roomId: room.id),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                    onPressed: () => _showEditRoomDialog(context, room),
                                  ),
                                ],
                                const Icon(Icons.chevron_right, color: AppColors.gold),
                              ],
                            ),
                            onTap: () {
                              if (_selection.isSelecting) {
                                setState(() => _selection.toggle(room.id));
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AssetsPage(filterRoomId: room.id.toString()),
                                  ),
                                );
                              }
                            },
                            onLongPress: () {
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
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
              onPressed: () => _showAddRoomDialog(context),
              backgroundColor: AppColors.gold,
              elevation: 4,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Nuwe Lokaal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ],
        ],
      ),
    );
  }
}

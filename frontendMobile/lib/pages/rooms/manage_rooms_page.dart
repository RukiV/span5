import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/campus_service.dart';
import '../../services/room_service.dart';
import '../../models/user_session.dart';
import '../../models/campus.dart';
import '../../models/building.dart';
import '../../models/room.dart';
import '../../widgets/header_action_button.dart';
import '../../widgets/location_filter_sheet.dart';
import '../../widgets/column_visibility.dart';
import '../../widgets/list_page_scaffold.dart';
import '../../widgets/selectable_row.dart';
import '../../widgets/selection_manager.dart';
import '../asset/asset_page.dart';
import '../reporting/scan_page.dart';
import '../room_checklist/room_checklist_page.dart';
import 'room_form_page.dart';

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

  List<Widget> _buildRoomCells(Room room, SearchableListState<int> state) {
    return state.columnVisibility.visibleColumns.map((col) {
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

  Future<void> _bulkDeleteRooms(BuildContext context, Set<int> ids) async {
    await runBulkDelete(
      context,
      ids: ids,
      delete: CampusService.removeRoom,
      refresh: CampusService.fetchCampuses,
      entityLabel: 'lokaal/lokale',
      onExit: () => setState(() {}),
    );
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
    return ValueListenableBuilder<List<Campus>>(
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
            final match = c.buildings
                .where((b) => b.id == _selectedBuilding!.id)
                .firstOrNull;
            if (match != null) {
              selectedBuilding = match;
              break;
            }
          }
        }
        _selectedBuilding = selectedBuilding;

        return SearchableListScaffold<int>(
          searchHint: "Soek lokale...",
          columns: const [
            ColumnDef(key: 'name', label: 'Naam'),
            ColumnDef(key: 'type', label: 'Tipe'),
            ColumnDef(key: 'capacity', label: 'Kapasiteit'),
          ],
          leadingActions: [
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
                    _selectedCampus =
                        campuses.where((c) => c.id == campusId).firstOrNull;
                    _selectedBuilding = _selectedCampus?.buildings
                        .where((b) => b.id == buildingId)
                        .firstOrNull;
                  });
                },
              ),
            ),
          ],
          canBulkDelete: UserSession.can('rooms.manage'),
          bulkDeleteTitle: 'Verwyder Lokale',
          bulkDeleteMessage:
              'Wil jy {count} geselekteerde lokaal/lokale verwyder?',
          bulkDeleteChildWarning:
              'Alle onderliggende bates, voorraad, foute en take sal ook verwyder word.',
          onBulkDelete: _bulkDeleteRooms,
          onRefresh: () => CampusService.fetchCampuses(),
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RoomFormPage(initialBuilding: _selectedBuilding),
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
          content: (context, state) {
            final baseRooms = _selectedBuilding != null
                ? (_selectedBuilding!.rooms ?? <Room>[])
                : campuses
                    .expand((c) => c.buildings)
                    .expand((b) => b.rooms ?? const <Room>[])
                    .toList();
            final filtered = baseRooms
                .where((r) =>
                    state.query.isEmpty ||
                    r.name.toLowerCase().contains(state.query) ||
                    r.type.toLowerCase().contains(state.query))
                .toList();
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final room = filtered[index];
                  final selecting = state.selection.isSelecting;
                  return SelectableRow<int>(
                    id: room.id,
                    selection: state.selection,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!selecting && UserSession.can('rooms.manage')) ...[
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
                          onPressed: selecting
                              ? () => state.selection.toggle(room.id)
                              : () {
                                  final onRoomSelected = widget.onRoomSelected;
                                  if (onRoomSelected != null) {
                                    onRoomSelected(room);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AssetsPage(
                                            filterRoomId: room.id.toString()),
                                      ),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                    onOpen: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoomFormPage(room: room),
                        ),
                      );
                    },
                    children: _buildRoomCells(room, state),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

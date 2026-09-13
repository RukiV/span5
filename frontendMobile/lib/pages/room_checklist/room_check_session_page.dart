import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/user.dart';
import '../../models/user_session.dart';
import '../../services/asset_service.dart';
import '../../services/campus_service.dart';
import '../../services/room_check_session_service.dart';
import '../../services/user_service.dart';
import '../reporting/scan_page.dart';
import 'new_room_check_session_page.dart';
import 'room_checklist_page.dart';
import 'room_check_history_page.dart';

class RoomCheckSessionPage extends StatefulWidget {
  /// true = "Lokaal Kontrole" (FK/Admin — sien en bestuur almal).
  /// false = "My Kontroles" (Dosent — sien en voltooi slegs eie skedules).
  final bool manageMode;

  const RoomCheckSessionPage({super.key, this.manageMode = true});

  @override
  State<RoomCheckSessionPage> createState() => _RoomCheckSessionPageState();
}

class _RoomCheckSessionPageState extends State<RoomCheckSessionPage> {
  final bool _canManage = UserSession.can('room_checks.manage');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.manageMode) {
      await UserService.fetchAssignableUsers();
      await RoomCheckSessionService.fetchSessions();
    } else {
      await RoomCheckSessionService.fetchSessions(
        assignedUserId: UserSession.userId,
      );
    }
  }

  Future<void> _openEditDialog(RoomCheckSession session) async {
    if (UserService.users.isEmpty) {
      await UserService.fetchAssignableUsers();
    }
    if (!mounted) return;

    int? assignedUserId;
    DateTime? scheduled;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text("Wysig Lokaal Kontrole"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.roomName ?? "Lokaal #${session.roomId}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text("Wysig aan",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: session.assignedUserId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Kies gebruiker",
                    ),
                    items: [
                      for (final u in _assignableUsers(session))
                        DropdownMenuItem(
                            value: u.id, child: Text(_displayName(u))),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => assignedUserId = val),
                  ),
                  const SizedBox(height: 16),
                  const Text("Datum en tyd",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate:
                            scheduled ?? session.scheduledDatetime ?? now,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: DateTime(now.year + 5),
                      );
                      if (date == null) return;
                      if (!dialogContext.mounted) return;
                      final time = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(
                            scheduled ?? session.scheduledDatetime ?? now),
                      );
                      if (time == null) return;
                      if (!dialogContext.mounted) return;
                      setDialogState(() => scheduled = DateTime(date.year,
                          date.month, date.day, time.hour, time.minute));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        scheduled?.toString() ??
                            (session.scheduledDatetime?.toString() ??
                                "Kies datum en tyd"),
                        style: TextStyle(
                          color: scheduled == null &&
                                  session.scheduledDatetime == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Kanselleer"),
              ),
              FilledButton(
                onPressed: () async {
                  await RoomCheckSessionService.updateSession(
                    session.sessionId,
                    assignedUserId: assignedUserId,
                    scheduledDatetime: scheduled,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text("Stoor"),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Wisselbare gebruikers vir die wysig-dialoog — dieselfde filtreer as
  /// skedulering (alle FK-koördineerders + dosente/professore + self, gesorteer
  /// per kampus), maar die huidige toegewysde persoon word altyd bygevoeg sodat
  /// DropdownButtonFormField se initialValue altyd 'n ooreenstemmende item het.
  List<User> _assignableUsers(RoomCheckSession session) {
    final assignable = UserService.roomCheckAssignable().toList();

    final assignedId = session.assignedUserId;
    if (!assignable.any((u) => u.id == assignedId)) {
      final assigned = UserService.users.where((u) => u.id == assignedId);
      if (assigned.isNotEmpty) assignable.add(assigned.first);
    }

    return assignable;
  }

  String _displayName(User u) {
    final campus =
        u.locationId == null ? "" : CampusService.getCampusName(u.locationId!);
    return campus.isEmpty ? u.displayName : "${u.displayName} — $campus";
  }

  Future<void> _confirmDelete(RoomCheckSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder Skedule"),
        content: const Text(
          "N Aktiewe kontrole is aan die gang. Is jy seker dat jy dit wil uitvee?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Nee"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Ja, verwyder"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RoomCheckSessionService.deleteSession(session.sessionId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "N Aktiewe kontrole is aan die gang. Is jy seker dat jy dit wil uitvee?",
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _openCheckOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  "BEGIN 'N LOKAAL KONTROLE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.question_answer, color: AppColors.navy),
                title: const Text("Skandeer bate-kode"),
                subtitle:
                    const Text("Skandeer 'n bate en kontroleer sy lokaal"),
                onTap: () {
                  Navigator.pop(ctx);
                  _startCheckByAssetScan();
                },
              ),
              ListTile(
                leading: const Icon(Icons.door_sliding, color: AppColors.navy),
                title: const Text("Kies 'n lokaal"),
                subtitle: const Text("Kies lokaal uit die lys"),
                onTap: () {
                  Navigator.pop(ctx);
                  _openRoomChecklistPicker();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCheckByAssetScan() async {
    final String? scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (scannedCode == null || !mounted) return;

    final asset = await AssetService.getAssetBySerialCode(scannedCode.trim());
    if (!mounted) return;
    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Geen bate gevind met hierdie kode nie"),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    final roomId = int.tryParse(asset.location);
    if (roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Hierdie bate is nie aan 'n geldige lokaal gekoppel nie"),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    _launchChecklist(roomId);
  }

  Future<void> _openRoomChecklistPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoomChecklistPage()),
    );
    if (result == true && mounted) _load();
  }

  Future<void> _launchChecklist(int roomId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomChecklistPage(roomId: roomId)),
    );
    if (result == true && mounted) _load();
  }

  Widget _statusBadge(String status) {
    final (label, color) = switch (status) {
      'completed' => ("Voltooi", AppColors.successGreen),
      'cancelled' => ("Gekanselleer", Colors.grey),
      _ => ("Geskeduleer", AppColors.warningOrange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  /// Wys slegs die mees onlangse skedule/kontrole per lokaal (dieselfde logika
  /// as die web): voltooi = voltooityd (of skeduletyd), anders skeduletyd
  /// (of geskep-tyd), met die laatse wat wen.
  List<RoomCheckSession> _collapsedSessions(List<RoomCheckSession> sessions) {
    final newestByRoom = <int, RoomCheckSession>{};
    DateTime? recency(RoomCheckSession s) => s.isCompleted
        ? (s.completedDatetime ?? s.scheduledDatetime)
        : (s.scheduledDatetime ?? s.createdAt);
    for (final s in sessions) {
      final prev = newestByRoom[s.roomId];
      final cur = recency(s);
      final prevTime = prev == null ? null : recency(prev);
      if (prev == null ||
          (cur != null && (prevTime == null || cur.isAfter(prevTime)))) {
        newestByRoom[s.roomId] = s;
      }
    }
    return newestByRoom.values.toList();
  }

  String _dateTimeString(DateTime? dt) {
    if (dt == null) return "Geen datum";
    return "${dt.day}/${dt.month}/${dt.year} "
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _earlyChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text("Vroeër voltooi",
          style: TextStyle(
              color: Color(0xFFB45309),
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(widget.manageMode ? "Lokaal Kontrole" : "My Kontroles"),
        actions: [
          if (widget.manageMode && _canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: "Nuwe skedule",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NewRoomCheckSessionPage()),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.manageMode && _canManage
          ? FloatingActionButton.extended(
              heroTag: "beginKontrole",
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.checklist),
              label: const Text("Begin Kontrole"),
              onPressed: _openCheckOptions,
            )
          : null,
      body: ValueListenableBuilder<List<RoomCheckSession>>(
        valueListenable: RoomCheckSessionService.sessionsNotifier,
        builder: (context, sessions, _) {
          if (RoomCheckSessionService.loadingNotifier.value &&
              sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (sessions.isEmpty) {
            return const Center(child: Text("Geen lokaal-kontroles nie."));
          }
          return RefreshIndicator(
              onRefresh: _load,
              color: AppColors.refreshSpinner,
              child: Builder(
                builder: (context) {
                  final visible = _collapsedSessions(sessions);
                  if (visible.isEmpty) {
                    return const Center(
                        child: Text("Geen lokaal-kontroles nie."));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final session = visible[index];
                      final dateStr = _dateTimeString(
                          session.scheduledDatetime ??
                              session.completedDatetime ??
                              session.createdAt);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      session.roomName ??
                                          "Lokaal #${session.roomId}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ),
                                  _statusBadge(session.status),
                                  if (session.isCompletedEarly) ...[
                                    const SizedBox(width: 6),
                                    _earlyChip(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.event,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(dateStr,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700])),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      session.assignedUserName ??
                                          "Gebruiker #${session.assignedUserId}",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                              if (session.isCompleted &&
                                  session.completedDatetime != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Voltooi op: ${_dateTimeString(session.completedDatetime)}",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ],
                              if (!session.isCompleted) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (widget.manageMode && _canManage) ...[
                                      TextButton.icon(
                                        onPressed: () =>
                                            _openEditDialog(session),
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 18),
                                        label: const Text("Wysig"),
                                      ),
                                      TextButton.icon(
                                        onPressed: () =>
                                            _confirmDelete(session),
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18),
                                        label: const Text("Verwyder"),
                                        style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppColors.errorRed),
                                      ),
                                    ],
                                    FilledButton.tonal(
                                      onPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RoomChecklistPage(
                                                roomId: session.roomId),
                                          ),
                                        );
                                        if (result == true && mounted) _load();
                                      },
                                      style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.gold),
                                      child: const Text("Voltooi"),
                                    ),
                                  ],
                                ),
                              ],
                              if (session.isCompleted) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                RoomCheckHistoryPage(
                                                    roomId: session.roomId),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.history, size: 18),
                                      label: const Text("Geskiedenis"),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ));
        },
      ),
    );
  }
}

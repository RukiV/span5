import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/user_session.dart';
import '../../services/room_check_session_service.dart';
import '../../services/user_service.dart';
import '../../widgets/location_cascade_picker.dart';
import 'room_checklist_page.dart';
import 'room_check_history_page.dart';

class RoomCheckSessionPage extends StatefulWidget {
  /// true = "Kontrole Skedules" (FK/Admin — sien en bestuur almal).
  /// false = "My Kontroles" (Dosent — sien en voltooi slegs eie skedules).
  final bool manageMode;

  const RoomCheckSessionPage({super.key, this.manageMode = true});

  @override
  State<RoomCheckSessionPage> createState() => _RoomCheckSessionPageState();
}

class _RoomCheckSessionPageState extends State<RoomCheckSessionPage> {
  final bool _canManage = UserSession.can('roomchecks.manage');

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

  Future<void> _openCreateDialog() async {
    if (UserService.users.isEmpty) {
      await UserService.fetchAssignableUsers();
    }
    if (!mounted) return;

    int? roomId;
    int? assignedUserId;
    DateTime? scheduled;
    int? campusId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final filteredUsers = UserService.users.where((u) {
            if (u.id == UserSession.userId) return true;
            if (u.roleId == 1 || u.roleId == 4) return false;
            if (u.roleId != 5) return false;
            if (campusId == null) return false;
            return u.locationId == null || u.locationId == campusId;
          }).toList();
          return AlertDialog(
            title: const Text("Nuwe Kontrole Skedule"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Lokaal", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LocationCascadePicker(
                    depth: LocationDepth.room,
                    onChanged: (newCampusId, buildingId, pickedRoomId) {
                      setDialogState(() {
                        campusId = newCampusId;
                        roomId = pickedRoomId;
                        assignedUserId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text("Toegewys aan", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: assignedUserId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Kies gebruiker",
                    ),
                    items: [
                      for (final u in filteredUsers)
                        DropdownMenuItem(value: u.id, child: Text(u.displayName)),
                    ],
                    onChanged: (val) => setDialogState(() => assignedUserId = val),
                  ),
                  const SizedBox(height: 16),
                  const Text("Datum en tyd", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: scheduled ?? now,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: DateTime(now.year + 5),
                      );
                      if (date == null) return;
                      if (!dialogContext.mounted) return;
                      final time = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(scheduled ?? now),
                      );
                      if (time == null) return;
                      if (!dialogContext.mounted) return;
                      setDialogState(() => scheduled = DateTime(
                        date.year, date.month, date.day, time.hour, time.minute));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        scheduled == null
                            ? "Kies datum en tyd"
                            : scheduled!.toString(),
                        style: TextStyle(color: scheduled == null ? Colors.grey : Colors.black),
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
                onPressed: roomId == null || assignedUserId == null
                    ? null
                    : () async {
                        await RoomCheckSessionService.createSession(
                          roomId: roomId!,
                          assignedUserId: assignedUserId!,
                          scheduledDatetime: scheduled,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                child: const Text("Skeduleer"),
              ),
            ],
          );
        },
      ),
    );
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
            title: const Text("Wysig Kontrole Skedule"),
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
                  const Text("Herroewys aan", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: session.assignedUserId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Kies gebruiker",
                    ),
                    items: [
                      for (final u in UserService.users.where((u) {
                        if (u.id == UserSession.userId) return true;
                        if (u.roleId == 1 || u.roleId == 4) return false;
                        if (u.roleId != 5) return false;
                        return true;
                      }))
                        DropdownMenuItem(value: u.id, child: Text(u.displayName)),
                    ],
                    onChanged: (val) => setDialogState(() => assignedUserId = val),
                  ),
                  const SizedBox(height: 16),
                  const Text("Datum en tyd", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: dialogContext,
                        initialDate: scheduled ?? session.scheduledDatetime ?? now,
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
                      setDialogState(() => scheduled = DateTime(
                        date.year, date.month, date.day, time.hour, time.minute));
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
                            (session.scheduledDatetime?.toString() ?? "Kies datum en tyd"),
                        style: TextStyle(
                          color: scheduled == null && session.scheduledDatetime == null
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
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(widget.manageMode ? "Kontrole Skedules" : "My Kontroles"),
        actions: [
          if (widget.manageMode && _canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: "Nuwe skedule",
              onPressed: _openCreateDialog,
            ),
        ],
      ),
      body: ValueListenableBuilder<List<RoomCheckSession>>(
        valueListenable: RoomCheckSessionService.sessionsNotifier,
        builder: (context, sessions, _) {
          if (RoomCheckSessionService.loadingNotifier.value && sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (sessions.isEmpty) {
            return const Center(child: Text("Geen kontrole-skedules nie."));
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final dateStr = session.scheduledDatetime == null
                    ? "Geen datum"
                    : "${session.scheduledDatetime!.day}/${session.scheduledDatetime!.month}/${session.scheduledDatetime!.year} "
                        "${session.scheduledDatetime!.hour.toString().padLeft(2, '0')}:${session.scheduledDatetime!.minute.toString().padLeft(2, '0')}";

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                session.roomName ?? "Lokaal #${session.roomId}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            _statusBadge(session.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                session.assignedUserName ?? "Gebruiker #${session.assignedUserId}",
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                        if (!session.isCompleted) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (widget.manageMode && _canManage) ...[
                                TextButton.icon(
                                  onPressed: () => _openEditDialog(session),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text("Herroewys"),
                                ),
                                TextButton.icon(
                                  onPressed: () => _confirmDelete(session),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text("Verwyder"),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
                                ),
                              ],
                              FilledButton.tonal(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RoomChecklistPage(roomId: session.roomId),
                                    ),
                                  );
                                  if (result == true && mounted) _load();
                                },
                                style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
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
                                      builder: (_) => RoomCheckHistoryPage(roomId: session.roomId),
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
            ),
          );
        },
      ),
    );
  }
}

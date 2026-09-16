import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/user.dart';
import '../../services/campus_service.dart';
import '../../services/room_check_session_service.dart';
import '../../services/user_service.dart';
import '../../widgets/location_cascade_picker.dart';
import '../../widgets/location_breadcrumbs.dart';
import '../../core/datetime_utils.dart';

/// Volblad-skepping van 'n nuwe "Lokaal Kontrole" (room check session).
///
/// Vervang die ou pop-op (AlertDialog) wat die [LocationCascadePicker] sonder
/// gelaaide kampusdata vertoon het en binne 'n dialog gebreek het. Hier word
/// die data eers gelaai (soos in [NewReportPage]) en die kieser op 'n gewone
/// bladsy vertoon — geen pop-up, geen kraak nie.
class NewRoomCheckSessionPage extends StatefulWidget {
  const NewRoomCheckSessionPage({super.key});

  @override
  State<NewRoomCheckSessionPage> createState() => _NewRoomCheckSessionPageState();
}

class _NewRoomCheckSessionPageState extends State<NewRoomCheckSessionPage> {
  bool _loading = true;
  bool _creating = false;
  int? _roomId;
  int? _assignedUserId;
  DateTime? _scheduled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (CampusService.campusesNotifier.value.isEmpty) {
      await CampusService.fetchCampuses();
    }
    if (UserService.users.isEmpty) {
      await UserService.fetchAssignableUsers();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<User> get _filteredUsers => UserService.roomCheckAssignable();

  String _displayName(User u) {
    final campus = u.locationId == null
        ? ""
        : CampusService.getCampusName(u.locationId!);
    return campus.isEmpty ? u.displayName : "${u.displayName} — $campus";
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled ?? now),
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() => _scheduled = DateTime(
      date.year, date.month, date.day, time.hour, time.minute));
  }

  String get _dateLabel =>
      _scheduled == null ? "Kies datum en tyd" : formatDateTime(_scheduled!);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text("Nuwe Lokaal Kontrole"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Lokaal", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_roomId != null) ...[
                    () {
                      final path = CampusService.findRoomPath(_roomId!);
                      final campus = path.campus?.name;
                      final building = path.building?.name;
                      final room = path.room?.name;
                      final label = campus == null
                          ? "Kies Kampus"
                          : "$campus > $building > $room";
                      return LocationBreadcrumbs(path: label);
                    }(),
                    const SizedBox(height: 12),
                  ],
                  LocationCascadePicker(
                    depth: LocationDepth.room,
                    showBreadcrumb: false,
                    onChanged: (campusId, buildingId, roomId) {
                      setState(() {
                        _roomId = roomId;
                        _assignedUserId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text("Toegewys aan", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Kies gebruiker",
                    ),
                    child: DropdownButton<int>(
                      value: _assignedUserId,
                      isExpanded: true,
                      hint: const Text("Kies gebruiker"),
                      items: [
                        for (final u in _filteredUsers)
                          DropdownMenuItem(value: u.id, child: Text(_displayName(u))),
                      ],
                      onChanged: (val) => setState(() => _assignedUserId = val),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Datum en tyd", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDateTime,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _dateLabel,
                        style: TextStyle(color: _scheduled == null ? Colors.grey : Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _roomId == null ||
                              _assignedUserId == null ||
                              _creating
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await RoomCheckSessionService.createSession(
                                  roomId: _roomId!,
                                  assignedUserId: _assignedUserId!,
                                  scheduledDatetime: _scheduled,
                                );
                                if (mounted) navigator.pop(true);
                              } catch (e) {
                                String msg = "Kon nie die skedule stoor nie";
                                if (e is DioException &&
                                    e.response?.data?['detail'] != null) {
                                  msg = e.response!.data['detail'].toString();
                                }
                                messenger.showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                              }
                            },
                      child: const Text("Skeduleer"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/user_session.dart';
import '../../widgets/searchable_dropdown.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/app_colors.dart';
import '../../services/calendar_service.dart';
import '../../services/outlook_service.dart';
import '../../services/outlook_token_manager.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<CalendarEvent> _events = [];
  bool _loading = true;
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('calendar', [
    const ColumnDef(key: 'title', label: 'Titel'),
    const ColumnDef(key: 'time', label: 'Tyd'),
    const ColumnDef(key: 'location', label: 'Ligging', defaultVisible: false),
  ]);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
    CalendarService.eventsNotifier.addListener(_onEventsChanged);
  }

  @override
  void dispose() {
    CalendarService.eventsNotifier.removeListener(_onEventsChanged);
    super.dispose();
  }

  void _onEventsChanged() {
    if (mounted) {
      setState(() {
        _events = CalendarService.eventsNotifier.value;
        _loading = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final start = DateTime(_focusedDay.year, _focusedDay.month, 1).subtract(const Duration(days: 30));
    final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).add(const Duration(days: 60));
    await CalendarService.fetchEvents(start, end);
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events.where((e) {
      final sameStart = e.startDatetime.year == day.year &&
          e.startDatetime.month == day.month &&
          e.startDatetime.day == day.day;
      if (sameStart) return true;
      final end = e.endDatetime;
      if (end == null) return false;
      // Meerdag-werksopdragte: wys op elke dag wat hulle beslaan.
      final dayDate = DateTime(day.year, day.month, day.day);
      final startDate = DateTime(e.startDatetime.year, e.startDatetime.month, e.startDatetime.day);
      final endDate = DateTime(end.year, end.month, end.day);
      return !dayDate.isBefore(startDate) && !dayDate.isAfter(endDate);
    }).toList();
  }

  String _sourceIcon(String? source) {
    switch (source) {
      case 'calendar_event': return '\u{1F4C5}';
      case 'jobcard': return '\u{1F527}';
      case 'outlook': return '\u{2601}\u{FE0F}';
      default: return '\u{1F4CC}';
    }
  }

  Future<void> _showAddEventDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    DateTime selectedDate = _selectedDay ?? _focusedDay;
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    bool notifyEmail = false;
    int reminderMinutes = 60;

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Nuwe Afspraak", style: TextStyle(color: AppColors.navy)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: "Onderwerp *", hintText: "bv. Onderhoud"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(labelText: "Plek", hintText: "bv. Hoofkampus"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Beskrywing"),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text("${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(selectedTime.format(ctx)),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setDialogState(() => selectedTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text("Stuur e-pos herinnering", style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    Switch(
                      value: notifyEmail,
                      activeThumbColor: AppColors.gold,
                      onChanged: (v) => setDialogState(() => notifyEmail = v),
                    ),
                  ],
                ),
                if (notifyEmail)
                  SearchableDropdown<int>(
                    label: "Herinnering",
                    hint: "Kies herinnering",
                    value: reminderMinutes,
                    items: const [
                      SearchableDropdownItem(value: 30, label: "30 minute voor tyd"),
                      SearchableDropdownItem(value: 60, label: "1 uur voor tyd"),
                      SearchableDropdownItem(value: 120, label: "2 ure voor tyd"),
                      SearchableDropdownItem(value: 1440, label: "24 ure voor tyd"),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => reminderMinutes = v);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("KANSELLEER"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                final startDt = DateTime(
                  selectedDate.year, selectedDate.month, selectedDate.day,
                  selectedTime.hour, selectedTime.minute,
                );
                final event = CalendarEvent(
                  title: titleCtrl.text,
                  description: descCtrl.text,
                  startDatetime: startDt,
                  endDatetime: startDt.add(const Duration(hours: 1)),
                  location: locCtrl.text,
                  notifyEmail: notifyEmail,
                  reminderMinutes: notifyEmail ? reminderMinutes : null,
                );
                final success = await CalendarService.addEvent(event);
                if (ctx.mounted) Navigator.pop(ctx);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Afspraak geskep"), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              child: const Text("SKEP"),
            ),
          ],
        ),
      ),
    );
  }

  /// Sinkroniseer 'n plaaslike afspraak na Outlook (dieselfde as die web se
  /// "Sinkroniseer na Outlook"-knoppie). Meld eers aan as die gebruiker nie
  /// 'n Outlook-sessie het nie.
  Future<void> _syncEventToOutlook(CalendarEvent event, {VoidCallback? onDone}) async {
    var token = await OutlookTokenManager.instance.getGraphAccessToken();
    if (token == null) {
      final signedIn = await OutlookTokenManager.instance.signIn();
      token = signedIn
          ? await OutlookTokenManager.instance.getGraphAccessToken()
          : null;
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Meld asseblief eers aan met Microsoft om te sinkroniseer."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    final start = event.startDatetime;
    final end = event.endDatetime ?? start.add(const Duration(hours: 1));
    final graphId = await OutlookService.instance.createEvent(
      title: event.title,
      description: event.description,
      start: start,
      end: end,
      location: event.location,
    );

    if (graphId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Fout tydens sinkronisering na Outlook."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final ok = await CalendarService.updateEventSync(
      event.eventId!,
      outlookEventId: graphId,
      outlookSynced: true,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? "Gesinkroniseer na Outlook!" : "Kon nie sinkronisering stoor nie."),
          backgroundColor: ok ? Colors.green : Colors.orange,
        ),
      );
    }
    onDone?.call();
  }

  /// Verwyder 'n suiver Outlook-afspraak (bron 'outlook') by MS Graph.
  Future<void> _deleteOutlookEvent(CalendarEvent event, BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text("Verwyder Outlook-afspraak?"),
        content: const Text("Dit sal die afspraak van jou Outlook-kalender verwyder."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("KANSELLEER")),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("VERWYDER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || event.outlookEventId == null) return;

    final deleted = await OutlookService.instance.deleteEvent(event.outlookEventId!);
    if (deleted) {
      CalendarService.removeOutlookEvent(event.outlookEventId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Outlook-afspraak verwyder."), backgroundColor: Colors.green),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fout tydens verwydering van Outlook-afspraak."), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showEventDetail(CalendarEvent event) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Text(_sourceIcon(event.source), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(event.title, style: const TextStyle(color: AppColors.navy))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(Icons.access_time, _detailDateTime(event.startDatetime)),
            if (event.endDatetime != null && !isSameDay(event.startDatetime, event.endDatetime!))
              _detailRow(Icons.event_available, "tot ${_detailDateTime(event.endDatetime!)}"),
            if (event.location != null && event.location!.isNotEmpty)
              _detailRow(Icons.location_on, event.location!),
            if (event.description != null && event.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(event.description!, style: const TextStyle(color: Colors.black87)),
              ),
            if (event.notifyEmail)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.green),
                    SizedBox(width: 4),
                    Text("E-pos herinnering aktief", style: TextStyle(color: Colors.green, fontSize: 13)),
                  ],
                ),
              ),
            if (event.outlookSynced)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text("Gesinkroniseer na Outlook", style: TextStyle(color: Colors.blue, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          if (UserSession.can('calendar.manage') && event.eventId != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text("Verwyder afspraak?"),
                    content: const Text("Hierdie aksie kan nie ongedaan gemaak word nie."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("KANSELLEER")),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("VERWYDER", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  final deleted = await CalendarService.deleteEvent(event.eventId!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(deleted
                            ? "Afspraak verwyder"
                            : "Kon nie die afspraak verwyder nie."),
                        backgroundColor: deleted ? Colors.orange : Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text("Verwyder", style: TextStyle(color: Colors.red)),
            ),
          if (UserSession.can('calendar.manage') &&
              event.source == 'calendar_event' &&
              !event.outlookSynced &&
              event.eventId != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _syncEventToOutlook(event);
              },
              child: const Text("Sinkroniseer na Outlook"),
            ),
          if (UserSession.can('calendar.manage') &&
              event.source == 'outlook' &&
              event.outlookEventId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deleteOutlookEvent(event, context);
              },
              child: const Text("Verwyder van Outlook", style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("SLUIT")),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }

  String _detailDateTime(DateTime dt) =>
      "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} "
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  String _eventTimeLabel(CalendarEvent event) {
    final start = event.startDatetime;
    final startTime = "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
    final end = event.endDatetime;
    if (end == null || isSameDay(start, end)) return startTime;
    return "$startTime – ${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')} "
        "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12.0),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: TableCalendar(
                    locale: 'af_ZA',
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2028, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Maand',
                    },
                    headerVisible: true,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy),
                      leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.gold),
                      rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.gold),
                    ),
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                      _loadEvents();
                    },
                    eventLoader: (day) => _getEventsForDay(day),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: AppColors.terracotta,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 1,
                      outsideDaysVisible: false,
                    ),
                  ),
                ),
                if (_selectedDay != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 18, color: AppColors.navy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Gebeure vir ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                        ),
                        ColumnVisibilityButton(controller: _colVis),
                      ],
                    ),
                  ),
                Expanded(child: _buildEventList()),
              ],
            ),
      floatingActionButton: UserSession.can('calendar.manage')
          ? FloatingActionButton(
              onPressed: _showAddEventDialog,
              backgroundColor: AppColors.gold,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay!);
    if (_sortCtrl.isActive) {
      events.sort((a, b) {
        final dir = _sortCtrl.direction;
        switch (_sortCtrl.sortKey) {
          case 'title': return a.title.toLowerCase().compareTo(b.title.toLowerCase()) * dir;
          case 'time': return a.startDatetime.compareTo(b.startDatetime) * dir;
          default: return 0;
        }
      });
    }
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text("Geen gebeure vir hierdie dag nie.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        Color cardColor;
        switch (event.source) {
          case 'jobcard':
            cardColor = AppColors.lavender;
            break;
          case 'outlook':
            cardColor = const Color(0xFFE3F2FD);
            break;
          default:
            cardColor = AppColors.lavender;
        }
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Text(_sourceIcon(event.source), style: const TextStyle(fontSize: 22)),
            title: Text(
              event.title,
              style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.black54),
                  const SizedBox(width: 4),
                  Text(
                    _eventTimeLabel(event),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on, size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(event.location!, style: const TextStyle(color: Colors.black54)),
                  ],
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.navy),
            onTap: () => _showEventDetail(event),
          ),
        );
      },
    );
  }
}

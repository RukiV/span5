import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/app_colors.dart';
import '../../models/user_session.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mock gebeure data
  final Map<DateTime, List<Map<String, String>>> _events = {
    DateTime.utc(2025, 5, 12): [
      {'title': 'Kampus Oudit', 'time': '09:00 - 11:00'},
      {'title': 'Brandveiligheid Inspeksie', 'time': '14:00 - 15:30'}
    ],
    DateTime.utc(2025, 5, 15): [
      {'title': 'Stock Aflewering', 'time': '08:00 - 09:00'}
    ],
    DateTime.utc(2025, 5, 20): [
      {'title': 'Onderhoud: Hyser', 'time': '10:00 - 12:00'}
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Kalenderrooster
          Card(
            margin: const EdgeInsets.all(12.0),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: TableCalendar(
              locale: 'af_ZA',
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2026, 12, 31),
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

          // Gebeure Titel
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 18, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Text(
                    "Gebeure vir ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                ],
              ),
            ),

          // Gebeure Lys
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay!);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey.withOpacity(0.5)),
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
        return Card(
          color: AppColors.lavender,
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              event['title']!,
              style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.black54),
                  const SizedBox(width: 4),
                  Text(event['time']!, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.navy),
            onTap: () {
              // Gebeurtenis besonderhede kan hier oopmaak
            },
          ),
        );
      },
    );
  }
}

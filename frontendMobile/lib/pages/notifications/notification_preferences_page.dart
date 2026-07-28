import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/notification_service.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  Map<String, dynamic> _prefs = {};
  bool _loading = true;

  static const _groups = [
    _PrefGroup('Foute', [
      _PrefItem('fault.created', 'Fout Aangeteken'),
      _PrefItem('fault.assigned', 'Fout Toegewys'),
      _PrefItem('fault.resolved', 'Fout Opgelos'),
      _PrefItem('fault.status_changed', 'Fout Status Verander'),
    ]),
    _PrefGroup('Werksopdragte', [
      _PrefItem('job.created', 'Werksopdrag Geskep'),
      _PrefItem('job.assigned', 'Werksopdrag Toegewys'),
      _PrefItem('job.status_changed', 'Status Verandering'),
    ]),
    _PrefGroup('Voorraad', [
      _PrefItem('stock.low', 'Lae Voorraad'),
    ]),
    _PrefGroup('Stelsel', [
      _PrefItem('system.announcement', 'Aankondiging'),
    ]),
    _PrefGroup('Kalender', [
      _PrefItem('calendar.reminder', 'Kalender Herinnering'),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await NotificationService.fetchPreferences();
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  bool _enabled(String type) {
    return _prefs[type]?['in_app_enabled'] ?? true;
  }

  Future<void> _toggle(String type) async {
    final current = _enabled(type);
    final newVal = !current;
    setState(() {
      _prefs[type] ??= {};
      _prefs[type]['in_app_enabled'] = newVal;
    });
    final ok = await NotificationService.updatePreference(type, newVal);
    if (!ok) {
      setState(() {
        _prefs[type]['in_app_enabled'] = current;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kon nie voorkeur stoor nie'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kennisgewing Voorkeure'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _groups.map((group) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        group.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    ...group.items.map((item) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: ListTile(
                          title: Text(item.label, style: const TextStyle(fontSize: 14)),
                          trailing: Switch(
                            value: _enabled(item.type),
                            activeColor: AppColors.navy,
                            onChanged: (_) => _toggle(item.type),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

class _PrefItem {
  final String type;
  final String label;
  const _PrefItem(this.type, this.label);
}

class _PrefGroup {
  final String name;
  final List<_PrefItem> items;
  const _PrefGroup(this.name, this.items);
}

// =============================================================================
// Flutter-voorkeure-bladsy (per kennisgewing-tipe)
// Vloei:
//   1) Laai tydens initState: NotificationService.fetchPreferences()
//   2) Wys 'n skakelaar per tipe × 3 kanale (In-App / E-pos / Stoot)
//   3) _toggle() stuur dadelik na PATCH /notifications/preferences
//      en rol terug as dit misluk
// =============================================================================
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
  Map<String, dynamic> _prefs = {};  // notification_type → { in_app_enabled, email_enabled, push_enabled }
  bool _loading = true;

  // --- Groepe vir die UI-uitleg (stem ooreen met PREF_TYPES in React) ---
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
      _PrefItem('job.completion_requested', 'Werksopdrag Voltooiingsversoek'),
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

  // --- Laai alle voorkeure van die bediener ---
  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await NotificationService.fetchPreferences();
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  // --- Lees een voorkeur-veld (gee verstek: in_app=waar, push=waar, e-pos=onwaar) ---
  bool _enabled(String type, String field) {
    return _prefs[type]?[field] ?? (field == 'in_app_enabled' || field == 'push_enabled');
  }

  // --- Skakel een veld aan/af en stoor dit op die bediener ---
  Future<void> _toggle(String type, String field) async {
    final current = _enabled(type, field);
    final newVal = !current;
    setState(() {
      _prefs[type] ??= {};
      _prefs[type][field] = newVal;
    });
    bool ok;
    if (field == 'in_app_enabled') {
      ok = await NotificationService.updatePreference(type, inAppEnabled: newVal);
    } else if (field == 'email_enabled') {
      ok = await NotificationService.updatePreference(type, emailEnabled: newVal);
    } else {
      ok = await NotificationService.updatePreference(type, pushEnabled: newVal);
    }
    if (!ok) {
      // Terugrol as die bedienerversoek misluk
      setState(() {
        _prefs[type][field] = current;
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

  // --- Bou 'n kolom met 'n klein etiket + 'n skakelaar (vir een kanaal) ---
  Widget _toggleColumn(String label, String type, String field) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Switch(
          value: _enabled(type, field),
          activeThumbColor: AppColors.navy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (_) => _toggle(type, field),
        ),
      ],
    );
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(item.label, style: const TextStyle(fontSize: 14)),
                              ),
                              // --- Drie kanale: In-App | E-pos | Stoot ---
                              _toggleColumn('In-App', item.type, 'in_app_enabled'),
                              const SizedBox(width: 8),
                              _toggleColumn('E-pos', item.type, 'email_enabled'),
                              const SizedBox(width: 8),
                              _toggleColumn('Stoot', item.type, 'push_enabled'),
                            ],
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

// --- Hulp-voorwerp: een kennisgewing-tipe in die UI ---
class _PrefItem {
  final String type;
  final String label;
  const _PrefItem(this.type, this.label);
}

// --- Hulp-voorwerp: 'n groep tipes (bv. "Foute", "Werksopdragte") ---
class _PrefGroup {
  final String name;
  final List<_PrefItem> items;
  const _PrefGroup(this.name, this.items);
}

import 'package:flutter/material.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../core/app_colors.dart';
import '../../models/user_session.dart';
import '../../services/jobcard_service.dart';
import '../../services/notification_service.dart';
import '../jobcards/jobcard_detail_page.dart';
import '../jobcards/jobcard_form_page.dart';
import 'notification_preferences_page.dart';
import '../../widgets/sort_utils.dart';
import '../../widgets/column_visibility.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  String _filterType = '';
  final SortController _sortCtrl = SortController();
  final ColumnVisibilityController _colVis = ColumnVisibilityController('notifications', [
    const ColumnDef(key: 'type', label: 'Tipe'),
    const ColumnDef(key: 'title', label: 'Titel'),
    const ColumnDef(key: 'message', label: 'Boodskap', defaultVisible: false),
    const ColumnDef(key: 'date', label: 'Datum'),
  ]);
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_loading) {
        _page++;
        _loadNotifications();
      }
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    final items = await NotificationService.fetchAll(
      page: _page,
      type: _filterType.isNotEmpty ? _filterType : null,
    );
    setState(() {
      if (_page == 1) {
        _notifications = items;
      } else {
        _notifications.addAll(items);
      }
      if (_sortCtrl.isActive) {
        _notifications.sort((a, b) {
          final dir = _sortCtrl.direction;
          switch (_sortCtrl.sortKey) {
            case 'title':
              return a.title.toLowerCase().compareTo(b.title.toLowerCase()) * dir;
            case 'type':
              return a.notificationType.toLowerCase().compareTo(b.notificationType.toLowerCase()) * dir;
            case 'date':
              final da = DateTime.tryParse(a.createdAt) ?? DateTime(0);
              final db = DateTime.tryParse(b.createdAt) ?? DateTime(0);
              return da.compareTo(db) * dir;
            default:
              return 0;
          }
        });
      }
      _hasMore = items.length >= 20;
      _loading = false;
    });
  }

  Future<void> _onRefresh() async {
    _page = 1;
    _hasMore = true;
    await _loadNotifications();
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'fault.created':
      case 'stock.low':
        return Colors.red;
      case 'fault.assigned':
        return Colors.orange;
      case 'fault.resolved':
        return Colors.green;
      case 'job.created':
        return Colors.blue;
      case 'job.assigned':
        return Colors.brown;
      case 'job.status_changed':
        return Colors.purple;
      case 'job.completion_requested':
        return Colors.teal;
      case 'system.announcement':
        return const Color(0xFF0e1e3b);
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'fault.created':
      case 'fault.assigned':
      case 'fault.resolved':
        return Icons.bug_report_outlined;
      case 'job.created':
      case 'job.assigned':
      case 'job.status_changed':
      case 'job.completion_requested':
        return Icons.construction_outlined;
      case 'stock.low':
        return Icons.warning_amber_outlined;
      case 'system.announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Nou net';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m gelede';
      if (diff.inHours < 24) return '${diff.inHours}h gelede';
      if (diff.inDays < 7) return '${diff.inDays}d gelede';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _handleTap(AppNotification notif) async {
    NotificationService.markAsRead(notif.notificationId);
    setState(() {
      final idx = _notifications.indexWhere(
        (n) => n.notificationId == notif.notificationId,
      );
      if (idx >= 0) {
        _notifications[idx] = AppNotification(
          notificationId: notif.notificationId,
          notificationType: notif.notificationType,
          title: notif.title,
          message: notif.message,
          referenceType: notif.referenceType,
          referenceId: notif.referenceId,
          isRead: true,
          createdAt: notif.createdAt,
        );
      }
    });

    // Werksopdrag-kennisgewings skakel deur na die werksopdrag self:
    // kontrakteurs kry die kontrakteur-aansig, FK/Admin die wysigingsvorm.
    if (notif.referenceType == 'job' && notif.referenceId != null) {
      if (JobcardService.jobcardsNotifier.value.isEmpty) {
        await JobcardService.fetchJobs();
      }
      if (!mounted) return;
      final job = JobcardService.jobcardsNotifier.value
          .where((j) => j.id == notif.referenceId)
          .firstOrNull;
      if (job == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserSession.isContractor
              ? JobcardDetailPage(job: job)
              : JobcardFormPage(jobcard: job),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kennisgewings'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationPreferencesPage(),
                ),
              );
            },
          ),
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                await NotificationService.markAllAsRead();
                _onRefresh();
              },
              child: const Text(
                'Merk almal as gelees',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SearchableDropdown<String>(
                    hint: 'Alle tipes',
                    value: _filterType.isEmpty ? null : _filterType,
                    items: const [
                      SearchableDropdownItem(value: '', label: 'Alle tipes'),
                      SearchableDropdownItem(
                          value: 'fault.created', label: 'Fout Aangeteken'),
                      SearchableDropdownItem(
                          value: 'job.created', label: 'Werksopdrag Geskep'),
                      SearchableDropdownItem(
                          value: 'job.completion_requested', label: 'Voltooiingsversoek'),
                      SearchableDropdownItem(
                          value: 'stock.low', label: 'Lae Voorraad'),
                      SearchableDropdownItem(
                          value: 'system.announcement', label: 'Aankondiging'),
                    ],
                    onChanged: (v) {
                      _filterType = v ?? '';
                      _page = 1;
                      _loadNotifications();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ColumnVisibilityButton(controller: _colVis),
              ],
            ),
          ),
          Expanded(
            child: _loading && _notifications.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'Geen kennisgewings nie',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            return InkWell(
                              onTap: () => _handleTap(n),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: n.isRead
                                      ? Colors.white
                                      : const Color(0xFFEEF3FA),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 0.5,
                                    ),
                                    left: n.isRead
                                        ? BorderSide.none
                                        : const BorderSide(
                                            color: Color(0xFF2a5f9e),
                                            width: 3,
                                          ),
                                  ),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _typeIcon(n.notificationType),
                                      color: _typeColor(n.notificationType),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            n.message,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _timeAgo(n.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

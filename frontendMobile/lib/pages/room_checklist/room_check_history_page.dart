import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/api_client.dart';
import '../../services/campus_service.dart';

class _RoomCheckRecord {
  final int id;
  final int roomId;
  final int? userId;
  final String? userName;
  final String summary;
  final DateTime checkedDatetime;

  _RoomCheckRecord({
    required this.id,
    required this.roomId,
    this.userId,
    this.userName,
    required this.summary,
    required this.checkedDatetime,
  });

  factory _RoomCheckRecord.fromJson(Map<String, dynamic> json) {
    return _RoomCheckRecord(
      id: json['room_check_id'] ?? 0,
      roomId: json['room_id'] ?? 0,
      userId: json['user_id'],
      userName: json['user_name'],
      summary: json['summary'] ?? '[]',
      checkedDatetime: DateTime.tryParse(json['checked_datetime'] ?? '') ?? DateTime.now(),
    );
  }
}

class RoomCheckHistoryPage extends StatefulWidget {
  final int roomId;

  const RoomCheckHistoryPage({super.key, required this.roomId});

  @override
  State<RoomCheckHistoryPage> createState() => _RoomCheckHistoryPageState();
}

class _RoomCheckHistoryPageState extends State<RoomCheckHistoryPage> {
  List<_RoomCheckRecord> _checks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient().client.get('/room-checks', queryParameters: {'room_id': widget.roomId});
      final List data = response.data as List;
      setState(() {
        _checks = data.map((j) => _RoomCheckRecord.fromJson(j as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fout met laai geskiedenis: $e"), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  int _countConfirmed(String s) {
    final list = jsonDecode(s) as List;
    return list.where((e) => e['status'] == 'confirmed').length;
  }

  int _countMissing(String s) {
    final list = jsonDecode(s) as List;
    return list.where((e) => e['status'] == 'missing').length;
  }

  int _countFaultReported(String s) {
    final list = jsonDecode(s) as List;
    return list.where((e) => e['status'] == 'fault_reported').length;
  }

  @override
  Widget build(BuildContext context) {
    final roomName = CampusService.getRoomName(widget.roomId.toString());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text("Geskiedenis: $roomName"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _checks.isEmpty
              ? const Center(child: Text("Geen kontrole-geskiedenis nie."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _checks.length,
                  itemBuilder: (context, index) {
                    final check = _checks[index];
                    return _buildCheckCard(check);
                  },
                ),
    );
  }

  Widget _buildCheckCard(_RoomCheckRecord check) {
    final confirmed = _countConfirmed(check.summary);
    final missing = _countMissing(check.summary);
    final faultReported = _countFaultReported(check.summary);
    final total = confirmed + missing + faultReported;

    final dateStr = "${check.checkedDatetime.day}/${check.checkedDatetime.month}/${check.checkedDatetime.year} "
        "${check.checkedDatetime.hour.toString().padLeft(2, '0')}:${check.checkedDatetime.minute.toString().padLeft(2, '0')}";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (check.userName != null && check.userName!.isNotEmpty)
              Text("Uitgevoer deur: ${check.userName}",
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            if (check.userId != null)
              Text("Gebruiker #${check.userId}",
                style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _summaryChip("Bevestig", confirmed, AppColors.successGreen),
              const SizedBox(width: 6),
              _summaryChip("Foute", faultReported, AppColors.warningOrange),
              const SizedBox(width: 6),
              _summaryChip("Vermis", missing, AppColors.errorRed),
              const Spacer(),
              Text("Totaal: $total", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ),
        children: [
          _buildSummaryDetail(check.summary),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text("$label: $count", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSummaryDetail(String summaryJson) {
    List items;
    try {
      items = jsonDecode(summaryJson) as List;
    } catch (_) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Ongeldige opsommingsdata", style: TextStyle(color: Colors.grey)),
      );
    }

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Geen items", style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: items.map((item) {
          final statusStr = item['status'] ?? 'pending';
          final assetId = item['asset_id'] ?? 0;
          final faultId = item['fault_id'];

          IconData icon;
          Color iconColor;
          String label;
          switch (statusStr) {
            case 'confirmed':
              icon = Icons.check_circle;
              iconColor = AppColors.successGreen;
              label = "Bevestig";
              break;
            case 'fault_reported':
              icon = Icons.warning;
              iconColor = AppColors.warningOrange;
              label = "Fout aangemeld";
              break;
            case 'missing':
              icon = Icons.highlight_off;
              iconColor = AppColors.errorRed;
              label = "Vermis";
              break;
            default:
              icon = Icons.radio_button_unchecked;
              iconColor = Colors.grey;
              label = "Hangend";
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Bate #$assetId", style: const TextStyle(fontSize: 13)),
                ),
                Text(label, style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.bold)),
                if (faultId != null) ...[
                  const SizedBox(width: 4),
                  Text("(FK#$faultId)", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

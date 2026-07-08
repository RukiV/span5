import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/campus_service.dart';
import '../../widgets/status_badge.dart';
import '../../core/app_colors.dart';
import '../../models/asset.dart';
import '../../models/campus.dart';
import '../../services/asset_service.dart';
import '../../services/report_service.dart';
import '../../models/user_session.dart';
import '../reporting/report_detail_page.dart';
import '../../widgets/searchable_dropdown.dart';

class AssetDetailPage extends StatefulWidget {
  final Asset asset;

  const AssetDetailPage({super.key, required this.asset});

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  late Asset _currentAsset;

  @override
  void initState() {
    super.initState();
    _currentAsset = widget.asset;
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final relatedReports = ReportService.reportsNotifier.value
        .where((r) => r.assetId == _currentAsset.id || r.assetId == _currentAsset.serialCode)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(_currentAsset.name.toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditAssetDialog(context),
          ),
          if (UserSession.hasAdminPrivileges)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Besonderhede Seksie
            _buildSectionHeader("Besonderhede"),
            const SizedBox(height: 12),
            _buildInfoCard(),
            
            const SizedBox(height: 25),
            
            // Identifikasie Seksie
            _buildSectionHeader("Identifikasie"),
            const SizedBox(height: 12),
            _buildQRCard(),

            const SizedBox(height: 25),

            // Verslag Geskiedenis
            _buildSectionHeader("Verslag Geskiedenis"),
            const SizedBox(height: 12),
            relatedReports.isEmpty
              ? _buildEmptyState("Geen rapporterings vir hierdie bate nie.")
              : _buildReportList(relatedReports),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildDetailRow("Kampus", Text(CampusService.getCampusNameByRoomId(_currentAsset.location), style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Gebou", Text(CampusService.getBuildingNameByRoomId(_currentAsset.location), style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Lokaal", Text(CampusService.getRoomName(_currentAsset.location), style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Plasing", Text(_currentAsset.isOutdoor ? "Buite" : "Binne", style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Kategorie", Text(_currentAsset.category, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Divider(height: 24),
          _buildDetailRow("Status", StatusBadge(status: _currentAsset.status)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        value,
      ],
    );
  }

  Widget _buildQRCard() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Text(_currentAsset.serialCode, 
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 18, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            QrImageView(
              data: _currentAsset.serialCode,
              size: 160,
              version: QrVersions.auto,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList(List relatedReports) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: relatedReports.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final r = relatedReports[index];
          return ListTile(
            title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(r.timestamp.toString().split('.')[0], style: const TextStyle(fontSize: 12)),
            trailing: StatusBadge(status: r.phase),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReportDetailPage(report: r))),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic)),
    );
  }

  void _showEditAssetDialog(BuildContext context) {
    String tempName = _currentAsset.name;
    String tempSerial = _currentAsset.serialCode;
    String tempLocation = _currentAsset.location;
    String tempStatus = _currentAsset.status;
    bool tempIsOutdoor = _currentAsset.isOutdoor;
    String? tempSelectedCampus = CampusService.getCampusNameByRoomId(_currentAsset.location);
    String? tempSelectedBuilding = CampusService.getBuildingNameByRoomId(_currentAsset.location);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Wysig Bate", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildPopupField("Naam", tempName, (v) => tempName = v),
                  const SizedBox(height: 16),
                  _buildPopupField("Serienommer", tempSerial, (v) => tempSerial = v),
                  const SizedBox(height: 16),
                  const Text("Plasing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SwitchListTile(
                    title: Text(tempIsOutdoor ? "Buite" : "Binne"),
                    value: tempIsOutdoor,
                    onChanged: (v) => setDialogState(() => tempIsOutdoor = v),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<List<Campus>>(
                    valueListenable: CampusService.campusesNotifier,
                    builder: (context, campuses, _) {
                      return Column(
                        children: [
                          SearchableDropdown<String>(
                            label: "Kampus",
                            hint: "Kies kampus",
                            value: tempSelectedCampus,
                            items: campuses
                                .map((c) => SearchableDropdownItem(value: c.name, label: c.name))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() {
                                  tempSelectedCampus = v;
                                  tempSelectedBuilding = null;
                                  tempLocation = "1";
                                });
                              }
                            },
                          ),
                          if (tempSelectedCampus != null) const SizedBox(height: 16),
                          if (tempSelectedCampus != null)
                            SearchableDropdown<String>(
                              label: "Gebou",
                              hint: "Kies gebou",
                              value: tempSelectedBuilding,
                              items: () {
                                try {
                                  return campuses
                                      .firstWhere((c) => c.name == tempSelectedCampus)
                                      .buildings
                                      .map((b) => SearchableDropdownItem(value: b.name, label: b.name))
                                      .toList();
                                } catch (_) {
                                  return <SearchableDropdownItem<String>>[];
                                }
                              }(),
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() {
                                    tempSelectedBuilding = v;
                                    tempLocation = "1";
                                  });
                                }
                              },
                            ),
                          if (tempSelectedBuilding != null) const SizedBox(height: 16),
                          if (tempSelectedBuilding != null)
                            SearchableDropdown<String>(
                              label: "Lokaal",
                              hint: "Kies lokaal",
                              value: tempLocation,
                              items: () {
                                try {
                                  return campuses
                                      .firstWhere((c) => c.name == tempSelectedCampus)
                                      .buildings
                                      .firstWhere((b) => b.name == tempSelectedBuilding)
                                      .rooms
                                      ?.map((r) => SearchableDropdownItem(value: r.id.toString(), label: r.name))
                                      .toList() ?? [];
                                } catch (_) {
                                  return <SearchableDropdownItem<String>>[];
                                }
                              }(),
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() => tempLocation = v);
                                }
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SearchableDropdown<String>(
                    label: "Status",
                    hint: "Kies Status",
                    value: ["active", "maintenance", "retired", "inactive", "decommissioned"].contains(tempStatus.toLowerCase()) 
                        ? tempStatus.toLowerCase() 
                        : "active",
                    items: [
                      {"value": "active", "label": "Aktief"},
                      {"value": "maintenance", "label": "Onderhoud"},
                      {"value": "decommissioned", "label": "Afgedank"},
                      {"value": "inactive", "label": "Onaktief"},
                    ].map((s) => SearchableDropdownItem(value: s["value"]!, label: s["label"]!)).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => tempStatus = v);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Kanselleer")),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final updated = _currentAsset.copyWith(
                            name: tempName,
                            serialCode: tempSerial,
                            location: tempLocation,
                            status: tempStatus,
                            isOutdoor: tempIsOutdoor,
                          );
                          final success = await AssetService.updateAsset(updated);
                          if (!mounted) return;
                          if (success) {
                            setState(() => _currentAsset = updated);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white),
                        child: const Text("Opdateer"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verwyder Bate"),
        content: Text("Is jy seker jy wil '${_currentAsset.name}' verwyder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Kanselleer")),
          TextButton(
            onPressed: () async {
              final success = await AssetService.deleteAsset(_currentAsset.id);
              if (!mounted) return;
              if (success) {
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
                }
              }
            },
            child: const Text("Verwyder", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupField(String label, String initialValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          decoration: _popupInputDecoration(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  InputDecoration _popupInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/campus_service.dart';
import '../../widgets/status_badge.dart';
import '../../core/app_colors.dart';
import '../../models/asset.dart';
import '../../models/campus.dart';
import '../../core/asset_service.dart';
import '../../core/report_service.dart';
import '../../models/user_session.dart';
import '../reporting/report_detail_page.dart';

class AssetDetailPage extends StatefulWidget {
  final Asset asset;

  const AssetDetailPage({super.key, required this.asset});

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  final ImagePicker _picker = ImagePicker();
  late Asset _currentAsset;

  @override
  void initState() {
    super.initState();
    _currentAsset = widget.asset;
    if (CampusService.campusesNotifier.value.isEmpty) {
      CampusService.fetchCampuses();
    }
  }

  Future<void> _pickReceipt() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _currentAsset = _currentAsset.copyWith(
          warrantyReceipts: [..._currentAsset.warrantyReceipts, image.path],
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Slippie suksesvol bygevoeg!"), backgroundColor: AppColors.successGreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final relatedReports = ReportService.reportsNotifier.value
        .where((r) => r.assetId == _currentAsset.serialCode)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("BATE #${_currentAsset.serialCode}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditAssetDialog(context),
          ),
          if (UserSession.hasAdminPrivileges)
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.errorRed),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HOOF INLIGTING KAART
            _buildInfoCard(),
            const SizedBox(height: 25),

            // FINANSIËLE / GARANTIE DATA
            _buildSectionHeader("Aankoop & Waarborg"),
            const SizedBox(height: 12),
            _buildDetailRow("Aankoopdatum", _currentAsset.purchaseDate.toString().split(' ')[0]),
            _buildDetailRow("Op Kampus sedert", _currentAsset.campusStartDate.toString().split(' ')[0]),
            const SizedBox(height: 22),
            
            // IDENTIFIKASIE KODE
            _buildSectionHeader("Identifikasie Kode"),
            const SizedBox(height: 12),
            Center(
              child: InkWell(
                onTap: () => _showFullCode(context),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(_currentAsset.serialCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 16)),
                      const SizedBox(height: 15),
                      _currentAsset.serialCode.contains('-') 
                        ? QrImageView(data: _currentAsset.serialCode, size: 140)
                        : BarcodeWidget(barcode: Barcode.code128(), data: _currentAsset.serialCode, width: 200, height: 80),
                      const SizedBox(height: 10),
                      const Text("Klik om te vergroot", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            
            // SLIPPIES / DOKUMENTE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader("Dokumente (Slippies)"),
                IconButton(
                  onPressed: _pickReceipt,
                  icon: const Icon(Icons.add_a_photo, color: AppColors.gold, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _currentAsset.warrantyReceipts.isEmpty 
              ? Text("Geen dokumente opgelaai nie.", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _currentAsset.warrantyReceipts.map((path) => _buildDocThumbnail(path)).toList(),
                ),

            const SizedBox(height: 25),

            // VERSLAG GESKIEDENIS
            _buildSectionHeader("Verslag Geskiedenis"),
            const SizedBox(height: 12),
            relatedReports.isEmpty
              ? Text("Geen rapporterings vir hierdie bate nie.", style: TextStyle(color: Colors.grey[600], fontSize: 13))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: relatedReports.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final r = relatedReports[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text("${r.timestamp} - ${r.user}", style: const TextStyle(fontSize: 12)),
                      trailing: StatusBadge(status: r.phase),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ReportDetailPage(report: r)),
                        );
                      },
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_currentAsset.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
              StatusBadge(status: _currentAsset.status, fontSize: 13),
            ],
          ),
          const SizedBox(height: 5),
          Text(_currentAsset.category, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.gold),
              const SizedBox(width: 5),
              Text(CampusService.getRoomName(_currentAsset.location),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        ],
      ),
    );
  }

  Widget _buildDocThumbnail(String path) {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.receipt_long, color: Colors.grey),
        ),
      ),
    );
  }

  void _showFullCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("BATE KODE: ${_currentAsset.serialCode}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 25),
              _currentAsset.serialCode.contains('-') 
                ? QrImageView(data: _currentAsset.serialCode, size: 250)
                : BarcodeWidget(barcode: Barcode.code128(), data: _currentAsset.serialCode, width: 300, height: 120),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("TOE"),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showEditAssetDialog(BuildContext context) {
    String tempName = _currentAsset.name;
    String tempSerial = _currentAsset.serialCode;
    String tempLocation = _currentAsset.location;
    String tempStatus = _currentAsset.status;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Wysig Bate", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogContext)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildPopupField("Naam", tempName, (v) => tempName = v),
                  const SizedBox(height: 16),
                  _buildPopupField("Serienommer", tempSerial, (v) => tempSerial = v),
                  const SizedBox(height: 16),
                  const Text("Lokaal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<List<Campus>>(
                    valueListenable: CampusService.campusesNotifier,
                    builder: (context, campuses, _) {
                      final allRooms = campuses
                          .expand((c) => c.buildings)
                          .expand((b) => b.rooms ?? [])
                          .map((r) => '${r.id}:${r.name}')
                          .toList();
                      return DropdownButtonFormField<String>(
                        value: allRooms.any((r) => r.startsWith("$tempLocation:")) 
                            ? allRooms.firstWhere((r) => r.startsWith("$tempLocation:"))
                            : null,
                        decoration: _popupInputDecoration(),
                        items: allRooms.map<DropdownMenuItem<String>>((r) {
                          final parts = r.split(":");
                          final name = parts.last;
                          return DropdownMenuItem<String>(value: r, child: Text(name));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => tempLocation = v.split(":").first);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: tempStatus.toLowerCase(),
                    decoration: _popupInputDecoration(),
                    items: [
                      {"value": "active", "label": "Aktief"},
                      {"value": "maintenance", "label": "Onderhoud"},
                      {"value": "decommissioned", "label": "Afgedank"},
                      {"value": "inactive", "label": "Onaktief"},
                    ].map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                      value: s["value"],
                      child: Text(s["label"]!),
                    )).toList(),
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
                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Kanselleer", style: TextStyle(color: Colors.grey))),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final updated = _currentAsset.copyWith(
                            name: tempName,
                            serialCode: tempSerial,
                            location: tempLocation,
                            status: tempStatus,
                          );
                          final success = await AssetService.updateAsset(updated);
                          if (success && mounted) {
                            setState(() => _currentAsset = updated);
                            Navigator.pop(dialogContext);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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
              if (success && mounted) {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Return to list
              }
            },
            child: const Text("Verwyder", style: TextStyle(color: AppColors.errorRed)),
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
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }

  // _statusBadge verwyder aangesien ons nou die herbruikbare StatusBadge widget gebruik
}

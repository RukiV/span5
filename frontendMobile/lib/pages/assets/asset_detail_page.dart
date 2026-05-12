import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../models/asset.dart';
import '../../core/report_service.dart';
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
        const SnackBar(content: Text("Slippie suksesvol bygevoeg!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final relatedReports = ReportService.reportsNotifier.value
        .where((r) => r.assetId == _currentAsset.id)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("BATE #${_currentAsset.id}"),
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
                      Text(_currentAsset.id, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold, fontSize: 16)),
                      const SizedBox(height: 15),
                      _currentAsset.id.contains('-') 
                        ? QrImageView(data: _currentAsset.id, size: 140)
                        : BarcodeWidget(barcode: Barcode.code128(), data: _currentAsset.id, width: 200, height: 80),
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
                      trailing: _statusBadge(r.phase),
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
              _statusBadge(_currentAsset.status),
            ],
          ),
          const SizedBox(height: 5),
          Text(_currentAsset.category, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.gold),
              const SizedBox(width: 5),
              Text(_currentAsset.location, style: const TextStyle(fontWeight: FontWeight.w500)),
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
              Text("BATE ID: ${_currentAsset.id}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 25),
              _currentAsset.id.contains('-') 
                ? QrImageView(data: _currentAsset.id, size: 250)
                : BarcodeWidget(barcode: Barcode.code128(), data: _currentAsset.id, width: 300, height: 120),
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

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case "Aktief": case "Voltooi": color = Colors.green; break;
      case "Onderhoud": case "Besig": color = Colors.orange; break;
      case "Geweier": color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

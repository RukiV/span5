import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/report_service.dart';
import '../../models/report.dart';
import 'scan_page.dart';

class HandleReportPage extends StatefulWidget {
  final Report report;

  const HandleReportPage({super.key, required this.report});

  @override
  State<HandleReportPage> createState() => _HandleReportPageState();
}

class _HandleReportPageState extends State<HandleReportPage> {
  final _notesController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _manualIdController = TextEditingController();
  
  String _selectedPriority = "Medium";
  String? _geverifiseerdeKode;
  bool _kodeOnsigbaar = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.report.title;
    _descController.text = widget.report.description;
    _selectedPriority = widget.report.priority == "Geen" ? "Medium" : widget.report.priority;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  bool get _isVerified => (_geverifiseerdeKode != null) || 
                         (_manualIdController.text.isNotEmpty) || 
                         _kodeOnsigbaar;

  Future<void> _handleApprove() async {
    if (!_isVerified) return;

    setState(() => _isLoading = true);
    try {
      // Ons kan ook die titel en beskrywing opdateer indien nodig
      // Vir nou gebruik ons die bestaande approveReport wat notas en prioriteit hanteer
      await ReportService.approveReport(
        widget.report.id, 
        _selectedPriority, 
        _notesController.text
      );
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verslag goedgekeur en in vordering gestel"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fout: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("HANTEER VERSLAG #${widget.report.id}"),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionCard(
                  title: "STAP 1: PRIORITEIT",
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ["Laag", "Medium", "Hoog"].map((p) {
                      bool isSel = _selectedPriority == p;
                      Color pCol = p == "Hoog" ? Colors.red : (p == "Medium" ? Colors.orange : Colors.green);
                      return ChoiceChip(
                        label: Text(p, style: TextStyle(color: isSel ? Colors.white : pCol, fontWeight: FontWeight.bold)),
                        selected: isSel,
                        selectedColor: pCol,
                        backgroundColor: pCol.withOpacity(0.1),
                        onSelected: (val) => setState(() => _selectedPriority = p),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: "STAP 2: VERIFISEER BATE",
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanPage(isLocation: false)));
                                if (result != null) setState(() => _geverifiseerdeKode = result);
                              },
                              icon: Icon(_geverifiseerdeKode != null ? Icons.check_circle : Icons.qr_code_scanner),
                              label: Text(_geverifiseerdeKode != null ? "Geskandeer" : "Skandeer"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _geverifiseerdeKode != null ? Colors.green : AppColors.navy,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _manualIdController,
                              onChanged: (v) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: "Handmatige ID...",
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        title: const Text("Kode Onsigbaar / Beskadig", style: TextStyle(fontSize: 14, color: Colors.red)),
                        value: _kodeOnsigbaar,
                        activeColor: Colors.red,
                        onChanged: (v) => setState(() => _kodeOnsigbaar = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: "STAP 3: BESONDERHEDE & NOTAS",
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: "Opskrif",
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "Beskrywing",
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: "Interne notas vir tegnici...",
                          labelText: "Admin Notas",
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isVerified ? _handleApprove : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isVerified ? AppColors.gold : Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("GOEDKEUR & BEGIN HERSTEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1.1)),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/idempotency.dart';
import '../../models/user_session.dart';
import '../../services/asset_type_service.dart';
import '../../models/asset_type.dart';
import '../../widgets/selection_manager.dart';

class ManageAssetTypesPage extends StatefulWidget {
  const ManageAssetTypesPage({super.key});

  @override
  State<ManageAssetTypesPage> createState() => _ManageAssetTypesPageState();
}

class _ManageAssetTypesPageState extends State<ManageAssetTypesPage> {
  final _nameController = TextEditingController();
  final _avgController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  final SelectionController<int> _selection = SelectionController<int>();
  bool _isSaving = false;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = Idempotency.generate();
    AssetTypeService.fetchTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avgController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    final avg = int.tryParse(_avgController.text.trim());
    final min = int.tryParse(_minController.text.trim());
    final max = int.tryParse(_maxController.text.trim());
    final success = await AssetTypeService.addType(name, avgLifespan: avg, minLifespan: min, maxLifespan: max, idempotencyKey: _idempotencyKey);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (success) {
        _idempotencyKey = Idempotency.generate();
        _nameController.clear();
        _avgController.clear();
        _minController.clear();
        _maxController.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? "Bate tipe '$name' bygevoeg" : "Fout: kon nie stoor nie"),
        backgroundColor: success ? Colors.green : AppColors.errorRed,
      ),
    );
  }

  Future<void> _confirmDelete(AssetType t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Verwyder Bate Tipe"),
        content: Text("Weet jy seker jy wil '${t.name}' verwyder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Kanselleer")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Verwyder"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await AssetTypeService.deleteType(t.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "'${t.name}' verwyder" : "Fout: kon nie verwyder nie"),
          backgroundColor: success ? Colors.green : AppColors.errorRed,
        ),
      );
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool numeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Bestuur Bate Tipes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Voeg Nuwe Tipe By", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 8),
                _buildField(label: "Tipe Naam", hint: "bv. Elektriese Toerusting", controller: _nameController),
                const SizedBox(height: 12),
                _buildField(label: "Gemiddelde Lewensduur (jare)", hint: "Opsioneel", controller: _avgController, numeric: true),
                const SizedBox(height: 12),
                _buildField(label: "Minimum Lewensduur (jare)", hint: "Opsioneel", controller: _minController, numeric: true),
                const SizedBox(height: 12),
                _buildField(label: "Maksimum Lewensduur (jare)", hint: "Opsioneel", controller: _maxController, numeric: true),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Stoor", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                ValueListenableBuilder<List<AssetType>>(
                  valueListenable: AssetTypeService.typesNotifier,
                  builder: (context, types, _) {
                    if (types.isEmpty) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Nog geen bate tipes geskep nie.", style: TextStyle(color: Colors.grey)),
                      ));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Bestaande Tipes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        const SizedBox(height: 8),
                        ...types.map((t) {
                          final type = t;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            color: _selection.isSelected(type.id)
                                ? AppColors.lavender
                                : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                if (_selection.isSelecting) {
                                  setState(() => _selection.toggle(type.id));
                                }
                              },
                              onLongPress: () {
                                if (!UserSession.can('assets.manage')) return;
                                setState(() {
                                  _selection.enter();
                                  _selection.toggle(type.id);
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    if (_selection.isSelecting) ...[
                                      Checkbox(
                                        value: _selection.isSelected(type.id),
                                        onChanged: (_) => setState(() =>
                                            _selection.toggle(type.id)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(type.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _lifespanString(type),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_selection.isSelecting) ...[
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _confirmDelete(type),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: UserSession.can('assets.manage')
          ? BulkDeleteFloatingAction<int>(
              controller: _selection,
              confirmTitle: 'Verwyder Bate Tipes',
              confirmMessage:
                  'Wil jy ${_selection.count} geselekteerde bate tipe(s) verwyder?',
              onDelete: _bulkDeleteTypes,
            )
          : null,
    );
  }

  Future<void> _bulkDeleteTypes(BuildContext context, Set<int> ids) async {
    int ok = 0;
    int fail = 0;
    for (final id in ids) {
      if (await AssetTypeService.deleteType(id)) {
        ok++;
      } else {
        fail++;
      }
    }
    await AssetTypeService.fetchTypes();
    if (context.mounted) {
      setState(() => _selection.exit());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fail == 0
              ? "$ok tipe(s) verwyder."
              : "$ok verwyder, $fail kon nie verwyder word nie."),
          backgroundColor:
              fail == 0 ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  String _lifespanString(AssetType t) {
    final parts = <String>[];
    if (t.avgLifespan != null) parts.add("Gem: ${t.avgLifespan}M");
    if (t.minLifespan != null) parts.add("Min: ${t.minLifespan}M");
    if (t.maxLifespan != null) parts.add("Maks: ${t.maxLifespan}M");
    return parts.isEmpty ? "Geen lewensduur" : parts.join(", ");
  }
}
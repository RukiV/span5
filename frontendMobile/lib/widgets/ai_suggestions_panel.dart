import 'dart:async';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/ai_service.dart';

/// AiSuggestionsPanel — drywende paneel wat AI-veldvoorstelle wys terwyl 'n
/// vorm ingevul word (mobiele eweknie van die web se AiSuggestPanel).
///
/// Die paneel bestuur sy eie debounce + versoeke: gee bloot die vorm se huidige
/// waardes in [fields] en hanteer [onUse] om 'n voorstel toe te pas. Onder 3
/// ingevulde velde wys dit 'n leidraad i.p.v. voorstelle.
class AiSuggestionsPanel extends StatefulWidget {
  /// Watter tipe vorm: 'asset' | 'stock' | 'fault' | 'job' | 'draft'.
  final String context;

  /// Die vorm se HUIDIGE waardes (sleutel → waarde).
  final Map<String, dynamic> fields;

  /// Vrywillige vertoonname per veldsleutel vir die paneel se rye.
  final Map<String, String> labels;

  /// Word aangeroep wanneer die gebruiker "Gebruik" tik.
  final void Function(String key, AiSuggestion suggestion)? onUse;

  const AiSuggestionsPanel({
    super.key,
    required this.context,
    required this.fields,
    this.labels = const {},
    this.onUse,
  });

  @override
  State<AiSuggestionsPanel> createState() => _AiSuggestionsPanelState();
}

class _AiSuggestionsPanelState extends State<AiSuggestionsPanel> {
  Map<String, AiSuggestion> _suggestions = {};
  bool _loading = false;
  bool _expanded = true;
  Timer? _debounce;

  int get _filledCount => widget.fields.values.where((v) {
        if (v == null) return false;
        if (v is String && v.trim().isEmpty) return false;
        return true;
      }).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _filledCount >= 3) _fetch();
    });
  }

  @override
  void didUpdateWidget(covariant AiSuggestionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.fields, widget.fields)) {
      _debounce?.cancel();
      if (_filledCount < 3) {
        setState(() => _suggestions = {});
        return;
      }
      _debounce = Timer(const Duration(milliseconds: 800), _fetch);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final result = await AiService.suggest(context: widget.context, fields: widget.fields);
    if (mounted) setState(() {
      _suggestions = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _suggestions.entries
        .where((e) => e.value.value.trim().isNotEmpty)
        .toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: AppColors.navy,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'AI Voorstelle${entries.isNotEmpty ? ' (${entries.length})' : ''}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_more : Icons.chevron_right, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: _buildBody(entries),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(List<MapEntry<String, AiSuggestion>> entries) {
    if (_filledCount < 3) {
      return const Text(
        'Vul minstens 3 velde in, dan stel ek voor hoe die res gevul kan word.',
        style: TextStyle(color: Colors.grey, fontSize: 12.5),
      );
    }
    if (_loading && entries.isEmpty) {
      return const Row(children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
        SizedBox(width: 8),
        Text('Dink…', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
      ]);
    }
    if (entries.isEmpty) {
      return const Text(
        'Geen voorstelle vir die oop velde nie.',
        style: TextStyle(color: Colors.grey, fontSize: 12.5),
      );
    }
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.labels[e.key] ?? e.key).toUpperCase(),
                        style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.4),
                      ),
                      Text(
                        e.value.value,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => widget.onUse?.call(e.key, e.value),
                  child: const Text('Gebruik'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

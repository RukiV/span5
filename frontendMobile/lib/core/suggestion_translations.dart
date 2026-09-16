/// Vertaal backend-/inskrywingsvoorstellings na die vorms se AF-vertoonwaardes.
///
/// Die AI-voorstel-diens ([AiService.suggest]) gee dikwels die backend interna
/// (bv. `MAINTENANCE`) of 'n vertoonwaarde uit 'n ander taksonomie (bv.
/// `Instandhouding`) terug. Hierdie helper bring dit in lyn met die waarde wat
/// die uniforme vormveld stoor, sodat 'n voorstel dadelik toegepas kan word.
String translateSuggestion(String key, String value) {
  if (value.trim().isEmpty) return value;
  final map = _translations[key];
  if (map == null) return value;
  final direct = map[value.trim()];
  if (direct != null) return direct;
  final lowered = value.trim().toLowerCase();
  for (final entry in map.entries) {
    if (entry.key.toLowerCase() == lowered) return entry.value;
  }
  return value;
}

const Map<String, Map<String, String>> _translations = {
  'asset_status': {
    'Instandhouding': 'Onderhoud',
  },
  'job_type': {
    'MAINTENANCE': 'Onderhoud',
    'REPAIR': 'Herstel',
  },
  'job_priority': {
    'HIGH': 'Hoog',
    'MEDIUM': 'Normal',
    'LOW': 'Laag',
  },
};
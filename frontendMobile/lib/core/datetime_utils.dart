DateTime? parseServerDatetime(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  if (s.isEmpty) return null;
  final hasOffset = RegExp(r'[zZ]$|[+-]\d{2}:?\d{2}$').hasMatch(s);
  return DateTime.parse(hasOffset ? s : '${s}Z').toLocal();
}

/// Parses a naive (no timezone offset) datetime string as local wall-clock
/// time with no conversion — the same interpretation the backend, the web
/// frontend, and jobcard.dart use. Values that DO carry an offset/Z suffix are
/// still normalised to local time.
DateTime? parseWallClockDatetime(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  if (s.isEmpty) return null;
  final hasOffset = RegExp(r'[zZ]$|[+-]\d{2}:?\d{2}$').hasMatch(s);
  if (hasOffset) return DateTime.parse(s).toLocal();
  return DateTime.tryParse(s);
}

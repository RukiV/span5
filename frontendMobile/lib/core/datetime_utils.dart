DateTime? parseServerDatetime(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  if (s.isEmpty) return null;
  final hasOffset = RegExp(r'[zZ]$|[+-]\d{2}:?\d{2}$').hasMatch(s);
  return DateTime.parse(hasOffset ? s : '${s}Z').toLocal();
}

import 'package:flutter/services.dart';

/// Formateer 'n batekode terwyl jy tik: hoofletters, en 'n spasie word tussen
/// die 2de en 3de letter ingevoeg wanneer die kode met "AK" begin
/// (bv. `akmt000014` → `AK MT000014`). Ander formate word net ge-uppercase.
class AssetCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase();
    String text = raw;
    if (raw.length >= 3 &&
        raw.startsWith('AK') &&
        raw[2] != ' ' &&
        raw[2] != '-') {
      text = 'AK ${raw.substring(2)}';
    }
    if (text == newValue.text) return newValue;
    final base = newValue.selection.baseOffset;
    final delta = text.length - newValue.text.length;
    final caret = base > 2 ? base + delta : base;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret.clamp(0, text.length)),
    );
  }
}
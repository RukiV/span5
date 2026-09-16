import 'package:flutter/material.dart';
import 'app_colors.dart';

InputDecoration appInputDecoration({
  String? label,
  String? hintText,
  TextStyle? hintStyle,
  TextStyle? labelStyle = const TextStyle(color: AppColors.navy, fontSize: 14),
  Color? fillColor = const Color(0xFFFAFAFA),
  Color? borderColor = const Color(0xFFE0E0E0),
  Color focusedBorderColor = AppColors.gold,
  double focusedBorderWidth = 2,
  double radius = 10,
  bool showErrorBorder = false,
  EdgeInsetsGeometry contentPadding =
      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: borderColor ?? const Color(0xFFE0E0E0)),
  );
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    hintStyle: hintStyle,
    labelStyle: labelStyle,
    filled: true,
    fillColor: fillColor,
    contentPadding: contentPadding,
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide:
          BorderSide(color: focusedBorderColor, width: focusedBorderWidth),
    ),
    errorBorder: showErrorBorder
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: AppColors.errorRed),
          )
        : null,
  );
}

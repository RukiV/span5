import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/input_decoration.dart';

/// Statiese etiket bo 'n [TextFormField] met die uniforme veldvoorkoms
/// (appInputDecoration). Vervang die herhaalde "vet etiket bo veld"-patroon
/// in die skep-/wysig-vorms.
class LabeledFormField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final bool showErrorBorder;
  final InputDecoration? decoration;

  const LabeledFormField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.inputFormatters,
    this.showErrorBorder = false,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.navy)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          style: const TextStyle(fontSize: 14),
          decoration: decoration ??
              appInputDecoration(showErrorBorder: showErrorBorder),
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }
}

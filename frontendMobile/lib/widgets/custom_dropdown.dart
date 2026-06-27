import 'package:flutter/material.dart';

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final String? label;

  const CustomDropdown({
    super.key,
    this.value,
    required this.hint,
    required this.items,
    this.onChanged,
    this.validator,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true, // Fix vir overflow
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFEFBEA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          hint: Text(hint, style: const TextStyle(fontSize: 14)),
          items: items,
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}

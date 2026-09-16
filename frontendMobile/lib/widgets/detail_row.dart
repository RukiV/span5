import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Gedeelde "label + waarde"-ry vir detail-/rekordbesigtiging.
///
/// Ondersteun drie uitlegte om elke bladsy se huidige voorkoms te behou:
/// - [icon]: 'n ikoon voor die waarde (kalender).
/// - [labelWidth]: vaste-etiket-kolom met 'n Expanded-waarde (verslae/werksopdragte).
/// - geen van bogenoemde nie: `spaceBetween`-ry met 'n vrywaarde-widget (bates).
class DetailRow extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String? value;
  final Widget? valueWidget;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final EdgeInsetsGeometry padding;
  final double? labelWidth;
  final double spacing;

  const DetailRow({
    super.key,
    this.label,
    this.icon,
    this.value,
    this.valueWidget,
    this.labelStyle,
    this.valueStyle,
    this.padding = EdgeInsets.zero,
    this.labelWidth,
    this.spacing = 6,
  }) : assert(label != null || icon != null, 'Provide a label or an icon');

  @override
  Widget build(BuildContext context) {
    final effectiveLabelStyle =
        labelStyle ?? TextStyle(color: Colors.grey[600], fontSize: 14);
    final effectiveValueStyle = valueStyle ??
        (icon != null
            ? const TextStyle(color: Colors.black54)
            : const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.bold,
                fontSize: 14));
    final valueChild =
        valueWidget ?? Text(value ?? '', style: effectiveValueStyle);

    final Widget body;
    if (icon != null) {
      body = Row(
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          SizedBox(width: spacing),
          Expanded(child: valueChild),
        ],
      );
    } else if (labelWidth != null) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: labelWidth, child: Text(label!, style: effectiveLabelStyle)),
          Expanded(child: valueChild),
        ],
      );
    } else {
      body = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label!, style: effectiveLabelStyle),
          valueChild,
        ],
      );
    }

    return Padding(padding: padding, child: body);
  }
}
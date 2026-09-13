import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final BoxShape shape;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final Size? minSize;
  final int? maxCount;

  const CountBadge(
    this.count, {
    super.key,
    this.color = AppColors.gold,
    this.shape = BoxShape.rectangle,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    this.fontSize = 9,
    this.minSize = const Size(16, 16),
    this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: shape == BoxShape.circle
          ? BoxDecoration(color: color, shape: BoxShape.circle)
          : BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
      constraints: minSize == null
          ? null
          : BoxConstraints(
              minWidth: minSize!.width, minHeight: minSize!.height),
      child: Text(
        maxCount != null && count > maxCount! ? '$maxCount+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Die een consistente ry-karakter vir alle lysbladsye in die app: 'n
/// afgeronde kaart wat kolom-gedrewe waardes vertoon (sonder veld-etikette).
///
/// Elke bladsy bou [children] deur sy sigbare kolomme (`_colVis.visibleColumns`)
/// na 'n waarde-widget per kolom te map. [leading] word vir die kies-modus
/// se merkboks gebruik en [trailing] vir bykomende aksies (bv. wysig/chevron).
class CardDataRow extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final double radius;
  final double bottomMargin;

  const CardDataRow({
    super.key,
    required this.children,
    this.onTap,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.all(15),
    this.elevation = 2,
    this.radius = 10,
    this.bottomMargin = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      margin: EdgeInsets.only(bottom: bottomMargin),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) leading!,
              ...children,
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

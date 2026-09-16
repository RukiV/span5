import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Kompakte ikoon-aksie vir [FixedPageHeader]. 'n 40px vierkant met 'n wit
/// ikoon op 'n deurskynende wit agtergrond — spaar spasie in die kop in
/// plaas van teks-pille.
class HeaderIconAction extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final Color iconColor;

  /// Wys 'n klein goue kolletjie wanneer 'n filter aktief is.
  final bool activeBadge;

  /// Vervang die ikoon met 'n spinner en deaktiveer die knoppie (bv. tydens
  /// 'n AI-versoek) sodat die gebruiker weet dié aksie is besig.
  final bool loading;

  const HeaderIconAction({
    super.key,
    required this.icon,
    this.tooltip,
    this.onTap,
    this.iconColor = Colors.white,
    this.activeBadge = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: loading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : Icon(icon, color: iconColor),
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor:
                Colors.white.withValues(alpha: loading ? 0 : 30 / 255),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: loading ? null : onTap,
        ),
        if (activeBadge)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

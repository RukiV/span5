import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'location_cascade_picker.dart';

export 'location_cascade_picker.dart' show LocationDepth;

/// Maak die Terrein › Gebou › Lokaal kieser oop teen die bokant van die
/// skerm (as 'n vasgestelde kieser), sodat die klawerbord wat onder oopmaak
/// die kieser nie toemaak nie. Gee [onChanged] deur soos die gebruiker kies;
/// die bladsy hou die huidige keuses self by.
Future<void> showLocationFilterSheet(
  BuildContext context, {
  LocationDepth depth = LocationDepth.room,
  int? campusId,
  int? buildingId,
  int? roomId,
  required void Function(int? campusId, int? buildingId, int? roomId)
      onChanged,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Sluit',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, __) {
      return Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: Colors.white,
              elevation: 8,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter op Ligging',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: Colors.grey,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      child: LocationCascadePicker(
                        depth: depth,
                        initialCampusId: campusId,
                        initialBuildingId: buildingId,
                        initialRoomId: roomId,
                        onChanged: onChanged,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Klaar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

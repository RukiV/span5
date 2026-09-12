import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Gedeelde skermraam vir 'n enkelvorm-bladsy wat beide "voeg nuwe"- en
/// "wysig"-modus hanteer.
///
/// In nie-skepmodus begin dit in 'n kyk-modus: velde is gesluit en 'n potlood-
/// knoppie (slegs wanneer [canEdit]) skakel redigering aan. Die [child]-velde
/// word deur die ouer gebou; die raam hanteer die appbar, vormomhulsel,
/// footer-knoppies en die stoor-toestand (spinner).
class ViewEditScaffold extends StatefulWidget {
  const ViewEditScaffold({
    super.key,
    required this.title,
    required this.formKey,
    required this.child,
    required this.onSave,
    this.editingTitle,
    this.saveLabel = 'STOOR',
    this.canEdit = false,
    this.alwaysEditable = false,
    this.deleteButton,
    this.showSaveSpinner = true,
    this.saveLetterSpacing = 1.1,
    this.showCancel = true,
  });

  final String title;
  final String? editingTitle;
  final String saveLabel;
  final double saveLetterSpacing;
  final GlobalKey<FormState> formKey;
  final bool canEdit;
  final bool alwaysEditable;
  final bool showSaveSpinner;
  final bool showCancel;
  final Widget child;
  final Future<void> Function() onSave;
  final Widget? deleteButton;

  @override
  State<ViewEditScaffold> createState() => _ViewEditScaffoldState();
}

class _ViewEditScaffoldState extends State<ViewEditScaffold> {
  bool _editing = false;
  bool _saving = false;

  bool get _active => widget.alwaysEditable || _editing;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.alwaysEditable || !_active
        ? widget.title
        : (widget.editingTitle ?? widget.title);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          if (!widget.alwaysEditable && !_editing && widget.canEdit)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Wysig',
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: widget.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IgnorePointer(
                  ignoring: !_active,
                  child: Opacity(
                    opacity: _active ? 1 : 0.6,
                    child: widget.child,
                  ),
                ),
                const SizedBox(height: 32),
                if (_active) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: widget.showSaveSpinner && _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              widget.saveLabel,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: widget.saveLetterSpacing),
                            ),
                    ),
                  ),
                  if (widget.showCancel) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Kanselleer",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("KLAAR",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                  ),
                if (widget.deleteButton != null) ...[
                  const SizedBox(height: 12),
                  widget.deleteButton!,
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

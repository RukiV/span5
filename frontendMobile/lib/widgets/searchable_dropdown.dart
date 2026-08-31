import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'anchored_dropdown.dart';

/// Die app se keuselys-widget: 'n veld wat 'n soekbare oorvleueling oopmaak
/// wat lewendig filter soos jy tik — nie meer 'n sentrale dialoog nie.
class SearchableDropdown<T> extends StatefulWidget {
  /// Opskrif bo die veld. Laat weg vir inlyn-filters wat reeds 'n konteks het.
  final String? label;
  final String hint;
  final T? value;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  /// Wanneer vals is die veld dof en open dit nie die soekoorvleueling nie.
  final bool enabled;

  /// Opsionele knoppie regs in die veld.
  final Widget? trailing;

  /// Wanneer waar kry die etiket 'n * en 'n rooi kleur as [error] waar is.
  final bool required;

  /// Maak die etiket (en veldraam) rooi — gebruik vir vereiste velde wat nog leeg is.
  final bool error;

  const SearchableDropdown({
    super.key,
    this.label,
    required this.hint,
    this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.trailing,
    this.required = false,
    this.error = false,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _open(BuildContext context) {
    if (_overlayEntry != null) return;
    final fieldSize = _fieldKey.currentContext?.size;
    final width = fieldSize?.width ?? 260.0;
    _overlayEntry = openAnchoredDropdown(
      context: context,
      layerLink: _layerLink,
      onDismiss: _close,
      child: _SearchOverlayPanel<T>(
        title: widget.label ?? widget.hint,
        items: widget.items,
        initialValue: widget.value,
        width: width,
        onSelected: (v) {
          widget.onChanged(v);
          _close();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayValue = widget.hint;
    if (widget.value != null) {
      final selectedItem = widget.items.where((i) => i.value == widget.value).firstOrNull;
      if (selectedItem != null) {
        displayValue = selectedItem.label;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.required ? '${widget.label} *' : widget.label!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: widget.error ? AppColors.errorRed : AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: widget.enabled ? () => _open(context) : null,
          child: FormField<T>(
            key: widget.value != null ? ValueKey('${widget.label}_${widget.value}') : null,
            validator: widget.validator,
            initialValue: widget.value,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: Container(
                      key: _fieldKey,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      decoration: BoxDecoration(
                        color: (state.hasError || widget.error)
                            ? const Color(0xFFFFEBEE)
                            : (widget.enabled ? Colors.white : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: (state.hasError || widget.error)
                                ? Colors.red
                                : Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayValue,
                              style: TextStyle(
                                color: widget.value == null ? Colors.grey[600] : Colors.black,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: widget.enabled ? Colors.grey : Colors.grey[400],
                          ),
                          if (widget.trailing != null) widget.trailing!,
                        ],
                      ),
                    ),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 12),
                      child: Text(
                        state.errorText ?? "",
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class SearchableDropdownItem<T> {
  final T value;
  final String label;

  const SearchableDropdownItem({required this.value, required this.label});
}

/// Open dieselfde soekbare oorvleueling as [SearchableDropdown], maar vir
/// kontroles wat hul eie voorkoms hou — bv. die kompakte filters in 'n blad se
/// kopbalk. Die paneel anker regs onder die toolbar.
Future<void> showSearchableDialog<T>({
  required BuildContext context,
  required String title,
  required List<SearchableDropdownItem<T>> items,
  required ValueChanged<T?> onSelected,
  T? initialValue,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final screenWidth = MediaQuery.sizeOf(ctx).width;
      final width = (screenWidth - 32).clamp(200.0, 360.0);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => entry.remove(),
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: kToolbarHeight + 4, right: 12),
              child: _SearchOverlayPanel<T>(
                title: title,
                items: items,
                initialValue: initialValue,
                width: width,
                onSelected: (v) {
                  onSelected(v);
                  entry.remove();
                },
              ),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  return Future.value();
}

class _SearchOverlayPanel<T> extends StatefulWidget {
  final String title;
  final List<SearchableDropdownItem<T>> items;
  final T? initialValue;
  final ValueChanged<T?> onSelected;
  final double width;

  const _SearchOverlayPanel({
    required this.title,
    required this.items,
    this.initialValue,
    required this.onSelected,
    required this.width,
  });

  @override
  State<_SearchOverlayPanel<T>> createState() => _SearchOverlayPanelState<T>();
}

class _SearchOverlayPanelState<T> extends State<_SearchOverlayPanel<T>> {
  late List<SearchableDropdownItem<T>> filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      filteredItems = widget.items
          .where((item) => item.label.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.width, maxHeight: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Text(
                "Kies ${widget.title}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Soek...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                ),
                onChanged: _filter,
              ),
            ),
            Flexible(
              child: filteredItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Geen opsies nie', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = item.value == widget.initialValue;
                        return ListTile(
                          dense: true,
                          title: Text(
                            item.label,
                            style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          ),
                          selected: isSelected,
                          selectedTileColor: AppColors.gold.withAlpha(30),
                          onTap: () => widget.onSelected(item.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'anchored_dropdown.dart';
import 'searchable_dropdown.dart' show SearchableDropdownItem;

/// 'n Keuselys wat soos 'n regte dropdown lyk en werk (soos die web se
/// react-select): 'n veld met 'n pyltjie wat 'n oorvleuelende soekbare keuselys
/// oopmaak direk onder hom. Die lys verleng met sy opsies in plaas van 'n
/// vasgestelde skuifwiel te wees — tot 'n hoogte-kap om van die skerm af te bly.
class InlineSearchableDropdown<T> extends StatefulWidget {
  /// Opskrif bo die veld. Laat weg vir inlyn-filters wat reeds 'n konteks het.
  final String? label;
  final String hint;
  final T? value;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  /// Wanneer vals is die veld dof en geen keuse moontlik nie.
  final bool enabled;

  /// Opsionele knoppie regs in die veld.
  final Widget? trailing;

  /// Bly die lys oop nadat 'n opsie gekies is (vir trap-vlak-kiesers soos die
  /// terrein/gebou/lokaal-kaskade). Default sluit na keuse.
  final bool closeOnSelect;

  /// Herstel die oorspronklike waarde se teks wanneer die veld verloor word
  /// sonder 'n keuse. Word vir die oorvleuelende menu nie meer gebruik nie maar
  /// bly vir terugwaartse verenigbaarheid.
  final bool restoreOnBlur;

  /// Vuur wanneer die menu oopmaak — bv. om 'n voltooide kaskade terug te stel
  /// na vlak 0 ("tik om te verander").
  final VoidCallback? onFocus;

  /// Vuur wanneer die menu oopmaak (true) of toemaak (false).
  final ValueChanged<bool>? onSearchModeChanged;

  /// Maksimum hoogte vir die opsie-lys. Laat weg (null) sodat die lys sy
  /// natuurlike hoogte kry — dit "verleng" met die aantal opsies in plaas van
  /// 'n vasgestelde skuifwiel te wees. Gee 'n waarde om te skuif bokant dit.
  final double? maxHeight;

  const InlineSearchableDropdown({
    super.key,
    this.label,
    required this.hint,
    this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.trailing,
    this.closeOnSelect = true,
    this.restoreOnBlur = true,
    this.onFocus,
    this.onSearchModeChanged,
    this.maxHeight,
  });

  @override
  State<InlineSearchableDropdown<T>> createState() =>
      _InlineSearchableDropdownState<T>();
}

class _InlineSearchableDropdownState<T>
    extends State<InlineSearchableDropdown<T>> {
  /// Gedeelde register oor alle instansies heen (statiese lede van 'n
  /// generiese klas word gedeel) sodat net EEN dropdown oop kan wees.
  static final Set<_InlineSearchableDropdownState<Object?>> _openStates = {};

  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _open = false;

  String? _labelOf(T? v) {
    if (v == null) return null;
    for (final i in widget.items) {
      if (i.value == v) return i.label;
    }
    return null;
  }

  String get _displayText =>
      _labelOf(widget.value) ?? widget.hint;

  bool get _hasValue => widget.value != null;

  @override
  void dispose() {
    _openStates.remove(this);
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InlineSearchableDropdown<T> old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _open) {
      _closeMenu();
    }
    // Die kaskade se opsies verander terwyl die menu oop is ('n vlak is gekies
    // en die volgende vlak se lyste moet wys). Herbou die oop menu in plek.
    if (_open &&
        (widget.items != old.items ||
            widget.hint != old.hint ||
            widget.value != old.value)) {
      _overlayEntry?.markNeedsBuild();
    }
    if (widget.hint != old.hint || widget.value != old.value) {
      setState(() {});
    }
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_open) {
      _open = false;
      _openStates.remove(this);
      widget.onSearchModeChanged?.call(false);
      if (mounted) setState(() {});
    }
  }

  void _openMenu() {
    if (!widget.enabled || _overlayEntry != null) return;
    for (final other in _openStates.toList()) {
      if (other != this && other.mounted && other._open) other._closeMenu();
    }
    _openStates.add(this);
    setState(() => _open = true);
    widget.onFocus?.call();
    widget.onSearchModeChanged?.call(true);
    _createMenu();
  }

  void _createMenu() {
    final ctx = _fieldKey.currentContext;
    if (ctx == null) return;
    final RenderBox? box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final width = box.size.width;
    _overlayEntry = openAnchoredDropdown(
      context: context,
      layerLink: _layerLink,
      onDismiss: _closeMenu,
      child: _SearchableOverlay<T>(
        items: widget.items,
        selectedValue: widget.value,
        width: width,
        maxHeight: _resolvedMaxHeight(ctx),
        onSelected: _select,
      ),
    );
  }

  /// Bepaal hoe ver die oop lys mag groei: die gegewe kap, andersins die
  /// natuurlike hoogte — maar nooit verder as die spasie wat op die skerm
  /// oorbly onder die veld nie, sodat die menu nooit van die skerm af hardloop.
  double _resolvedMaxHeight(BuildContext ctx) {
    final screen = MediaQuery.sizeOf(ctx).height;
    final bottom = boxBottomGlobalY(ctx);
    final availableBelow = screen - bottom - 8;
    final cap = widget.maxHeight ?? screen * 0.45;
    return cap.clamp(160.0, availableBelow);
  }

  double boxBottomGlobalY(BuildContext ctx) {
    final RenderBox? box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return MediaQuery.sizeOf(ctx).height;
    return box.localToGlobal(Offset.zero).dy + box.size.height;
  }

  void _select(T? value) {
    widget.onChanged(value);
    if (widget.closeOnSelect) {
      _closeMenu();
    } else {
      // Bly oop sodat die kaskade sy volgende vlak se opsies kan wys.
      setState(() {});
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _clear() {
    widget.onChanged(null);
    setState(() {});
    _overlayEntry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: InkWell(
            key: _fieldKey,
            borderRadius: BorderRadius.circular(10),
            onTap: widget.enabled
                ? (_open ? _closeMenu : _openMenu)
                : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: widget.enabled ? Colors.white : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _open ? AppColors.gold : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayText,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: _hasValue ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: widget.enabled ? Colors.grey[700] : Colors.grey[400],
                  ),
                  if (widget.enabled && _hasValue)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clear,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Die oorvleuelende keuselys wat onder die veld oopmaak: 'n soekveld bo wat
/// die opsies lewendig filter, en die lys wat met sy opsies verleng.
class _SearchableOverlay<T> extends StatefulWidget {
  final List<SearchableDropdownItem<T>> items;
  final T? selectedValue;
  final double width;
  final double maxHeight;
  final ValueChanged<T?> onSelected;

  const _SearchableOverlay({
    required this.items,
    required this.selectedValue,
    required this.width,
    required this.maxHeight,
    required this.onSelected,
  });

  @override
  State<_SearchableOverlay<T>> createState() => _SearchableOverlayState<T>();
}

class _SearchableOverlayState<T> extends State<_SearchableOverlay<T>> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SearchableDropdownItem<T>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((i) => i.label.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Soek...',
                  hintStyle:
                      TextStyle(color: Colors.grey[600], fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: filtered.isEmpty
                  ? const SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Geen opsies nie',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected =
                            widget.selectedValue == item.value;
                        return ListTile(
                          dense: true,
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
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
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Die item-klas vir [InlineSearchableDropdown].
class InlineSearchableDropdownItem<T> {
  final T value;
  final String label;

  const InlineSearchableDropdownItem({
    required this.value,
    required this.label,
  });
}

/// 'n Keuselys met twee modusse:
/// * **Blaai-modus** (default): 'n Nie-redigeerbare veld wat lyk soos 'n
///   teksboks. Tik om die lys oop/ toe te maak. 'n Soek-ikoon regs gee
///   toegang tot soek-modus.
/// * **Soek-modus**: 'n Regte [TextField] met sleutelbord vir filtering.
class InlineSearchableDropdown<T> extends StatefulWidget {
  final String? label;
  final String hint;
  final T? value;
  final List<InlineSearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  final bool enabled;
  final Widget? trailing;
  final bool required;
  final bool error;

  /// Form-valsidasie; `null` = geen valsidasie.
  final String? Function(T?)? validator;

  /// Bly die lys oop nadat 'n opsie gekies is (vir kaskades).
  final bool closeOnSelect;

  /// Herstel die oorspronklike waarde se teks wanneer die veld verloor word
  /// sonder 'n keuse.
  final bool restoreOnBlur;

  /// Vuur wanneer die veld fokus kry (slegs in soek-modus).
  final VoidCallback? onFocus;

  const InlineSearchableDropdown({
    super.key,
    this.label,
    required this.hint,
    this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.trailing,
    this.required = false,
    this.error = false,
    this.validator,
    this.closeOnSelect = true,
    this.restoreOnBlur = true,
    this.onFocus,
  });

  @override
  State<InlineSearchableDropdown<T>> createState() =>
      _InlineSearchableDropdownState<T>();
}

class _InlineSearchableDropdownState<T>
    extends State<InlineSearchableDropdown<T>> {
  static final Set<_InlineSearchableDropdownState<Object?>> _openStates = {};

  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  final FocusNode _browseFocus = FocusNode();
  final GlobalKey _listKey = GlobalKey();
  bool _open = false;

  String? _preFocusText;

  bool _searchMode = false;

  /// Word vinnig gesit terwyl die gebruiker die sleutelbord-ikoon druk
  /// (verberg sleutelbord), sodat die outo-afsluiting met 150ms vertraging
  /// nie soek-modus beëindig nie.
  bool _suppressExit = false;

  /// Wys of die sleutelbord tans verberg is (soek-modus bly oop).
  bool _keyboardHidden = false;

  String? _labelOf(T? v) {
    if (v == null) return null;
    for (final i in widget.items) {
      if (i.value == v) return i.label;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _text.text = _labelOf(widget.value) ?? '';
    _focus.addListener(_onFocusChanged);
    _browseFocus.addListener(_onBrowseFocusChanged);
  }

  @override
  void didUpdateWidget(InlineSearchableDropdown<T> old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) {
      _closeAll();
    }
    if (widget.hint != old.hint || widget.value != old.value) {
      final lbl = _labelOf(widget.value);
      final newText = lbl ?? '';
      if (_text.text != newText) _text.text = newText;
    }
  }

  @override
  void dispose() {
    _openStates.remove(this);
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _browseFocus.removeListener(_onBrowseFocusChanged);
    _browseFocus.dispose();
    _text.dispose();
    super.dispose();
  }

  // ─── Soek-modus fokusbestuur ───────────────────────────────────────────

  void _onFocusChanged() {
    if (!mounted) return;
    if (!_searchMode) return;
    if (_focus.hasFocus) {
      setState(() => _keyboardHidden = false);
      widget.onFocus?.call();
    } else {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focus.hasFocus && !_suppressExit) {
          _exitSearchMode();
        }
      });
    }
  }

  // ─── Blaai-modus fokusbestuur ─────────────────────────────────────────

  void _onBrowseFocusChanged() {
    if (!mounted) return;
    if (_searchMode) return;
    if (!_browseFocus.hasFocus && _open) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_browseFocus.hasFocus && !_searchMode) {
          _closeList();
        }
      });
    }
  }

  // ─── Blaai-modus (tik op die veld) ─────────────────────────────────────

  void _toggleList() {
    if (!widget.enabled) return;
    if (_open) {
      _closeList();
    } else {
      _openList();
    }
  }

  // ─── Soek-ikoon ────────────────────────────────────────────────────────

  void _enterSearchMode() {
    if (!widget.enabled) return;
    _openList();
    setState(() {
      _searchMode = true;
      _keyboardHidden = false;
      _suppressExit = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _exitSearchMode() {
    _searchMode = false;
    _keyboardHidden = false;
    _closeList();
  }

  /// Wys/verberg die sleutelbord terwyl jy in soek-modus bly. Die lys bly
  /// oop en die getikte soekteks word behou.
  void _toggleKeyboard() {
    if (_focus.hasFocus) {
      _suppressExit = true;
      setState(() => _keyboardHidden = true);
      _focus.unfocus();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _suppressExit = false;
      });
    } else {
      setState(() => _keyboardHidden = false);
      _focus.requestFocus();
    }
  }

  // ─── Gedeelde oop/maak-toe logika ─────────────────────────────────────

  void _openList() {
    for (final other in _openStates.toList()) {
      if (other != this && other.mounted) {
        other._closeAll();
      }
    }
    _openStates.add(this);
    _preFocusText = null;
    if (_text.text.isNotEmpty) {
      _preFocusText = _text.text;
      _text.clear();
    }
    setState(() => _open = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollListIntoView();
      if (mounted && !_searchMode) _browseFocus.requestFocus();
    });
  }

  void _closeList() {
    if (!_open) return;
    setState(() => _open = false);
    _openStates.remove(this);
    if (widget.restoreOnBlur && _preFocusText != null) {
      _text.text = _preFocusText!;
    }
    _preFocusText = null;
  }

  void _closeAll() {
    _searchMode = false;
    _focus.unfocus();
    _browseFocus.unfocus();
    _closeList();
  }

  // ─── Hulpmiddels ───────────────────────────────────────────────────────

  void _scrollListIntoView() {
    final ctx = _listKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.15,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  List<InlineSearchableDropdownItem<T>> get _filtered {
    final q = _text.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((i) => i.label.toLowerCase().contains(q))
        .toList();
  }

  void _select(InlineSearchableDropdownItem<T> item) {
    _text.text = item.label;
    _preFocusText = null;
    widget.onChanged(item.value);
    if (widget.closeOnSelect) {
      _closeAll();
    }
  }

  void _clear() {
    _text.clear();
    _preFocusText = null;
    widget.onChanged(null);
    setState(() {});
  }

  // ─── Bou ───────────────────────────────────────────────────────────────

  Widget _buildLabel() {
    return Text(
      widget.required ? '${widget.label} *' : widget.label!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: widget.error ? AppColors.errorRed : AppColors.navy,
      ),
    );
  }

  Widget _buildOptionList() {
    return Material(
      key: _listKey,
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: _filtered.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Geen opsies nie',
                    style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final item = _filtered[index];
                  final isSelected = widget.value == item.value;
                  return ListTile(
                    dense: true,
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: AppColors.gold.withAlpha(30),
                    onTap: () => _select(item),
                  );
                },
              ),
      ),
    );
  }

  /// Blaai-modus: nie-redigeerbare veld met soek-ikoon regs.
  Widget _buildBrowseField({bool validationError = false}) {
    final displayText = _text.text.isNotEmpty ? _text.text : null;
    final showError = widget.error || validationError;

    return Focus(
      focusNode: _browseFocus,
      child: InkWell(
        onTap: widget.enabled ? _toggleList : null,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.enabled ? Colors.white : Colors.grey[200],
            hintText: widget.hint,
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.gold, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: showError ? AppColors.errorRed : Colors.grey[300]!),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            suffixIcon: widget.enabled
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.trailing != null) widget.trailing!,
                      IconButton(
                        icon: const Icon(Icons.search, size: 20),
                        onPressed: _enterSearchMode,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  )
                : widget.trailing,
          ),
          child: Text(
            displayText ?? '',
            style: TextStyle(
              color: displayText != null ? Colors.black : Colors.grey[600],
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// Soek-modus: redigeerbare veld met sleutelbord.
  Widget _buildSearchField({bool validationError = false}) {
    final showError = widget.error || validationError;
    return TextField(
      controller: _text,
      focusNode: _focus,
      enabled: widget.enabled,
      readOnly: false,
      showCursor: true,
      style: const TextStyle(fontSize: 14),
      scrollPadding: const EdgeInsets.only(bottom: 220),
      onChanged: (_) {
        setState(() {});
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollListIntoView());
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: widget.enabled ? Colors.white : Colors.grey[200],
        hintText: widget.hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: showError ? AppColors.errorRed : Colors.grey[300]!),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        suffixIcon: widget.enabled
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_text.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _clear,
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    icon: Icon(
                      _keyboardHidden ? Icons.keyboard : Icons.keyboard_hide,
                      size: 20,
                    ),
                    tooltip: _keyboardHidden
                        ? "Wys sleutelbord"
                        : "Verberg sleutelbord",
                    onPressed: _toggleKeyboard,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildField({bool validationError = false}) {
    return _searchMode
        ? _buildSearchField(validationError: validationError)
        : _buildBrowseField(validationError: validationError);
  }

  @override
  Widget build(BuildContext context) {
    final Widget control = widget.validator != null
        ? FormField<T>(
            key: widget.value != null
                ? ValueKey('${widget.label}_${widget.value}')
                : null,
            validator: widget.validator,
            initialValue: widget.value,
            builder: (state) {
              final hasError = state.hasError;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(validationError: hasError),
                  if (hasError)
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
          )
        : _buildField();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          _buildLabel(),
          const SizedBox(height: 6),
        ],
        control,
        if (_open && widget.enabled) ...[
          const SizedBox(height: 6),
          _buildOptionList(),
        ],
      ],
    );
  }
}

// ─── Kompakte oorvleuel-filter ───────────────────────────────────────────────

/// Open 'n soekbare oorvleueling, maar vir kontroles wat hul eie voorkoms
/// hou — bv. die kompakte filters in 'n blad se kopbalk. Die paneel anker
/// regs onder die toolbar.
Future<void> showSearchableDialog<T>({
  required BuildContext context,
  required String title,
  required List<InlineSearchableDropdownItem<T>> items,
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
              padding:
                  const EdgeInsets.only(top: kToolbarHeight + 4, right: 12),
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
  final List<InlineSearchableDropdownItem<T>> items;
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
  late List<InlineSearchableDropdownItem<T>> filteredItems;
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
          .where(
              (item) => item.label.toLowerCase().contains(query.toLowerCase()))
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
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy),
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
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
                      child: Text('Geen opsies nie',
                          style: TextStyle(color: Colors.grey)),
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
                            style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal),
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

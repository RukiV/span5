import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'searchable_dropdown.dart' show SearchableDropdownItem;

/// 'n Keuselys met twee modusse:
/// * **Blaai-modus** (default): 'n Nie-redigeerbare veld wat lyk soos 'n
///   teksboks. Tik om die lys oop/ toe te maak. 'n Soek-ikoon regs gee
///   toegang tot soek-modus.
/// * **Soek-modus**: 'n Regte [TextField] met sleutelbord vir filtering.
class InlineSearchableDropdown<T> extends StatefulWidget {
  final String? label;
  final String hint;
  final T? value;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  final bool enabled;
  final Widget? trailing;
  final bool required;
  final bool error;

  /// Bly die lys oop nadat 'n opsie gekies is (vir kaskades).
  final bool closeOnSelect;

  /// Herstel die oorspronklike waarde se teks wanneer die veld verloor word
  /// sonder 'n keuse.
  final bool restoreOnBlur;

  /// Vuur wanneer die veld fokus kry (slegs in soek-modus).
  final VoidCallback? onFocus;

  /// Vuur wanneer die lys oopmaak (true) of toemaak (false).
  final ValueChanged<bool>? onSearchModeChanged;

  /// Maksimum hoogte vir die opsie-lys. Laat weg (null) sodat die lys sy
  /// natuurlike hoogte kry tot `240` in plaas van 'n skuifwiel te wees.
  final double? maxHeight;

  /// Wys 'n skoonmaak-("x")-knoppie regs in die blaai-veld wanneer `true` en
  /// [onClear] verskaf is.
  final bool showClear;

  /// Vuur wanneer die skoonmaak-("x")-knoppie gedruk word.
  final VoidCallback? onClear;

  /// Ekstra knoppie heel regs in die blaai-veld (bv. die terug-knoppie van 'n
  /// kaskade-ligging-kieser).
  final Widget? browseSuffixAction;

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
    this.required = false,
    this.error = false,
    this.closeOnSelect = true,
    this.restoreOnBlur = true,
    this.onFocus,
    this.onSearchModeChanged,
    this.maxHeight,
    this.showClear = false,
    this.onClear,
    this.browseSuffixAction,
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

  void _onFocusChanged() {
    if (!mounted) return;
    if (!_searchMode) return;
    if (_focus.hasFocus) {
      widget.onFocus?.call();
    } else {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focus.hasFocus) {
          _exitSearchMode();
        }
      });
    }
  }

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

  void _toggleList() {
    if (!widget.enabled) return;
    if (_open) {
      _closeList();
    } else {
      _openList();
    }
  }

  void _enterSearchMode() {
    if (!widget.enabled) return;
    _openList();
    setState(() => _searchMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _exitSearchMode() {
    _searchMode = false;
    _closeList();
  }

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
    widget.onSearchModeChanged?.call(true);
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
    widget.onSearchModeChanged?.call(false);
  }

  void _closeAll() {
    _searchMode = false;
    _focus.unfocus();
    _browseFocus.unfocus();
    _closeList();
  }

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

  List<SearchableDropdownItem<T>> get _filtered {
    final q = _text.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((i) => i.label.toLowerCase().contains(q))
        .toList();
  }

  void _select(SearchableDropdownItem<T> item) {
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
        constraints: BoxConstraints(maxHeight: widget.maxHeight ?? 240),
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
  Widget _buildBrowseField() {
    final displayText = _text.text.isNotEmpty ? _text.text : null;

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
                  color: widget.error ? AppColors.errorRed : Colors.grey[300]!),
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
                      if (widget.showClear && widget.onClear != null)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          onPressed: widget.onClear,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Maak skoon',
                        ),
                      IconButton(
                        icon: const Icon(Icons.search, size: 20),
                        onPressed: _enterSearchMode,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (widget.browseSuffixAction != null)
                        widget.browseSuffixAction!,
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
  Widget _buildSearchField() {
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
              color: widget.error ? AppColors.errorRed : Colors.grey[300]!),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        suffixIcon: widget.enabled && _text.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: _clear,
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          _buildLabel(),
          const SizedBox(height: 6),
        ],
        _searchMode ? _buildSearchField() : _buildBrowseField(),
        if (_open && widget.enabled) ...[
          const SizedBox(height: 6),
          _buildOptionList(),
        ],
      ],
    );
  }
}
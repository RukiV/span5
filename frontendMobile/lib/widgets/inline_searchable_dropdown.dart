import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'searchable_dropdown.dart' show SearchableDropdownItem;

/// 'n Keuselys waar jy DIREK in die boks self tik om te filter — die opsie-lys
/// verskyn net onder die veld om uit te kies. Geen aparte "soek in 'n dropdown"
/// meer nie: die boks is 'n normale teksboks soos die res van die app.
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
  /// sonder 'n keuse. Skakel af vir die kaskade wat self sy vlakke terugstel.
  final bool restoreOnBlur;

  /// Vuur wanneer die veld fokus kry — bv. om 'n voltooide kaskade terug te
  /// stel na vlak 0 ("tik om te verander").
  final VoidCallback? onFocus;

  /// Vuur wanneer soek-modus begin (tweede tik) of eindig (blur). Die eerste
  /// tik blaai net deur die opsies (geen sleutelbord); 'n tweede tik op die
  /// oop veld skakel oor na soek-modus waar getik kan word om te filter.
  final ValueChanged<bool>? onSearchModeChanged;

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

  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  final GlobalKey _listKey = GlobalKey();
  bool _open = false;

  /// Teks wat voor fokus gewys is, sodat dit herstel kan word as die gebruiker
  /// weggaan sonder om te kies.
  String? _preFocusText;
  bool _pickedSinceFocus = false;

  /// Vals = blaai-modus (lees-alleen veld, geen sleutelbord); waar = soek-modus
  /// waar getik kan word om deur die opsies te filter.
  bool _searchMode = false;

  /// Merk die fokus-gebeurtenis wat deur die huidige tik veroorsaak is, sodat
  /// die eerste tik blaai en 'n tweede tik soek.
  bool _freshFocus = false;

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
  }

  @override
  void didUpdateWidget(InlineSearchableDropdown<T> old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) {
      _open = false;
      _openStates.remove(this);
      if (_searchMode) {
        _searchMode = false;
        widget.onSearchModeChanged?.call(false);
      }
      _focus.unfocus();
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
    _text.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focus.hasFocus) {
      // Maak enige ander oop dropdown toe en teken hierdie een aan.
      _freshFocus = true;
      for (final other in _openStates.toList()) {
        if (other != this && other.mounted && other._open) {
          other._focus.unfocus();
        }
      }
      _openStates.add(this);
      setState(() => _open = true);
      // "Tap om te verander": 'n bestaande waarde word gewipe sodat die volle
      // lys wys; sonder 'n keuse word die waarde op blur herstel.
      if (_text.text.isNotEmpty) {
        _preFocusText = _text.text;
        _text.clear();
      }
      widget.onFocus?.call();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollListIntoView());
    } else {
      // Vertraag sodat 'n opsie-tap eers kan afhandel.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focus.hasFocus) {
          if (_searchMode) {
            _searchMode = false;
            widget.onSearchModeChanged?.call(false);
          }
          _freshFocus = false;
          setState(() => _open = false);
          _openStates.remove(this);
          if (widget.restoreOnBlur &&
              _preFocusText != null &&
              !_pickedSinceFocus) {
            _text.text = _preFocusText!;
          }
          _preFocusText = null;
          _pickedSinceFocus = false;
        }
      });
    }
  }

  void _handleTap() {
    if (_searchMode) return;
    // Eerste tik: die fokus-gebeurtenis het die lys reeds oopgemaak — bly in
    // blaai-modus (geen sleutelbord, want die veld is lees-alleen).
    if (_freshFocus) {
      _freshFocus = false;
      return;
    }
    // Tweede tik op die oop veld: skakel oor na soek-modus en maak die
    // sleutelbord oop sodat getik kan word om te filter.
    setState(() => _searchMode = true);
    widget.onSearchModeChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
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
    _pickedSinceFocus = false;
    widget.onChanged(item.value);
    if (widget.closeOnSelect) {
      setState(() => _open = false);
      _openStates.remove(this);
      _focus.unfocus();
    }
  }

  void _clear() {
    _text.clear();
    _preFocusText = null;
    _pickedSinceFocus = false;
    widget.onChanged(null);
    setState(() {});
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
                color: AppColors.navy),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: _text,
          focusNode: _focus,
          enabled: widget.enabled,
          readOnly: !_searchMode,
          showCursor: _searchMode,
          onTap: _handleTap,
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
              borderSide: BorderSide(color: Colors.grey[300]!),
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
                : widget.trailing,
          ),
        ),
        if (_open && widget.enabled) ...[
          const SizedBox(height: 6),
          Material(
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
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: AppColors.gold.withAlpha(30),
                          onTap: () => _select(item),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

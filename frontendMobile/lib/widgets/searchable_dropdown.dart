import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Die app se enigste keuselys-widget: 'n veld wat 'n soekdialoog open waar die
/// lys lewendig filter soos jy tik.
class SearchableDropdown<T> extends StatefulWidget {
  /// Opskrif bo die veld. Laat weg vir inlyn-filters wat reeds 'n konteks het.
  final String? label;
  final String hint;
  final T? value;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  /// Wanneer vals is die veld dof en open dit nie die soekdialoog nie.
  final bool enabled;

  /// Opsionele knoppie regs in die veld (die ligging-kieser gebruik dit vir sy
  /// "terug"-knoppie).
  final Widget? trailing;

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
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
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
          Text(widget.label!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: widget.enabled ? () => _showSearchDialog(context) : null,
          child: FormField<T>(
            key: widget.value != null ? ValueKey('${widget.label}_${widget.value}') : null,
            validator: widget.validator,
            initialValue: widget.value,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: state.hasError
                          ? const Color(0xFFFFEBEE)
                          : (widget.enabled ? Colors.white : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: state.hasError ? Colors.red : Colors.grey[300]!),
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

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SearchDialog<T>(
        title: widget.label ?? widget.hint,
        items: widget.items,
        initialValue: widget.value,
        onSelected: widget.onChanged,
      ),
    );
  }
}

class SearchableDropdownItem<T> {
  final T value;
  final String label;

  const SearchableDropdownItem({required this.value, required this.label});
}

/// Open dieselfde soekdialoog as [SearchableDropdown], maar vir kontroles wat
/// hul eie voorkoms hou — bv. die kompakte filters in 'n blad se kopbalk, waar
/// 'n volle veld met raam en etiket nie inpas nie.
Future<void> showSearchableDialog<T>({
  required BuildContext context,
  required String title,
  required List<SearchableDropdownItem<T>> items,
  required ValueChanged<T?> onSelected,
  T? initialValue,
}) {
  return showDialog(
    context: context,
    builder: (context) => _SearchDialog<T>(
      title: title,
      items: items,
      initialValue: initialValue,
      onSelected: onSelected,
    ),
  );
}

class _SearchDialog<T> extends StatefulWidget {
  final String title;
  final List<SearchableDropdownItem<T>> items;
  final T? initialValue;
  final ValueChanged<T?> onSelected;

  const _SearchDialog({
    required this.title,
    required this.items,
    this.initialValue,
    required this.onSelected,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Kies ${widget.title}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: _searchController,
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
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final isSelected = item.value == widget.initialValue;
                  return ListTile(
                    title: Text(item.label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedTileColor: AppColors.gold.withAlpha(30),
                    onTap: () {
                      widget.onSelected(item.value);
                      Navigator.pop(context);
                    },
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

import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final String hint;
  final T? value;
  final List<SearchableDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.hint,
    this.value,
    required this.items,
    required this.onChanged,
    this.validator,
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
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showSearchDialog(context),
          child: FormField<T>(
            validator: widget.validator,
            initialValue: widget.value,
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
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
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
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
        title: widget.label,
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

  SearchableDropdownItem({required this.value, required this.label});
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
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

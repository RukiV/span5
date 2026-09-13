import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'column_visibility.dart';
import 'fixed_page_header.dart';
import 'selection_manager.dart';

/// Read-only view of the shared list-scaffold state handed to the page's
/// [SearchableListScaffold.content] builder so it can filter rows and render
/// selectable cards without owning that state itself.
class SearchableListState<T> {
  final String query;
  final SelectionController<T> selection;
  final ColumnVisibilityController columnVisibility;

  const SearchableListState({
    required this.query,
    required this.selection,
    required this.columnVisibility,
  });
}

/// Die gemeenskaplike raam vir al die app se soekbare lysbladsye. Die skil
/// besit die soekveld, kolom-sigbaarheid en ry-kiesing (`select mode`) en bou
/// die `FixedPageHeader` (met bulk-verwyder en kolom-kieser) plus die
/// `Scaffold`-raam. Elke bladsy voorsien die aksies, bulk-verwyder-konfigurasie
/// en die lys-inhoud via [content].
///
/// `T` is die ry-id-tipe (int vir die meeste bladsye, String vir Assets/Faults).
class SearchableListScaffold<T> extends StatefulWidget {
  final String searchHint;
  final List<ColumnDef> columns;
  final List<Widget> leadingActions;
  final bool canBulkDelete;
  final String bulkDeleteTitle;
  final String bulkDeleteMessage;
  final String? bulkDeleteChildWarning;
  final Future<void> Function(BuildContext context, Set<T> ids) onBulkDelete;
  final Widget Function(BuildContext context, SearchableListState<T> state)
      content;
  final Widget? floatingActionButton;
  final Color backgroundColor;

  /// Reken die tans-versteekte geselekteerde rye uit vir die bulk-verwyder
  /// bevestiging. Die bladsy verskaf 'n suiwer funksie van sy eie filter-staat
  /// plus die soek-query; wanneer dit `null` is word geen waarskuwing gewys nie.
  final Set<T> Function(String query)? visibleIdsProvider;

  const SearchableListScaffold({
    super.key,
    required this.searchHint,
    required this.columns,
    required this.onBulkDelete,
    required this.content,
    this.leadingActions = const [],
    this.canBulkDelete = false,
    required this.bulkDeleteTitle,
    required this.bulkDeleteMessage,
    this.bulkDeleteChildWarning,
    this.floatingActionButton,
    this.backgroundColor = AppColors.background,
    this.visibleIdsProvider,
  });

  @override
  State<SearchableListScaffold<T>> createState() =>
      _SearchableListScaffoldState<T>();
}

class _SearchableListScaffoldState<T> extends State<SearchableListScaffold<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";
  late final ColumnVisibilityController _colVis;
  late final SelectionController<T> _selection;

  @override
  void initState() {
    super.initState();
    _colVis = ColumnVisibilityController(widget.columns)
      ..addListener(_onColumnVisibilityChanged);
    _selection = SelectionController<T>()..addListener(_onSelectionChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _colVis.removeListener(_onColumnVisibilityChanged);
    _colVis.dispose();
    _selection.removeListener(_onSelectionChanged);
    _selection.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _query = _searchController.text.toLowerCase());
  }

  void _onColumnVisibilityChanged() {
    if (mounted) setState(() {});
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Column(
        children: [
          FixedPageHeader(
            controller: _searchController,
            hintText: widget.searchHint,
            actions: [
              ...widget.leadingActions,
              ColumnVisibilityButton(controller: _colVis),
            ],
          ),
          Expanded(
            child: widget.content(
              context,
              SearchableListState<T>(
                query: _query,
                selection: _selection,
                columnVisibility: _colVis,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  /// Bou die drywende aksies: wanneer [canBulkDelete] waar is, verskyn die rooi
  /// vullis-knoppie bo die bladsy se eie "nuwe"-FAB (net terwyl kies-modus met
  /// ten minste een geselekteerde ry aktief is). Dieselfde bevestiging en
  /// versteekte-ry-waarskuwing as die ou kopskrif-aksie.
  Widget? _buildFloatingActions() {
    if (!widget.canBulkDelete) return widget.floatingActionButton;

    final deleteFab = BulkDeleteFloatingAction<T>(
      controller: _selection,
      confirmTitle: widget.bulkDeleteTitle,
      confirmMessage: widget.bulkDeleteMessage
          .replaceAll('{count}', '${_selection.count}'),
      childWarning: widget.bulkDeleteChildWarning,
      hiddenSelectedCount: widget.visibleIdsProvider == null
          ? null
          : () {
              final visible = widget.visibleIdsProvider!(_query).toSet();
              return _selection.selectedIds
                  .where((id) => !visible.contains(id))
                  .length;
            },
      onDelete: (context, ids) async {
        await widget.onBulkDelete(context, ids);
        if (mounted) _selection.exit();
      },
    );

    final createFab = widget.floatingActionButton;
    final selecting = _selection.isSelecting && _selection.count > 0;
    if (createFab == null) return selecting ? deleteFab : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (selecting) deleteFab,
        if (selecting) const SizedBox(height: 12),
        createFab,
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';

/// A selection item for the SelectionSheet.
class SelectionItem<T> {
  const SelectionItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// A reusable BottomSheet for selecting from a list of options.
/// Supports search filtering and a "none" option.
class SelectionSheet<T> extends StatefulWidget {
  const SelectionSheet({
    super.key,
    required this.title,
    required this.items,
    this.selectedValue,
    this.searchHint,
    this.noneLabel,
    this.showSearch = true,
    this.icon,
    this.iconColor,
  });

  final String title;
  final List<SelectionItem<T>> items;
  final T? selectedValue;
  final String? searchHint;
  final String? noneLabel;
  final bool showSearch;
  final IconData? icon;
  final Color? iconColor;

  /// Shows the selection sheet and returns the selected value.
  /// Returns the selected value, or null if the "none" option was selected.
  /// Returns the same value (unchanged) if the sheet was dismissed.
  static Future<SelectionResult<T>?> show<T>(
    BuildContext context, {
    required String title,
    required List<SelectionItem<T>> items,
    T? selectedValue,
    String? searchHint,
    String? noneLabel,
    bool showSearch = true,
    IconData? icon,
    Color? iconColor,
  }) async {
    return showModalBottomSheet<SelectionResult<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SelectionSheet<T>(
        title: title,
        items: items,
        selectedValue: selectedValue,
        searchHint: searchHint,
        noneLabel: noneLabel,
        showSearch: showSearch,
        icon: icon,
        iconColor: iconColor,
      ),
    );
  }

  @override
  State<SelectionSheet<T>> createState() => _SelectionSheetState<T>();
}

/// Result of the selection sheet.
class SelectionResult<T> {
  const SelectionResult({this.value, this.isNone = false});

  final T? value;
  final bool isNone;

  /// Creates a result with the selected value.
  factory SelectionResult.selected(T value) => SelectionResult(value: value);

  /// Creates a result with no selection (none option).
  factory SelectionResult.none() => const SelectionResult(isNone: true);
}

class _SelectionSheetState<T> extends State<SelectionSheet<T>> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SelectionItem<T>> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    final query = _searchQuery.toLowerCase();
    return widget.items.where((item) {
      return item.label.toLowerCase().contains(query) ||
          (item.subtitle?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppDimensions.paddingL,
          right: AppDimensions.paddingL,
          top: AppDimensions.paddingL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row with title and close button
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    color: widget.iconColor ?? AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // Search field
            if (widget.showSearch && widget.items.length > 5) ...[
              const SizedBox(height: AppDimensions.paddingM),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint ?? context.l10n.coreFlutterSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ],
            const SizedBox(height: AppDimensions.paddingM),

            // Options list
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // None option
                  if (widget.noneLabel != null)
                    _SelectionTile<T>(
                      label: widget.noneLabel!,
                      isSelected: widget.selectedValue == null,
                      onTap: () => Navigator.pop(
                        context,
                        SelectionResult<T>.none(),
                      ),
                    ),

                  // Items
                  ..._filteredItems.map((item) => _SelectionTile<T>(
                        label: item.label,
                        subtitle: item.subtitle,
                        icon: item.icon,
                        isSelected: item.value == widget.selectedValue,
                        onTap: () => Navigator.pop(
                          context,
                          SelectionResult<T>.selected(item.value),
                        ),
                      )),

                  // Empty state
                  if (_filteredItems.isEmpty && _searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      child: Center(
                        child: Text(
                          context.l10n.coreFlutterNoResultsFor(_searchQuery),
                          style: const TextStyle(color: AppColors.medium),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );
  }
}

class _SelectionTile<T> extends StatelessWidget {
  const _SelectionTile({
    required this.label,
    this.subtitle,
    this.icon,
    this.isSelected = false,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon != null
          ? Icon(icon, color: isSelected ? AppColors.primary : AppColors.medium)
          : null,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : null,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: onTap,
      selected: isSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
    );
  }
}

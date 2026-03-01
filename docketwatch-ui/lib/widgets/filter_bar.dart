import 'package:flutter/material.dart';

/// A horizontal filter bar with search, dropdowns, and action buttons.
class FilterBar extends StatelessWidget {
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget> filters;
  final List<Widget> actions;

  const FilterBar({
    super.key,
    this.searchHint,
    this.onSearchChanged,
    this.filters = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          // Search field
          if (onSearchChanged != null)
            SizedBox(
              width: 280,
              child: TextField(
                decoration: InputDecoration(
                  hintText: searchHint ?? 'Search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: onSearchChanged,
              ),
            ),
          if (onSearchChanged != null) const SizedBox(width: 12),

          // Filter dropdowns
          ...filters.expand((w) => [w, const SizedBox(width: 8)]),

          const Spacer(),

          // Action buttons
          ...actions.expand((w) => [const SizedBox(width: 8), w]),
        ],
      ),
    );
  }
}

/// A dropdown filter chip.
class FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const FilterDropdown({
    super.key,
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: [
          DropdownMenuItem<T>(value: null, child: Text('All $label')),
          ...items,
        ],
        onChanged: onChanged,
      ),
    );
  }
}

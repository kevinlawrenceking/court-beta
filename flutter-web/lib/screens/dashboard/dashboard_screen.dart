import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/status_badge.dart';

/// Main dashboard screen showing all tracked cases.
/// Replaces: index.cfm + cases_ajax.cfm
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(casesProvider);
    final filter = ref.watch(caseFilterProvider);
    final selectedIds = ref.watch(selectedCaseIdsProvider);

    return Scaffold(
      body: Column(
        children: [
          // Filter bar
          FilterBar(
            searchHint: 'Search cases...',
            onSearchChanged: (query) {
              ref.read(caseFilterProvider.notifier).state =
                  filter.copyWith(query: query, page: 1);
            },
            filters: [
              // Status filter
              ToggleButtons(
                isSelected: [
                  filter.status == 'Review',
                  filter.status == 'Tracked',
                  filter.status == 'Removed',
                ],
                onPressed: (index) {
                  final statuses = ['Review', 'Tracked', 'Removed'];
                  ref.read(caseFilterProvider.notifier).state =
                      filter.copyWith(status: statuses[index], page: 1);
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
                children: const [
                  Text('Review'),
                  Text('Tracked'),
                  Text('Removed'),
                ],
              ),
            ],
            actions: [
              if (selectedIds.isNotEmpty) ...[
                Text('${selectedIds.length} selected',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _bulkUpdateStatus(ref, 'Tracked'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Track'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _bulkUpdateStatus(ref, 'Removed'),
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),

          // Cases table
          Expanded(
            child: casesAsync.when(
              data: (response) {
                if (response.data.isEmpty) {
                  return const EmptyState(
                    message: 'No cases found',
                    icon: Icons.folder_open,
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          showCheckboxColumn: true,
                          columns: const [
                            DataColumn(label: Text('Case Number')),
                            DataColumn(label: Text('Case Name')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Owner')),
                            DataColumn(label: Text('Events'), numeric: true),
                            DataColumn(label: Text('Docs'), numeric: true),
                            DataColumn(label: Text('Created')),
                          ],
                          rows: response.data.map((c) {
                            final selected = selectedIds.contains(c.id);
                            return DataRow(
                              selected: selected,
                              onSelectChanged: (val) {
                                final ids = Set<int>.from(selectedIds);
                                if (val == true) {
                                  ids.add(c.id);
                                } else {
                                  ids.remove(c.id);
                                }
                                ref.read(selectedCaseIdsProvider.notifier).state = ids;
                              },
                              cells: [
                                DataCell(
                                  Text(c.caseNumber, style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1a73e8),
                                  )),
                                  onTap: () => context.go('/cases/${c.id}'),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: Text(c.caseName, overflow: TextOverflow.ellipsis),
                                  ),
                                  onTap: () => context.go('/cases/${c.id}'),
                                ),
                                DataCell(StatusBadge(status: c.status)),
                                DataCell(Text(c.owner ?? '')),
                                DataCell(Text('${c.eventCount}')),
                                DataCell(Text('${c.docCount}')),
                                DataCell(Text(_formatDate(c.createdAt))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Pagination
                    _PaginationBar(
                      page: response.page,
                      totalPages: response.totalPages,
                      total: response.total,
                      onPageChanged: (page) {
                        ref.read(caseFilterProvider.notifier).state =
                            filter.copyWith(page: page);
                      },
                    ),
                  ],
                );
              },
              loading: () => const LoadingState(message: 'Loading cases...'),
              error: (err, _) => ErrorState(
                message: 'Failed to load cases: $err',
                onRetry: () => ref.invalidate(casesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkUpdateStatus(WidgetRef ref, String status) async {
    final ids = ref.read(selectedCaseIdsProvider);
    if (ids.isEmpty) return;

    try {
      await ref.read(apiClientProvider).bulkUpdateCaseStatus(ids.toList(), status);
      ref.read(selectedCaseIdsProvider.notifier).state = {};
      ref.invalidate(casesProvider);
    } catch (e) {
      debugPrint('Bulk update failed: $e');
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final ValueChanged<int> onPageChanged;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$total total cases', style: const TextStyle(fontSize: 13)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
              ),
              Text('Page $page of $totalPages', style: const TextStyle(fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

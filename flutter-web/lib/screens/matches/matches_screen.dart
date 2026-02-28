import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/status_badge.dart';

/// Celebrity-case matches table with filtering and status management.
/// Replaces: case_matches.cfm + case_matches_ajax.cfm
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Text('Celebrity Matches',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          Expanded(
            child: matchesAsync.when(
              data: (response) {
                if (response.data.isEmpty) {
                  return const EmptyState(
                    message: 'No celebrity matches found',
                    icon: Icons.link_off,
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Celebrity')),
                      DataColumn(label: Text('Case ID'), numeric: true),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Score'), numeric: true),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: response.data.map((m) {
                      return DataRow(cells: [
                        DataCell(Text(m.celebrityName ?? 'Celebrity #${m.celebrityId}')),
                        DataCell(Text('${m.caseId}')),
                        DataCell(StatusBadge(status: m.matchStatus)),
                        DataCell(Text(m.matchScore?.toStringAsFixed(1) ?? '-')),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, size: 18),
                              tooltip: 'Verify',
                              onPressed: () async {
                                await ref.read(apiClientProvider)
                                    .updateMatchStatus(m.id, 'Verified');
                                ref.invalidate(matchesProvider);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Reject',
                              onPressed: () async {
                                await ref.read(apiClientProvider)
                                    .updateMatchStatus(m.id, 'Rejected');
                                ref.invalidate(matchesProvider);
                              },
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                );
              },
              loading: () => const LoadingState(message: 'Loading matches...'),
              error: (err, _) => ErrorState(
                message: '$err',
                onRetry: () => ref.invalidate(matchesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';

/// Provider for error logs from the admin API.
final _errorLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getErrorLogs(limit: 200);
});

/// Error log viewer with filtering by severity.
/// Replaces: error_log.cfm
class ErrorLogScreen extends ConsumerStatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  ConsumerState<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends ConsumerState<ErrorLogScreen> {
  String _severityFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(_errorLogsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Error Log', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),

            // Filters
            Row(
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search errors...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'error', label: Text('Errors')),
                    ButtonSegment(
                        value: 'warning', label: Text('Warnings')),
                    ButtonSegment(value: 'info', label: Text('Info')),
                  ],
                  selected: {_severityFilter},
                  onSelectionChanged: (s) =>
                      setState(() => _severityFilter = s.first),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _resolveAll(logsAsync),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Clear Resolved'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(_errorLogsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error logs list
            Expanded(
              child: logsAsync.when(
                data: (logs) {
                  final query = _searchController.text.toLowerCase();
                  final filtered = logs.where((log) {
                    final severity = log['severity'] as String? ?? '';
                    final message = (log['message'] as String? ?? '')
                        .toLowerCase();
                    final script = (log['script_name'] as String? ?? '')
                        .toLowerCase();

                    if (_severityFilter != 'all' &&
                        severity != _severityFilter) {
                      return false;
                    }
                    if (query.isNotEmpty &&
                        !message.contains(query) &&
                        !script.contains(query)) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green.shade400),
                          const SizedBox(height: 16),
                          Text('No errors found',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'System errors and warnings will appear here.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final log = filtered[i];
                      final severity =
                          log['severity'] as String? ?? 'error';
                      final resolved =
                          log['resolved'] as bool? ?? false;
                      final createdAt =
                          log['created_at'] as String?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: _severityIcon(severity),
                          title: Text(
                            log['message'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${log['script_name'] ?? ''}'
                            '${createdAt != null ? ' | ${_formatDateTime(DateTime.parse(createdAt))}' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: resolved
                              ? const Chip(
                                  label: Text('Resolved'),
                                  visualDensity:
                                      VisualDensity.compact,
                                )
                              : TextButton(
                                  onPressed: () =>
                                      _resolveError(log['id'] as int),
                                  child: const Text('Resolve'),
                                ),
                          isThreeLine: log['detail'] != null &&
                              (log['detail'] as String).isNotEmpty,
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingState(
                    message: 'Loading error logs...'),
                error: (err, _) => ErrorState(
                  message: '$err',
                  onRetry: () => ref.invalidate(_errorLogsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _severityIcon(String severity) {
    switch (severity) {
      case 'error':
        return const Icon(Icons.error, color: Colors.red, size: 24);
      case 'warning':
        return const Icon(Icons.warning, color: Colors.orange, size: 24);
      default:
        return const Icon(Icons.info, color: Colors.blue, size: 24);
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _resolveError(int id) async {
    await ref.read(apiClientProvider).resolveErrors([id]);
    ref.invalidate(_errorLogsProvider);
  }

  void _resolveAll(AsyncValue<List<Map<String, dynamic>>> logsAsync) {
    logsAsync.whenData((logs) async {
      final unresolvedIds = logs
          .where((l) => l['resolved'] != true)
          .map((l) => l['id'] as int)
          .toList();
      if (unresolvedIds.isEmpty) return;
      await ref.read(apiClientProvider).resolveErrors(unresolvedIds);
      ref.invalidate(_errorLogsProvider);
    });
  }
}

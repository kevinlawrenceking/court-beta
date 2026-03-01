import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';

/// Provider for task log data from the admin API.
final _taskLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getTaskLogs(limit: 100);
});

/// Scheduled task execution history viewer.
/// Replaces: scheduled_task_log.cfm + scheduled_tasks.cfm
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _taskFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(_taskLogsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Scheduled Tasks',
                    style: theme.textTheme.headlineSmall),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(_taskLogsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter chips
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _taskFilter == 'all',
                  onSelected: (_) => setState(() => _taskFilter = 'all'),
                ),
                FilterChip(
                  label: const Text('Success'),
                  selected: _taskFilter == 'success',
                  onSelected: (_) =>
                      setState(() => _taskFilter = 'success'),
                ),
                FilterChip(
                  label: const Text('Failed'),
                  selected: _taskFilter == 'failed',
                  onSelected: (_) =>
                      setState(() => _taskFilter = 'failed'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Task logs
            Expanded(
              child: logsAsync.when(
                data: (logs) {
                  final filtered = _taskFilter == 'all'
                      ? logs
                      : logs
                          .where((l) => l['status'] == _taskFilter)
                          .toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      message: 'No task logs found',
                      icon: Icons.task_alt,
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final task = filtered[index];
                      final status = task['status'] as String? ?? '';
                      final taskName = task['task_name'] as String? ?? '';
                      final durationMs = task['duration_ms'] as int? ?? 0;
                      final startedAt = task['started_at'] as String?;
                      final errorMsg = task['error_message'] as String?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _statusIcon(status),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(taskName,
                                        style: theme.textTheme.titleSmall),
                                    if (errorMsg != null &&
                                        errorMsg.isNotEmpty)
                                      Text(
                                        errorMsg,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.error,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  startedAt != null
                                      ? _formatDateTime(
                                          DateTime.parse(startedAt))
                                      : '-',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  _formatDuration(durationMs),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const LoadingState(message: 'Loading task logs...'),
                error: (err, _) => ErrorState(
                  message: '$err',
                  onRetry: () => ref.invalidate(_taskLogsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'success':
        return const Icon(Icons.check_circle,
            color: Colors.green, size: 24);
      case 'running':
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case 'failed':
        return const Icon(Icons.error, color: Colors.red, size: 24);
      default:
        return const Icon(Icons.circle_outlined,
            color: Colors.grey, size: 24);
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    final secs = ms / 1000;
    if (secs < 60) return '${secs.toStringAsFixed(1)}s';
    final mins = (secs / 60).floor();
    return '${mins}m ${(secs % 60).toStringAsFixed(0)}s';
  }
}

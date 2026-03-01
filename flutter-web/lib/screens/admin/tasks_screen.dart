import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scheduled task execution history viewer.
/// Replaces: scheduled_task_log.cfm + scheduled_tasks.cfm
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _taskFilter = 'all';

  // Placeholder tasks - replace with GET /api/admin/tasks
  final List<_TaskEntry> _tasks = [
    _TaskEntry(
      name: 'RSS Poller',
      description: 'Polls PACER RSS feeds for new case events',
      interval: 'Every 5 minutes',
      lastRun: DateTime.now().subtract(const Duration(minutes: 3)),
      status: 'success',
      duration: const Duration(seconds: 12),
    ),
    _TaskEntry(
      name: 'Celebrity Matcher',
      description: 'Matches case parties against celebrity database',
      interval: 'Every 15 minutes',
      lastRun: DateTime.now().subtract(const Duration(minutes: 8)),
      status: 'success',
      duration: const Duration(seconds: 45),
    ),
    _TaskEntry(
      name: 'Cleanup Worker',
      description: 'Removes orphaned documents and old error logs',
      interval: 'Daily at 3:00 AM',
      lastRun: DateTime.now().subtract(const Duration(hours: 21)),
      status: 'success',
      duration: const Duration(minutes: 2, seconds: 30),
    ),
    _TaskEntry(
      name: 'Email Notifier',
      description: 'Sends notification emails for new case events',
      interval: 'Every 5 minutes',
      lastRun: DateTime.now().subtract(const Duration(minutes: 4)),
      status: 'warning',
      duration: const Duration(seconds: 8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  onPressed: () => setState(() {}),
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
                  onSelected: (_) =>
                      setState(() => _taskFilter = 'all'),
                ),
                FilterChip(
                  label: const Text('Running'),
                  selected: _taskFilter == 'running',
                  onSelected: (_) =>
                      setState(() => _taskFilter = 'running'),
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

            // Tasks table
            Expanded(
              child: ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Status icon
                          _statusIcon(task.status),
                          const SizedBox(width: 16),

                          // Task info
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(task.name,
                                    style:
                                        theme.textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(task.description,
                                    style:
                                        theme.textTheme.bodySmall),
                              ],
                            ),
                          ),

                          // Interval
                          Expanded(
                            child: Text(task.interval,
                                style: theme.textTheme.bodySmall),
                          ),

                          // Last run
                          Expanded(
                            child: Text(
                              _timeAgo(task.lastRun),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),

                          // Duration
                          SizedBox(
                            width: 80,
                            child: Text(
                              _formatDuration(task.duration),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),

                          // Actions
                          IconButton(
                            icon: const Icon(Icons.play_arrow,
                                size: 20),
                            tooltip: 'Run now',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
      case 'warning':
        return const Icon(Icons.warning, color: Colors.orange, size: 24);
      default:
        return const Icon(Icons.circle_outlined,
            color: Colors.grey, size: 24);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    return '${d.inSeconds}s';
  }
}

class _TaskEntry {
  final String name;
  final String description;
  final String interval;
  final DateTime lastRun;
  final String status;
  final Duration duration;

  _TaskEntry({
    required this.name,
    required this.description,
    required this.interval,
    required this.lastRun,
    required this.status,
    required this.duration,
  });
}

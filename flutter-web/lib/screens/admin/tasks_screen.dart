import 'package:flutter/material.dart';

/// Scheduled task execution history viewer.
/// Replaces: scheduled_task_log.cfm + scheduled_tasks.cfm
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scheduled Tasks', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            // TODO: Fetch from GET /api/admin/tasks with task name filtering
            const Expanded(
              child: Center(
                child: Text('Task history viewer - integrate with admin tasks API'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

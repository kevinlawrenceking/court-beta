import 'package:flutter/material.dart';

/// Error log viewer with filtering by date, severity, and script.
/// Replaces: error_log.cfm
class ErrorLogScreen extends StatelessWidget {
  const ErrorLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Error Log', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            // TODO: Fetch from GET /api/admin/errors with filtering
            const Expanded(
              child: Center(
                child: Text('Error log viewer - integrate with admin errors API'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

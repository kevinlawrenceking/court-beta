import 'package:flutter/material.dart';

/// Tool management screen for PACER, UniCourt, etc.
/// Replaces: tools.cfm + tool_update.cfm + save_tool.cfm
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data Source Tools', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            // TODO: Fetch from GET /api/reference/tools with CRUD operations
            const Expanded(
              child: Center(
                child: Text('Tool management - integrate with tools API'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

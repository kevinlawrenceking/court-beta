import 'package:flutter/material.dart';

/// DAMZ headlines review and editing screen.
/// Replaces: damz_headlines.cfm
class HeadlinesScreen extends StatelessWidget {
  const HeadlinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Headlines', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            // TODO: Fetch from GET /api/headlines and display with edit capability
            const Expanded(
              child: Center(
                child: Text('Headlines review - integrate with headlines API endpoint'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

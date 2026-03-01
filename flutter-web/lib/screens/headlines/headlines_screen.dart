import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DAMZ headlines review and editing screen.
/// Replaces: damz_headlines.cfm
class HeadlinesScreen extends ConsumerStatefulWidget {
  const HeadlinesScreen({super.key});

  @override
  ConsumerState<HeadlinesScreen> createState() => _HeadlinesScreenState();
}

class _HeadlinesScreenState extends ConsumerState<HeadlinesScreen> {
  String _statusFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('Headlines', style: theme.textTheme.headlineSmall),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Article'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters
            Row(
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search headlines...',
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
                    ButtonSegment(value: 'draft', label: Text('Drafts')),
                    ButtonSegment(value: 'review', label: Text('In Review')),
                    ButtonSegment(
                        value: 'published', label: Text('Published')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (s) =>
                      setState(() => _statusFilter = s.first),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Empty state - replace with API data
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.article_outlined,
                        size: 64, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('No articles yet',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Articles generated from case summaries will appear here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

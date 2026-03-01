import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';

/// Provider for articles from the admin API.
final _articlesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getArticles(limit: 100);
});

/// DAMZ headlines review and editing screen.
/// Replaces: damz_headlines.cfm
class HeadlinesScreen extends ConsumerStatefulWidget {
  const HeadlinesScreen({super.key});

  @override
  ConsumerState<HeadlinesScreen> createState() => _HeadlinesScreenState();
}

class _HeadlinesScreenState extends ConsumerState<HeadlinesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articlesAsync = ref.watch(_articlesProvider);

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
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(_articlesProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search
            SizedBox(
              width: 400,
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
            const SizedBox(height: 16),

            // Articles list
            Expanded(
              child: articlesAsync.when(
                data: (articles) {
                  final query = _searchController.text.toLowerCase();
                  final filtered = query.isEmpty
                      ? articles
                      : articles.where((a) {
                          final headline =
                              (a['headline'] as String? ?? '')
                                  .toLowerCase();
                          final subhead =
                              (a['subhead'] as String? ?? '')
                                  .toLowerCase();
                          return headline.contains(query) ||
                              subhead.contains(query);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined,
                              size: 64,
                              color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No articles yet',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Articles generated from case summaries will appear here.',
                            style:
                                theme.textTheme.bodyMedium?.copyWith(
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
                      final article = filtered[i];
                      final createdAt =
                          article['created_at'] as String?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                article['headline'] as String? ??
                                    '',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(
                                        fontWeight:
                                            FontWeight.w600),
                              ),
                              if ((article['subhead'] as String? ??
                                      '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  article['subhead'] as String,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: theme.colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (article['model_name'] != null)
                                    Chip(
                                      label: Text(
                                          article['model_name']
                                              as String),
                                      visualDensity:
                                          VisualDensity.compact,
                                    ),
                                  const Spacer(),
                                  if (createdAt != null)
                                    Text(
                                      _formatDateTime(
                                          DateTime.parse(createdAt)),
                                      style:
                                          theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingState(
                    message: 'Loading articles...'),
                error: (err, _) => ErrorState(
                  message: '$err',
                  onRetry: () => ref.invalidate(_articlesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/loading_state.dart';

/// Celebrity gallery with cards and filtering.
/// Replaces: celebrity_gallery.cfm + celeb_gallery_ajax.cfm
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebsAsync = ref.watch(celebritiesProvider);

    return Scaffold(
      body: Column(
        children: [
          FilterBar(
            searchHint: 'Search celebrities...',
            onSearchChanged: (query) {
              // TODO: Update celebrity filter provider
            },
            actions: [
              FilledButton.icon(
                onPressed: () {
                  // TODO: Open add celebrity dialog
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Celebrity'),
              ),
            ],
          ),
          Expanded(
            child: celebsAsync.when(
              data: (response) {
                if (response.data.isEmpty) {
                  return const EmptyState(message: 'No celebrities found');
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: response.data.length,
                  itemBuilder: (context, i) {
                    final celeb = response.data[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go('/celebrities/${celeb.id}'),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.grey[200],
                                child: celeb.imageUrl != null
                                    ? Image.network(
                                        celeb.imageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.person, size: 48),
                                      )
                                    : const Center(
                                        child: Icon(Icons.person, size: 48, color: Colors.grey),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Text(
                                    celeb.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${celeb.caseCount} cases',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (celeb.verified)
                                    const Icon(Icons.verified, size: 14, color: Colors.blue),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingState(message: 'Loading celebrities...'),
              error: (err, _) => ErrorState(
                message: '$err',
                onRetry: () => ref.invalidate(celebritiesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

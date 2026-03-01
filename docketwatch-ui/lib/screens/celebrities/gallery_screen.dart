import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/loading_state.dart';

/// Celebrity gallery with cards and filtering.
/// Replaces: celebrity_gallery.cfm + celeb_gallery_ajax.cfm
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  String _searchQuery = '';
  bool? _verifiedFilter;

  @override
  Widget build(BuildContext context) {
    final celebsAsync = ref.watch(celebritiesProvider);

    return Scaffold(
      body: Column(
        children: [
          FilterBar(
            searchHint: 'Search celebrities...',
            onSearchChanged: (query) {
              setState(() => _searchQuery = query.toLowerCase());
            },
            filters: [
              FilterDropdown<bool>(
                label: 'Status',
                value: _verifiedFilter,
                items: const [
                  DropdownMenuItem(value: true, child: Text('Verified')),
                  DropdownMenuItem(value: false, child: Text('Unverified')),
                ],
                onChanged: (v) => setState(() => _verifiedFilter = v),
              ),
            ],
            actions: [
              FilledButton.icon(
                onPressed: () => _showAddCelebrityDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Celebrity'),
              ),
            ],
          ),
          Expanded(
            child: celebsAsync.when(
              data: (response) {
                final filtered = response.data.where((c) {
                  if (_searchQuery.isNotEmpty &&
                      !c.name.toLowerCase().contains(_searchQuery)) {
                    return false;
                  }
                  if (_verifiedFilter != null &&
                      c.verified != _verifiedFilter) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    message: 'No celebrities found',
                    icon: Icons.person_search,
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final celeb = filtered[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            context.go('/celebrities/${celeb.id}'),
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
                                            const Icon(Icons.person,
                                                size: 48),
                                      )
                                    : const Center(
                                        child: Icon(Icons.person,
                                            size: 48,
                                            color: Colors.grey),
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
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${celeb.caseCount} cases',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      if (celeb.verified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified,
                                            size: 14,
                                            color: Colors.blue),
                                      ],
                                    ],
                                  ),
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
              loading: () =>
                  const LoadingState(message: 'Loading celebrities...'),
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

  void _showAddCelebrityDialog(BuildContext context) {
    final nameController = TextEditingController();
    final tmzIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Celebrity'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Celebrity Name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tmzIdController,
                decoration: const InputDecoration(
                  labelText: 'TMZ Celeb ID (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final data = <String, dynamic>{'name': name};
              final tmzId = int.tryParse(tmzIdController.text.trim());
              if (tmzId != null) data['tmz_celeb_id'] = tmzId;

              await ref.read(apiClientProvider).createCelebrity(data);
              ref.invalidate(celebritiesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

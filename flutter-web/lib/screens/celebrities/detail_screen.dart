import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/status_badge.dart';

/// Provider that fetches matches for a specific celebrity.
final _celebrityMatchesProvider = FutureProvider.autoDispose
    .family<List<dynamic>, int>((ref, celebrityId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getMatches(celebrityId: celebrityId, perPage: 100);
  return response.data;
});

/// Individual celebrity profile with linked cases.
/// Replaces: celebrity_details.cfm
class CelebrityDetailScreen extends ConsumerWidget {
  final int celebrityId;

  const CelebrityDetailScreen({super.key, required this.celebrityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebAsync = ref.watch(celebrityDetailProvider(celebrityId));
    final matchesAsync = ref.watch(_celebrityMatchesProvider(celebrityId));

    return celebAsync.when(
      data: (celeb) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: celeb.imageUrl != null
                        ? NetworkImage(celeb.imageUrl!)
                        : null,
                    child: celeb.imageUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(celeb.name,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            if (celeb.verified)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child:
                                    Icon(Icons.verified, color: Colors.blue),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${celeb.caseCount} linked cases',
                            style: Theme.of(context).textTheme.bodyMedium),
                        if (celeb.tmzCelebId != null)
                          Text('TMZ ID: ${celeb.tmzCelebId}',
                              style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/celebrities'),
                    tooltip: 'Back to gallery',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Linked Cases',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),

              // Linked cases list
              Expanded(
                child: matchesAsync.when(
                  data: (matches) {
                    if (matches.isEmpty) {
                      return const EmptyState(
                        message: 'No cases linked to this celebrity',
                        icon: Icons.link_off,
                      );
                    }

                    return ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final match = matches[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _matchStatusColor(
                                  match.matchStatus),
                              child: Icon(
                                _matchStatusIcon(match.matchStatus),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            title: Text('Case #${match.caseId}'),
                            subtitle: Text(
                              'Status: ${match.matchStatus}'
                              '${match.matchScore != null ? " | Score: ${(match.matchScore! * 100).toStringAsFixed(0)}%" : ""}'
                              '${match.matchedBy != null ? " | By: ${match.matchedBy}" : ""}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.go('/cases/${match.caseId}'),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingState(
                      message: 'Loading linked cases...'),
                  error: (err, _) => ErrorState(
                    message: '$err',
                    onRetry: () => ref
                        .invalidate(_celebrityMatchesProvider(celebrityId)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Scaffold(body: LoadingState()),
      error: (err, _) => Scaffold(
        body: ErrorState(
          message: '$err',
          onRetry: () =>
              ref.invalidate(celebrityDetailProvider(celebrityId)),
        ),
      ),
    );
  }

  Color _matchStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _matchStatusIcon(String status) {
    switch (status) {
      case 'Confirmed':
        return Icons.check;
      case 'Rejected':
        return Icons.close;
      default:
        return Icons.help_outline;
    }
  }
}

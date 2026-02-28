import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';

/// Individual celebrity profile with linked cases.
/// Replaces: celebrity_details.cfm
class CelebrityDetailScreen extends ConsumerWidget {
  final int celebrityId;

  const CelebrityDetailScreen({super.key, required this.celebrityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celebAsync = ref.watch(celebrityDetailProvider(celebrityId));

    return celebAsync.when(
      data: (celeb) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        celeb.imageUrl != null ? NetworkImage(celeb.imageUrl!) : null,
                    child: celeb.imageUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(celeb.name,
                              style: Theme.of(context).textTheme.headlineSmall),
                          if (celeb.verified)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.verified, color: Colors.blue),
                            ),
                        ],
                      ),
                      Text('${celeb.caseCount} linked cases',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Linked Cases',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // TODO: Load and display linked cases for this celebrity
              const Expanded(
                child: EmptyState(
                  message: 'Case links will appear here',
                  icon: Icons.link,
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Scaffold(body: LoadingState()),
      error: (err, _) => Scaffold(
        body: ErrorState(message: '$err',
            onRetry: () => ref.invalidate(celebrityDetailProvider(celebrityId))),
      ),
    );
  }
}

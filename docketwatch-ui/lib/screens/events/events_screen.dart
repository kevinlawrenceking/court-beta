import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';

/// Alert dashboard for unacknowledged court events.
/// Replaces: case_events.cfm
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(unacknowledgedEventsProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Text('Court Event Alerts',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(unacknowledgedEventsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),

          // Event list
          Expanded(
            child: eventsAsync.when(
              data: (response) {
                if (response.data.isEmpty) {
                  return const EmptyState(
                    message: 'No unacknowledged events',
                    icon: Icons.check_circle_outline,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: response.data.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final event = response.data[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Event type icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: event.storyworthy
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                event.isDoc ? Icons.description : Icons.gavel,
                                size: 24,
                                color: event.storyworthy ? Colors.amber[800] : Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Event details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Case name link
                                  if (event.caseName != null)
                                    InkWell(
                                      onTap: () => context.go('/cases/${event.caseId}'),
                                      child: Text(
                                        '${event.caseNumber ?? ''} - ${event.caseName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1a73e8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.eventDescription,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  if (event.summaryHtml != null)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        event.summaryHtml!,
                                        style: const TextStyle(fontSize: 12),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.eventDate != null
                                        ? 'Event date: ${event.eventDate!.month}/${event.eventDate!.day}/${event.eventDate!.year}'
                                        : '',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),

                            // Acknowledge button
                            FilledButton.tonal(
                              onPressed: () async {
                                await ref.read(apiClientProvider).acknowledgeEvent(event.id);
                                ref.invalidate(unacknowledgedEventsProvider);
                              },
                              child: const Text('Acknowledge'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingState(message: 'Loading events...'),
              error: (err, _) => ErrorState(
                message: 'Failed to load events: $err',
                onRetry: () => ref.invalidate(unacknowledgedEventsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

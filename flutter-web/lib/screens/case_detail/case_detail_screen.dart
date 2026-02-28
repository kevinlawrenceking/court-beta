import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/status_badge.dart';

/// Full case detail view with tabs for events, documents, celebrities, subscribers.
/// Replaces: case_details.cfm
class CaseDetailScreen extends ConsumerWidget {
  final int caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseAsync = ref.watch(caseDetailProvider(caseId));
    final eventsAsync = ref.watch(caseEventsProvider(caseId));

    return caseAsync.when(
      data: (caseData) => DefaultTabController(
        length: 4,
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                caseData.caseNumber,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              StatusBadge(status: caseData.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            caseData.caseName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (caseData.owner != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Owner: ${caseData.owner}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Actions
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Open edit dialog
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(apiClientProvider).subscribeToCaseAlerts(caseId);
                          },
                          icon: const Icon(Icons.notifications_active, size: 16),
                          label: const Text('Subscribe'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tabs
              const TabBar(
                tabs: [
                  Tab(text: 'Events'),
                  Tab(text: 'Documents'),
                  Tab(text: 'Celebrities'),
                  Tab(text: 'Subscribers'),
                ],
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    // Events tab
                    eventsAsync.when(
                      data: (response) {
                        if (response.data.isEmpty) {
                          return const EmptyState(
                            message: 'No events yet',
                            icon: Icons.event_note,
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: response.data.length,
                          itemBuilder: (context, i) {
                            final event = response.data[i];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  event.isDoc ? Icons.description : Icons.event,
                                  color: event.acknowledged
                                      ? Colors.grey
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  event.eventDescription,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  event.eventDate != null
                                      ? '${event.eventDate!.month}/${event.eventDate!.day}/${event.eventDate!.year}'
                                      : 'No date',
                                ),
                                trailing: event.acknowledged
                                    ? Chip(
                                        label: Text('Ack by ${event.acknowledgedBy ?? ""}'),
                                        visualDensity: VisualDensity.compact,
                                      )
                                    : FilledButton.tonal(
                                        onPressed: () async {
                                          await ref.read(apiClientProvider)
                                              .acknowledgeEvent(event.id);
                                          ref.invalidate(caseEventsProvider(caseId));
                                        },
                                        child: const Text('Acknowledge'),
                                      ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const LoadingState(),
                      error: (err, _) => ErrorState(message: '$err'),
                    ),

                    // Documents tab (placeholder)
                    const EmptyState(
                      message: 'Documents will appear here',
                      icon: Icons.picture_as_pdf,
                    ),

                    // Celebrities tab (placeholder)
                    const EmptyState(
                      message: 'Linked celebrities will appear here',
                      icon: Icons.star,
                    ),

                    // Subscribers tab (placeholder)
                    const EmptyState(
                      message: 'Email subscribers will appear here',
                      icon: Icons.email,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Scaffold(body: LoadingState(message: 'Loading case...')),
      error: (err, _) => Scaffold(
        body: ErrorState(
          message: 'Failed to load case: $err',
          onRetry: () => ref.invalidate(caseDetailProvider(caseId)),
        ),
      ),
    );
  }
}

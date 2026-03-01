import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/case_model.dart';
import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/status_badge.dart';

/// Provider for matches linked to a specific case.
final _caseMatchesProvider = FutureProvider.autoDispose
    .family<List<CelebrityMatchModel>, int>((ref, caseId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.getMatches(caseId: caseId, perPage: 100);
  return response.data;
});

/// Full case detail view with tabs for events, documents, celebrities, subscribers.
/// Replaces: case_details.cfm
class CaseDetailScreen extends ConsumerWidget {
  final int caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseAsync = ref.watch(caseDetailProvider(caseId));
    final eventsAsync = ref.watch(caseEventsProvider(caseId));
    final matchesAsync = ref.watch(_caseMatchesProvider(caseId));

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
                    bottom:
                        BorderSide(color: Theme.of(context).dividerColor),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 12),
                              StatusBadge(status: caseData.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            caseData.caseName,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                          if (caseData.owner != null) ...[
                            const SizedBox(height: 4),
                            Text('Owner: ${caseData.owner}',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    // Actions
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showEditDialog(context, ref, caseData),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(apiClientProvider)
                                .subscribeToCaseAlerts(caseId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Subscribed to alerts')),
                              );
                            }
                          },
                          icon: const Icon(Icons.notifications_active,
                              size: 16),
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
                    _buildEventsTab(context, ref, eventsAsync),

                    // Documents tab
                    _buildDocumentsTab(context, ref, caseData),

                    // Celebrities tab
                    _buildCelebritiesTab(context, ref, matchesAsync),

                    // Subscribers tab
                    _buildSubscribersTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () =>
          const Scaffold(body: LoadingState(message: 'Loading case...')),
      error: (err, _) => Scaffold(
        body: ErrorState(
          message: 'Failed to load case: $err',
          onRetry: () => ref.invalidate(caseDetailProvider(caseId)),
        ),
      ),
    );
  }

  Widget _buildEventsTab(
      BuildContext context, WidgetRef ref, AsyncValue eventsAsync) {
    return eventsAsync.when(
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
                        label: Text(
                            'Ack by ${event.acknowledgedBy ?? ""}'),
                        visualDensity: VisualDensity.compact,
                      )
                    : FilledButton.tonal(
                        onPressed: () async {
                          await ref
                              .read(apiClientProvider)
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
    );
  }

  Widget _buildDocumentsTab(
      BuildContext context, WidgetRef ref, CaseModel caseData) {
    if (caseData.docCount == 0) {
      return const EmptyState(
        message: 'No documents attached to this case',
        icon: Icons.picture_as_pdf,
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf,
              size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('${caseData.docCount} documents',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Documents are loaded from the Events tab when an event has an attached document.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCelebritiesTab(
      BuildContext context, WidgetRef ref, AsyncValue matchesAsync) {
    return matchesAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const EmptyState(
            message: 'No celebrities linked to this case',
            icon: Icons.star,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, i) {
            final match = matches[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: match.celebrityImageUrl != null
                      ? NetworkImage(match.celebrityImageUrl!)
                      : null,
                  child: match.celebrityImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(match.celebrityName ?? 'Celebrity #${match.celebrityId}'),
                subtitle: Text(
                  'Match: ${match.matchStatus}'
                  '${match.matchScore != null ? " (${(match.matchScore! * 100).toStringAsFixed(0)}%)" : ""}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'confirm') {
                      await ref
                          .read(apiClientProvider)
                          .updateMatchStatus(match.id, 'Confirmed');
                    } else if (value == 'reject') {
                      await ref
                          .read(apiClientProvider)
                          .updateMatchStatus(match.id, 'Rejected');
                    } else if (value == 'remove') {
                      await ref
                          .read(apiClientProvider)
                          .deleteMatch(match.id);
                    }
                    ref.invalidate(_caseMatchesProvider(caseId));
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'confirm', child: Text('Confirm Match')),
                    const PopupMenuItem(
                        value: 'reject', child: Text('Reject Match')),
                    const PopupMenuItem(
                        value: 'remove', child: Text('Remove')),
                  ],
                ),
                onTap: () =>
                    context.go('/celebrities/${match.celebrityId}'),
              ),
            );
          },
        );
      },
      loading: () => const LoadingState(message: 'Loading celebrities...'),
      error: (err, _) => ErrorState(
        message: '$err',
        onRetry: () => ref.invalidate(_caseMatchesProvider(caseId)),
      ),
    );
  }

  Widget _buildSubscribersTab(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.email,
              size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Email Subscribers',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Use the Subscribe button above to receive email notifications for this case.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, CaseModel caseData) {
    final nameController =
        TextEditingController(text: caseData.caseName);
    final numberController =
        TextEditingController(text: caseData.caseNumber);
    final ownerController =
        TextEditingController(text: caseData.owner ?? '');
    String selectedStatus = caseData.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Case'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberController,
                  decoration:
                      const InputDecoration(labelText: 'Case Number'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Case Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ownerController,
                  decoration:
                      const InputDecoration(labelText: 'Owner'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration:
                      const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Review', child: Text('Review')),
                    DropdownMenuItem(
                        value: 'Tracked', child: Text('Tracked')),
                    DropdownMenuItem(
                        value: 'Filed', child: Text('Filed')),
                    DropdownMenuItem(
                        value: 'Closed', child: Text('Closed')),
                    DropdownMenuItem(
                        value: 'Removed', child: Text('Removed')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedStatus = v);
                    }
                  },
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
                await ref.read(apiClientProvider).updateCase(caseId, {
                  'case_number': numberController.text.trim(),
                  'case_name': nameController.text.trim(),
                  'owner': ownerController.text.trim(),
                  'status': selectedStatus,
                });
                ref.invalidate(caseDetailProvider(caseId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/loading_state.dart';

/// Real-time legal activity monitor with dark theme.
/// Replaces: docketwatch_monitor.cfm + docketwatch_monitor_data.cfm
class MonitorScreen extends ConsumerStatefulWidget {
  const MonitorScreen({super.key});

  @override
  ConsumerState<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends ConsumerState<MonitorScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.invalidate(monitorEventsProvider),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(monitorEventsProvider);

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.monitor_heart, color: Colors.red),
              SizedBox(width: 8),
              Text('Live Monitor'),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E1E),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(monitorEventsProvider),
            ),
          ],
        ),
        body: eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return const Center(
                child: Text('No recent activity',
                    style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final event = events[i];
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: _buildStatusIcon(event.acknowledged, event.storyworthy),
                    title: Text(
                      event.eventDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      event.caseName ?? 'Case #${event.caseId}',
                      style: TextStyle(
                        color: Colors.blue[300],
                        fontSize: 12,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _timeAgo(event.createdAt),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        if (!event.acknowledged)
                          TextButton(
                            onPressed: () async {
                              await ref.read(apiClientProvider)
                                  .acknowledgeEvent(event.id);
                              ref.invalidate(monitorEventsProvider);
                            },
                            child: const Text('ACK', style: TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                    onTap: () => context.go('/cases/${event.caseId}'),
                  ),
                );
              },
            );
          },
          loading: () => const LoadingState(message: 'Loading feed...'),
          error: (err, _) => ErrorState(
            message: '$err',
            onRetry: () => ref.invalidate(monitorEventsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool acknowledged, bool storyworthy) {
    if (storyworthy) {
      return const CircleAvatar(
        backgroundColor: Colors.amber,
        radius: 16,
        child: Icon(Icons.star, size: 18, color: Colors.black),
      );
    }
    if (!acknowledged) {
      return const CircleAvatar(
        backgroundColor: Colors.red,
        radius: 16,
        child: Icon(Icons.priority_high, size: 18, color: Colors.white),
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.grey[700],
      radius: 16,
      child: const Icon(Icons.check, size: 18, color: Colors.white),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

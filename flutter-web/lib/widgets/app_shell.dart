import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The main app shell with a NavigationRail on the left and content area.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail
          NavigationRail(
            selectedIndex: _selectedIndex(location),
            onDestinationSelected: (index) => _onNavTap(context, index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.gavel, size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 4),
                  const Text('DocketWatch', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: Text('Events'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.star_outline),
                selectedIcon: Icon(Icons.star),
                label: Text('Celebrities'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.link_outlined),
                selectedIcon: Icon(Icons.link),
                label: Text('Matches'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.monitor_outlined),
                selectedIcon: Icon(Icons.monitor),
                label: Text('Monitor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.summarize_outlined),
                selectedIcon: Icon(Icons.summarize),
                label: Text('Summarize'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: Text('Calendar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('Headlines'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Admin'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/events')) return 1;
    if (location.startsWith('/celebrities')) return 2;
    if (location.startsWith('/matches')) return 3;
    if (location.startsWith('/monitor')) return 4;
    if (location.startsWith('/summarize')) return 5;
    if (location.startsWith('/calendar')) return 6;
    if (location.startsWith('/headlines')) return 7;
    if (location.startsWith('/admin')) return 8;
    return 0; // Dashboard
  }

  void _onNavTap(BuildContext context, int index) {
    const routes = [
      '/',
      '/events',
      '/celebrities',
      '/matches',
      '/monitor',
      '/summarize',
      '/calendar',
      '/headlines',
      '/admin/tasks',
    ];
    if (index < routes.length) {
      context.go(routes[index]);
    }
  }
}

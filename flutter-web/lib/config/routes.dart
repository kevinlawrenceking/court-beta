import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/case_detail/case_detail_screen.dart';
import '../screens/events/events_screen.dart';
import '../screens/celebrities/gallery_screen.dart';
import '../screens/celebrities/detail_screen.dart';
import '../screens/matches/matches_screen.dart';
import '../screens/monitor/monitor_screen.dart';
import '../screens/summarize/summarize_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/headlines/headlines_screen.dart';
import '../screens/admin/error_log_screen.dart';
import '../screens/admin/tasks_screen.dart';
import '../screens/admin/tools_screen.dart';
import '../screens/login/login_screen.dart';
import '../widgets/app_shell.dart';

/// Paths that don't require authentication.
const _publicPaths = {'/login'};

/// Build the application router with auth redirect.
GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final isPublic = _publicPaths.contains(state.matchedLocation);

      if (!isAuthenticated && !isPublic) return '/login';
      if (isAuthenticated && state.matchedLocation == '/login') return '/';
      return null;
    },
    routes: [
      // Login (no shell)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Main app with navigation shell
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/cases/:id',
            pageBuilder: (context, state) => NoTransitionPage(
              child: CaseDetailScreen(
                caseId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ),
          GoRoute(
            path: '/events',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EventsScreen(),
            ),
          ),
          GoRoute(
            path: '/celebrities',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GalleryScreen(),
            ),
          ),
          GoRoute(
            path: '/celebrities/:id',
            pageBuilder: (context, state) => NoTransitionPage(
              child: CelebrityDetailScreen(
                celebrityId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ),
          GoRoute(
            path: '/matches',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MatchesScreen(),
            ),
          ),
          GoRoute(
            path: '/monitor',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MonitorScreen(),
            ),
          ),
          GoRoute(
            path: '/summarize',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SummarizeScreen(),
            ),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CalendarScreen(),
            ),
          ),
          GoRoute(
            path: '/headlines',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HeadlinesScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/errors',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ErrorLogScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/tasks',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TasksScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/tools',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ToolsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}

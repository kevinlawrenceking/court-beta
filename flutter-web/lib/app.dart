import 'package:flutter/material.dart';

import 'config/routes.dart';
import 'config/theme.dart';

/// Root application widget.
class DocketWatchApp extends StatelessWidget {
  const DocketWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DocketWatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}

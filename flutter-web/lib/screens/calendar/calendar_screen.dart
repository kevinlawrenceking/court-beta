import 'package:flutter/material.dart';

/// Calendar view of upcoming hearings and court events.
/// Replaces: calendar.cfm
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hearing Calendar',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            // TODO: Integrate syncfusion_flutter_calendar or table_calendar
            // for monthly/weekly view of hearings from GET /api/hearings
            const Expanded(
              child: Center(
                child: Text('Calendar view - integrate with hearing API endpoint'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

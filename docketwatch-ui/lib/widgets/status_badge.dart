import 'package:flutter/material.dart';

/// A colored badge chip showing case/match status.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _color,
        ),
      ),
    );
  }

  Color get _color {
    switch (status.toLowerCase()) {
      case 'tracked':
      case 'verified':
        return const Color(0xFF1e8e3e);
      case 'review':
      case 'pending':
        return const Color(0xFFfbbc04);
      case 'removed':
      case 'rejected':
        return const Color(0xFFd93025);
      default:
        return const Color(0xFF5f6368);
    }
  }
}

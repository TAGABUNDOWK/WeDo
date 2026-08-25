import 'package:flutter/material.dart';
import '../utils/time_format.dart';

class DateSeparator extends StatelessWidget {
  final dynamic timestamp;

  const DateSeparator({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final label = formatDateSeparator(timestamp);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

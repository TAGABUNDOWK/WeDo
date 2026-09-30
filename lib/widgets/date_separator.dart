import 'package:flutter/material.dart';
import '../utils/time_format.dart';

class DateSeparator extends StatelessWidget {
  final dynamic timestamp;

  const DateSeparator({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final label = formatDateSeparator(timestamp);
    // Chat background is always dark (scaffold 0xFF190831), but the app theme
    // is light, so brightness-derived colors would render near-invisible here.
    const lineColor = Color(0x26FFFFFF); // white @ 0.15
    const textColor = Color(0x99FFFFFF); // white @ 0.6

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1, color: lineColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1, color: lineColor)),
        ],
      ),
    );
  }
}

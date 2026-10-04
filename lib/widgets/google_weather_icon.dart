import 'package:flutter/material.dart';

/// Renders Google Weather's own icon (from the API's `iconBaseUri`) so the
/// app matches Google's weather display exactly. Falls back to a Material
/// icon when the URI is missing or the image fails to load.
class GoogleWeatherIcon extends StatelessWidget {
  final String iconUri;
  final String conditionType;
  final double size;

  const GoogleWeatherIcon({
    super.key,
    required this.iconUri,
    required this.conditionType,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (iconUri.trim().isEmpty) return _fallbackIcon;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final url = '$iconUri${isDark ? '_dark' : ''}.png';

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : SizedBox(width: size, height: size),
      errorBuilder: (_, __, ___) => _fallbackIcon,
    );
  }

  Widget get _fallbackIcon {
    final lower = conditionType.toLowerCase();
    final isRain = lower.contains('rain') ||
        lower.contains('shower') ||
        lower.contains('drizzle');
    final IconData icon = isRain
        ? Icons.water_drop_rounded
        : lower.contains('thunder')
            ? Icons.thunderstorm
            : lower.contains('snow')
                ? Icons.ac_unit
                : lower.contains('cloud') || lower.contains('overcast')
                    ? Icons.cloud
                    : Icons.wb_sunny_rounded;
    return Icon(
      icon,
      color: isRain ? const Color(0xFF77B8FF) : const Color(0xFFFFD76A),
      size: size,
    );
  }
}

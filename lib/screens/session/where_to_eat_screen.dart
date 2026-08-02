import 'package:flutter/material.dart';
import 'nearby_places_screen.dart';
import 'province_picker_screen.dart';

class WhereToEatScreen extends StatelessWidget {
  const WhereToEatScreen({super.key});

  static const _bg = Color(0xFFE7ECEF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Where should we eat?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _OptionCard(
              icon: Icons.near_me,
              title: 'Nearby restaurants',
              subtitle: 'Find places to eat within 5km of you',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NearbyPlacesScreen(
                      title: 'Nearby restaurants',
                      foodMode: true,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.location_city,
              title: 'Specify a city',
              subtitle: 'Choose a province, then city to explore',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProvincePickerScreen(foodMode: true),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const _bg = Color(0xFFE7ECEF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFFFFFFF),
              offset: Offset(-6, -6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Color(0xFFB8C6CC),
              offset: Offset(6, 6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

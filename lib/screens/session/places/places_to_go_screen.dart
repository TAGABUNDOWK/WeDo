import 'package:flutter/material.dart';
import '../../../models/place_category.dart';
import 'nearby_places_screen.dart';
import 'province_picker_screen.dart';

class PlacesToGoScreen extends StatelessWidget {
  const PlacesToGoScreen({super.key});

  static const _bg = Color(0xFF190831);

  static const _categories = [
    _CategoryData(
      title: 'Mall',
      subtitle: 'Shops, outlets & department stores',
      icon: Icons.storefront,
      category: PlaceCategory.mall,
    ),
    _CategoryData(
      title: 'Nature & Outdoor',
      subtitle: 'Parks, gardens & scenic spots',
      icon: Icons.park,
      category: PlaceCategory.natureOutdoor,
    ),
    _CategoryData(
      title: 'Karaoke',
      subtitle: 'Sing your heart out',
      icon: Icons.mic,
      category: PlaceCategory.karaoke,
    ),
    _CategoryData(
      title: 'FastFood',
      subtitle: 'Burgers, fries & quick bites',
      icon: Icons.fastfood,
      category: PlaceCategory.fastFood,
    ),
    _CategoryData(
      title: 'Restaurant',
      subtitle: 'Sit-down dining spots',
      icon: Icons.restaurant,
      category: PlaceCategory.restaurant,
    ),
    _CategoryData(
      title: 'Pool',
      subtitle: 'Pools for a splash',
      icon: Icons.pool,
      category: PlaceCategory.pool,
    ),
    _CategoryData(
      title: 'Hotel',
      subtitle: 'Stays, inns & resorts',
      icon: Icons.hotel,
      category: PlaceCategory.hotel,
    ),
    _CategoryData(
      title: 'Cafe',
      subtitle: 'Coffee & chill spots',
      icon: Icons.coffee,
      category: PlaceCategory.cafe,
    ),
    _CategoryData(
      title: 'Gym',
      subtitle: 'Workout & fitness centers',
      icon: Icons.fitness_center,
      category: PlaceCategory.gym,
    ),
    _CategoryData(
      title: 'Bar',
      subtitle: 'Drinks & nightlife',
      icon: Icons.local_bar,
      category: PlaceCategory.bar,
    ),
    _CategoryData(
      title: 'Sports',
      subtitle: 'Courts, fields & stadiums',
      icon: Icons.sports_soccer,
      category: PlaceCategory.sports,
    ),
    _CategoryData(
      title: 'Salon',
      subtitle: 'Hair & beauty care',
      icon: Icons.content_cut,
      category: PlaceCategory.salon,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Nearby Go to Places',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: _categories.map((cat) {
            return _CategoryCard(
              icon: cat.icon,
              title: cat.title,
              subtitle: cat.subtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _NearbyOrCityScreen(category: cat.category),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final PlaceCategory category;

  const _CategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
  });
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: const Color(0xFFFE4EF0)),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyOrCityScreen extends StatelessWidget {
  final PlaceCategory category;

  const _NearbyOrCityScreen({required this.category});

  static const _bg = Color(0xFF190831);

  String get _categoryTitle => category.label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _categoryTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _OptionCard(
              icon: Icons.near_me,
              title: 'Places nearby',
              subtitle: 'Find spots within 5km of you',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NearbyPlacesScreen(
                      title: _categoryTitle,
                      category: category,
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
                    builder: (_) => ProvincePickerScreen(category: category),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: const Color(0xFFFE4EF0)),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.54)),
          ],
        ),
      ),
    );
  }
}

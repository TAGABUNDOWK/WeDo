import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../screens/weather/weather_forecast_screen.dart';
import '../services/weather/weather_service.dart';
import 'google_weather_icon.dart';
import 'weather_skeleton.dart';

class WeatherSummaryCard extends StatefulWidget {
  const WeatherSummaryCard({super.key});

  @override
  State<WeatherSummaryCard> createState() => _WeatherSummaryCardState();
}

class _WeatherSummaryCardState extends State<WeatherSummaryCard> {
  late Future<WeatherSnapshot> _weather;

  @override
  void initState() {
    super.initState();
    _weather = WeatherService().fetchCurrentLocationWeather();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherSnapshot>(
      future: _weather,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Shell(child: WeatherSummaryCardSkeleton());
        }
        if (snapshot.hasError) {
          return _Shell(
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _weather = WeatherService().fetchCurrentLocationWeather(),
                  ),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
          );
        }
        final weather = snapshot.data!;
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WeatherForecastScreen()),
          ),
          child: _Shell(
            child: Row(
              children: [
                GoogleWeatherIcon(
                  iconUri: weather.iconUri,
                  conditionType: weather.conditionType,
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weather.locationName,
                        style: const TextStyle(
                          color: Color(0xFFBFA6FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${weather.temperature.round()}°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        weather.condition,
                        style: const TextStyle(
                          color: Color(0xFFFF77E9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${weather.precipitationChance}% rain',
                      style: const TextStyle(
                        color: Color(0xFF9CC5FF),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Forecast',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  final Widget child;

  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2A1464), Color(0xFF171044)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFF9A4CFF).withValues(alpha: 0.75),
      ),
    ),
    child: child,
  );
}

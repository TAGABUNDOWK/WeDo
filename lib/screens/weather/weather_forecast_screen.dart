import 'package:flutter/material.dart';

import '../../models/weather.dart';
import '../../services/weather/weather_service.dart';
import '../../utils/time_format.dart';
import '../../widgets/google_weather_icon.dart';
import '../../widgets/weather_skeleton.dart';

class WeatherForecastScreen extends StatefulWidget {
  const WeatherForecastScreen({super.key});

  @override
  State<WeatherForecastScreen> createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  late Future<WeatherSnapshot> _weather;

  @override
  void initState() {
    super.initState();
    _weather = WeatherService().fetchCurrentLocationWeather();
  }

  void _refresh() => setState(() => _weather = WeatherService().fetchCurrentLocationWeather());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12052F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Weather Forecast'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: FutureBuilder<WeatherSnapshot>(
        future: _weather,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const WeatherForecastSkeleton();
          }
          if (snapshot.hasError) {
            return _WeatherError(message: snapshot.error.toString(), onRetry: _refresh);
          }
          return _ForecastContent(weather: snapshot.data!);
        },
      ),
    );
  }
}

class _ForecastContent extends StatelessWidget {
  final WeatherSnapshot weather;

  const _ForecastContent({required this.weather});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFFE4EF0),
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _CurrentWeatherCard(weather: weather),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Hourly Forecast',
            icon: Icons.schedule_rounded,
            child: SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: weather.hourly.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final item = weather.hourly[index];
                  final start = weather.rainWindowStart;
                  final end = weather.rainWindowEnd;
                  final inRainWindow = start != null &&
                      end != null &&
                      !item.time.isBefore(start) &&
                      item.time.isBefore(end);
                  return _HourlyTile(item: item, inRainWindow: inRainWindow);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '5 Days Forecast',
            icon: Icons.calendar_month_rounded,
            child: Column(
              children: weather.daily.take(5).map((item) => _DailyRow(item: item)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  final WeatherSnapshot weather;

  const _CurrentWeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFB98CFF), size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(weather.locationName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GoogleWeatherIcon(iconUri: weather.iconUri, conditionType: weather.conditionType, size: 58),
                const SizedBox(width: 14),
                Text('${weather.temperature.round()}°C', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(weather.condition, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFF72E9), fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Feels like ${weather.feelsLike.round()}°', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Metric(icon: Icons.water_drop_outlined, label: 'Humidity', value: '${weather.humidity}%'),
              _Metric(icon: Icons.air_rounded, label: 'Wind', value: '${weather.windSpeedKmh.round()} km/h ${weather.windDirection}'),
              _Metric(icon: Icons.wb_sunny_outlined, label: 'UV Index', value: '${weather.uvIndex}'),
              _Metric(
                icon: Icons.umbrella_outlined,
                label: 'Rain today',
                value: weather.rainWindowStart != null
                    ? '${formatHourAmPm(weather.rainWindowStart!)} – ${formatHourAmPm(weather.rainWindowEnd!)}'
                    : 'No rain',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: const Color(0xFFB98CFF), size: 21), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _HourlyTile extends StatelessWidget {
  final HourlyWeather item;
  final bool inRainWindow;

  const _HourlyTile({required this.item, this.inRainWindow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: inRainWindow ? const Color(0xFF1C2F6B) : const Color(0xFF24115B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inRainWindow ? const Color(0xFF82B7FF) : const Color(0xFF743CDE),
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(formatHourAmPm(item.time), style: const TextStyle(color: Color(0xFFBDA7FF), fontSize: 11)),
        GoogleWeatherIcon(iconUri: item.iconUri, conditionType: item.conditionType, size: 28),
        Text('${item.temperature.round()}°', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        Text('${item.precipitationChance}%', style: const TextStyle(color: Color(0xFF82B7FF), fontSize: 11)),
      ]),
    );
  }
}

class _DailyRow extends StatelessWidget {
  final DailyWeather item;

  const _DailyRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 46, child: Text('${item.date.month}/${item.date.day}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
        GoogleWeatherIcon(iconUri: item.iconUri, conditionType: item.conditionType, size: 28),
        const SizedBox(width: 8),
        Expanded(child: Text(item.condition, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFBDA7FF), fontSize: 12))),
        Text('${item.minTemperature.round()}° / ${item.maxTemperature.round()}°', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text('${item.precipitationChance}%', style: const TextStyle(color: Color(0xFF82B7FF), fontSize: 12)),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Metric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: const Color(0xFF98B7FF), size: 18), const SizedBox(width: 5), Text('$label\n$value', style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35))]);
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassPanel({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2A1464), Color(0xFF171044)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF9A4CFF).withValues(alpha: 0.75)),
        ),
        child: child,
      );
}

class _WeatherError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _WeatherError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, color: Colors.white54, size: 48), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)), const SizedBox(height: 14), ElevatedButton(onPressed: onRetry, child: const Text('Retry'))])));
}

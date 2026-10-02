import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../../models/weather.dart';
import '../location/location_service.dart';

class WeatherLocation {
  final double latitude;
  final double longitude;
  final String name;

  const WeatherLocation({
    required this.latitude,
    required this.longitude,
    required this.name,
  });
}

class WeatherService {
  static const _directBaseUrl = 'https://weather.googleapis.com/v1';
  static const _proxyBaseUrl = 'https://wedo-api.vercel.app/weather';
  static const _locationUnavailableMessage =
      'Location unavailable. Please enable location permissions and try again.';

  static Future<WeatherLocation>? _resolvedLocation;

  final http.Client _client;
  final LocationService _locationService;
  final Geocoding _geocoding;

  WeatherService({http.Client? client})
    : _client = client ?? http.Client(),
      _locationService = LocationService(),
      _geocoding = Geocoding();

  Future<WeatherSnapshot> fetchCurrentLocationWeather() async {
    final location = await (_resolvedLocation ??= _resolveLocation());
    return fetchWeather(
      latitude: location.latitude,
      longitude: location.longitude,
      locationName: location.name,
    );
  }

  Future<WeatherLocation> _resolveLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        throw const WeatherException(_locationUnavailableMessage);
      }
      return WeatherLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        name: await _cityName(position.latitude, position.longitude),
      );
    } on WeatherException {
      _resolvedLocation = null;
      rethrow;
    } catch (_) {
      _resolvedLocation = null;
      throw const WeatherException(_locationUnavailableMessage);
    }
  }

  Future<String> _cityName(double latitude, double longitude) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        for (final name in [
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ]) {
          if (name != null && name.trim().isNotEmpty) return name.trim();
        }
      }
    } catch (_) {}
    return 'Current Location';
  }

  Future<WeatherSnapshot> fetchWeather({
    required double latitude,
    required double longitude,
    required String locationName,
  }) async {
    final apiKey = dotenv.env['GOOGLE_WEATHER_API_KEY']?.trim();
    final proxied = apiKey == null || apiKey.isEmpty;
    final baseUrl = proxied ? _proxyBaseUrl : _directBaseUrl;

    final query = <String, String>{
      if (!proxied) 'key': apiKey,
      'location.latitude': '$latitude',
      'location.longitude': '$longitude',
      'unitsSystem': 'METRIC',
      'languageCode': 'en',
    };

    final responses = await Future.wait([
      _get(
        _buildUri(baseUrl, proxied, 'currentConditions:lookup', query),
        proxied: proxied,
      ),
      _get(
        _buildUri(baseUrl, proxied, 'forecast/hours:lookup', {
          ...query,
          'hours': '24',
        }),
        proxied: proxied,
      ),
      _get(
        _buildUri(baseUrl, proxied, 'forecast/days:lookup', {
          ...query,
          'days': '5',
        }),
        proxied: proxied,
      ),
    ]);

    final current = responses[0];
    final hourly = responses[1];
    final daily = responses[2];

    final currentCondition = _condition(current['weatherCondition']);
    final currentPrecipitation = _precipitationChance(current['precipitation']);

    return WeatherSnapshot(
      locationName: locationName,
      currentTime:
          DateTime.tryParse(current['currentTime'] as String? ?? '') ??
          DateTime.now(),
      condition: currentCondition.$1,
      conditionType: currentCondition.$2,
      iconUri: currentCondition.$3,
      temperature: _degrees(current['temperature']),
      feelsLike: _degrees(current['feelsLikeTemperature']),
      humidity: _int(current['relativeHumidity']),
      uvIndex: _int(current['uvIndex']),
      windSpeedKmh: _windSpeed(current['wind']),
      windDirection: _windDirection(current['wind']),
      precipitationChance: currentPrecipitation,
      hourly: _parseHourly(hourly['forecastHours']),
      daily: _parseDaily(daily['forecastDays']),
    );
  }

  Uri _buildUri(
    String baseUrl,
    bool proxied,
    String path,
    Map<String, String> query,
  ) {
    if (proxied) {
      return Uri.parse(baseUrl).replace(
        queryParameters: {'path': path, ...query},
      );
    }
    return Uri.parse('$baseUrl/$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _get(Uri uri, {required bool proxied}) async {
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WeatherException(_errorMessage(response, proxied: proxied));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _errorMessage(http.Response response, {required bool proxied}) {
    final detail = _errorDetail(response.body);
    if (detail != null) return detail;
    if (proxied && response.statusCode == 404) {
      return 'Weather proxy unavailable. Deploy the /weather route to Vercel.';
    }
    return 'Weather request failed (${response.statusCode}).';
  }

  String? _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  List<HourlyWeather> _parseHourly(dynamic value) {
    final items = value is List ? value : const [];
    return items.whereType<Map<String, dynamic>>().map((item) {
      final condition = _condition(item['weatherCondition']);
      return HourlyWeather(
        time: _dateTime(item['displayDateTime'], item['interval']),
        condition: condition.$1,
        conditionType: condition.$2,
        iconUri: condition.$3,
        temperature: _degrees(item['temperature']),
        precipitationChance: _precipitationChance(item['precipitation']),
      );
    }).toList();
  }

  List<DailyWeather> _parseDaily(dynamic value) {
    final items = value is List ? value : const [];
    return items.whereType<Map<String, dynamic>>().map((item) {
      final part = item['daytimeForecast'] as Map<String, dynamic>? ?? const {};
      final condition = _condition(part['weatherCondition']);
      final date = item['displayDate'] as Map<String, dynamic>? ?? const {};
      return DailyWeather(
        date: DateTime(
          _int(date['year']),
          _int(date['month']),
          _int(date['day']),
        ),
        condition: condition.$1,
        conditionType: condition.$2,
        iconUri: condition.$3,
        minTemperature: _degrees(item['minTemperature']),
        maxTemperature: _degrees(item['maxTemperature']),
        precipitationChance: _precipitationChance(part['precipitation']),
      );
    }).toList();
  }

  DateTime _dateTime(dynamic display, dynamic interval) {
    final displayMap = display is Map<String, dynamic> ? display : null;
    if (displayMap != null) {
      return DateTime(
        _int(displayMap['year']),
        _int(displayMap['month']),
        _int(displayMap['day']),
        _int(displayMap['hours']),
      );
    }
    final intervalMap = interval is Map<String, dynamic> ? interval : null;
    return DateTime.tryParse(intervalMap?['startTime'] as String? ?? '') ??
        DateTime.now();
  }

  (String, String, String) _condition(dynamic value) {
    final map = value is Map<String, dynamic> ? value : const {};
    final description = map['description'];
    final text = description is Map<String, dynamic>
        ? description['text'] as String?
        : null;
    return (
      text ?? _humanize(map['type'] as String?),
      map['type'] as String? ?? '',
      map['iconBaseUri'] as String? ?? '',
    );
  }

  String _humanize(String? value) {
    return (value ?? 'Unknown')
        .toLowerCase()
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  double _degrees(dynamic value) {
    final map = value is Map<String, dynamic> ? value : const {};
    return (map['degrees'] as num?)?.toDouble() ?? 0;
  }

  int _precipitationChance(dynamic value) {
    final map = value is Map<String, dynamic> ? value : const {};
    final probability = map['probability'];
    if (probability is Map<String, dynamic>) {
      return _int(probability['percent']);
    }
    return _int(probability);
  }

  double _windSpeed(dynamic value) {
    final map = value is Map<String, dynamic> ? value : const {};
    final speed = map['speed'] as Map<String, dynamic>?;
    return (speed?['value'] as num?)?.toDouble() ?? 0;
  }

  String _windDirection(dynamic value) {
    final map = value is Map<String, dynamic> ? value : const {};
    final direction = map['direction'] as Map<String, dynamic>?;
    return direction?['cardinal'] as String? ?? '';
  }

  int _int(dynamic value) => (value as num?)?.round() ?? 0;
}

class WeatherException implements Exception {
  final String message;

  const WeatherException(this.message);

  @override
  String toString() => message;
}

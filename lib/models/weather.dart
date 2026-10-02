class WeatherSnapshot {
  final String locationName;
  final DateTime currentTime;
  final String condition;
  final String conditionType;
  final String iconUri;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final int uvIndex;
  final double windSpeedKmh;
  final String windDirection;
  final DateTime? rainWindowStart;
  final DateTime? rainWindowEnd;
  final int? rainWindowAvgChance;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;

  const WeatherSnapshot({
    required this.locationName,
    required this.currentTime,
    required this.condition,
    required this.conditionType,
    required this.iconUri,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.uvIndex,
    required this.windSpeedKmh,
    required this.windDirection,
    this.rainWindowStart,
    this.rainWindowEnd,
    this.rainWindowAvgChance,
    required this.hourly,
    required this.daily,
  });
}

class HourlyWeather {
  final DateTime time;
  final String condition;
  final String conditionType;
  final String iconUri;
  final double temperature;
  final int precipitationChance;

  const HourlyWeather({
    required this.time,
    required this.condition,
    required this.conditionType,
    required this.iconUri,
    required this.temperature,
    required this.precipitationChance,
  });
}

class DailyWeather {
  final DateTime date;
  final String condition;
  final String conditionType;
  final String iconUri;
  final double minTemperature;
  final double maxTemperature;
  final int precipitationChance;

  const DailyWeather({
    required this.date,
    required this.condition,
    required this.conditionType,
    required this.iconUri,
    required this.minTemperature,
    required this.maxTemperature,
    required this.precipitationChance,
  });
}

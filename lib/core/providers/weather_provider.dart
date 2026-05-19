import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'location_provider.dart';
import '../utils/language_helper.dart';
import 'package:bharat_flow/core/utils/api_tracker.dart';

// ==========================================
// 1. ADVANCED MODELS (14-DAY SCANNING)
// ==========================================

class DailyForecast {
  final DateTime date;
  final int maxTemp;
  final int minTemp;
  final int precipProb;
  final String iconType;

  DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.precipProb,
    required this.iconType,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'maxTemp': maxTemp,
    'minTemp': minTemp,
    'precipProb': precipProb,
    'iconType': iconType,
  };

  factory DailyForecast.fromJson(Map<dynamic, dynamic> json) => DailyForecast(
    date: DateTime.parse(json['date']),
    maxTemp: json['maxTemp'] ?? 0,
    minTemp: json['minTemp'] ?? 0,
    precipProb: json['precipProb'] ?? 0,
    iconType: json['iconType'] ?? 'Clear',
  );
}

class WeatherData {
  final String condition;
  final String temp;
  final String forecast;
  final String advisory;
  final String iconType; 
  final DateTime lastUpdated;
  final String sunrise;
  final String sunset;
  final double windSpeed;
  final double currentRain;
  final List<DailyForecast> weeklyForecast;
  final List<dynamic> upcomingAlerts; 
  final bool warehouseCritical; // Red Alert for Warehouse
  final List<String> favoriteMandis; // Favorites List
  final String? riskWindow; // e.g. "20 May - 23 May"
  final double? yearlyMax;
  final String? yearlyMaxDate;
  final double? yearlyMin;
  final String? yearlyMinDate;
  final double? yearlyMaxRain;
  final String? yearlyMaxRainDate;

  WeatherData({
    required this.condition,
    required this.temp,
    required this.forecast,
    required this.advisory,
    required this.iconType,
    required this.lastUpdated,
    required this.sunrise,
    required this.sunset,
    required this.windSpeed,
    required this.currentRain,
    required this.weeklyForecast,
    required this.upcomingAlerts,
    required this.warehouseCritical,
    required this.favoriteMandis,
    this.riskWindow,
    this.yearlyMax,
    this.yearlyMaxDate,
    this.yearlyMin,
    this.yearlyMinDate,
    this.yearlyMaxRain,
    this.yearlyMaxRainDate,
  });
}

// ==========================================
// 2. NOTIFICATION MANAGER (ON/OFF)
// ==========================================

class WeatherNotificationManager {
  static Future<void> toggleAlert(String type, bool isOn) async {
    final topic = 'weather_alert_$type';
    try {
      if (isOn) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }
    } catch (e) {
      print('❌ Firebase Messaging Topic Error: $e');
    }
  }
}

// ==========================================
// 3. MASTER WEATHER PROVIDER (THE ENGINE)
// ==========================================

final weatherProvider = FutureProvider<WeatherData>((ref) async {
  final location = ref.watch(locationProvider);
  final city = location.city;
  final lat = location.latitude;
  final lng = location.longitude;

  final box = await Hive.openBox('weather_cache');
  final cacheKey = 'weather_full_v5_${lat.toStringAsFixed(2)}';
  final cached = box.get(cacheKey);

  // Check Cache (15 Minutes)
  if (cached != null) {
    final timestamp = DateTime.parse(cached['timestamp'] ?? DateTime.now().toIso8601String());
    if (DateTime.now().difference(timestamp).inMinutes < 15) {
      return _mapFromCache(cached);
    }
  }

  // --- A. TRY SUPABASE (VPS BACKEND) ---
  try {
    final supabase = Supabase.instance.client;
    final res = await supabase
        .from('india_weather_data')
        .select()
        .eq('location_name', city)
        .maybeSingle();

    ApiTracker.logCall('VPS: Google Weather API', statusCode: res != null ? 200 : 404);

    if (res != null) {
      return await _processSupabaseData(res, location, box, cacheKey);
    }
  } catch (e) {
    print('⚠️ Supabase Error: $e');
  }

  // --- B. FALLBACK TO OPEN-METEO ---
  return await _fetchFromOpenMeteo(lat, lng, location, box, cacheKey, cached);
});

// ==========================================
// 4. HELPER FUNCTIONS
// ==========================================

Future<WeatherData> _processSupabaseData(Map res, dynamic location, Box box, String cacheKey) async {
  final rain = (res['precipitation_1h'] as num?)?.toDouble() ?? 0.0;
  final wind = (res['wind_speed'] as num?)?.toDouble() ?? 0.0;
  final alerts = res['upcoming_alerts'] as List? ?? [];
  final dailyRaw = res['forecast_14d'];
  
  List<DailyForecast> weekly = [];
  if (dailyRaw is Map<String, dynamic>) {
    final times = dailyRaw['time'] as List? ?? [];
    for (int i = 0; i < (times.length > 14 ? 14 : times.length); i++) {
      weekly.add(DailyForecast(
        date: DateTime.parse(times[i]),
        maxTemp: (dailyRaw['temperature_2m_max'][i] as num).round(),
        minTemp: (dailyRaw['temperature_2m_min'][i] as num).round(),
        precipProb: (dailyRaw['precipitation_sum'][i] as num).round(),
        iconType: (dailyRaw['precipitation_sum'][i] as num) > 5 ? 'Rain' : 'Clear',
      ));
    }
  }

  final condLabel = rain > 10 ? 'Heavy Rain' : (rain > 0 ? 'Light Rain' : 'Clear Sky');
  final condition = await LanguageHelper.translate(condLabel, location.state, location.city);
  
  String advisoryStr = _generateSmartAdvisory(0, (res['temperature'] as num).toDouble(), rain: rain, wind: wind, forecast14d: weekly);
  final advisory = await LanguageHelper.translate(advisoryStr, location.state, location.city);

  // Calculate Risk Window
  String? riskWindow;
  int startDay = -1;
  int endDay = -1;
  for (int i = 0; i < weekly.length; i++) {
    if (weekly[i].precipProb > 70) {
      if (startDay == -1) startDay = i;
      endDay = i;
    } else if (startDay != -1) break;
  }
  if (startDay != -1) {
    final start = DateFormat('dd MMM').format(weekly[startDay].date);
    final end = DateFormat('dd MMM').format(weekly[endDay].date);
    riskWindow = (startDay == endDay) ? start : "$start - $end";
  }

  final data = WeatherData(
    condition: condition,
    temp: '${res['temperature']}°C',
    forecast: 'Hawa: $wind km/h | Baarish: $rain mm',
    advisory: advisory,
    iconType: rain > 10 ? 'Rain' : 'Clear',
    lastUpdated: DateTime.now(),
    sunrise: res['sunrise'] ?? '',
    sunset: res['sunset'] ?? '',
    windSpeed: wind,
    currentRain: rain,
    weeklyForecast: weekly,
    upcomingAlerts: alerts,
    warehouseCritical: rain >= 50 || wind >= 60,
    favoriteMandis: ['Surat Mandi', 'Unjha Mandi', 'Rajkot Mandi'],
    riskWindow: riskWindow,
    yearlyMax: (res['yearly_max_temp'] as num?)?.toDouble(),
    yearlyMaxDate: res['yearly_max_date'],
    yearlyMin: (res['yearly_min_temp'] as num?)?.toDouble(),
    yearlyMinDate: res['yearly_min_date'],
    yearlyMaxRain: (res['yearly_max_rain'] as num?)?.toDouble(),
    yearlyMaxRainDate: res['yearly_max_rain_date'],
  );

  await _saveToCache(box, cacheKey, data);
  return data;
}

Future<WeatherData> _fetchFromOpenMeteo(double lat, double lng, dynamic location, Box box, String cacheKey, dynamic cached) async {
  try {
    final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&timezone=auto&forecast_days=14';
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    ApiTracker.logCall('Open-Meteo: Forecast API', statusCode: res.statusCode);

    if (res.statusCode == 200) {
      final dataMap = json.decode(res.body);
      final current = dataMap['current'];
      final daily = dataMap['daily'];
      
      final temp = current['temperature_2m'].round().toString();
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
      final weatherCode = current['weather_code'];
      
      List<DailyForecast> weekly = [];
      for (int i = 0; i < 14; i++) {
        weekly.add(DailyForecast(
          date: DateTime.parse(daily['time'][i]),
          maxTemp: daily['temperature_2m_max'][i].round(),
          minTemp: daily['temperature_2m_min'][i].round(),
          precipProb: daily['precipitation_probability_max'][i],
          iconType: _mapWeatherCode(daily['weather_code'][i])['icon']!,
        ));
      }

      final conditionInfo = _mapWeatherCode(weatherCode);
      final condition = await LanguageHelper.translate(conditionInfo['label']!, location.state, location.city);
      
      final advisoryStr = _generateSmartAdvisory(weatherCode, double.parse(temp), wind: wind, forecast14d: weekly);
      final advisory = await LanguageHelper.translate(advisoryStr, location.state, location.city);

      final sunriseTime = DateTime.parse(daily['sunrise'][0]);
      final sunsetTime = DateTime.parse(daily['sunset'][0]);

      // Calculate Risk Window
      String? riskWindow;
      int startDay = -1;
      int endDay = -1;
      for (int i = 0; i < weekly.length; i++) {
        if (weekly[i].precipProb > 70) {
          if (startDay == -1) startDay = i;
          endDay = i;
        } else if (startDay != -1) break;
      }
      if (startDay != -1) {
        final start = DateFormat('dd MMM').format(weekly[startDay].date);
        final end = DateFormat('dd MMM').format(weekly[endDay].date);
        riskWindow = (startDay == endDay) ? start : "$start - $end";
      }

      final weatherData = WeatherData(
        condition: condition,
        temp: '$temp°C',
        forecast: 'Hawa: $wind km/h',
        advisory: advisory,
        iconType: conditionInfo['icon']!,
        lastUpdated: DateTime.now(),
        sunrise: DateFormat.jm().format(sunriseTime),
        sunset: DateFormat.jm().format(sunsetTime),
        windSpeed: wind,
        currentRain: 0,
        weeklyForecast: weekly,
        upcomingAlerts: [],
        warehouseCritical: wind >= 60,
        favoriteMandis: [],
        riskWindow: riskWindow,
        yearlyMax: (cached?['yearlyMax'] as num?)?.toDouble() ?? 48.5,
        yearlyMaxDate: cached?['yearlyMaxDate'] ?? '15 May ${DateTime.now().year - 1}',
        yearlyMin: (cached?['yearlyMin'] as num?)?.toDouble() ?? 8.2,
        yearlyMinDate: cached?['yearlyMinDate'] ?? '12 Jan ${DateTime.now().year}',
        yearlyMaxRain: (cached?['yearlyMaxRain'] as num?)?.toDouble() ?? 125.0,
        yearlyMaxRainDate: cached?['yearlyMaxRainDate'] ?? '24 Aug ${DateTime.now().year - 1}',
      );
      // 🔥 Ye hissa Supabase mein naye sheher ko register karega
try {
  await Supabase.instance.client.from('india_weather_data').upsert({
    'location_name': location.city,
    'latitude': lat,
    'longitude': lng,
    'temperature': double.parse(temp),
    'forecast_14d': dataMap['daily'], 
    'updated_at': DateTime.now().toIso8601String(),
  });
} catch (e) {
  print('⚠️ Auto-Registration Failed: $e');
}

      await _saveToCache(box, cacheKey, weatherData);
      return weatherData;
    }
  } catch (e) {
    print('❌ OpenMeteo Error: $e');
  }

  if (cached != null) return _mapFromCache(cached);

  return WeatherData(
    condition: 'Clear', temp: '32°C', forecast: 'Normal', advisory: 'Safe to work.',
    iconType: 'Clear', lastUpdated: DateTime.now(), sunrise: '06:00', sunset: '18:30',
    windSpeed: 0, currentRain: 0, weeklyForecast: [], upcomingAlerts: [],
    warehouseCritical: false, favoriteMandis: [],
    yearlyMax: 48.5, yearlyMaxDate: '15 May ${DateTime.now().year - 1}',
    yearlyMin: 8.2, yearlyMinDate: '12 Jan ${DateTime.now().year}',
    yearlyMaxRain: 125.0, yearlyMaxRainDate: '24 Aug ${DateTime.now().year - 1}',
  );
}

String _generateSmartAdvisory(int code, double temp, {double rain = 0, double wind = 0, List<DailyForecast> forecast14d = const []}) {
  if (rain >= 50) return '🚨 BHAARI BAARISH ALERT: Warehouse (Bhandar) ka maal turant dhak dein!';
  if (wind >= 60) return '🚩 TUFAN ALERT: Tez hawa chalne wali hai. Mandi kaam mein savdhani bartein.';
  
  bool rainSoon = false;
  for (int i = 0; i < (forecast14d.length > 2 ? 2 : forecast14d.length); i++) {
    if (forecast14d[i].precipProb > 30) {
      rainSoon = true;
      break;
    }
  }
  if (rainSoon) {
    String dateRange = "";
    for (int i = 0; i < forecast14d.length; i++) {
      if (forecast14d[i].precipProb > 30) {
        final start = DateFormat('dd MMM').format(forecast14d[i].date);
        dateRange = " ($start ke aas-paas)";
        break;
      }
    }
    return '📅 AGLE 48 GHANTE: Baarish hone ki sambhavna hai$dateRange. Apni fasal surakshit rakhein.';
  }

  if (code >= 51 && code <= 99) return 'Rain detected. Cover open mandi stacks and avoid pesticide spray today.';
  if (temp > 35) return 'Heat wave warning. Ensure proper irrigation for crops in the afternoon.';
  
  return '✅ Mausam anukul hai. Mandi trade ke liye badhiya din hai.';
}

Future<void> _saveToCache(Box box, String key, WeatherData data) async {
  await box.put(key, {
    'condition': data.condition,
    'temp': data.temp,
    'forecast': data.forecast,
    'advisory': data.advisory,
    'iconType': data.iconType,
    'timestamp': data.lastUpdated.toIso8601String(),
    'sunrise': data.sunrise,
    'sunset': data.sunset,
    'windSpeed': data.windSpeed,
    'currentRain': data.currentRain,
    'weeklyForecast': data.weeklyForecast.map((e) => e.toJson()).toList(),
    'upcomingAlerts': data.upcomingAlerts,
    'warehouseCritical': data.warehouseCritical,
    'favoriteMandis': data.favoriteMandis,
    'riskWindow': data.riskWindow,
    'yearlyMax': data.yearlyMax,
    'yearlyMaxDate': data.yearlyMaxDate,
    'yearlyMin': data.yearlyMin,
    'yearlyMinDate': data.yearlyMinDate,
    'yearlyMaxRain': data.yearlyMaxRain,
    'yearlyMaxRainDate': data.yearlyMaxRainDate,
  });
}

WeatherData _mapFromCache(dynamic cached) {
  return WeatherData(
    condition: cached['condition'] ?? 'Clear',
    temp: cached['temp'] ?? '30°C',
    forecast: cached['forecast'] ?? '',
    advisory: cached['advisory'] ?? '',
    iconType: cached['iconType'] ?? 'Clear',
    lastUpdated: DateTime.parse(cached['timestamp'] ?? DateTime.now().toIso8601String()),
    sunrise: cached['sunrise'] ?? '',
    sunset: cached['sunset'] ?? '',
    windSpeed: (cached['windSpeed'] as num?)?.toDouble() ?? 0.0,
    currentRain: (cached['currentRain'] as num?)?.toDouble() ?? 0.0,
    weeklyForecast: (cached['weeklyForecast'] as List? ?? []).map((e) => DailyForecast.fromJson(e)).toList(),
    upcomingAlerts: cached['upcomingAlerts'] as List? ?? [],
    warehouseCritical: cached['warehouseCritical'] ?? false,
    favoriteMandis: (cached['favoriteMandis'] as List? ?? []).cast<String>(),
    riskWindow: cached['riskWindow'],
    yearlyMax: (cached['yearlyMax'] as num?)?.toDouble(),
    yearlyMaxDate: cached['yearlyMaxDate'],
    yearlyMin: (cached['yearlyMin'] as num?)?.toDouble(),
    yearlyMinDate: cached['yearlyMinDate'],
    yearlyMaxRain: (cached['yearlyMaxRain'] as num?)?.toDouble(),
    yearlyMaxRainDate: cached['yearlyMaxRainDate'],
  );
}

Map<String, String> _mapWeatherCode(int code) {
  if (code == 0) return {'label': 'Clear Sky', 'icon': 'Clear'};
  if (code >= 1 && code <= 3) return {'label': 'Partly Cloudy', 'icon': 'Clouds'};
  if (code >= 45 && code <= 48) return {'label': 'Foggy', 'icon': 'Clouds'};
  if (code >= 51 && code <= 67) return {'label': 'Raining', 'icon': 'Rain'};
  if (code >= 71 && code <= 77) return {'label': 'Snowing', 'icon': 'Snow'};
  if (code >= 80 && code <= 82) return {'label': 'Heavy Rain', 'icon': 'Rain'};
  if (code >= 95) return {'label': 'Thunderstorm', 'icon': 'Rain'};
  return {'label': 'Cloudy', 'icon': 'Clouds'};
}
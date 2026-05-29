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
import 'package:bharat_flow/core/services/notification_service.dart';

// ==========================================
// 1. ADVANCED MODELS (14-DAY SCANNING)
// ==========================================

class DailyForecast {
  final DateTime date;
  final int maxTemp;
  final int minTemp;
  final int precipProb;
  final String iconType;
  final String dominantCondition;
  final String dominantValue;

  DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.precipProb,
    required this.iconType,
    this.dominantCondition = '',
    this.dominantValue = '',
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'maxTemp': maxTemp,
    'minTemp': minTemp,
    'precipProb': precipProb,
    'iconType': iconType,
    'dominantCondition': dominantCondition,
    'dominantValue': dominantValue,
  };

  factory DailyForecast.fromJson(Map<dynamic, dynamic> json) => DailyForecast(
    date: DateTime.parse(json['date']),
    maxTemp: json['maxTemp'] ?? 0,
    minTemp: json['minTemp'] ?? 0,
    precipProb: json['precipProb'] ?? 0,
    iconType: json['iconType'] ?? 'Clear',
    dominantCondition: json['dominantCondition'] ?? '',
    dominantValue: json['dominantValue'] ?? '',
  );
}

class HourlyForecast {
  final DateTime time;
  final int temp;
  final int precipProb;
  final String iconType;

  HourlyForecast({
    required this.time,
    required this.temp,
    required this.precipProb,
    required this.iconType,
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'temp': temp,
    'precipProb': precipProb,
    'iconType': iconType,
  };

  factory HourlyForecast.fromJson(Map<dynamic, dynamic> json) => HourlyForecast(
    time: DateTime.parse(json['time']),
    temp: json['temp'] ?? 0,
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
  final List<HourlyForecast> hourlyForecast;
  final double uvIndex;
  final double pressure;
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
    required this.hourlyForecast,
    required this.uvIndex,
    required this.pressure,
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
      if (cached['hourlyForecast'] == null || (cached['hourlyForecast'] as List).isEmpty) {
         print('⚠️ Missing hourlyForecast in Hive Cache. Bypassing to OpenMeteo!');
      } else {
         return _mapFromCache(cached);
      }
    }
  }

  // --- A. TRY SUPABASE (VPS BACKEND) ---
  try {
    final supabase = Supabase.instance.client;
    Map<String, dynamic>? res;

    // 1. First attempt: exact city match
    final cityMatch = await supabase
        .from('india_weather_data')
        .select()
        .eq('location_name', city)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
        
    if (cityMatch != null) {
      res = Map<String, dynamic>.from(cityMatch);
    }

    // 2. Second attempt: proximity matching (within ~20km) to catch users with different city spellings
    if (res == null) {
      final closeRecords = await supabase
          .from('india_weather_data')
          .select()
          .gte('latitude', lat - 0.18)
          .lte('latitude', lat + 0.18)
          .gte('longitude', lng - 0.18)
          .lte('longitude', lng + 0.18)
          .limit(1);
          
      if (closeRecords != null && (closeRecords as List).isNotEmpty) {
        res = Map<String, dynamic>.from(closeRecords.first);
        print('✅ Weather loaded via 20km Proximity Match from Supabase for Lat: ${lat.toStringAsFixed(2)}, Lng: ${lng.toStringAsFixed(2)}');
      }
    }

    ApiTracker.logCall('VPS: Google Weather API', statusCode: res != null ? 200 : 404);

    if (res != null) {
      if (res['hourly_data'] == null) {
         print('⚠️ Missing hourly_data in Supabase. Bypassing to OpenMeteo!');
      } else if (res['wind_speed'] == null) {
         print('⚠️ Missing wind_speed in Supabase. Bypassing to OpenMeteo to fix 0.0 issue!');
      } else {
         return await _processSupabaseData(res, location, box, cacheKey);
      }
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
  if (dailyRaw is Map) {
    final times = dailyRaw['time'] as List? ?? [];
    for (int i = 0; i < (times.length > 14 ? 14 : times.length); i++) {
      final maxT = (dailyRaw['temperature_2m_max'][i] as num).round();
      final minT = (dailyRaw['temperature_2m_min'][i] as num).round();
      final pSum = (dailyRaw['precipitation_sum']?[i] as num?)?.round() ?? 0;
      final maxWind = (dailyRaw['wind_speed_10m_max']?[i] as num?)?.toDouble() ?? 0.0;
      final uv = (dailyRaw['uv_index_max']?[i] as num?)?.toDouble() ?? 0.0;
      final wCode = dailyRaw['weather_code']?[i] ?? 0;
      
      // Calculate dominant condition
      String domCond = '';
      String domVal = '';

      if (maxWind > 50) {
        domCond = 'Tufan (Storm)';
        domVal = '${maxWind.round()} km/h';
      } else if (pSum > 0 && (pSum > 10 || wCode >= 51)) {
        domCond = 'Rain';
        domVal = '$pSum mm';
      } else if (maxT >= 35) {
        domCond = 'Kadi Dhoop (Heat)';
        domVal = '$maxT°C';
      } else if (maxWind > 25) {
        domCond = 'Tez Hawa (Wind)';
        domVal = '${maxWind.round()} km/h';
      } else if (minT <= 15) {
        domCond = 'Thandi (Cold)';
        domVal = '$minT°C';
      } else if (uv > 6) {
        domCond = 'Dhoop (Sun)';
        domVal = 'UV $uv';
      } else {
        domCond = 'Normal';
        domVal = '$maxT°C';
      }

      weekly.add(DailyForecast(
        date: DateTime.parse(times[i]),
        maxTemp: maxT,
        minTemp: minT,
        precipProb: pSum,
        iconType: pSum > 0 && (pSum > 5 || wCode >= 51) ? 'Rain' : (wCode >= 1 && wCode <= 3 ? 'Clouds' : 'Clear'),
        dominantCondition: domCond,
        dominantValue: domVal,
      ));
    }
  }

  final condLabel = rain > 10 ? 'Heavy Rain' : (rain > 0 ? 'Light Rain' : 'Clear Sky');
  final condition = await LanguageHelper.translate(condLabel, location.state, location.city);
  
  String advisoryStr = _generateSmartAdvisory(0, (res['temperature'] as num).toDouble(), rain: rain, wind: wind, forecast14d: weekly);
  final advisory = await LanguageHelper.translate(advisoryStr, location.state, location.city);

  // Parse Hourly Data from Supabase if available
  List<HourlyForecast> hourlyList = [];
  final hourlyRaw = res['hourly_data'];
  if (hourlyRaw is Map) {
    final times = hourlyRaw['time'] as List? ?? [];
    for (int i = 0; i < (times.length > 48 ? 48 : times.length); i++) {
      hourlyList.add(HourlyForecast(
        time: DateTime.parse(times[i]),
        temp: (hourlyRaw['temperature_2m'][i] as num).round(),
        precipProb: (hourlyRaw['precipitation_probability'][i] as num).round(),
        iconType: _mapWeatherCode(hourlyRaw['weather_code'][i])['icon']!,
      ));
    }
  }

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

  String forecastStr = 'Hawa: $wind km/h';
  if (rain > 0) {
    forecastStr += ' | ${rain}mm Rain';
  }

  final data = WeatherData(
    condition: condition,
    temp: '${res['temperature']}°C',
    forecast: forecastStr,
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
    hourlyForecast: hourlyList,
    uvIndex: 0.0,
    pressure: 1013.0,
  );

  try {
    final locBox = await Hive.openBox('settings');
    final isEnabled = locBox.get('weather_notifications_enabled', defaultValue: true);
    if (isEnabled && weekly.isNotEmpty) {
      await NotificationService.scheduleDailyWeatherNotifications(
        location.city,
        weekly[0].maxTemp,
        weekly[0].minTemp,
      );
    }
  } catch (e) {
    print('Error scheduling weather notification from Supabase: $e');
  }

  await _saveToCache(box, cacheKey, data);
  return data;
}

Future<WeatherData> _fetchFromOpenMeteo(double lat, double lng, dynamic location, Box box, String cacheKey, dynamic cached) async {
  try {
    final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,surface_pressure,precipitation&hourly=temperature_2m,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,uv_index_max,wind_speed_10m_max&timezone=auto&forecast_days=14';
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    ApiTracker.logCall('Open-Meteo: Forecast API', statusCode: res.statusCode);

    if (res.statusCode == 200) {
      final dataMap = json.decode(res.body);
      final current = dataMap['current'];
      final daily = dataMap['daily'];
      final hourly = dataMap['hourly'];
      
      final temp = current['temperature_2m'].round().toString();
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
      final currentRain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
      final weatherCode = current['weather_code'];
      final pressure = (current['surface_pressure'] as num?)?.toDouble() ?? 1013.0;
      final uvIndex = (daily['uv_index_max'][0] as num?)?.toDouble() ?? 0.0;
      
      List<DailyForecast> weekly = [];
      for (int i = 0; i < 14; i++) {
        final wCode = daily['weather_code'][i];
        final pProb = daily['precipitation_probability_max'][i];
        final maxT = daily['temperature_2m_max'][i].round();
        final minT = daily['temperature_2m_min'][i].round();
        final maxWind = (daily['wind_speed_10m_max']?[i] as num?)?.toDouble() ?? 0.0;
        final uv = (daily['uv_index_max']?[i] as num?)?.toDouble() ?? 0.0;

        String domCond = '';
        String domVal = '';

        if (maxWind > 50) {
          domCond = 'Tufan (Storm)';
          domVal = '${maxWind.round()} km/h';
        } else if (pProb > 0 && (pProb > 60 || wCode >= 51)) {
          domCond = 'Rain';
          domVal = '$pProb%';
        } else if (maxT >= 35) {
          domCond = 'Kadi Dhoop (Heat)';
          domVal = '$maxT°C';
        } else if (maxWind > 25) {
          domCond = 'Tez Hawa (Wind)';
          domVal = '${maxWind.round()} km/h';
        } else if (minT <= 15) {
          domCond = 'Thandi (Cold)';
          domVal = '$minT°C';
        } else if (uv > 6) {
          domCond = 'Dhoop (Sun)';
          domVal = 'UV $uv';
        } else {
          domCond = 'Normal';
          domVal = '$maxT°C';
        }

        weekly.add(DailyForecast(
          date: DateTime.parse(daily['time'][i]),
          maxTemp: maxT,
          minTemp: minT,
          precipProb: pProb,
          iconType: _mapWeatherCode(wCode)['icon']!,
          dominantCondition: domCond,
          dominantValue: domVal,
        ));
      }

      List<HourlyForecast> hourlyList = [];
      if (hourly != null) {
        for (int i = 0; i < 48; i++) {
          hourlyList.add(HourlyForecast(
            time: DateTime.parse(hourly['time'][i]),
            temp: hourly['temperature_2m'][i].round(),
            precipProb: hourly['precipitation_probability'][i],
            iconType: _mapWeatherCode(hourly['weather_code'][i])['icon']!,
          ));
        }
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

      String forecastStr = 'Hawa: $wind km/h';
      if (currentRain > 0) {
        forecastStr += ' | ${currentRain}mm Rain';
      }

      final weatherData = WeatherData(
        condition: condition,
        temp: '$temp°C',
        forecast: forecastStr,
        advisory: advisory,
        iconType: conditionInfo['icon']!,
        lastUpdated: DateTime.now(),
        sunrise: DateFormat.jm().format(sunriseTime),
        sunset: DateFormat.jm().format(sunsetTime),
        windSpeed: wind,
        currentRain: 0,
        weeklyForecast: weekly,
        hourlyForecast: hourlyList,
        uvIndex: uvIndex,
        pressure: pressure,
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
    'wind_speed': wind,
    'precipitation_1h': currentRain,
    'sunrise': daily['sunrise'][0],
    'sunset': daily['sunset'][0],
    'forecast_14d': dataMap['daily'], 
    'hourly_data': dataMap['hourly'],
    'updated_at': DateTime.now().toIso8601String(),
  });
} catch (e) {
  print('⚠️ Auto-Registration Failed: $e');
}

      await _saveToCache(box, cacheKey, weatherData);
      
      // Schedule background local notifications with exact real data
      try {
        final locBox = await Hive.openBox('settings');
        final isEnabled = locBox.get('weather_notifications_enabled', defaultValue: true);
        if (isEnabled && weekly.isNotEmpty) {
          await NotificationService.scheduleDailyWeatherNotifications(
            location.city,
            weekly[0].maxTemp,
            weekly[0].minTemp,
          );
        }
      } catch (e) {
        print('Error scheduling weather notification: $e');
      }

      return weatherData;
    }
  } catch (e) {
    print('❌ OpenMeteo Error: $e');
  }

  if (cached != null) return _mapFromCache(cached);

  return WeatherData(
    condition: 'Clear', temp: '32°C', forecast: 'Normal', advisory: 'Safe to work.',
    iconType: 'Clear', lastUpdated: DateTime.now(), sunrise: '06:00', sunset: '18:30',
    windSpeed: 0, currentRain: 0, weeklyForecast: [], hourlyForecast: [], uvIndex: 0.0, pressure: 1013.0, upcomingAlerts: [],
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
    'hourlyForecast': data.hourlyForecast.map((e) => e.toJson()).toList(),
    'uvIndex': data.uvIndex,
    'pressure': data.pressure,
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
    hourlyForecast: (cached['hourlyForecast'] as List? ?? []).map((e) => HourlyForecast.fromJson(e)).toList(),
    uvIndex: (cached['uvIndex'] as num?)?.toDouble() ?? 0.0,
    pressure: (cached['pressure'] as num?)?.toDouble() ?? 1013.0,
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
  if (code >= 1 && code <= 3) return {'label': 'Partly Cloudy', 'icon': 'PartlyCloudy'};
  if (code >= 45 && code <= 48) return {'label': 'Foggy', 'icon': 'Foggy'};
  if (code >= 51 && code <= 55) return {'label': 'Light Rain', 'icon': 'LightRain'};
  if (code >= 56 && code <= 67) return {'label': 'Raining', 'icon': 'Rain'};
  if (code >= 71 && code <= 77) return {'label': 'Snowing', 'icon': 'Snow'};
  if (code >= 80 && code <= 82) return {'label': 'Heavy Rain', 'icon': 'HeavyRain'};
  if (code >= 95) return {'label': 'Thunderstorm', 'icon': 'Thunderstorm'};
  return {'label': 'Cloudy', 'icon': 'Clouds'};
}
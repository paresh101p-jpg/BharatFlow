import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bharat_flow/main.dart';
import 'package:bharat_flow/features/notifications/presentation/screens/notification_history_screen.dart';
import 'package:bharat_flow/features/news/presentation/screens/market_news_hub_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/mandi_intelligence_screen.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/favorites_alerts_screen.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/weather_impact_screen.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/mandi_calendar_screen.dart';
import 'package:bharat_flow/features/store/presentation/screens/product_details_screen.dart';
import 'package:bharat_flow/features/fuel/presentation/screens/fuel_prices_screen.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:bharat_flow/core/constants/api_keys.dart';
import 'package:bharat_flow/core/services/config_service.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init({bool isBackground = false}) async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/notif_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        handlePayload(response.payload);
      },
    );

    if (!isBackground) {
      // Request runtime permission for Android 13+ (API 33+)
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();

      // Schedule daily fuel price notification for exactly 6:05 AM IST
      try {
        await scheduleDailyFuelNotification();
      } catch (e) {
        debugPrint("NotificationService: Error scheduling daily fuel notification: $e");
      }

      // Schedule daily news notifications (Morning 8 AM, Evening 6:30 PM)
      try {
        await scheduleDailyNewsNotifications();
      } catch (e) {
        debugPrint("NotificationService: Error scheduling daily news notifications: $e");
      }

      // Schedule daily Mandi price alert check (7 PM)
      try {
        await scheduleDailyMandiAlertNotification();
      } catch (e) {
        debugPrint("NotificationService: Error scheduling daily Mandi alert notification: $e");
      }

      // Fetch FCM Token and save to Supabase
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            await Supabase.instance.client
                .from('profiles')
                .update({'fcm_token': fcmToken})
                .eq('id', userId);
            debugPrint("NotificationService: Saved FCM Token to profile.");
          }
        }
      } catch (e) {
        debugPrint("NotificationService: Error saving FCM Token: $e");
      }
    }
  }

  static Future<NotificationResponse?> getInitialNotification() async {
    final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse;
    }
    return null;
  }

  static void handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
      );
      return;
    }

    try {
      final data = json.decode(payload);
      final type = data['type'];

      if (type == 'news') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MarketNewsHubScreen()),
        );
      } else if (type == 'festival') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MandiCalendarScreen()),
        );
      } else if (type == 'price') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const FavoritesAlertsScreen()),
        );
      } else if (type == 'weather') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const WeatherImpactScreen()),
        );
      } else if (type == 'store_match') {
        final product = data['product'];
        if (product != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: Map<String, dynamic>.from(product))),
          );
        }
      } else if (type == 'fuel' || type == 'fuel_daily') {
        final context = navigatorKey.currentState?.context;
        if (context != null) {
          final box = Hive.box('settings');
          final lockKey = 'fuel';
          final unlockStr = box.get('unlock_until_$lockKey');
          bool isUnlocked = false;
          if (unlockStr != null) {
            final unlockTime = DateTime.tryParse(unlockStr);
            if (unlockTime != null && unlockTime.isAfter(DateTime.now())) {
              isUnlocked = true;
            }
          }

          if (isUnlocked || !AdmobService.hasRewardedAd) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const FuelPricesScreen()),
            );
          } else {
            AdmobService.showRewardConfirmationDialog(
              context,
              () {
                box.put('unlock_until_$lockKey', DateTime.now().add(const Duration(hours: 24)).toIso8601String());
                navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (_) => const FuelPricesScreen()),
                );
              },
            );
          }
        } else {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const FuelPricesScreen()),
          );
        }
      } else {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
        );
      }
    } catch (e) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
      );
    }
  }

  static Future<void> showNotification(String title, String body, {String? payload}) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'news_channel',
      'Bharat Flow Alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(body),
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    // Generate a unique ID to prevent consecutive notifications from overwriting each other
    final int notifId = DateTime.now().millisecondsSinceEpoch % 100000;
    await _notificationsPlugin.show(notifId, title, body, platformChannelSpecifics, payload: payload);

    // Save to history
    await _saveToHistory(title, body, payload);
  }

  static Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    } catch (e) {
      debugPrint("NotificationService: Error scheduling exact alarm: $e. Falling back to inexact alarm...");
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchDateTimeComponents,
          payload: payload,
        );
        debugPrint("NotificationService: Fallback to inexact alarm successful for ID: $id");
      } catch (err) {
        debugPrint("NotificationService: Error scheduling fallback inexact alarm: $err");
      }
    }
  }

  static Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledDate, {String? payload}) async {
    tz.initializeTimeZones();
    final scheduledDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDateTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'festival_channel',
          'Festival Notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/notif_icon',
        ),
      ),
      payload: payload,
    );

    print('⏰ Notification scheduled for: $scheduledDateTime');
  }

  static Future<void> clearAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (e) {
      debugPrint("Error subscribing to topic: $e");
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint("Error unsubscribing from topic: $e");
    }
  }

  static Future<void> scheduleDailyFuelNotification() async {
    tz.initializeTimeZones();
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 6, 5);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _safeZonedSchedule(
      id: 1001,
      title: "⛽ Aaj Ke Fuel Daam",
      body: "Apke shehar mein petrol aur diesel ke naye daam check karein.",
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fuel_channel',
          'Fuel Price Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: json.encode({'type': 'fuel_daily'}),
    );
  }

  static Future<void> scheduleDailyNewsNotifications() async {
    tz.initializeTimeZones();
    final now = tz.TZDateTime.now(tz.local);
    
    // 8:00 AM Notification
    tz.TZDateTime morningDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
    if (morningDate.isBefore(now)) {
      morningDate = morningDate.add(const Duration(days: 1));
    }
    
    await _safeZonedSchedule(
      id: 7777,
      title: "📰 Subah Ki Taza Khabar",
      body: "Kisan aur kheti se judi aaj ki sabse badi khabarein padhein.",
      scheduledDate: morningDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'news_daily_channel',
          'Daily News Updates',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/notif_icon',
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: json.encode({'type': 'news'}),
    );

    // 6:30 PM Notification
    tz.TZDateTime eveningDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 30);
    if (eveningDate.isBefore(now)) {
      eveningDate = eveningDate.add(const Duration(days: 1));
    }

    await _safeZonedSchedule(
      id: 7778,
      title: "📰 Sham Ki Taza Khabar",
      body: "Kheti aur mandi ke naye updates janne ke liye abhi tap karein.",
      scheduledDate: eveningDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'news_daily_channel',
          'Daily News Updates',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/notif_icon',
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: json.encode({'type': 'news'}),
    );
  }

  static Future<void> scheduleDailyWeatherNotifications(String city, int maxTemp, int minTemp) async {
    tz.initializeTimeZones();
    final now = tz.TZDateTime.now(tz.local);
    
    // Morning 8:00 AM Notification
    tz.TZDateTime morningDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
    if (morningDate.isBefore(now)) {
      morningDate = morningDate.add(const Duration(days: 1));
    }
    
    await _safeZonedSchedule(
      id: 8881,
      title: "🌤️ Aaj Ka Mausam ($city)",
      body: "Aaj $city mein adhiktam tapman $maxTemp°C aur nyuntam $minTemp°C rahega.",
      scheduledDate: morningDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'weather_daily_channel',
          'Daily Weather Updates',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/notif_icon',
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: json.encode({'type': 'weather'}),
    );

    // Evening 6:00 PM Notification
    tz.TZDateTime eveningDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 0);
    if (eveningDate.isBefore(now)) {
      eveningDate = eveningDate.add(const Duration(days: 1));
    }

    await _safeZonedSchedule(
      id: 8882,
      title: "🌙 Aaj Raat Ka Mausam ($city)",
      body: "Aaj raat ka nyuntam tapman $minTemp°C tak ja sakta hai. Kal ke forecast ke liye tap karein.",
      scheduledDate: eveningDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'weather_daily_channel',
          'Daily Weather Updates',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/notif_icon',
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: json.encode({'type': 'weather'}),
    );
  }

  static Future<void> scheduleDailyMandiAlertNotification() async {
    tz.initializeTimeZones();
    final now = tz.TZDateTime.now(tz.local);
    
    // 7:00 PM Notification
    tz.TZDateTime alertDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19, 0);
    if (alertDate.isBefore(now)) {
      alertDate = alertDate.add(const Duration(days: 1));
    }
    
    await _safeZonedSchedule(
      id: 7779,
      title: "🔔 Mandi Price Alerts",
      body: "Mandi ke naye bhav aa chuke hain! Tap karke apne set kiye hue alerts check karein.",
      scheduledDate: alertDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'price_alert_daily_channel',
          'Daily Price Alerts',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/notif_icon',
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: json.encode({'type': 'price'}),
    );
  }

  static Future<void> scheduleFertilizerAlerts(String cropName, DateTime sowingDate) async {
    tz.initializeTimeZones();
    
    // Day 20: 1st Top Dressing
    final day20 = sowingDate.add(const Duration(days: 20));
    final day20tz = tz.TZDateTime.from(day20, tz.local).add(const Duration(hours: 7)); // 7 AM
    if (day20tz.isAfter(tz.TZDateTime.now(tz.local))) {
      await _safeZonedSchedule(
        id: (cropName.hashCode + 20) % 100000,
        title: "🌿 Fertilizer Alert: $cropName",
        body: "Aaj $cropName mein 1st Top Dressing (Urea) dalne ka din hai. Khet mein check karein!",
        scheduledDate: day20tz,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'farm_alerts',
            'Farm Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }

    // Day 45: 2nd Top Dressing
    final day45 = sowingDate.add(const Duration(days: 45));
    final day45tz = tz.TZDateTime.from(day45, tz.local).add(const Duration(hours: 7)); // 7 AM
    if (day45tz.isAfter(tz.TZDateTime.now(tz.local))) {
      await _safeZonedSchedule(
        id: (cropName.hashCode + 45) % 100000,
        title: "🌿 Fertilizer Alert: $cropName",
        body: "Aaj $cropName mein 2nd Top Dressing (Urea + Potash) dalne ka din hai. Fasal ki growth badhayein!",
        scheduledDate: day45tz,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'farm_alerts',
            'Farm Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  static Future<void> _saveToHistory(String title, String body, String? payload) async {
    try {
      final box = await Hive.openBox('notification_history');
      String type = 'news';
      if (payload != null) {
        final data = json.decode(payload);
        type = data['type'] ?? 'news';
      }

      await box.add({
        'title': title,
        'body': body,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Background mein Hive aur Supabase initialize karna zaroori hai
      await Hive.initFlutter();
      
      // ✅ Initialize Notification Service in the background isolate!
      await NotificationService.init(isBackground: true);
      
      final alertsBox = await Hive.openBox('mandi_alerts');
      final favBox = await Hive.openBox('product_favorites');
      final locBox = await Hive.openBox('settings');
      final stateBox = await Hive.openBox('notification_states'); // State tracking box
      final String lang = locBox.get('language', defaultValue: 'en');
      
      final double lat = locBox.get('last_lat') ?? 21.17;
      final double lng = locBox.get('last_lng') ?? 72.83;

      SupabaseClient? supabase;
      try {
        await Supabase.initialize(
          url: ApiKeys.supabaseUrl,
          anonKey: ApiKeys.supabaseAnonKey,
        );
        supabase = Supabase.instance.client;
      } catch (_) {
        try { 
          supabase = Supabase.instance.client; 
        } catch(_) {}
      }

      // Initialize ConfigService separately so it always runs
      try {
        await ConfigService.initialize();
      } catch (_) {}
      
      if (supabase == null) return Future.value(true); // Stop quietly if no DB

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. NEWS SYNC & CHECK (Decoupled sync and notifications with robust RSS feeds)
      try {
        final lastFetchStr = stateBox.get('last_news_fetch_time');
        final lastFetch = lastFetchStr != null ? DateTime.parse(lastFetchStr) : DateTime.fromMillisecondsSinceEpoch(0);
        
        // 1a. Background News Sync is now handled by VPS
        // News fetching logic removed from client.
      } catch (_) {}

      // 1b. News Notification Trigger (Completely decoupled from the fetching process!)
      try {
        final news = await supabase!.from('app_news').select().order('published_at', ascending: false).limit(1);
        if ((news as List).isNotEmpty) {
          final newsId = news[0]['source_url'].toString();
          if (stateBox.get('last_news_notif_url') != newsId) {
            // ✅ CHECK NEWS NOTIFICATION SETTING
            final isNewsEnabled = locBox.get('news_notifications', defaultValue: true);
            if (isNewsEnabled) {
              String decodeAndStrip(String text) {
                String s = text
                  .replaceAll('&lt;', '<')
                  .replaceAll('&gt;', '>')
                  .replaceAll('&quot;', '"')
                  .replaceAll('&amp;', '&')
                  .replaceAll('&#39;', "'")
                  .replaceAll(RegExp(r'&\w+;'), ''); // Strip other entities

                s = s.replaceAll(RegExp(r'<[^>]*>'), ''); // Strip closed tags
                
                // Remove truncated tags at the end (e.g. <a href="... without >)
                final lastOpen = s.lastIndexOf('<');
                final lastClose = s.lastIndexOf('>');
                if (lastOpen != -1 && lastOpen > lastClose) {
                  s = s.substring(0, lastOpen);
                }
                
                return s.trim();
              }
              final titleRaw = news[0]['title']?.toString() ?? '';
              final summaryRaw = news[0]['summary']?.toString() ?? '';
              final titleClean = decodeAndStrip(titleRaw);
              final summaryClean = decodeAndStrip(summaryRaw);
              
              final titleStr = titleClean.isEmpty ? 'News' : titleClean;
              final sumStrHi = summaryClean.isEmpty ? 'सरकारी योजना और खेती की जानकारी देखें।' : summaryClean;
              final sumStrEn = summaryClean.isEmpty ? 'Check latest schemes and agri info.' : summaryClean;

              await NotificationService.showNotification(
                lang == 'hi' ? "📢 नयी ख़बर: $titleStr" : "📢 Latest News: $titleStr", 
                lang == 'hi' ? "$sumStrHi\n\n• पूरा पढ़ने के लिए टैप करें।" : "$sumStrEn\n\n• Tap to read full.",
                payload: json.encode({'type': 'news', 'url': newsId})
              );
            }
            await stateBox.put('last_news_notif_url', newsId);
          }
        }
      } catch (_) {}

      // 2. WEATHER RISK CHECK (14-DAY ADVANCED SCAN)
      try {
        final isEnabled = locBox.get('weather_notifications_enabled', defaultValue: true);
        if (isEnabled) {
          final weatherUrl = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code,wind_speed_10m,precipitation&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max&timezone=auto&forecast_days=14';
          final wRes = await http.get(Uri.parse(weatherUrl)).timeout(const Duration(seconds: 20));
          
          if (wRes.statusCode == 200) {
            final wData = json.decode(wRes.body);
            final current = wData['current'];
            final daily = wData['daily'];
            final double rain = (current['precipitation'] as num).toDouble();
            final double wind = (current['wind_speed_10m'] as num).toDouble();
            final List dailyProbs = daily['precipitation_probability_max'];
            final List dailyWinds = daily['wind_speed_10m_max'];
            final List dailyMaxTemp = daily['temperature_2m_max'];
            final List dailyMinTemp = daily['temperature_2m_min'];
            
            // Schedule the daily exact notifications (8 AM and 6 PM) in the background!
            final cityStr = locBox.get('last_city', defaultValue: 'Aapke shehar');
            await NotificationService.scheduleDailyWeatherNotifications(
              cityStr, 
              (dailyMaxTemp[0] as num).round(), 
              (dailyMinTemp[0] as num).round()
            );

            String? alertTitle;
            String? alertBody;
            String alertType = "none";

            if (rain >= 50) {
              alertTitle = lang == 'hi' ? "🚨 भारी बारिश अलर्ट" : "🚨 HEAVY RAIN ALERT";
              alertBody = lang == 'hi' ? "आपके क्षेत्र में भारी बारिश ($rain mm) हो रही है!" : "Heavy rain ($rain mm) is happening in your area!";
              alertType = "immediate_heavy_rain";
            } else if (wind >= 60) {
              alertTitle = lang == 'hi' ? "🚩 तूफ़ान अलर्ट" : "🚩 STORM ALERT";
              alertBody = lang == 'hi' ? "तेज़ हवाएं ($wind km/h) चल रही हैं। सावधान रहें!" : "Strong winds ($wind km/h) are blowing. Stay safe!";
              alertType = "immediate_cyclone";
            } else if (dailyProbs.sublist(0, 2).any((p) => (p as num) > 70)) {
              alertTitle = lang == 'hi' ? "📅 48 घंटे बारिश की संभावना" : "📅 48h RAIN FORECAST";
              alertBody = lang == 'hi' ? "अगले 2 दिनों में बारिश होने की पक्की संभावना है। तैयारी रखें।" : "High chance of rain in the next 48 hours. Be prepared.";
              alertType = "planning_48h";
            } else {
              int startDay = -1;
              int endDay = -1;
              String riskType = "";
              for (int i = 2; i < 14; i++) {
                if ((dailyWinds[i] as num) > 50 || (dailyProbs[i] as num) > 80) {
                  if (startDay == -1) {
                    startDay = i;
                    riskType = (dailyWinds[i] as num) > 50 ? (lang == 'hi' ? "तूफ़ान" : "Storm") : (lang == 'hi' ? "भारी बारिश" : "Heavy Rain");
                  }
                  endDay = i;
                } else if (startDay != -1) break;
              }

              if (startDay != -1) {
                final startDate = DateFormat('dd MMM').format(DateTime.now().add(Duration(days: startDay)));
                final endDate = DateFormat('dd MMM').format(DateTime.now().add(Duration(days: endDay)));
                alertTitle = lang == 'hi' ? "📡 जोखिम का समय: $riskType" : "📡 RISK WINDOW: $riskType";
                alertBody = (startDay == endDay) 
                    ? (lang == 'hi' ? "$startDate को $riskType की संभावना है।" : "Possibility of $riskType on $startDate.") 
                    : (lang == 'hi' ? "$startDate से $endDate तक $riskType चलने की संभावना है। तैयारी रखें!" : "Possibility of $riskType from $startDate to $endDate. Be prepared!");
                alertType = "long_term_risk_window";
              }
            }

            if (alertTitle != null) {
              String lastNotifType = stateBox.get('last_weather_alert_type') ?? "none";
              String lastNotifDay = stateBox.get('last_weather_alert_day') ?? "";
              String currentDay = DateFormat('yyyy-MM-dd').format(DateTime.now());
              if (lastNotifType != alertType || lastNotifDay != currentDay) {
                NotificationService.showNotification(alertTitle, alertBody!, payload: json.encode({'type': 'weather'}));
                await stateBox.put('last_weather_alert_type', alertType);
                await stateBox.put('last_weather_alert_day', currentDay);
              }
            }

            // Background scanning for monitored crop-specific sowing dates risks!
            try {
              final cropsBox = await Hive.openBox('weather_selected_crops');
              final selectedCrops = cropsBox.values.cast<String>().toList();
              
              for (var crop in selectedCrops) {
                final intelRes = await supabase!.from('crop_intelligence').select().eq('name', crop).maybeSingle();
                if (intelRes != null) {
                  final rainSensitive = intelRes['rain_sensitive'] ?? false;
                  final windSensitive = intelRes['wind_sensitive'] ?? false;
                  final List sowMonths = List<String>.from(intelRes['sow_months'] ?? []);
                  
                  final savedSowDateStr = locBox.get('sow_date_$crop');
                  final sowingDate = savedSowDateStr != null ? DateTime.parse(savedSowDateStr) : DateTime.now();
                  
                  DateTime? riskDate;
                  String riskType = '';
                  
                  for (int offset = 0; offset < 14; offset++) {
                    final targetDate = sowingDate.add(Duration(days: offset));
                    
                    final hasRealForecast = dailyProbs.length > offset;
                    if (hasRealForecast) {
                      final diffDays = targetDate.difference(DateTime.now()).inDays;
                      if (diffDays >= 0 && diffDays < 14) {
                        final precipProb = (dailyProbs[diffDays] as num).toDouble();
                        final windSpeed = (dailyWinds[diffDays] as num).toDouble();
                        
                        if (precipProb > 60 && rainSensitive) {
                          riskDate = targetDate;
                          riskType = 'Heavy Rain';
                          break;
                        }
                        if (windSpeed > 40 && windSensitive) {
                          riskDate = targetDate;
                          riskType = 'Strong Winds';
                          break;
                        }
                      } else {
                        // Check out of season month
                        final monthStr = DateFormat('MMM').format(targetDate);
                        if (!sowMonths.contains(monthStr)) {
                          riskDate = targetDate;
                          riskType = 'Out of Season ($monthStr)';
                          break;
                        }
                      }
                    }
                  }
                  
                  if (riskDate != null) {
                    final formattedDate = DateFormat('dd MMM').format(riskDate);
                    final alertKey = 'bg_crop_alert_${crop}_${riskType}_$formattedDate';
                    
                    final String lastState = stateBox.get(alertKey) ?? "Normal";
                    if (lastState == "Normal") {
                      String msg = riskType.contains('Out of Season')
                          ? (lang == 'hi' ? 'उच्च जोखिम: $crop की बुवाई ${DateFormat('dd MMM').format(sowingDate)} को $riskType में शुरू होती है। बुवाई की सलाह नहीं है।' : 'High Risk: $crop planting on ${DateFormat('dd MMM').format(sowingDate)} starts in $riskType. Planting is not recommended.')
                          : (lang == 'hi' ? '$formattedDate पर उच्च जोखिम: आपके $crop बुवाई कार्यक्रम के लिए $riskType की भविष्यवाणी की गई है।' : 'High Risk on $formattedDate: $riskType predicted for your $crop sowing schedule.');
                          
                      await NotificationService.showNotification(
                        lang == 'hi' ? "🚨 उच्च जोखिम अलर्ट: $crop" : "🚨 High Risk Alert: $crop", 
                        msg,
                        payload: json.encode({'type': 'weather'})
                      );
                      await stateBox.put(alertKey, "Triggered");
                    }
                  }
                }
              }
            } catch (_) {}
          }
        }
      } catch(_) {}

      // 3. PRICE ALERT CHECK
      try {
        final isEnabled = locBox.get('price_alerts', defaultValue: true);
        if (isEnabled) {
          final alertsBox = await Hive.openBox('mandi_alerts');
          final alerts = alertsBox.values.toList();
          if (alerts.isNotEmpty) {
            for (var alert in alerts) {
              final commodity = alert['commodity'];
              final mandiName = alert['mandiName'];
              final targetPrice = (alert['targetPrice'] as num?)?.toDouble() ?? 0.0;
              final isAbove = alert['isAbove'] ?? true;
              final alertKey = 'price_${commodity}_${mandiName}_$targetPrice';

              var query = supabase!.from('mandi_prices').select('modal_price, mandi_name').eq('commodity_name', commodity);
              if (mandiName != null && mandiName.toString().isNotEmpty) query = query.eq('mandi_name', mandiName);
              final res = await query.order('arrival_date', ascending: false).order('sync_at', ascending: false).limit(1);
              
              if ((res as List).isNotEmpty) {
                final double livePrice = (res[0]['modal_price'] as num).toDouble();
                bool isTriggered = isAbove ? livePrice >= targetPrice : livePrice <= targetPrice;
                String lastState = stateBox.get(alertKey) ?? "Normal";
                
                if (isTriggered && lastState == "Normal") {
                  NotificationService.showNotification(
                    lang == 'hi' ? "💰 भाव अलर्ट: $commodity" : "💰 Price Alert: $commodity", 
                    lang == 'hi' ? "भाव ₹$livePrice हो गया है! (लक्ष्य: ₹$targetPrice)" : "Price reached ₹$livePrice! (Target: ₹$targetPrice)", 
                    payload: json.encode({'type': 'price', 'commodity': commodity})
                  );
                }
                await stateBox.put(alertKey, isTriggered ? "Triggered" : "Normal");

                // ✅ UPDATE LIVE PRICE IN ALERTS BOX
                final Map<String, dynamic> updatedAlert = Map<String, dynamic>.from(alert);
                updatedAlert['currentPrice'] = livePrice;
                updatedAlert['isHit'] = isTriggered;
                updatedAlert['arrivalDate'] = res[0]['arrival_date'] ?? alert['arrivalDate'];
                await alertsBox.put(commodity, updatedAlert);
              }
            }
          }
        }
      } catch(_) {}

      // 4. FUEL PRICE CHECK
      try {
        final isFuelEnabled = locBox.get('fuel_notifications', defaultValue: true);
        if (isFuelEnabled) {
          final fuelRes = await supabase!
              .from('fuel_prices')
              .select('petrol, city')
              .ilike('city', '%Surat%')
              .limit(1)
              .maybeSingle();
              
          if (fuelRes != null) {
            final double currentPrice = (fuelRes['petrol'] as num).toDouble();
            final String lastPriceKey = 'last_petrol_price_${fuelRes['city']}';
            final double lastPrice = stateBox.get(lastPriceKey) ?? 0.0;

            if (lastPrice > 0 && lastPrice != currentPrice) {
              final diff = (currentPrice - lastPrice).toStringAsFixed(2);
              final direction = currentPrice > lastPrice ? (lang == 'hi' ? "बढ़ गया" : "Up") : (lang == 'hi' ? "कम हो गया" : "Down");
              NotificationService.showNotification(
                lang == 'hi' ? "⛽ ईंधन भाव अपडेट" : "⛽ Fuel Price Update", 
                lang == 'hi' ? "${fuelRes['city']} में पेट्रोल ₹$currentPrice ($direction ₹$diff) हो गया है।" : "Petrol in ${fuelRes['city']} is now ₹$currentPrice ($direction ₹$diff).",
                payload: json.encode({'type': 'fuel'})
              );
            }
            await stateBox.put(lastPriceKey, currentPrice);
          }
        }
      } catch(_) {}

      // 5. GOLD & SILVER PRICE CHECK
      try {
        final goldRes = await http.get(Uri.parse('https://api.gold-api.com/price/XAU/INR')).timeout(const Duration(seconds: 10));
        final silverRes = await http.get(Uri.parse('https://api.gold-api.com/price/XAG/INR')).timeout(const Duration(seconds: 10));

        if (goldRes.statusCode == 200 && silverRes.statusCode == 200) {
          final goldData = json.decode(goldRes.body);
          final silverData = json.decode(silverRes.body);

          final rawGold = (goldData['price'] as num).toDouble();
          final pricePerGramGold = (rawGold / 31.1035) * 1.03;
          final double currentGold = (pricePerGramGold * 10).round().toDouble();
          
          final pricePerGramSilver = ((silverData['price'] as num) / 31.1035) * 1.05;
          final double currentSilver = (pricePerGramSilver * 1000).round().toDouble();

          final double lastGold = stateBox.get('last_bg_gold_price') ?? 0.0;
          final double lastSilver = stateBox.get('last_bg_silver_price') ?? 0.0;

          // Trigger notification if gold changes by Rs 100 or silver by Rs 150 (to avoid spamming 1 Rs changes)
          if (lastGold > 0 && (currentGold - lastGold).abs() >= 100) {
            final diff = (currentGold - lastGold).abs().toStringAsFixed(0);
            final direction = currentGold > lastGold ? (lang == 'hi' ? "बढ़ गया 📈" : "Up 📈") : (lang == 'hi' ? "गिर गया 📉" : "Down 📉");
            NotificationService.showNotification(
              lang == 'hi' ? "🌟 सोने का भाव अलर्ट" : "🌟 Gold Price Alert", 
              lang == 'hi' ? "सोना ₹$diff $direction! नया भाव: ₹$currentGold/10g" : "Gold ₹$diff $direction! New Price: ₹$currentGold/10g",
            );
            await stateBox.put('last_bg_gold_price', currentGold);
          } else if (lastGold == 0) {
            await stateBox.put('last_bg_gold_price', currentGold);
          }

          if (lastSilver > 0 && (currentSilver - lastSilver).abs() >= 150) {
            final diff = (currentSilver - lastSilver).abs().toStringAsFixed(0);
            final direction = currentSilver > lastSilver ? (lang == 'hi' ? "बढ़ गई 📈" : "Up 📈") : (lang == 'hi' ? "गिर गई 📉" : "Down 📉");
            NotificationService.showNotification(
              lang == 'hi' ? "🥈 चांदी का भाव अलर्ट" : "🥈 Silver Price Alert", 
              lang == 'hi' ? "चांदी ₹$diff $direction! नया भाव: ₹$currentSilver/kg" : "Silver ₹$diff $direction! New Price: ₹$currentSilver/kg",
            );
            await stateBox.put('last_bg_silver_price', currentSilver);

          } else if (lastSilver == 0) {
            await stateBox.put('last_bg_silver_price', currentSilver);
          }
        }
      } catch(_) {}

      // 6. NEW NETA NOTIFICATION CHECK
      try {
        final userCity = locBox.get('last_city');
        if (userCity != null && userCity.toString().isNotEmpty) {
          final res = await supabase!
              .from('leaders_master')
              .select('id, name, party, constituency')
              .eq('is_active', true)
              .ilike('constituency', '%$userCity%')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (res != null) {
            final latestNetaId = res['id'].toString();
            final lastNotifiedNetaId = stateBox.get('last_notified_neta_city_$userCity');

            if (lastNotifiedNetaId != latestNetaId) {
              final netaName = res['name'] ?? 'Naya Neta';
              final party = res['party'] ?? 'Independent';
              
              NotificationService.showNotification(
                lang == 'hi' ? "📢 नया नेता अलर्ट" : "📢 New Neta Alert",
                lang == 'hi' 
                    ? "$netaName ($party) अब आपके क्षेत्र से जनता की आवाज़ पर आ गए हैं!" 
                    : "$netaName ($party) is now on Janta Ki Awaaz from your area!",
              );
              
              await stateBox.put('last_notified_neta_city_$userCity', latestNetaId);
            }
          }
        }
      } catch(_) {}

      return Future.value(true);
    } catch (e) {
      return Future.value(true);
    }
  });
}

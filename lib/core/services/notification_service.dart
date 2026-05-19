import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:bharat_flow/main.dart';
import 'package:bharat_flow/features/notifications/presentation/screens/notification_history_screen.dart';
import 'package:bharat_flow/features/news/presentation/screens/market_news_hub_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/mandi_intelligence_screen.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/favorites_alerts_screen.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/weather_impact_screen.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/mandi_calendar_screen.dart';
import 'package:bharat_flow/features/store/presentation/screens/product_details_screen.dart';
import 'package:bharat_flow/core/constants/api_keys.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/notif_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        handlePayload(response.payload);
      },
    );

    // Request runtime permission for Android 13+ (API 33+)
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
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
    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics, payload: payload);

    // Save to history
    await _saveToHistory(title, body, payload);
  }

  static Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledDate, {String? payload}) async {
    tz.initializeTimeZones();
    final scheduledDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'festival_channel',
          'Festival Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    print('⏰ Notification scheduled for: $scheduledDateTime');
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
      await NotificationService.init();
      
      final alertsBox = await Hive.openBox('mandi_alerts');
      final favBox = await Hive.openBox('product_favorites');
      final locBox = await Hive.openBox('settings');
      final stateBox = await Hive.openBox('notification_states'); // State tracking box
      
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
        // If already initialized or no internet, try to get instance
        try { supabase = Supabase.instance.client; } catch(_) {}
      }
      
      if (supabase == null) return Future.value(true); // Stop quietly if no DB

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. NEWS SYNC & CHECK
      try {
        final lastFetchStr = stateBox.get('last_news_fetch_time');
        final lastFetch = lastFetchStr != null ? DateTime.parse(lastFetchStr) : DateTime.fromMillisecondsSinceEpoch(0);
        
        if (DateTime.now().difference(lastFetch).inHours >= 4) {
          final queries = ['PM Kisan Subsidy Scheme', 'Fasal Bima Yojana News', 'Kheti Nayi Technology', 'Kisan Mela Agri Expo'];
          final q = queries.join(' OR ');
          final gnewsUrl = 'https://gnews.io/api/v4/search?q=${Uri.encodeComponent(q)}&lang=hi&country=in&max=5&apikey=${ApiKeys.gnewsApiKey}';
          final response = await http.get(Uri.parse(gnewsUrl)).timeout(const Duration(seconds: 20));
          
          if (response.statusCode == 200) {
            final articles = json.decode(response.body)['articles'] as List;
            for (var art in articles) {
              await supabase!.from('app_news').upsert({
                'title': art['title'],
                'summary': art['description'] ?? '',
                'content': art['content'] ?? '',
                'image_url': art['image'],
                'source_url': art['url'],
                'published_at': DateTime.parse(art['publishedAt']).toIso8601String(),
              }, onConflict: 'source_url');
            }
            await stateBox.put('last_news_fetch_time', DateTime.now().toIso8601String());
          }
        }

        final news = await supabase!.from('app_news').select().order('published_at', ascending: false).limit(1);
        if ((news as List).isNotEmpty) {
          final newsId = news[0]['source_url'].toString();
          if (stateBox.get('last_news_notif_url') != newsId) {
            // ✅ CHECK NEWS NOTIFICATION SETTING
            final isNewsEnabled = locBox.get('news_notifications', defaultValue: true);
            if (isNewsEnabled) {
              NotificationService.showNotification(
                "📢 Nayi Khabar: ${news[0]['title']}", 
                "${news[0]['summary'] ?? 'Sarkari yojana aur kheti ki jankari dekhein.'}\n\n• Tap karke pura padhein.",
                payload: json.encode({'type': 'news', 'url': newsId})
              );
            }
            await stateBox.put('last_news_notif_url', newsId);
          }
        }
      } catch(_) {}

      // 2. WEATHER RISK CHECK (14-DAY ADVANCED SCAN)
      try {
        final isEnabled = locBox.get('weather_notifications_enabled', defaultValue: true);
        if (isEnabled) {
          final weatherUrl = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code,wind_speed_10m,precipitation&daily=precipitation_probability_max,wind_speed_10m_max&timezone=auto&forecast_days=14';
          final wRes = await http.get(Uri.parse(weatherUrl)).timeout(const Duration(seconds: 20));
          
          if (wRes.statusCode == 200) {
            final wData = json.decode(wRes.body);
            final current = wData['current'];
            final daily = wData['daily'];
            final double rain = (current['precipitation'] as num).toDouble();
            final double wind = (current['wind_speed_10m'] as num).toDouble();
            final List dailyProbs = daily['precipitation_probability_max'];
            final List dailyWinds = daily['wind_speed_10m_max'];
            
            String? alertTitle;
            String? alertBody;
            String alertType = "none";

            if (rain >= 50) {
              alertTitle = "🚨 BHAARI BAARISH ALERT";
              alertBody = "Aapke kshetra mein abhi bhari barish ($rain mm) ho rahi hai!";
              alertType = "immediate_heavy_rain";
            } else if (wind >= 60) {
              alertTitle = "🚩 TUFAN ALERT";
              alertBody = "Tez hawaayein ($wind km/h) chal rahi hain. Savdhan rahein!";
              alertType = "immediate_cyclone";
            } else if (dailyProbs.sublist(0, 2).any((p) => (p as num) > 70)) {
              alertTitle = "📅 48h BAARISH KI SAMBHAVNA";
              alertBody = "Agle 2 dino mein barish hone ki pakki sambhavna hai. Taiyari rakhein.";
              alertType = "planning_48h";
            } else {
              int startDay = -1;
              int endDay = -1;
              String riskType = "";
              for (int i = 2; i < 14; i++) {
                if ((dailyWinds[i] as num) > 50 || (dailyProbs[i] as num) > 80) {
                  if (startDay == -1) {
                    startDay = i;
                    riskType = (dailyWinds[i] as num) > 50 ? "Tufan" : "Bhari Baarish";
                  }
                  endDay = i;
                } else if (startDay != -1) break;
              }

              if (startDay != -1) {
                final startDate = DateFormat('dd MMM').format(DateTime.now().add(Duration(days: startDay)));
                final endDate = DateFormat('dd MMM').format(DateTime.now().add(Duration(days: endDay)));
                alertTitle = "📡 RISK WINDOW: $riskType";
                alertBody = (startDay == endDay) ? "$startDate ko $riskType ki sambhavna hai." : "$startDate se $endDate tak $riskType chalne ki sambhavna hai. Taiyari rakhein!";
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
                    "💰 Price Alert: $commodity", 
                    "Bhav ₹$livePrice ho gaya hai! (Target: ₹$targetPrice)", 
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
              final direction = currentPrice > lastPrice ? "Badh gaya" : "Kam ho gaya";
              NotificationService.showNotification(
                "⛽ Fuel Price Change", 
                "${fuelRes['city']} mein Petrol ₹$currentPrice ($direction ₹$diff) ho gaya hai.",
                payload: json.encode({'type': 'fuel'})
              );
            }
            await stateBox.put(lastPriceKey, currentPrice);
          }
        }
      } catch(_) {}

      return Future.value(true);
    } catch (e) {
      return Future.value(true);
    }
  });
}

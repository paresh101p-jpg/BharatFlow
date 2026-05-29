import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncService {
  static final _supabase = Supabase.instance.client;

  /// Restores data from Supabase to Hive locally.
  static Future<void> restoreFromCloud() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data == null) return;

      // Restore mandi favorites
      if (data['mandi_favorites'] != null) {
        final box = Hive.box('mandi_favorites');
        final List list = data['mandi_favorites'];
        for (var item in list) {
          box.put(item.toString(), true);
        }
      }

      // Restore product favorites
      if (data['product_favorites'] != null) {
        final box = Hive.box('product_favorites');
        final List list = data['product_favorites'];
        for (var item in list) {
          box.put(item.toString(), true);
        }
      }

      // Restore alerts
      if (data['alerts'] != null) {
        final box = Hive.box('mandi_alerts');
        final Map<String, dynamic> alerts = Map<String, dynamic>.from(data['alerts']);
        alerts.forEach((key, value) {
          box.put(key, value);
        });
      }
      
      debugPrint('✅ Cloud restore successful');
    } catch (e) {
      debugPrint('❌ Cloud restore error: $e');
    }
  }

  /// Saves local Hive data to Supabase.
  static Future<void> saveToCloud() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final mandiFavBox = Hive.box('mandi_favorites');
      final productFavBox = Hive.box('product_favorites');
      final alertsBox = Hive.box('mandi_alerts');

      final mandiFavs = mandiFavBox.keys.toList();
      final productFavs = productFavBox.keys.toList();
      
      final Map<String, dynamic> alerts = {};
      for (var key in alertsBox.keys) {
        alerts[key.toString()] = alertsBox.get(key);
      }

      await _supabase.from('user_preferences').upsert({
        'user_id': user.id,
        'mandi_favorites': mandiFavs,
        'product_favorites': productFavs,
        'alerts': alerts,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('✅ Cloud backup successful');
    } catch (e) {
      debugPrint('❌ Cloud backup error: $e');
    }
  }
}

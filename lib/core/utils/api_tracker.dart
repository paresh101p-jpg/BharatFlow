import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ApiTracker {
  static final _supabase = Supabase.instance.client;

  /// Log an API call asynchronously to track usage stats and daily limits
  static Future<void> logCall(String apiName, {int? statusCode}) async {
    try {
      final user = _supabase.auth.currentUser;
      // Asynchronous insert to ensure zero impact on main UI thread performance
      await _supabase.from('api_usage_logs').insert({
        'api_name': apiName,
        'status_code': statusCode,
        'user_id': user?.id,
      });
      debugPrint('📈 ApiTracker: Logged "$apiName" call with status: $statusCode');
    } catch (e) {
      debugPrint('⚠️ ApiTracker Log Error: $e');
    }
  }
}

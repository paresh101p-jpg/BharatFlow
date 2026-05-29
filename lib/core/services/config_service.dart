import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/api_keys.dart';

class ConfigService {
  static final Map<String, String> _configs = {};

  /// Load configurations from Supabase remote database with silent fallback to hardcoded keys
  static Future<void> initialize() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Try to fetch configs from database
      final response = await supabase
          .from('secure_remote_config')
          .select('config_key, config_value')
          .timeout(const Duration(seconds: 4));
          
      for (var row in response) {
        final key = row['config_key']?.toString();
        final value = row['config_value']?.toString();
        if (key != null && value != null) {
          _configs[key] = value;
        }
      }
      debugPrint('🛡️ [CONFIG] Secure Remote Config Loaded: ${_configs.length} items');
    } catch (e) {
      // Graceful error logging - do not crash the app!
      debugPrint('⚠️ [CONFIG] Dynamic config fetch failed (Using fallback keys): $e');
    }
  }

  /// Get config value dynamically. Falls back to static keys from ApiKeys if not found in db.
  static String get(String key, {String defaultValue = ''}) {
    if (_configs.containsKey(key)) {
      return _configs[key]!;
    }
    
    // Graceful fallback to frontend ApiKeys
    switch (key) {
      case 'gemini_api_key':
        return ApiKeys.geminiApiKey;
      case 'ai_service_gemini_key':
        return ApiKeys.aiServiceGeminiKey;
      case 'gemini_map_key':
        return ApiKeys.geminiMapKey;
      case 'gnews_api_key':
        return ApiKeys.gnewsApiKey;
      case 'govt_data_api_key':
        return ApiKeys.govtDataApiKey;
      case 'news_data_api_key':
        return ApiKeys.newsDataApiKey;
      case 'google_places_key':
        return ApiKeys.googlePlacesKey;
      case 'resend_api_key':
        return ApiKeys.resendApiKey;
      case 'google_web_client_id':
        return ApiKeys.googleWebClientId;
      default:
        return defaultValue;
    }
  }

  /// Check if a config key exists in remote database
  static bool hasKey(String key) {
    return _configs.containsKey(key);
  }
}

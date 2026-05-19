import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:translator/translator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/core/utils/api_tracker.dart';

class LanguageHelper {
  static final _translator = GoogleTranslator();
  static final _supabase = Supabase.instance.client;

  // State-to-Language Mapping (All 28 States + UTs)
  static const Map<String, String> indiaLanguageMap = {
    // Northern India
    "Punjab": "pa",
    "Haryana": "hi",
    "Himachal Pradesh": "hi",
    "Jammu and Kashmir": "ur",
    "Jammu & Kashmir": "ur",
    "Ladakh": "hi",
    "Uttarakhand": "hi",
    "Delhi": "hi",
    "Nct Of Delhi": "hi",
    "Uttar Pradesh": "hi",

    // Western India
    "Gujarat": "gu",
    "Maharashtra": "mr",
    "Rajasthan": "hi",
    "Goa": "gom",
    "Dadra and Nagar Haveli": "gu",
    "Dadra & Nagar Haveli": "gu",
    "Daman and Diu": "gu",
    "Daman & Diu": "gu",


    // Southern India
    "Karnataka": "kn",
    "Kerala": "ml",
    "Tamil Nadu": "ta",
    "Andhra Pradesh": "te",
    "Telangana": "te",
    "Puducherry": "ta",

    // Eastern India
    "West Bengal": "bn",
    "Odisha": "or",
    "Bihar": "hi",
    "Jharkhand": "hi",
    "Sikkim": "ne",

    // North-East
    "Assam": "as",
    "Arunachal Pradesh": "hi",
    "Manipur": "hi", // Manipur (Meitei) might not be in all versions
    "Meghalaya": "hi",
    "Mizoram": "hi", // Mizo
    "Nagaland": "hi",
    "Tripura": "bn",

    // Central India
    "Madhya Pradesh": "hi",
    "Chhattisgarh": "hi",
  };

  // City-specific Local feel
  static final Map<String, String> cityLanguageOverride = {
    "Surat": "gu",
    "Ahmedabad": "gu",
    "Mumbai": "mr",
    "Pune": "mr",
    "Amritsar": "pa",
    "Ludhiana": "pa",
  };

  static Future<String> translate(String text, String state, String city) async {
    if (text.trim().isEmpty) return text;

    final settingsBox = Hive.box('settings');
    final bool isAutoEnabled = settingsBox.get('auto_language_enabled', defaultValue: false);
    final String selectedLang = settingsBox.get('selected_language', defaultValue: 'English');

    String lang = "en";

    if (isAutoEnabled) {
      // Determine target language based on location
      String normalizedState = _capitalize(state.trim());
      String normalizedCity = _capitalize(city.trim());
      lang = cityLanguageOverride[normalizedCity] ?? indiaLanguageMap[normalizedState] ?? "hi";
    } else {
      // Use manual selection
      switch (selectedLang) {
        case 'Hindi': lang = 'hi'; break;
        case 'Gujarati': lang = 'gu'; break;
        case 'Punjabi': lang = 'pa'; break;
        case 'Marathi': lang = 'mr'; break;
        case 'Bengali': lang = 'bn'; break;
        case 'Telugu': lang = 'te'; break;
        case 'Tamil': lang = 'ta'; break;
        case 'Kannada': lang = 'kn'; break;
        case 'Malayalam': lang = 'ml'; break;
        default: lang = 'en';
      }
    }
    
    final translationBox = Hive.box('translations_cache');
    final String cacheKey = '${lang}_$text';

    // Special case: If target is English but input contains regional characters, translate to English
    bool containsRegional = text.runes.any((r) => r > 127);
    if (lang == "en" && containsRegional) {
      // Force translation from regional to English, bypass cache to ensure clean result
    } else {
      if (translationBox.containsKey(cacheKey)) {
        return translationBox.get(cacheKey);
      }
      if (lang == "en") return text; // Standard English, no translation needed
    }

    try {
      // Pre-process: If name has parentheses like "Yam(Ratalu)", try to extract local part
      String cleanText = text;
      if (text.contains('(') && text.contains(')')) {
        final regExp = RegExp(r'\((.*?)\)');
        final match = regExp.firstMatch(text);
        if (match != null && match.group(1) != null) {
          cleanText = match.group(1)!;
        }
      }

      // 2. Check Supabase Cache with Timeout
      final existing = await _supabase
          .from('translations_cache')
          .select('translated_text')
          .eq('original_text', cleanText)
          .eq('target_lang', lang)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (existing != null) {
        final result = existing['translated_text'];
        await translationBox.put(cacheKey, result);
        return result;
      }

      // 3. Translate using Google Translator
      final translation = await _translator.translate(cleanText, to: lang)
          .timeout(const Duration(seconds: 5));
      ApiTracker.logCall('Gemini: AI Translation', statusCode: 200);
      final result = translation.text;

      // 4. Save to Local and Supabase Cache
      await translationBox.put(cacheKey, result);
      
      _supabase.from('translations_cache').upsert({
        'original_text': cleanText,
        'translated_text': result,
        'target_lang': lang,
      }).then((_) {}).catchError((e) {
        // Silently ignore RLS or network errors for translations
      });

      return result;
    } catch (e) {
      // Return original if language not supported or other error
      return text;
    }
  }

  static String getLanguageForLocation(String state, String city) {
    String normalizedState = _capitalize(state.trim());
    String normalizedCity = _capitalize(city.trim());
    return cityLanguageOverride[normalizedCity] ?? indiaLanguageMap[normalizedState] ?? "hi";
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}


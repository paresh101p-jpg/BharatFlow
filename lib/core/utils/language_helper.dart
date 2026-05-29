import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:translator/translator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/core/utils/api_tracker.dart';

class LanguageHelper {
  static final _translator = GoogleTranslator();
  static final _supabase = Supabase.instance.client;

  // Static Commodity Override Map for flawless instant offline translations
  static const Map<String, Map<String, String>> staticCommodityOverrides = {
    'dalchini': {
      'hi': 'दालचीनी',
      'gu': 'તજ (દાલચીની)',
      'pa': 'ਦਾਲਚੀਨੀ',
      'mr': 'दालचिनी',
      'bn': 'দারুচিনি',
      'te': 'దాల్చిన చెక్క',
      'ta': 'இலவங்கப்பட்டை',
      'kn': 'ದಾಲ್ಚಿನ್ನಿ',
      'ml': 'കറുവപ്പട്ട',
    },
    'cinnamon': {
      'hi': 'दालचीनी',
      'gu': 'તજ',
      'pa': 'ਦਾਲਚੀਨੀ',
      'mr': 'दालचिनी',
      'bn': 'দারুচিনি',
      'te': 'దాల్చిన చెక్క',
      'ta': 'இலவங்கப்பட்டை',
      'kn': 'ದಾಲ್ಚಿನ್ನಿ',
      'ml': 'കറുവപ്പട്ട',
    },
    'potato': {
      'hi': 'आलू',
      'gu': 'બટાકા',
      'pa': 'ਆਲੂ',
      'mr': 'बटाटा',
      'bn': 'আলু',
      'te': 'బంగాళాదుंप',
      'ta': 'உருளைக்கிழங்கு',
      'kn': 'ಆಲೂಗಡ್ಡೆ',
      'ml': 'ഉരുളക്കിഴങ്ങ്',
    },
    'onion': {
      'hi': 'प्याज',
      'gu': 'ડુંગળી',
      'pa': 'ਪਿਆਜ਼',
      'mr': 'कांदा',
      'bn': 'পেঁয়াজ',
      'te': 'ఉల్లిపాయ',
      'ta': 'வெங்காயம்',
      'kn': 'ಈರುಳ್ಳಿ',
      'ml': 'സവാള',
    },
    'tomato': {
      'hi': 'टमाटर',
      'gu': 'ટામેટા',
      'pa': 'ਟਮਾਟਰ',
      'mr': 'टोमॅटो',
      'bn': 'টমেটো',
      'te': 'టమోటా',
      'ta': 'தக்காளி',
      'kn': 'ಟೊಮೆಟೊ',
      'ml': 'തക്കാളി',
    },
    'wheat': {
      'hi': 'गेहूं',
      'gu': 'ઘઉં',
      'pa': 'ਕਣਕ',
      'mr': 'गहू',
      'bn': 'গম',
      'te': 'గోధుమలు',
      'ta': 'கோதுமை',
      'kn': 'ಗೋದೂಮಿ',
      'ml': 'ഗോതമ്പ്',
    },
    'rice': {
      'hi': 'चावल',
      'gu': 'ચોખા',
      'pa': 'ਚੌਲ',
      'mr': 'तांदूळ',
      'bn': 'চাল',
      'te': 'వరి',
      'ta': 'அரிசி',
      'kn': 'ಅಕ್ಕಿ',
      'ml': 'അരി',
    },
  };

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
    "Manipur": "hi",
    "Meghalaya": "hi",
    "Mizoram": "hi",
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

  // Heuristic validation: checks if a translation contains English letters when it should be Indic script
  static bool _isInvalidTranslation(String translated, String targetLang) {
    if (targetLang == 'en') return false;
    const nonLatinLangs = {
      'hi',
      'gu',
      'pa',
      'mr',
      'bn',
      'te',
      'ta',
      'kn',
      'ml'
    };
    if (!nonLatinLangs.contains(targetLang)) return false;

    // If target language is non-Latin, but translation contains Latin letters and no regional characters
    final hasLatin = RegExp(r'[a-zA-Z]').hasMatch(translated);
    final hasRegional = translated.runes.any((r) => r > 127);

    return hasLatin && !hasRegional;
  }

  static Future<String> translate(
      String text, String state, String city) async {
    if (text.trim().isEmpty) return text;

    final settingsBox = Hive.box('settings');
    final bool isAutoEnabled =
        settingsBox.get('auto_language_enabled', defaultValue: false);
    final String selectedLang =
        settingsBox.get('language', defaultValue: 'English');

    String lang = "en";

    if (isAutoEnabled) {
      // Determine target language based on location
      String normalizedState = _capitalize(state.trim());
      String normalizedCity = _capitalize(city.trim());
      lang = cityLanguageOverride[normalizedCity] ??
          indiaLanguageMap[normalizedState] ??
          "hi";
    } else {
      // Use manual selection
      switch (selectedLang) {
        case 'Hindi':
          lang = 'hi';
          break;
        case 'Gujarati':
          lang = 'gu';
          break;
        case 'Punjabi':
          lang = 'pa';
          break;
        case 'Marathi':
          lang = 'mr';
          break;
        case 'Bengali':
          lang = 'bn';
          break;
        case 'Telugu':
          lang = 'te';
          break;
        case 'Tamil':
          lang = 'ta';
          break;
        case 'Kannada':
          lang = 'kn';
          break;
        case 'Malayalam':
          lang = 'ml';
          break;
        default:
          lang = 'en';
      }
    }

    // 1. Static Commodity Override Map for flawless instant offline translations
    final cleanText = text.trim();
    final lowerCleanText = cleanText.toLowerCase();
    if (staticCommodityOverrides.containsKey(lowerCleanText)) {
      final translationMap = staticCommodityOverrides[lowerCleanText]!;
      if (translationMap.containsKey(lang)) {
        return translationMap[lang]!;
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
        final cachedVal = translationBox.get(cacheKey);
        if (!_isInvalidTranslation(cachedVal, lang)) {
          return cachedVal;
        }
      }
      if (lang == "en") return text; // Standard English, no translation needed
    }

    try {
      // Pre-process: If name has parentheses like "Yam(Ratalu)", try to extract local part
      String processedText = cleanText;
      if (cleanText.contains('(') && cleanText.contains(')')) {
        final regExp = RegExp(r'\((.*?)\)');
        final match = regExp.firstMatch(cleanText);
        if (match != null && match.group(1) != null) {
          processedText = match.group(1)!;
        }
      }

      // 2. Check Supabase Cache with Timeout
      final existing = await _supabase
          .from('translations_cache')
          .select('translated_text')
          .eq('original_text', processedText)
          .eq('target_lang', lang)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (existing != null) {
        final result = existing['translated_text'];
        if (!_isInvalidTranslation(result, lang)) {
          await translationBox.put(cacheKey, result);
          return result;
        }
      }

      // 3. Translate using Google Translator
      final translation = await _translator
          .translate(processedText, to: lang)
          .timeout(const Duration(seconds: 5));
      ApiTracker.logCall('Gemini: AI Translation', statusCode: 200);
      final result = translation.text;

      // 4. Save to Local and Supabase Cache
      await translationBox.put(cacheKey, result);

      _supabase
          .from('translations_cache')
          .upsert({
            'original_text': processedText,
            'translated_text': result,
            'target_lang': lang,
          })
          .then((_) {})
          .catchError((e) {
            // Silently ignore RLS or network errors for translations
          });

      return result;
    } catch (e) {
      // Return original if language not supported or other error
      return text;
    }
  }

  static Future<String> translateToEnglish(String text) async {
    if (text.trim().isEmpty) return text;
    bool containsRegional = text.runes.any((r) => r > 127);
    if (!containsRegional) return text; // Already English/ASCII

    try {
      final translation = await _translator
          .translate(text, to: 'en')
          .timeout(const Duration(seconds: 4));
      ApiTracker.logCall('GoogleTranslator: To English', statusCode: 200);
      return translation.text;
    } catch (e) {
      return text;
    }
  }

  static String getLanguageForLocation(String state, String city) {
    String normalizedState = _capitalize(state.trim());
    String normalizedCity = _capitalize(city.trim());
    return cityLanguageOverride[normalizedCity] ??
        indiaLanguageMap[normalizedState] ??
        "hi";
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

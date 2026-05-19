import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PanchangUtils {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> getPanchangForDate(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    try {
      // 1. Try to fetch from Supabase Cache
      final cached = await _supabase
          .from('panchang_cache')
          .select()
          .eq('date', dateStr)
          .maybeSingle();

      if (cached != null) {
        // Return cached data (ensure JSON types are correct)
        return {
          ...cached,
          'choghadiya': List<Map<String, String>>.from(
            (cached['choghadiya'] as List).map((item) => Map<String, String>.from(item))
          ),
        };
      }

      // 2. Not in cache, Fetch from API and Calculate
      final realData = await _fetchAndCalculate(date);

      // 3. Store in Supabase for future use
      await _supabase.from('panchang_cache').insert({
        'date': dateStr,
        ...realData,
        'choghadiya': realData['choghadiya'],
        'sowing_muhurat': realData['sowing_muhurat'],
        'harvesting_muhurat': realData['harvesting_muhurat'],
        'tractor_muhurat': realData['tractor_muhurat'],
      });

      return realData;
    } catch (e) {
      print('❌ Panchang Error: $e');
      // Fallback to local calculation if everything fails
      return _calculateLocal(date);
    }
  }

  static Future<Map<String, dynamic>> _fetchAndCalculate(DateTime date) async {
    // Fetch real Sunrise/Sunset from a free API
    // Using default lat/lng for India (Central) if no GPS
    double lat = 20.5937;
    double lng = 78.9629;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    String sunriseStr = "06:00 AM";
    String sunsetStr = "18:45 PM";

    try {
      final url = 'https://api.sunrise-sunset.org/json?lat=$lat&lng=$lng&date=$dateStr&formatted=0';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          DateTime sunR = DateTime.parse(data['results']['sunrise']).toLocal();
          DateTime sunS = DateTime.parse(data['results']['sunset']).toLocal();
          sunriseStr = DateFormat('hh:mm a').format(sunR);
          sunsetStr = DateFormat('hh:mm a').format(sunS);
        }
      }
    } catch (e) {
      print('API Error: $e');
    }

    return _calculateLocal(date, sunriseOverride: sunriseStr, sunsetOverride: sunsetStr);
  }

  static Map<String, dynamic> _calculateLocal(DateTime date, {String? sunriseOverride, String? sunsetOverride}) {
    DateTime refDate = DateTime(2024, 5, 8);
    int daysDiff = date.difference(refDate).inDays;

    // Tithi
    int tithiNum = (daysDiff % 30) + 1;
    String paksha = tithiNum <= 15 ? "Shukla Paksha" : "Krishna Paksha";
    int displayTithi = tithiNum <= 15 ? tithiNum : tithiNum - 15;
    final tithiNames = ["Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Purnima/Amavasya"];
    String tithiName = "$paksha ${tithiNames[displayTithi - 1]}";

    // Nakshatra
    final nakshatras = ["Ashwini", "Bharani", "Krithika", "Rohini", "Mrigashira", "Ardra", "Punarvasu", "Pushya", "Ashlesha", "Magha", "Purva Phalguni", "Uttara Phalguni", "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha", "Jyeshtha", "Mula", "Purva Ashadha", "Uttara Ashadha", "Shravana", "Dhanishta", "Shatabhisha", "Purva Bhadrapada", "Uttara Bhadrapada", "Revati"];
    String nakshatra = nakshatras[daysDiff % 27];

    // Yoga/Karan
    final yogas = ["Vishkumbha", "Preeti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda", "Sukarma", "Dhriti", "Shoola", "Ganda", "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra", "Siddhi", "Vyatipata", "Variyan", "Parigha", "Shiva", "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma", "Indra", "Vaidhriti"];
    String yoga = yogas[(daysDiff + 5) % 27];
    final karans = ["Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti", "Shakuni", "Chatushpada", "Naga", "Kinstughna"];
    String karan = karans[(daysDiff * 2) % 11];

    // Choghadiya
    DateTime sunR = _parseTime(date, sunriseOverride ?? "06:00 AM");
    DateTime sunS = _parseTime(date, sunsetOverride ?? "06:45 PM");
    List<Map<String, String>> dayChoghadiya = _calculateChoghadiya(sunR, sunS);

    // Abhijit
    Duration dayDuration = sunS.difference(sunR);
    DateTime midDay = sunR.add(dayDuration ~/ 2);
    DateTime abhijitStart = midDay.subtract(const Duration(minutes: 24));
    DateTime abhijitEnd = midDay.add(const Duration(minutes: 24));

    // --- KRISHI MUHURAT LOGIC ---
    String sowing = "Not Recommended";
    if (["Rohini", "Mrigashira", "Hasta", "Chitra", "Swati", "Anuradha", "Revati"].contains(nakshatra)) {
      sowing = "${DateFormat('hh:mm a').format(sunR.add(const Duration(hours: 1)))} - ${DateFormat('hh:mm a').format(sunR.add(const Duration(hours: 3)))}";
    } else if (displayTithi % 2 == 0) {
      sowing = "${DateFormat('hh:mm a').format(sunR.add(const Duration(hours: 2)))} - ${DateFormat('hh:mm a').format(sunR.add(const Duration(hours: 4)))}";
    }

    String harvesting = "Not Recommended";
    if (["Shravana", "Dhanishta", "Shatabhisha", "Rohini", "Ashwini", "Hasta"].contains(nakshatra)) {
      harvesting = "${DateFormat('hh:mm a').format(sunR.add(const Duration(hours: 3)))} - ${DateFormat('hh:mm a').format(sunR.add(const Duration(hours: 5)))}";
    } else {
      harvesting = "${DateFormat('hh:mm a').format(midDay.add(const Duration(hours: 1)))} - ${DateFormat('hh:mm a').format(midDay.add(const Duration(hours: 3)))}";
    }

    String tractor = "Not Recommended";
    if (["Pushya", "Ashwini", "Revati", "Mrigashira", "Hasta", "Chitra", "Swati"].contains(nakshatra)) {
      tractor = "${DateFormat('hh:mm a').format(sunR.add(const Duration(hours: 4)))} - ${DateFormat('hh:mm a').format(sunR.add(const Duration(hours: 6)))}";
    } else if (displayTithi >= 10 && displayTithi <= 12) {
      tractor = "${DateFormat('hh:mm a').format(midDay.subtract(const Duration(hours: 2)))} - ${DateFormat('hh:mm a').format(midDay)}";
    }

    return {
      'sunrise': sunriseOverride ?? DateFormat('hh:mm a').format(sunR),
      'sunset': sunsetOverride ?? DateFormat('hh:mm a').format(sunS),
      'tithi': tithiName,
      'nakshatra': nakshatra,
      'yoga': yoga,
      'karan': karan,
      'choghadiya': dayChoghadiya,
      'abhijit': "${DateFormat('hh:mm a').format(abhijitStart)} - ${DateFormat('hh:mm a').format(abhijitEnd)}",
      'sowing_muhurat': sowing,
      'harvesting_muhurat': harvesting,
      'tractor_muhurat': tractor,
    };
  }

  static DateTime _parseTime(DateTime date, String timeStr) {
    try {
      final format = DateFormat('hh:mm a');
      final parsed = format.parse(timeStr);
      return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
    } catch (_) {
      return DateTime(date.year, date.month, date.day, 6, 0);
    }
  }

  static List<Map<String, String>> _calculateChoghadiya(DateTime sunrise, DateTime sunset) {
    Duration gap = sunset.difference(sunrise) ~/ 8;
    final types = ["Shubh", "Rog", "Udveg", "Char", "Labh", "Amrit", "Kaal", "Shubh"];
    int dayOfWeek = sunrise.weekday;
    final dayStarts = {1: 2, 2: 6, 3: 4, 4: 3, 5: 3, 6: 6, 7: 2};
    int startIdx = dayStarts[dayOfWeek] ?? 0;
    List<Map<String, String>> result = [];
    for (int i = 0; i < 8; i++) {
      String name = types[(startIdx + i) % 7];
      DateTime start = sunrise.add(gap * i);
      DateTime end = sunrise.add(gap * (i + 1));
      result.add({
        'name': name,
        'time': "${DateFormat('hh:mm').format(start)} - ${DateFormat('hh:mm').format(end)}",
        'color': _getColorForChoghadiya(name),
      });
    }
    return result;
  }

  static String _getColorForChoghadiya(String name) {
    switch (name) {
      case 'Shubh': return '0xFF4CAF50';
      case 'Amrit': return '0xFF009688';
      case 'Labh': return '0xFF2196F3';
      case 'Char': return '0xFF9C27B0';
      case 'Rog': return '0xFFFF9800';
      case 'Kaal': return '0xFFF44336';
      case 'Udveg': return '0xFFE91E63';
      default: return '0xFF9E9E9E';
    }
  }
}

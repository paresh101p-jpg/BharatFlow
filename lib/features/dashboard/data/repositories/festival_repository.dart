import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../../core/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FestivalRepository {
  static final List<Map<String, dynamic>> masterList = [
    {'name': 'Buddha Purnima', 'date': '2026-05-02', 'description': 'Religious Holiday', 'is_mandi_closed': true},
    {'name': 'Rabindranath Tagore Jayanti', 'date': '2026-05-07', 'description': 'Cultural Day', 'is_mandi_closed': false},
    {'name': 'Eid-ul-Adha', 'date': '2026-05-27', 'description': 'Religious Festival', 'is_mandi_closed': true},
    {'name': 'Kabir Jayanti', 'date': '2026-06-09', 'description': 'Religious Holiday', 'is_mandi_closed': false},
    {'name': 'Muharram', 'date': '2026-06-26', 'description': 'Islamic New Year', 'is_mandi_closed': true},
    {'name': 'Jagannath Rath Yatra', 'date': '2026-07-06', 'description': 'Religious Procession', 'is_mandi_closed': false},
    {'name': 'Independence Day', 'date': '2026-08-15', 'description': 'National Holiday', 'is_mandi_closed': true},
    {'name': 'Parsi New Year', 'date': '2026-08-17', 'description': 'Community Festival', 'is_mandi_closed': false},
    {'name': 'Raksha Bandhan', 'date': '2026-08-28', 'description': 'Sibling Festival', 'is_mandi_closed': true},
    {'name': 'Janmashtami', 'date': '2026-08-28', 'description': 'Religious Festival', 'is_mandi_closed': true},
    {'name': 'Ganesh Chaturthi', 'date': '2026-09-14', 'description': 'Religious Festival', 'is_mandi_closed': true},
    {'name': 'Onam', 'date': '2026-09-15', 'description': 'Kerala Harvest', 'is_mandi_closed': false},
    {'name': 'Eid-e-Milad', 'date': '2026-09-25', 'description': 'Prophet Birthday', 'is_mandi_closed': true},
    {'name': 'Gandhi Jayanti', 'date': '2026-10-02', 'description': 'National Holiday', 'is_mandi_closed': true},
    {'name': 'Maha Navami', 'date': '2026-10-19', 'description': 'Religious Festival', 'is_mandi_closed': false},
    {'name': 'Dussehra', 'date': '2026-10-20', 'description': 'Festival of Victory', 'is_mandi_closed': true},
    {'name': 'Valmiki Jayanti', 'date': '2026-10-26', 'description': 'Religious Holiday', 'is_mandi_closed': false},
    {'name': 'Karwa Chauth', 'date': '2026-10-29', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Dhanteras', 'date': '2026-11-07', 'description': 'Festival of Wealth', 'is_mandi_closed': true},
    {'name': 'Diwali', 'date': '2026-11-09', 'description': 'Festival of Lights', 'is_mandi_closed': true},
    {'name': 'Govardhan Puja', 'date': '2026-11-10', 'description': 'Religious Festival', 'is_mandi_closed': true},
    {'name': 'Bhai Dooj', 'date': '2026-11-11', 'description': 'Religious Festival', 'is_mandi_closed': true},
    {'name': 'Chhath Puja', 'date': '2026-11-15', 'description': 'Sun Worship', 'is_mandi_closed': true},
    {'name': 'Guru Nanak Jayanti', 'date': '2026-11-24', 'description': 'Religious Holiday', 'is_mandi_closed': true},
    {'name': 'Christmas Day', 'date': '2026-12-25', 'description': 'Public Holiday', 'is_mandi_closed': true},
    {'name': 'Ekadashi (Apara)', 'date': '2026-05-12', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Ekadashi (Nirjala)', 'date': '2026-05-27', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Purnima (Punam)', 'date': '2026-06-01', 'description': 'Full Moon Day', 'is_mandi_closed': false},
    {'name': 'Amavasya (Amas)', 'date': '2026-06-15', 'description': 'New Moon Day', 'is_mandi_closed': false},
    {'name': 'Devshayani Ekadashi', 'date': '2026-07-26', 'description': 'Auspicious Day', 'is_mandi_closed': false},
    {'name': 'Guru Purnima', 'date': '2026-07-29', 'description': 'Teacher Day', 'is_mandi_closed': false},
    {'name': 'Hariyali Teej', 'date': '2026-08-16', 'description': 'Monsoon Festival', 'is_mandi_closed': false},
    {'name': 'Nag Panchami', 'date': '2026-08-18', 'description': 'Religious Day', 'is_mandi_closed': false},
    {'name': 'Kajari Teej', 'date': '2026-08-30', 'description': 'Monsoon Festival', 'is_mandi_closed': false},
    {'name': 'Hartalika Teej', 'date': '2026-09-13', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Anant Chaturdashi', 'date': '2026-09-24', 'description': 'Religious Day', 'is_mandi_closed': false},
    {'name': 'Sharad Purnima', 'date': '2026-10-25', 'description': 'Harvest Moon', 'is_mandi_closed': false},
    {'name': 'Ahoi Ashtami', 'date': '2026-11-02', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Labh Pancham', 'date': '2026-11-14', 'description': 'Auspicious Business Day', 'is_mandi_closed': false},
    {'name': 'Dev Diwali', 'date': '2026-11-24', 'description': 'Religious Festival', 'is_mandi_closed': false},
    {'name': 'Pradosh Vrat', 'date': '2026-05-30', 'description': 'Shiva Vrat', 'is_mandi_closed': false},
    {'name': 'Sankashti Chaturthi', 'date': '2026-06-03', 'description': 'Ganesh Vrat', 'is_mandi_closed': false},
    {'name': 'Masik Shivratri', 'date': '2026-06-13', 'description': 'Religious Night', 'is_mandi_closed': false},
    {'name': 'Jyeshtha Purnima', 'date': '2026-06-30', 'description': 'Full Moon', 'is_mandi_closed': false},
    {'name': 'Ashadha Amavasya', 'date': '2026-07-14', 'description': 'New Moon', 'is_mandi_closed': false},
    {'name': 'Kamika Ekadashi', 'date': '2026-08-09', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Shravana Putrada Ekadashi', 'date': '2026-08-24', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Bhadrapada Amavasya', 'date': '2026-09-12', 'description': 'New Moon', 'is_mandi_closed': false},
    {'name': 'Indira Ekadashi', 'date': '2026-10-06', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Papankusha Ekadashi', 'date': '2026-10-21', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Rama Ekadashi', 'date': '2026-11-05', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Utpanna Ekadashi', 'date': '2026-12-05', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Mokshada Ekadashi', 'date': '2026-12-20', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Margashirsha Purnima', 'date': '2026-12-24', 'description': 'Full Moon', 'is_mandi_closed': false},
    {'name': 'Pausha Amavasya', 'date': '2026-01-18', 'description': 'New Moon', 'is_mandi_closed': false},
    {'name': 'Vaikuntha Ekadashi', 'date': '2026-12-20', 'description': 'Religious Fast', 'is_mandi_closed': false},
    {'name': 'Skanda Sashti', 'date': '2026-11-15', 'description': 'Religious Day', 'is_mandi_closed': false},
    {'name': 'Tulsi Vivah', 'date': '2026-11-21', 'description': 'Religious Festival', 'is_mandi_closed': false},
    {'name': 'Vrischika Sankranti', 'date': '2026-11-16', 'description': 'Solar Event', 'is_mandi_closed': false},
    {'name': 'Dhanu Sankranti', 'date': '2026-12-16', 'description': 'Solar Event', 'is_mandi_closed': false},
  ];

  static Future<void> scheduleUpcomingFestivals() async {
    final today = DateTime.now();
    final upcomingList = masterList.where((f) {
      final festDate = DateTime.parse(f['date']);
      return festDate.isAfter(today) || (festDate.year == today.year && festDate.month == today.month && festDate.day == today.day);
    }).toList();

    upcomingList.sort((a, b) => a['date'].compareTo(b['date']));

    // Schedule next 15 upcoming festivals
    final nextFestivals = upcomingList.take(15).toList();

    for (var f in nextFestivals) {
      try {
        final DateTime festDate = DateTime.parse(f['date']);
        // Schedule for 9:00 AM on the day of the festival
        final DateTime scheduledDate = DateTime(festDate.year, festDate.month, festDate.day, 9, 0);
        
        if (scheduledDate.isAfter(DateTime.now())) {
          final int id = f['name'].hashCode.abs();
          await NotificationService.scheduleNotification(
            id,
            "🎉 Aaj ${f['name']} hai!",
            "${f['description']}. BharatFlow ki taraf se aapko hardik shubhkamnayein!",
            scheduledDate,
            payload: json.encode({'type': 'festival'}),
          );
        }
      } catch (e) {
        print('Error scheduling notification for ${f['name']}: $e');
      }
    }
  }

  static Future<void> syncFestivalsToCloud() async {
    final client = Supabase.instance.client;
    try {
      for (var f in masterList) {
        await client.from('festivals').upsert(f, onConflict: 'name,date');
      }
    } catch (e) {
      print('Sync Error: $e');
    }
  }
}

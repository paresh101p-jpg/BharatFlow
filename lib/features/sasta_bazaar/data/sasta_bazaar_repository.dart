import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/services/config_service.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

final sastaBazaarRepositoryProvider = Provider((ref) => SastaBazaarRepository());

class Mandali {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final bool isOpen;
  final String openingTime;
  final String closingTime;
  final double distanceKm;
  final double lat;
  final double lng;
  final DateTime createdAt;

  Mandali({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    required this.isOpen,
    required this.openingTime,
    required this.closingTime,
    required this.distanceKm,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  factory Mandali.fromJson(Map<String, dynamic> json) {
    return Mandali(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Mandali',
      address: json['address'] ?? 'No Address',
      phone: json['phone'],
      isOpen: json['is_open'] ?? true,
      openingTime: json['opening_time'] ?? '09:00 AM',
      closingTime: json['closing_time'] ?? '06:00 PM',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}

class SastaBazaarRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Step 1: Get Current Location
  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    } 

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Step 2 & 3: Check Supabase (Cache) and optionally fetch External API
  Future<List<Mandali>> getNearbyMandalis() async {
    try {
      final position = await _getCurrentPosition();
      
      // Query Supabase PostGIS via RPC
      final response = await _supabase.rpc('get_nearby_mandalis', params: {
        'user_lat': position.latitude,
        'user_lng': position.longitude,
        'radius_km': 40.0
      });

      List<Mandali> mandalis = (response as List).map((e) => Mandali.fromJson(e)).toList();

      // Check if data is empty
      if (mandalis.isEmpty) {
        print('Cache miss. Fetching from external API...');
        await _fetchAndCacheFromExternalApi(position.latitude, position.longitude);
        
        // Re-query Supabase after inserting
        print('Re-querying Supabase...');
        final freshResponse = await _supabase.rpc('get_nearby_mandalis', params: {
          'user_lat': position.latitude,
          'user_lng': position.longitude,
          'radius_km': 40.0
        });
        print('Fresh Response: $freshResponse');
        mandalis = (freshResponse as List).map((e) => Mandali.fromJson(e)).toList();
      } else {
        // Data exists in Supabase, return it immediately to UI.
        // Then, fire a silent background update to keep data fresh (upsert handles updates).
        print('Data found in Supabase. Returning to UI and starting silent background sync...');
        _fetchAndCacheFromExternalApi(position.latitude, position.longitude).catchError((e) {
          print('Background sync failed: $e');
        });
      }

      print('Returning ${mandalis.length} mandalis');
      return mandalis;
    } catch (e) {
      // Return empty or throw based on app logic
      print('Error fetching mandalis: $e');
      throw Exception('Failed to load mandalis: $e');
    }
  }

  // Real External API Fetch using Google Places API (Key from Supabase Remote Config)
  Future<void> _fetchAndCacheFromExternalApi(double lat, double lng) async {
    try {
      final apiKey = ConfigService.get('google_places_key');
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Google API Key not found in config');
      }

      final queries = ['sahkari mandali', 'cooperative society', 'agro center'];
      List<dynamic> allResults = [];

      for (var query in queries) {
        final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=40000&keyword=${Uri.encodeComponent(query)}&key=$apiKey';
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            allResults.addAll(data['results'] as List? ?? []);
          }
        }
      }

      if (allResults.isEmpty) return;

      List<Map<String, dynamic>> insertData = [];
      for (var place in allResults) {
        insertData.add({
          'name': place['name'] ?? 'Sahkari Mandali',
          'address': place['vicinity'] ?? 'Local Branch',
          'is_open': place['opening_hours']?['open_now'] ?? true,
          'opening_time': '09:00 AM', 
          'closing_time': '06:00 PM',
          'lat': place['geometry']['location']['lat'],
          'lng': place['geometry']['location']['lng'],
        });
      }

      // Filter unique by name to avoid duplicates before upsert
      var uniqueData = { for (var e in insertData) e['name']: e }.values.toList();

        final inserted = await _supabase.from('cooperative_societies').upsert(uniqueData, onConflict: 'name').select();
        print('Successfully inserted ${inserted.length} records from Google.');

    } catch (e) {
      print('Error fetching real data: $e');
      throw Exception('Failed to fetch from backend API: $e');
    }
  }
}

// Riverpod Provider for the UI
final sastaBazaarProvider = FutureProvider.autoDispose<List<Mandali>>((ref) async {
  final repo = ref.watch(sastaBazaarRepositoryProvider);
  return await repo.getNearbyMandalis();
});

final totalMandalisCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final count = await Supabase.instance.client.from('cooperative_societies').count(CountOption.exact);
  return count;
});

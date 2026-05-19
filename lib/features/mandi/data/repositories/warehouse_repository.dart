import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class Warehouse {
  final String id;
  final String name;
  final String address;
  final String? district;
  final String capacity;
  final String? contactNo;
  final double latitude;
  final double longitude;
  final bool isLive;
  final String type;
  final double monthlyRentPerQuintal;
  double? distanceKm;
  final int yesCount;
  final int noCount;

  Warehouse({
    required this.id,
    required this.name,
    required this.address,
    this.district,
    required this.capacity,
    this.contactNo,
    required this.latitude,
    required this.longitude,
    this.isLive = true,
    required this.type,
    required this.monthlyRentPerQuintal,
    this.distanceKm,
    this.yesCount = 0,
    this.noCount = 0,
  });

  factory Warehouse.fromRpc(Map<String, dynamic> map) {
    return Warehouse(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? 'Unknown Warehouse',
      address: map['address'] ?? '',
      district: map['district'],
      capacity: map['capacity'] ?? 'N/A',
      contactNo: map['contact_no']?.toString(),
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      isLive: map['is_live'] ?? true,
      type: map['type'] ?? 'Government',
      monthlyRentPerQuintal: (map['monthly_rent'] ?? 15.0).toDouble(),
      distanceKm: (map['distance_km'] ?? 0.0).toDouble(),
      yesCount: (map['yes_count'] ?? 0).toInt(),
      noCount: (map['no_count'] ?? 0).toInt(),
    );
  }

  factory Warehouse.fromMap(Map<String, dynamic> map, double userLat, double userLng) {
    double lat = (map['latitude'] ?? 0.0).toDouble();
    double lng = (map['longitude'] ?? 0.0).toDouble();

    if (lat == 0.0) {
      final dist = (map['district'] ?? '').toLowerCase();
      if (dist.contains('rajkot')) { lat = 22.3039; lng = 70.8022; }
      else if (dist.contains('surat')) { lat = 21.1702; lng = 72.8311; }
      else if (dist.contains('ahmedabad')) { lat = 23.0225; lng = 72.5714; }
      else if (dist.contains('junagadh')) { lat = 21.5222; lng = 70.4579; }
      else if (dist.contains('bhavnagar')) { lat = 21.7645; lng = 72.1519; }
      else if (dist.contains('amreli')) { lat = 21.6032; lng = 71.2184; }
      else if (dist.contains('kolkata')) { lat = 22.5726; lng = 88.3639; }
      else if (dist.contains('patna')) { lat = 25.5941; lng = 85.1376; }
      else if (dist.contains('ludhiana')) { lat = 30.9010; lng = 75.8573; }
      else if (dist.contains('bhopal')) { lat = 23.2599; lng = 77.4126; }
      else if (dist.contains('indore')) { lat = 22.7196; lng = 75.8577; }
      else if (dist.contains('jaipur')) { lat = 26.9124; lng = 75.7873; }
      else if (dist.contains('lucknow')) { lat = 26.8467; lng = 80.9462; }
      else if (dist.contains('chennai')) { lat = 13.0827; lng = 80.2707; }
      else if (dist.contains('hyderabad')) { lat = 17.3850; lng = 78.4867; }
      else if (dist.contains('bangalore')) { lat = 12.9716; lng = 77.5946; }
      else if (dist.contains('mumbai')) { lat = 19.0760; lng = 72.8777; }
      else if (dist.contains('pune')) { lat = 18.5204; lng = 73.8567; }
      else { lat = 20.5937; lng = 78.9629; }
    }

    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat - userLat) * p) / 2 +
        c(userLat * p) * c(lat * p) * (1 - c((lng - userLng) * p)) / 2;
    final distance = 12742 * asin(sqrt(a));

    return Warehouse(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? 'Unknown Warehouse',
      address: map['address'] ?? '',
      district: map['district'],
      capacity: map['capacity'] ?? 'N/A',
      contactNo: map['contact_no']?.toString(),
      latitude: lat,
      longitude: lng,
      isLive: map['is_live'] ?? true,
      type: map['type'] ?? 'Government',
      monthlyRentPerQuintal: (map['monthly_rent'] ?? 15.0).toDouble(),
      distanceKm: distance,
      yesCount: map['yes_count'] ?? 0,
      noCount: map['no_count'] ?? 0,
    );
  }
}

class WarehouseRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Warehouse>> getNearbyWarehouses(
    double lat,
    double lng, {
    int limit = 20,
    int offset = 0,
    String? filterType,
  }) async {
    try {
      final response = await _supabase.rpc('get_nearby_warehouses', params: {
        'user_lat': lat,
        'user_lng': lng,
        'p_limit': limit,
        'p_offset': offset,
        'p_type': (filterType == null || filterType == 'All') ? null : filterType,
      });

      if (response != null && (response as List).isNotEmpty) {
        return (response as List)
            .map((e) => Warehouse.fromRpc(e as Map<String, dynamic>))
            .toList();
      }

    } catch (e) {
      debugPrint('RPC failed, fallback: $e');
      try {
        var query = _supabase.from('warehouses').select();
        if (filterType != null && filterType != 'All') {
          query = query.eq('type', filterType);
        }
        final response = await query.range(offset, offset + limit - 1);
        if (response != null && (response as List).isNotEmpty) {
          final warehouses = (response as List)
              .map((e) => Warehouse.fromMap(e as Map<String, dynamic>, lat, lng))
              .toList();
          warehouses.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
          return warehouses;
        }
      } catch (e2) {
        debugPrint('Fallback failed: $e2');
      }
    }

    // ─── FINAL STARTER PACK (If DB is empty or connection fails) ────────
    print('📦 Using Warehouse Starter Pack...');
    final starterData = [
      {
        'id': 'w1', 'name': 'Gujarat State Warehousing Corp (GSWC)', 'address': 'Sayajigunj, Vadodara, Gujarat', 
        'district': 'Vadodara', 'capacity': '50,000 MT', 'latitude': 22.3106, 'longitude': 73.1926, 'type': 'Government'
      },
      {
        'id': 'w2', 'name': 'Central Warehousing Corporation (CWC)', 'address': 'Puna Kumbharia Road, Surat, Gujarat', 
        'district': 'Surat', 'capacity': '25,000 MT', 'latitude': 21.1950, 'longitude': 72.8650, 'type': 'Government'
      },
      {
        'id': 'w3', 'name': 'Adani Agri Logistics Ltd', 'address': 'Mundra Port Road, Kutch, Gujarat', 
        'district': 'Kutch', 'capacity': '2,00,000 MT', 'latitude': 22.8400, 'longitude': 69.7100, 'type': 'Private'
      },
      {
        'id': 'w4', 'name': 'National Bulk Handling Corp (NBHC)', 'address': 'Bavla-Bagodara Road, Ahmedabad', 
        'district': 'Ahmedabad', 'capacity': '15,000 MT', 'latitude': 22.8360, 'longitude': 72.3680, 'type': 'Private'
      },
      {
        'id': 'w5', 'name': 'Rajkot APMC Cold Storage', 'address': 'Marketing Yard, Rajkot, Gujarat', 
        'district': 'Rajkot', 'capacity': '10,000 MT', 'latitude': 22.3039, 'longitude': 70.8022, 'type': 'Government'
      },
      {
        'id': 'w6', 'name': 'Star Agri Warehousing', 'address': 'Gondal Road, Rajkot, Gujarat', 
        'district': 'Rajkot', 'capacity': '12,500 MT', 'latitude': 22.2500, 'longitude': 70.7800, 'type': 'Private'
      },
      {
        'id': 'w7', 'name': 'CWC Kandla Terminal', 'address': 'Kandla Port, Gandhidham, Gujarat', 
        'district': 'Kutch', 'capacity': '75,000 MT', 'latitude': 23.0133, 'longitude': 70.2170, 'type': 'Government'
      },
      {
        'id': 'w8', 'name': 'GSWC Gondal Branch', 'address': 'Marketing Yard, Gondal, Gujarat', 
        'district': 'Rajkot', 'capacity': '30,000 MT', 'latitude': 21.9619, 'longitude': 70.7923, 'type': 'Government'
      },
      {
        'id': 'w9', 'name': 'Indus Agri Logistics', 'address': 'Sanand GIDC, Ahmedabad', 
        'district': 'Ahmedabad', 'capacity': '45,000 MT', 'latitude': 22.9904, 'longitude': 72.3820, 'type': 'Private'
      },
      {
        'id': 'w10', 'name': 'AgriLogix Solutions', 'address': 'Vapi Industrial Area, Gujarat', 
        'district': 'Valsad', 'capacity': '20,000 MT', 'latitude': 20.3705, 'longitude': 72.9100, 'type': 'Private'
      },
      {
        'id': 'w11', 'name': 'CWC Navi Mumbai Store', 'address': 'Turbhe, Navi Mumbai, Maharashtra', 
        'district': 'Mumbai', 'capacity': '1,00,000 MT', 'latitude': 19.0700, 'longitude': 73.0000, 'type': 'Government'
      },
      {
        'id': 'w12', 'name': 'Punjab State Warehousing', 'address': 'Gill Road, Ludhiana, Punjab', 
        'district': 'Ludhiana', 'capacity': '1,50,000 MT', 'latitude': 30.9010, 'longitude': 75.8573, 'type': 'Government'
      },
      {
        'id': 'w13', 'name': 'Sohan Lal Commodity Management', 'address': 'Jaipur Road, Bikaner, Rajasthan', 
        'district': 'Bikaner', 'capacity': '40,000 MT', 'latitude': 28.0227, 'longitude': 73.3119, 'type': 'Private'
      },
      {
        'id': 'w14', 'name': 'Central Warehousing - Pipavav', 'address': 'Pipavav Port, Amreli, Gujarat', 
        'district': 'Amreli', 'capacity': '60,000 MT', 'latitude': 20.9167, 'longitude': 71.5000, 'type': 'Government'
      },
      {
        'id': 'w15', 'name': 'Ruchi Soya Agri Logistics', 'address': 'Indore Bypass, Madhya Pradesh', 
        'district': 'Indore', 'capacity': '80,000 MT', 'latitude': 22.7196, 'longitude': 75.8577, 'type': 'Private'
      },
      {
        'id': 'w16', 'name': 'GSWC Deesa Potato Storage', 'address': 'Deesa, Banaskantha, Gujarat', 
        'district': 'Banaskantha', 'capacity': '25,000 MT', 'latitude': 24.2500, 'longitude': 72.1800, 'type': 'Government'
      },
      {
        'id': 'w17', 'name': 'Adani Silos - Khanna', 'address': 'GT Road, Khanna, Punjab', 
        'district': 'Ludhiana', 'capacity': '2,50,000 MT', 'latitude': 30.7000, 'longitude': 76.2100, 'type': 'Private'
      },
      {
        'id': 'w18', 'name': 'CWC Patna Central', 'address': 'Anisabad, Patna, Bihar', 
        'district': 'Patna', 'capacity': '35,000 MT', 'latitude': 25.5941, 'longitude': 85.1376, 'type': 'Government'
      },
      {
        'id': 'w19', 'name': 'Sardar Patel Agri Park', 'address': 'Anand-Sojitra Road, Gujarat', 
        'district': 'Anand', 'capacity': '18,000 MT', 'latitude': 22.5560, 'longitude': 72.9510, 'type': 'Private'
      },
      {
        'id': 'w20', 'name': 'CWC Chennai South', 'address': 'Guindy Industrial Estate, Chennai', 
        'district': 'Chennai', 'capacity': '55,000 MT', 'latitude': 13.0067, 'longitude': 80.2206, 'type': 'Government'
      },
    ];

    final starterWarehouses = starterData
        .map((e) => Warehouse.fromMap(e, lat, lng))
        .where((w) => filterType == null || filterType == 'All' || w.type == filterType)
        .toList();
    starterWarehouses.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
    return starterWarehouses;
  }

  Future<void> saveWarehouseFeedback(String id, bool isFull, String? userId) async {
    if (userId == null) return;
    try {
      await _supabase.from('warehouse_feedback').insert({
        'warehouse_id': id,
        'user_id': userId,
        'is_full': isFull,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Feedback save error: $e');
    }
  }
}

final warehouseRepositoryProvider = Provider((ref) => WarehouseRepository());

final nearbyWarehousesProvider = FutureProvider.family<
    List<Warehouse>,
    ({double lat, double lng, int limit, int offset, String? filterType})>((ref, arg) async {
  final repo = ref.watch(warehouseRepositoryProvider);
  return repo.getNearbyWarehouses(
    arg.lat,
    arg.lng,
    limit: arg.limit,
    offset: arg.offset,
    filterType: arg.filterType,
  );
});
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/location_provider.dart';

class CropIntelligence {
  final String name;
  final List<String> sowMonths;
  final List<String> harvestMonths;
  final int cycleDays;
  final String season;
  final bool rainSensitive;
  final bool windSensitive;
  final double idealTempMin;
  final double idealTempMax;

  CropIntelligence({
    required this.name,
    required this.sowMonths,
    required this.harvestMonths,
    required this.cycleDays,
    required this.season,
    this.rainSensitive = false,
    this.windSensitive = false,
    this.idealTempMin = 15.0,
    this.idealTempMax = 35.0,
  });

  factory CropIntelligence.fromMap(Map<String, dynamic> map) {
    return CropIntelligence(
      name: map['name'] ?? '',
      sowMonths: List<String>.from(map['sow_months'] ?? []),
      harvestMonths: List<String>.from(map['harvest_months'] ?? []),
      cycleDays: map['cycle_days'] ?? 90,
      season: map['season'] ?? 'Annual',
      rainSensitive: map['rain_sensitive'] ?? false,
      windSensitive: map['wind_sensitive'] ?? false,
      idealTempMin: (map['ideal_temp_min'] as num?)?.toDouble() ?? 15.0,
      idealTempMax: (map['ideal_temp_max'] as num?)?.toDouble() ?? 35.0,
    );
  }

  factory CropIntelligence.fromMasterJson(Map<String, dynamic> json) {
    // Helper to map months like "July-Aug" or "June" to ['Jul', 'Aug'] or ['Jun']
    List<String> mapMonths(String monthStr) {
      if (monthStr.isEmpty) return [];
      final parts = monthStr.split('-').map((e) => e.trim()).toList();
      final monthMap = {
        'jan': 'Jan', 'feb': 'Feb', 'mar': 'Mar', 'apr': 'Apr', 'may': 'May', 'jun': 'Jun',
        'jul': 'Jul', 'aug': 'Aug', 'sep': 'Sep', 'oct': 'Oct', 'nov': 'Nov', 'dec': 'Dec'
      };
      
      List<String> result = [];
      for (var part in parts) {
        final lower = part.toLowerCase();
        for (var key in monthMap.keys) {
          if (lower.startsWith(key)) {
            result.add(monthMap[key]!);
            break;
          }
        }
      }
      return result;
    }

    // Helper to extract days from "120-150 days"
    int extractDays(String duration) {
      final match = RegExp(r'(\d+)').allMatches(duration).map((m) => int.parse(m.group(0)!)).toList();
      if (match.isEmpty) return 100;
      if (match.length == 1) return match[0];
      return ((match[0] + match[1]) / 2).round(); // Average
    }

    return CropIntelligence(
      name: json['Crop'] ?? '',
      sowMonths: mapMonths(json['Sowing'] ?? ''),
      harvestMonths: mapMonths(json['Harvesting'] ?? ''),
      cycleDays: extractDays(json['Duration'] ?? '100 days'),
      season: json['Season'] ?? 'Annual',
      rainSensitive: (json['Category'] == 'Vegetable' || json['Category'] == 'Spices'),
      windSensitive: (json['Category'] == 'Fruit' || json['Category'] == 'Plantation'),
    );
  }

  // Helper to get generic data if DB doesn't have specific info
  static CropIntelligence generic(String name) {
    final lower = name.toLowerCase();
    
    if (lower.contains('paddy') || lower.contains('rice')) {
      return CropIntelligence(
        name: name,
        sowMonths: ['Jun', 'Jul', 'Aug'],
        harvestMonths: ['Nov', 'Dec'],
        cycleDays: 120,
        season: 'Kharif',
        rainSensitive: false,
      );
    }
    // ... (rest of generic remains same or simplified)
    return CropIntelligence(
      name: name,
      sowMonths: ['Jun', 'Jul', 'Oct', 'Nov'],
      harvestMonths: ['Mar', 'Apr', 'Aug', 'Sep'],
      cycleDays: 100,
      season: 'Kharif/Rabi',
    );
  }
}

class CropIntelligenceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<dynamic>? _masterData;

  Future<void> _ensureMasterLoaded() async {
    if (_masterData != null) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/india_crop_calendar_master.json');
      _masterData = json.decode(jsonStr);
    } catch (e) {
      _masterData = [];
    }
  }

  Future<CropIntelligence?> getCropInfo(String name, String state) async {
    await _ensureMasterLoaded();
    
    final normalizedName = name.toLowerCase().trim();
    final normalizedState = state.toLowerCase().trim();

    // First try Master Dataset
    if (_masterData != null && _masterData!.isNotEmpty) {
      final match = _masterData!.firstWhere(
        (e) {
          final cropInJson = (e['Crop'] as String).toLowerCase();
          final stateInJson = (e['State'] as String).toLowerCase().trim();
          
          // Match if name is contained in crop string (handles aliases like "Ginger (Adrak)")
          return cropInJson.contains(normalizedName) && stateInJson == normalizedState;
        },
        orElse: () => null,
      );
      
      if (match != null) {
        return CropIntelligence.fromMasterJson(match);
      }

      // If state-specific match fails, try any state for the same crop
      final genericMatch = _masterData!.firstWhere(
        (e) => (e['Crop'] as String).toLowerCase().contains(normalizedName),
        orElse: () => null,
      );
      if (genericMatch != null) {
        return CropIntelligence.fromMasterJson(genericMatch);
      }
    }

    // Fallback to Supabase
    try {
      final data = await _supabase
          .from('crop_intelligence')
          .select()
          .eq('name', name)
          .maybeSingle();
      
      if (data == null) return CropIntelligence.generic(name);
      return CropIntelligence.fromMap(data);
    } catch (e) {
      return CropIntelligence.generic(name);
    }
  }

  Future<Map<String, CropIntelligence>> getBulkCropsInfo(List<String> names, String state) async {
    final Map<String, CropIntelligence> result = {};
    for (var name in names) {
      final info = await getCropInfo(name, state);
      if (info != null) result[name] = info;
    }
    return result;
  }
}

final cropIntelligenceRepositoryProvider = Provider((ref) => CropIntelligenceRepository());

final cropIntelligenceProvider = FutureProvider.family<CropIntelligence?, String>((ref, name) {
  final userState = ref.watch(locationProvider).state;
  return ref.watch(cropIntelligenceRepositoryProvider).getCropInfo(name, userState);
});

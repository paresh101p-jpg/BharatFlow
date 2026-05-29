import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'lib/features/political/data/models/leader_model.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  
  print('Connecting to Supabase...');
  try {
    final response = await supabase.from('leaders_master').select().limit(5);
    final data = response as List;
    
    if (data.isEmpty) {
      print('FAILED: No data found in leaders_master.');
      exit(1);
    }
    
    print('SUCCESS: Found ${data.length} leaders in the database.');
    
    for (var item in data) {
      final leader = LeaderModel.fromJson(item);
      print('---------------------------');
      print('Name: ${leader.name}');
      print('Party: ${leader.party}');
      print('Constituency: ${leader.constituency}');
      print('Likes: ${leader.totalLikes}, Dislikes: ${leader.totalDislikes}');
      print('Assets: ${leader.assets?['total'] ?? "N/A"}');
    }
    
    print('---------------------------');
    print('All data parsed perfectly using LeaderModel!');
    exit(0);
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}

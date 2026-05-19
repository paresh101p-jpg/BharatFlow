import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    print('--- Checking if row was deleted ---');
    final check = await supabase
        .from('mandi_prices')
        .select()
        .eq('id', '019538d9-8ef5-4fbc-ae75-4a94edd1f947');
    
    if ((check as List).isEmpty) {
      print('Row was deleted successfully!');
    } else {
      print('Row was NOT deleted! It still exists: $check');
    }
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}

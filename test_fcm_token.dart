import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    // Try to select fcm_token
    final res = await supabase.from('profiles').select('id, fcm_token').limit(1);
    print('SUCCESS! Column exists. Data: $res');
  } catch (e) {
    print('ERROR: $e');
  }
  exit(0);
}

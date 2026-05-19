import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    final data = await supabase.from('profiles').select().limit(1);
    print('profiles table exists: $data');
  } catch (e) {
    print('profiles Error: $e');
  }
  
  try {
    final data = await supabase.from('users').select().limit(1);
    print('users table exists: $data');
  } catch (e) {
    print('users Error: $e');
  }
  exit(0);
}

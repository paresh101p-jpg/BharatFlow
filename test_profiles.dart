import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    final res = await supabase.from('profiles').select().limit(1);
    print('Profiles data: $res');
  } catch (e) {
    print('ERROR: $e');
  }
  exit(0);
}

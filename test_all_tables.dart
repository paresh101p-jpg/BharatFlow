import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    final res = await supabase.rpc('get_tables');
    print(res);
  } catch(e) {
    print('Error: $e');
  }
  exit(0);
}

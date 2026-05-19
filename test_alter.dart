import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    // Wait, anon key cannot use RPC or alter table.
    print('Attempting to add column via REST...');
    // I can't add a column via Anon key!
    // But I can check if it exists or not. It doesn't exist.
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}

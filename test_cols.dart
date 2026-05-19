import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    final data = await supabase.from('store_products').select().limit(1);
    print('Cols: ${data.first.keys.toList()}');
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}

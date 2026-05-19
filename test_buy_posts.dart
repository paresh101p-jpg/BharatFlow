import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    final data = await supabase.from('store_products').select().eq('type', 'BUY');
    print('BUY posts count: ${data.length}');
    if (data.isNotEmpty) {
      print('First BUY post: ${data.first}');
    }
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}

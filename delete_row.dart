import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    print('Deleting Khadsad from fuel_prices...');
    await supabase.from('fuel_prices').delete().eq('city', 'Khadsad');
    
    print('Deleting Khadsad from fuel_price_history...');
    await supabase.from('fuel_price_history').delete().eq('city', 'Khadsad');
    
    print('Deletion complete!');
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}

import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient('YOUR_URL', 'YOUR_KEY');
  final data = await supabase.from('mandi_prices').select().ilike('mandi_name', 'BUDHPUR MAIN APMC');
  print(data);
}

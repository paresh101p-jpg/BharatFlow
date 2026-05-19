import 'package:supabase/supabase.dart';
import 'lib/core/constants/api_keys.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(ApiKeys.supabaseUrl, ApiKeys.supabaseAnonKey);
  try {
    final response = await supabase.from('chat_messages').insert({
        'sender_id': '109627501874403654210',
        'receiver_id': '109627501874403654210',
        'message': 'Test message from script'
    }).select();
    print('Inserted: $response');
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}

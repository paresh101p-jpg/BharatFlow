import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KhataRepository {
  final Box _box;
  final SupabaseClient _supabase;

  KhataRepository(this._box, this._supabase);

  // Get all transactions sorted by date descending
  List<Map<String, dynamic>> getAllTransactions() {
    final List<Map<String, dynamic>> transactions = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value != null) {
        // Handle Map conversion from Hive dynamic map
        final Map<String, dynamic> typedMap = Map<String, dynamic>.from(value as Map);
        transactions.add(typedMap);
      }
    }
    
    // Sort by date descending
    transactions.sort((a, b) {
      final dateA = DateTime.parse(a['date'] as String);
      final dateB = DateTime.parse(b['date'] as String);
      return dateB.compareTo(dateA);
    });
    
    return transactions;
  }

  // Add or update a transaction
  Future<void> saveTransaction(Map<String, dynamic> transaction) async {
    final id = transaction['id'] as String;
    transaction['updated_at'] = DateTime.now().toIso8601String();
    await _box.put(id, transaction);
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id) async {
    await _box.delete(id);
  }

  // Cloud Backup
  Future<bool> backupToCloud() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final allTransactions = getAllTransactions();
    if (allTransactions.isEmpty) return true;

    try {
      // Upsert transactions to Supabase
      // Assuming a table 'khata_transactions' exists.
      // If it doesn't exist, this will fail gracefully.
      for (var t in allTransactions) {
        t['user_id'] = user.id;
      }
      
      await _supabase.from('khata_transactions').upsert(allTransactions);
      return true;
    } catch (e) {
      print('Cloud Backup Error: $e');
      return false;
    }
  }

  // Cloud Restore
  Future<bool> restoreFromCloud() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final data = await _supabase
          .from('khata_transactions')
          .select()
          .eq('user_id', user.id);
          
      if (data == null) return true;
      
      final List<dynamic> records = data as List<dynamic>;
      for (var record in records) {
        final map = Map<String, dynamic>.from(record as Map);
        // Remove user_id before saving locally
        map.remove('user_id');
        await _box.put(map['id'], map);
      }
      return true;
    } catch (e) {
      print('Cloud Restore Error: $e');
      return false;
    }
  }
}

// Provider
final khataBoxProvider = Provider<Box>((ref) => Hive.box('khata_transactions'));

final khataRepositoryProvider = Provider<KhataRepository>((ref) {
  final box = ref.watch(khataBoxProvider);
  final supabase = Supabase.instance.client;
  return KhataRepository(box, supabase);
});

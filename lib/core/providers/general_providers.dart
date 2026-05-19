import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/general_repository.dart';

final generalRepositoryProvider = Provider((ref) => GeneralRepository());

final tableDataProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, tableName) {
  return ref.watch(generalRepositoryProvider).getTableData(tableName);
});

final khataTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(generalRepositoryProvider).getTableData('khata_transactions', orderBy: 'transaction_date', ascending: false);
});

final storeProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(generalRepositoryProvider).getTableData('store_products');
});

final hasUnreadNotificationsProvider = StateProvider<bool>((ref) => false);

final dashboardIndexProvider = StateProvider<int>((ref) => 0);

final weatherSelectedCropsProvider = StateProvider<int>((ref) => 0); // Used for invalidation/refresh
final weatherEditModeProvider = StateProvider<bool>((ref) => false);

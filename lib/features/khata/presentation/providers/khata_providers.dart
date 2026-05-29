import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/khata_repository.dart';

class KhataState {
  final List<Map<String, dynamic>> transactions;
  final double totalSales;
  final double totalExpenses;
  final double netBalance;
  final String activeTab; // 'All', 'Sales', 'Expenses'
  final String searchQuery;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;

  KhataState({
    required this.transactions,
    required this.totalSales,
    required this.totalExpenses,
    required this.netBalance,
    this.activeTab = 'All',
    this.searchQuery = '',
    this.filterStartDate,
    this.filterEndDate,
  });

  KhataState copyWith({
    List<Map<String, dynamic>>? transactions,
    double? totalSales,
    double? totalExpenses,
    double? netBalance,
    String? activeTab,
    String? searchQuery,
    DateTime? filterStartDate,
    DateTime? filterEndDate,
    bool clearDates = false,
  }) {
    return KhataState(
      transactions: transactions ?? this.transactions,
      totalSales: totalSales ?? this.totalSales,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      netBalance: netBalance ?? this.netBalance,
      activeTab: activeTab ?? this.activeTab,
      searchQuery: searchQuery ?? this.searchQuery,
      filterStartDate: clearDates ? null : (filterStartDate ?? this.filterStartDate),
      filterEndDate: clearDates ? null : (filterEndDate ?? this.filterEndDate),
    );
  }
}

class KhataNotifier extends StateNotifier<KhataState> {
  final KhataRepository _repository;

  KhataNotifier(this._repository)
      : super(KhataState(
          transactions: [],
          totalSales: 0,
          totalExpenses: 0,
          netBalance: 0,
        )) {
    loadTransactions();
  }

  void loadTransactions() {
    final allTx = _repository.getAllTransactions();
    
    // Calculate Totals
    double sales = 0;
    double expenses = 0;
    
    for (var tx in allTx) {
      final isExpense = tx['isExpense'] as bool? ?? false;
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      if (isExpense) {
        expenses += amount;
      } else {
        sales += amount;
      }
    }

    state = state.copyWith(
      transactions: allTx,
      totalSales: sales,
      totalExpenses: expenses,
      netBalance: sales - expenses,
    );
  }

  Future<void> addTransaction(Map<String, dynamic> transaction) async {
    await _repository.saveTransaction(transaction);
    loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _repository.deleteTransaction(id);
    loadTransactions();
  }

  void setTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setDateFilter(DateTime? start, DateTime? end) {
    state = state.copyWith(
      filterStartDate: start,
      filterEndDate: end,
      clearDates: start == null && end == null,
    );
  }

  Future<bool> backupToCloud() async {
    return await _repository.backupToCloud();
  }

  Future<bool> restoreFromCloud() async {
    final success = await _repository.restoreFromCloud();
    if (success) {
      loadTransactions();
    }
    return success;
  }
}

final khataNotifierProvider =
    StateNotifierProvider<KhataNotifier, KhataState>((ref) {
  final repo = ref.watch(khataRepositoryProvider);
  return KhataNotifier(repo);
});

// Filtered List Provider
final filteredKhataTransactionsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final state = ref.watch(khataNotifierProvider);
  
  var filtered = state.transactions;
  
  // Tab Filter
  if (state.activeTab == 'Sales') {
    filtered = filtered.where((t) => !(t['isExpense'] as bool? ?? false)).toList();
  } else if (state.activeTab == 'Expenses') {
    filtered = filtered.where((t) => (t['isExpense'] as bool? ?? false)).toList();
  }
  
  // Search Filter
  if (state.searchQuery.isNotEmpty) {
    final query = state.searchQuery.toLowerCase();
    filtered = filtered.where((t) {
      final title = (t['title'] as String?)?.toLowerCase() ?? '';
      final category = (t['category'] as String?)?.toLowerCase() ?? '';
      return title.contains(query) || category.contains(query);
    }).toList();
  }

  // Date Filter
  if (state.filterStartDate != null || state.filterEndDate != null) {
    filtered = filtered.where((t) {
      final dateStr = t['date'] as String?;
      if (dateStr == null) return true;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return true;

      // Extract only year, month, day for comparison to ignore time
      final txDate = DateTime(dt.year, dt.month, dt.day);
      
      bool isAfterOrEq = true;
      if (state.filterStartDate != null) {
        final st = state.filterStartDate!;
        final start = DateTime(st.year, st.month, st.day);
        isAfterOrEq = txDate.isAfter(start.subtract(const Duration(days: 1)));
      }

      bool isBeforeOrEq = true;
      if (state.filterEndDate != null) {
        final en = state.filterEndDate!;
        final end = DateTime(en.year, en.month, en.day);
        isBeforeOrEq = txDate.isBefore(end.add(const Duration(days: 1)));
      }

      return isAfterOrEq && isBeforeOrEq;
    }).toList();
  }
  
  // Sort by date descending
  filtered.sort((a, b) {
    final dA = DateTime.tryParse(a['date'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dB = DateTime.tryParse(b['date'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dB.compareTo(dA); // Newest first
  });

  return filtered;
});

// Totals Provider (Respects Date Filter but NOT Tab/Search filter so Dashboard Top Card is accurate)
final khataTotalsProvider = Provider<Map<String, double>>((ref) {
  final state = ref.watch(khataNotifierProvider);
  var filtered = state.transactions;

  // Apply ONLY Date Filter
  if (state.filterStartDate != null || state.filterEndDate != null) {
    filtered = filtered.where((t) {
      final dateStr = t['date'] as String?;
      if (dateStr == null) return true;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return true;

      final txDate = DateTime(dt.year, dt.month, dt.day);
      
      bool isAfterOrEq = true;
      if (state.filterStartDate != null) {
        final st = state.filterStartDate!;
        final start = DateTime(st.year, st.month, st.day);
        isAfterOrEq = txDate.isAfter(start.subtract(const Duration(days: 1)));
      }

      bool isBeforeOrEq = true;
      if (state.filterEndDate != null) {
        final en = state.filterEndDate!;
        final end = DateTime(en.year, en.month, en.day);
        isBeforeOrEq = txDate.isBefore(end.add(const Duration(days: 1)));
      }

      return isAfterOrEq && isBeforeOrEq;
    }).toList();
  }

  double sales = 0;
  double expenses = 0;
  for (var tx in filtered) {
    final isExpense = tx['isExpense'] as bool? ?? false;
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    if (isExpense) {
      expenses += amount;
    } else {
      sales += amount;
    }
  }

  return {
    'sales': sales,
    'expenses': expenses,
    'net': sales - expenses,
  };
});

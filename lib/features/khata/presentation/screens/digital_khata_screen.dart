import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/general_providers.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_screen.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/widgets/common_app_bar.dart';

class DigitalKhataScreen extends ConsumerWidget {
  const DigitalKhataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(khataTransactionsProvider);
    final t = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          CommonSliverAppBar(title: t['khata'] ?? 'Digital Khata', showBack: false),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                transactionsAsync.when(
                  data: (txs) => _buildBalanceCard(txs, t),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const SizedBox(),
                ),
                const SizedBox(height: 24),
                _buildSearchAndFilter(t),
                const SizedBox(height: 24),
                _buildTabSwitcher(t),
                const SizedBox(height: 24),
                transactionsAsync.when(
                  data: (txs) => _buildTransactionList(context, txs, t),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(context, ref, t),
        backgroundColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }


  Widget _buildBalanceCard(List<Map<String, dynamic>> txs, Map<String, String> t) {
    double totalCredit = 0;
    double totalDebit = 0;

    for (var tx in txs) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
      if (tx['type'] == 'Credit') {
        totalCredit += amount;
      } else {
        totalDebit += amount;
      }
    }

    final netBalance = totalCredit - totalDebit;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: glassDecoration().copyWith(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['net_balance'] ?? 'NET BALANCE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Text('₹${netBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _balanceDetail(t['total_sales'] ?? 'Total Sales', '₹${totalCredit.toStringAsFixed(0)}', Icons.arrow_upward, Colors.teal)),
              const SizedBox(width: 12),
              Expanded(child: _balanceDetail(t['total_expenses'] ?? 'Total Expenses', '₹${totalDebit.toStringAsFixed(0)}', Icons.arrow_downward, Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceDetail(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))]),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(Map<String, String> t) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [const Icon(Icons.search, color: Colors.grey, size: 20), const SizedBox(width: 12), Expanded(child: TextField(decoration: InputDecoration(hintText: t['search_transactions'] ?? 'Search transactions...', border: InputBorder.none, hintStyle: const TextStyle(fontSize: 14))))]),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.filter_list, color: AppTheme.primaryColor)),
      ],
    );
  }

  Widget _buildTabSwitcher(Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [_tabItem(t['all_transactions'] ?? 'All Transactions', true), _tabItem(t['total_sales'] ?? 'Sales', false), _tabItem(t['total_expenses'] ?? 'Expenses', false)]),
    );
  }

  Widget _tabItem(String label, bool isActive) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: isActive ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]) : null, child: Center(child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? AppTheme.primaryColor : Colors.grey)))));
  }

  Widget _buildTransactionList(BuildContext context, List<Map<String, dynamic>> txs, Map<String, String> t) {
    if (txs.isEmpty) return Center(child: Text(t['no_transactions'] ?? 'No transactions yet. Add one!'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['recent_activity'] ?? 'Recent Activity', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        ...txs.map((tx) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _transactionItem(
            tx['title'] ?? 'Unknown',
            '${tx['transaction_date'] ?? ''} • ${tx['payment_method'] ?? ''}',
            '${tx['type'] == 'Credit' ? '+' : '-'}₹${tx['amount']}',
            tx['type'] == 'Credit' ? Icons.add_circle_outline : Icons.remove_circle_outline,
            tx['type'] == 'Credit' ? Colors.teal : Colors.orange,
          ),
        )),
      ],
    );
  }

  Widget _transactionItem(String title, String subtitle, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11))])),
          Text(amount, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: amount.startsWith('+') ? Colors.teal : Colors.orange)),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref, Map<String, String> t) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String type = 'Credit';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['add_transaction'] ?? 'Add Transaction', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const SizedBox(height: 24),
              TextField(controller: titleController, decoration: InputDecoration(labelText: t['title'] ?? 'Title', border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t['amount'] ?? 'Amount (₹)', border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: ChoiceChip(label: Text(t['credit'] ?? 'Credit'), selected: type == 'Credit', onSelected: (s) => setState(() => type = 'Credit'))),
                const SizedBox(width: 12),
                Expanded(child: ChoiceChip(label: Text(t['debit'] ?? 'Debit'), selected: type == 'Debit', onSelected: (s) => setState(() => type = 'Debit'))),
              ]),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final repo = ref.read(generalRepositoryProvider);
                  await repo.insertData('khata_transactions', {
                    'title': titleController.text,
                    'amount': double.parse(amountController.text),
                    'type': type,
                    'category': 'General',
                  });
                  ref.invalidate(khataTransactionsProvider);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, minimumSize: const Size(double.infinity, 50)),
                child: Text(t['save_transaction'] ?? 'SAVE TRANSACTION', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

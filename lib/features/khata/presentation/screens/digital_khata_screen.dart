import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import '../providers/khata_providers.dart';
import 'add_transaction_screen.dart';
import 'report_screen.dart';

class DigitalKhataScreen extends ConsumerWidget {
  const DigitalKhataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(khataNotifierProvider);
    final transactions = ref.watch(filteredKhataTransactionsProvider);
    final totals = ref.watch(khataTotalsProvider);
    final formatter = NumberFormat("#,##,###.##", "en_IN");
    final t = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F3D2F), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t['digital_khata'] ?? 'Digital Khata',
          style: const TextStyle(
            color: Color(0xFF0F3D2F),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F3D2F)),
            onSelected: (value) async {
              if (value == 'backup') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t['backing_up_cloud'] ?? 'Backing up to Cloud...')),
                );
                final success = await ref.read(khataNotifierProvider.notifier).backupToCloud();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? (t['backup_success'] ?? 'Backup Successful! ✅')
                            : (t['backup_failed'] ?? 'Backup Failed ❌'),
                      ),
                    ),
                  );
                }
              } else if (value == 'restore') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t['restoring_from_cloud'] ?? 'Restoring from Cloud...')),
                );
                final success = await ref.read(khataNotifierProvider.notifier).restoreFromCloud();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? (t['restore_success'] ?? 'Restore Successful! ✅')
                            : (t['restore_failed'] ?? 'Restore Failed ❌'),
                      ),
                    ),
                  );
                }
              } else if (value == 'reports') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    const Icon(Icons.pie_chart, size: 20),
                    const SizedBox(width: 8),
                    Text(t['reports_analysis'] ?? 'Reports & Analysis'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(t['backup_to_cloud'] ?? 'Backup to Cloud'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    const Icon(Icons.cloud_download_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(t['restore_from_cloud'] ?? 'Restore from Cloud'),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // 1. Balance Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['net_balance'] ?? 'NET BALANCE',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${formatter.format(totals['net'] ?? 0)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F3D2F),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FBF9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['total_sales'] ?? 'Total Sales', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.arrow_upward_rounded, color: Color(0xFF5DB075), size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹${formatter.format(totals['sales'] ?? 0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF5DB075),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['total_expenses'] ?? 'Total Expenses', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.arrow_downward_rounded, color: Color(0xFFFF7A59), size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹${formatter.format(totals['expenses'] ?? 0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFF7A59),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Search & Filter Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.black45, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => ref.read(khataNotifierProvider.notifier).setSearchQuery(val),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: t['search_transactions'] ?? 'Search transactions...',
                                    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _showDateFilterBottomSheet(context, ref, state, t),
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: (state.filterStartDate != null || state.filterEndDate != null)
                                ? const Color(0xFF0F3D2F)
                                : Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: (state.filterStartDate != null || state.filterEndDate != null)
                                ? Colors.white
                                : const Color(0xFF0F3D2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Tabs
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildTab('All', state.activeTab, ref, t),
                        _buildTab('Sales', state.activeTab, ref, t),
                        _buildTab('Expenses', state.activeTab, ref, t),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Recent Activity
                  Text(
                    t['recent_activity'] ?? 'Recent Activity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          t['no_transactions_found'] ?? 'No transactions found.\nTap + to add a new entry.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black45, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...transactions.map((tItem) => _buildTransactionCard(context, tItem, formatter)),
                    
                  const SizedBox(height: 100), // Space for FAB
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F3D2F),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
      ),
    );
  }

  Widget _buildTab(String label, String activeTab, WidgetRef ref, Map<String, String> t) {
    final isActive = label == activeTab || (label == 'All' && activeTab == 'All Transactions');
    final displayLabel = label == 'All' ? 'All Transactions' : label;
    
    String tabText = displayLabel;
    if (label == 'All') {
      tabText = t['all_transactions'] ?? 'All Transactions';
    } else if (label == 'Sales') {
      tabText = t['total_sales'] ?? 'Sales';
    } else if (label == 'Expenses') {
      tabText = t['total_expenses'] ?? 'Expenses';
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(khataNotifierProvider.notifier).setTab(displayLabel == 'All Transactions' ? 'All' : label);
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            tabText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? const Color(0xFF0F3D2F) : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> tx, NumberFormat formatter) {
    final isExpense = tx['isExpense'] as bool? ?? false;
    final title = tx['title'] as String? ?? 'Unknown';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final dateStr = tx['date'] as String? ?? DateTime.now().toIso8601String();
    final payment = tx['paymentMethod'] as String? ?? 'Cash';
    final iconCode = tx['categoryIcon'] as int? ?? Icons.receipt_long.codePoint;
    
    final date = DateTime.parse(dateStr);
    final formattedDate = DateFormat('dd MMM yyyy').format(date);

    final colorBg = isExpense ? const Color(0xFFFCEFE9) : const Color(0xFFE6F4EA);
    final colorIcon = isExpense ? const Color(0xFFD64A20) : const Color(0xFF1E8E3E);
    final colorAmt = isExpense ? const Color(0xFFFF7A59) : const Color(0xFF5DB075);
    final prefix = isExpense ? '-' : '+';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(transactionToEdit: tx),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: colorBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_safeIcon(iconCode), color: colorIcon, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3748),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$formattedDate • $payment',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$prefix₹${formatter.format(amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colorAmt,
            ),
          ),
        ],
      ),
    ));
  }

  void _showDateFilterBottomSheet(BuildContext context, WidgetRef ref, KhataState state, Map<String, String> t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t['filter_by_date'] ?? 'Filter by Date', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (state.filterStartDate != null || state.filterEndDate != null)
                    TextButton(
                      onPressed: () {
                        ref.read(khataNotifierProvider.notifier).setDateFilter(null, null);
                        Navigator.pop(context);
                      },
                      child: Text(t['clear'] ?? 'Clear', style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(t['all_time'] ?? 'All Time', style: const TextStyle(fontWeight: FontWeight.w600)),
                leading: const Icon(Icons.calendar_today, color: Colors.black54),
                onTap: () {
                  ref.read(khataNotifierProvider.notifier).setDateFilter(null, null);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(t['today'] ?? 'Today', style: const TextStyle(fontWeight: FontWeight.w600)),
                leading: const Icon(Icons.today, color: Colors.black54),
                onTap: () {
                  final now = DateTime.now();
                  ref.read(khataNotifierProvider.notifier).setDateFilter(now, now);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(t['this_month'] ?? 'This Month', style: const TextStyle(fontWeight: FontWeight.w600)),
                leading: const Icon(Icons.calendar_month, color: Colors.black54),
                onTap: () {
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, 1);
                  final end = DateTime(now.year, now.month + 1, 0); // Last day of month
                  ref.read(khataNotifierProvider.notifier).setDateFilter(start, end);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(t['custom_range'] ?? 'Custom Range...', style: const TextStyle(fontWeight: FontWeight.w600)),
                leading: const Icon(Icons.date_range, color: Colors.black54),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2050),
                    initialDateRange: state.filterStartDate != null && state.filterEndDate != null 
                        ? DateTimeRange(start: state.filterStartDate!, end: state.filterEndDate!)
                        : null,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF0F3D2F), // header background color
                            onPrimary: Colors.white, // header text color
                            onSurface: Colors.black, // body text color
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref.read(khataNotifierProvider.notifier).setDateFilter(picked.start, picked.end);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
  // Safe icon lookup to avoid non-constant IconData tree-shake error in release builds
  static IconData _safeIcon(int codePoint) {
    const Map<int, IconData> _iconMap = {
      0xe8b0: Icons.receipt_long,
      0xe1bc: Icons.agriculture,
      0xf8e5: Icons.water_drop,
      0xe3f4: Icons.grass,
      0xe553: Icons.store,
      0xe145: Icons.add_shopping_cart,
      0xe15b: Icons.attach_money,
      0xe87d: Icons.home,
      0xe030: Icons.directions_car,
      0xe1d8: Icons.build,
      0xe25a: Icons.local_hospital,
      0xe8b6: Icons.school,
      0xe7ef: Icons.people,
      0xe3a5: Icons.food_bank,
      0xe7f2: Icons.person,
      0xe53f: Icons.shopping_cart,
      0xe559: Icons.star,
      0xe5c3: Icons.trending_up,
      0xe164: Icons.account_balance_wallet,
      0xe227: Icons.category,
    };
    return _iconMap[codePoint] ?? Icons.receipt_long;
  }
}

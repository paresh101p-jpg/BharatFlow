import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/widgets/translated_text.dart';
import '../providers/khata_providers.dart';
import '../utils/khata_icons.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  String _timeFilter = '7 Days'; // '7 Days', 'This Month', 'This Year'

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(khataNotifierProvider);
    final allTransactions = state.transactions;
    final t = ref.watch(translationsProvider);

    // Filter transactions based on TimeFilter
    final now = DateTime.now();
    DateTime startDate;

    if (_timeFilter == '7 Days') {
      startDate = now.subtract(const Duration(days: 6));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
    } else if (_timeFilter == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
    } else {
      startDate = DateTime(now.year, 1, 1);
    }

    final filtered = allTransactions.where((tx) {
      final dateStr = tx['date'] as String?;
      if (dateStr == null) return false;
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return false;
      final txDate = DateTime(dt.year, dt.month, dt.day);
      return txDate.isAfter(startDate.subtract(const Duration(days: 1)));
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    final Map<String, double> categorySums = {};

    for (var tx in filtered) {
      final isExpense = tx['isExpense'] as bool? ?? false;
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final category = tx['category'] as String? ?? 'General';

      if (isExpense) {
        totalExpense += amount;
      } else {
        totalIncome += amount;
      }

      categorySums[category] = (categorySums[category] ?? 0.0) + amount;
    }

    // Sort categories by amount
    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final formatter = NumberFormat("#,##,###.##", "en_IN");

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F5), // Light neumorphic background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F3F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F3D2F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t['reports_analysis'] ?? 'Reports & Analysis', style: const TextStyle(color: Color(0xFF0F3D2F), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Filters
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(4, 4)),
                ],
              ),
              child: Row(
                children: [
                  _buildTimeTab('7 Days', t['seven_days'] ?? '7 Days'),
                  _buildTimeTab('This Month', t['this_month'] ?? 'This Month'),
                  _buildTimeTab('This Year', t['this_year'] ?? 'This Year'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary Cards (3D Neumorphic look)
            Row(
              children: [
                Expanded(child: _buildSummaryCard(t['income'] ?? 'Income', totalIncome, const Color(0xFFE6F4EA), const Color(0xFF1E8E3E), isIncome: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildSummaryCard(t['expense'] ?? 'Expense', totalExpense, const Color(0xFFFCEFE9), const Color(0xFFD64A20), isIncome: false)),
              ],
            ),
            const SizedBox(height: 32),

            // Graph Section
            Text(t['cashflow_overview'] ?? 'Cashflow Overview', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3748))),
            const SizedBox(height: 16),
            _buildChartCard(totalIncome, totalExpense, t),
            const SizedBox(height: 32),

            // Category Breakdown
            Text(t['top_categories'] ?? 'Top Categories', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3748))),
            const SizedBox(height: 16),
            if (sortedCategories.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(t['no_data_available_period'] ?? 'No data available for this period.', style: const TextStyle(color: Colors.black45)),
              ))
            else
              ...sortedCategories.map((e) => _buildCategoryRow(e.key, e.value, totalIncome + totalExpense, formatter)),
              
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTab(String value, String label) {
    final isActive = _timeFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _timeFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0F3D2F) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [BoxShadow(color: const Color(0xFF0F3D2F).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: isActive ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color bgColor, Color textColor, {required bool isIncome}) {
    final formatter = NumberFormat("#,##,###.##", "en_IN");
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          const BoxShadow(color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: textColor, size: 16),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${formatter.format(amount)}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(double income, double expense, Map<String, String> t) {
    if (income == 0 && expense == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(4, 4))],
        ),
        alignment: Alignment.center,
        child: Text(t['no_transactions_chart'] ?? 'No transactions to chart.', style: const TextStyle(color: Colors.black45)),
      );
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          const BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-5, -5)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(5, 5)),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (income > expense ? income : expense) * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final text = value == 0 ? (t['income'] ?? 'Income') : (t['expense'] ?? 'Expense');
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                  );
                },
                reservedSize: 32,
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: income,
                  color: const Color(0xFF1E8E3E),
                  width: 40,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: (income > expense ? income : expense) * 1.2, color: const Color(0xFFE6F4EA)),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: expense,
                  color: const Color(0xFFD64A20),
                  width: 40,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: (income > expense ? income : expense) * 1.2, color: const Color(0xFFFCEFE9)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String category, double amount, double total, NumberFormat formatter) {
    IconData icon = Icons.category;
    Color iconColor = Colors.blueGrey;
    final percent = total == 0 ? 0 : amount / total;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(2, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TranslatedText(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D3748))),
              ),
              Text('₹${formatter.format(amount)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.toDouble(),
              backgroundColor: Colors.grey[200],
              color: const Color(0xFF0F3D2F),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

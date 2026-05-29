import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/mandi_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';

class MandiProductHistoryScreen extends ConsumerStatefulWidget {
  final String mandiName;
  final String commodityName;
  final String? variety;
  final String? grade;

  const MandiProductHistoryScreen({
    super.key,
    required this.mandiName,
    required this.commodityName,
    this.variety,
    this.grade,
  });

  @override
  ConsumerState<MandiProductHistoryScreen> createState() => _MandiProductHistoryScreenState();
}

class _MandiProductHistoryScreenState extends ConsumerState<MandiProductHistoryScreen> {
  int _selectedMonths = 3;

  @override
Widget build(BuildContext context) {
  final t = ref.read(translationsProvider);
  final historyKey = "${widget.mandiName}|${widget.commodityName}|$_selectedMonths";
  final historyAsync = ref.watch(mandiProductHistoryProvider(historyKey));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.commodityName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(t),
            _buildTimeRangeSelector(),
            _buildUnitSelector(),
            historyAsync.when(
              data: (historyData) => _buildHistoryContent(historyData, t),
              loading: () => const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
              ),
              error: (e, stack) {
                print('❌ ERROR: $e');
                return Center(child: Text('Error: $e'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1B5E20),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.mandiName,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.variety != null) ...[
                _headerChip(widget.variety!, Colors.white24),
                const SizedBox(width: 8),
              ],
              if (widget.grade != null) ...[
                _headerChip(widget.grade!, Colors.white24),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              _buildShareButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final ranges = [
      {'label': '3M', 'value': 3},
      {'label': '1Y', 'value': 12},
      {'label': '3Y', 'value': 36},
      {'label': '5Y', 'value': 60},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ranges.map((r) {
          final isSelected = _selectedMonths == r['value'];
          final isLocked = (r['value'] as int) > 3;

          return GestureDetector(
            onTap: () {
              if (isLocked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('History more than 3 months is Coming Soon!'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFF1B5E20),
                  ),
                );
                return;
              }
              setState(() => _selectedMonths = r['value'] as int);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
                border: Border.all(
                  color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    r['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.lock_outline, size: 12, color: Colors.grey.shade400),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryContent(List<Map<String, dynamic>> data, Map<String, String> t) {
    if (data.isEmpty) {
      return SizedBox(
        height: 300,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.query_stats, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              t['no_history_found'] ?? "No historical data found for this range.",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final selectedUnit = ref.watch(priceUnitProvider);
    double minPrice = double.infinity;
    double maxPrice = 0;
    double avgPrice = 0;
    for (var item in data) {
      final p = (item['modal_price'] as num).toDouble();
      if (p < minPrice) minPrice = p;
      if (p > maxPrice) maxPrice = p;
      avgPrice += p;
    }
    avgPrice /= data.length;

    // Conversion logic
    double convert(double p) {
      if (selectedUnit == 'KG') return p / 100;
      if (selectedUnit == '20 KG') return p / 5;
      if (selectedUnit == '40 KG') return p / 2.5;
      return p;
    }

    final displayMin = convert(minPrice);
    final displayMax = convert(maxPrice);
    final displayAvg = convert(avgPrice);

    return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    children: [
      if (data.length > 1) _buildChart(data),
      if (data.length == 1) Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Text('Only 1 data point available', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
          const SizedBox(height: 24),
          _buildStats(displayMin, displayMax, displayAvg, t),
          const SizedBox(height: 24),
          _buildHistoryList(data, t),
        ],
      ),
    );
  }

  Widget _buildChart(List<Map<String, dynamic>> data) {
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['modal_price'] as num).toDouble());
    }).toList();

    double minVal = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    double padding = (maxVal - minVal) * 0.15;
    if (padding == 0) padding = 100;

    return Container(
      height: 250,
      width: double.infinity,
      padding: const EdgeInsets.only(right: 16, top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '₹${value.toInt()}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minVal - padding,
          maxY: maxVal + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF1B5E20),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1B5E20).withOpacity(0.3),
                    const Color(0xFF1B5E20).withOpacity(0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(double min, double max, double avg, Map<String, String> t) {
    return Row(
      children: [
        _statBox(t['min'] ?? 'Min', min, Colors.blue),
        const SizedBox(width: 12),
        _statBox(t['avg'] ?? 'Avg', avg, Colors.green),
        const SizedBox(width: 12),
        _statBox(t['max'] ?? 'Max', max, Colors.red),
      ],
    );
  }

  Widget _statBox(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '₹${value.toStringAsFixed(value < 100 ? 1 : 0)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> data, Map<String, String> t) {
    List<Map<String, dynamic>> transitions = [];
    double? currentP;
    for (var item in data) {
      double p = (item['modal_price'] as num).toDouble();
      if (currentP == null || p != currentP) {
        transitions.add(item);
        currentP = p;
      }
    }
    final sortedData = transitions.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            t['price_logs'] ?? "Price Logs",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedData.length,
          itemBuilder: (context, index) {
            final item = sortedData[index];
            final date = item['arrival_date'] as String;
            final rawPrice = (item['modal_price'] as num).toDouble();
            final selectedUnit = ref.watch(priceUnitProvider);
            
            double price = rawPrice;
            if (selectedUnit == 'KG') price = rawPrice / 100;
            else if (selectedUnit == '20 KG') price = rawPrice / 5;
            else if (selectedUnit == '40 KG') price = rawPrice / 2.5;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(DateTime.parse(date)),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '₹${price.toStringAsFixed(price < 100 ? 1 : 0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const DynamicAdmobCardWidget(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildUnitSelector() {
    final selectedUnit = ref.watch(priceUnitProvider);
    final units = ['Quintal', 'KG', '20 KG', '40 KG'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: units.map((u) {
          final isSelected = selectedUnit == u;
          return GestureDetector(
            onTap: () => ref.read(priceUnitProvider.notifier).state = u,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.orange : Colors.grey.shade300,
                ),
              ),
              child: Text(
                u,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: _shareProductHistory,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text(
              'Share',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _shareProductHistory() {
    final historyKey = "${widget.mandiName}|${widget.commodityName}|$_selectedMonths";
    final historyState = ref.read(mandiProductHistoryProvider(historyKey));

    if (historyState is! AsyncData<List<Map<String, dynamic>>>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for historical data to load...')),
      );
      return;
    }

    final data = historyState.value;
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No history data available to share.')),
      );
      return;
    }

    final selectedUnit = ref.read(priceUnitProvider);
    double minPrice = double.infinity;
    double maxPrice = 0;
    double avgPrice = 0;
    for (var item in data) {
      final p = (item['modal_price'] as num).toDouble();
      if (p < minPrice) minPrice = p;
      if (p > maxPrice) maxPrice = p;
      avgPrice += p;
    }
    avgPrice /= data.length;

    // Conversion logic
    double convert(double p) {
      if (selectedUnit == 'KG') return p / 100;
      if (selectedUnit == '20 KG') return p / 5;
      if (selectedUnit == '40 KG') return p / 2.5;
      return p;
    }

    final displayMin = convert(minPrice);
    final displayMax = convert(maxPrice);
    final displayAvg = convert(avgPrice);
    final suffix = selectedUnit == 'Quintal' ? '/q' : selectedUnit == 'KG' ? '/kg' : selectedUnit == '20 KG' ? '/20k' : '/40k';

    final buffer = StringBuffer();
    buffer.writeln('🌾 *BharatFlow - Price History* 🌾\n');
    buffer.writeln('📦 *Commodity:* ${widget.commodityName}');
    buffer.writeln('📍 *Mandi:* ${widget.mandiName}');
    if (widget.variety != null) {
      buffer.writeln('🌱 *Variety:* ${widget.variety}');
    }
    if (widget.grade != null) {
      buffer.writeln('🏷️ *Grade:* ${widget.grade}');
    }
    buffer.writeln('⏱️ *Range:* Last $_selectedMonths Months');
    buffer.writeln('⚖️ *Unit:* $selectedUnit\n');

    buffer.writeln('📊 *Price Summary:*');
    buffer.writeln('📉 Min Price: ₹${displayMin.toStringAsFixed(displayMin < 100 ? 1 : 0)}$suffix');
    buffer.writeln('📈 Max Price: ₹${displayMax.toStringAsFixed(displayMax < 100 ? 1 : 0)}$suffix');
    buffer.writeln('🔄 Avg Price: ₹${displayAvg.toStringAsFixed(displayAvg < 100 ? 1 : 0)}$suffix\n');

    buffer.writeln('📅 *Price Logs:*');
    List<Map<String, dynamic>> transitions = [];
    double? currentP;
    for (var item in data) {
      double p = (item['modal_price'] as num).toDouble();
      if (currentP == null || p != currentP) {
        transitions.add(item);
        currentP = p;
      }
    }
    final sortedData = transitions.reversed.toList();
    // Let's take up to the top 10 logs to keep the share message clean and under limits
    final logLimit = sortedData.length > 10 ? 10 : sortedData.length;
    for (int i = 0; i < logLimit; i++) {
      final item = sortedData[i];
      final date = item['arrival_date'] as String;
      final rawPrice = (item['modal_price'] as num).toDouble();
      final price = convert(rawPrice);
      final formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(date));
      buffer.writeln('• $formattedDate: ₹${price.toStringAsFixed(price < 100 ? 1 : 0)}$suffix');
    }
    if (sortedData.length > 10) {
      buffer.writeln('... and ${sortedData.length - 10} more logs.');
    }

    buffer.writeln('\n📲 Download *BharatFlow App* for live mandi prices & crop calendar:');
    buffer.writeln('https://play.google.com/store/apps/details?id=com.BharatFlow');

    Share.share(buffer.toString(), subject: 'Price History of ${widget.commodityName} at ${widget.mandiName}');
  }
}
import 'package:flutter/material.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';

class WeatherHistoryScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String city;

  const WeatherHistoryScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.city,
  });

  @override
  State<WeatherHistoryScreen> createState() => _WeatherHistoryScreenState();
}

class _WeatherHistoryScreenState extends State<WeatherHistoryScreen> {
  bool _isLoading = true;
  List<FlSpot> _maxSpots = [];
  List<FlSpot> _minSpots = [];
  List<BarChartGroupData> _rainBarGroups = [];
  List<Map<String, dynamic>> _yearlySummaries = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final now = DateTime.now();
      final startDate = "${now.year - 10}-01-01";
      final endDate = "${now.year - 1}-12-31";

      final url = 'https://archive-api.open-meteo.com/v1/archive?latitude=${widget.latitude}&longitude=${widget.longitude}&start_date=$startDate&end_date=$endDate&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=auto';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final daily = data['daily'];
        final times = daily['time'] as List;
        final maxTemps = daily['temperature_2m_max'] as List;
        final minTemps = daily['temperature_2m_min'] as List;
        final rainSums = daily['precipitation_sum'] as List;

        Map<int, List<double>> yearlyMaxes = {};
        Map<int, List<double>> yearlyMins = {};
        Map<int, List<double>> yearlyRainDaily = {};

        for (int i = 0; i < times.length; i++) {
          final year = DateTime.parse(times[i]).year;
          if (maxTemps[i] != null) {
            yearlyMaxes.putIfAbsent(year, () => []).add((maxTemps[i] as num).toDouble());
          }
          if (minTemps[i] != null) {
            yearlyMins.putIfAbsent(year, () => []).add((minTemps[i] as num).toDouble());
          }
          if (rainSums[i] != null) {
            yearlyRainDaily.putIfAbsent(year, () => []).add((rainSums[i] as num).toDouble());
          }
        }

        List<FlSpot> maxSpots = [];
        List<FlSpot> minSpots = [];
        List<BarChartGroupData> rainBarGroups = [];
        List<Map<String, dynamic>> summaries = [];

        int index = 0;
        yearlyMaxes.forEach((year, values) {
          final max = values.reduce((a, b) => a > b ? a : b);
          final min = yearlyMins[year]!.reduce((a, b) => a < b ? a : b);
          final peakRain = yearlyRainDaily[year]!.reduce((a, b) => a > b ? a : b);
          
          maxSpots.add(FlSpot(index.toDouble(), max));
          minSpots.add(FlSpot(index.toDouble(), min));
          
          rainBarGroups.add(BarChartGroupData(
            x: index,
            barRods: [BarChartRodData(toY: peakRain, color: Colors.blue.withOpacity(0.5), width: 12, borderRadius: BorderRadius.circular(4))],
          ));

          summaries.add({
            'year': year,
            'max': max.toStringAsFixed(1),
            'min': min.toStringAsFixed(1),
            'rain': peakRain.toStringAsFixed(1),
          });
          index++;
        });

        setState(() {
          _maxSpots = maxSpots;
          _minSpots = minSpots;
          _rainBarGroups = rainBarGroups;
          _yearlySummaries = summaries.reversed.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching weather history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('10-Year Climate History', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            Text(widget.city, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChartCard(),
                  const SizedBox(height: 24),
                  _buildRainChartCard(),
                  const SizedBox(height: 16),
                  const DynamicAdmobCardWidget(),
                  const SizedBox(height: 24),
                  const Text('YEARLY TRENDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _yearlySummaries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _yearlySummaries[index];
                      return _buildHistoryCard(item);
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Temp History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _legendItem('Max', Colors.orange),
                  const SizedBox(width: 12),
                  _legendItem('Min', Colors.blue),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        if (val % 2 != 0) return const SizedBox();
                        final index = val.toInt();
                        if (index < 0 || index >= _yearlySummaries.length) return const SizedBox();
                        return Text(
                          _yearlySummaries.reversed.toList()[index]['year'].toString().substring(2),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _maxSpots,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.1)),
                  ),
                  LineChartBarData(
                    spots: _minSpots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRainChartCard() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Peak Rainfall Day (Yearly)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final index = val.toInt();
                        if (index < 0 || index >= _yearlySummaries.length) return const SizedBox();
                        return Text(
                          _yearlySummaries.reversed.toList()[index]['year'].toString().substring(2),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _rainBarGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item['year'].toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          Row(
            children: [
              _miniValue('🔥', '${item['max']}°C', Colors.orange),
              const SizedBox(width: 12),
              _miniValue('❄️', '${item['min']}°C', Colors.blue),
              const SizedBox(width: 12),
              _miniValue('🌧️', '${item['rain']}mm', Colors.indigo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniValue(String emoji, String val, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

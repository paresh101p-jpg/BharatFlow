import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FuelHistoryScreen extends StatelessWidget {
  final String fuelType;
  final String city;
  final List<Map<String, dynamic>> history;
  final Color themeColor;

  const FuelHistoryScreen({
    super.key,
    required this.fuelType,
    required this.city,
    required this.history,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Premium Header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: themeColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "$fuelType History",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [themeColor, themeColor.withOpacity(0.8)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getIcon(),
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),

          // 2. City Info Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    "Historical Rates for $city",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ),

          // 3. History List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Filter history to only show price changes
                var ascendingHistory = history.reversed.toList();
                List<Map<String, dynamic>> transitions = [];
                double? currentP;
                
                for (var item in ascendingHistory) {
                  double? p = double.tryParse(item[fuelType.toLowerCase()]?.toString() ?? '');
                  if (p == null) continue;
                  
                  if (currentP == null || p != currentP) {
                    transitions.add(item);
                    currentP = p;
                  }
                }
                
                var filteredHistory = transitions.reversed.toList();

                if (index >= filteredHistory.length) return null;

                final item = filteredHistory[index];
                final date = DateTime.parse(item['recorded_at']);
                final double? currentVal = double.tryParse(item[fuelType.toLowerCase()]?.toString() ?? '');
                
                double? prevVal;
                if (index + 1 < filteredHistory.length) {
                  prevVal = double.tryParse(filteredHistory[index + 1][fuelType.toLowerCase()]?.toString() ?? '');
                }

                Widget trendWidget = const SizedBox.shrink();
                if (currentVal != null && prevVal != null && prevVal > 0) {
                  double diff = currentVal - prevVal;
                  double pct = (diff / prevVal) * 100;
                  bool isUp = diff > 0;
                  Color trendColor = isUp ? Colors.red : Colors.green;
                  IconData trendIcon = isUp ? Icons.arrow_upward : Icons.arrow_downward;
                  
                  trendWidget = Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(trendIcon, size: 12, color: trendColor),
                        const SizedBox(width: 4),
                        Text(
                          '${pct.abs().toStringAsFixed(2)}% (₹${diff.abs().toStringAsFixed(2)})',
                          style: TextStyle(fontSize: 11, color: trendColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: index == 0 ? Border.all(color: themeColor.withOpacity(0.3), width: 1.5) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, dd MMMM').format(date),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            index == 0 ? "Latest Record" : "Previous Rate",
                            style: TextStyle(fontSize: 11, color: index == 0 ? themeColor : Colors.grey),
                          ),
                          if (trendWidget is! SizedBox) trendWidget,
                        ],
                      ),
                      Text(
                        "₹${currentVal?.toStringAsFixed(2) ?? '...'}",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: themeColor),
                      ),
                    ],
                  ),
                );
              },
              childCount: () {
                var ascendingHistory = history.reversed.toList();
                List<Map<String, dynamic>> transitions = [];
                double? currentP;
                for (var item in ascendingHistory) {
                  double? p = double.tryParse(item[fuelType.toLowerCase()]?.toString() ?? '');
                  if (p == null) continue;
                  if (currentP == null || p != currentP) {
                    transitions.add(item);
                    currentP = p;
                  }
                }
                return transitions.length;
              }(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (fuelType.toLowerCase()) {
      case 'petrol': return Icons.local_gas_station;
      case 'diesel': return Icons.ev_station;
      case 'cng': return Icons.eco_rounded;
      case 'lpg': return Icons.propane_tank;
      default: return Icons.local_gas_station;
    }
  }
}

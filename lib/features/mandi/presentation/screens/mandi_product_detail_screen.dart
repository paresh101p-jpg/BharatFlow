import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../providers/mandi_providers.dart';

class MandiProductDetailScreen extends ConsumerWidget {
  final String mandiName;
  final String commodityName;
  final List<Map<String, dynamic>> varietyList;

  const MandiProductDetailScreen({
    super.key,
    required this.mandiName,
    required this.commodityName,
    required this.varietyList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final selectedUnit = ref.watch(priceUnitProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("$commodityName - $mandiName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Unit Selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['Quintal', 'KG', '20 KG', '40 KG'].map((u) {
                final isSelected = selectedUnit == u;
                return GestureDetector(
                  onTap: () => ref.read(priceUnitProvider.notifier).state = u,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade300),
                    ),
                    child: Text(
                      u,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 9,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Header Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(bottom: BorderSide(color: Colors.green[100]!, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t['variety_grade'] ?? "VARIETY & GRADE", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900], fontSize: 12, letterSpacing: 0.5)),
                Text(selectedUnit == 'Quintal' ? (t['price_per_qtl'] ?? "PRICE (PER QTL)") : "PRICE (PER $selectedUnit)", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900], fontSize: 12, letterSpacing: 0.5)),
              ],
            ),
          ),
          
          // Variety List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: varietyList.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, index) {
                final item = varietyList[index];
                final rawPrice = (item['modal_price'] as num).toDouble();
                final rawMin = (item['min_price'] as num).toDouble();
                final rawMax = (item['max_price'] as num).toDouble();
                
                double price = rawPrice;
                double minP = rawMin;
                double maxP = rawMax;
                
                if (selectedUnit == 'KG') {
                  price = rawPrice / 100; minP = rawMin / 100; maxP = rawMax / 100;
                } else if (selectedUnit == '20 KG') {
                  price = rawPrice / 5; minP = rawMin / 5; maxP = rawMax / 5;
                } else if (selectedUnit == '40 KG') {
                  price = rawPrice / 2.5; minP = rawMin / 2.5; maxP = rawMax / 2.5;
                }

                return Container(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    title: Text(
                      item['variety'] ?? 'General Variety',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "${t['grade'] ?? 'Grade'}: ${item['grade'] ?? 'FAQ'}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₹${price.toStringAsFixed(price < 100 ? 1 : 0)}",
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${t['range'] ?? 'Range'}: ₹${minP.toStringAsFixed(minP < 100 ? 1 : 0)} - ₹${maxP.toStringAsFixed(maxP < 100 ? 1 : 0)}", 
                          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

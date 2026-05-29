import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/location_provider.dart' as core_loc;
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/widgets/translated_text.dart';

class SarkariShopScreen extends ConsumerStatefulWidget {
  const SarkariShopScreen({super.key});

  @override
  ConsumerState<SarkariShopScreen> createState() => _SarkariShopScreenState();
}

class _SarkariShopScreenState extends ConsumerState<SarkariShopScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rates = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final loc = ref.read(core_loc.locationProvider);
      final supabase = Supabase.instance.client;

      // Filter by State and District if available
      var query = supabase.from('all_india_agri_rates').select();
      
      if (loc.state.isNotEmpty) {
        query = query.eq('state', loc.state);
      }
      if (loc.city.isNotEmpty) {
        // District is often same as city in our data
        // query = query.eq('district', loc.city); 
      }

      var response = await query.order('item_name', ascending: true);
      
      // Fallback to National rates if no state-specific data found
      if (response.isEmpty && loc.state.isNotEmpty) {
        response = await supabase.from('all_india_agri_rates').select().order('item_name', ascending: true).limit(50);
      }

      setState(() {
        _rates = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(t['sarkari_shop_title'] ?? 'Sarkari Shop (Govt Rates)'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRates,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0D47A1).withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF0D47A1), size: 16),
                const SizedBox(width: 8),
                Text(
                  '${t['bhav_for'] ?? 'Bhav for: '} ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                ),
                TranslatedText(
                  loc.state,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                ),
                if (loc.city.isNotEmpty) ...[
                  const Text(
                    ' > ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                  ),
                  TranslatedText(
                    loc.city,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                        : _rates.isEmpty
                        ? _buildEmptyState(t)
                        : ListView.builder(
                            itemCount: _rates.length,
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (context, index) {
                              final item = _rates[index];
                              return _buildRateCard(item, t);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard(Map<String, dynamic> item, Map<String, String> t) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getItemIcon(item['item_name']), color: const Color(0xFF0D47A1)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    item['item_name'] ?? 'Unknown Item',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${t['source'] ?? 'Source'}: ${item['source_api'] ?? 'Govt Dept'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 10, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(t['updated_today'] ?? 'updated Today', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${item['govt_rate']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  '${t['per'] ?? 'per'} ${t[item['unit']?.toString().toLowerCase()] ?? item['unit'] ?? 'unit'}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getItemIcon(String? name) {
    final n = name?.toLowerCase() ?? '';
    if (n.contains('urea') || n.contains('dap') || n.contains('fertilizer')) return Icons.science;
    if (n.contains('seed')) return Icons.grass;
    return Icons.shopping_basket;
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!),
          TextButton(onPressed: _fetchRates, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Map<String, String> t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.blue.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(t['no_govt_rates_found'] ?? 'No govt rates found for your area'),
          Text(t['syncing_all_india_db'] ?? 'Syncing with All India Database...', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

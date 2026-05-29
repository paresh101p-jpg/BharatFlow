import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/leader_model.dart';

class BattleModeWidget extends StatefulWidget {
  const BattleModeWidget({super.key});

  @override
  State<BattleModeWidget> createState() => _BattleModeWidgetState();
}

class _BattleModeWidgetState extends State<BattleModeWidget> {
  LeaderModel? _leader1;
  LeaderModel? _leader2;
  bool _isSearching1 = false;
  bool _isSearching2 = false;

  void _showLeaderSearchDialog(int position) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _LeaderSearchBottomSheet(
        onSelect: (leader) {
          setState(() {
            if (position == 1) {
              _leader1 = leader;
            } else {
              _leader2 = leader;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Battle Arena', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
          const SizedBox(height: 8),
          const Text('Select two leaders to compare their real stats', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Selection Row
          Row(
            children: [
              Expanded(child: _buildSelectorBox(1, _leader1)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('VS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.red, fontStyle: FontStyle.italic)),
              ),
              Expanded(child: _buildSelectorBox(2, _leader2)),
            ],
          ),

          if (_leader1 != null && _leader2 != null) ...[
            const SizedBox(height: 32),
            _buildComparisonRow('Total Likes', _leader1!.totalLikes.toDouble(), _leader2!.totalLikes.toDouble(), isReverse: false),
            const SizedBox(height: 16),
            _buildComparisonRow('Criminal Cases', (_leader1!.criminalCases).toDouble(), (_leader2!.criminalCases).toDouble(), isReverse: true),
            const SizedBox(height: 16),
            _buildFinancialComparisonRow('Assets', _leader1!.assets, _leader2!.assets),
          ] else ...[
            const SizedBox(height: 60),
            Center(
              child: Icon(Icons.sports_kabaddi, size: 100, color: Colors.grey.shade300),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSelectorBox(int position, LeaderModel? leader) {
    return GestureDetector(
      onTap: () => _showLeaderSearchDialog(position),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: leader != null ? Colors.green : Colors.grey.shade300, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: leader == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle, color: Colors.green, size: 32),
                  SizedBox(height: 8),
                  Text('Select Neta', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: leader.photoUrl != null ? NetworkImage(leader.photoUrl!) : null,
                    child: leader.photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(height: 8),
                  Text(leader.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(leader.party, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  Widget _buildComparisonRow(String title, double val1, double val2, {required bool isReverse}) {
    final double maxVal = (val1 > val2 ? val1 : val2) == 0 ? 1 : (val1 > val2 ? val1 : val2);
    final double pct1 = val1 / maxVal;
    final double pct2 = val2 / maxVal;

    // isReverse means higher is worse (like criminal cases)
    Color color1 = isReverse ? (val1 > val2 ? Colors.red : Colors.green) : (val1 > val2 ? Colors.green : Colors.red);
    Color color2 = isReverse ? (val2 > val1 ? Colors.red : Colors.green) : (val2 > val1 ? Colors.green : Colors.red);

    if (val1 == val2) {
      color1 = Colors.blue;
      color2 = Colors.blue;
    }

    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(val1.toInt().toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color1)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct1,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: color1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(val2.toInt().toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color2)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct2,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: color2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialComparisonRow(String title, Map<String, dynamic>? assets1, Map<String, dynamic>? assets2) {
    double extractValue(Map<String, dynamic>? assets) {
      if (assets == null || !assets.containsKey('total')) return 0.0;
      String raw = assets['total'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(raw) ?? 0.0;
    }

    double val1 = extractValue(assets1);
    double val2 = extractValue(assets2);

    final double maxVal = (val1 > val2 ? val1 : val2) == 0 ? 1 : (val1 > val2 ? val1 : val2);
    final double pct1 = val1 / maxVal;
    final double pct2 = val2 / maxVal;

    Color color1 = val1 > val2 ? Colors.green : Colors.red;
    Color color2 = val2 > val1 ? Colors.green : Colors.red;

    if (val1 == val2) {
      color1 = Colors.blue;
      color2 = Colors.blue;
    }

    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${assets1?['total'] ?? '0'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color1)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct1,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: color1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₹${assets2?['total'] ?? '0'}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color2)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct2,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: color2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LeaderSearchBottomSheet extends StatefulWidget {
  final Function(LeaderModel) onSelect;
  const _LeaderSearchBottomSheet({required this.onSelect});

  @override
  State<_LeaderSearchBottomSheet> createState() => _LeaderSearchBottomSheetState();
}

class _LeaderSearchBottomSheetState extends State<_LeaderSearchBottomSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<LeaderModel> _results = [];
  bool _isLoading = false;

  void _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final q = query.trim();
      final res = await _supabase
          .from('leaders_master')
          .select()
          .or('name.ilike.%$q%,constituency.ilike.%$q%')
          .limit(20);
      setState(() {
        _results = (res as List).map((e) => LeaderModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Battle Search Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search leader by name or city...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final l = _results[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: l.photoUrl != null ? NetworkImage(l.photoUrl!) : null,
                          child: l.photoUrl == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${l.party} • ${l.constituency}'),
                        onTap: () {
                          widget.onSelect(l);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

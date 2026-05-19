import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_screen.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import '../providers/mandi_providers.dart';
import '../../data/repositories/mandi_repository.dart';

class ProfitCalculatorScreen extends ConsumerStatefulWidget {
  const ProfitCalculatorScreen({super.key});

  @override
  ConsumerState<ProfitCalculatorScreen> createState() => _ProfitCalculatorScreenState();
}

class _ProfitCalculatorScreenState extends ConsumerState<ProfitCalculatorScreen> {
  final _qtyController = TextEditingController(text: '100');
  final _costPriceController = TextEditingController(text: '2000');
  final _freightController = TextEditingController(text: '3000');
  final _extraCostController = TextEditingController(text: '0');
  final _commRateController = TextEditingController(text: '2'); // 2%
  final _laborController = TextEditingController(text: '20'); // 20 per Q
  
  Map<String, dynamic>? _selectedMandi;
  String? _selectedProduct;
  String _selectedUnit = 'Quintal'; 
  bool _isSellingMode = true; 
  
  List<Map<String, dynamic>> _availableProducts = [];
  bool _isProductLoading = false;

  final List<String> _units = ['KG', '20 KG', '40 KG', 'Quintal'];

  double get quantityRaw => double.tryParse(_qtyController.text) ?? 0;
  
  double get quantityInQuintals {
    switch (_selectedUnit) {
      case 'KG': return quantityRaw / 100;
      case '20 KG': return (quantityRaw * 20) / 100;
      case '40 KG': return (quantityRaw * 40) / 100;
      case 'Quintal': return quantityRaw;
      default: return quantityRaw;
    }
  }

  double get costPrice => double.tryParse(_costPriceController.text) ?? 0;
  double get freight => double.tryParse(_freightController.text) ?? 0;
  double get extraCost => double.tryParse(_extraCostController.text) ?? 0;
  double get commRate => double.tryParse(_commRateController.text) ?? 0;
  double get laborPerQ => double.tryParse(_laborController.text) ?? 0;

  @override
  void dispose() {
    _qtyController.dispose();
    _costPriceController.dispose();
    _freightController.dispose();
    _extraCostController.dispose();
    _commRateController.dispose();
    _laborController.dispose();
    super.dispose();
  }

  Future<void> _pickMandi() async {
    final repo = ref.read(mandiRepositoryProvider);
    final position = ref.read(userLocationProvider).valueOrNull;

    final selected = await showSearch<Map<String, dynamic>?>(
      context: context,
      delegate: MandiSearchDelegate(repo, position?.latitude, position?.longitude),
    );

    if (selected != null) {
      setState(() {
        _selectedMandi = selected;
        _selectedProduct = null;
        _availableProducts = [];
        _isProductLoading = true;
      });

      final dist = (selected['distance_km'] as num?)?.toDouble() ?? 0;
      if (dist > 0 && dist < 9000) {
        final autoFreight = (dist * quantityInQuintals * 4).toInt();
        _freightController.text = autoFreight.toString();
      }

      final products = await repo.fetchMandiProducts(selected['mandi_name']);
      setState(() {
        _availableProducts = products;
        _isProductLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleUserAsync = ref.watch(googleUserProvider);
    final photoUrl = googleUserAsync.when(data: (u) => u?.photoUrl, loading: () => null, error: (_, __) => null);
    final t = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildTopAppBar(context, photoUrl, t),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _buildModeToggle(t),
                const SizedBox(height: 16),
                _buildUnitSelector(t),
                const SizedBox(height: 16),
                _buildMandiAndProductSelector(t),
                const SizedBox(height: 16),
                _buildInputSection(t),
                const SizedBox(height: 24),
                _buildResultsSection(t),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    t['data_source'] ?? 'Data Source: DATA.GOV.IN',
                    style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show a success dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 10),
                  Text(t['analysis_saved'] ?? 'Analysis Saved!'),
                ],
              ),
              content: const Text('Your profit analysis has been saved to your local history successfully.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analysis saved to history!'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.analytics_outlined, color: Colors.white),
        label: Text(t['save_analysis'] ?? 'Save Analysis', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, String? photoUrl, Map<String, String> t) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Text(
        t['bharat_munafa_advisor'] ?? 'Bharat Munafa Advisor',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: CircleAvatar(
            radius: 18,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person) : null,
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildModeToggle(Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _modeButton(t['sell'] ?? 'I WANT TO SELL', true, Icons.trending_up, Colors.green)),
          Expanded(child: _modeButton(t['buy'] ?? 'I WANT TO BUY', false, Icons.shopping_bag_outlined, Colors.blue)),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool mode, IconData icon, Color activeColor) {
    bool isSelected = _isSellingMode == mode;
    return InkWell(
      onTap: () => setState(() => _isSellingMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitSelector(Map<String, String> t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['qty_unit'] ?? 'QUANTITY UNIT', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _units.map((unit) {
            bool isSelected = _selectedUnit == unit;
            return InkWell(
              onTap: () => setState(() => _selectedUnit = unit),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
                ),
                child: Text(unit, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMandiAndProductSelector(Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _glassDecoration(),
      child: Column(
        children: [
          InkWell(
            onTap: _pickMandi,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isSellingMode ? (t['source_buy'] ?? 'SOURCE (BUY FROM)') : (t['target_source'] ?? 'TARGET (SOURCE)'), style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text(_selectedMandi?['mandi_name'] ?? (t['search_mandi'] ?? 'Search Mandi'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (_selectedMandi != null)
                    IconButton(icon: const Icon(Icons.cancel, size: 16, color: Colors.redAccent), onPressed: () => setState(() { _selectedMandi = null; _selectedProduct = null; _availableProducts = []; }))
                  else
                    const Icon(Icons.search, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_selectedMandi != null)
            _isProductLoading 
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<String>(
                  value: _availableProducts.any((p) => p['commodity_name'] == _selectedProduct) ? _selectedProduct : null,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    labelText: t['select_product'] ?? 'SELECT PRODUCT',
                    labelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: _availableProducts.map((p) => p['commodity_name'].toString()).toSet().map((name) {
                    final pData = _availableProducts.firstWhere((e) => e['commodity_name'] == name);
                    return DropdownMenuItem(value: name, child: Text('$name (₹${pData['modal_price']})', style: const TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (val) {
                    final pData = _availableProducts.firstWhere((e) => e['commodity_name'] == val);
                    setState(() { _selectedProduct = val; _costPriceController.text = pData['modal_price'].toString(); });
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildInputSection(Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['cost_qty_data'] ?? 'COST & QUANTITY DATA', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          // Row 1: Quantity, Price, Freight
          Row(
            children: [
              Expanded(child: _smallInputField('${t['items'] ?? 'QTY'} ($_selectedUnit)', _qtyController)),
              const SizedBox(width: 8),
              Expanded(child: _smallInputField(_isSellingMode ? (t['buy_cost'] ?? 'BUY COST') : (t['budget'] ?? 'BUDGET'), _costPriceController)),
              const SizedBox(width: 8),
              Expanded(child: _smallInputField(t['transport'] ?? 'TRANSPORT', _freightController)),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Extra, Comm, Labor
          Row(
            children: [
              Expanded(child: _smallInputField(t['extra_cost'] ?? 'EXTRA COST', _extraCostController)),
              const SizedBox(width: 8),
              Expanded(child: _smallInputField(t['comm_percent'] ?? 'COMM (%)', _commRateController)),
              const SizedBox(width: 8),
              Expanded(child: _smallInputField(t['labor_per_q'] ?? 'LABOR / Q', _laborController)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallInputField(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            onChanged: (v) => setState(() {}),
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 4)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(Map<String, String> t) {
    if (_selectedProduct == null) return _buildDirectPL(t);

    final commodity = _selectedProduct!;
    final comparisonAsync = ref.watch(productComparisonProvider('$commodity:${!_isSellingMode}'));

    return comparisonAsync.when(
      data: (list) {
        if (list.isEmpty) return _buildDirectPL(t);
        
        final topMandi = list.first;
        final targetPrice = (topMandi['modal_price'] as num).toDouble();
        
        final qty = quantityInQuintals;
        final buyPrice = costPrice;
        final f = freight;
        final e = extraCost;
        final cRate = commRate / 100;
        final lPerQ = laborPerQ;
        
        final totalTargetVal = qty * targetPrice;
        final totalBaseVal = qty * buyPrice;
        final commission = totalTargetVal * cRate;
        final labor = qty * lPerQ;
        final totalExpenses = commission + f + labor + e;
        
        double netResult;
        String resultLabel;
        if (_isSellingMode) {
          netResult = totalTargetVal - totalBaseVal - totalExpenses;
          resultLabel = t['net_profit'] ?? 'NET PROFIT';
        } else {
          netResult = totalBaseVal - totalTargetVal - totalExpenses;
          resultLabel = t['net_saving'] ?? 'NET SAVING';
        }

        return Column(
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: _isSellingMode ? Colors.green : Colors.blue, size: 16),
                const SizedBox(width: 8),
                Text(_isSellingMode ? (t['ai_sell_opp'] ?? 'AI: Best Sell Opportunity') : (t['ai_buy_opp'] ?? 'AI: Best Buy Opportunity'), style: TextStyle(fontWeight: FontWeight.bold, color: _isSellingMode ? Colors.green : Colors.blue, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 10),
            _compactComparisonRow(buyPrice, targetPrice, netResult, resultLabel, t),
            const SizedBox(height: 10),
            _comparisonCard(topMandi['mandi_name'], _isSellingMode ? (t['selling_market'] ?? 'Selling Market') : (t['buying_market'] ?? 'Buying Market'), '₹${targetPrice.toInt()}', '₹${totalTargetVal.toInt()}', '−₹${totalExpenses.toInt()}', '₹${netResult.toInt()}', true, resultLabel, t),
            const SizedBox(height: 12),
            _buildExpenseSummary(commission, f, labor, e, t),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildDirectPL(t),
    );
  }

  Widget _compactComparisonRow(double buy, double target, double result, String label, Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade100)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat(_isSellingMode ? (t['buy_price_caps'] ?? 'BUY PRICE') : (t['your_budget_caps'] ?? 'YOUR BUDGET'), '₹${buy.toInt()}'),
          Icon(_isSellingMode ? Icons.arrow_forward : Icons.arrow_back, size: 14, color: Colors.blue),
          _miniStat(_isSellingMode ? (t['sell_price_caps'] ?? 'SELL PRICE') : (t['mandi_price_caps'] ?? 'MANDI PRICE'), '₹${target.toInt()}'),
          _miniStat(label, '₹${result.toInt()}', valColor: result > 0 ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val, {Color? valColor}) {
    return Column(children: [Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.blueGrey)), Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: valColor ?? Colors.black87))]);
  }

  Widget _comparisonCard(String name, String sub, String pPerQ, String total, String exp, String result, bool isBest, String resultLabel, Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _glassDecoration().copyWith(border: isBest ? Border.all(color: AppTheme.primaryColor, width: 2) : null),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis), Text(sub, style: const TextStyle(fontSize: 8, color: Colors.grey))])),
              Text(pPerQ, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primaryColor)),
            ],
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_isSellingMode ? '${t['sale'] ?? 'Sale'}: $total' : '${t['cost'] ?? 'Cost'}: $total', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)), Text('${t['exp'] ?? 'Exp'}: $exp', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red))]),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(resultLabel, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)), Text(result, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: double.tryParse(result.replaceAll('₹', '').replaceAll(',', '')) != null && double.parse(result.replaceAll('₹', '').replaceAll(',', '')) > 0 ? Colors.green : Colors.red), overflow: TextOverflow.ellipsis)]))
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectPL(Map<String, String> t) {
    final qty = quantityInQuintals;
    final totalCost = qty * costPrice;
    final f = freight;
    final e = extraCost;
    final labor = qty * laborPerQ;
    final totalExp = totalCost + f + e + labor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Text(_isSellingMode ? (t['sell_analysis'] ?? 'SELL ANALYSIS') : (t['buy_analysis'] ?? 'BUY ANALYSIS'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          _rowInfo(_isSellingMode ? (t['total_cost'] ?? 'Total Cost') : (t['budget'] ?? 'Budget'), '₹${totalCost.toInt()}'),
          _rowInfo(t['total_expenses'] ?? 'Total Expenses', '₹${(f + e + labor).toInt()}'),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t['required_fund'] ?? 'REQUIRED FUND', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text('₹${totalExp.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.red))]),
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String val) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)), Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))]));
  }

  Widget _buildExpenseSummary(double comm, double f, double labor, double extra, Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['expense_breakdown'] ?? 'EXPENSE BREAKDOWN', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          _rowInfo(t['commission'] ?? 'Commission', '₹${comm.toInt()}'),
          _rowInfo(t['labor_loading'] ?? 'Labor (Loading)', '₹${labor.toInt()}'),
          _rowInfo(t['freight'] ?? 'Freight', '₹${f.toInt()}'),
          _rowInfo(t['extra'] ?? 'Extra', '₹${extra.toInt()}'),
          const Divider(),
          _rowInfo(t['total_expenses'] ?? 'Total Expenses', '₹${(comm + labor + f + extra).toInt()}'),
        ],
      ),
    );
  }

  BoxDecoration _glassDecoration() { return BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]); }
}

class MandiSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final MandiRepository repo;
  final double? lat;
  final double? lng;
  MandiSearchDelegate(this.repo, this.lat, this.lng);

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildList(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.fetchMandis(searchQuery: query, page: 0, userLat: lat, userLng: lng),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        return ListView.builder(itemCount: list.length, itemBuilder: (context, index) { final m = list[index]; return ListTile(title: Text(m['mandi_name'] ?? ''), subtitle: Text('${m['district']}, ${m['state']}'), trailing: Text('${(m['distance_km'] as num?)?.toStringAsFixed(1) ?? '??'} km'), onTap: () => close(context, m)); });
      },
    );
  }
}

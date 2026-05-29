import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import '../providers/khata_providers.dart';
import '../utils/khata_icons.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? transactionToEdit;
  const AddTransactionScreen({super.key, this.transactionToEdit});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  
  bool _isExpense = false; // False = Sale, True = Expense
  String _paymentMethod = 'Cash';
  int? _selectedIcon;

  final List<String> _paymentMethods = ['Cash', 'UPI', 'Bank Transfer'];

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _titleController.text = t['title'] ?? '';
      _amountController.text = (t['amount']?.toString() ?? '');
      _categoryController.text = t['category'] ?? '';
      _isExpense = t['isExpense'] ?? false;
      _paymentMethod = t['paymentMethod'] ?? 'Cash';
      _selectedIcon = t['categoryIcon'];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _saveTransaction(Map<String, String> t) {
    if (_titleController.text.trim().isEmpty || _amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['write_question_first'] ?? 'Please enter Title and Amount')),
      );
      return;
    }

    if (_categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['please_enter_category'] ?? 'Please enter or select a Category')),
      );
      return;
    }

    if (_selectedIcon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['please_select_icon'] ?? 'Please select an Icon')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['please_enter_valid_amount'] ?? 'Please enter a valid amount')),
      );
      return;
    }

    final id = widget.transactionToEdit?['id'] ?? const Uuid().v4();
    final date = widget.transactionToEdit?['date'] ?? DateTime.now().toIso8601String();

    final newTransaction = {
      'id': id,
      'title': _titleController.text.trim(),
      'amount': amount,
      'isExpense': _isExpense,
      'category': _categoryController.text.trim(),
      'categoryIcon': _selectedIcon!,
      'paymentMethod': _paymentMethod,
      'date': date,
    };

    ref.read(khataNotifierProvider.notifier).addTransaction(newTransaction);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    // Extract unique categories and filter
    final transactions = ref.watch(khataNotifierProvider).transactions;
    final Set<String> allCategoriesSet = {};
    for (var tx in transactions) {
      final cat = (tx['category'] as String?)?.trim();
      if (cat != null && cat.isNotEmpty && cat != 'General') {
        allCategoriesSet.add(cat);
      }
    }
    final query = _categoryController.text.toLowerCase();
    final filteredCategories = query.isEmpty 
      ? allCategoriesSet.take(10).toList() 
      : allCategoriesSet.where((c) => c.toLowerCase().contains(query)).take(10).toList();

    final top5 = khataColorIcons.take(4).toList();
    if (_selectedIcon != null) {
      final isTop5 = top5.any((element) => element.icon.codePoint == _selectedIcon);
      if (!isTop5) {
        final selectedKhataIcon = khataColorIcons.firstWhere(
          (element) => element.icon.codePoint == _selectedIcon, 
          orElse: () => top5.first
        );
        top5[3] = selectedKhataIcon;
      }
    }

    final screenBgColor = _isExpense ? const Color(0xFFFDE6E0) : const Color(0xFFE6F4EA);

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: screenBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.transactionToEdit != null ? (t['edit_entry'] ?? 'Edit Entry') : (t['add_entry'] ?? 'Add Entry'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: widget.transactionToEdit != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(t['delete_entry_query'] ?? 'Delete Entry?'),
                        content: Text(t['delete_entry_confirm'] ?? 'Are you sure you want to delete this transaction?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c), child: Text(t['cancel'] ?? 'Cancel')),
                          TextButton(
                            onPressed: () {
                              ref.read(khataNotifierProvider.notifier).deleteTransaction(widget.transactionToEdit!['id']);
                              Navigator.pop(c); // close dialog
                              Navigator.pop(context); // close screen
                            },
                            child: Text(t['delete'] ?? 'Delete', style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                )
              ]
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Toggle (Sale vs Expense)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTypeToggle(t['income_sale'] ?? 'Income (Sale)', false, const Color(0xFF1E8E3E)),
                    _buildTypeToggle(t['expense'] ?? 'Expense', true, const Color(0xFFD64A20)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Amount
              Text((t['amount'] ?? 'AMOUNT') + ' (₹)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F3D2F)),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.1)),
                  border: InputBorder.none,
                ),
              ),
              const Divider(),
              const SizedBox(height: 24),

              // Title
              Text(t['entry_details'] ?? 'ENTRY DETAILS', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: t['title_field_hint'] ?? 'Title (e.g., Sold Wheat, Bought Seeds)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryController,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t['category_field_hint'] ?? 'Category (Required)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (filteredCategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(t['suggestions_caps'] ?? 'SUGGESTIONS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filteredCategories.map((cat) => GestureDetector(
                    onTap: () {
                      _categoryController.text = cat;
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withOpacity(0.1)),
                      ),
                      child: Text(cat, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    ),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 24),

              // Icons Picker
              Text(t['select_icon_caps'] ?? 'SELECT ICON', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...top5.map((khataIcon) {
                    final isSelected = _selectedIcon == khataIcon.icon.codePoint;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = khataIcon.icon.codePoint),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? khataIcon.color : khataIcon.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected ? Border.all(color: Colors.black12, width: 2) : null,
                          boxShadow: isSelected
                              ? [BoxShadow(color: khataIcon.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                              : [],
                        ),
                        child: Icon(
                          khataIcon.icon,
                          color: isSelected ? Colors.white : khataIcon.color,
                          size: 26,
                        ),
                      ),
                    );
                  }).toList(),
                  // More Button
                  GestureDetector(
                    onTap: () => _showAllIconsBottomSheet(context, t),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.more_horiz_rounded, color: Colors.black54, size: 28),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Payment Method
              Text(t['payment_method_caps'] ?? 'PAYMENT METHOD', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                children: _paymentMethods.map((method) {
                  final isSelected = _paymentMethod == method;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentMethod = method),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F3D2F) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          t[method.toLowerCase()] ?? method,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 48),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3D2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _saveTransaction(t),
                  child: Text(t['save_entry'] ?? 'Save Entry', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeToggle(String label, bool isExp, Color color) {
    final isSelected = _isExpense == isExp;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isExpense = isExp),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? null : Border.all(color: color.withOpacity(0.3), width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  void _showAllIconsBottomSheet(BuildContext context, Map<String, String> t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(t['all_icons'] ?? 'All Icons', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: khataColorIcons.length,
                    itemBuilder: (context, index) {
                      final khataIcon = khataColorIcons[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedIcon = khataIcon.icon.codePoint);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: khataIcon.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(khataIcon.icon, color: khataIcon.color, size: 28),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

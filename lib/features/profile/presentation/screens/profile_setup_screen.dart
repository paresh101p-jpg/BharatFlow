import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:bharat_flow/core/constants/api_keys.dart';
import 'package:bharat_flow/features/profile/data/repositories/profile_repository.dart';
import 'package:bharat_flow/core/theme/app_theme.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  String? _userType;
  final _birthdayController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  List<String> _citySuggestions = [];

  @override
  void initState() {
    super.initState();
    _loadCitySuggestions();
  }

  Future<void> _loadCitySuggestions() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('medical_stores').select('city').limit(100);
      final cities = (data as List).map((e) => e['city'] as String).toSet().toList();
      cities.sort();
      if (mounted) setState(() => _citySuggestions = cities);
    } catch (_) {}
  }

  Future<Iterable<String>> _getCitySuggestions(String query) async {
    if (query.length < 2) {
      return _citySuggestions.where((c) => c.toLowerCase().contains(query.toLowerCase()));
    }
    
    try {
      final apiKey = ApiKeys.googlePlacesKey;
      final url = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&types=(cities)&components=country:in&key=$apiKey";
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List predictions = data['predictions'] ?? [];
        final googleCities = predictions.map((p) => p['structured_formatting']['main_text'] as String).toList();
        
        return {..._citySuggestions.where((c) => c.toLowerCase().contains(query.toLowerCase())), ...googleCities};
      }
    } catch (e) {
      debugPrint("Autocomplete Error: $e");
    }
    return _citySuggestions.where((c) => c.toLowerCase().contains(query.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(t['welcome_title'] ?? 'Welcome to BharatFlow!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  const SizedBox(height: 8),
                  Text(t['setup_desc'] ?? 'Let\'s set up your profile for a personalized experience.', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 32),

                  // Details Form
                  _buildField(t['birthday_label'] ?? 'Birthday (Limited Edits)', _birthdayController, Icons.cake, onTap: _selectDate),
                  
                  // City Field with Autocomplete
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _cityController.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        return _getCitySuggestions(textEditingValue.text);
                      },
                      onSelected: (String selection) {
                        _cityController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        if (controller.text.isEmpty && _cityController.text.isNotEmpty) {
                          controller.text = _cityController.text;
                        }
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onSubmitted: (val) {
                            _cityController.text = val;
                            onFieldSubmitted();
                          },
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            labelText: t['city'] ?? 'City',
                            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            prefixIcon: const Icon(Icons.location_city, color: AppTheme.primaryColor, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              width: MediaQuery.of(context).size.width - 48,
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.location_city, size: 18, color: Colors.grey),
                                    title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildField(
                    t['mobile_number'] ?? 'Mobile Number',
                    _mobileController,
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  _buildField(t['full_address'] ?? 'Full Address', _addressController, Icons.home, maxLines: 2),

                  const SizedBox(height: 12),
                  Text(
                    t['birthday_limit_note'] ?? 'Note: Birthday can only be edited 3 times in the future.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 40),
                  
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    child: Text(t['complete_setup'] ?? 'COMPLETE SETUP', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      ),
    );
  }


  Widget _buildField(String label, TextEditingController controller, IconData icon, {VoidCallback? onTap, TextInputType? keyboardType, int maxLines = 1, List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        readOnly: onTap != null,
        onTap: onTap,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _submit() async {

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await ref.read(profileRepositoryProvider).completeSetup(
          userId: user.id, 
          type: 'User',
          birthday: _selectedDate,
          city: _cityController.text,
          mobileNo: _mobileController.text,
          fullAddress: _addressController.text,
          email: user.email,
        );
        
        ref.invalidate(profileProvider);
        if (mounted) {
          Navigator.of(context).pop(); 
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

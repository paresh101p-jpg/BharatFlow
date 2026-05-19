import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  void _savePin() {
    if (_pinController.text == _confirmController.text && _pinController.text.length == 4) {
      ref.read(settingsProvider.notifier).setPinCode(_pinController.text);
      ref.read(settingsProvider.notifier).togglePinSecurity(true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN successfully updated and enabled!'), backgroundColor: Colors.teal),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match or must be 4 digits.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Security PIN'), foregroundColor: AppTheme.primaryColor),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set a new 4-digit PIN for secure transactions.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            _buildPinField('Enter New PIN', _pinController),
            const SizedBox(height: 16),
            _buildPinField('Confirm New PIN', _confirmController),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('SAVE PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        counterText: '',
      ),
    );
  }
}

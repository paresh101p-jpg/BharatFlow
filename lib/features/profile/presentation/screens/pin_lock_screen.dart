import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  final List<String> _input = [];

  void _onKeyTap(String key) {
    if (_input.length < 4) {
      setState(() => _input.add(key));
    }
    if (_input.length == 4) {
      final settings = ref.read(settingsProvider);
      if (_input.join() == settings.pinCode) {
        widget.onUnlocked();
      } else {
        setState(() => _input.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Logo and Name
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Image.asset('assets/images/logo.png', height: 60),
            ),
            const SizedBox(height: 16),
            const Text(
              'BharatFlow',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 40),
            const Icon(Icons.lock_outline, color: Colors.white70, size: 32),
            const SizedBox(height: 12),
            const Text('Enter App PIN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: index < _input.length ? Colors.white : Colors.white24,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              )),
            ),
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      children: [
        ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((k) => _key(k)),
        const SizedBox.shrink(),
        _key('0'),
        IconButton(
          onPressed: () => setState(() { if (_input.isNotEmpty) _input.removeLast(); }), 
          icon: const Icon(Icons.backspace_outlined, color: Colors.white, size: 28)
        ),
      ],
    );
  }

  Widget _key(String val) {
    return InkWell(
      onTap: () => _onKeyTap(val),
      borderRadius: BorderRadius.circular(50),
      child: Center(child: Text(val, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BharatFlow Privacy Policy & Terms',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            _buildSection('1. Data Privacy', 
              'We collect your basic profile information via Google Sign-in to personalize your experience. Your location data is used only to provide local market prices and weather updates.'),
            _buildSection('2. Usage Policy', 
              'BharatFlow is intended for farmers, traders, and citizens to access agricultural and market intelligence. Misuse of data or automated scraping is prohibited.'),
            _buildSection('3. Market Data', 
              'While we strive for accuracy, Mandi prices and AI predictions are for guidance only. Market conditions can change rapidly.'),
            _buildSection('4. Permissions', 
              'By using this app, you grant permission to access your Location for local data and Notifications for critical price alerts.'),
            const SizedBox(height: 30),
            const Center(
              child: Text('Last Updated: May 2026', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(color: Colors.grey[700], height: 1.5)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Privacy Policy for BharatFlow', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
            const SizedBox(height: 8),
            Text('Last Updated: May 2026', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            const Text(
              'At BharatFlow, we value your trust and are committed to protecting your privacy. This policy explains what information we collect, how it is used, and the third-party services we rely on. We believe in complete transparency.',
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 32),
            
            _buildSection(
              title: '1. What Data Do We Collect?',
              icon: Icons.data_usage_rounded,
              content: '• Personal Information: When you sign in with Google, we securely receive your basic profile details (Name, Email Address, and Profile Picture).\n\n'
                       '• Profile Details: Information you voluntarily provide, such as Mobile Number, Birthdate, City, and Full Address, is securely saved to enhance your experience.\n\n'
                       '• Location Data: We request background and foreground GPS location access to fetch the most accurate nearby Mandi (Market) prices, Government fertilizer shops, and hyper-local weather alerts. Location data is NOT tracked unnecessarily.\n\n'
                       '• App Preferences: Your favorite commodities, saved alerts, and app settings are stored locally on your device for fast offline access.',
            ),
            
            _buildSection(
              title: '2. Where Does Our Data Come From?',
              icon: Icons.source_rounded,
              content: 'BharatFlow acts as a smart aggregator. We DO NOT generate market prices. Our data is sourced from:\n\n'
                       '• DATA.GOV.IN: Official Government of India portals for authentic Mandi prices and Sarkari Shop details.\n\n'
                       '• OpenWeatherMap & Weather APIs: For real-time climate telemetry, 7-day forecasts, and agricultural risk analysis.\n\n'
                       '• Google APIs (Places & Maps): To calculate road-based logistics distances and verify APMC Market operational timings.',
            ),
            
            _buildSection(
              title: '3. How We Use Your Data',
              icon: Icons.analytics_rounded,
              content: 'Your data is strictly used to provide the app\'s core services:\n\n'
                       '• To deliver personalized crop vulnerability analysis based on your favorite commodities and local weather.\n\n'
                       '• To calculate accurate logistics costs and distances from your location to the nearest Mandis.\n\n'
                       '• Your "Digital Khata" (ledger) transactions are entirely private, encrypted, and synced only with your authenticated account.',
            ),

            _buildSection(
              title: '4. What We Do NOT Do',
              icon: Icons.security_rounded,
              content: '• We DO NOT sell, rent, or trade your personal data to any third-party marketing agencies.\n\n'
                       '• We DO NOT access your personal contacts, photos, or files (other than app-specific cache).\n\n'
                       '• We DO NOT store unnecessary data. If you log out or delete the app, your local session is instantly cleared.',
            ),

            _buildSection(
              title: '5. Data Storage & Security',
              icon: Icons.cloud_done_rounded,
              content: 'We use Supabase (an enterprise-grade backend service) to securely store your profile and authentication state. Communication between the app and servers is fully encrypted via HTTPS/SSL. Local preferences are stored safely on your device using Hive database.',
            ),

            _buildSection(
              title: '6. Your Rights & Contact Information',
              icon: Icons.contact_support_rounded,
              content: 'You have full control over your data. You can update your profile anytime or log out to clear local data. If you have any questions, concerns, or wish to request data deletion, please contact us directly at:\n\n'
                       'Email: paresh101p@gmail.com',
            ),
            
            const SizedBox(height: 40),
            Center(
              child: Text('Made with ❤️ in India for Farmers & Traders', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A237E)))),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87)),
        ],
      ),
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help Center'), foregroundColor: AppTheme.primaryColor),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.support_agent, size: 80, color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            const Text('How can we help you?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Our team is available 24/7 for farmers and traders.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            _supportCard(Icons.phone, 'Call Us', 'Coming Soon', onTap: null),
            const SizedBox(height: 16),
            _supportCard(Icons.email, 'Email Us', 'paresh101p@gmail.com', onTap: () async {
              final Uri emailLaunchUri = Uri.parse('mailto:paresh101p@gmail.com?subject=BharatFlow%20Support&body=Hi%20BharatFlow%20Team,%0A%0A');
              try {
                await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint('Could not launch email app: $e');
              }
            }),
            const Spacer(),
            const Text('BharatFlow v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _supportCard(IconData icon, String title, String sub, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: glassDecoration(),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

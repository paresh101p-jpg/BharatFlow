import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/panchang_utils.dart';

class FestivalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> festival;
  const FestivalDetailScreen({super.key, required this.festival});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(festival['date']);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: PanchangUtils.getPanchangForDate(date),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          
          final panchang = snapshot.data ?? {};
          
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, festival['name']),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMainHeader(context, festival['name'], date, panchang),
                    const SizedBox(height: 24),
                    _buildSunMoonSection(panchang),
                    const SizedBox(height: 24),
                    _buildTithiSection(panchang),
                    const SizedBox(height: 24),
                    _buildKrishiMuhuratSection(panchang),
                    const SizedBox(height: 24),
                    _buildChoghadiyaSection(panchang),
                    const SizedBox(height: 24),
                    _buildMuhuratSection(panchang),
                    const SizedBox(height: 16),
                    const DynamicAdmobCardWidget(),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKrishiMuhuratSection(Map<String, dynamic> panchang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KRISHI MUHURAT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.green.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _muhuratRow('Sowing (Beej Bone)', panchang['sowing_muhurat']?.toString() ?? 'N/A', Icons.grass, Colors.green),
              const Divider(),
              _muhuratRow('Harvesting (Katai)', panchang['harvesting_muhurat']?.toString() ?? 'N/A', Icons.agriculture, Colors.orange),
              const Divider(),
              _muhuratRow('Tractor Purchase', panchang['tractor_muhurat']?.toString() ?? 'N/A', Icons.local_shipping, Colors.blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _muhuratRow(String label, String value, IconData icon, Color color) {
    final isNotRec = value == "Not Recommended";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isNotRec ? Colors.red.shade400 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String title) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Text(title, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
      iconTheme: const IconThemeData(color: AppTheme.primaryColor),
    );
  }

  void _shareFestivalDetails(String name, DateTime date, Map<String, dynamic> panchang) async {
    try {
      final tithi = panchang['tithi']?.toString() ?? 'N/A';
      final nakshatra = panchang['nakshatra']?.toString() ?? 'N/A';
      final yoga = panchang['yoga']?.toString() ?? 'N/A';
      final karan = panchang['karan']?.toString() ?? 'N/A';
      
      final sunrise = panchang['sunrise']?.toString() ?? 'N/A';
      final sunset = panchang['sunset']?.toString() ?? 'N/A';
      
      final sowing = panchang['sowing_muhurat']?.toString() ?? 'N/A';
      final harvesting = panchang['harvesting_muhurat']?.toString() ?? 'N/A';
      final tractor = panchang['tractor_muhurat']?.toString() ?? 'N/A';
      
      final abhijit = panchang['abhijit']?.toString() ?? 'N/A';

      final buffer = StringBuffer();
      buffer.writeln('🌾 *BharatFlow Panchang & Krishi Samachar* 🌾');
      buffer.writeln('🎉 *Festival:* $name');
      buffer.writeln('📅 *Date:* ${date.day}/${date.month}/${date.year}');
      buffer.writeln();
      buffer.writeln('🌅 *Sunrise:* $sunrise | 🌇 *Sunset:* $sunset');
      buffer.writeln();
      buffer.writeln('📜 *Panchang Details:*');
      buffer.writeln('• *Tithi:* $tithi');
      buffer.writeln('• *Nakshatra:* $nakshatra');
      buffer.writeln('• *Yoga:* $yoga');
      buffer.writeln('• *Karan:* $karan');
      buffer.writeln();
      buffer.writeln('🚜 *Krishi Muhurat:*');
      buffer.writeln('• *Sowing:* $sowing');
      buffer.writeln('• *Harvesting:* $harvesting');
      buffer.writeln('• *Tractor Purchase:* $tractor');
      buffer.writeln();
      buffer.writeln('✨ *Abhijit Muhurat:* $abhijit');
      buffer.writeln();
      buffer.writeln('📲 Stay connected with direct local Krishi Panchang alerts on *BharatFlow app*!');
      buffer.writeln('Download App Now:\nhttps://play.google.com/store/apps/details?id=com.BharatFlow');

      await Share.share(
        buffer.toString(),
        subject: 'Festival Panchang Details: $name',
      );
    } catch (e) {
      debugPrint('Error sharing festival details: $e');
    }
  }

  Widget _buildMainHeader(BuildContext context, String name, DateTime date, Map<String, dynamic> panchang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UPCOMING FESTIVAL', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _shareFestivalDetails(name, date, panchang),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunMoonSection(Map<String, dynamic> panchang) {
    return Row(
      children: [
        Expanded(child: _infoCard('Sunrise', panchang['sunrise']?.toString() ?? 'N/A', Icons.wb_sunny_outlined, Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _infoCard('Sunset', panchang['sunset']?.toString() ?? 'N/A', Icons.nights_stay_outlined, Colors.deepPurple)),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTithiSection(Map<String, dynamic> panchang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PANCHANG DETAILS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              _panchangRow('Tithi', panchang['tithi']?.toString() ?? 'N/A'),
              const Divider(),
              _panchangRow('Nakshatra', panchang['nakshatra']?.toString() ?? 'N/A'),
              const Divider(),
              _panchangRow('Yoga', panchang['yoga']?.toString() ?? 'N/A'),
              const Divider(),
              _panchangRow('Karan', panchang['karan']?.toString() ?? 'N/A'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panchangRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildChoghadiyaSection(Map<String, dynamic> panchang) {
    final list = (panchang['choghadiya'] as List?)?.map((e) => Map<String, String>.from(e)).toList() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DAY CHOGHADIYA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: list.map((c) => _choghadiyaCard(
              c['name'] ?? 'Unknown', 
              c['time'] ?? 'N/A', 
              Color(int.parse(c['color'] ?? '0xFF9E9E9E'))
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _choghadiyaCard(String name, String time, Color color) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMuhuratSection(Map<String, dynamic> panchang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.shade700, Colors.teal]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ABHIJIT MUHURAT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(panchang['abhijit']?.toString() ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

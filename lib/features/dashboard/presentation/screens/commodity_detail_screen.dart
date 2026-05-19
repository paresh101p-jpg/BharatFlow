import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/date_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/settings_provider.dart';

class CommodityDetailScreen extends ConsumerWidget {
  final String name;
  final String gujName;
  final String currentPrice;
  final String change;
  final bool isUp;
  final String image;

  const CommodityDetailScreen({
    super.key,
    required this.name,
    required this.gujName,
    required this.currentPrice,
    required this.change,
    required this.isUp,
    required this.image,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isGujarati = settings.language == 'Gujarati';
    final location = ref.watch(locationProvider);
    final lastUpdated = AppDateFormatter.formatDateTime(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeaderInfo(isGujarati, lastUpdated),
                  const SizedBox(height: 24),
                  _buildPriceGraph(isGujarati),
                  const SizedBox(height: 24),
                  _buildNearbyMandisList(isGujarati, location.address),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              image, 
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.agriculture, size: 64, color: AppTheme.primaryColor),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent], 
                  begin: Alignment.bottomCenter, 
                  end: Alignment.topCenter
                )
              )
            ),
          ],
        ),
      ),
      leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
    );
  }

  Widget _buildHeaderInfo(bool isGujarati, String time) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isGujarati ? gujName : name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  Text(isGujarati ? 'આજના સરેરાશ ભાવ' : "Today's Avg Price", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(currentPrice, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87)),
                  Text(change, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isUp ? Colors.green : Colors.red)),
                ],
              ),
            ],
          ),
          const Divider(height: 32, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoTile(isGujarati ? 'છેલ્લું અપડેટ' : 'Last Update', time, Icons.access_time),
              _infoTile(isGujarati ? 'મુખ્ય મંડી' : 'Main Mandi', 'Bardoli', Icons.location_on),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String val, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(val, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceGraph(bool isGujarati) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isGujarati ? '૩૦ દિવસના ભાવનો ટ્રેન્ડ' : '30-Day Price Trend', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: glassDecoration(),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(15, (index) => Flexible(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 30 + (index * 4.0) + (index % 3 == 0 ? 25 : 0),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.3 + (index * 0.04)), 
                        borderRadius: BorderRadius.circular(3)
                      ),
                    ),
                  )),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('01 May', style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text('15 May', style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text('30 May', style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyMandisList(bool isGujarati, String userLoc) {
    final mandis = [
      {'name': 'Bardoli', 'guj': 'બારડોલી', 'price': '₹1,450', 'dist': '34 KM', 'time': '10:30 AM', 'change': '+2.5%', 'isUp': true},
      {'name': 'Vyara', 'guj': 'વ્યારા', 'price': '₹1,420', 'dist': '62 KM', 'time': '11:15 AM', 'change': '-1.2%', 'isUp': false},
      {'name': 'Navsari', 'guj': 'નવસારી', 'price': '₹1,440', 'dist': '45 KM', 'time': '09:45 AM', 'change': '+1.8%', 'isUp': true},
      {'name': 'Surat', 'guj': 'સુરત', 'price': '₹1,460', 'dist': '12 KM', 'time': '10:00 AM', 'change': '+3.1%', 'isUp': true},
      {'name': 'Anand', 'guj': 'આણંદ', 'price': '₹1,380', 'dist': '145 KM', 'time': '08:30 AM', 'change': '-0.5%', 'isUp': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isGujarati ? 'નજીકની મંડીઓ' : 'Nearby Mandis', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            TextButton(onPressed: () {}, child: Text(isGujarati ? 'વધારે જુઓ' : 'View More', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 4),
        ...mandis.map((m) => InkWell(
          onTap: () => _openMap(m['name'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isGujarati ? m['guj']! as String : m['name']! as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    Row(
                      children: [
                        Text('${m['dist']} ${isGujarati ? "દૂર" : "away"}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(width: 8),
                        const Icon(Icons.directions, size: 10, color: Colors.blue),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(m['price']! as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87)),
                    Row(
                      children: [
                        Text(m['change']! as String, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: (m['isUp'] as bool) ? Colors.green : Colors.red)),
                        const SizedBox(width: 4),
                        Text(m['time']! as String, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Icon(Icons.map_outlined, size: 20, color: Colors.blueAccent),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Future<void> _openMap(String mandiName) async {
    final query = Uri.encodeComponent('$mandiName Mandi Gujarat');
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

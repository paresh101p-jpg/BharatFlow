import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SharePriceCardScreen extends StatelessWidget {
  const SharePriceCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildTopAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _buildShareableCard(),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Shared prices are indicative and subject to quality variations and transportation costs at the Mandi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.4),
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.white.withOpacity(0.7),
      elevation: 0,
      centerTitle: false,
      title: const Text('Share Price Card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close, color: AppTheme.primaryColor),
      ),
      actions: [
        const CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuDZz37dAyU9d1tJGtsg3zdyUTXa9A4qXX4S9a6SYh2XqAKNpRBej3r3Ynuddl6mvaceSLtDkYXnaZNUxDZgYQ5A5I65-YUkui1_O7kbDYYPSiwjEw-Cyx1LftDhpL_mMsVInLfUedvPCnsxkoaQrTM4On71mCRNtGQ_p9R3RIUXaXAy5SEkU8Lnmg-Qmi6wK-KxiLPKX1InTT_OJO8pJEkJ1eCqlBzCjnma8rmd4eQRI6XfBGGxXiMSfnkLNKooaNwjUmXj08OjRJE'),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildShareableCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryColor.withOpacity(0.12), blurRadius: 64, offset: const Offset(0, 32)),
        ],
        border: Border.all(color: Colors.teal.shade50),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wheat - Sharbati', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text('Azaadpur Mandi, Delhi', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 10)]),
                child: const Text('Premium Grade A', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('TODAY\'S MARKET RATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('₹2,450', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
              const SizedBox(width: 8),
              const Text('/qtl', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.withOpacity(0.2))),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up, size: 18, color: Colors.teal),
                SizedBox(width: 8),
                Text('Above MSP by 12%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('7-DAY TREND', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final heights = [0.3, 0.55, 0.45, 0.75, 0.65, 0.85, 1.0];
                        return Container(
                          width: 8,
                          height: 30 * heights[index],
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(color: index == 6 ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.1 + (index * 0.1)), borderRadius: BorderRadius.circular(4)),
                        );
                      }),
                    ),
                  ],
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified, size: 14, color: Colors.teal),
                        SizedBox(width: 4),
                        Text('Verified Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                    Text('Updated: 10:45 AM', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.agriculture, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text('Smart Mandi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryColor, letterSpacing: -0.5)),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Image.network('https://lh3.googleusercontent.com/aida-public/AB6AXuBQtOvQox3IxtxvhZg4KYxK7i6kVUN0vj-95Os8zlsi1HOh4pJ96WRBlTFucyuRVpEh7Vsz2YN00-_roQwF_W7fCT6Ig5J96yxYMigNPPEz4A3XWcoiWsR5Lsgk-Gn4dwrkFkocKrvFehLFoc7rwzg0xLrRsxHX22hFgwXnpybuZScCZKvf2x9XmKdQqcfTsU2M9127_hz6MBexDYxrjswLNgfw8hGTHXIa0X6-knSjC7K8t3KXV4g_sKZEOiXbD7E_xjwIAYMvjDk'),
                  ),
                  const Text('DOWNLOAD APP', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.share, color: Colors.white, size: 18),
          label: const Text('SHARE ON WHATSAPP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: const Color(0xFF25D366).withOpacity(0.4)),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download, color: AppTheme.primaryColor, size: 18),
          label: const Text('DOWNLOAD IMAGE', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.1))),
        ),
      ],
    );
  }
}

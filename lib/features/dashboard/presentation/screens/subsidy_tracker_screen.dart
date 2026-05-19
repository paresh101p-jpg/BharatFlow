import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SubsidyTrackerScreen extends StatelessWidget {
  const SubsidyTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildTopAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _buildGovernmentNotice(),
                const SizedBox(height: 24),
                _buildActiveBenefits(),
                const SizedBox(height: 24),
                _buildApplicationTracking(),
                const SizedBox(height: 24),
                _buildPayoutHistory(),
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
      title: const Text('Subsidy & Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.menu, color: AppTheme.primaryColor),
      ),
      actions: [
        const CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBuH6gA3jUib4xCSrZN95cikLVieSOKyBeeclJvXVA3A_9DviZwWEDRow99l4xWRr0d29Sb-ByVCK8Rlbt7v7KmcxSr-WydjpNsPidBe1f2nLTJ2C7rFPTf4rkS0NekJt5QDC3FbmZWHaRvuaVh5bqy6Xmkop6NwYzYtjRC8-YV9jnWz4tGxsu8JCFu32nyq-GEKsF4jcyPF2YYglK3AXNWOLpPwDh0zHBez78blEsVm8SS3GS8Xq4HXaeri6GjC9I2zUFLyeO_VDA'),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildGovernmentNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withOpacity(0.2))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.campaign, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Government Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                Text('New subsidy for Drip Irrigation systems is now open. Apply before 30th Oct.', style: TextStyle(fontSize: 11, color: Colors.black87)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.orange),
        ],
      ),
    );
  }

  Widget _buildActiveBenefits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Active Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            Text('VIEW ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _benefitCard('FERTILIZER', 'NPK Subsidy Scheme', '₹12,400', '12 Nov 2023', AppTheme.primaryColor, Icons.eco)),
            const SizedBox(width: 16),
            Expanded(child: _benefitCard('ENERGY', 'Solar Pump Scheme', '₹45,000', 'Verified', Colors.blue, Icons.wb_sunny)),
          ],
        ),
      ],
    );
  }

  Widget _benefitCard(String category, String title, String amount, String nextPayout, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration().copyWith(
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          const Text('AMOUNT DISBURSED', style: TextStyle(fontSize: 8, color: Colors.grey)),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryColor)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text('NEXT PAYOUT', style: TextStyle(fontSize: 8, color: Colors.grey)),
          Text(nextPayout, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildApplicationTracking() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Application Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
          const SizedBox(height: 24),
          _timelineItem('Application Submitted', 'PM-Kisan Samman Nidhi (Batch 15)', '12 OCT', isCompleted: true),
          _timelineItem('Verification in Progress', 'State Revenue Department is reviewing documents.', 'ACTIVE', isPending: true),
          _timelineItem('Disbursement', 'Estimated date: Nov 20 - Nov 25', 'FUTURE', isFuture: true),
        ],
      ),
    );
  }

  Widget _timelineItem(String title, String subtitle, String date, {bool isCompleted = false, bool isPending = false, bool isFuture = false}) {
    final color = isCompleted ? AppTheme.primaryColor : (isPending ? Colors.orange : Colors.grey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4)]),
                  child: Icon(isCompleted ? Icons.check : (isPending ? Icons.pending : Icons.hourglass_empty), size: 12, color: Colors.white),
                ),
                if (!isFuture)
                  Expanded(
                    child: Container(width: 2, color: color.withOpacity(0.2)),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isFuture ? Colors.grey : AppTheme.primaryColor)),
                      Text(date, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  if (isPending)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.1))),
                      child: const Row(
                        children: [
                          Icon(Icons.description, size: 14, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Aadhaar verified successfully', style: TextStyle(fontSize: 10, color: Colors.orange)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Payout History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            Icon(Icons.search, size: 18, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 16),
        _payoutItem('PM-Kisan Installment', 'ID: #9902341 • 15 SEP 2023', '₹2,000', Icons.account_balance_wallet),
        const SizedBox(height: 12),
        _payoutItem('Micro Irrigation Rebate', 'ID: #8812390 • 02 AUG 2023', '₹8,500', Icons.water_drop),
        const SizedBox(height: 12),
        _payoutItem('Seed Subsidy Claim', 'ID: #7721098 • 20 JUN 2023', '₹1,250', Icons.inventory_2),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryFixed.withOpacity(0.3), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
          child: const Text('Download Statement', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _payoutItem(String title, String details, String amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primaryFixed.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(details, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                child: const Text('SUCCESS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

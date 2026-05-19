import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class MandiClosureDetailsScreen extends StatelessWidget {
  const MandiClosureDetailsScreen({super.key});

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
                _buildStatusVisual(),
                const SizedBox(height: 24),
                _buildReasonCard(),
                const SizedBox(height: 16),
                _buildImpactAnalysis(),
                const SizedBox(height: 24),
                _buildAlternativesSection(),
                const SizedBox(height: 32),
                _buildPrimaryAction(),
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
      title: const Text('Mandi Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline, color: AppTheme.primaryColor)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatusVisual() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: glassDecoration(),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), shape: BoxShape.circle),
              ),
              Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuDuTWGlh5srfJlWbpQkeN3ZiYVMavXPbtfizutRMVEbXjd-c_Hy_9dr9MHToODuluAPxJXqDUfbIvpUHGSuISk5_-V41r8dlMJzrlOCLSBVs1i0bCmHZAkeLnWGV4qiQ0epaaVQN6756Tm0-xAWJW57305Zg5w1SQFbpg2xVgIRF8mCOlOBPd_SYlUSQmwvQMO7fYKwP0dtKSvfX0wTaTuyfD5yu9ecFq7DDnxrdh2vrYwYJ2SyyyCJKGyrhNaGQeTlDDGnsA3qf5Y',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Transform.rotate(
            angle: -0.04,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 12)]),
              child: const Text('CLOSED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2.0)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Azadpur Mandi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('North Delhi District, Delhi', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryFixed, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.cleaning_services, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CURRENT REASON', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
                    Text('Weekly Maintenance & Deep Cleaning', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REOPENING', style: TextStyle(fontSize: 8, color: Colors.grey)),
                    Text('Monday, Oct 13', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TIME', style: TextStyle(fontSize: 8, color: Colors.grey)),
                    const Text('04:00 AM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withOpacity(0.2))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.trending_up, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Price Impact Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                    children: [
                      TextSpan(text: 'Potential '),
                      TextSpan(text: '+2% surge ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: 'in vegetable prices due to low supply today.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Suggested Alternative Mandis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            Text('2 FOUND', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _alternativeCard('Karnal Grain Market', '12km away', 'https://lh3.googleusercontent.com/aida-public/AB6AXuA-yRTmNg9kaEFjt5z1C7Q7rpFw10K3VKcRsIqiHl75lySyDfiRM8mhB7ckEaT-fEh8_7VhZBXW-r8OmygSKT34FbnH8ElZdh8LHe8fYeLLly6s6wURvHt59Zc6U__Fi336Y2r5DgbNUagM4gzK-W1pIp9BexBISiDd3NSjI_Lbci6wBP6YYKDNPQdgM28f9K1TLuptBpZBXGyqXIMhdsLsY2f3UpKutro-9b9LlS_qvoOOF_zjzsIwQl3RUZGatzm3LD88TfbbyCc')),
            const SizedBox(width: 12),
            Expanded(child: _alternativeCard('Ghazipur Mandi', '15km away', 'https://lh3.googleusercontent.com/aida-public/AB6AXuB1G5pWtV5ImbhKE2EAD9pgUtyyVyXL9-u01H_hbHkgfi7mH_RpZ5Oy3JJe2EqXuYw8WQG7bWlX7XJUmvbHtKxAzPdHut4y4-sb3YmyUd6NzzopK97ILji63lAY2nUO3LP-rBHa1YP9jaL8FCL9OlgpAEVIZyROoAicVPg19TvXP_NKfQJzaeE_llYCiBm2LwWLfi68AqOduWYCC3OR__T1XRhhrEEsRlwjFmFXTWpyMThXRu6l-5DwKAPqEH0kf1pBERYqQPxETg0')),
          ],
        ),
      ],
    );
  }

  Widget _alternativeCard(String name, String distance, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(imageUrl, height: 80, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(
            children: [
              const Icon(Icons.near_me, size: 10, color: AppTheme.primaryColor),
              const SizedBox(width: 4),
              Text(distance, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
                child: const Text('OPEN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction() {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.explore, color: Colors.white),
      label: const Text('FIND NEAREST OPEN MANDI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 10, shadowColor: AppTheme.primaryColor.withOpacity(0.5)),
    );
  }
}

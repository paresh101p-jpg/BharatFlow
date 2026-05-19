import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class RouteOptimizerScreen extends StatelessWidget {
  const RouteOptimizerScreen({super.key});

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
                _buildInteractiveMap(),
                const SizedBox(height: 24),
                _buildPathComparison(),
                const SizedBox(height: 32),
                _buildStartNavigationButton(),
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
      centerTitle: true,
      title: const Text('Route Optimizer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildInteractiveMap() {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        image: const DecorationImage(
          image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuDmdbmZF2U6J9SpoAVviYNYIK-tbB43hVlqD1Al2Aoo2JnONaHS0UBysEPTkwKJNzCn6_BODlqXlV8LSki76LB8uj7tZw7W9GcaWJhMJ2yOFgl-x-f8fR1eYY49FcqeO6M2aAhxaQNvuaO6wshHg1zHv9twXylzofElyG09rLz5RSCfJl4337rmysUTrZYdjGg_7LPK60ZZfCWjVOUGtx5Y8ua_o3ayqU7JBpWehBLn0F4inV0z2HQHdOEIPYRXdbyPzTb51urhrhc'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // Origin Marker
          Positioned(
            top: 40,
            left: 40,
            child: _mapMarker('Farm Origin', Colors.teal),
          ),
          // Dest Marker
          Positioned(
            bottom: 80,
            right: 40,
            child: _mapMarker('Azadpur Mandi', AppTheme.primaryColor, icon: Icons.storefront),
          ),
          // Price Info Overlay
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.withOpacity(0.2))),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, size: 14, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Panipat: +₹2/kg', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
          ),
          // Bottom Summary
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: glassDecoration(),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESTIMATED NET GAIN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
                      Text('₹4,200', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                    ],
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('FREIGHT', style: TextStyle(fontSize: 8, color: Colors.grey)),
                          Text('₹1,500', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('PROFIT', style: TextStyle(fontSize: 8, color: Colors.grey)),
                          Text('+12%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapMarker(String label, Color color, {IconData icon = Icons.location_on}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)]),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 10),
              const SizedBox(width: 4),
              Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Container(width: 2, height: 10, color: color),
      ],
    );
  }

  Widget _buildPathComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Path Comparison', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text('2 ROUTES FOUND', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _routeCard('Route A: Cheapest', 'Via NH-44 • 142 km • 3h 15m', '₹8,450 Profit', '₹1,200 fuel', isRecommended: true),
        const SizedBox(height: 12),
        _routeCard('Route B: Shortest', 'Via SH-12 • 128 km • 2h 45m', '₹7,100 Profit', '₹1,850 fuel'),
      ],
    );
  }

  Widget _routeCard(String name, String details, String profit, String cost, {bool isRecommended = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration().copyWith(
        border: isRecommended ? Border.all(color: Colors.teal.withOpacity(0.5), width: 1.5) : null,
      ),
      child: Stack(
        children: [
          if (isRecommended)
            Positioned(
              top: -16,
              right: -16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: const BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12))),
                child: const Text('RECOMMENDED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isRecommended ? Colors.teal.withOpacity(0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Icon(isRecommended ? Icons.auto_awesome : Icons.speed, color: isRecommended ? Colors.teal : Colors.grey, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(details, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(profit, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isRecommended ? Colors.teal : Colors.grey.shade700)),
                  Text(cost, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartNavigationButton() {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.navigation, color: Colors.white),
      label: const Text('Start Navigation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: AppTheme.primaryColor.withOpacity(0.5),
      ),
    );
  }
}

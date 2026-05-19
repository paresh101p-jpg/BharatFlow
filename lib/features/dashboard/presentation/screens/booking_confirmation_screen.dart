import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

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
                _buildSuccessHeader(),
                const SizedBox(height: 24),
                _buildBookingDetailsCard(),
                const SizedBox(height: 24),
                _buildPaymentSummary(),
                const SizedBox(height: 24),
                _buildActionButtons(),
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
      title: const Text('Booking Confirmed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 100, height: 100, decoration: BoxDecoration(color: AppTheme.secondaryContainer.withOpacity(0.2), shape: BoxShape.circle)),
            Container(
              width: 80,
              height: 80,
              decoration: glassDecoration().copyWith(shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 48),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Booking Confirmed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
        const Text('Your transporter is on the way', style: TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBookingDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BOOKING ID', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text('#SM-99281', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                child: const Text('ACTIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBAbyjEUKUMDm07nEUUO0m2PfMFCXVvWiQ13p_PjqK79C-mZNWFylduqEOzAEUPJpmOTTaNrANtuHiMBEMA6-cNn46oxN8qWDDZVvYKW_dJWo795F3aj5DCb74FCZVVMyEfFye_zK30nWYvvzsAgfAvYCUtf7CkanegSV01t263tkTakXQZs63ALyoGyP47_820Wdu4qbISc5zU_vJU6UT_A1gheLih9vLTS_TV6XqryM2M8em_quKj0POigB7LkGisyyGSKrr7DnE'),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Karnal Logistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('4.8 • Verified', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.call, color: AppTheme.primaryColor),
                style: IconButton.styleFrom(backgroundColor: AppTheme.secondaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _routeItem(Icons.circle, 'Karnal Mandi', 'PICKUP', Colors.teal),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(width: 1, height: 20, color: Colors.grey.shade300),
          ),
          _routeItem(Icons.location_on, 'Azadpur Mandi', 'DROP-OFF', Colors.red),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.local_shipping, color: AppTheme.primaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VEHICLE DETAILS', style: TextStyle(fontSize: 8, color: Colors.grey)),
                      Text('HR 05 AB 1234', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text('12 Wheeler Truck', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeItem(IconData icon, String city, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(city, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PAYMENT SUMMARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        _summaryRow('Estimated Freight', '₹4,250', isBold: true),
        const SizedBox(height: 8),
        _summaryRow('Payment Mode', 'Pay on Delivery', isChip: true),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isChip = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        if (isChip)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          )
        else
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: AppTheme.primaryColor)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.near_me, color: Colors.white, size: 18),
          label: const Text('TRACK LIVE SHIPMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.support_agent, color: AppTheme.primaryColor, size: 18),
          label: const Text('CONTACT SUPPORT', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.1))),
        ),
      ],
    );
  }
}

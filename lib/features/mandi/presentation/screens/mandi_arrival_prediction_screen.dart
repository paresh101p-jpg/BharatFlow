import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class MandiArrivalPredictionScreen extends StatelessWidget {
  const MandiArrivalPredictionScreen({super.key});

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
                _buildPredictiveChart(),
                const SizedBox(height: 24),
                _buildMarketImpactAlert(),
                const SizedBox(height: 24),
                _buildCommoditySpecifics(),
                const SizedBox(height: 24),
                _buildMandiIntensityList(),
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
      title: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuBIQdbPdqKfIp8cmUgm70DijvqvnXvgvzhPGTJEXZrhD5My5yE7h8rDjRNoBMyu3Htwy9i08Jl2yvws4CjBDOQexuoqBSVOaPhlEUXPDLS4GmWy8xngkEf8Vr5gV_FD-qY3lc5fMOKH4TvvZmDAaowC9tDoVvxvhZWQp3GVJwLYVBgx927svypAid78NKt5wt7CkNtIBUtMeHHHmqv9k1V8Q8F7_7VfokrcosgWHlDEtpj3KvDNOrCYAOCEs19qYnKKpzUaYFOo5ZM'),
          ),
          const SizedBox(width: 12),
          Text('Arrival Forecast', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 18, letterSpacing: -1.0)),
        ],
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: AppTheme.primaryColor)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPredictiveChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ARRIVAL FORECAST (NEXT 7 DAYS)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          const Text('2.4k Metric Tons', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
          const SizedBox(height: 24),
          Container(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: ChartPainter(),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mon', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Tue', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Wed', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Thu', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              Text('Fri', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Sat', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Sun', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketImpactAlert() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.trending_down, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMPACT ALERT: AZADPUR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Projected arrival surge expected', style: TextStyle(color: Colors.white60, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Column(
              children: [
                Text('▼ 4.2%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                Text('Price Dip', style: TextStyle(color: Colors.white60, fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommoditySpecifics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Commodity Specifics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _commodityCard('Wheat', '98% Conf.', 'https://lh3.googleusercontent.com/aida-public/AB6AXuB2rZd--0x7PF7G5JmVwWXmyjrsTKEenk0z8zZsIU9HRItZjSNMs6MEoMo-TfdXLmRIAKjlKn8y_vIdHQl7Nxg_HJMKzdTbIfxQGWhQSbWWChnOVYPlxsNBe90sfGsCcZa2ErdhUIrxc0HfMPoYE9uCTrm_6vgdJouhgOkFFrcsrApTEK5-KdqsMJtGi-cHy1kRQqmEekNOl-3WSGMd7pC2jms4QgnhjJbMYjtJCHd0vQtxXyyTBUMZurJB8JIxSDCrnjpgfxVRZ6E'),
              _commodityCard('Tomato', '82% Conf.', 'https://lh3.googleusercontent.com/aida-public/AB6AXuC80no2vJDBS9a7eqqYE5yyvGjyIzYgZGpCSkMzj8oqgsjjfXw0V_ITptactdan1nZtairl7poly0dHnstbtVBaJNODrnAs408tA2Wjt-QonsdxJOeICDo56NtSVXTPmuCWyjm4s2IVEfbHvg63O-mrE2S6YeP_j55yzMikZ4etj4jBt0Y2vobXw4za5ZDcPGOYCqZSwliaJSwuxs7vbOdWs1ae-U6tSWm4kh40MSXiZPreiwIXF6FKMemuyjlBK1KRKIStZdd3Ud4'),
              _commodityCard('Mustard', '91% Conf.', 'https://lh3.googleusercontent.com/aida-public/AB6AXuDBIGXxvMN8EI1m4e4u-HfcJKia7hcFWGaXzZbgMXwOfzyZxLA7P10BIO6l11GlwQlVrUo-9HWVH10j26q8f402oagNVpBpD-dsAw3Qwqo8KzD_SJtPCvaumr2-qON0OCtHRIYvlf4MJatASQua1NvQ4EfraaoLCTDc0Q0HAgKhCLC0RwsmubQ0PVaDTX56T2uImoox9CY4ASnhZqbgQJETr6zepxq279DLC9AEmYnAxuAc7IdMEtxQgxS0VL7vWbzhN5_2Uyjqr4w'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commodityCard(String name, String conf, String imageUrl) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: glassDecoration(),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(imageUrl),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(conf, style: const TextStyle(color: Colors.teal, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMandiIntensityList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mandi Intensity List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _intensityItem('Karnal', 'Avg. 450T daily', 'Peak: Oct 24', 0.75, Colors.teal),
        const SizedBox(height: 12),
        _intensityItem('Azadpur', 'Avg. 1.2kT daily', 'Peak: Oct 21', 0.95, Colors.red),
        const SizedBox(height: 12),
        _intensityItem('Panipat', 'Avg. 320T daily', 'Peak: Oct 28', 0.40, Colors.teal),
      ],
    );
  }

  Widget _intensityItem(String name, String avg, String peak, double progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.location_on, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(avg, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(peak, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.7, size.width * 0.5, size.height * 0.85);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.4, size.width, size.height * 0.2);

    canvas.drawPath(path, paint);

    // Fill under path
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.primaryColor.withOpacity(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Draw active point
    final pointPaint = Paint()..color = AppTheme.primaryColor;
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.53), 4, pointPaint);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.53), 8, pointPaint..color = AppTheme.primaryColor.withOpacity(0.1));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

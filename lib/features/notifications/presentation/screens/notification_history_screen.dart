import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../news/presentation/screens/market_news_hub_screen.dart';
import '../../../dashboard/presentation/screens/favorites_alerts_screen.dart';
import '../../../dashboard/presentation/screens/weather_impact_screen.dart';
import '../../../dashboard/presentation/screens/mandi_calendar_screen.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notification History'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final box = await Hive.openBox('notification_history');
              await box.clear();
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: Hive.openBox('notification_history'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final box = snapshot.data as Box;
          final notifications = box.values.toList().reversed.toList();

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppTheme.primaryColor.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.5))),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = Map<String, dynamic>.from(notifications[index]);
              final type = item['type'] ?? 'news';
              
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.1)),
                ),
                child: ListTile(
                  onTap: () {
                    if (type == 'news') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MarketNewsHubScreen()),
                      );
                    } else if (type == 'price') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FavoritesAlertsScreen()),
                      );
                    } else if (type == 'weather') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WeatherImpactScreen()),
                      );
                    } else if (type == 'festival') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MandiCalendarScreen()),
                      );
                    }
                  },
                  leading: CircleAvatar(
                    backgroundColor: _getIconColor(type).withOpacity(0.1),
                    child: Icon(_getIcon(type), color: _getIconColor(type), size: 20),
                  ),
                  title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['body'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy, hh:mm a').format(DateTime.parse(item['timestamp'])),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'price': return Icons.currency_rupee;
      case 'weather': return Icons.wb_sunny;
      default: return Icons.newspaper;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'price': return Colors.orange;
      case 'weather': return Colors.blue;
      default: return AppTheme.primaryColor;
    }
  }
}

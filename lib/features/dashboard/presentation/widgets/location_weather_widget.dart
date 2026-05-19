import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';

class LocationWeatherWidget extends ConsumerWidget {
  final Map<String, String> loc;
  final Color primaryColor;

  const LocationWeatherWidget({
    super.key,
    required this.loc,
    this.primaryColor = const Color(0xFF1B5E20),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_rounded, color: primaryColor, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc['displayCity'] ?? loc['city'] ?? '...',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if ((loc['displayState'] ?? loc['state'] ?? '').isNotEmpty)
                Text(
                  loc['displayState'] ?? loc['state']!,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              Consumer(builder: (context, ref, child) {
                final lastSync = ref.watch(settingsProvider).lastSync;
                if (lastSync == null) return const SizedBox();
                final diff = DateTime.now().difference(lastSync);
                String ago = '';
                if (diff.inMinutes < 1) ago = 'Just now';
                else if (diff.inMinutes < 60) ago = '${diff.inMinutes}m ago';
                else if (diff.inHours < 24) ago = '${diff.inHours}h ago';
                else ago = '${diff.inDays}d ago';
                
                return Text(
                  'updated $ago',
                  style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.green),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

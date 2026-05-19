import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/news_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MarketNewsHubScreen extends ConsumerStatefulWidget {
  const MarketNewsHubScreen({super.key});

  @override
  ConsumerState<MarketNewsHubScreen> createState() =>
      _MarketNewsHubScreenState();
}

class _MarketNewsHubScreenState extends ConsumerState<MarketNewsHubScreen> with WidgetsBindingObserver {
  bool _isBatteryOptimized = false;
  bool _clickedFixNow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBatteryStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newsProvider.notifier).fetchNews();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _checkBatteryStatus();
      if (_clickedFixNow) {
        // User clicked Fix Now and went to settings. When they return, we automatically
        // dismiss/hide the banner so they get instant satisfaction!
        final box = Hive.box('settings');
        await box.put('battery_warning_dismissed', true);
        if (mounted) {
          setState(() {
            _isBatteryOptimized = false;
          });
        }
        _clickedFixNow = false;
      }
    }
  }

  Future<void> _checkBatteryStatus() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (mounted) {
        setState(() {
          _isBatteryOptimized = !status.isGranted;
        });
      }
    } catch (_) {}
  }

  Future<void> _requestDisableBatteryOptimization() async {
    _clickedFixNow = true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (status.isGranted) {
        _clickedFixNow = false;
        if (mounted) {
          setState(() {
            _isBatteryOptimized = false;
          });
        }
      } else {
        // Fallback: open App Settings so they can disable battery saver there
        await openAppSettings();
      }
    } catch (_) {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(newsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F1),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: newsAsync.when(
              data: (newsList) {
                if (newsList.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.newspaper, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Abhi koi khabar nahi\nRefresh karein',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    _buildBreakingAlerts(newsList.take(3).toList()),
                    const SizedBox(height: 16),
                    _buildNotificationToggle(),
                    const SizedBox(height: 24),
                    _buildTopStories(newsList.skip(3).toList()),
                    const SizedBox(height: 100),
                  ]),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryColor),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('News load nahi ho payi'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(newsProvider.notifier).fetchNews(),
                        child: const Text('Dobara try karein'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    final box = Hive.box('settings');
    final isEnabled = box.get('news_notifications', defaultValue: true);

    final bgColor = isEnabled ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5);
    final borderColor = isEnabled ? const Color(0xFFC8E6C9) : const Color(0xFFE0E0E0);
    final iconColor = isEnabled ? const Color(0xFF2E7D32) : Colors.grey.shade500;
    final titleColor = isEnabled ? const Color(0xFF1B5E20) : Colors.grey.shade800;
    final descColor = isEnabled ? const Color(0xFF388E3C) : Colors.grey.shade500;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, 
                  color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'News Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 14,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      'Sarkari yojana aur kheti ki taaza khabar payein',
                      style: TextStyle(
                        fontSize: 11, 
                        color: descColor,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isEnabled,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF10B981),
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade200,
                onChanged: (val) async {
                  await box.put('news_notifications', val);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        _buildBatteryOptimizationBanner(isEnabled),
      ],
    );
  }

  Widget _buildBatteryOptimizationBanner(bool isNotifEnabled) {
    final box = Hive.box('settings');
    final isDismissed = box.get('battery_warning_dismissed', defaultValue: false);
    if (!isNotifEnabled || !_isBatteryOptimized || isDismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Important: Delayed Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await box.put('battery_warning_dismissed', true);
                  setState(() {});
                },
                child: Icon(Icons.close, color: Colors.amber.shade900, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Android might block news alerts to save battery. Change setting to "No Restrictions" for instant updates.',
            style: TextStyle(fontSize: 11, color: Colors.brown.shade900),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: _requestDisableBatteryOptimization,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Fix Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Kisan Samachar',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => ref.read(newsProvider.notifier).fetchNews(),
          icon: const Icon(Icons.refresh_rounded,
              color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // Top 3 news — horizontal scroll alert cards
  Widget _buildBreakingAlerts(List<NewsItem> news) {
    final colors = [Colors.teal, Colors.orange, Colors.indigo];
    final icons = [Icons.campaign_rounded, Icons.wb_sunny_rounded, Icons.trending_up_rounded];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.campaign_rounded, color: Colors.orange, size: 18),
            SizedBox(width: 6),
            Text('Taaza Khabar',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: news.asMap().entries.map((e) {
              final i = e.key;
              final n = e.value;
              return _alertCard(n, colors[i % colors.length],
                  icons[i % icons.length]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _alertCard(NewsItem news, Color color, IconData icon) {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(news.sourceUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          image: news.imageUrl != null 
            ? DecorationImage(
                image: NetworkImage(news.imageUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
              )
            : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: news.imageUrl != null ? Colors.white : color, size: 14),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd MMM').format(news.publishedAt),
                  style: TextStyle(
                      color: news.imageUrl != null ? Colors.white : color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(news.title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 13,
                    color: news.imageUrl != null ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(news.summary,
                style: TextStyle(
                    color: news.imageUrl != null ? Colors.white70 : Colors.grey, 
                    fontSize: 11
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // Baaki saari news — list style
  Widget _buildTopStories(List<NewsItem> news) {
    if (news.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sabhi Khabarein',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 12),
        ...news.map((item) => _storyCard(item)),
      ],
    );
  }

  Widget _storyCard(NewsItem news) {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(news.sourceUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            // Image ya placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: news.imageUrl != null
                  ? Image.network(
                      news.imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(news.publishedAt),
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(news.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(news.summary,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.eco_rounded,
          color: Colors.green.shade300, size: 32),
    );
  }
}
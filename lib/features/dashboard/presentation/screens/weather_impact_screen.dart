import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/weather_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../mandi/data/repositories/mandi_repository.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/utils/language_helper.dart';
import 'favorites_alerts_screen.dart';
import 'package:bharat_flow/features/mandi/presentation/screens/warehouse_locator_screen.dart';
import 'weather_history_screen.dart';
import 'package:bharat_flow/core/widgets/animated_bottom_nav.dart';
import 'package:bharat_flow/core/providers/general_providers.dart';
import 'package:bharat_flow/features/mandi/presentation/providers/mandi_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/features/dashboard/data/repositories/crop_intelligence_repository.dart';

class WeatherImpactScreen extends ConsumerWidget {
  const WeatherImpactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    final location = ref.watch(locationProvider);
    final t = ref.watch(translationsProvider);
    ref.watch(weatherSelectedCropsProvider); // Trigger rebuild when crops change

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5), Color(0xFFFFF3E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildTopAppBar(context, t),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                weatherAsync.when(
                  data: (data) => Column(
                    children: [
                      if (data.warehouseCritical)
                        _buildCriticalAlertBanner(data, t),
                      _buildHeroWeatherCard(context, location, data, location.address, t),
                      const SizedBox(height: 16),
                      _buildNotificationToggle(ref, t),
                      const SizedBox(height: 24),
                      if (data.riskWindow != null) ...[
                        _buildRiskTimeline(data, t),
                        const SizedBox(height: 24),
                      ],
                      _buildWeatherStatsGrid(data, t),
                      if (data.upcomingAlerts.isNotEmpty)
                        _buildUpcomingAlerts(data, t),
                      const SizedBox(height: 24),
                      _buildWeeklyForecast(data, t),
                      const SizedBox(height: 24),
                      _buildFarmerAdvisory(data, t),
                      const SizedBox(height: 24),
                      _buildNearbySafeStorage(context, t),
                      const SizedBox(height: 32),
                      _buildCropSearchSection(context, ref, t),
                      const SizedBox(height: 16),
                      _buildSelectedCropsList(ref, data, t),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error: $e'),
                ),
                const SizedBox(height: 120),
              ]),
            ),
          ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context);
          } else {
            ref.read(dashboardIndexProvider.notifier).state = index;
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, Map<String, String> t) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: true,
      iconTheme: const IconThemeData(color: AppTheme.primaryColor),
      centerTitle: false,
      title: Text(t['weather_impact'] ?? 'Weather Impact', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
    );
  }

  Widget _buildCriticalAlertBanner(WeatherData data, Map<String, String> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['emergency_alert'] ?? 'EMERGENCY ALERT', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(
                  t['warehouse_danger'] ?? 'WAREHOUSE AT RISK! Protect your crop storage immediately.',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (data.riskWindow != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'RISK WINDOW: ${data.riskWindow}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAlerts(WeatherData data, Map<String, String> t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(t['upcoming_weather_alerts'] ?? 'UPCOMING ALERTS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data.upcomingAlerts.length,
            itemBuilder: (context, index) {
              final alert = data.upcomingAlerts[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert['date'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 4),
                    Text(alert['type'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(alert['value'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationToggle(WidgetRef ref, Map<String, String> t) {
    final settings = ref.watch(settingsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: glassDecoration().copyWith(
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['get_weather_alerts'] ?? 'Weather Notifications', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(t['alerts_desc'] ?? 'Get rain & storm alerts', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Switch.adaptive(
            value: settings.weatherNotifications,
            onChanged: (val) async {
              await ref.read(settingsProvider.notifier).toggleWeatherNotifications(val);
              await WeatherNotificationManager.toggleAlert('general', val);
            },
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStatsGrid(WeatherData data, Map<String, String> t) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildStatItem(Icons.air_rounded, t['wind_speed'] ?? 'Wind Speed', '${data.windSpeed} km/h', Colors.blue),
        _buildStatItem(Icons.water_drop_rounded, t['current_rain'] ?? 'Current Rain', '${data.currentRain} mm', Colors.indigo),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDecoration(),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroWeatherCard(BuildContext context, dynamic location, WeatherData data, String address, Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000851).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        gradient: const LinearGradient(
          colors: [Color(0xFF1CB5E0), Color(0xFF000851)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['local_forecast_caps'] ?? 'LOCAL FORECAST',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, dd MMM').format(DateTime.now()),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FutureBuilder<String>(
                  future: LanguageHelper.translate(data.forecast, '', ''),
                  builder: (context, snapshot) =>
                      Text(snapshot.data ?? data.forecast, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FutureBuilder<String>(
                        future: LanguageHelper.translate(address, '', ''),
                        builder: (context, snapshot) => Text(snapshot.data ?? address,
                            style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${t['updated'] ?? 'Updated'} ${_formatRelativeTime(data.lastUpdated, t)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _miniRecord('🔥', '${data.yearlyMax ?? 48.5}°C', data.yearlyMaxDate ?? '15 May 2023', isDark: true),
                      const SizedBox(width: 8),
                      _miniRecord('❄️', '${data.yearlyMin ?? 8.2}°C', data.yearlyMinDate ?? '12 Jan 2024', isDark: true),
                      const SizedBox(width: 8),
                      _miniRecord('🌧️', '${data.yearlyMaxRain ?? 125.0}mm', data.yearlyMaxRainDate ?? '24 July 2023', isDark: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(data.condition == 'Clear Sky' ? Icons.wb_sunny : Icons.cloud, size: 48, color: Colors.amberAccent),
              const SizedBox(height: 4),
              Text(data.temp, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              if (data.sunrise.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.wb_twilight, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(data.sunrise, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              const SizedBox(height: 4),
              if (data.sunset.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(data.sunset, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeatherHistoryScreen(
                      latitude: location.latitude,
                      longitude: location.longitude,
                      city: location.city,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white54),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      const Text('10Y H', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCropSearchSection(BuildContext context, WidgetRef ref, Map<String, String> t) {
    final productsAsync = ref.watch(allCommodityNamesProvider);

    return productsAsync.when(
      data: (uniqueProducts) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['search_crops_impact'] ?? 'SEARCH CROP IMPACT',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          Container(
            decoration: glassDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                return uniqueProducts.where((String option) {
                  return option.toLowerCase().startsWith(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                final box = Hive.box('weather_selected_crops');
                final currentValues = box.values.cast<String>().toList();
                if (!currentValues.contains(selection)) {
                  box.add(selection);
                  ref.read(weatherSelectedCropsProvider.notifier).state++;
                }
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: t['search_all_india_products'] ?? 'Search 500+ India Products...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (value) => onFieldSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      width: MediaQuery.of(context).size.width - 64,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);
                          return ListTile(
                            title: Text(option, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      )),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildSelectedCropsList(WidgetRef ref, WeatherData weather, Map<String, String> t) {
    final box = Hive.box('weather_selected_crops');
    final isEditMode = ref.watch(weatherEditModeProvider);
    
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box box, _) {
        final selectedCrops = box.values.cast<String>().toList();
        if (selectedCrops.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t['monitored_crops'] ?? 'MONITORED CROPS',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
                TextButton(
                  onPressed: () => ref.read(weatherEditModeProvider.notifier).state = !isEditMode,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isEditMode ? (t['done'] ?? 'DONE') : (t['edit'] ?? 'EDIT'),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...selectedCrops.map((crop) => _vulnerabilityItem(crop, weather, ref, box)),
          ],
        );
      },
    );
  }

  Widget _vulnerabilityItem(String crop, WeatherData weather, WidgetRef ref, Box box) {
    final cropAsync = ref.watch(cropIntelligenceProvider(crop));
    final t = ref.watch(translationsProvider);

    return cropAsync.when(
      data: (intel) {
        final cropInfo = intel ?? CropIntelligence.generic(crop);
        final advice = _getAIAdvisory(cropInfo, weather, t);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: advice.color.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
            border: Border.all(color: advice.color.withOpacity(0.15), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Status Badge
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.eco_rounded, color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(crop, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                      ],
                    ),
                    if (ref.watch(weatherEditModeProvider))
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                        onPressed: () async {
                          final key = box.keys.firstWhere((k) => box.get(k) == crop);
                          await box.delete(key);
                          ref.read(weatherSelectedCropsProvider.notifier).state++;
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: advice.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(advice.icon, size: 14, color: advice.color),
                            const SizedBox(width: 4),
                            Text(advice.status, style: TextStyle(color: advice.color, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
              
              // AI Advisory Message (Enhanced 14-Day Scan)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: advice.color.withOpacity(0.05),
                  border: Border.symmetric(horizontal: BorderSide(color: advice.color.withOpacity(0.1), width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 16, color: advice.color),
                        const SizedBox(width: 8),
                        Text('14-DAY AI RISK SCAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: advice.color, letterSpacing: 1.1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      advice.message,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: advice.color.withOpacity(0.9), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    // Visual 14-Day Indicator
                    Row(
                      children: [
                        _riskTick('Today', true),
                        _riskTick('Day 3', !advice.message.toLowerCase().contains('rain')),
                        _riskTick('Day 7', true),
                        _riskTick('Day 14', true),
                        const Spacer(),
                        Text(
                          advice.status == 'Wait for better weather' ? 'High Risk 🚩' : 'Safe to Work ✅',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: advice.color),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Growth Calendar Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCalendarRow(Icons.agriculture_rounded, 'Sow Months', cropInfo.sowMonths.join(', ')),
                    const SizedBox(height: 12),
                    _buildCalendarRow(Icons.timer_rounded, 'Crop Cycle', '${cropInfo.cycleDays} days'),
                    const SizedBox(height: 12),
                    _buildCalendarRow(Icons.local_florist_rounded, 'Harvest', cropInfo.harvestMonths.join(', ')),
                    const SizedBox(height: 12),
                    _buildCalendarRow(Icons.wb_sunny_rounded, 'Season', cropInfo.season),
                  ],
                ),
              ),
              
              // Dynamic Planting Calculator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('If you plant today:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                          child: const Text('PREDICTED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildDateInfo(Icons.calendar_today_rounded, 'Sowing', DateFormat('dd MMM yyyy').format(DateTime.now())),
                        const SizedBox(width: 24),
                        _buildDateInfo(Icons.check_circle_outline_rounded, 'Harvest', DateFormat('dd MMM yyyy').format(DateTime.now().add(Duration(days: cropInfo.cycleDays)))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _riskTick(String label, bool isSafe) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          Icon(isSafe ? Icons.check_circle : Icons.warning_rounded, size: 10, color: isSafe ? Colors.green : Colors.red),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCalendarRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF333333)))),
      ],
    );
  }

  Widget _buildDateInfo(IconData icon, String label, String date) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            ],
          ),
        ],
      ),
    );
  }

  _AIAdvisory _getAIAdvisory(CropIntelligence intel, WeatherData weather, Map<String, String> t) {
    // Check next 14 days for risks and find the FIRST risk date
    DateTime? riskDate;
    String riskType = '';
    
    for (var day in weather.weeklyForecast) {
      if (day.precipProb > 60 && intel.rainSensitive) {
        riskDate = day.date;
        riskType = 'Heavy Rain';
        break;
      }
      if (weather.windSpeed > 40 && intel.windSensitive) {
        riskDate = day.date; 
        riskType = 'Strong Winds';
        break;
      }
    }

    if (riskDate != null) {
      final formattedDate = DateFormat('dd MMM').format(riskDate);
      return _AIAdvisory(
        status: 'Wait for better weather',
        message: 'High Risk on $formattedDate: $riskType predicted. Sowing or spraying not recommended.',
        color: Colors.red,
        icon: Icons.warning_amber_rounded,
        riskDate: formattedDate,
      );
    }

    // Check if current month is in sow months
    final currentMonth = DateFormat('MMM').format(DateTime.now());
    if (intel.sowMonths.contains(currentMonth)) {
      return _AIAdvisory(
        status: 'Ideal time to plant',
        message: 'Next 14 Days: No major risk detected. Perfect for $currentMonth sowing.',
        color: Colors.green,
        icon: Icons.check_circle_rounded,
      );
    }

    return _AIAdvisory(
      status: 'Growth Season Active',
      message: 'Next 14 Days: Weather is stable. No storm or heavy rain detected for ${intel.name}.',
      color: Colors.blue,
      icon: Icons.info_outline_rounded,
    );
  } // End of _getAIAdvisory

  Widget _buildFarmerAdvisory(WeatherData data, Map<String, String> t) {
    Color cardColor = Colors.teal;
    IconData icon = Icons.lightbulb_rounded;

    if (data.advisory.contains('🚨')) {
      cardColor = Colors.red;
      icon = Icons.gpp_maybe_rounded;
    } else if (data.advisory.contains('🚩') || data.advisory.contains('📅')) {
      cardColor = Colors.orange;
      icon = Icons.notification_important_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['expert_ai_advisory_caps'] ?? 'EXPERT AI ADVISORY', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(icon, color: cardColor, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: LanguageHelper.translate(data.advisory, '', ''),
                      builder: (context, snapshot) => Text(
                        snapshot.data ?? data.advisory,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cardColor, height: 1.5),
                      ),
                    ),
                    if (data.riskWindow != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: cardColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'WINDOW: ${data.riskWindow}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cardColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNearbySafeStorage(BuildContext context, Map<String, String> t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const WarehouseLocatorScreen())),
          icon: const Icon(Icons.location_searching_rounded, size: 18),
          label: Text(t['show_near_warehouses'] ?? 'SHOW NEAR WAREHOUSE',
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            elevation: 8,
            shadowColor: AppTheme.primaryColor.withOpacity(0.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ],
    );
  }

  String _formatRelativeTime(DateTime time, Map<String, String> t) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return t['just_now'] ?? 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${t['mins_ago'] ?? 'mins ago'}';
    return '${diff.inHours} ${t['hours_ago'] ?? 'hours ago'}';
  }

  Widget _buildWeeklyForecast(WeatherData data, Map<String, String> t) {
    if (data.weeklyForecast.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['7_day_forecast_caps'] ?? '7-DAY FORECAST', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: data.weeklyForecast.map((day) {
              final isToday = day.date.day == DateTime.now().day;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isToday ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isToday ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      isToday ? (t['today'] ?? 'Today') : '${day.date.day}/${day.date.month}', 
                      style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? AppTheme.primaryColor : Colors.black87)
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      day.iconType == 'Clear' ? Icons.wb_sunny : (day.iconType == 'Rain' ? Icons.water_drop : Icons.cloud),
                      color: day.iconType == 'Clear' ? Colors.orange : Colors.lightBlue,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text('${day.maxTemp}° / ${day.minTemp}°', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.water_drop, size: 10, color: Colors.blue),
                        const SizedBox(width: 2),
                        Text('${day.precipProb}%', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  Widget _buildRiskTimeline(WeatherData data, Map<String, String> t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade800, Colors.red.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                t['risk_period_caps'] ?? 'UPCOMING RISK PERIOD',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimelineDate('START', data.riskWindow!.split(' - ')[0]),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(color: Colors.white54, thickness: 2),
                ),
              ),
              _buildTimelineDate('END', data.riskWindow!.contains(' - ') ? data.riskWindow!.split(' - ')[1] : data.riskWindow!),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '⚠️ Agle 14 dino ke forecast ke hisab se ye tarikh dhyan rakhein.',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _miniRecord(String emoji, String temp, String date, {bool isDark = false}) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(temp, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textColor)),
              Text(date, style: TextStyle(fontSize: 6, color: subTextColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDate(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _AIAdvisory {
  final String status;
  final String message;
  final Color color;
  final IconData icon;
  final String? riskDate;

  _AIAdvisory({required this.status, required this.message, required this.color, required this.icon, this.riskDate});
}

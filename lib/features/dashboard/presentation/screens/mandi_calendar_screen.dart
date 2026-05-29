import 'package:flutter/material.dart';
import 'package:bharat_flow/core/widgets/common_app_bar.dart';
import 'package:bharat_flow/core/services/admob_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/services/notification_service.dart';
import 'festival_detail_screen.dart';
import 'dart:convert';
import '../../data/repositories/festival_repository.dart';

class MandiCalendarScreen extends ConsumerStatefulWidget {
  const MandiCalendarScreen({super.key});

  @override
  ConsumerState<MandiCalendarScreen> createState() => _MandiCalendarScreenState();
}

class _MandiCalendarScreenState extends ConsumerState<MandiCalendarScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isGujarati = settings.language == 'Gujarati';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF7),
      appBar: AppBar(
        title: Text(isGujarati ? 'તહેવાર કેલેન્ડર' : 'Festival Calendar', 
          style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryColor, letterSpacing: 0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primaryColor),
            onPressed: () => shareAppBranding(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(isGujarati),
          Expanded(child: _buildFestivalList(isGujarati)),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(bool isGujarati) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: isGujarati ? 'તહેવાર શોધો...' : 'Search festivals...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFestivalList(bool isGujarati) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchFestivals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(isGujarati ? 'કોઈ તહેવાર મળ્યો નથી' : 'No festivals found'));
        }

        final filtered = snapshot.data!.where((f) {
          final name = f['name'].toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

        if (filtered.isEmpty) {
          return Center(child: Text(isGujarati ? 'શોધ મુજબ કોઈ તહેવાર નથી' : 'No matching festivals'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length + (filtered.length ~/ 5),
          itemBuilder: (context, index) {
            if (index > 0 && (index + 1) % 6 == 0) {
              return const DynamicAdmobCardWidget();
            }

            final dataIndex = index - (index ~/ 6);
            if (dataIndex < filtered.length) {
              final f = filtered[dataIndex];
              final date = DateTime.parse(f['date']);
              final day = DateFormat('dd').format(date);
              final month = DateFormat('MMM').format(date).toUpperCase();
              
              return _buildFestivalTile(context, f, day, month, date);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFestivals() async {
    final today = DateTime.now();
    final upcomingList = FestivalRepository.masterList.where((f) {
      final festDate = DateTime.parse(f['date']);
      return festDate.isAfter(today) || (festDate.year == today.year && festDate.month == today.month && festDate.day == today.day);
    }).toList();

    upcomingList.sort((a, b) => a['date'].compareTo(b['date']));
    return upcomingList;
  }

  String _getTithiForDate(DateTime date, bool isGujarati) {
    // Basic Lunar Tithi Calculation Logic for 2026 (Approximate)
    // Base New Moon (Amavasya): Feb 17, 2026
    final baseNewMoon = DateTime(2026, 2, 17);
    final diffDays = date.difference(baseNewMoon).inDays;
    final lunarDay = (diffDays % 29.53).floor() + 1;
    
    final List<String> tithis = isGujarati 
      ? ['એકમ', 'બીજ', 'ત્રીજ', 'ચોથ', 'પાંચમ', 'છઠ', 'સાતમ', 'આઠમ', 'નોમ', 'દસમ', 'અગિયારસ', 'બારસ', 'તેરસ', 'ચૌદસ', 'પૂનમ', 
         'એકમ', 'બીજ', 'ત્રીજ', 'ચોથ', 'પાંચમ', 'છઠ', 'સાતમ', 'આઠમ', 'નોમ', 'દસમ', 'અગિયારસ', 'બારસ', 'તેરસ', 'ચૌદસ', 'અમાસ']
      : ['Prathama', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi', 'Saptami', 'Ashtami', 'Navami', 'Dashami', 'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi', 'Purnima',
         'Prathama', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi', 'Saptami', 'Ashtami', 'Navami', 'Dashami', 'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi', 'Amavasya'];
    
    final paksha = lunarDay <= 15 ? (isGujarati ? 'સુદ' : 'Shukla') : (isGujarati ? 'વદ' : 'Krishna');
    final tithiIndex = (lunarDay - 1).clamp(0, 29);
    
    return '$paksha ${tithis[tithiIndex]}';
  }

  Widget _buildFestivalTile(BuildContext context, Map<String, dynamic> f, String day, String month, DateTime date) {
    final settings = ref.watch(settingsProvider);
    final isGujarati = settings.language == 'Gujarati';
    final tithi = _getTithiForDate(date, isGujarati);
    final name = f['name'];
    final desc = f['description'] ?? 'Festival';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final festDate = DateTime(date.year, date.month, date.day);
    final daysLeft = festDate.difference(today).inDays;
    
    // Vibrant Colors based on festival proximity
    final List<Color> cardGradient = daysLeft == 0 
      ? [const Color(0xFFFF5F6D), const Color(0xFFFFC371)] // Today: Sunset Orange
      : daysLeft <= 7 
        ? [const Color(0xFF2193b0), const Color(0xFF6dd5ed)] // Upcoming: Ocean Blue
        : [Colors.white, Colors.white];

    final Color primaryTextColor = daysLeft <= 7 ? Colors.white : AppTheme.primaryColor;
    final Color secondaryTextColor = daysLeft <= 7 ? Colors.white.withOpacity(0.9) : Colors.grey.shade700;

    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FestivalDetailScreen(festival: f))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left Color Strip
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: daysLeft == 0 ? Colors.orange : (daysLeft <= 7 ? AppTheme.primaryColor : Colors.grey.shade300),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                  ),
                ),
                const SizedBox(width: 12),
                // Date Section
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(month, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                        Text(day, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor, height: 1.1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Middle Section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(isGujarati ? 'તિથિ: ' : 'TITHI: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                            Flexible(child: Text(tithi, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600))),
                          ],
                        ),
                        _buildMandiStatus(f),
                      ],
                    ),
                  ),
                ),
                // Right Countdown Section (Bold)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: daysLeft <= 7 ? AppTheme.primaryColor.withOpacity(0.05) : Colors.transparent,
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        daysLeft == 0 ? (isGujarati ? 'આજે' : 'TODAY') : '$daysLeft',
                        style: TextStyle(
                          fontSize: daysLeft == 0 ? 14 : 24, 
                          fontWeight: FontWeight.w900, 
                          color: daysLeft <= 7 ? AppTheme.primaryColor : Colors.grey.shade400
                        ),
                      ),
                      if (daysLeft > 0)
                        Text(
                          isGujarati ? 'દિવસ' : 'DAYS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: daysLeft <= 7 ? AppTheme.primaryColor : Colors.grey.shade400),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMandiStatus(Map<String, dynamic> f) {
    final bool isClosed = f['is_mandi_closed'] ?? false;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isClosed ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isClosed ? Icons.close_rounded : Icons.check_circle_outline, size: 10, color: isClosed ? Colors.red : Colors.green),
          const SizedBox(width: 4),
          Text(
            isClosed ? 'CLOSED MANDI' : 'OPEN MANDI',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.3, color: isClosed ? Colors.red : Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBadge(int daysLeft) {
    final settings = ref.watch(settingsProvider);
    final isGujarati = settings.language == 'Gujarati';
    
    String text = '';
    if (daysLeft == 0) {
      text = isGujarati ? 'આજે' : 'TODAY';
    } else if (daysLeft == 1) {
      text = isGujarati ? 'આવતીકાલે' : 'TOMORROW';
    } else {
      text = isGujarati ? '$daysLeft દિવસ બાકી' : '$daysLeft DAYS LEFT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: daysLeft <= 7 ? Colors.white.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: daysLeft <= 7 ? Colors.white30 : AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Text(
        text, 
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 0.5,
          color: daysLeft <= 7 ? Colors.white : AppTheme.primaryColor
        )
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'package:bharat_flow/core/providers/location_provider.dart' as core_loc;
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/providers/general_providers.dart';
import 'package:bharat_flow/features/dashboard/presentation/widgets/location_weather_widget.dart';
import 'package:bharat_flow/features/notifications/presentation/screens/notification_history_screen.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_screen.dart';
import 'package:bharat_flow/core/services/share_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bharat_flow/features/profile/data/repositories/profile_repository.dart';

class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool showBack;
  final bool showActions;
  final String? title;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final bool showProfile;

  const CommonAppBar({
    super.key,
    this.showBack = false,
    this.showActions = true,
    this.title,
    this.onBack,
    this.bottom,
    this.showProfile = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(core_loc.dashboardLocationProvider);
    final googleUserAsync = ref.watch(googleUserProvider);
    final hasUnread = ref.watch(hasUnreadNotificationsProvider);
    final t = ref.watch(translationsProvider);
    const primary = Color(0xFF1B5E20);

    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;
    final googleUser = googleUserAsync.value;
    final authUser = Supabase.instance.client.auth.currentUser;
    final box = Hive.box('settings');

    final String? photoUrl = profile?.avatarUrl ??
        googleUser?.photoUrl ??
        authUser?.userMetadata?['avatar_url'] ??
        authUser?.userMetadata?['picture'] ??
        box.get('userPhoto');

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 64,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : 16,
      bottom: bottom,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primary, size: 20),
              onPressed: onBack ?? () => Navigator.pop(context),
            )
          : null,
      title: title != null
          ? Text(title!, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), fontSize: 18))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 36,
                    width: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "BharatFlow",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
      actions: showActions
          ? [
              GestureDetector(
                onTap: () => shareAppBranding(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share, color: primary, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasUnread ? Icons.notifications_active : Icons.notifications_none,
                        color: primary,
                        size: 22,
                      ),
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              if (showProfile) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary.withOpacity(0.2), width: 1.5),
                    ),
                    child: ClipOval(
                      child: photoUrl != null
                          ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatar(primary))
                          : _avatar(primary),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 16),
            ]
          : null,
    );
  }

  Widget _avatar(Color primary) => Container(
        color: primary.withOpacity(0.1),
        child: Icon(Icons.person, color: primary, size: 22),
      );
}

class CommonSliverAppBar extends ConsumerWidget {
  final bool showBack;
  final bool showActions;
  final String? title;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final bool showProfile;

  const CommonSliverAppBar({
    super.key,
    this.showBack = false,
    this.showActions = true,
    this.title,
    this.onBack,
    this.bottom,
    this.showProfile = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(core_loc.dashboardLocationProvider);
    final googleUserAsync = ref.watch(googleUserProvider);
    final hasUnread = ref.watch(hasUnreadNotificationsProvider);
    final t = ref.watch(translationsProvider);
    const primary = Color(0xFF1B5E20);

    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;
    final googleUser = googleUserAsync.value;
    final authUser = Supabase.instance.client.auth.currentUser;
    final box = Hive.box('settings');

    final String? photoUrl = profile?.avatarUrl ??
        googleUser?.photoUrl ??
        authUser?.userMetadata?['avatar_url'] ??
        authUser?.userMetadata?['picture'] ??
        box.get('userPhoto');

    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 64,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : 16,
      bottom: bottom,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primary, size: 20),
              onPressed: onBack ?? () => Navigator.pop(context),
            )
          : null,
      title: title != null
          ? Text(title!, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), fontSize: 18))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 36,
                    width: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "BharatFlow",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
      actions: showActions
          ? [
              GestureDetector(
                onTap: () => shareAppBranding(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share, color: primary, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasUnread ? Icons.notifications_active : Icons.notifications_none,
                        color: primary,
                        size: 22,
                      ),
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              if (showProfile) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary.withOpacity(0.2), width: 1.5),
                    ),
                    child: ClipOval(
                      child: photoUrl != null
                          ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatar(primary))
                          : _avatar(primary),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 16),
            ]
          : null,
    );
  }

  Widget _avatar(Color primary) => Container(
        color: primary.withOpacity(0.1),
        child: Icon(Icons.person, color: primary, size: 22),
      );
}

Future<void> shareAppBranding(BuildContext context) async {
  try {
    final byteData = await rootBundle.load('assets/images/logo.png');
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/bharat_flow_logo.png');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List(
      byteData.offsetInBytes, 
      byteData.lengthInBytes,
    ));

    await ShareManager.shareXFiles(
      context,
      [XFile(tempFile.path)],
      text: '🌾 *BharatFlow super app* 🌾\n\nLive Mandi Prices, Proximity Crop Calendars, Kisan Market Store, and Real-time Price Alerts! 📲\n\nDownload Now:\nhttps://play.google.com/store/apps/details?id=com.BharatFlow',
      subject: 'Download BharatFlow App',
    );
  } catch (e) {
    await ShareManager.share(
      context,
      '🌾 *BharatFlow super app* 🌾\n\nLive Mandi Prices, Proximity Crop Calendars, Kisan Market Store, and Real-time Price Alerts! 📲\n\nDownload Now:\nhttps://play.google.com/store/apps/details?id=com.BharatFlow',
      subject: 'Download BharatFlow App',
    );
  }
}

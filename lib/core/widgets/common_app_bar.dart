import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'package:bharat_flow/core/providers/location_provider.dart' as core_loc;
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/core/providers/general_providers.dart';
import 'package:bharat_flow/features/dashboard/presentation/widgets/location_weather_widget.dart';
import 'package:bharat_flow/features/notifications/presentation/screens/notification_history_screen.dart';
import 'package:bharat_flow/features/profile/presentation/screens/profile_screen.dart';

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

    String? photoUrl = googleUserAsync.when(
      data: (user) => user?.photoUrl,
      loading: () => null,
      error: (_, __) => null,
    );

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
          : locationAsync.when(
              data: (loc) => LocationWeatherWidget(loc: loc),
              loading: () => LocationWeatherWidget(loc: {'displayCity': t['fetching_location'] ?? 'Locating...', 'displayState': ''}),
              error: (_, __) => const LocationWeatherWidget(loc: {'displayCity': 'Surat', 'displayState': 'Gujarat'}),
            ),
      actions: showActions
          ? [
              GestureDetector(
                onTap: () {
                  ref.read(hasUnreadNotificationsProvider.notifier).state = false;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()));
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_none_rounded, color: primary, size: 22),
                      ),
                      if (hasUnread)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (showProfile)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary.withOpacity(0.4), width: 2),
                    ),
                    child: ClipOval(
                      child: photoUrl != null
                          ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatar(primary))
                          : _avatar(primary),
                    ),
                  ),
                ),
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

    String? photoUrl = googleUserAsync.when(
      data: (user) => user?.photoUrl,
      loading: () => null,
      error: (_, __) => null,
    );

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
          : locationAsync.when(
              data: (loc) => LocationWeatherWidget(loc: loc),
              loading: () => LocationWeatherWidget(loc: {'displayCity': t['fetching_location'] ?? 'Locating...', 'displayState': ''}),
              error: (_, __) => const LocationWeatherWidget(loc: {'displayCity': 'Surat', 'displayState': 'Gujarat'}),
            ),
      actions: showActions
          ? [
              GestureDetector(
                onTap: () {
                  ref.read(hasUnreadNotificationsProvider.notifier).state = false;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()));
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_none_rounded, color: primary, size: 22),
                      ),
                      if (hasUnread)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primary.withOpacity(0.4), width: 2),
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatar(primary))
                        : _avatar(primary),
                  ),
                ),
              ),
            ]
          : null,
    );
  }

  Widget _avatar(Color primary) => Container(
        color: primary.withOpacity(0.1),
        child: Icon(Icons.person, color: primary, size: 22),
      );
}

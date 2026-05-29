import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bharat_flow/core/utils/date_formatter.dart';
import 'package:bharat_flow/core/theme/app_theme.dart';
import 'package:bharat_flow/features/auth/presentation/screens/login_screen.dart';
import 'package:bharat_flow/features/profile/data/repositories/profile_repository.dart';
import 'package:bharat_flow/features/profile/presentation/screens/support_screens.dart';
import 'package:bharat_flow/features/profile/presentation/screens/public_profile_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';
import 'dart:ui';
import 'package:bharat_flow/core/providers/settings_provider.dart';
import 'package:bharat_flow/features/mandi/presentation/providers/mandi_providers.dart';

import 'package:intl/intl.dart';
import 'package:bharat_flow/core/widgets/common_app_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _primaryGradient = const LinearGradient(
    colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool _isSaving = false;

  // ─── FIX 2: Proactive session check on screen open ──────────────────────
  @override
  void initState() {
    super.initState();
    _proactiveSessionCheck();
  }

  Future<void> _proactiveSessionCheck() async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;

    if (session == null) {
      debugPrint(
          '_proactiveSessionCheck: No session found, ensuring session...');
      await _ensureSession();
      return;
    }

    // Refresh if token expires within 5 minutes
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      session.expiresAt! * 1000,
    );
    final timeUntilExpiry = expiresAt.difference(DateTime.now());

    if (timeUntilExpiry.inMinutes < 5) {
      debugPrint('_proactiveSessionCheck: Token expiring soon, refreshing...');
      try {
        await auth.refreshSession();
        debugPrint('_proactiveSessionCheck: Token refreshed ✓');
      } catch (e) {
        debugPrint('_proactiveSessionCheck: Refresh failed: $e');
        await _ensureSession();
      }
    }
  }

  String _getMemberSinceText(DateTime? createdAt, Map<String, String> t) {
    final dateToUse = createdAt ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMM yyyy').format(dateToUse);
    final days = DateTime.now().difference(dateToUse).inDays;
    final String daysOldSuffix = t['days_old'] ?? 'Days Old';
    return '$formattedDate • $days $daysOldSuffix';
  }

  // ─── FIX 1: Improved _ensureSession with Supabase refresh + redirect ────
  Future<User?> _ensureSession() async {
    try {
      final auth = Supabase.instance.client.auth;

      // Level 1: Active session
      if (auth.currentUser != null) {
        debugPrint('_ensureSession: Current user found ✓');
        return auth.currentUser;
      }

      // Level 2: Try refreshing the existing Supabase session first
      debugPrint('_ensureSession: Trying Supabase session refresh...');
      try {
        final refreshed = await auth.refreshSession();
        if (refreshed.user != null) {
          debugPrint('_ensureSession: Supabase refresh successful ✓');
          return refreshed.user;
        }
      } catch (e) {
        debugPrint('_ensureSession: Supabase refresh failed: $e');
      }

      // Level 3: Silent Google re-auth → new Supabase token
      debugPrint('_ensureSession: Trying silent Google re-auth...');
      try {
        final googleUser = await googleSignInInstance.signInSilently();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          if (googleAuth.idToken != null) {
            final res = await auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: googleAuth.idToken!,
              accessToken: googleAuth.accessToken,
            );
            if (res.user != null) {
              debugPrint('_ensureSession: Silent Google re-auth successful ✓');
              return res.user;
            }
          }
        }
      } catch (e) {
        debugPrint('_ensureSession: Silent re-auth failed: $e');
      }

      // Level 4: Redirect to login instead of showing error or interactive popup
      debugPrint('_ensureSession: All methods failed, redirecting to login...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('_ensureSession critical error: $e');
      return null;
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final googleUserAsync = ref.watch(googleUserProvider);
    final t = ref.watch(translationsProvider);
    final googleUser = googleUserAsync.value;
    final profile = profileAsync.value;
    final authUser = Supabase.instance.client.auth.currentUser;
    final box = Hive.box('settings');

    final String name = profile?.fullName ?? 
        googleUser?.displayName ?? 
        authUser?.userMetadata?['full_name'] ?? 
        authUser?.userMetadata?['name'] ?? 
        box.get('userName') ?? 
        'Bharat User';

    final String email = profile?.email ?? 
        googleUser?.email ?? 
        authUser?.email ?? 
        box.get('userEmail') ?? 
        'Account Email';

    final String? photoUrl = profile?.avatarUrl ?? 
        googleUser?.photoUrl ?? 
        authUser?.userMetadata?['avatar_url'] ?? 
        authUser?.userMetadata?['picture'] ?? 
        box.get('userPhoto');

    final DateTime? authCreatedAt = authUser?.createdAt != null
        ? DateTime.parse(authUser!.createdAt)
        : null;
    final DateTime? profileCreatedAt = profile?.createdAt;

    DateTime? effectiveCreatedAt = profileCreatedAt;
    if (authCreatedAt != null) {
      if (effectiveCreatedAt == null ||
          authCreatedAt.isBefore(effectiveCreatedAt)) {
        effectiveCreatedAt = authCreatedAt;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: _primaryGradient,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        profileAsync.when(
                          data: (_) => _buildPremiumProfileCard(
                              name,
                              _getMemberSinceText(effectiveCreatedAt, t),
                              photoUrl,
                              t),
                          loading: () => _buildPremiumProfileCard(
                              name, t['loading'] ?? 'Loading...', photoUrl, t),
                          error: (_, __) => _buildPremiumProfileCard(
                              name,
                              _getMemberSinceText(effectiveCreatedAt, t),
                              photoUrl,
                              t),
                        ),
                        const SizedBox(height: 30),
                        profileAsync.when(
                          data: (profile) =>
                              _buildModernSettingsList(profile, email, t),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                          ),
                          error: (e, _) => _buildErrorState(e.toString()),
                        ),
                        const SizedBox(height: 40),
                        _buildLogoutButton(context),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                    SizedBox(height: 20),
                    Text(
                      'Syncing with Database...',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── WIDGETS ───────────────────────────────────────────────────────────────

  Widget _buildModernAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      actions: const [],
    );
  }

  Widget _buildPremiumProfileCard(
      String name, String subText, String? photoUrl, Map<String, String> t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF0D47A1)]),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person, size: 50, color: Color(0xFF1976D2))
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Text(name,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E))),
          const SizedBox(height: 4),
          Text(subText,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final authUser = Supabase.instance.client.auth.currentUser;
              if (authUser != null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PublicProfileScreen(
                              userId: authUser.id,
                              userName: name,
                              userAvatar: photoUrl,
                            )));
              }
            },
            icon: const Icon(Icons.remove_red_eye, size: 18),
            label: Text(t['view_profile'] ?? 'View my Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSettingsList(UserProfile? profile, String currentEmail, Map<String, String> t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 15),
          child: Text(t['personal_info']?.toUpperCase() ?? 'PERSONAL INFORMATION',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            children: [
              _modernItem(
                  icon: Icons.email_rounded,
                  title: t['account_email'] ?? 'Account Email',
                  value: currentEmail,
                  color: Colors.blueGrey,
                  onTap: null),
              _divider(),
              _modernItem(
                  icon: Icons.phone_android_rounded,
                  title: t['mobile_number'] ?? 'Mobile Number',
                  value: profile?.mobileNo != null && profile!.mobileNo!.isNotEmpty
                      ? profile.mobileNo!
                      : (t['not_set'] ?? 'Not set'),
                  color: Colors.orange,
                  onTap: () => _editField(
                      'mobile_no', t['mobile_number'] ?? 'Mobile Number', Icons.phone, currentEmail)),
              _divider(),
              _modernItem(
                  icon: Icons.cake_rounded,
                  title: t['birthday_label'] ?? 'Birthdate',
                  value: profile?.birthday != null
                      ? AppDateFormatter.format(profile!.birthday!)
                      : (t['not_set'] ?? 'Not set'),
                  color: Colors.pink,
                  onTap: () => _editBirthday(profile, currentEmail)),
              _divider(),
              _modernItem(
                  icon: Icons.location_city_rounded,
                  title: t['city'] ?? 'City',
                  value: profile?.city != null && profile!.city!.isNotEmpty
                      ? profile.city!
                      : (t['not_set'] ?? 'Not set'),
                  color: Colors.teal,
                  onTap: () => _editField(
                      'city', t['city'] ?? 'City', Icons.location_city, currentEmail)),
              _divider(),
              _modernItem(
                  icon: Icons.home_rounded,
                  title: t['full_address'] ?? 'Full Address',
                  value: profile?.fullAddress != null && profile!.fullAddress!.isNotEmpty
                      ? profile.fullAddress!
                      : (t['not_set'] ?? 'Not set'),
                  color: Colors.indigo,
                  onTap: () => _editAddress(profile, currentEmail)),
              _divider(),
              _modernItem(
                  icon: Icons.language_rounded,
                  title: t['app_language'] ?? 'App Language',
                  value: ref.watch(settingsProvider).language,
                  color: Colors.blue,
                  onTap: () => _showLanguageSelectionDialog()),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 15),
          child: Text(t['support_help']?.toUpperCase() ?? 'SUPPORT & HELP',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            children: [
              _modernItem(
                  icon: Icons.help_center_rounded,
                  title: t['help_center'] ?? 'Help Center',
                  value: 'Get assistance',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HelpCenterScreen()))),
              _divider(),
              _modernItem(
                  icon: Icons.privacy_tip_rounded,
                  title: t['privacy_policy'] ?? 'Privacy Policy',
                  value: 'Data & Security',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()))),
              _divider(),
              _modernItem(
                  icon: Icons.info_rounded,
                  title: t['bharatflow_version'] ?? 'BharatFlow Version',
                  value: '1.0.8 Production',
                  color: Colors.blueGrey,
                  onTap: null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modernItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50))),
      subtitle: Text(value,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: value == 'Not set'
                  ? Colors.redAccent
                  : Colors.grey.shade600)),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
          : null,
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey.shade100, indent: 70);

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text('Syncing error: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
          TextButton(
              onPressed: () => ref.invalidate(profileProvider),
              child: const Text('Try Again')),
        ],
      ),
    );
  }

  // ─── ACTIONS ───────────────────────────────────────────────────────────────

  Future<void> _doUpdate(Map<String, dynamic> data, String currentEmail) async {
    setState(() => _isSaving = true);

    final auth = Supabase.instance.client.auth;
    User? user = auth.currentUser;

    // If null, try full ensure session flow
    if (user == null) {
      user = await _ensureSession();
    }

    // If still null after _ensureSession, it already redirected to login
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    final uid = user.id;

    final Map<String, dynamic> updateData = {
      ...data,
      'id': uid,
      // ✅ 'email' field removed — fixes duplicate key constraint on profiles_email_idx
    };

    try {
      await Supabase.instance.client
          .from('profiles')
          .upsert(updateData, onConflict: 'id');

      await Future.delayed(const Duration(milliseconds: 500));
      ref.invalidate(profileProvider);
      await ref.read(profileProvider.future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Profile Save Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editField(
      String field, String label, IconData icon, String currentEmail) {
    final controller = TextEditingController();
    final bool isPhone = field == 'mobile_no';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernSheet(
        title: 'Update $label',
        child: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: isPhone ? TextInputType.number : TextInputType.text,
          maxLength: isPhone ? 10 : null,
          inputFormatters: isPhone
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]
              : [],
          decoration: InputDecoration(
            hintText: isPhone ? 'Enter 10 digit number' : 'Enter $label',
            prefixIcon: Icon(icon, color: Colors.blue),
            filled: true,
            counterText: '',
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none),
          ),
        ),
        onSave: () async {
          if (isPhone && controller.text.length != 10) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please enter a valid 10-digit number')),
            );
            return;
          }
          await _doUpdate({field: controller.text}, currentEmail);
        },
      ),
    );
  }

  void _editBirthday(UserProfile? profile, String currentEmail) async {
    if (profile != null && profile.birthdayEditCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit limit reached (3/3)')));
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: profile?.birthday ??
          DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await _doUpdate({
        'birthday': picked.toIso8601String().split('T')[0],
        'birthday_edit_count': (profile?.birthdayEditCount ?? 0) + 1,
      }, currentEmail);
    }
  }

  void _editAddress(UserProfile? profile, String currentEmail) {
    final controller = TextEditingController(text: profile?.fullAddress);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernSheet(
        title: 'Update Full Address',
        child: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter complete address',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none),
          ),
        ),
        onSave: () async => await _doUpdate({
          'full_address': controller.text,
          'address_updated_at': DateTime.now().toIso8601String(),
        }, currentEmail),
      ),
    );
  }

  void _showLanguageSelectionDialog() {
    final currentLang = ref.read(settingsProvider).language;
    final List<Map<String, String>> languages = [
      {'name': 'English', 'native': 'English'},
      {'name': 'Hindi', 'native': 'हिन्दी'},
      {'name': 'Gujarati', 'native': 'ગુજરાતી'},
      {'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
      {'name': 'Marathi', 'native': 'मराठी'},
      {'name': 'Bengali', 'native': 'বাংলা'},
      {'name': 'Telugu', 'native': 'తెలుగు'},
      {'name': 'Tamil', 'native': 'தமிழ்'},
      {'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
      {'name': 'Malayalam', 'native': 'മലയാളം'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select App Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your preferred language for the app',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  final isSelected = lang['name'] == currentLang;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE3F2FD)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1976D2)
                            : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      onTap: () {
                        final name = lang['name']!;
                        ref.read(settingsProvider.notifier).setLanguage(name);
                        ref
                            .read(settingsProvider.notifier)
                            .toggleAutoLanguage(false);

                        final box = Hive.box('settings');
                        box.put('language', name);
                        box.put('selected_language', name);
                        box.put('auto_language_enabled', false);

                        ref.invalidate(translationsProvider);
                        ref.invalidate(mandiPricesProvider);
                        ref.invalidate(productListProvider);
                        ref.invalidate(mandiProductsProvider);
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Language changed to $name successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? const Color(0xFF1976D2)
                            : Colors.grey.shade300,
                        radius: 18,
                        child: Text(
                          lang['name']!.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        lang['name']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF0D47A1)
                              : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        lang['native']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? const Color(0xFF1976D2)
                              : Colors.grey.shade600,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF1976D2))
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog(String currentEmail) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernSheet(
        title: 'Select Your Category',
        child: Column(
          children: [
            _catOption('Farmer', Icons.agriculture, Colors.green, currentEmail),
            const SizedBox(height: 12),
            _catOption(
                'Consumer', Icons.shopping_bag, Colors.blue, currentEmail),
            const SizedBox(height: 20),
            const Text('Note: This cannot be changed later.',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _catOption(
      String val, IconData icon, Color color, String currentEmail) {
    return InkWell(
      onTap: () async {
        await _doUpdate({'user_type': val}, currentEmail);
        if (mounted) Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Text(val,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const Spacer(),
          Icon(Icons.check_circle_outline, color: color, size: 18),
        ]),
      ),
    );
  }

  Widget _buildModernSheet({
    required String title,
    required Widget child,
    Function? onSave,
  }) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A237E))),
            const SizedBox(height: 25),
            child,
            if (onSave != null) ...[
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () async {
                  await onSave();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('SAVE CHANGES',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
      label: const Text('LOGOUT ACCOUNT',
          style:
              TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      onPressed: () async {
        await Supabase.instance.client.auth.signOut();
        await googleSignInInstance.signOut();
        Hive.box('settings').put('isLoggedIn', false);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        }
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        side: const BorderSide(color: Colors.redAccent, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

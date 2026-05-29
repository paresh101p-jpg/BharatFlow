import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bharat_flow/core/providers/auth_providers.dart';

class UserProfile {
  final String id;
  final String? userType;
  final DateTime? birthday;
  final int birthdayEditCount;
  final String? city;
  final String? language;
  final String? fullAddress;
  final String? mobileNo;
  final bool isSetupComplete;
  final DateTime? createdAt;
  final DateTime? addressUpdatedAt;
  final String? fullName;
  final String? avatarUrl;
  final String? email;

  UserProfile({
    required this.id,
    this.userType,
    this.birthday,
    this.birthdayEditCount = 0,
    this.city,
    this.language,
    this.fullAddress,
    this.mobileNo,
    this.isSetupComplete = false,
    this.createdAt,
    this.addressUpdatedAt,
    this.fullName,
    this.avatarUrl,
    this.email,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      userType: map['user_type'],
      birthday: map['birthday'] != null ? DateTime.parse(map['birthday']) : null,
      birthdayEditCount: map['birthday_edit_count'] ?? 0,
      city: map['city'],
      language: map['language'],
      fullAddress: map['full_address'],
      mobileNo: map['mobile_no'],
      isSetupComplete: map['is_setup_complete'] ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      addressUpdatedAt: map['address_updated_at'] != null ? DateTime.parse(map['address_updated_at']) : null,
      fullName: map['full_name'],
      avatarUrl: map['avatar_url'],
      email: map['email'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_type': userType,
      'birthday': birthday?.toIso8601String().split('T')[0],
      'birthday_edit_count': birthdayEditCount,
      'city': city,
      'language': language,
      'full_address': fullAddress,
      'mobile_no': mobileNo,
      'is_setup_complete': isSetupComplete,
      'address_updated_at': addressUpdatedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'email': email,
    };
  }

  // ✅ toMap without email — used for updates to avoid unique constraint
  Map<String, dynamic> toMapWithoutEmail() {
    return {
      'id': id,
      'user_type': userType,
      'birthday': birthday?.toIso8601String().split('T')[0],
      'birthday_edit_count': birthdayEditCount,
      'city': city,
      'language': language,
      'full_address': fullAddress,
      'mobile_no': mobileNo,
      'is_setup_complete': isSetupComplete,
      'address_updated_at': addressUpdatedAt?.toIso8601String(),
      'full_name': fullName,
      'avatar_url': avatarUrl,
    };
  }
}

class ProfileRepository {
  final _supabase = Supabase.instance.client;

  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
      if (response == null) return null;
      return UserProfile.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    try {
      final String id = profile.id;
      final data = profile.toMapWithoutEmail();

      // Priority 1: Update by ID
      final res = await _supabase.from('profiles').update(data).eq('id', id).select();
      
      if (res.isEmpty) {
        // Priority 2: Not found by ID? Insert new record (include email on first insert)
        await _supabase.from('profiles').insert(profile.toMap());
      }
      
      debugPrint('✅ Profile saved successfully for $id');
    } catch (e) {
      debugPrint('❌ Update Profile Error: $e');
      // Final attempt: Upsert by ID only
      try {
        final data = profile.toMapWithoutEmail();
        await _supabase.from('profiles').upsert(data, onConflict: 'id');
      } catch (e2) {
        debugPrint('❌ Critical Profile Save Failure: $e2');
        rethrow;
      }
    }
  }

  Future<void> completeSetup({
    required String userId,
    String? type,
    DateTime? birthday,
    String? city,
    String? language,
    String? fullAddress,
    String? mobileNo,
    String? email,
    String? fullName,
    String? avatarUrl,
  }) async {
    final auth = Supabase.instance.client.auth;
    final currentUser = auth.currentUser;
    final box = Hive.box('settings');

    final String? resolvedFullName = fullName ?? 
        currentUser?.userMetadata?['full_name'] ?? 
        currentUser?.userMetadata?['name'] ?? 
        box.get('userName');

    final String? resolvedAvatarUrl = avatarUrl ?? 
        currentUser?.userMetadata?['avatar_url'] ?? 
        currentUser?.userMetadata?['picture'] ?? 
        box.get('userPhoto');

    final profile = UserProfile(
      id: userId,
      userType: type,
      birthday: birthday,
      city: city,
      language: language,
      fullAddress: fullAddress,
      mobileNo: mobileNo,
      isSetupComplete: true,
      createdAt: DateTime.now(),
      email: email,
      fullName: resolvedFullName,
      avatarUrl: resolvedAvatarUrl,
    );
    await updateProfile(profile);
  }
}

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final auth = Supabase.instance.client.auth;
  var user = auth.currentUser;
  String? currentEmail;

  try {
    // ✅ Use the Singleton — avoid multiple GoogleSignIn instances
    final googleUser = await googleSignInInstance.signInSilently();
    currentEmail = googleUser?.email ?? user?.email;

    if (user == null && googleUser != null) {
      final googleAuth = await googleUser.authentication;
      final res = await auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      user = res.user;
    }
  } catch (_) {}

  try {
    final client = Supabase.instance.client;
    final box = Hive.box('settings');

    // PRIORITY 1: Fetch by Current Session ID (Most accurate)
    if (user != null) {
      final res = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .limit(1);
      if ((res as List).isNotEmpty) {
        final profile = UserProfile.fromMap(res.first);
        return UserProfile(
          id: profile.id,
          userType: profile.userType,
          birthday: profile.birthday,
          birthdayEditCount: profile.birthdayEditCount,
          city: profile.city,
          language: profile.language,
          fullAddress: profile.fullAddress,
          mobileNo: profile.mobileNo,
          isSetupComplete: profile.isSetupComplete,
          createdAt: profile.createdAt,
          addressUpdatedAt: profile.addressUpdatedAt,
          fullName: profile.fullName ?? user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? box.get('userName'),
          avatarUrl: profile.avatarUrl ?? user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'] ?? box.get('userPhoto'),
          email: profile.email ?? user.email ?? box.get('userEmail'),
        );
      }
    }

    // PRIORITY 2: Fetch by Email (Recovery)
    if (currentEmail != null) {
      final res = await client
          .from('profiles')
          .select()
          .eq('email', currentEmail)
          .order('is_setup_complete', ascending: false)
          .limit(1);
      if ((res as List).isNotEmpty) {
        final profile = UserProfile.fromMap(res.first);
        return UserProfile(
          id: profile.id,
          userType: profile.userType,
          birthday: profile.birthday,
          birthdayEditCount: profile.birthdayEditCount,
          city: profile.city,
          language: profile.language,
          fullAddress: profile.fullAddress,
          mobileNo: profile.mobileNo,
          isSetupComplete: profile.isSetupComplete,
          createdAt: profile.createdAt,
          addressUpdatedAt: profile.addressUpdatedAt,
          fullName: profile.fullName ?? user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'] ?? box.get('userName'),
          avatarUrl: profile.avatarUrl ?? user?.userMetadata?['avatar_url'] ?? user?.userMetadata?['picture'] ?? box.get('userPhoto'),
          email: profile.email ?? user?.email ?? currentEmail,
        );
      }
    }

    // Default: Empty profile
    if (user != null) {
      return UserProfile(
        id: user.id,
        fullName: user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? box.get('userName'),
        avatarUrl: user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'] ?? box.get('userPhoto'),
        email: user.email ?? box.get('userEmail'),
      );
    }
  } catch (e) {
    debugPrint('Profile Fetch Error: $e');
  }

  return null;
});
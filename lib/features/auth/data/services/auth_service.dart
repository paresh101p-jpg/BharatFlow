import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // 1. Google Login
  Future<AuthResponse> signInWithGoogle() async {
    // Note: Implementation requires google_sign_in package setup
    const webClientId = '277298612621-emnsgoefr2q8b0p3811fgd97jmm60l1v.apps.googleusercontent.com';
    const iosClientId = '277298612621-emnsgoefr2q8b0p3811fgd97jmm60l1v.apps.googleusercontent.com';

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
    );
    final googleUser = await googleSignIn.signIn();
    final googleAuth = await googleUser!.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) {
      throw 'No Access Token found.';
    }
    if (idToken == null) {
      throw 'No ID Token found.';
    }

    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // 2. GitHub Login
  Future<void> signInWithGitHub() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'com.bharatflow://login-callback',
    );
  }

  // 3. Magic Link
  Future<void> signInWithMagicLink(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'com.bharatflow://login-callback',
    );
  }

  // 4. Anonymous Mode
  Future<AuthResponse> signInAnonymously() async {
    return await _supabase.auth.signInAnonymously();
  }

  // 5. Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user profile
  User? get currentUser => _supabase.auth.currentUser;
  
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}

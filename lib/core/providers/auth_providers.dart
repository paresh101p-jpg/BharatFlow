import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ── Singleton ──────────────────────────────────────────────────────────────
// ONE instance shared across entire app.
// Creating new GoogleSignIn() every time = cached session lost = idToken null.
final googleSignInInstance = GoogleSignIn(
  serverClientId: '277298612621-emnsgoefr2q8b0p3811fgd97jmm60l1v.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);

// ── Provider ───────────────────────────────────────────────────────────────
final googleUserProvider = FutureProvider<GoogleSignInAccount?>((ref) async {
  try {
    // Already signed in
    final current = googleSignInInstance.currentUser;
    if (current != null) return current;

    // Restore cached session silently
    return await googleSignInInstance.signInSilently();
  } catch (e) {
    return null;
  }
});
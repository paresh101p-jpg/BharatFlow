import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bharat_flow/features/auth/presentation/screens/login_screen.dart';

import 'package:bharat_flow/features/auth/presentation/screens/permission_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          // User is logged in, now ask for permissions
          return const PermissionScreen();
        } else {
          // User is not logged in
          return const LoginScreen();
        }
      },
    );
  }
}

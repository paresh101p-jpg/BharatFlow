import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bharat_flow/core/theme/app_theme.dart';
import 'package:bharat_flow/features/dashboard/presentation/screens/dashboard_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    try {
      final locStatus = await Permission.location.status;
      final notifStatus = await Permission.notification.status;
      
      if (locStatus.isGranted && notifStatus.isGranted) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking existing permissions: $e");
      // Fallback: If anything fails, navigate to Dashboard to avoid black screen
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    }
  }

  bool _isRequesting = false;

  Future<void> _requestPermissions() async {
    if (!context.mounted) return;
    setState(() => _isRequesting = true);
    
    try {
      // Request Location, Notifications, Camera, and Microphone
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.notification,
        Permission.camera,
        Permission.microphone,
      ].request();

      final locGranted = statuses[Permission.location]?.isGranted ?? false;

      if (locGranted) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is needed for Mandi & Weather data.')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error requesting permissions: $e");
      // Fallback: Navigate to Dashboard to avoid black screen if permission channels throw exceptions
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } finally {
      if (context.mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(color: Colors.black),
          Center(
            child: GlassmorphicContainer(
              width: 340,
              height: 500,
              borderRadius: 30,
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
              ),
              borderGradient: LinearGradient(
                colors: [AppTheme.primaryColor.withOpacity(0.5), Colors.white24],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 80, color: Colors.blueAccent),
                    const SizedBox(height: 24),
                    Text(
                      'Izazat Chahiye',
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'BharatFlow ko aapki Location ki zaroorat hai taaki hum:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    _PermissionReason(icon: Icons.cloud, text: 'Local weather & rain alerts'),
                    _PermissionReason(icon: Icons.agriculture, text: 'Live Mandi prices nearby'),
                    _PermissionReason(icon: Icons.mic, text: 'Voice AI Market Assistant'),
                    _PermissionReason(icon: Icons.camera_alt, text: 'Scan bills & crop health'),
                    const SizedBox(height: 40),
                    if (_isRequesting)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _requestPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('Allow Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionReason extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PermissionReason({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }
}

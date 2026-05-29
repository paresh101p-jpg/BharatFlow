import 'package:in_app_update/in_app_update.dart';
import 'package:flutter/material.dart';

class UpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      debugPrint('UpdateService: Checking for available app updates...');
      final info = await InAppUpdate.checkForUpdate()
          .timeout(const Duration(seconds: 4));

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint(
            'UpdateService: A new update is available! Version Code: ${info.availableVersionCode}');

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _InAppUpdateDialog(updateInfo: info),
          );
        }
      } else {
        debugPrint('UpdateService: App is up to date.');
      }
    } catch (e) {
      debugPrint('UpdateService: In-app updates not supported or failed: $e');
    }
  }
}

class _InAppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  const _InAppUpdateDialog({required this.updateInfo});

  @override
  State<_InAppUpdateDialog> createState() => _InAppUpdateDialogState();
}

class _InAppUpdateDialogState extends State<_InAppUpdateDialog> {
  bool _updating = false;
  String _statusText = "New Update Available! 🚀";

  Future<void> _startUpdate() async {
    setState(() {
      _updating = true;
      _statusText = "Downloading update... 📥";
    });

    try {
      if (widget.updateInfo.immediateUpdateAllowed) {
        // Immediate Update: Forces user to wait
        await InAppUpdate.performImmediateUpdate();
      } else if (widget.updateInfo.flexibleUpdateAllowed) {
        // Flexible Update: Download
        await InAppUpdate.startFlexibleUpdate();

        setState(() {
          _statusText = "Installing update... ⚙️";
        });

        // Complete the flexible update
        await InAppUpdate.completeFlexibleUpdate();
      } else {
        // Fallback: If neither allowed but updateAvailable, try immediate
        await InAppUpdate.performImmediateUpdate();
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updating = false;
          _statusText = "Update failed. Please try again! ❌";
        });
      }
      debugPrint('UpdateService: Failed to perform update: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Slate
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: Colors.greenAccent,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              _statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            const Text(
              "A newer version of BharatFlow is available. Update now to get the latest features, security enhancements, and improvements directly inside the app!",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (_updating) ...[
              // Progress Loader
              const LinearProgressIndicator(
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please do not close the app...",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ] else ...[
              // Action Buttons
              Row(
                children: [
                  // Cancel / Later
                  if (!widget.updateInfo.immediateUpdateAllowed)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Later",
                          style: TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Update Now Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Update Now",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

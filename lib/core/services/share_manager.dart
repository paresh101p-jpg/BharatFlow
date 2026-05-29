import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'admob_service.dart';

class ShareManager {
  /// Custom dynamic text sharing gateway with 24-hour AdMob unlock security
  static Future<void> share(BuildContext context, String text, {String? subject}) async {
    await _executeWithAdCheck(context, () {
      Share.share(text, subject: subject);
    });
  }

  /// Custom dynamic file sharing gateway with 24-hour AdMob unlock security
  static Future<void> shareXFiles(BuildContext context, List<XFile> files, {String? text, String? subject}) async {
    await _executeWithAdCheck(context, () {
      Share.shareXFiles(files, text: text, subject: subject);
    });
  }

  /// Master execution controller that handles Hive state parsing and Ad completion
  static Future<void> _executeWithAdCheck(BuildContext context, VoidCallback onGranted) async {
    try {
      final box = Hive.box('settings');
      final lastUnlockStr = box.get('last_share_unlock_time');
      bool isUnlocked = false;

      if (lastUnlockStr != null) {
        final lastUnlock = DateTime.parse(lastUnlockStr);
        final difference = DateTime.now().difference(lastUnlock);
        if (difference.inHours < 24 && difference.inHours >= 0) {
          isUnlocked = true;
        }
      }

      if (isUnlocked) {
        // Safe direct execution - 24 hours lock is active and free!
        onGranted();
      } else {
        // Show our beautiful NAMASTE dialog first!
        AdmobService.showRewardConfirmationDialog(context, () {
          try {
            box.put('last_share_unlock_time', DateTime.now().toIso8601String());
          } catch (_) {}
          onGranted(); // Fire the actual share intent!
        });
      }
    } catch (e) {
      // Safe fallback: if anything fails (like Hive box not open or thread isolate error),
      // directly fire the share intent so kisan is NEVER stuck or experiencing crashes.
      onGranted();
    }
  }
}

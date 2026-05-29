import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AdBlockerService {
  static const MethodChannel _channel = MethodChannel('com.bharatflow.app/adblock_dns');

  /// Domains typically blocked by ad-blocking DNS / host lists
  static const List<String> _adDomains = [
    'googleads.g.doubleclick.net',
    'pagead2.googlesyndication.com',
    'adservice.google.com',
    'securepubads.g.doubleclick.net',
    'dns.adguard.com',
  ];

  /// Core method to check if Private DNS or an Ad Blocker is active (Optimized for zero false positives)
  static Future<bool> isAdBlockerOrPrivateDnsActive() async {
    // 1. Check Connectivity First (Don't block offline users with ad-block warning)
    final isOnline = await _checkBasicConnectivity();
    if (!isOnline) {
      debugPrint('📶 [ADBLOCK] Device is offline. Skipping adblock detection.');
      return false;
    }

    // 2. Run Checks Concurrently for Speed and High Reliability
    final results = await Future.wait([
      _checkNativePrivateDns(),
      _checkDartDnsResolution(),
    ]);

    final nativeDnsActive = results[0];
    final dartDnsBlocked = results[1];

    debugPrint('🛡️ [ADBLOCK DIAGNOSTICS] Native: $nativeDnsActive | Dart DNS: $dartDnsBlocked');

    // If active on the OS Private DNS level or multiple ad servers fail with SocketException
    return nativeDnsActive || dartDnsBlocked;
  }

  /// Launch the device settings directly into the Private DNS section (Android only)
  static Future<void> openPrivateDnsSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openPrivateDnsSettings');
    } catch (e) {
      debugPrint('⚠️ [ADBLOCK] Failed to open Private DNS settings: $e');
    }
  }

  /// Check basic internet reachability using clean, standard servers
  static Future<bool> _checkBasicConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final fallback = await InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(seconds: 2));
        return fallback.isNotEmpty && fallback.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// Layer 1: Query Android OS LinkProperties and Global Settings
  /// Optimized to avoid cached values from the Settings.Global database when Private DNS is currently disabled.
  static Future<bool> _checkNativePrivateDns() async {
    if (!Platform.isAndroid) return false;

    try {
      final Map? dnsInfo = await _channel.invokeMapMethod('getPrivateDnsInfo');
      if (dnsInfo == null) return false;

      final bool isPrivateDnsActive = dnsInfo['isPrivateDnsActive'] == true;
      final String? serverName = dnsInfo['privateDnsServerName'] as String?;

      debugPrint('📱 [ADBLOCK NATIVE] active=$isPrivateDnsActive, server=$serverName');

      // CRITICAL FIX: Only check the hostname if Private DNS is ACTUALLY active at the network link level.
      // Settings.Global values like 'private_dns_specifier' persist in the DB even when Private DNS is turned OFF!
      if (isPrivateDnsActive) {
        if (serverName != null) {
          final serverLower = serverName.toLowerCase();
          final List<String> adBlockProviders = ['adguard', 'nextdns', 'block', 'dns.dns', 'anti-ad', 'dns.adg'];
          if (adBlockProviders.any((prov) => serverLower.contains(prov))) {
            return true;
          }
        } else {
          // If Private DNS is reported active but serverName is null, it means it is active in Automatic mode.
          // Automatic mode does not use AdGuard / custom host blocks unless set by hostname, so we don't flag it.
          return false;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ADBLOCK NATIVE] MethodChannel check error: $e');
    }

    return false;
  }

  /// Layer 2: Resolve standard AdMob/AdGuard domains using Dart's DNS lookup
  /// Optimized: Only flags a domain if it throws a SocketException (resolution blocked)
  /// or resolves to local loopback. Completely ignores TimeoutExceptions to prevent
  /// false positives on slow/rural internet connections.
  static Future<bool> _checkDartDnsResolution() async {
    int blockedCount = 0;

    for (final domain in _adDomains) {
      try {
        final addresses = await InternetAddress.lookup(domain)
            .timeout(const Duration(milliseconds: 1500));

        if (addresses.isEmpty) {
          blockedCount++;
          continue;
        }

        // Check if resolved to local loopback (common for DNS sinkholes like Pi-hole)
        for (final addr in addresses) {
          final ip = addr.address;
          if (ip == '127.0.0.1' || ip == '0.0.0.0' || ip == '::1') {
            blockedCount++;
            break;
          }
        }
      } on SocketException catch (e) {
        // SocketException (Host not found / lookup failed) is the standard behavior when blocked
        debugPrint('🔌 [ADBLOCK DNS RESOLUTION] Domain blocked ($domain): $e');
        blockedCount++;
      } catch (e) {
        // Ignore TimeoutException and other general connection errors.
        // If a request times out, it is likely due to slow latency, not active blocking.
        debugPrint('🔌 [ADBLOCK DNS RESOLUTION] Domain lookup timeout or slow network ($domain): $e');
      }
    }

    // If 2 or more standard advertising domains are blocked/unresolved, we flag it
    return blockedCount >= 2;
  }
}

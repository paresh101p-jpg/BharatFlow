import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'config_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bharat_flow/core/providers/settings_provider.dart';

class AdmobService {
  /// Initialize Google Mobile Ads SDK
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      debugPrint('📢 [ADMOB] Google Mobile Ads SDK Initialized.');
    } catch (e) {
      debugPrint('⚠️ [ADMOB] AdMob SDK Initialization failed: $e');
    }
  }

  /// Check if banner ads are configured in remote configuration
  static bool get hasBannerAd {
    if (!ConfigService.hasKey('admob_banner_ad_id')) return false;
    final val = ConfigService.get('admob_banner_ad_id');
    return val.isNotEmpty &&
        val.toLowerCase() != 'none' &&
        val.toLowerCase() != 'disabled';
  }

  /// Check if rewarded video ads are configured in remote configuration
  static bool get hasRewardedAd {
    if (!ConfigService.hasKey('admob_rewarded_ad_id')) return false;
    final val = ConfigService.get('admob_rewarded_ad_id');
    return val.isNotEmpty &&
        val.toLowerCase() != 'none' &&
        val.toLowerCase() != 'disabled';
  }

  /// Dynamic Ad Unit ID Getter for Banner Ads
  static String get bannerAdUnitId {
    return ConfigService.get(
      'admob_banner_ad_id',
      defaultValue: 'ca-app-pub-4064462736581300/8496961361',
    );
  }

  /// Dynamic Ad Unit ID Getter for Interstitial Ads
  static String get interstitialAdUnitId {
    return ConfigService.get(
      'admob_interstitial_ad_id',
      defaultValue: 'ca-app-pub-4064462736581300/1666313762',
    );
  }

  /// Dynamic Ad Unit ID Getter for Rewarded Video Ads
  static String get rewardedAdUnitId {
    return ConfigService.get(
      'admob_rewarded_ad_id',
      defaultValue: 'ca-app-pub-4064462736581300/7273863668',
    );
  }

  /// Static Helper to Load and Show an Interstitial Ad dynamically
  static void showInterstitialAd(VoidCallback onAdClosed) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ [ADMOB] Interstitial Ad loaded.');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onAdClosed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onAdClosed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ [ADMOB] Interstitial Ad failed: $error');
          onAdClosed();
        },
      ),
    );
  }

  /// Static Helper to Load and Show a Rewarded Video Ad
  static void showRewardedAd(BuildContext context, VoidCallback onRewarded) {
    bool hasResponded = false;

    // Show a high-fidelity visual loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false, // Prevent dismissing loader manually
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1B5E20)),
                SizedBox(height: 16),
                Text(
                  'Loading video ad...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final t = ProviderScope.containerOf(context).read(translationsProvider);

    // Set a safety timeout of 20 seconds to prevent getting stuck forever
    Future.delayed(const Duration(seconds: 20), () {
      if (!hasResponded) {
        hasResponded = true;
        if (context.mounted) {
          try {
            Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog safely
          } catch (_) {}
          
          debugPrint('⏳ [ADMOB] Rewarded Ad load timeout. Granting direct fallback access.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t['ad_not_available'] ?? 'Video ad not available. Direct access granted!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        onRewarded(); // Fallback: grant direct sharing access so kisan is never stuck
      }
    });

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (hasResponded) {
            ad.dispose();
            return;
          }
          hasResponded = true;
          if (context.mounted) {
            try {
              Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog
            } catch (_) {}

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(t['ad_display_failed'] ??
                          'Video could not be displayed. Please try again!')),
                );
              },
            );

            ad.show(
              onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
                debugPrint('🎉 [ADMOB] User successfully earned reward!');
                onRewarded();
              },
            );
          } else {
            ad.dispose();
            onRewarded();
          }
        },
        onAdFailedToLoad: (error) {
          if (hasResponded) return;
          hasResponded = true;
          if (context.mounted) {
            try {
              Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog
            } catch (_) {}

            debugPrint('❌ [ADMOB] Rewarded Ad failed to load: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(t['ad_not_available'] ??
                      'Video ad not available. Direct access granted!')),
            );
          }
          onRewarded(); // Fallback: grant direct sharing access if ad fails to load so user is never stuck
        },
      ),
    );
  }

  /// Show a beautiful, premium visual confirmation dialog to kisan before playing Rewarded Ad
  static void showRewardConfirmationDialog(
      BuildContext parentContext, VoidCallback onAdCompleted) {
    showDialog(
      context: parentContext,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Consumer(
            builder: (consumerContext, ref, _) {
              final t = ref.watch(translationsProvider);

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withOpacity(0.04),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium glowing Namaste folded hands image
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/namaste_folded_hands.png',
                          height: 95,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              '🙏',
                              style: TextStyle(
                                fontSize: 48,
                                decoration: TextDecoration.none,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t['support_needed'] ?? '🌾 Your Support is Needed!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t['support_desc'] ??
                          'To keep BharatFlow free forever, please watch this short video just once in 24 hours before sharing. We hope you will support us. Thank you!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Watch Ad Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // Close info popup
                        showRewardedAd(parentContext, onAdCompleted); // Start ad flow
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_filled_rounded,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            t['watch_and_share'] ?? '🎬 Watch Video and Share',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Cancel/Close Text Button
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      child: Text(
                        t['cancel_maybe_later'] ?? '❌ Cancel / Maybe Later',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// A premium, plug-and-play Banner Ad Widget that handles dynamic loading gracefully
class DynamicBannerAdWidget extends StatefulWidget {
  const DynamicBannerAdWidget({super.key});

  @override
  State<DynamicBannerAdWidget> createState() => _DynamicBannerAdWidgetState();
}

class _DynamicBannerAdWidgetState extends State<DynamicBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdmobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ [ADMOB] Banner Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdmobService.hasBannerAd) {
      return const SizedBox.shrink();
    }
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// A premium, inline list ad widget styled exactly like the surrounding commodity cards
class DynamicAdmobCardWidget extends StatefulWidget {
  const DynamicAdmobCardWidget({super.key});

  @override
  State<DynamicAdmobCardWidget> createState() => _DynamicAdmobCardWidgetState();
}

class _DynamicAdmobCardWidgetState extends State<DynamicAdmobCardWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdmobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ [ADMOB] Card Banner Ad failed: $error');
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdmobService.hasBannerAd) {
      return const SizedBox.shrink();
    }
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side: icon looking like commodity image
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '📢',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Middle & Right: Sponsored headline + centered banner ad
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sponsored Advertisement',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AD',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: SizedBox(
                    height: _bannerAd!.size.height.toDouble(),
                    width: _bannerAd!.size.width.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A premium, inline list ad widget styled exactly like the surrounding green mandi cards
class DynamicAdmobGreenCardWidget extends StatefulWidget {
  const DynamicAdmobGreenCardWidget({super.key});

  @override
  State<DynamicAdmobGreenCardWidget> createState() =>
      _DynamicAdmobGreenCardWidgetState();
}

class _DynamicAdmobGreenCardWidgetState
    extends State<DynamicAdmobGreenCardWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdmobService.bannerAdUnitId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ [ADMOB] Green Card Banner Ad failed: $error');
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdmobService.hasBannerAd) {
      return const SizedBox.shrink();
    }
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D40).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Sponsored Advertisement',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AD',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        ],
      ),
    );
  }
}

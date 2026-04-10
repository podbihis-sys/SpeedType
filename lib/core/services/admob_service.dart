import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'premium_service.dart';

/// Types of rewards users can earn from watching rewarded ads.
enum RewardType {
  streakFreeze,
  doubleXp,
  dailyRetry,
  themeUnlock,
}

/// Result of showing a rewarded ad.
class RewardResult {
  final bool isEarned;
  final bool isDismissed;
  final bool isNotReady;
  final RewardType rewardType;
  final int amount;

  const RewardResult._({
    required this.isEarned,
    required this.isDismissed,
    required this.isNotReady,
    required this.rewardType,
    this.amount = 0,
  });

  factory RewardResult.earned(RewardType rewardType, {int amount = 1}) {
    return RewardResult._(
      isEarned: true,
      isDismissed: false,
      isNotReady: false,
      rewardType: rewardType,
      amount: amount,
    );
  }

  factory RewardResult.dismissed(RewardType rewardType) {
    return RewardResult._(
      isEarned: false,
      isDismissed: true,
      isNotReady: false,
      rewardType: rewardType,
    );
  }

  factory RewardResult.notReady(RewardType rewardType) {
    return RewardResult._(
      isEarned: false,
      isDismissed: false,
      isNotReady: true,
      rewardType: rewardType,
    );
  }
}

/// Singleton service that manages AdMob integration for the app.
///
/// Handles GDPR UMP consent, banner ads, interstitial ads and rewarded ads.
/// Premium users never see ads. In debug/test builds the Google test ad unit
/// ids are used to avoid invalid traffic on production units.
class AdMobService {
  AdMobService._internal();
  static final AdMobService _instance = AdMobService._internal();
  static AdMobService get instance => _instance;
  factory AdMobService() => _instance;

  /// Toggle this to `false` for production ad units.
  static const bool _isTest = true;

  // Ad instances
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // Interstitial frequency capping - show every 3rd completed test
  int _testCount = 0;

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize AdMob: request GDPR UMP consent, initialize MobileAds SDK
  /// and preload the first interstitial + rewarded ad.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _requestConsentInfo();
    } catch (e) {
      debugPrint('AdMobService: consent request failed: $e');
    }

    try {
      await MobileAds.instance.initialize();

      // In test mode, register common emulator/simulator hashes.
      if (_isTest) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: <String>['EMULATOR'],
          ),
        );
      }
    } catch (e) {
      debugPrint('AdMobService: MobileAds init failed: $e');
    }

    _initialized = true;

    // Warm up cached ads.
    _loadInterstitial();
    _loadRewarded();
  }

  /// Request GDPR / UMP consent information before loading any ads.
  Future<void> _requestConsentInfo() async {
    final params = ConsentRequestParameters(
      consentDebugSettings: _isTest
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
            )
          : null,
    );

    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          final isFormAvailable =
              await ConsentInformation.instance.isConsentFormAvailable();
          if (isFormAvailable) {
            await _loadConsentForm();
          }
        } catch (e) {
          debugPrint('AdMobService: consent form load failed: $e');
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError error) {
        debugPrint(
            'AdMobService: consent info update error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  Future<void> _loadConsentForm() async {
    final completer = Completer<void>();
    ConsentForm.loadConsentForm(
      (ConsentForm form) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          form.show((FormError? error) {
            if (error != null) {
              debugPrint('AdMobService: consent form show error: '
                  '${error.message}');
            }
            if (!completer.isCompleted) completer.complete();
          });
        } else {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError error) {
        debugPrint('AdMobService: load consent form error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Banner Ads
  // ---------------------------------------------------------------------------

  /// Creates a new banner ad instance configured for the standard banner size.
  /// The caller is responsible for disposing the returned instance.
  BannerAd createBannerAd() {
    final banner = BannerAd(
      adUnitId: _getBannerAdUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdMobService: banner loaded');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMobService: banner failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    );
    banner.load();
    _bannerAd = banner;
    return banner;
  }

  // ---------------------------------------------------------------------------
  // Interstitial Ads
  // ---------------------------------------------------------------------------

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _getInterstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('AdMobService: interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          debugPrint('AdMobService: interstitial failed: ${error.message}');
        },
      ),
    );
  }

  /// Shows an interstitial ad after a completed typing test if frequency
  /// and premium rules allow it.
  ///
  /// * Daily challenge results never trigger an interstitial.
  /// * Premium users never see ads.
  /// * Non-premium users see an ad only on every 3rd completed test.
  /// * A 2 second delay gives the result screen time to settle first.
  Future<void> showInterstitialIfReady({required bool isDailyChallenge}) async {
    if (isDailyChallenge) return;

    if (PremiumService.instance.isPremium) return;

    _testCount++;
    if (_testCount % 3 != 0) return;

    if (_interstitialAd == null) {
      _loadInterstitial();
      return;
    }

    await Future.delayed(const Duration(seconds: 2));

    final ad = _interstitialAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint(
            'AdMobService: interstitial show failed: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );

    await ad.show();
    _interstitialAd = null;
  }

  // ---------------------------------------------------------------------------
  // Rewarded Ads
  // ---------------------------------------------------------------------------

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _getRewardedAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('AdMobService: rewarded loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          debugPrint('AdMobService: rewarded failed: ${error.message}');
        },
      ),
    );
  }

  /// Shows a rewarded ad for the given [rewardType].
  ///
  /// Returns a [RewardResult] describing whether the user earned the reward,
  /// dismissed the ad, or whether no ad was ready to be shown.
  Future<RewardResult> showRewardedAd(RewardType rewardType) async {
    if (_rewardedAd == null) {
      _loadRewarded();
      return RewardResult.notReady(rewardType);
    }

    final completer = Completer<RewardResult>();
    bool earned = false;

    final ad = _rewardedAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) {
          completer.complete(
            earned
                ? RewardResult.earned(rewardType)
                : RewardResult.dismissed(rewardType),
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMobService: rewarded show failed: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) {
          completer.complete(RewardResult.notReady(rewardType));
        }
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );
    _rewardedAd = null;

    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Ad Unit IDs
  // ---------------------------------------------------------------------------

  String _getBannerAdUnitId() {
    if (_isTest) {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-0000000000000000/0000000000';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-0000000000000000/0000000000';
    }
    return 'ca-app-pub-3940256099942544/6300978111';
  }

  String _getInterstitialAdUnitId() {
    if (_isTest) {
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-0000000000000000/0000000000';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-0000000000000000/0000000000';
    }
    return 'ca-app-pub-3940256099942544/1033173712';
  }

  String _getRewardedAdUnitId() {
    if (_isTest) {
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-0000000000000000/0000000000';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-0000000000000000/0000000000';
    }
    return 'ca-app-pub-3940256099942544/5224354917';
  }

  /// Dispose cached ads - called on app shutdown.
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _bannerAd = null;
    _interstitialAd = null;
    _rewardedAd = null;
  }
}

// ---------------------------------------------------------------------------
// BannerAdWidget
// ---------------------------------------------------------------------------

/// A reusable widget that loads and displays a banner ad.
///
/// The widget hides itself entirely if the user is a premium subscriber or if
/// the banner fails to load. It handles its own ad lifecycle, creating the
/// banner in [initState] and disposing it in [dispose].
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _createBanner();
  }

  void _createBanner() {
    if (PremiumService.instance.isPremium) return;

    _bannerAd = BannerAd(
      adUnitId: AdMobService.instance._getBannerAdUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAdWidget: failed to load: ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PremiumService.instance.isPremium) {
      return const SizedBox.shrink();
    }
    if (!_loaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

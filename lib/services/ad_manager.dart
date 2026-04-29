import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  // TODO: Replace with your actual ad unit IDs
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test ID for Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Test ID for iOS
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test ID for Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // Test ID for iOS
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Test ID for Android
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test ID for iOS
    }
    throw UnsupportedError('Unsupported platform');
  }

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int _numInterstitialLoadAttempts = 0;
  int _numRewardedLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    await MobileAds.instance.initialize();
    _isInitialized = true;
    debugPrint('AdMob SDK initialized');
  }

  /// Create a banner ad
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => debugPrint('Banner ad loaded'),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed to load: $error');
        },
      ),
    );
  }

  /// Load an interstitial ad
  Future<void> loadInterstitialAd() async {
    if (_numInterstitialLoadAttempts >= maxFailedLoadAttempts) {
      return;
    }

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _numInterstitialLoadAttempts = 0;
          },
          onAdFailedToLoad: (error) {
            _numInterstitialLoadAttempts++;
            _interstitialAd = null;
            debugPrint('Interstitial ad failed to load: $error');
          },
        ),
      );
    } catch (e) {
      debugPrint('Error loading interstitial ad: $e');
    }
  }

  /// Show the interstitial ad if it's ready
  Future<void> showInterstitialAd() async {
    if (_interstitialAd == null) {
      debugPrint('Interstitial ad not ready');
      return;
    }

    try {
      await _interstitialAd!.show();
    } catch (e) {
      debugPrint('Error showing interstitial ad: $e');
    } finally {
      _interstitialAd = null;
      loadInterstitialAd(); // Load the next ad
    }
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (_numRewardedLoadAttempts >= maxFailedLoadAttempts) {
      return;
    }

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _numRewardedLoadAttempts = 0;
          },
          onAdFailedToLoad: (error) {
            _numRewardedLoadAttempts++;
            _rewardedAd = null;
            debugPrint('Rewarded ad failed to load: $error');
          },
        ),
      );
    } catch (e) {
      debugPrint('Error loading rewarded ad: $e');
    }
  }

  /// Show the rewarded ad if it's ready
  Future<void> showRewardedAd({
    required Function(RewardItem reward) onRewarded,
  }) async {
    if (_rewardedAd == null) {
      debugPrint('Rewarded ad not ready');
      return;
    }

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (_, reward) => onRewarded(reward),
      );
    } catch (e) {
      debugPrint('Error showing rewarded ad: $e');
    } finally {
      _rewardedAd = null;
      loadRewardedAd(); // Load the next ad
    }
  }

  /// Dispose of any active ads
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
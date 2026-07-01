/// Ad Manager - Stub implementation
class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  Future<void> initialize() async {}
  Future<void> showInterstitialAd() async {}
  Future<void> showRewardedAd({
    required Function(dynamic) onEarnedReward,
    required Function() onAdClosed,
  }) async {}
  void dispose() {}
}

final adManager = AdManager();

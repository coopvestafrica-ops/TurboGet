/// Best Downloader Service - Stub implementation
class BestDownloaderService {
  static final BestDownloaderService _instance = BestDownloaderService._internal();
  factory BestDownloaderService() => _instance;
  BestDownloaderService._internal();

  Future<void> initialize() async {}
}

final bestDownloader = BestDownloaderService();

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OverlayService {
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  OverlayEntry? _progressOverlay;
  bool _isVisible = false;

  Future<bool> requestOverlayPermission() async {
    // Request SYSTEM_ALERT_WINDOW permission
    // This needs to be implemented using platform-specific code
    const platform = MethodChannel('com.example.turboget/overlay');
    try {
      final bool hasPermission = await platform.invokeMethod('requestOverlayPermission');
      return hasPermission;
    } catch (e) {
      print('Failed to get overlay permission: $e');
      return false;
    }
  }

  void showDownloadProgress({
    required String filename,
    required double progress,
    required String speed,
    required String timeRemaining,
  }) {
    if (!_isVisible) {
      _createOverlay(
        filename: filename,
        progress: progress,
        speed: speed,
        timeRemaining: timeRemaining,
      );
      _isVisible = true;
    } else {
      _updateOverlay(
        filename: filename,
        progress: progress,
        speed: speed,
        timeRemaining: timeRemaining,
      );
    }
  }

  void _createOverlay({
    required String filename,
    required double progress,
    required String speed,
    required String timeRemaining,
  }) {
    _progressOverlay = OverlayEntry(
      builder: (context) => _DownloadOverlay(
        filename: filename,
        progress: progress,
        speed: speed,
        timeRemaining: timeRemaining,
        onClose: hideDownloadProgress,
      ),
    );
  }

  void _updateOverlay({
    required String filename,
    required double progress,
    required String speed,
    required String timeRemaining,
  }) {
    _progressOverlay?.markNeedsBuild();
  }

  void hideDownloadProgress() {
    _progressOverlay?.remove();
    _progressOverlay = null;
    _isVisible = false;
  }
}

class _DownloadOverlay extends StatelessWidget {
  final String filename;
  final double progress;
  final String speed;
  final String timeRemaining;
  final VoidCallback onClose;

  const _DownloadOverlay({
    required this.filename,
    required this.progress,
    required this.speed,
    required this.timeRemaining,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      filename,
                      style: TextStyle(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation(Colors.blue),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    speed,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                timeRemaining,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

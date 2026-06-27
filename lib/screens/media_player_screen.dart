import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';

/// Professional media player screen
class MediaPlayerScreen extends StatefulWidget {
  final String filePath;
  final bool isAudio;

  const MediaPlayerScreen({
    super.key,
    required this.filePath,
    this.isAudio = false,
  });

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFullscreen = false;
  double _currentSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _hasError = true;
          _errorMessage = 'File not found';
        });
        return;
      }

      if (widget.isAudio) {
        // For audio files, we don't need video player
        setState(() => _isInitialized = true);
        return;
      }

      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _changeSpeed(double speed) {
    setState(() => _currentSpeed = speed);
    _videoController?.setPlaybackSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final filename = widget.filePath.split('/').last;
    final theme = Theme.of(context);

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: Text(filename),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load video',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = '';
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: Text(
                filename,
                style: const TextStyle(fontSize: 14),
              ),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              actions: [
                if (_isInitialized && !widget.isAudio)
                  PopupMenuButton<double>(
                    icon: const Icon(Icons.speed),
                    tooltip: 'Playback Speed',
                    onSelected: _changeSpeed,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                      const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                      const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                      const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                    ],
                  ),
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _toggleFullscreen,
                  tooltip: 'Fullscreen',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    // Handle share, info, etc.
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'info',
                      child: ListTile(
                        leading: Icon(Icons.info),
                        title: Text('File Info'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: widget.isAudio ? _buildAudioPlayer() : _buildVideoPlayer(),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized || _chewieController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleFullscreen,
      child: Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Chewie(controller: _chewieController!),
                if (_currentSpeed != 1.0)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentSpeed}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Album art / icon
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Icon(
                Icons.music_note,
                size: 120,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            // Track info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    widget.filePath.split('/').last,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unknown Artist',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Progress bar (placeholder)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Theme.of(context).colorScheme.primary,
                      overlayColor:
                          Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: 0,
                      onChanged: (value) {},
                    ),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0:00', style: TextStyle(color: Colors.white70)),
                      Text('--:--', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 48),
                  color: Colors.white,
                  onPressed: () {},
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow, size: 64),
                    color: Colors.white,
                    onPressed: () {},
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 48),
                  color: Colors.white,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

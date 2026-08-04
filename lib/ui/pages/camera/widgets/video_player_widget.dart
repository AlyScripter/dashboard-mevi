import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
/// Widget for playing local video files as dummy camera in rosbag mode
class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  final BoxFit fit;
  final bool showControls;
  final bool autoPlay;
  final bool loop;

  const VideoPlayerWidget({
    super.key,
    required this.videoPath,
    this.fit = BoxFit.contain,
    this.showControls = true,
    this.autoPlay = true,
    this.loop = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    // Dispose old controller
    await _controller?.dispose();

    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = '';
    });

    if (widget.videoPath.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No video file selected';
      });
      return;
    }

    final file = File(widget.videoPath);
    if (!await file.exists()) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video file not found:\n${widget.videoPath}';
      });
      return;
    }

    try {
      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();

      _controller!.setLooping(widget.loop);

      if (widget.autoPlay) {
        _controller!.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Listen for playback completion
      _controller!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or placeholder
          _buildVideoContent(),

          // Controls overlay
          if (widget.showControls && _isInitialized) _buildControls(),

          // Badge
          Positioned(
            top: 12,
            left: 12,
            child: _buildBadge(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.videoOff,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initializePlayer,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildControls() {
    final isPlaying = _controller?.value.isPlaying ?? false;
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble(),
                min: 0,
                max: duration.inMilliseconds
                    .toDouble()
                    .clamp(1, double.infinity),
                activeColor: Colors.blue.shade400,
                inactiveColor: Colors.white24,
                onChanged: (value) {
                  _controller?.seekTo(Duration(milliseconds: value.toInt()));
                },
              ),
            ),

            // Controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time display
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),

                // Play/Pause button
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isPlaying ? LucideIcons.pause : LucideIcons.play,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          _controller?.pause();
                        } else {
                          _controller?.play();
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        LucideIcons.rotateCcw,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        _controller?.seekTo(Duration.zero);
                        _controller?.play();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.shade600,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.video,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          const Text(
            'Video Playback',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

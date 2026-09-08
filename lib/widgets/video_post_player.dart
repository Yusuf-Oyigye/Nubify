import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPostPlayer extends StatefulWidget {
  final String videoUrl;

  const VideoPostPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoPostPlayer> createState() =>
      _VideoPostPlayerState();
}

class _VideoPostPlayerState
    extends State<VideoPostPlayer> {
  late VideoPlayerController _controller;

  bool _isInitialized = false;
  bool _isMuted = false;
  bool _showPlayIcon = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  // ============================================================
  // INITIALIZE VIDEO
  // ============================================================

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    try {
      await _controller.initialize();

      _controller.setLooping(true);

      // START AUTOMATICALLY
      await _controller.play();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitialized = false;
      });
    }
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  void _togglePlayPause() {
    if (!_controller.value.isInitialized) {
      return;
    }

    if (_controller.value.isPlaying) {
      _controller.pause();

      setState(() {
        _showPlayIcon = true;
      });
    } else {
      _controller.play();

      setState(() {
        _showPlayIcon = false;
      });
    }
  }

  // ============================================================
  // MUTE / UNMUTE
  // ============================================================

  void _toggleMute() {
    if (!_controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isMuted = !_isMuted;
    });

    _controller.setVolume(
      _isMuted ? 0 : 1,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        width: double.infinity,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ======================================================
          // VIDEO
          // ======================================================

          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(
                  _controller,
                ),
              ),
            ),
          ),

          // ======================================================
          // PLAY ICON WHEN PAUSED
          // ======================================================

          if (_showPlayIcon)
            Container(
              width: 65,
              height: 65,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),

          // ======================================================
          // MUTE BUTTON
          // ======================================================

          Positioned(
            right: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted
                      ? Icons.volume_off
                      : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
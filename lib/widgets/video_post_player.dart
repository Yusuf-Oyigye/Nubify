import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/media_route_observer.dart';

class VideoPostPlayer extends StatefulWidget {
  final String videoUrl;

  //============================
  // STORY VIDEO CONTROL
  //============================

  final bool loop;

  final bool forcePaused;

  final ValueChanged<double>? onProgressChanged;

  final VoidCallback? onCompleted;
  final VoidCallback? onReady;

  const VideoPostPlayer({
    super.key,
    required this.videoUrl,
    this.loop = true,
    this.forcePaused = false,
    this.onProgressChanged,
    this.onCompleted,
    this.onReady,
  });

  @override
  State<VideoPostPlayer> createState() => _VideoPostPlayerState();
}

class _VideoPostPlayerState extends State<VideoPostPlayer> with RouteAware {
  late VideoPlayerController _controller;

  ModalRoute<dynamic>? _route;

  bool _routeIsCovered = false;

  bool _resumeWhenRouteIsVisible = false;

  bool _resumeWhenExternalPauseEnds = false;

  bool _isInitialized = false;

  bool _isMuted = false;

  bool _showPlayIcon = false;

  //============================
  // VIDEO COMPLETION
  //============================

  bool _completionSent = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant VideoPostPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.forcePaused != widget.forcePaused) {
      _syncExternalPause();
    }
  }

  //===================================================
  // ROUTE VISIBILITY
  //===================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);

    if (currentRoute == _route) {
      return;
    }

    if (_route != null) {
      nubifyMediaRouteObserver.unsubscribe(this);
    }

    _route = currentRoute;

    if (currentRoute != null) {
      nubifyMediaRouteObserver.subscribe(this, currentRoute);
    }
  }

  @override
  void didPushNext() {
    _routeIsCovered = true;

    _pauseForCoveredRoute();
  }

  @override
  void didPopNext() {
    _routeIsCovered = false;

    _resumeForVisibleRoute();
  }

  void _pauseForCoveredRoute() {
    if (!_controller.value.isInitialized) {
      // This video normally autoplays after initialization. Remember that
      // intention, but do not allow initialization to start it while hidden.
      _resumeWhenRouteIsVisible = true;

      return;
    }

    _resumeWhenRouteIsVisible = _controller.value.isPlaying;

    if (!_resumeWhenRouteIsVisible) {
      return;
    }

    _controller.pause();

    if (!mounted) {
      return;
    }

    setState(() {
      _showPlayIcon = true;
    });
  }

  void _resumeForVisibleRoute() {
    _resumePlaybackIfAllowed();
  }

  void _syncExternalPause() {
    if (!_controller.value.isInitialized) {
      if (widget.forcePaused) {
        _resumeWhenExternalPauseEnds = true;
      }

      return;
    }

    if (widget.forcePaused) {
      _resumeWhenExternalPauseEnds = _controller.value.isPlaying;

      if (_resumeWhenExternalPauseEnds) {
        _controller.pause();
      }

      if (mounted) {
        setState(() {
          _showPlayIcon = true;
        });
      }

      return;
    }

    _resumePlaybackIfAllowed();
  }

  void _resumePlaybackIfAllowed() {
    final bool shouldResume =
        _resumeWhenRouteIsVisible || _resumeWhenExternalPauseEnds;

    if (!shouldResume ||
        _routeIsCovered ||
        widget.forcePaused ||
        !_controller.value.isInitialized) {
      return;
    }

    _resumeWhenRouteIsVisible = false;

    _resumeWhenExternalPauseEnds = false;

    _controller.play();

    _controller.setVolume(_isMuted ? 0.0 : 1.0);

    if (!mounted) {
      return;
    }

    setState(() {
      _showPlayIcon = false;
    });
  }

  // ============================================================
  // INITIALIZE VIDEO
  // ============================================================
  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),

      //============================
      // VIDEO AUDIO
      //============================
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    try {
      await _controller.initialize();

      //============================
      // SOUND ON BY DEFAULT
      //============================

      await _controller.setVolume(1.0);

      _isMuted = false;

      //============================
      // LOOP CONTROL
      //============================

      await _controller.setLooping(widget.loop);

      //============================
      // REAL VIDEO PROGRESS
      //============================

      _controller.addListener(_handleVideoProgress);

      // Never start sound while this route is behind another screen.
      // If initialization finishes while hidden, playback resumes only after
      // the covering route closes.
      if (_routeIsCovered || widget.forcePaused) {
        if (_routeIsCovered) {
          _resumeWhenRouteIsVisible = true;
        }

        if (widget.forcePaused) {
          _resumeWhenExternalPauseEnds = true;
        }
      } else {
        await _controller.play();

        _resumeWhenRouteIsVisible = false;
      }
      //============================
      // FORCE SOUND AFTER PLAY STARTS
      //============================

      await _controller.setVolume(_isMuted ? 0.0 : 1.0);

      //============================
      // VIDEO IS READY
      //============================

      widget.onProgressChanged?.call(0.0);

      widget.onReady?.call();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitialized = true;

        _showPlayIcon = _routeIsCovered || widget.forcePaused;
      });
    } catch (error) {
      debugPrint('Video player error: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitialized = false;
      });
    }
  }
  //============================
  // REAL VIDEO PROGRESS
  //============================

  void _handleVideoProgress() {
    if (!_controller.value.isInitialized) {
      return;
    }

    final Duration duration = _controller.value.duration;

    final Duration position = _controller.value.position;

    final int durationMs = duration.inMilliseconds;

    if (durationMs <= 0) {
      return;
    }

    final double progress = position.inMilliseconds / durationMs;

    widget.onProgressChanged?.call(progress.clamp(0.0, 1.0).toDouble());

    //============================
    // VIDEO FINISHED
    //============================

    if (!widget.loop &&
        !_completionSent &&
        position.inMilliseconds >= durationMs - 120) {
      _completionSent = true;

      widget.onProgressChanged?.call(1.0);

      widget.onCompleted?.call();
    }
  }
  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  void _togglePlayPause() {
    if (!_controller.value.isInitialized ||
        _routeIsCovered ||
        widget.forcePaused) {
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

    _controller.setVolume(_isMuted ? 0 : 1);
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    nubifyMediaRouteObserver.unsubscribe(this);

    _controller.removeListener(_handleVideoProgress);

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
          child: CircularProgressIndicator(color: Colors.white),
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
                child: VideoPlayer(_controller),
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
                  _isMuted ? Icons.volume_off : Icons.volume_up,
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

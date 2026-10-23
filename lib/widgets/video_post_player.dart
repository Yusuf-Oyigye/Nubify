import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

class _VideoPostPlayerState extends State<VideoPostPlayer>
    with RouteAware, WidgetsBindingObserver {
  late VideoPlayerController _controller;

  ModalRoute<dynamic>? _route;

  bool _routeIsCovered = false;

  bool _isInitialized = false;

  bool _isMuted = false;

  bool _showPlayIcon = false;

  // A feed video is allowed to play only when it is actually on screen, its
  // tab/route is active, and the application is in the foreground.
  bool _appIsActive = true;

  bool _tickerIsActive = true;

  double _visibleFraction = 0;

  bool _userPaused = false;

  //============================
  // VIDEO COMPLETION
  //============================

  bool _completionSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant VideoPostPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.forcePaused != widget.forcePaused ||
        oldWidget.loop != widget.loop) {
      if (_controller.value.isInitialized) {
        unawaited(_controller.setLooping(widget.loop));
      }

      _syncPlayback();
    }
  }

  //===================================================
  // ROUTE VISIBILITY
  //===================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _tickerIsActive = TickerMode.valuesOf(context).enabled;

    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);

    if (currentRoute == _route) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncPlayback();
        }
      });
      return;
    }

    if (_route != null) {
      nubifyMediaRouteObserver.unsubscribe(this);
    }

    _route = currentRoute;

    if (currentRoute != null) {
      nubifyMediaRouteObserver.subscribe(this, currentRoute);
    }

    _routeIsCovered = currentRoute != null && !currentRoute.isCurrent;
  }

  @override
  void didPushNext() {
    _routeIsCovered = true;

    _syncPlayback();
  }

  @override
  void didPopNext() {
    _routeIsCovered = false;

    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  bool get _canPlay {
    return _isInitialized &&
        !_routeIsCovered &&
        !widget.forcePaused &&
        _appIsActive &&
        _tickerIsActive &&
        _visibleFraction >= 0.65 &&
        !_userPaused;
  }

  Future<void> _syncPlayback() async {
    if (!_controller.value.isInitialized) {
      return;
    }

    final bool shouldPlay = _canPlay;

    if (shouldPlay && !_controller.value.isPlaying) {
      await _controller.setVolume(_isMuted ? 0.0 : 1.0);
      await _controller.play();
    } else if (!shouldPlay && _controller.value.isPlaying) {
      await _controller.pause();
    }

    if (!mounted) {
      return;
    }

    final bool showPlay = !shouldPlay && _visibleFraction > 0.05;

    if (_showPlayIcon != showPlay) {
      setState(() {
        _showPlayIcon = showPlay;
      });
    }
  }

  void _visibilityChanged(VisibilityInfo info) {
    final double nextFraction = info.visibleFraction.clamp(0.0, 1.0);

    if ((_visibleFraction - nextFraction).abs() < 0.02) {
      return;
    }

    _visibleFraction = nextFraction;
    _syncPlayback();
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

        _showPlayIcon = true;
      });

      await _syncPlayback();
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
        widget.forcePaused ||
        !_appIsActive ||
        !_tickerIsActive ||
        _visibleFraction < 0.65) {
      return;
    }

    if (_controller.value.isPlaying) {
      _userPaused = true;

      unawaited(_controller.pause());

      setState(() {
        _showPlayIcon = true;
      });
    } else {
      _userPaused = false;

      unawaited(_controller.play());

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
    WidgetsBinding.instance.removeObserver(this);

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
    return VisibilityDetector(
      key: ValueKey<String>(
        'nubify-video-${widget.videoUrl}-${identityHashCode(this)}',
      ),
      onVisibilityChanged: _visibilityChanged,
      child: !_isInitialized
          ? Container(
              width: double.infinity,
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          : GestureDetector(
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
            ),
    );
  }
}

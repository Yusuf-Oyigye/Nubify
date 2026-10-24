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

  final ValueChanged<bool>? onBufferingChanged;

  final VoidCallback? onCompleted;
  final VoidCallback? onReady;

  const VideoPostPlayer({
    super.key,
    required this.videoUrl,
    this.loop = true,
    this.forcePaused = false,
    this.onProgressChanged,
    this.onBufferingChanged,
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

  // Every playback decision gets a new number. If an older asynchronous
  // play request finishes after the video has been hidden, it is rejected
  // instead of starting audio in the background.
  int _playbackDecision = 0;

  bool _isDisposed = false;

  bool _progressListenerAttached = false;

  bool _lastBuffering = false;

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
    return !_isDisposed &&
        _isInitialized &&
        !_routeIsCovered &&
        !widget.forcePaused &&
        _appIsActive &&
        _tickerIsActive &&
        _visibleFraction >= 0.65 &&
        !_userPaused;
  }

  Future<void> _syncPlayback() async {
    final int decision = ++_playbackDecision;

    if (_isDisposed || !_controller.value.isInitialized) {
      return;
    }

    final bool shouldPlay = _canPlay;

    try {
      if (shouldPlay) {
        await _controller.setVolume(_isMuted ? 0.0 : 1.0);

        if (_isDisposed || decision != _playbackDecision || !_canPlay) {
          await _silenceAndPause();
          return;
        }

        if (!_controller.value.isPlaying) {
          await _controller.play();
        }

        // The page can become inactive while the native play call is being
        // processed. Check once more after it returns.
        if (_isDisposed || decision != _playbackDecision || !_canPlay) {
          await _silenceAndPause();
          return;
        }
      } else {
        // Pause even when Dart says it is already paused. The native player
        // can briefly be ahead of the cached isPlaying value.
        await _silenceAndPause();
      }
    } catch (error) {
      if (!_isDisposed) {
        debugPrint('Video playback sync error: $error');
      }
    }

    if (!mounted || _isDisposed || decision != _playbackDecision) {
      return;
    }

    final bool showPlay = !shouldPlay && _visibleFraction > 0.05;

    if (_showPlayIcon != showPlay) {
      setState(() {
        _showPlayIcon = showPlay;
      });
    }
  }

  Future<void> _silenceAndPause() async {
    if (!_controller.value.isInitialized) {
      return;
    }

    try {
      await _controller.setVolume(0.0);
    } catch (_) {
      // The native controller may already be shutting down.
    }

    try {
      await _controller.pause();
    } catch (_) {
      // The native controller may already be shutting down.
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

      if (_isDisposed || !mounted) {
        return;
      }

      //============================
      // SOUND ON BY DEFAULT
      //============================

      await _controller.setVolume(1.0);

      if (_isDisposed || !mounted) {
        return;
      }

      _isMuted = false;

      //============================
      // LOOP CONTROL
      //============================

      await _controller.setLooping(widget.loop);

      if (_isDisposed || !mounted) {
        return;
      }

      //============================
      // REAL VIDEO PROGRESS
      //============================

      _controller.addListener(_handleVideoProgress);
      _progressListenerAttached = true;

      //============================
      // VIDEO IS READY
      //============================

      widget.onProgressChanged?.call(0.0);

      widget.onReady?.call();

      if (!mounted || _isDisposed) {
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

    final bool buffering = _controller.value.isBuffering;

    if (_lastBuffering != buffering) {
      _lastBuffering = buffering;
      widget.onBufferingChanged?.call(buffering);

      if (mounted) {
        setState(() {});
      }
    }

    final Duration duration = _controller.value.duration;

    final Duration position = _controller.value.position;

    final int durationMs = duration.inMilliseconds;

    if (durationMs <= 0) {
      return;
    }

    final double progress = position.inMilliseconds / durationMs;

    if (!buffering) {
      widget.onProgressChanged?.call(progress.clamp(0.0, 1.0).toDouble());
    }

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
    } else {
      _userPaused = false;
    }

    _syncPlayback();
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
    _isDisposed = true;
    _playbackDecision++;

    WidgetsBinding.instance.removeObserver(this);

    nubifyMediaRouteObserver.unsubscribe(this);

    if (_progressListenerAttached) {
      _controller.removeListener(_handleVideoProgress);
    }

    unawaited(_disposeController());

    super.dispose();
  }

  Future<void> _disposeController() async {
    await _silenceAndPause();

    try {
      await _controller.dispose();
    } catch (_) {
      // A controller that failed during initialization can already be closed.
    }
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
                  if (_showPlayIcon && !_lastBuffering)
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

                  if (_lastBuffering)
                    const SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
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

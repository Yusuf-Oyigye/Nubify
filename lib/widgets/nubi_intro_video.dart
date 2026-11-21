
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/media_route_observer.dart';

class NubiIntroVideo extends StatefulWidget {
  const NubiIntroVideo({super.key});

  @override
  State<NubiIntroVideo> createState() => _NubiIntroVideoState();
}

class _NubiIntroVideoState extends State<NubiIntroVideo>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _player;
  ModalRoute<dynamic>? _route;

  bool _visible = false;
  bool _foreground = true;
  bool _covered = false;
  bool _ready = false;
  bool _failed = false;
  bool _disposed = false;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.asset(
      'assets/animations/nubi_digitaldoc_intro.mp4',
    );
    _player = controller;

    try {
      await controller.initialize();
      if (_disposed) return;

      await controller.setVolume(0);
      await controller.setLooping(true);
      if (_disposed) return;

      setState(() => _ready = true);
      _updatePlayback();
    } catch (error) {
      debugPrint('NUBi animation: $error');
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (_route != route) {
      if (_route != null) {
        nubifyMediaRouteObserver.unsubscribe(this);
      }
      _route = route;
      if (route != null) {
        nubifyMediaRouteObserver.subscribe(this, route);
      }
    }

    _covered = route != null && !route.isCurrent;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updatePlayback();
    });
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    _foreground = state == AppLifecycleState.resumed;
    _updatePlayback();
  }

  @override
  void didPushNext() {
    _covered = true;
    _updatePlayback();
  }

  @override
  void didPopNext() {
    _covered = false;
    _updatePlayback();
  }

  void _updatePlayback() {
    if (!mounted || _disposed || !_ready) return;

    final player = _player;
    if (player == null) return;

    final operation = ++_operation;
    final reducedMotion =
        MediaQuery.of(context).disableAnimations;

    final shouldPlay = _foreground &&
        !_covered &&
        _visible &&
        !reducedMotion &&
        TickerMode.valuesOf(context).enabled;

    if (shouldPlay) {
      unawaited(_playSafely(player, operation));
    } else {
      unawaited(player.pause());
    }
  }

  Future<void> _playSafely(
      VideoPlayerController player,
      int operation,
      ) async {
    try {
      await player.play();
      if (_disposed || operation != _operation) {
        await player.pause();
      }
    } catch (error) {
      debugPrint('NUBi playback: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.of(context).disableAnimations;
    final player = _player;

    return VisibilityDetector(
      key: const ValueKey('nubi-intro-video'),
      onVisibilityChanged: (info) {
        if (!mounted || _disposed) return;
        final visible = info.visibleFraction >= 0.55;

        if (visible != _visible) {
          _visible = visible;
          _updatePlayback();
        }
      },
      child: AspectRatio(
        aspectRatio: _ready &&
            player != null &&
            player.value.aspectRatio > 0
            ? player.value.aspectRatio
            : 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready &&
                  player != null &&
                  !reducedMotion)
                VideoPlayer(player)
              else
                Image.asset(
                  'assets/animations/nubi_intro_poster.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    alignment: Alignment.center,
                    color: const Color(0xFF12243B),
                    child: Text(
                      _failed
                          ? 'Cannot load NUBi animation'
                          : 'Add the original NUBi assets',
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (!_ready && !_failed)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    WidgetsBinding.instance.removeObserver(this);
    nubifyMediaRouteObserver.unsubscribe(this);

    final player = _player;
    if (player != null) {
      unawaited(player.dispose());
    }
    super.dispose();
  }
}

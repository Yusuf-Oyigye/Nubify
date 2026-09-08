import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

//===============================
// CHAT VOICE MESSAGE
//===============================

class ChatVoiceMessage
    extends StatefulWidget {
  const ChatVoiceMessage({
    super.key,
    required this.url,
    required this.mine,
    required this.durationMs,
  });

  final String url;

  final bool mine;

  final int durationMs;

  @override
  State<ChatVoiceMessage>
  createState() =>
      _ChatVoiceMessageState();
}

//===============================
// CHAT VOICE MESSAGE STATE
//===============================

class _ChatVoiceMessageState
    extends State<
        ChatVoiceMessage> {
  final AudioPlayer
  _player =
  AudioPlayer();

  StreamSubscription<Duration>?
  _positionSubscription;

  StreamSubscription<Duration>?
  _durationSubscription;

  StreamSubscription<void>?
  _completeSubscription;

  StreamSubscription<PlayerState>?
  _stateSubscription;

  Duration _position =
      Duration.zero;

  Duration _duration =
      Duration.zero;

  bool _playing =
  false;

  bool _loading =
  false;

  //===============================
  // WAVEFORM
  //===============================

  static const List<double>
  _wave =
  <double>[
    12,
    24,
    17,
    31,
    20,
    38,
    25,
    15,
    29,
    42,
    22,
    33,
    18,
    27,
    40,
    16,
    32,
    21,
    36,
    25,
    14,
    28,
    39,
    19,
    34,
    23,
    41,
    16,
    30,
    20,
    35,
    24,
  ];

  //===============================
  // AUDIO ROUTE
  //===============================

  Future<void>
  _configurePlayback() async {
    try {
      await _player
          .setPlayerMode(
        PlayerMode.mediaPlayer,
      );

      await _player
          .setAudioContext(
        AudioContext(
          android:
          const AudioContextAndroid(
            isSpeakerphoneOn:
            true,

            audioMode:
            AndroidAudioMode
                .normal,

            stayAwake:
            true,

            contentType:
            AndroidContentType
                .speech,

            usageType:
            AndroidUsageType
                .media,

            audioFocus:
            AndroidAudioFocus
                .gain,
          ),
        ),
      );

      await _player
          .setReleaseMode(
        ReleaseMode.stop,
      );

      await _player
          .setVolume(
        1.0,
      );
    } catch (_) {}
  }

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();

    if (widget.durationMs >
        0) {
      _duration =
          Duration(
            milliseconds:
            widget.durationMs,
          );
    }

    _positionSubscription =
        _player
            .onPositionChanged
            .listen(
              (
              Duration position,
              ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _position =
                  position;
            });
          },
        );

    _durationSubscription =
        _player
            .onDurationChanged
            .listen(
              (
              Duration duration,
              ) {
            if (!mounted ||
                duration <=
                    Duration.zero) {
              return;
            }

            setState(() {
              _duration =
                  duration;
            });
          },
        );

    _completeSubscription =
        _player
            .onPlayerComplete
            .listen(
              (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _position =
                  Duration.zero;

              _playing =
              false;

              _loading =
              false;
            });
          },
        );

    _stateSubscription =
        _player
            .onPlayerStateChanged
            .listen(
              (
              PlayerState state,
              ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _playing =
                  state ==
                      PlayerState
                          .playing;

              if (state ==
                  PlayerState
                      .playing ||
                  state ==
                      PlayerState
                          .paused ||
                  state ==
                      PlayerState
                          .stopped) {
                _loading =
                false;
              }
            });
          },
        );
  }

  //===============================
  // UPDATE MESSAGE
  //===============================

  @override
  void didUpdateWidget(
      covariant ChatVoiceMessage
      oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.url !=
        widget.url) {
      _player.stop();

      _position =
          Duration.zero;

      _duration =
      widget.durationMs >
          0
          ? Duration(
        milliseconds:
        widget.durationMs,
      )
          : Duration.zero;

      _playing =
      false;

      _loading =
      false;
    }
  }

  //===============================
  // PLAY / PAUSE
  //===============================

  Future<void> _toggle() async {
    final String url =
    widget.url.trim();

    if (url.isEmpty) {
      return;
    }

    try {
      if (_playing) {
        await _player.pause();

        return;
      }

      await _configurePlayback();

      if (_position >
          Duration.zero &&
          _duration >
              Duration.zero &&
          _position <
              _duration) {
        await _player.resume();

        return;
      }

      setState(() {
        _loading =
        true;
      });

      await _player.stop();

      await _player.play(
        UrlSource(
          url,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
        false;

        _playing =
        false;
      });
    }
  }

  //===============================
  // SEEK
  //===============================

  Future<void> _seekFromFraction(
      double fraction,
      ) async {
    final int durationMs =
    _duration.inMilliseconds >
        0
        ? _duration
        .inMilliseconds
        : widget.durationMs;

    if (durationMs <=
        0) {
      return;
    }

    final double safe =
    fraction.clamp(
      0.0,
      1.0,
    );

    final Duration target =
    Duration(
      milliseconds:
      (durationMs *
          safe)
          .round(),
    );

    await _player.seek(
      target,
    );

    if (mounted) {
      setState(() {
        _position =
            target;
      });
    }
  }

  //===============================
  // WAVEFORM
  //===============================

  Widget _waveform() {
    final int totalMs =
    _duration.inMilliseconds >
        0
        ? _duration
        .inMilliseconds
        : widget.durationMs >
        0
        ? widget.durationMs
        : 1;

    final double progress =
    (_position.inMilliseconds /
        totalMs)
        .clamp(
      0.0,
      1.0,
    );

    return LayoutBuilder(
      builder:
          (
          BuildContext context,
          BoxConstraints constraints,
          ) {
        void seek(
            double x,
            ) {
          if (constraints.maxWidth <=
              0) {
            return;
          }

          _seekFromFraction(
            x /
                constraints
                    .maxWidth,
          );
        }

        return GestureDetector(
          behavior:
          HitTestBehavior.opaque,

          onTapDown:
              (
              TapDownDetails details,
              ) {
            seek(
              details
                  .localPosition
                  .dx,
            );
          },

          onHorizontalDragUpdate:
              (
              DragUpdateDetails details,
              ) {
            seek(
              details
                  .localPosition
                  .dx,
            );
          },

          child:
          SizedBox(
            height:
            45,

            child:
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.center,

              children:
              List<Widget>.generate(
                _wave.length,

                    (
                    int index,
                    ) {
                  final double barProgress =
                      (index +
                          1) /
                          _wave.length;

                  final bool active =
                      barProgress <=
                          progress;

                  return Expanded(
                    child:
                    Align(
                      alignment:
                      Alignment.center,

                      child:
                      Container(
                        width:
                        2.4,

                        height:
                        _wave[index],

                        decoration:
                        BoxDecoration(
                          color:
                          active
                              ? Colors.white
                              : Colors.white38,

                          borderRadius:
                          BorderRadius.circular(
                            4,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  //===============================
  // FORMAT TIME
  //===============================

  String _formatDuration(
      Duration duration,
      ) {
    final int minutes =
        duration.inMinutes;

    final int seconds =
        duration.inSeconds %
            60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    final Duration shownDuration =
    _position >
        Duration.zero
        ? _position
        : _duration >
        Duration.zero
        ? _duration
        : Duration(
      milliseconds:
      widget.durationMs,
    );

    return SizedBox(
      width:
      245,

      child:
      Row(
        children:
        <Widget>[
          InkWell(
            customBorder:
            const CircleBorder(),

            onTap:
            _loading
                ? null
                : _toggle,

            child:
            CircleAvatar(
              radius:
              21,

              backgroundColor:
              Colors.white24,

              child:
              _loading
                  ? const SizedBox(
                width:
                17,

                height:
                17,

                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,

                  color:
                  Colors.white,
                ),
              )
                  : Icon(
                _playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,

                color:
                Colors.white,

                size:
                27,
              ),
            ),
          ),

          const SizedBox(
            width:
            8,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              mainAxisSize:
              MainAxisSize.min,

              children:
              <Widget>[
                _waveform(),

                Text(
                  _formatDuration(
                    shownDuration,
                  ),

                  style:
                  const TextStyle(
                    color:
                    Colors.white70,

                    fontSize:
                    10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _positionSubscription
        ?.cancel();

    _durationSubscription
        ?.cancel();

    _completeSubscription
        ?.cancel();

    _stateSubscription
        ?.cancel();

    _player.dispose();

    super.dispose();
  }
}
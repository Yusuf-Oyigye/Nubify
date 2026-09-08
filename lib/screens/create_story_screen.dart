import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../models/story.dart';
import '../services/story_service.dart';
import 'story_people_picker_screen.dart';

//===================================================
// CREATE STORY SCREEN
//===================================================

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({
    super.key,
  });

  @override
  State<CreateStoryScreen> createState() =>
      _CreateStoryScreenState();
}

//===================================================
// CREATE STORY STATE
//===================================================

class _CreateStoryScreenState
    extends State<CreateStoryScreen> {
  //===================================================
  // SERVICES
  //===================================================

  final StoryService _storyService =
  StoryService();

  final ImagePicker _imagePicker =
  ImagePicker();

  final AudioRecorder _audioRecorder =
  AudioRecorder();

  final AudioPlayer _audioPlayer =
  AudioPlayer();

  //===================================================
  // CONTROLLERS
  //===================================================

  final TextEditingController
  _storyTextController =
  TextEditingController();

  final TextEditingController
  _captionController =
  TextEditingController();

  final TextEditingController
  _pollQuestionController =
  TextEditingController();

  final List<TextEditingController>
  _pollOptionControllers =
  <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  //===================================================
  // MODE
  //===================================================

  String _mode =
      'media';

  //===================================================
  // MEDIA
  //===================================================

  XFile? _mediaFile;

  bool _mediaIsVideo =
  false;

  int _mediaVideoDurationSeconds =
  15;

  //===================================================
  // LAYOUT
  //===================================================

  List<XFile> _layoutFiles =
  <XFile>[];

  int _layoutCount =
  2;

  String _layoutStyle =
      'vertical';

  //===================================================
  // POST
  //===================================================

  bool _isPosting =
  false;

  //===================================================
  // VOICE RECORDING
  //===================================================

  bool _isRecording =
  false;

  String? _voicePath;

  int _voiceSeconds =
  0;

  //===================================================
  // VOICE RECORDING LIMIT
  //
  // THIS IS WHERE YOU CHANGE MINUTES + SECONDS.
  //
  // 5:00
  // minutes = 5
  // seconds = 0
  //
  // 2:30
  // minutes = 2
  // seconds = 30
  //===================================================

  static const int _voiceLimitMinutes =
  5;

  static const int _voiceLimitSeconds =
  0;

  static const int _maxVoiceSeconds =
      (_voiceLimitMinutes * 60) +
          _voiceLimitSeconds;

  Timer? _voiceTimer;

  Timer? _waveformTimer;

  //===================================================
  // VOICE PLAYER
  //===================================================

  bool _isVoicePlaying =
  false;

  bool _isVoicePaused =
  false;

  bool _voiceCompleted =
  false;

  Duration _voicePosition =
      Duration.zero;

  Duration _voiceDuration =
      Duration.zero;

  StreamSubscription<Duration>?
  _voicePositionSubscription;

  StreamSubscription<Duration>?
  _voiceDurationSubscription;

  StreamSubscription<void>?
  _audioCompleteSubscription;

  //===================================================
  // WAVEFORM
  //===================================================

  final List<double> _waveformHeights =
  List<double>.filled(
    22,
    10,
  );

  //===================================================
  // DESIGN
  //===================================================

  int _backgroundColor =
  0xFF101114;

  int _textColor =
  0xFFFFFFFF;

  String _textStyle =
      'bold';

  String _textAlign =
      'center';

  double _textSize =
  34;

  String _sticker =
      '';

  //===================================================
  // TAGGED PEOPLE
  //===================================================

  List<StoryPerson> _taggedPeople =
  <StoryPerson>[];

  //===================================================
  // COLORS
  //===================================================

  final List<int> _backgroundColors =
  <int>[
    0xFF101114,
    0xFF102A43,
    0xFF003B5C,
    0xFF5B2C83,
    0xFF7A1F3D,
    0xFF6B4F1D,
    0xFF00695C,
    0xFF263238,
  ];

  final List<int> _textColors =
  <int>[
    0xFFFFFFFF,
    0xFF29B6F6,
    0xFFFFE082,
    0xFFFF8A80,
    0xFFB9F6CA,
    0xFFE1BEE7,
    0xFF111111,
  ];

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _voicePositionSubscription =
        _audioPlayer
            .onPositionChanged
            .listen(
              (
              Duration position,
              ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _voicePosition =
                  position;
            });
          },
        );

    _voiceDurationSubscription =
        _audioPlayer
            .onDurationChanged
            .listen(
              (
              Duration duration,
              ) {
            if (!mounted) {
              return;
            }

            setState(() {
              _voiceDuration =
                  duration;
            });
          },
        );

    _audioCompleteSubscription =
        _audioPlayer
            .onPlayerComplete
            .listen(
              (_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _isVoicePlaying =
              false;

              _isVoicePaused =
              false;

              _voiceCompleted =
              true;

              if (_voiceDuration >
                  Duration.zero) {
                _voicePosition =
                    _voiceDuration;
              }
            });
          },
        );
  }

  //===================================================
  // SELECT MODE
  //===================================================

  Future<void> _selectMode(
      String mode,
      ) async {
    if (_isRecording) {
      await _stopRecording();
    }

    if (_isVoicePlaying ||
        _isVoicePaused) {
      await _audioPlayer.pause();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _mode =
          mode;

      if (mode !=
          'voice') {
        _isVoicePlaying =
        false;

        _isVoicePaused =
        false;
      }
    });

    if (mode ==
        'media' &&
        _mediaFile ==
            null) {
      await _showMediaPicker();
    }

    if (mode ==
        'layout' &&
        _layoutFiles.isEmpty) {
      await _pickLayoutImages();
    }
  }

  //===================================================
  // MEDIA PICKER
  //===================================================

  Future<void> _showMediaPicker() async {
    await showModalBottomSheet<void>(
      context:
      context,
      builder:
          (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child:
          Wrap(
            children:
            <Widget>[
              ListTile(
                leading:
                const Icon(
                  Icons
                      .photo_library_outlined,
                ),
                title:
                const Text(
                  'Photo from gallery',
                ),
                onTap:
                    () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _pickImage(
                    ImageSource.gallery,
                  );
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons
                      .video_library_outlined,
                ),
                title:
                const Text(
                  'Video from gallery',
                ),
                onTap:
                    () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _pickVideo(
                    ImageSource.gallery,
                  );
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons
                      .camera_alt_outlined,
                ),
                title:
                const Text(
                  'Take photo',
                ),
                onTap:
                    () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _pickImage(
                    ImageSource.camera,
                  );
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.videocam_outlined,
                ),
                title:
                const Text(
                  'Record video',
                ),
                onTap:
                    () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _pickVideo(
                    ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // PICK IMAGE
  //===================================================

  Future<void> _pickImage(
      ImageSource source,
      ) async {
    final XFile? file =
    await _imagePicker
        .pickImage(
      source:
      source,
      imageQuality:
      92,
    );

    if (file == null ||
        !mounted) {
      return;
    }

    setState(() {
      _mode =
      'media';

      _mediaFile =
          file;

      _mediaIsVideo =
      false;
    });
  }

  //===================================================
  // PICK VIDEO
  //
  // VIDEO REMAINS 60 SEC.
  // VOICE IS NOW 5 MIN.
  //===================================================

  Future<void> _pickVideo(
      ImageSource source,
      ) async {
    final XFile? file =
    await _imagePicker
        .pickVideo(
      source:
      source,
      maxDuration:
      const Duration(
        seconds:
        60,
      ),
    );

    if (file == null) {
      return;
    }

    int durationSeconds =
    15;

    try {
      final VideoPlayerController controller =
      VideoPlayerController.file(
        File(
          file.path,
        ),
      );

      await controller.initialize();

      durationSeconds =
          controller
              .value
              .duration
              .inSeconds
              .clamp(
            3,
            60,
          )
              .toInt();

      await controller.dispose();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _mode =
      'media';

      _mediaFile =
          file;

      _mediaIsVideo =
      true;

      _mediaVideoDurationSeconds =
          durationSeconds;
    });
  }

  //===================================================
  // PICK LAYOUT PHOTOS
  //===================================================

  Future<void> _pickLayoutImages() async {
    final List<XFile> files =
    await _imagePicker
        .pickMultiImage(
      imageQuality:
      92,
    );

    if (files.isEmpty ||
        !mounted) {
      return;
    }

    final List<XFile> limited =
    files.take(
      4,
    ).toList();

    setState(() {
      _mode =
      'layout';

      _layoutFiles =
          limited;
    });
  }

  //===================================================
  // LAYOUT FILE FOR SLOT
  //
  // 1 PHOTO IN 4 = 1 1 1 1
  // 2 PHOTOS IN 4 = 1 2 1 2
  // 3 PHOTOS IN 4 = 1 2 3 1
  //===================================================

  XFile _layoutFileForSlot(
      int index,
      ) {
    return _layoutFiles[
    index %
        _layoutFiles.length
    ];
  }

  //===================================================
  // LAYOUT SETTINGS
  //===================================================

  Future<void> _showLayoutSettings() async {
    await showModalBottomSheet<void>(
      context:
      context,
      isScrollControlled:
      true,
      backgroundColor:
      const Color(
        0xFF171717,
      ),
      shape:
      const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top:
          Radius.circular(
            24,
          ),
        ),
      ),
      builder:
          (
          BuildContext sheetContext,
          ) {
        return StatefulBuilder(
          builder:
              (
              BuildContext context,
              void Function(
                  void Function(),
                  )
              setSheetState,
              ) {
            void updateLayout({
              int? count,
              String? style,
            }) {
              setState(() {
                if (count !=
                    null) {
                  _layoutCount =
                      count;

                  _layoutStyle =
                      _defaultLayoutStyle(
                        count,
                      );
                }

                if (style !=
                    null) {
                  _layoutStyle =
                      style;
                }
              });

              setSheetState(
                    () {},
              );
            }

            final List<
                Map<String, String>>
            styles =
            _layoutStylesForCount(
              _layoutCount,
            );

            return SafeArea(
              child:
              Padding(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  18,
                  18,
                  18,
                  28,
                ),
                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children:
                  <Widget>[
                    Center(
                      child:
                      Container(
                        width:
                        45,
                        height:
                        4,
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.white30,
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                      18,
                    ),

                    const Text(
                      'Layout',
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontSize:
                        21,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      6,
                    ),

                    const Text(
                      'Choose 2, 3 or 4 panels. One photo can fill every panel.',
                      style:
                      TextStyle(
                        color:
                        Colors.white60,
                      ),
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    Row(
                      children:
                      <Widget>[
                        for (
                        final int count
                        in <int>[
                          2,
                          3,
                          4,
                        ]
                        )
                          Expanded(
                            child:
                            Padding(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal:
                                4,
                              ),
                              child:
                              FilledButton(
                                style:
                                FilledButton
                                    .styleFrom(
                                  backgroundColor:
                                  _layoutCount ==
                                      count
                                      ? const Color(
                                    0xFF29B6F6,
                                  )
                                      : Colors.white10,
                                ),
                                onPressed:
                                    () {
                                  updateLayout(
                                    count:
                                    count,
                                  );
                                },
                                child:
                                Text(
                                  '$count',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height:
                      20,
                    ),

                    const Text(
                      'Style',
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                      10,
                    ),

                    Wrap(
                      spacing:
                      8,
                      runSpacing:
                      8,
                      children:
                      styles.map(
                            (
                            Map<String, String> item,
                            ) {
                          final String id =
                          item['id']!;

                          final bool selected =
                              _layoutStyle ==
                                  id;

                          return ChoiceChip(
                            selected:
                            selected,
                            selectedColor:
                            const Color(
                              0xFF29B6F6,
                            ),
                            backgroundColor:
                            Colors.white10,
                            label:
                            Text(
                              item['label']!,
                              style:
                              TextStyle(
                                color:
                                selected
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                            onSelected:
                                (_) {
                              updateLayout(
                                style:
                                id,
                              );
                            },
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(
                      height:
                      22,
                    ),

                    SizedBox(
                      width:
                      double.infinity,
                      child:
                      FilledButton(
                        onPressed:
                            () {
                          Navigator.pop(
                            sheetContext,
                          );
                        },
                        child:
                        const Text(
                          'Done',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  //===================================================
  // DEFAULT LAYOUT STYLE
  //===================================================

  String _defaultLayoutStyle(
      int count,
      ) {
    switch (count) {
      case 3:
        return 'big_top';

      case 4:
        return 'grid';

      default:
        return 'vertical';
    }
  }

  //===================================================
  // LAYOUT STYLES
  //===================================================

  List<Map<String, String>>
  _layoutStylesForCount(
      int count,
      ) {
    if (count ==
        2) {
      return const <
          Map<String, String>>[
        <String, String>{
          'id':
          'vertical',
          'label':
          'Left / Right',
        },
        <String, String>{
          'id':
          'horizontal',
          'label':
          'Top / Bottom',
        },
      ];
    }

    if (count ==
        3) {
      return const <
          Map<String, String>>[
        <String, String>{
          'id':
          'big_top',
          'label':
          'Big Top',
        },
        <String, String>{
          'id':
          'big_left',
          'label':
          'Big Left',
        },
        <String, String>{
          'id':
          'three_vertical',
          'label':
          '3 Vertical',
        },
        <String, String>{
          'id':
          'three_horizontal',
          'label':
          '3 Horizontal',
        },
      ];
    }

    return const <
        Map<String, String>>[
      <String, String>{
        'id':
        'grid',
        'label':
        '2 × 2',
      },
      <String, String>{
        'id':
        'four_vertical',
        'label':
        '4 Vertical',
      },
      <String, String>{
        'id':
        'four_horizontal',
        'label':
        '4 Horizontal',
      },
      <String, String>{
        'id':
        'big_left_three',
        'label':
        'Big Left + 3',
      },
    ];
  }

  //===================================================
  // START VOICE RECORDING
  //===================================================

  Future<void> _startRecording() async {
    if (_isRecording) {
      return;
    }

    try {
      await _audioPlayer.stop();

      await _deleteOldVoiceFileOnly();

      final bool allowed =
      await _audioRecorder
          .hasPermission();

      if (!allowed) {
        _showMessage(
          'Microphone permission is required.',
        );

        return;
      }

      final Directory directory =
      await getTemporaryDirectory();

      final String path =
          '${directory.path}/nubify_story_'
          '${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder:
          AudioEncoder.aacLc,
          bitRate:
          128000,
          sampleRate:
          44100,
          numChannels:
          1,
        ),
        path:
        path,
      );

      _voiceTimer?.cancel();

      _waveformTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _mode =
        'voice';

        _voicePath =
        null;

        _voiceSeconds =
        0;

        _voicePosition =
            Duration.zero;

        _voiceDuration =
            Duration.zero;

        _isRecording =
        true;

        _isVoicePlaying =
        false;

        _isVoicePaused =
        false;

        _voiceCompleted =
        false;

        for (
        int index = 0;
        index <
            _waveformHeights.length;
        index++
        ) {
          _waveformHeights[index] =
          10;
        }
      });

      //===================================================
      // RECORDING TIMER
      //
      // AUTO-STOPS AT 5:00
      //===================================================

      _voiceTimer =
          Timer.periodic(
            const Duration(
              seconds:
              1,
            ),
                (
                Timer timer,
                ) {
              if (!mounted ||
                  !_isRecording) {
                return;
              }

              setState(() {
                _voiceSeconds++;
              });

              if (_voiceSeconds >=
                  _maxVoiceSeconds) {
                _stopRecording();
              }
            },
          );

      //===================================================
      // LIVE WAVEFORM
      //===================================================

      _waveformTimer =
          Timer.periodic(
            const Duration(
              milliseconds:
              120,
            ),
                (
                Timer timer,
                ) async {
              if (!mounted ||
                  !_isRecording) {
                return;
              }

              try {
                final Amplitude amplitude =
                await _audioRecorder
                    .getAmplitude();

                //===================================================
                // IMPORTANT:
                //
                // THE 60 BELOW IS AUDIO dB NORMALIZATION.
                // IT IS NOT THE 60-SECOND RECORD LIMIT.
                // DO NOT CHANGE THIS TO 300.
                //===================================================

                final double normalized =
                ((amplitude.current +
                    60) /
                    60)
                    .clamp(
                  0.0,
                  1.0,
                )
                    .toDouble();

                final double nextHeight =
                    10 +
                        normalized *
                            48;

                if (!mounted ||
                    !_isRecording) {
                  return;
                }

                setState(() {
                  _waveformHeights.removeAt(
                    0,
                  );

                  _waveformHeights.add(
                    nextHeight,
                  );
                });
              } catch (_) {}
            },
          );
    } catch (error) {
      _voiceTimer?.cancel();

      _waveformTimer?.cancel();

      if (mounted) {
        setState(() {
          _isRecording =
          false;
        });
      }

      _showMessage(
        'Unable to start voice recording: $error',
      );
    }
  }

  //===================================================
  // STOP RECORDING
  //===================================================

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      final String? path =
      await _audioRecorder
          .stop();

      _voiceTimer?.cancel();

      _waveformTimer?.cancel();

      if (!mounted) {
        return;
      }

      if (path == null ||
          path.trim().isEmpty) {
        setState(() {
          _isRecording =
          false;

          _voicePath =
          null;
        });

        _showMessage(
          'No audio recording was created.',
        );

        return;
      }

      final File file =
      File(
        path,
      );

      if (!await file.exists() ||
          await file.length() <=
              0) {
        setState(() {
          _isRecording =
          false;

          _voicePath =
          null;
        });

        _showMessage(
          'The recorded audio is empty.',
        );

        return;
      }

      final int safeSeconds =
      _voiceSeconds <
          1
          ? 1
          : _voiceSeconds;

      setState(() {
        _isRecording =
        false;

        _isVoicePlaying =
        false;

        _isVoicePaused =
        false;

        _voiceCompleted =
        false;

        _voicePath =
            path;

        _voiceSeconds =
            safeSeconds;

        _voicePosition =
            Duration.zero;

        _voiceDuration =
            Duration(
              seconds:
              safeSeconds,
            );
      });
    } catch (error) {
      _voiceTimer?.cancel();

      _waveformTimer?.cancel();

      if (mounted) {
        setState(() {
          _isRecording =
          false;
        });
      }

      _showMessage(
        'Unable to stop voice recording: $error',
      );
    }
  }

  //===================================================
  // PLAY / PAUSE VOICE REVIEW
  //===================================================

  Future<void> _toggleVoicePreview() async {
    final String? path =
        _voicePath;

    if (path == null ||
        path.trim().isEmpty) {
      return;
    }

    final File file =
    File(
      path,
    );

    if (!await file.exists()) {
      _showMessage(
        'The recorded audio file is no longer available.',
      );

      return;
    }

    try {
      //===================================================
      // PLAYING -> PAUSE
      //===================================================

      if (_isVoicePlaying) {
        await _audioPlayer.pause();

        if (!mounted) {
          return;
        }

        setState(() {
          _isVoicePlaying =
          false;

          _isVoicePaused =
          true;
        });

        return;
      }

      //===================================================
      // PAUSED -> RESUME
      //===================================================

      if (_isVoicePaused &&
          !_voiceCompleted) {
        await _audioPlayer.resume();

        if (!mounted) {
          return;
        }

        setState(() {
          _isVoicePlaying =
          true;

          _isVoicePaused =
          false;
        });

        return;
      }

      //===================================================
      // NEW PLAY / REPLAY
      //===================================================

      Duration startPosition =
          _voicePosition;

      if (_voiceCompleted ||
          (_voiceDuration >
              Duration.zero &&
              _voicePosition >=
                  _voiceDuration)) {
        startPosition =
            Duration.zero;
      }

      await _audioPlayer.stop();

      await _audioPlayer.setVolume(
        1,
      );

      await _audioPlayer.play(
        DeviceFileSource(
          path,
        ),
      );

      if (startPosition >
          Duration.zero) {
        await _audioPlayer.seek(
          startPosition,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _voicePosition =
            startPosition;

        _isVoicePlaying =
        true;

        _isVoicePaused =
        false;

        _voiceCompleted =
        false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isVoicePlaying =
        false;

        _isVoicePaused =
        false;
      });

      _showMessage(
        'Unable to play recording: $error',
      );
    }
  }

  //===================================================
  // SEEK VOICE
  //===================================================

  Future<void> _seekVoice(
      double value,
      ) async {
    final Duration duration =
        _effectiveVoiceDuration;

    if (duration <=
        Duration.zero) {
      return;
    }

    final Duration newPosition =
    Duration(
      milliseconds:
      (duration.inMilliseconds *
          value)
          .round(),
    );

    setState(() {
      _voicePosition =
          newPosition;

      _voiceCompleted =
      false;
    });

    try {
      if (_isVoicePlaying ||
          _isVoicePaused) {
        await _audioPlayer.seek(
          newPosition,
        );
      }
    } catch (_) {}
  }

  //===================================================
  // EFFECTIVE VOICE DURATION
  //===================================================

  Duration get _effectiveVoiceDuration {
    if (_voiceDuration >
        Duration.zero) {
      return _voiceDuration;
    }

    return Duration(
      seconds:
      _voiceSeconds,
    );
  }

  //===================================================
  // VOICE SLIDER
  //===================================================

  double get _voiceSliderValue {
    final Duration duration =
        _effectiveVoiceDuration;

    if (duration.inMilliseconds <=
        0) {
      return 0;
    }

    return (_voicePosition.inMilliseconds /
        duration.inMilliseconds)
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();
  }

  //===================================================
  // DELETE VOICE
  //===================================================

  Future<void> _deleteVoiceRecording() async {
    _voiceTimer?.cancel();

    _waveformTimer?.cancel();

    try {
      if (_isRecording) {
        await _audioRecorder.stop();
      }
    } catch (_) {}

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    await _deleteOldVoiceFileOnly();

    if (!mounted) {
      return;
    }

    setState(() {
      _voicePath =
      null;

      _voiceSeconds =
      0;

      _voicePosition =
          Duration.zero;

      _voiceDuration =
          Duration.zero;

      _isRecording =
      false;

      _isVoicePlaying =
      false;

      _isVoicePaused =
      false;

      _voiceCompleted =
      false;

      for (
      int index = 0;
      index <
          _waveformHeights.length;
      index++
      ) {
        _waveformHeights[index] =
        10;
      }
    });
  }

  //===================================================
  // DELETE TEMP VOICE FILE
  //===================================================

  Future<void> _deleteOldVoiceFileOnly() async {
    final String? path =
        _voicePath;

    if (path == null ||
        path.trim().isEmpty) {
      return;
    }

    try {
      final File file =
      File(
        path,
      );

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  //===================================================
  // TAG PEOPLE
  //===================================================

  Future<void> _pickTaggedPeople() async {
    final List<StoryPerson>? result =
    await Navigator.push<
        List<StoryPerson>>(
      context,
      MaterialPageRoute<
          List<StoryPerson>>(
        builder:
            (_) =>
            StoryPeoplePickerScreen(
              title:
              'Tag People',
              initialSelected:
              _taggedPeople,
              maxSelection:
              20,
            ),
      ),
    );

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      _taggedPeople =
          result;
    });
  }

  //===================================================
  // ADD POLL OPTION
  //===================================================

  void _addPollOption() {
    if (_pollOptionControllers.length >=
        4) {
      _showMessage(
        'A story poll can have up to 4 options.',
      );

      return;
    }

    setState(() {
      _pollOptionControllers.add(
        TextEditingController(),
      );
    });
  }

  //===================================================
  // REMOVE POLL OPTION
  //===================================================

  void _removePollOption(
      int index,
      ) {
    if (_pollOptionControllers.length <=
        2) {
      return;
    }

    final TextEditingController controller =
    _pollOptionControllers.removeAt(
      index,
    );

    controller.dispose();

    setState(
          () {},
    );
  }

  //===================================================
  // STICKERS
  //===================================================

  Future<void> _showStickers() async {
    const List<String> stickers =
    <String>[
      '🎓',
      '🔥',
      '💙',
      '📚',
      '🧠',
      '☕',
      '😂',
      '✨',
      '🥹',
      '✅',
      '💯',
      '👀',
    ];

    final String? selected =
    await showModalBottomSheet<
        String>(
      context:
      context,
      builder:
          (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child:
          Padding(
            padding:
            const EdgeInsets.all(
              20,
            ),
            child:
            Wrap(
              spacing:
              16,
              runSpacing:
              16,
              children:
              stickers.map(
                    (
                    String sticker,
                    ) {
                  return InkWell(
                    onTap:
                        () {
                      Navigator.pop(
                        sheetContext,
                        sticker,
                      );
                    },
                    child:
                    Text(
                      sticker,
                      style:
                      const TextStyle(
                        fontSize:
                        32,
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _sticker =
          selected;
    });
  }

  //===================================================
  // POST STORY
  //===================================================

  Future<void> _postStory() async {
    if (_isPosting) {
      return;
    }

    if (_isRecording) {
      await _stopRecording();
    }

    if (_mode ==
        'media' &&
        _mediaFile ==
            null) {
      _showMessage(
        'Choose a photo or video first.',
      );

      return;
    }

    if (_mode ==
        'layout' &&
        _layoutFiles.isEmpty) {
      _showMessage(
        'Choose at least 1 photo for your layout.',
      );

      return;
    }

    if (_mode ==
        'text' &&
        _storyTextController.text
            .trim()
            .isEmpty) {
      _showMessage(
        'Write something for your story.',
      );

      return;
    }

    if (_mode ==
        'poll') {
      final String question =
      _pollQuestionController.text
          .trim();

      final List<String> options =
      _pollOptionControllers
          .map(
            (
            TextEditingController controller,
            ) {
          return controller.text
              .trim();
        },
      )
          .where(
            (
            String text,
            ) {
          return text
              .isNotEmpty;
        },
      )
          .toList();

      if (question.isEmpty ||
          options.length <
              2) {
        _showMessage(
          'Add a poll question and at least 2 options.',
        );

        return;
      }
    }

    if (_mode ==
        'voice' &&
        (_voicePath ==
            null ||
            _voicePath!
                .trim()
                .isEmpty)) {
      _showMessage(
        'Record your voice first.',
      );

      return;
    }

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isVoicePlaying =
        false;

        _isVoicePaused =
        false;

        _isPosting =
        true;
      });
    }

    try {
      final String storyId =
      _storyService.newStoryId();

      String mediaUrl =
          '';

      final List<String> mediaUrls =
      <String>[];

      String type =
          _mode;

      StoryPoll? poll;

      int durationSeconds =
      8;

      //===================================================
      // MEDIA
      //===================================================

      if (_mode ==
          'media') {
        mediaUrl =
        await _storyService
            .uploadStoryMedia(
          storyId:
          storyId,
          file:
          _mediaFile!,
        );

        type =
        _mediaIsVideo
            ? 'video'
            : 'image';

        durationSeconds =
        _mediaIsVideo
            ? _mediaVideoDurationSeconds
            : 8;
      }

      //===================================================
      // LAYOUT
      //===================================================

      if (_mode ==
          'layout') {
        for (
        int index = 0;
        index <
            _layoutFiles.length;
        index++
        ) {
          final String url =
          await _storyService
              .uploadStoryMedia(
            storyId:
            storyId,
            file:
            _layoutFiles[index],
            folder:
            'layout_$index',
          );

          mediaUrls.add(
            url,
          );
        }

        type =
        'layout';

        durationSeconds =
        10;
      }

      //===================================================
      // VOICE
      //===================================================

      if (_mode ==
          'voice') {
        mediaUrl =
        await _storyService
            .uploadVoiceStory(
          storyId:
          storyId,
          filePath:
          _voicePath!,
        );

        type =
        'voice';

        durationSeconds =
        _effectiveVoiceDuration
            .inSeconds >
            0
            ? _effectiveVoiceDuration
            .inSeconds
            .clamp(
          3,
          _maxVoiceSeconds,
        )
            .toInt()
            : _voiceSeconds
            .clamp(
          3,
          _maxVoiceSeconds,
        )
            .toInt();
      }

      //===================================================
      // POLL
      //===================================================

      if (_mode ==
          'poll') {
        final List<StoryPollOption> options =
        _pollOptionControllers
            .map(
              (
              TextEditingController controller,
              ) {
            return controller.text
                .trim();
          },
        )
            .where(
              (
              String text,
              ) {
            return text
                .isNotEmpty;
          },
        )
            .map(
              (
              String text,
              ) {
            return StoryPollOption(
              text:
              text,
              votes:
              0,
            );
          },
        )
            .toList();

        poll =
            StoryPoll(
              question:
              _pollQuestionController.text
                  .trim(),
              options:
              options,
              totalVotes:
              0,
            );

        durationSeconds =
        15;
      }

      //===================================================
      // TEXT + STICKER
      //===================================================

      final String storyText =
      <String>[
        _sticker,
        _storyTextController.text
            .trim(),
      ]
          .where(
            (
            String value,
            ) {
          return value
              .trim()
              .isNotEmpty;
        },
      )
          .join(
        '\n',
      );

      //===================================================
      // CREATE STORY
      //===================================================

      await _storyService.createStory(
        storyId:
        storyId,
        type:
        type,
        mediaUrl:
        mediaUrl,
        mediaUrls:
        mediaUrls,
        text:
        storyText,
        caption:
        _captionController.text
            .trim(),
        backgroundColor:
        _backgroundColor,
        textColor:
        _textColor,
        textStyle:
        _textStyle,
        textAlign:
        _textAlign,
        textSize:
        _textSize,
        durationSeconds:
        durationSeconds,
        layoutCount:
        _layoutCount,
        layoutStyle:
        _layoutStyle,
        taggedPeople:
        _taggedPeople,
        poll:
        poll,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      _showMessage(
        'Unable to post story: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting =
          false;
        });
      }
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      Colors.black,
      appBar:
      AppBar(
        backgroundColor:
        Colors.black,
        title:
        const Text(
          'Create Story',
          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
        actions:
        <Widget>[
          Padding(
            padding:
            const EdgeInsets.only(
              right:
              8,
            ),
            child:
            TextButton(
              onPressed:
              _isPosting
                  ? null
                  : _postStory,
              child:
              _isPosting
                  ? const SizedBox(
                width:
                20,
                height:
                20,
                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                  color:
                  Color(
                    0xFF29B6F6,
                  ),
                ),
              )
                  : const Text(
                'Share',
                style:
                TextStyle(
                  color:
                  Color(
                    0xFF29B6F6,
                  ),
                  fontWeight:
                  FontWeight.bold,
                  fontSize:
                  16,
                ),
              ),
            ),
          ),
        ],
      ),
      body:
      SafeArea(
        child:
        Column(
          children:
          <Widget>[
            _buildModeBar(),

            Expanded(
              child:
              Padding(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  10,
                  6,
                  10,
                  4,
                ),
                child:
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    22,
                  ),
                  child:
                  Container(
                    width:
                    double.infinity,
                    color:
                    Color(
                      _backgroundColor,
                    ),
                    child:
                    Stack(
                      fit:
                      StackFit.expand,
                      children:
                      <Widget>[
                        _buildCanvasContent(),

                        if ((_mode ==
                            'media' ||
                            _mode ==
                                'layout') &&
                            _storyTextController
                                .text
                                .trim()
                                .isNotEmpty)
                          Center(
                            child:
                            Padding(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal:
                                24,
                              ),
                              child:
                              Text(
                                _storyTextController
                                    .text
                                    .trim(),
                                textAlign:
                                _selectedTextAlign,
                                style:
                                _buildTextStyle(),
                              ),
                            ),
                          ),

                        if (_sticker
                            .isNotEmpty)
                          Positioned(
                            top:
                            18,
                            right:
                            18,
                            child:
                            Text(
                              _sticker,
                              style:
                              const TextStyle(
                                fontSize:
                                46,
                              ),
                            ),
                          ),

                        if (_taggedPeople
                            .isNotEmpty)
                          Positioned(
                            left:
                            14,
                            right:
                            14,
                            bottom:
                            14,
                            child:
                            Wrap(
                              spacing:
                              5,
                              runSpacing:
                              5,
                              children:
                              _taggedPeople
                                  .take(
                                5,
                              )
                                  .map(
                                    (
                                    StoryPerson person,
                                    ) {
                                  return Container(
                                    padding:
                                    const EdgeInsets
                                        .symmetric(
                                      horizontal:
                                      8,
                                      vertical:
                                      4,
                                    ),
                                    decoration:
                                    BoxDecoration(
                                      color:
                                      Colors.black54,
                                      borderRadius:
                                      BorderRadius.circular(
                                        15,
                                      ),
                                    ),
                                    child:
                                    Text(
                                      '@${person.username}',
                                      style:
                                      const TextStyle(
                                        color:
                                        Colors.white,
                                        fontSize:
                                        12,
                                      ),
                                    ),
                                  );
                                },
                              ).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            _buildEditingControls(),

            Padding(
              padding:
              const EdgeInsets
                  .fromLTRB(
                12,
                5,
                12,
                10,
              ),
              child:
              TextField(
                controller:
                _captionController,
                maxLength:
                160,
                maxLines:
                1,
                style:
                const TextStyle(
                  color:
                  Colors.white,
                ),
                decoration:
                InputDecoration(
                  counterText:
                  '',
                  hintText:
                  'Add a caption...',
                  hintStyle:
                  const TextStyle(
                    color:
                    Colors.white54,
                  ),
                  filled:
                  true,
                  fillColor:
                  Colors.white10,
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // MODE BAR
  //===================================================

  Widget _buildModeBar() {
    final List<Map<String, dynamic>>
    modes =
    <Map<String, dynamic>>[
      <String, dynamic>{
        'id':
        'media',
        'label':
        'Media',
        'icon':
        Icons
            .photo_camera_back_outlined,
      },
      <String, dynamic>{
        'id':
        'layout',
        'label':
        'Layout',
        'icon':
        Icons
            .grid_view_rounded,
      },
      <String, dynamic>{
        'id':
        'text',
        'label':
        'Text',
        'icon':
        Icons
            .text_fields_rounded,
      },
      <String, dynamic>{
        'id':
        'poll',
        'label':
        'Poll',
        'icon':
        Icons
            .poll_outlined,
      },
      <String, dynamic>{
        'id':
        'voice',
        'label':
        'Voice',
        'icon':
        Icons
            .mic_none_rounded,
      },
    ];

    return SizedBox(
      height:
      68,
      child:
      ListView.builder(
        scrollDirection:
        Axis.horizontal,
        padding:
        const EdgeInsets
            .symmetric(
          horizontal:
          7,
        ),
        itemCount:
        modes.length,
        itemBuilder:
            (
            BuildContext context,
            int index,
            ) {
          final String id =
          modes[index]['id']
          as String;

          final bool selected =
              id ==
                  _mode;

          return InkWell(
            onTap:
                () {
              _selectMode(
                id,
              );
            },
            child:
            Container(
              width:
              72,
              margin:
              const EdgeInsets.all(
                4,
              ),
              decoration:
              BoxDecoration(
                color:
                selected
                    ? const Color(
                  0xFF29B6F6,
                ).withOpacity(
                  0.15,
                )
                    : Colors.transparent,
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
                border:
                Border.all(
                  color:
                  selected
                      ? const Color(
                    0xFF29B6F6,
                  )
                      : Colors.white12,
                ),
              ),
              child:
              Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children:
                <Widget>[
                  Icon(
                    modes[index]['icon']
                    as IconData,
                    color:
                    selected
                        ? const Color(
                      0xFF29B6F6,
                    )
                        : Colors.white70,
                  ),
                  Text(
                    modes[index]['label']
                    as String,
                    style:
                    TextStyle(
                      color:
                      selected
                          ? const Color(
                        0xFF29B6F6,
                      )
                          : Colors.white70,
                      fontSize:
                      11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  //===================================================
  // CANVAS ROUTER
  //===================================================

  Widget _buildCanvasContent() {
    switch (_mode) {
      case 'media':
        return _buildMediaCanvas();

      case 'layout':
        return _buildLayoutCanvas();

      case 'poll':
        return _buildPollCanvas();

      case 'voice':
        return _buildVoiceCanvas();

      case 'text':
      default:
        return _buildTextCanvas();
    }
  }

  //===================================================
  // MEDIA CANVAS
  //===================================================

  Widget _buildMediaCanvas() {
    final XFile? file =
        _mediaFile;

    if (file == null) {
      return _emptyCanvasButton(
        icon:
        Icons
            .add_photo_alternate_outlined,
        label:
        'Choose a photo or video',
        onTap:
        _showMediaPicker,
      );
    }

    return Stack(
      fit:
      StackFit.expand,
      children:
      <Widget>[
        if (_mediaIsVideo)
          _LocalVideoPreview(
            filePath:
            file.path,
          )
        else
          Image.file(
            File(
              file.path,
            ),
            fit:
            BoxFit.cover,
          ),

        Positioned(
          top:
          12,
          left:
          12,
          child:
          _smallGlassButton(
            icon:
            Icons.swap_horiz,
            label:
            'Change',
            onTap:
            _showMediaPicker,
          ),
        ),
      ],
    );
  }

  //===================================================
  // LAYOUT CANVAS
  //===================================================

  Widget _buildLayoutCanvas() {
    if (_layoutFiles.isEmpty) {
      return _emptyCanvasButton(
        icon:
        Icons
            .grid_view_rounded,
        label:
        'Choose 1–4 photos',
        onTap:
        _pickLayoutImages,
      );
    }

    return Stack(
      fit:
      StackFit.expand,
      children:
      <Widget>[
        _buildLayoutPreview(),

        Positioned(
          top:
          12,
          left:
          12,
          child:
          _smallGlassButton(
            icon:
            Icons
                .photo_library_outlined,
            label:
            '${_layoutFiles.length} photo${_layoutFiles.length == 1 ? '' : 's'}',
            onTap:
            _pickLayoutImages,
          ),
        ),

        Positioned(
          top:
          12,
          right:
          12,
          child:
          _smallGlassButton(
            icon:
            Icons
                .dashboard_customize_outlined,
            label:
            '$_layoutCount panels',
            onTap:
            _showLayoutSettings,
          ),
        ),
      ],
    );
  }

  //===================================================
  // LAYOUT PREVIEW
  //===================================================

  Widget _buildLayoutPreview() {
    Widget slot(
        int index,
        ) {
      return Padding(
        padding:
        const EdgeInsets.all(
          1.5,
        ),
        child:
        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            4,
          ),
          child:
          Image.file(
            File(
              _layoutFileForSlot(
                index,
              ).path,
            ),
            fit:
            BoxFit.cover,
            width:
            double.infinity,
            height:
            double.infinity,
          ),
        ),
      );
    }

    //===================================================
    // 2 PANELS
    //===================================================

    if (_layoutCount ==
        2) {
      if (_layoutStyle ==
          'horizontal') {
        return Column(
          children:
          <Widget>[
            Expanded(
              child:
              slot(
                0,
              ),
            ),
            Expanded(
              child:
              slot(
                1,
              ),
            ),
          ],
        );
      }

      return Row(
        children:
        <Widget>[
          Expanded(
            child:
            slot(
              0,
            ),
          ),
          Expanded(
            child:
            slot(
              1,
            ),
          ),
        ],
      );
    }

    //===================================================
    // 3 PANELS
    //===================================================

    if (_layoutCount ==
        3) {
      if (_layoutStyle ==
          'big_left') {
        return Row(
          children:
          <Widget>[
            Expanded(
              flex:
              2,
              child:
              slot(
                0,
              ),
            ),
            Expanded(
              child:
              Column(
                children:
                <Widget>[
                  Expanded(
                    child:
                    slot(
                      1,
                    ),
                  ),
                  Expanded(
                    child:
                    slot(
                      2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      if (_layoutStyle ==
          'three_vertical') {
        return Row(
          children:
          <Widget>[
            for (
            int index = 0;
            index < 3;
            index++
            )
              Expanded(
                child:
                slot(
                  index,
                ),
              ),
          ],
        );
      }

      if (_layoutStyle ==
          'three_horizontal') {
        return Column(
          children:
          <Widget>[
            for (
            int index = 0;
            index < 3;
            index++
            )
              Expanded(
                child:
                slot(
                  index,
                ),
              ),
          ],
        );
      }

      return Column(
        children:
        <Widget>[
          Expanded(
            flex:
            2,
            child:
            slot(
              0,
            ),
          ),
          Expanded(
            child:
            Row(
              children:
              <Widget>[
                Expanded(
                  child:
                  slot(
                    1,
                  ),
                ),
                Expanded(
                  child:
                  slot(
                    2,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    //===================================================
    // 4 PANELS
    //===================================================

    if (_layoutStyle ==
        'four_vertical') {
      return Row(
        children:
        <Widget>[
          for (
          int index = 0;
          index < 4;
          index++
          )
            Expanded(
              child:
              slot(
                index,
              ),
            ),
        ],
      );
    }

    if (_layoutStyle ==
        'four_horizontal') {
      return Column(
        children:
        <Widget>[
          for (
          int index = 0;
          index < 4;
          index++
          )
            Expanded(
              child:
              slot(
                index,
              ),
            ),
        ],
      );
    }

    if (_layoutStyle ==
        'big_left_three') {
      return Row(
        children:
        <Widget>[
          Expanded(
            flex:
            2,
            child:
            slot(
              0,
            ),
          ),
          Expanded(
            child:
            Column(
              children:
              <Widget>[
                Expanded(
                  child:
                  slot(
                    1,
                  ),
                ),
                Expanded(
                  child:
                  slot(
                    2,
                  ),
                ),
                Expanded(
                  child:
                  slot(
                    3,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children:
      <Widget>[
        Expanded(
          child:
          Row(
            children:
            <Widget>[
              Expanded(
                child:
                slot(
                  0,
                ),
              ),
              Expanded(
                child:
                slot(
                  1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
          Row(
            children:
            <Widget>[
              Expanded(
                child:
                slot(
                  2,
                ),
              ),
              Expanded(
                child:
                slot(
                  3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //===================================================
  // TEXT CANVAS
  //===================================================

  Widget _buildTextCanvas() {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal:
          24,
        ),
        child:
        TextField(
          controller:
          _storyTextController,
          maxLength:
          500,
          minLines:
          1,
          maxLines:
          8,
          textAlign:
          _selectedTextAlign,
          onChanged:
              (_) {
            setState(
                  () {},
            );
          },
          style:
          _buildTextStyle(),
          decoration:
          const InputDecoration(
            hintText:
            'Type something...',
            hintStyle:
            TextStyle(
              color:
              Colors.white54,
            ),
            border:
            InputBorder.none,
            counterText:
            '',
          ),
        ),
      ),
    );
  }

  //===================================================
  // POLL CANVAS
  //===================================================

  Widget _buildPollCanvas() {
    return SingleChildScrollView(
      padding:
      const EdgeInsets
          .fromLTRB(
        24,
        50,
        24,
        50,
      ),
      child:
      Column(
        children:
        <Widget>[
          TextField(
            controller:
            _pollQuestionController,
            style:
            const TextStyle(
              color:
              Colors.white,
              fontWeight:
              FontWeight.bold,
              fontSize:
              22,
            ),
            decoration:
            const InputDecoration(
              hintText:
              'Ask a question...',
              hintStyle:
              TextStyle(
                color:
                Colors.white54,
              ),
            ),
          ),

          const SizedBox(
            height:
            20,
          ),

          for (
          int index = 0;
          index <
              _pollOptionControllers
                  .length;
          index++
          )
            Padding(
              padding:
              const EdgeInsets.only(
                bottom:
                10,
              ),
              child:
              Row(
                children:
                <Widget>[
                  Expanded(
                    child:
                    TextField(
                      controller:
                      _pollOptionControllers[
                      index],
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                      ),
                      decoration:
                      InputDecoration(
                        hintText:
                        'Option ${index + 1}',
                        hintStyle:
                        const TextStyle(
                          color:
                          Colors.white54,
                        ),
                        filled:
                        true,
                        fillColor:
                        Colors.white10,
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            15,
                          ),
                          borderSide:
                          BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  if (_pollOptionControllers
                      .length >
                      2)
                    IconButton(
                      onPressed:
                          () {
                        _removePollOption(
                          index,
                        );
                      },
                      icon:
                      const Icon(
                        Icons.close,
                        color:
                        Colors.white70,
                      ),
                    ),
                ],
              ),
            ),

          TextButton.icon(
            onPressed:
            _addPollOption,
            icon:
            const Icon(
              Icons.add,
            ),
            label:
            const Text(
              'Add option',
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // VOICE CANVAS
  //===================================================

  Widget _buildVoiceCanvas() {
    //===================================================
    // NO RECORDING
    //===================================================

    if (_voicePath ==
        null &&
        !_isRecording) {
      return Center(
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children:
          <Widget>[
            GestureDetector(
              onTap:
              _startRecording,
              child:
              Container(
                width:
                128,
                height:
                128,
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFF29B6F6,
                  ).withOpacity(
                    0.16,
                  ),
                  shape:
                  BoxShape.circle,
                  border:
                  Border.all(
                    color:
                    const Color(
                      0xFF29B6F6,
                    ),
                    width:
                    3,
                  ),
                ),
                child:
                const Icon(
                  Icons.mic_rounded,
                  color:
                  Colors.white,
                  size:
                  60,
                ),
              ),
            ),

            const SizedBox(
              height:
              18,
            ),

            const Text(
              'Tap to record',
              style:
              TextStyle(
                color:
                Colors.white,
                fontSize:
                19,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
              6,
            ),

            Text(
              'Maximum ${_formatDuration(Duration(seconds: _maxVoiceSeconds))}',
              style:
              const TextStyle(
                color:
                Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    //===================================================
    // RECORDING
    //===================================================

    if (_isRecording) {
      return Center(
        child:
        Padding(
          padding:
          const EdgeInsets
              .symmetric(
            horizontal:
            18,
          ),
          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,
            children:
            <Widget>[
              GestureDetector(
                onTap:
                _stopRecording,
                child:
                Container(
                  width:
                  120,
                  height:
                  120,
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.red
                        .withOpacity(
                      0.18,
                    ),
                    shape:
                    BoxShape.circle,
                    border:
                    Border.all(
                      color:
                      Colors.redAccent,
                      width:
                      3,
                    ),
                  ),
                  child:
                  const Icon(
                    Icons.stop_rounded,
                    size:
                    57,
                    color:
                    Colors.white,
                  ),
                ),
              ),

              const SizedBox(
                height:
                18,
              ),

              const Text(
                'Recording...',
                style:
                TextStyle(
                  color:
                  Colors.white,
                  fontSize:
                  18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                15,
              ),

              _buildWaveform(
                recording:
                true,
              ),

              const SizedBox(
                height:
                12,
              ),

              //===================================================
              // LIVE MIN:SEC
              //===================================================

              Text(
                _formatDuration(
                  Duration(
                    seconds:
                    _voiceSeconds,
                  ),
                ),
                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize:
                  16,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                4,
              ),

              Text(
                'Maximum ${_formatDuration(Duration(seconds: _maxVoiceSeconds))}',
                style:
                const TextStyle(
                  color:
                  Colors.white54,
                  fontSize:
                  12,
                ),
              ),

              const SizedBox(
                height:
                12,
              ),

              const Text(
                'Tap the red button to stop',
                style:
                TextStyle(
                  color:
                  Colors.white54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    //===================================================
    // PLAY REVIEW
    //===================================================

    return _buildVoiceReview();
  }

  //===================================================
  // VOICE REVIEW
  //===================================================

  Widget _buildVoiceReview() {
    final Duration total =
        _effectiveVoiceDuration;

    return Center(
      child:
      SingleChildScrollView(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal:
          20,
          vertical:
          24,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children:
          <Widget>[
            Container(
              width:
              82,
              height:
              82,
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFF29B6F6,
                ).withOpacity(
                  0.15,
                ),
                shape:
                BoxShape.circle,
              ),
              child:
              const Icon(
                Icons
                    .graphic_eq_rounded,
                size:
                46,
                color:
                Color(
                  0xFF29B6F6,
                ),
              ),
            ),

            const SizedBox(
              height:
              12,
            ),

            const Text(
              'Play Review',
              style:
              TextStyle(
                color:
                Colors.white,
                fontSize:
                19,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
              14,
            ),

            _buildWaveform(
              recording:
              false,
            ),

            const SizedBox(
              height:
              16,
            ),

            Container(
              padding:
              const EdgeInsets
                  .fromLTRB(
                12,
                12,
                12,
                10,
              ),
              decoration:
              BoxDecoration(
                color:
                Colors.black
                    .withOpacity(
                  0.28,
                ),
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
                border:
                Border.all(
                  color:
                  Colors.white12,
                ),
              ),
              child:
              Row(
                children:
                <Widget>[
                  //===================================================
                  // PLAY / PAUSE
                  //===================================================

                  GestureDetector(
                    onTap:
                    _toggleVoicePreview,
                    child:
                    Container(
                      width:
                      48,
                      height:
                      48,
                      decoration:
                      const BoxDecoration(
                        color:
                        Color(
                          0xFF29B6F6,
                        ),
                        shape:
                        BoxShape.circle,
                      ),
                      child:
                      Icon(
                        _isVoicePlaying
                            ? Icons.pause_rounded
                            : _voiceCompleted
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded,
                        size:
                        32,
                        color:
                        Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width:
                    10,
                  ),

                  //===================================================
                  // SLIDER + TIME
                  //===================================================

                  Expanded(
                    child:
                    Column(
                      children:
                      <Widget>[
                        SliderTheme(
                          data:
                          SliderTheme.of(
                            context,
                          ).copyWith(
                            trackHeight:
                            4,
                            thumbShape:
                            const RoundSliderThumbShape(
                              enabledThumbRadius:
                              7,
                            ),
                            overlayShape:
                            const RoundSliderOverlayShape(
                              overlayRadius:
                              14,
                            ),
                            activeTrackColor:
                            const Color(
                              0xFF29B6F6,
                            ),
                            thumbColor:
                            const Color(
                              0xFF29B6F6,
                            ),
                            inactiveTrackColor:
                            Colors.white24,
                          ),
                          child:
                          Slider(
                            min:
                            0,
                            max:
                            1,
                            value:
                            _voiceSliderValue,
                            onChanged:
                            _seekVoice,
                          ),
                        ),

                        Padding(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal:
                            5,
                          ),
                          child:
                          Row(
                            children:
                            <Widget>[
                              Text(
                                _formatDuration(
                                  _voicePosition,
                                ),
                                style:
                                const TextStyle(
                                  color:
                                  Colors.white70,
                                  fontSize:
                                  12,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),

                              const Spacer(),

                              Text(
                                _formatDuration(
                                  total,
                                ),
                                style:
                                const TextStyle(
                                  color:
                                  Colors.white70,
                                  fontSize:
                                  12,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height:
              20,
            ),

            Row(
              children:
              <Widget>[
                Expanded(
                  child:
                  OutlinedButton.icon(
                    style:
                    OutlinedButton
                        .styleFrom(
                      foregroundColor:
                      Colors.white,
                      side:
                      const BorderSide(
                        color:
                        Colors.white38,
                      ),
                      padding:
                      const EdgeInsets
                          .symmetric(
                        vertical:
                        13,
                      ),
                    ),
                    onPressed:
                    _startRecording,
                    icon:
                    const Icon(
                      Icons
                          .refresh_rounded,
                    ),
                    label:
                    const Text(
                      'Record Again',
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  10,
                ),

                Expanded(
                  child:
                  OutlinedButton.icon(
                    style:
                    OutlinedButton
                        .styleFrom(
                      foregroundColor:
                      Colors.redAccent,
                      side:
                      const BorderSide(
                        color:
                        Colors.redAccent,
                      ),
                      padding:
                      const EdgeInsets
                          .symmetric(
                        vertical:
                        13,
                      ),
                    ),
                    onPressed:
                    _deleteVoiceRecording,
                    icon:
                    const Icon(
                      Icons
                          .delete_outline_rounded,
                    ),
                    label:
                    const Text(
                      'Delete',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // WAVEFORM
  //===================================================

  Widget _buildWaveform({
    required bool recording,
  }) {
    return SizedBox(
      height:
      62,
      child:
      Row(
        mainAxisAlignment:
        MainAxisAlignment.center,
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children:
        _waveformHeights.map(
              (
              double height,
              ) {
            return AnimatedContainer(
              duration:
              const Duration(
                milliseconds:
                100,
              ),
              width:
              3,
              height:
              recording
                  ? height
                  : height
                  .clamp(
                10,
                48,
              )
                  .toDouble(),
              margin:
              const EdgeInsets
                  .symmetric(
                horizontal:
                2,
              ),
              decoration:
              BoxDecoration(
                color:
                recording
                    ? Colors.redAccent
                    : const Color(
                  0xFF29B6F6,
                ),
                borderRadius:
                BorderRadius.circular(
                  5,
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  //===================================================
  // EDITING CONTROLS
  //===================================================

  Widget _buildEditingControls() {
    return SizedBox(
      height:
      58,
      child:
      ListView(
        scrollDirection:
        Axis.horizontal,
        padding:
        const EdgeInsets
            .symmetric(
          horizontal:
          8,
        ),
        children:
        <Widget>[
          _controlButton(
            icon:
            Icons
                .person_add_alt,
            label:
            'Tag',
            onTap:
            _pickTaggedPeople,
          ),

          _controlButton(
            icon:
            Icons
                .emoji_emotions_outlined,
            label:
            'Sticker',
            onTap:
            _showStickers,
          ),

          if (_mode ==
              'layout')
            _controlButton(
              icon:
              Icons
                  .dashboard_customize_outlined,
              label:
              'Layout',
              onTap:
              _showLayoutSettings,
            ),

          _controlButton(
            icon:
            Icons
                .format_align_center,
            label:
            'Align',
            onTap:
            _cycleTextAlignment,
          ),

          _controlButton(
            icon:
            Icons.format_bold,
            label:
            'Style',
            onTap:
            _cycleTextStyle,
          ),

          _controlButton(
            icon:
            Icons
                .palette_outlined,
            label:
            'Background',
            onTap:
            _cycleBackgroundColor,
          ),

          _controlButton(
            icon:
            Icons
                .format_color_text,
            label:
            'Text',
            onTap:
            _cycleTextColor,
          ),
        ],
      ),
    );
  }

  //===================================================
  // CONTROL BUTTON
  //===================================================

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap:
      onTap,
      child:
      Container(
        width:
        78,
        margin:
        const EdgeInsets
            .symmetric(
          horizontal:
          3,
          vertical:
          5,
        ),
        child:
        Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children:
          <Widget>[
            Icon(
              icon,
              color:
              Colors.white70,
              size:
              21,
            ),
            const SizedBox(
              height:
              2,
            ),
            Text(
              label,
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
    );
  }

  //===================================================
  // GLASS BUTTON
  //===================================================

  Widget _smallGlassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
      Colors.black54,
      borderRadius:
      BorderRadius.circular(
        18,
      ),
      child:
      InkWell(
        onTap:
        onTap,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        child:
        Padding(
          padding:
          const EdgeInsets
              .symmetric(
            horizontal:
            10,
            vertical:
            7,
          ),
          child:
          Row(
            mainAxisSize:
            MainAxisSize.min,
            children:
            <Widget>[
              Icon(
                icon,
                color:
                Colors.white,
                size:
                16,
              ),
              const SizedBox(
                width:
                5,
              ),
              Text(
                label,
                style:
                const TextStyle(
                  color:
                  Colors.white,
                  fontSize:
                  11,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //===================================================
  // EMPTY CANVAS BUTTON
  //===================================================

  Widget _emptyCanvasButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Center(
      child:
      InkWell(
        onTap:
        onTap,
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children:
          <Widget>[
            Icon(
              icon,
              color:
              Colors.white70,
              size:
              58,
            ),
            const SizedBox(
              height:
              12,
            ),
            Text(
              label,
              style:
              const TextStyle(
                color:
                Colors.white,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // TEXT STYLE
  //===================================================

  TextStyle _buildTextStyle() {
    return TextStyle(
      color:
      Color(
        _textColor,
      ),
      fontSize:
      _textSize,
      fontWeight:
      _textStyle ==
          'bold'
          ? FontWeight.w800
          : FontWeight.w500,
      fontStyle:
      _textStyle ==
          'italic'
          ? FontStyle.italic
          : FontStyle.normal,
      fontFamily:
      _textStyle ==
          'mono'
          ? 'monospace'
          : null,
      shadows:
      const <Shadow>[
        Shadow(
          color:
          Colors.black45,
          blurRadius:
          5,
        ),
      ],
    );
  }

  //===================================================
  // TEXT ALIGN
  //===================================================

  TextAlign get _selectedTextAlign {
    switch (_textAlign) {
      case 'left':
        return TextAlign.left;

      case 'right':
        return TextAlign.right;

      default:
        return TextAlign.center;
    }
  }

  //===================================================
  // CYCLE ALIGNMENT
  //===================================================

  void _cycleTextAlignment() {
    setState(() {
      if (_textAlign ==
          'center') {
        _textAlign =
        'left';
      } else if (_textAlign ==
          'left') {
        _textAlign =
        'right';
      } else {
        _textAlign =
        'center';
      }
    });
  }

  //===================================================
  // CYCLE STYLE
  //===================================================

  void _cycleTextStyle() {
    setState(() {
      switch (_textStyle) {
        case 'bold':
          _textStyle =
          'italic';
          break;

        case 'italic':
          _textStyle =
          'mono';
          break;

        default:
          _textStyle =
          'bold';
      }
    });
  }

  //===================================================
  // CYCLE BACKGROUND
  //===================================================

  void _cycleBackgroundColor() {
    int index =
    _backgroundColors.indexOf(
      _backgroundColor,
    );

    if (index <
        0) {
      index =
      0;
    }

    setState(() {
      _backgroundColor =
      _backgroundColors[
      (index + 1) %
          _backgroundColors.length
      ];
    });
  }

  //===================================================
  // CYCLE TEXT COLOR
  //===================================================

  void _cycleTextColor() {
    int index =
    _textColors.indexOf(
      _textColor,
    );

    if (index <
        0) {
      index =
      0;
    }

    setState(() {
      _textColor =
      _textColors[
      (index + 1) %
          _textColors.length
      ];
    });
  }

  //===================================================
  // FORMAT DURATION
  //
  // THIS IS WHAT DISPLAYS:
  // 0:01
  // 1:05
  // 2:30
  // 5:00
  //===================================================

  String _formatDuration(
      Duration duration,
      ) {
    int seconds =
        duration.inSeconds;

    if (seconds <
        0) {
      seconds =
      0;
    }

    final int minutes =
        seconds ~/
            60;

    final int remaining =
        seconds %
            60;

    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  //===================================================
  // MESSAGE
  //===================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _voiceTimer?.cancel();

    _waveformTimer?.cancel();

    _voicePositionSubscription
        ?.cancel();

    _voiceDurationSubscription
        ?.cancel();

    _audioCompleteSubscription
        ?.cancel();

    _audioPlayer.dispose();

    _audioRecorder.dispose();

    _storyTextController.dispose();

    _captionController.dispose();

    _pollQuestionController.dispose();

    for (
    final TextEditingController controller
    in _pollOptionControllers
    ) {
      controller.dispose();
    }

    super.dispose();
  }
}

//===================================================
// LOCAL VIDEO PREVIEW
//===================================================

class _LocalVideoPreview
    extends StatefulWidget {
  const _LocalVideoPreview({
    required this.filePath,
  });

  final String filePath;

  @override
  State<_LocalVideoPreview> createState() =>
      _LocalVideoPreviewState();
}

class _LocalVideoPreviewState
    extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;

  bool _loading =
  true;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  //===================================================
  // INITIALIZE
  //===================================================

  Future<void> _initialize() async {
    try {
      final VideoPlayerController controller =
      VideoPlayerController.file(
        File(
          widget.filePath,
        ),
      );

      await controller.initialize();

      await controller.setLooping(
        true,
      );

      await controller.setVolume(
        1,
      );

      await controller.play();

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _controller =
            controller;

        _loading =
        false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
        false;
      });
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final VideoPlayerController? controller =
        _controller;

    if (_loading ||
        controller ==
            null ||
        !controller
            .value
            .isInitialized) {
      return const Center(
        child:
        CircularProgressIndicator(
          color:
          Colors.white,
        ),
      );
    }

    return GestureDetector(
      onTap:
          () {
        if (controller
            .value
            .isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }

        setState(
              () {},
        );
      },
      child:
      Center(
        child:
        AspectRatio(
          aspectRatio:
          controller
              .value
              .aspectRatio,
          child:
          VideoPlayer(
            controller,
          ),
        ),
      ),
    );
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _controller?.dispose();

    super.dispose();
  }
}
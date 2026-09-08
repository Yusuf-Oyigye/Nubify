import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart'
as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'universal_link_composer_preview.dart';

//===============================
// CHAT COMPOSER
//===============================

class ChatComposer
    extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onCamera,
    required this.onGallery,
    required this.onVideo,
    required this.onDocument,
    required this.onVoiceRecorded,
    required this.onStickerSelected,
    this.onTextChanged,
    this.onRecordingChanged,
    this.enabled = true,
    this.onLinkPreviewSuppressedChanged,
  });

  final ValueChanged<bool>?
  onLinkPreviewSuppressedChanged;
  final TextEditingController
  controller;

  final bool sending;

  final bool enabled;

  final Future<void> Function()
  onSend;

  final Future<void> Function()
  onCamera;

  final Future<void> Function()
  onGallery;

  final Future<void> Function()
  onVideo;

  final Future<void> Function()
  onDocument;

  final Future<void> Function(
      String path,
      int durationMs,
      ) onVoiceRecorded;

  final Future<void> Function(
      String sticker,
      ) onStickerSelected;

  final ValueChanged<String>?
  onTextChanged;

  final ValueChanged<bool>?
  onRecordingChanged;

  @override
  State<ChatComposer>
  createState() =>
      _ChatComposerState();
}

//===============================
// CHAT COMPOSER STATE
//===============================

class _ChatComposerState
    extends State<
        ChatComposer> {
  final AudioRecorder
  _recorder =
  AudioRecorder();
  //===============================
 // STICKER EMOJI CONTROLLER
 //===============================

  final TextEditingController
  _stickerEmojiController =
  TextEditingController();

  bool _showEmoji =
  false;

  bool _showStickers =
  false;

  bool _recording =
  false;
  bool _recordingPaused = false;
  bool _pauseActionBusy = false;
  bool _processingVoice =
  false;

  int _recordSeconds =
  0;

  String _recordPath =
      '';

  Timer? _recordTimer;

  static const List<String>
  _stickers =
  <String>[
    '😂',
    '🤣',
    '😭',
    '🥹',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤓',
    '🥳',
    '🤯',
    '😡',
    '🤬',
    '😴',
    '🤔',
    '🫡',
    '🤝',
    '👏',
    '🙌',
    '🙏',
    '👍',
    '👎',
    '❤️',
    '💔',
    '🔥',
    '💯',
    '🎉',
    '✨',
    '😹',
    '🙈',
  ];

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();

    widget.controller
        .addListener(
      _controllerChanged,
    );
  }

  //===============================
  // CONTROLLER CHANGED
  //===============================

  void _controllerChanged() {
    if (!mounted || _recordingPaused) {
      return;
    }

    setState(() {});

    widget.onTextChanged
        ?.call(
      widget.controller.text,
    );
  }

  //===============================
  // TOGGLE EMOJI
  //===============================

  void _toggleEmoji() {
    if (!widget.enabled) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _showEmoji =
      !_showEmoji;

      _showStickers =
      false;
    });
  }

  //===============================
  // TOGGLE STICKERS
  //===============================

  void _toggleStickers() {
    if (!widget.enabled) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _showStickers =
      !_showStickers;

      _showEmoji =
      false;
    });
  }

  //===============================
  // ATTACHMENT SHEET
  //===============================

  Future<void>
  _showAttachments() async {
    if (!widget.enabled) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _showEmoji =
      false;

      _showStickers =
      false;
    });

    await showModalBottomSheet<void>(
      context:
      context,
      backgroundColor:
      const Color(
        0xFF141B21,
      ),
      showDragHandle:
      true,
      builder:
          (
          BuildContext context,
          ) {
        return SafeArea(
          child:
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              18,
              0,
              18,
              20,
            ),
            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,
              children:
              <Widget>[
                const Align(
                  alignment:
                  Alignment.centerLeft,
                  child:
                  Text(
                    'Send attachment',
                    style:
                    TextStyle(
                      color:
                      Colors.white,
                      fontSize:
                      18,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                  18,
                ),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceAround,
                  children:
                  <Widget>[
                    _AttachmentButton(
                      icon:
                      Icons
                          .photo_camera_rounded,
                      label:
                      'Camera',
                      color:
                      const Color(
                        0xFF29B6F6,
                      ),
                      onTap:
                          () async {
                        Navigator.pop(
                          context,
                        );

                        await widget
                            .onCamera();
                      },
                    ),

                    _AttachmentButton(
                      icon:
                      Icons
                          .photo_library_rounded,
                      label:
                      'Gallery',
                      color:
                      const Color(
                        0xFF8E7CFF,
                      ),
                      onTap:
                          () async {
                        Navigator.pop(
                          context,
                        );

                        await widget
                            .onGallery();
                      },
                    ),

                    _AttachmentButton(
                      icon:
                      Icons
                          .videocam_rounded,
                      label:
                      'Video',
                      color:
                      const Color(
                        0xFFFF6B81,
                      ),
                      onTap:
                          () async {
                        Navigator.pop(
                          context,
                        );

                        await widget
                            .onVideo();
                      },
                    ),

                    _AttachmentButton(
                      icon:
                      Icons
                          .description_rounded,
                      label:
                      'Document',
                      color:
                      const Color(
                        0xFFFFB74D,
                      ),
                      onTap:
                          () async {
                        Navigator.pop(
                          context,
                        );

                        await widget
                            .onDocument();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //===============================
  // START RECORDING
  //===============================

  Future<void>
  _startRecording() async {
    if (!widget.enabled ||
        _processingVoice ||
        widget.sending) {
      return;
    }

    try {
      final bool permitted =
      await _recorder
          .hasPermission();

      if (!permitted) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content:
            Text(
              'Microphone permission is required for voice messages.',
            ),
          ),
        );

        return;
      }

      final directory =
      await getTemporaryDirectory();

      final String path =
          '${directory.path}/nubify_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder:
          AudioEncoder.aacLc,

          bitRate:
          128000,

          sampleRate:
          44100,

          numChannels:
          1,

          //===============================
          // ANDROID AUDIO
          //===============================

          androidConfig:
          AndroidRecordConfig(
            manageBluetooth:
            true,
          ),
        ),

        path:
        path,
      );

      _recordPath =
          path;

      _recordSeconds =
      0;

      _recordTimer
          ?.cancel();

      _recordTimer =
          Timer.periodic(
            const Duration(
              seconds:
              1,
            ),
                (_) {
              if (!mounted) {
                return;
              }

              setState(() {
                _recordSeconds++;
              });
            },
          );

      widget
          .onRecordingChanged
          ?.call(
        true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recording =
        true;

        _showEmoji =
        false;

        _showStickers =
        false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
          Text(
            'Could not start recording: $error',
          ),
        ),
      );
    }
  }
//===================================================
// PAUSE AND RESUME VOICE RECORDING
//===================================================

  Future<void> _toggleRecordingPause() async {
    if (!_recording ||
        _processingVoice ||
        _pauseActionBusy) {
      return;
    }

    setState(() {
      _pauseActionBusy = true;
    });

    try {
      if (_recordingPaused) {
        // Continue recording into the same audio file.
        await _recorder.resume();

        if (mounted) {
          setState(() {
            _recordingPaused = false;
          });
        }
      } else {
        // Temporarily stop capturing audio.
        await _recorder.pause();

        if (mounted) {
          setState(() {
            _recordingPaused = true;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to pause or resume recording: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pauseActionBusy = false;
        });
      }
    }
  }
  //===============================
  // CANCEL RECORDING
  //===============================

  Future<void>
  _cancelRecording() async {
    if (!_recording) {
      return;
    }

    _recordTimer
        ?.cancel();

    _recordTimer =
    null;

    try {
      await _recorder
          .cancel();
    } catch (_) {}

    widget
        .onRecordingChanged
        ?.call(
      false,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _recording =
      false;
      _recordingPaused = false;

      _recordSeconds =
      0;

      _recordPath =
      '';
    });
  }

  //===============================
  // STOP AND SEND RECORDING
  //===============================

  Future<void>
  _stopAndSendRecording() async {
    if (!_recording ||
        _processingVoice) {
      return;
    }

    setState(() {
      _processingVoice =
      true;
    });

    _recordTimer
        ?.cancel();

    _recordTimer =
    null;

    try {
      final String? path =
      await _recorder
          .stop();

      widget
          .onRecordingChanged
          ?.call(
        false,
      );

      final int durationMs =
          _recordSeconds *
              1000;

      final String finalPath =
      (path ?? _recordPath)
          .trim();

      if (finalPath.isNotEmpty) {
        // Allow M4A/AAC to finish writing.
        await Future<void>.delayed(
          const Duration(
            milliseconds:
            120,
          ),
        );

        final File file =
        File(
          finalPath,
        );

        if (!await file.exists() ||
            await file.length() <
                100) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(
              const SnackBar(
                content:
                Text(
                  'Voice recording could not be saved correctly. Please try again.',
                ),
              ),
            );
          }

          return;
        }

        final int safeDurationMs =
        durationMs >
            0
            ? durationMs
            : 1000;

        await widget
            .onVoiceRecorded(
          finalPath,

          safeDurationMs,
        );
      }
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _recording =
        false;
        _recordingPaused = false;
        _processingVoice =
        false;

        _recordSeconds =
        0;
        _recordingPaused = false;
        _recordPath =
        '';
      });
    }
  }

  //===============================
  // FORMAT RECORD TIME
  //===============================

  String _recordTime() {
    final int minutes =
        _recordSeconds ~/
            60;

    final int seconds =
        _recordSeconds %
            60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  //===============================
  // SEND TEXT
  //===============================

  Future<void>
  _sendText() async {
    if (!widget.enabled ||
        widget.sending ||
        widget.controller.text
            .trim()
            .isEmpty) {
      return;
    }

    await widget.onSend();
  }

  //===============================
// STICKER PANEL
//===============================

  Widget _buildStickerPanel() {
    return Container(
      height:
      330,
      decoration:
      const BoxDecoration(
        color:
        Color(
          0xFF11181E,
        ),
        border:
        Border(
          top:
          BorderSide(
            color:
            Colors.white10,
          ),
        ),
      ),
      child:
      EmojiPicker(
        textEditingController:
        _stickerEmojiController,

        onEmojiSelected:
            (
            Category? category,
            Emoji emoji,
            ) async {
          HapticFeedback
              .selectionClick();

          await widget
              .onStickerSelected(
            emoji.emoji,
          );

          _stickerEmojiController
              .clear();
        },

        config:
        Config(
          height:
          330,

          checkPlatformCompatibility:
          true,

          emojiViewConfig:
          EmojiViewConfig(
            emojiSizeMax:
            34 *
                (foundation.defaultTargetPlatform ==
                    TargetPlatform.iOS
                    ? 1.20
                    : 1.0),
          ),

          viewOrderConfig:
          const ViewOrderConfig(
            top:
            EmojiPickerItem
                .categoryBar,

            middle:
            EmojiPickerItem
                .emojiView,

            bottom:
            EmojiPickerItem
                .searchBar,
          ),

          skinToneConfig:
          const SkinToneConfig(),

          categoryViewConfig:
          const CategoryViewConfig(),

          bottomActionBarConfig:
          const BottomActionBarConfig(),

          searchViewConfig:
          const SearchViewConfig(),
        ),
      ),
    );
  }

  //===============================
  // EMOJI PANEL
  //===============================

  Widget _buildEmojiPanel() {
    return Container(
      color:
      const Color(
        0xFF11181E,
      ),
      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,
        children:
        <Widget>[
          SizedBox(
            height:
            38,
            child:
            Row(
              children:
              <Widget>[
                const SizedBox(
                  width:
                  10,
                ),

                TextButton.icon(
                  onPressed:
                  _toggleStickers,
                  icon:
                  const Icon(
                    Icons
                        .auto_awesome_rounded,
                    size:
                    18,
                  ),
                  label:
                  const Text(
                    'Stickers',
                  ),
                ),
              ],
            ),
          ),

          EmojiPicker(
            textEditingController:
            widget.controller,
            onEmojiSelected:
                (
                Category?
                category,
                Emoji emoji,
                ) {
              HapticFeedback
                  .selectionClick();
            },
            config:
            Config(
              height:
              275,
              checkPlatformCompatibility:
              true,
              emojiViewConfig:
              EmojiViewConfig(
                emojiSizeMax:
                28 *
                    (foundation.defaultTargetPlatform ==
                        TargetPlatform.iOS
                        ? 1.20
                        : 1.0),
              ),
              viewOrderConfig:
              const ViewOrderConfig(
                top:
                EmojiPickerItem
                    .categoryBar,
                middle:
                EmojiPickerItem
                    .emojiView,
                bottom:
                EmojiPickerItem
                    .searchBar,
              ),
              skinToneConfig:
              const SkinToneConfig(),
              categoryViewConfig:
              const CategoryViewConfig(),
              bottomActionBarConfig:
              const BottomActionBarConfig(),
              searchViewConfig:
              const SearchViewConfig(),
            ),
          ),
        ],
      ),
    );
  }


  //===================================================
  // VOICE RECORDING BAR WITH PAUSE AND RESUME
  //===================================================

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: const BoxDecoration(
        color: Color(0xFF16232B),
        border: Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: <Widget>[
          //===================================================
          // RECORDING INDICATOR
          //===================================================

          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _recordingPaused
                  ? Colors.white38
                  : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 9),

          //===================================================
          // VOICE RECORDING DURATION
          //===================================================

          Text(
            _recordTime(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(width: 10),

          //===================================================
          // RECORDING STATUS
          //===================================================

          Expanded(
            child: Text(
              _recordingPaused
                  ? 'Paused'
                  : 'Recording voice note...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ),

          //===================================================
          // PAUSE OR RESUME BUTTON
          //===================================================

          IconButton(
            tooltip: _recordingPaused
                ? 'Resume recording'
                : 'Pause recording',
            onPressed: _processingVoice || _pauseActionBusy
                ? null
                : _toggleRecordingPause,
            icon: Icon(
              _recordingPaused
                  ? Icons.play_circle_fill_rounded
                  : Icons.pause_circle_filled_rounded,
              color: const Color(0xFF29B6F6),
              size: 28,
            ),
          ),

          //===================================================
          // DELETE RECORDING
          //===================================================

          IconButton(
            tooltip: 'Delete recording',
            onPressed: _processingVoice || _pauseActionBusy
                ? null
                : _cancelRecording,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
          ),

          //===================================================
          // SEND RECORDING
          //===================================================

          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF29B6F6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Send voice note',
              onPressed: _processingVoice || _pauseActionBusy
                  ? null
                  : _stopAndSendRecording,
              icon: _processingVoice
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.send_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===============================
  // MAIN INPUT
  //===============================

  Widget _buildMainInput() {
    final bool hasText =
        widget.controller.text
            .trim()
            .isNotEmpty;

    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        7,
        6,
        7,
        7,
      ),
      decoration:
      const BoxDecoration(
        color:
        Color(
          0xFF0E151A,
        ),
        border:
        Border(
          top:
          BorderSide(
            color:
            Colors.white10,
          ),
        ),
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children:
        <Widget>[
          IconButton(
            onPressed:
            widget.enabled
                ? _toggleStickers
                : null,
            icon:
            Icon(
              _showStickers
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_outlined,

              color:
              _showStickers
                  ? const Color(
                0xFF29B6F6,
              )
                  : Colors.white70,
            ),
          ),

          IconButton(
            onPressed:
            widget.enabled
                ? _showAttachments
                : null,
            icon:
            const Icon(
              Icons
                  .photo_camera_outlined,
              color:
              Colors.white70,
            ),
          ),

          Expanded(
            child:
            Container(
              constraints:
              const BoxConstraints(
                minHeight:
                44,
              ),
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFF20282E,
                ),
                borderRadius:
                BorderRadius.circular(
                  24,
                ),
              ),
              child:
              TextField(
                controller:
                widget.controller,
                enabled:
                widget.enabled,
                minLines:
                1,
                maxLines:
                5,
                keyboardType:
                TextInputType
                    .multiline,
                textCapitalization:
                TextCapitalization
                    .sentences,
                decoration:
                const InputDecoration(
                  hintText:
                  'Message...',
                  hintStyle:
                  TextStyle(
                    color:
                    Colors.white38,
                  ),
                  border:
                  InputBorder
                      .none,
                  contentPadding:
                  EdgeInsets.symmetric(
                    horizontal:
                    15,
                    vertical:
                    11,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            width:
            5,
          ),

          if (hasText)
            Container(
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
              IconButton(
                onPressed:
                widget.sending ||
                    !widget
                        .enabled
                    ? null
                    : _sendText,
                icon:
                widget.sending
                    ? const SizedBox(
                  width:
                  18,
                  height:
                  18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                    color:
                    Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .send_rounded,
                  color:
                  Colors.white,
                ),
              ),
            )
          else
            Container(
              decoration:
              BoxDecoration(
                color:
                widget.enabled
                    ? const Color(
                  0xFF29B6F6,
                )
                    : Colors.white12,
                shape:
                BoxShape.circle,
              ),
              child:
              IconButton(
                onPressed:
                widget.enabled
                    ? _startRecording
                    : null,
                icon:
                const Icon(
                  Icons.mic_rounded,
                  color:
                  Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      mainAxisSize:
      MainAxisSize.min,

      children:
      <Widget>[
        if (!_recording)
          UniversalLinkComposerPreview(
            controller:
            widget.controller,

            onSuppressedChanged:
            widget
                .onLinkPreviewSuppressedChanged,
          ),

        if (_recording)
          _buildRecordingBar()
        else
          _buildMainInput(),

        if (!_recording &&
            _showStickers)
          _buildStickerPanel(),
      ],
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    widget.controller
        .removeListener(
      _controllerChanged,
    );

    _recordTimer
        ?.cancel();

    _recorder.dispose();

    _stickerEmojiController
        .dispose();

    super.dispose();
  }
}

//===============================
// ATTACHMENT BUTTON
//===============================

class _AttachmentButton
    extends StatelessWidget {
  const _AttachmentButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;

  final String label;

  final Color color;

  final VoidCallback onTap;

  @override
  Widget build(
      BuildContext context,
      ) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(
        16,
      ),
      onTap:
      onTap,
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          7,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children:
          <Widget>[
            Container(
              width:
              54,
              height:
              54,
              decoration:
              BoxDecoration(
                color:
                color.withOpacity(
                  0.16,
                ),
                borderRadius:
                BorderRadius.circular(
                  17,
                ),
              ),
              child:
              Icon(
                icon,
                color:
                color,
                size:
                27,
              ),
            ),
            const SizedBox(
              height:
              6,
            ),
            Text(
              label,
              style:
              const TextStyle(
                color:
                Colors.white70,
                fontSize:
                11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
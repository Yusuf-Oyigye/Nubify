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
import '../services/story_sticker_service.dart';
import 'story_people_picker_screen.dart';
import '../widgets/draggable_story_tags.dart';
import '../widgets/story_link_preview_overlay.dart';

//===================================================
// CREATE STORY SCREEN
//===================================================

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({
    super.key,
    this.initialLinkUrl = '',
    this.initialText = '',
    this.initialCaption = '',
    this.initialBackgroundColor = 0xFF102A43,
  });

  final String initialLinkUrl;
  final String initialText;
  final String initialCaption;
  final int initialBackgroundColor;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

//===================================================
// CREATE STORY STATE
//===================================================

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  //===================================================
  // STORY LINK STATE
  //===================================================

  String _storyLinkUrl = '';

  String _storyLinkStyle = 'medium';

  double _storyLinkX = 0.50;

  double _storyLinkY = 0.52;

  double _storyLinkScale = 1.0;
  //===================================================
  // OPEN STORY LINK PICKER
  //===================================================

  Future<void> _openStoryLinkPicker() async {
    final TextEditingController controller = TextEditingController(
      text: _storyLinkUrl,
    );

    String style = _storyLinkStyle;

    final Map<String, String>?
    result = await showModalBottomSheet<Map<String, String>>(
      context: context,

      isScrollControlled: true,

      backgroundColor: const Color(0xFF151D23),

      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setSheetState,
              ) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 18,
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: <Widget>[
                      const Text(
                        'Add link',

                        style: TextStyle(
                          color: Colors.white,

                          fontSize: 20,

                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: controller,

                        keyboardType: TextInputType.url,

                        decoration: const InputDecoration(
                          hintText: 'https://example.com',

                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Wrap(
                        spacing: 8,

                        children: <Widget>[
                          for (final String option in <String>[
                            'compact',
                            'medium',
                            'large',
                          ])
                            ChoiceChip(
                              label: Text(
                                option[0].toUpperCase() + option.substring(1),
                              ),

                              selected: style == option,

                              onSelected: (_) {
                                setSheetState(() {
                                  style = option;
                                });
                              },
                            ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: <Widget>[
                          if (_storyLinkUrl.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(sheetContext, <String, String>{
                                  'url': '',

                                  'style': style,
                                });
                              },

                              child: const Text('Remove'),
                            ),

                          const Spacer(),

                          FilledButton(
                            onPressed: () {
                              Navigator.pop(sheetContext, <String, String>{
                                'url': controller.text.trim(),

                                'style': style,
                              });
                            },

                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
        );
      },
    );

    controller.dispose();

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _storyLinkUrl = result['url'] ?? '';

      _storyLinkStyle = result['style'] ?? 'medium';
    });
  }
  //===================================================
  // SERVICES
  //===================================================

  final StoryService _storyService = StoryService();

  final StoryStickerService _storyStickerService = StoryStickerService();

  final ImagePicker _imagePicker = ImagePicker();

  final AudioRecorder _audioRecorder = AudioRecorder();

  final AudioPlayer _audioPlayer = AudioPlayer();

  //===================================================
  // CONTROLLERS
  //===================================================

  final TextEditingController _storyTextController = TextEditingController();

  final TextEditingController _captionController = TextEditingController();

  final TextEditingController _pollQuestionController = TextEditingController();

  final List<TextEditingController> _pollOptionControllers =
      <TextEditingController>[TextEditingController(), TextEditingController()];

  //===================================================
  // MODE
  //===================================================

  String _mode = 'media';

  //===================================================
  // MEDIA
  //===================================================

  XFile? _mediaFile;

  bool _mediaIsVideo = false;

  int _mediaVideoDurationSeconds = 15;

  //===================================================
  // LAYOUT
  //===================================================

  List<XFile> _layoutFiles = <XFile>[];

  int _layoutCount = 2;

  String _layoutStyle = 'vertical';

  //===================================================
  // POST
  //===================================================

  bool _isPosting = false;

  //===================================================
  // VOICE RECORDING
  //===================================================

  bool _isRecording = false;

  String? _voicePath;

  int _voiceSeconds = 0;

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

  static const int _voiceLimitMinutes = 3;

  static const int _voiceLimitSeconds = 0;

  static const int _maxVoiceSeconds =
      (_voiceLimitMinutes * 60) + _voiceLimitSeconds;

  Timer? _voiceTimer;

  Timer? _waveformTimer;

  //===================================================
  // VOICE PLAYER
  //===================================================

  bool _isVoicePlaying = false;

  bool _isVoicePaused = false;

  bool _voiceCompleted = false;

  Duration _voicePosition = Duration.zero;

  Duration _voiceDuration = Duration.zero;

  StreamSubscription<Duration>? _voicePositionSubscription;

  StreamSubscription<Duration>? _voiceDurationSubscription;

  StreamSubscription<void>? _audioCompleteSubscription;

  //===================================================
  // WAVEFORM
  //===================================================

  final List<double> _waveformHeights = List<double>.filled(22, 10);

  //===================================================
  // DESIGN
  //===================================================

  int _backgroundColor = 0xFF101114;

  int _textColor = 0xFFFFFFFF;

  String _textStyle = 'bold';

  String _textAlign = 'center';

  final double _textSize = 34;

  String _sticker = '';
  //=============================
  // STICKER POSITION
  //=============================

  double _stickerX = 0.80;

  double _stickerY = 0.14;

  //=============================
  // STICKER SIZE
  //=============================

  double _stickerSize = 54.0;

  double _stickerStartSize = 54.0;

  //===================================================
  // RECENT STORY STICKERS
  //===================================================

  List<String> _recentStickers = <String>[];

  //===================================================
  // TAGGED PEOPLE
  //===================================================

  List<StoryPerson> _taggedPeople = <StoryPerson>[];

  //===================================================
  // COLORS
  //===================================================

  final List<int> _backgroundColors = <int>[
    0xFF101114,
    0xFF102A43,
    0xFF003B5C,
    0xFF5B2C83,
    0xFF7A1F3D,
    0xFF6B4F1D,
    0xFF00695C,
    0xFF263238,
  ];

  final List<int> _textColors = <int>[
    0xFFFFFFFF,
    0xFF29B6F6,
    0xFFFFE082,
    0xFFFF8A80,
    0xFFB9F6CA,
    0xFFE1BEE7,
    0xFF111111,
  ];

  //===================================================
  // MANUALLY ARRANGED STORY EMOJIS / STICKERS
  //
  // NORMAL UNICODE EMOJIS ARE USED SO THE PHONE
  // RENDERS THEM USING ITS OWN EMOJI FONT.
  //===================================================

  static const Map<String, List<String>> _storyEmojiGroups =
      <String, List<String>>{
        'Smileys': <String>[
          '😀',
          '😃',
          '😄',
          '😁',
          '😆',
          '😅',
          '😂',
          '🤣',
          '😊',
          '😇',
          '🙂',
          '🙃',
          '😉',
          '😌',
          '😍',
          '🥰',
          '😘',
          '😗',
          '😙',
          '😚',
          '😋',
          '😛',
          '😝',
          '😜',
          '🤪',
          '🤨',
          '🧐',
          '🤓',
          '😎',
          '🥸',
          '🤩',
          '🥳',
          '😏',
          '😒',
          '😞',
          '😔',
          '😟',
          '😕',
          '🙁',
          '☹️',
          '😣',
          '😖',
          '😫',
          '😩',
          '🥺',
          '😢',
          '😭',
          '😤',
          '😠',
          '😡',
          '🤬',
          '🤯',
          '😳',
          '🥵',
          '🥶',
          '😱',
          '😨',
          '😰',
          '😥',
          '😓',
          '🤗',
          '🤔',
          '🫣',
          '🤭',
          '🫢',
          '🫡',
          '🤫',
          '🫠',
          '🤥',
          '😶',
          '🫥',
          '😐',
          '🫤',
          '😑',
          '😬',
          '🙄',
          '😯',
          '😦',
          '😧',
          '😮',
          '😲',
          '🥱',
          '😴',
          '🤤',
          '😪',
          '😵',
          '😵‍💫',
          '🤐',
          '🥴',
          '🤢',
          '🤮',
          '🤧',
          '😷',
          '🤒',
          '🤕',
          '🤑',
          '🤠',
          '😈',
          '👿',
          '👹',
          '👺',
          '🤡',
          '💩',
          '👻',
          '💀',
          '☠️',
          '👽',
          '👾',
          '🤖',
          '🎃',
          '😺',
          '😸',
          '😹',
          '😻',
          '😼',
          '😽',
          '🙀',
          '😿',
          '😾',
        ],

        'Gestures': <String>[
          '👋',
          '🤚',
          '🖐️',
          '✋',
          '🖖',
          '🫱',
          '🫲',
          '🫳',
          '🫴',
          '👌',
          '🤌',
          '🤏',
          '✌️',
          '🤞',
          '🫰',
          '🤟',
          '🤘',
          '🤙',
          '👈',
          '👉',
          '👆',
          '🖕',
          '👇',
          '☝️',
          '👍',
          '👎',
          '✊',
          '👊',
          '🤛',
          '🤜',
          '👏',
          '🙌',
          '🫶',
          '👐',
          '🤲',
          '🤝',
          '🙏',
          '✍️',
          '💅',
          '🤳',
          '💪',
          '🦾',
          '🦿',
          '🦵',
          '🦶',
          '👂',
          '🦻',
          '👃',
          '🧠',
          '🫀',
          '🫁',
          '🦷',
          '🦴',
          '👀',
          '👁️',
          '👅',
          '👄',
          '🫦',
          '💋',
          '🩸',
        ],

        'People': <String>[
          '👶',
          '🧒',
          '👦',
          '👧',
          '🧑',
          '👱',
          '👨',
          '🧔',
          '👩',
          '🧓',
          '👴',
          '👵',
          '🙍',
          '🙎',
          '🙅',
          '🙆',
          '💁',
          '🙋',
          '🧏',
          '🙇',
          '🤦',
          '🤷',
          '👮',
          '👷',
          '💂',
          '🕵️',
          '👩‍⚕️',
          '👨‍⚕️',
          '👩‍🎓',
          '👨‍🎓',
          '👩‍🏫',
          '👨‍🏫',
          '👩‍⚖️',
          '👨‍⚖️',
          '👩‍🌾',
          '👨‍🌾',
          '👩‍🍳',
          '👨‍🍳',
          '👩‍🔧',
          '👨‍🔧',
          '👩‍🏭',
          '👨‍🏭',
          '👩‍💻',
          '👨‍💻',
          '👩‍🔬',
          '👨‍🔬',
          '👩‍🎨',
          '👨‍🎨',
          '👩‍🚒',
          '👨‍🚒',
          '👩‍✈️',
          '👨‍✈️',
          '👩‍🚀',
          '👨‍🚀',
          '🧕',
          '👳',
          '👲',
          '🧔‍♀️',
          '🧔‍♂️',
          '🤵',
          '👰',
          '🤰',
          '🫃',
          '🫄',
          '🤱',
          '👼',
          '🎅',
          '🤶',
          '🦸',
          '🦹',
          '🧙',
          '🧚',
          '🧛',
          '🧜',
          '🧝',
          '🧞',
          '🧟',
          '🧌',
        ],

        'Hearts': <String>[
          '❤️',
          '🩷',
          '🧡',
          '💛',
          '💚',
          '💙',
          '🩵',
          '💜',
          '🤎',
          '🖤',
          '🩶',
          '🤍',
          '💔',
          '❤️‍🔥',
          '❤️‍🩹',
          '❣️',
          '💕',
          '💞',
          '💓',
          '💗',
          '💖',
          '💘',
          '💝',
          '💟',
          '♥️',
          '💌',
          '💋',
          '💯',
          '🔥',
          '✨',
          '⭐',
          '🌟',
          '💫',
          '⚡',
          '💥',
          '💢',
          '💦',
          '💨',
          '🕳️',
          '💬',
          '👁️‍🗨️',
          '🗨️',
          '🗯️',
          '💭',
          '💤',
        ],

        'Animals': <String>[
          '🐶',
          '🐱',
          '🐭',
          '🐹',
          '🐰',
          '🦊',
          '🐻',
          '🐼',
          '🐻‍❄️',
          '🐨',
          '🐯',
          '🦁',
          '🐮',
          '🐷',
          '🐽',
          '🐸',
          '🐵',
          '🙈',
          '🙉',
          '🙊',
          '🐒',
          '🐔',
          '🐧',
          '🐦',
          '🐤',
          '🐣',
          '🐥',
          '🦆',
          '🦅',
          '🦉',
          '🦇',
          '🐺',
          '🐗',
          '🐴',
          '🦄',
          '🐝',
          '🪱',
          '🐛',
          '🦋',
          '🐌',
          '🐞',
          '🐜',
          '🪰',
          '🪲',
          '🪳',
          '🦟',
          '🦗',
          '🕷️',
          '🦂',
          '🐢',
          '🐍',
          '🦎',
          '🦖',
          '🦕',
          '🐙',
          '🦑',
          '🦐',
          '🦞',
          '🦀',
          '🐡',
          '🐠',
          '🐟',
          '🐬',
          '🐳',
          '🐋',
          '🦈',
          '🦭',
          '🐊',
          '🐅',
          '🐆',
          '🦓',
          '🦍',
          '🦧',
          '🐘',
          '🦛',
          '🦏',
          '🐪',
          '🐫',
          '🦒',
          '🦘',
          '🦬',
          '🐃',
          '🐂',
          '🐄',
          '🐎',
          '🐖',
          '🐏',
          '🐑',
          '🦙',
          '🐐',
          '🦌',
          '🐕',
          '🐩',
          '🦮',
          '🐕‍🦺',
          '🐈',
        ],

        'Nature': <String>[
          '🌵',
          '🎄',
          '🌲',
          '🌳',
          '🌴',
          '🪵',
          '🌱',
          '🌿',
          '☘️',
          '🍀',
          '🎍',
          '🪴',
          '🎋',
          '🍃',
          '🍂',
          '🍁',
          '🍄',
          '🐚',
          '🪨',
          '🌾',
          '💐',
          '🌷',
          '🌹',
          '🥀',
          '🪻',
          '🌺',
          '🌸',
          '🌼',
          '🌻',
          '🌞',
          '🌝',
          '🌛',
          '🌜',
          '🌚',
          '🌕',
          '🌖',
          '🌗',
          '🌘',
          '🌑',
          '🌒',
          '🌓',
          '🌔',
          '🌙',
          '🌎',
          '🌍',
          '🌏',
          '🪐',
          '💫',
          '⭐',
          '🌟',
          '✨',
          '⚡',
          '☄️',
          '💥',
          '🔥',
          '🌪️',
          '🌈',
          '☀️',
          '🌤️',
          '⛅',
          '🌥️',
          '☁️',
          '🌦️',
          '🌧️',
          '⛈️',
          '🌩️',
          '🌨️',
          '❄️',
          '☃️',
          '⛄',
          '🌬️',
          '💨',
          '💧',
          '💦',
          '☔',
          '☂️',
          '🌊',
          '🌫️',
        ],

        'Food': <String>[
          '🍏',
          '🍎',
          '🍐',
          '🍊',
          '🍋',
          '🍋‍🟩',
          '🍌',
          '🍉',
          '🍇',
          '🍓',
          '🫐',
          '🍈',
          '🍒',
          '🍑',
          '🥭',
          '🍍',
          '🥥',
          '🥝',
          '🍅',
          '🍆',
          '🥑',
          '🥦',
          '🫛',
          '🥬',
          '🥒',
          '🌶️',
          '🫑',
          '🌽',
          '🥕',
          '🫒',
          '🧄',
          '🧅',
          '🥔',
          '🍠',
          '🫚',
          '🥐',
          '🥯',
          '🍞',
          '🥖',
          '🥨',
          '🧀',
          '🥚',
          '🍳',
          '🧈',
          '🥞',
          '🧇',
          '🥓',
          '🥩',
          '🍗',
          '🍖',
          '🌭',
          '🍔',
          '🍟',
          '🍕',
          '🫓',
          '🥪',
          '🥙',
          '🧆',
          '🌮',
          '🌯',
          '🫔',
          '🥗',
          '🥘',
          '🫕',
          '🥫',
          '🍝',
          '🍜',
          '🍲',
          '🍛',
          '🍣',
          '🍱',
          '🥟',
          '🦪',
          '🍤',
          '🍙',
          '🍚',
          '🍘',
          '🍥',
          '🥠',
          '🥮',
          '🍢',
          '🍡',
          '🍧',
          '🍨',
          '🍦',
          '🥧',
          '🧁',
          '🍰',
          '🎂',
          '🍮',
          '🍭',
          '🍬',
          '🍫',
          '🍿',
          '🍩',
          '🍪',
          '🌰',
          '🥜',
          '🍯',
          '🥛',
          '🍼',
          '🫖',
          '☕',
          '🍵',
          '🧃',
          '🥤',
          '🧋',
          '🧉',
          '🧊',
          '🥄',
          '🍴',
          '🥣',
        ],

        'Activities': <String>[
          '⚽',
          '🏀',
          '🏈',
          '⚾',
          '🥎',
          '🎾',
          '🏐',
          '🏉',
          '🥏',
          '🎱',
          '🪀',
          '🏓',
          '🏸',
          '🏒',
          '🏑',
          '🥍',
          '🏏',
          '🪃',
          '🥅',
          '⛳',
          '🪁',
          '🏹',
          '🎣',
          '🤿',
          '🥊',
          '🥋',
          '🎽',
          '🛹',
          '🛼',
          '🛷',
          '⛸️',
          '🥌',
          '🎿',
          '⛷️',
          '🏂',
          '🪂',
          '🏋️',
          '🤼',
          '🤸',
          '⛹️',
          '🤺',
          '🤾',
          '🏌️',
          '🏇',
          '🧘',
          '🏄',
          '🏊',
          '🤽',
          '🚣',
          '🧗',
          '🚵',
          '🚴',
          '🏆',
          '🥇',
          '🥈',
          '🥉',
          '🏅',
          '🎖️',
          '🏵️',
          '🎗️',
          '🎫',
          '🎟️',
          '🎪',
          '🤹',
          '🎭',
          '🩰',
          '🎨',
          '🎬',
          '🎤',
          '🎧',
          '🎼',
          '🎹',
          '🥁',
          '🪘',
          '🎷',
          '🎺',
          '🪗',
          '🎸',
          '🪕',
          '🎻',
          '🎲',
          '♟️',
          '🎯',
          '🎳',
          '🎮',
          '🎰',
          '🧩',
        ],

        'Travel': <String>[
          '🚗',
          '🚕',
          '🚙',
          '🚌',
          '🚎',
          '🏎️',
          '🚓',
          '🚑',
          '🚒',
          '🚐',
          '🛻',
          '🚚',
          '🚛',
          '🚜',
          '🏍️',
          '🛵',
          '🚲',
          '🛴',
          '🚏',
          '🛣️',
          '🛤️',
          '⛽',
          '🛞',
          '🚨',
          '🚥',
          '🚦',
          '🛑',
          '🚧',
          '⚓',
          '🛟',
          '⛵',
          '🛶',
          '🚤',
          '🛳️',
          '⛴️',
          '🛥️',
          '🚢',
          '✈️',
          '🛩️',
          '🛫',
          '🛬',
          '🪂',
          '💺',
          '🚁',
          '🚟',
          '🚠',
          '🚡',
          '🛰️',
          '🚀',
          '🛸',
          '🏠',
          '🏡',
          '🏢',
          '🏥',
          '🏦',
          '🏨',
          '🏪',
          '🏫',
          '🏬',
          '🏭',
          '🏰',
          '🏯',
          '🏟️',
          '🗼',
          '🗽',
          '⛪',
          '🕌',
          '🛕',
          '🕍',
          '⛩️',
          '🕋',
          '⛲',
          '⛺',
          '🌁',
          '🌃',
          '🏙️',
          '🌄',
          '🌅',
          '🌆',
          '🌇',
          '🌉',
          '♨️',
          '🎠',
          '🛝',
          '🎡',
          '🎢',
          '💈',
          '🎪',
        ],

        'Objects': <String>[
          '⌚',
          '📱',
          '📲',
          '💻',
          '⌨️',
          '🖥️',
          '🖨️',
          '🖱️',
          '🖲️',
          '🕹️',
          '🗜️',
          '💽',
          '💾',
          '💿',
          '📀',
          '📼',
          '📷',
          '📸',
          '📹',
          '🎥',
          '📽️',
          '🎞️',
          '📞',
          '☎️',
          '📟',
          '📠',
          '📺',
          '📻',
          '🎙️',
          '🎚️',
          '🎛️',
          '🧭',
          '⏱️',
          '⏲️',
          '⏰',
          '🕰️',
          '⌛',
          '⏳',
          '📡',
          '🔋',
          '🪫',
          '🔌',
          '💡',
          '🔦',
          '🕯️',
          '🪔',
          '🧯',
          '🛢️',
          '💸',
          '💵',
          '💴',
          '💶',
          '💷',
          '🪙',
          '💰',
          '💳',
          '💎',
          '⚖️',
          '🪜',
          '🧰',
          '🪛',
          '🔧',
          '🔨',
          '⚒️',
          '🛠️',
          '⛏️',
          '🪚',
          '🔩',
          '⚙️',
          '🪤',
          '🧱',
          '⛓️',
          '🧲',
          '🔫',
          '💣',
          '🧨',
          '🪓',
          '🔪',
          '🗡️',
          '⚔️',
          '🛡️',
          '🚬',
          '⚰️',
          '🪦',
          '⚱️',
          '🏺',
          '🔮',
          '📿',
          '🧿',
          '🪬',
          '💈',
          '⚗️',
          '🔭',
          '🔬',
          '🕳️',
          '🩹',
          '🩺',
          '💊',
          '💉',
          '🩸',
          '🧬',
          '🦠',
          '🧫',
          '🧪',
          '🌡️',
          '🧹',
          '🪠',
          '🧺',
          '🧻',
          '🚽',
          '🚿',
          '🛁',
          '🪥',
          '🪒',
          '🧴',
          '🧷',
          '🛒',
          '🎁',
          '🎈',
        ],

        'Symbols': <String>[
          '✅',
          '☑️',
          '✔️',
          '❌',
          '❎',
          '➕',
          '➖',
          '➗',
          '✖️',
          '♾️',
          '‼️',
          '⁉️',
          '❓',
          '❔',
          '❕',
          '❗',
          '〰️',
          '💱',
          '💲',
          '⚕️',
          '♻️',
          '⚜️',
          '🔱',
          '📛',
          '🔰',
          '⭕',
          '🟢',
          '🔵',
          '🟣',
          '🟡',
          '🟠',
          '🔴',
          '⚫',
          '⚪',
          '🟤',
          '🟥',
          '🟧',
          '🟨',
          '🟩',
          '🟦',
          '🟪',
          '⬛',
          '⬜',
          '◼️',
          '◻️',
          '◾',
          '◽',
          '▪️',
          '▫️',
          '🔶',
          '🔷',
          '🔸',
          '🔹',
          '🔺',
          '🔻',
          '💠',
          '🔘',
          '🔳',
          '🔲',
          '⬆️',
          '⬇️',
          '⬅️',
          '➡️',
          '↗️',
          '↘️',
          '↙️',
          '↖️',
          '↕️',
          '↔️',
          '↩️',
          '↪️',
          '⤴️',
          '⤵️',
          '🔃',
          '🔄',
          '🔙',
          '🔚',
          '🔛',
          '🔜',
          '🔝',
          '🆕',
          '🆓',
          '🆒',
          '🆗',
          '🆙',
          '🆘',
          '⭐',
          '💯',
        ],

        'Flags': <String>[
          '🇳🇬',
          '🇪🇬',
          '🇬🇭',
          '🇿🇦',
          '🇰🇪',
          '🇪🇹',
          '🇹🇿',
          '🇺🇬',
          '🇷🇼',
          '🇸🇳',
          '🇨🇲',
          '🇨🇮',
          '🇩🇿',
          '🇲🇦',
          '🇹🇳',
          '🇸🇩',
          '🇸🇴',
          '🇦🇪',
          '🇸🇦',
          '🇶🇦',
          '🇰🇼',
          '🇧🇭',
          '🇴🇲',
          '🇯🇴',
          '🇱🇧',
          '🇹🇷',
          '🇵🇸',
          '🇬🇧',
          '🇺🇸',
          '🇨🇦',
          '🇫🇷',
          '🇩🇪',
          '🇮🇹',
          '🇪🇸',
          '🇵🇹',
          '🇳🇱',
          '🇧🇪',
          '🇨🇭',
          '🇸🇪',
          '🇳🇴',
          '🇩🇰',
          '🇫🇮',
          '🇵🇱',
          '🇺🇦',
          '🇷🇺',
          '🇮🇳',
          '🇵🇰',
          '🇧🇩',
          '🇨🇳',
          '🇯🇵',
          '🇰🇷',
          '🇮🇩',
          '🇲🇾',
          '🇸🇬',
          '🇹🇭',
          '🇵🇭',
          '🇦🇺',
          '🇳🇿',
          '🇧🇷',
          '🇦🇷',
          '🇲🇽',
          '🇯🇲',
          '🏳️',
          '🏴',
          '🏁',
          '🚩',
          '🏳️‍🌈',
          '🏴‍☠️',
        ],
      };
  //===================================================
  // VOICE PLAYBACK AUDIO ROUTE
  //
  // AFTER RECORDING, FORCE PLAYBACK BACK TO THE
  // NORMAL MEDIA / SPEAKER OUTPUT.
  //===================================================

  Future<void> _configureVoicePlayback() async {
    try {
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);

      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            audioMode: AndroidAudioMode.normal,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );

      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      await _audioPlayer.setVolume(1.0);
    } catch (error) {
      debugPrint('Voice playback configuration error: $error');
    }
  }
  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    if (widget.initialLinkUrl.trim().isNotEmpty) {
      _storyLinkUrl = widget.initialLinkUrl.trim();
      _storyTextController.text = widget.initialText.trim();
      _captionController.text = widget.initialCaption.trim();
      _backgroundColor = widget.initialBackgroundColor;
      _mode = 'text';
    }

    _loadRecentStickers();

    unawaited(_configureVoicePlayback());

    _voicePositionSubscription = _audioPlayer.onPositionChanged.listen((
      Duration position,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        _voicePosition = position;
      });
    });

    _voiceDurationSubscription = _audioPlayer.onDurationChanged.listen((
      Duration duration,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        _voiceDuration = duration;
      });
    });

    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isVoicePlaying = false;

        _isVoicePaused = false;

        _voiceCompleted = true;

        if (_voiceDuration > Duration.zero) {
          _voicePosition = _voiceDuration;
        }
      });
    });
  }

  //===================================================
  // SELECT MODE
  //
  // ONLY ONE PRIMARY STORY TYPE CAN BE ACTIVE.
  // USER MUST DELETE/CLEAR CURRENT CONTENT BEFORE
  // CHANGING TO ANOTHER PRIMARY MODE.
  //===================================================

  Future<void> _selectMode(String mode) async {
    if (mode == _mode) {
      if (mode == 'media' && _mediaFile == null) {
        await _showMediaPicker();
      }

      if (mode == 'layout' && _layoutFiles.isEmpty) {
        await _pickLayoutImages();
      }

      return;
    }

    if (_modeHasContent(_mode)) {
      _showMessage(
        'Delete the current ${_modeLabel(_mode)} first before choosing ${_modeLabel(mode)}.',
      );

      return;
    }

    if (_isRecording) {
      await _stopRecording();
    }

    if (_isVoicePlaying || _isVoicePaused) {
      await _audioPlayer.pause();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _mode = mode;

      if (mode != 'voice') {
        _isVoicePlaying = false;

        _isVoicePaused = false;
      }
    });

    if (mode == 'media' && _mediaFile == null) {
      await _showMediaPicker();
    }

    if (mode == 'layout' && _layoutFiles.isEmpty) {
      await _pickLayoutImages();
    }
  }

  //===================================================
  // MODE HAS CONTENT
  //===================================================

  bool _modeHasContent(String mode) {
    switch (mode) {
      case 'media':
        return _mediaFile != null;

      case 'layout':
        return _layoutFiles.isNotEmpty;

      case 'voice':
        return _isRecording ||
            (_voicePath?.trim().isNotEmpty ?? false) ||
            _voiceSeconds > 0;

      case 'text':
        return _storyTextController.text.trim().isNotEmpty;

      case 'poll':
        return _pollQuestionController.text.trim().isNotEmpty ||
            _pollOptionControllers.any(
              (TextEditingController controller) =>
                  controller.text.trim().isNotEmpty,
            );

      default:
        return false;
    }
  }

  //===================================================
  // MODE LABEL
  //===================================================

  String _modeLabel(String mode) {
    switch (mode) {
      case 'media':
        return 'photo/video';

      case 'layout':
        return 'layout';

      case 'voice':
        return 'voice';

      case 'text':
        return 'text';

      case 'poll':
        return 'poll';

      default:
        return 'story';
    }
  }

  //===================================================
  // MEDIA PICKER
  //===================================================

  Future<void> _showMediaPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photo from gallery'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _pickImage(ImageSource.gallery);
                },
              ),

              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Video from gallery'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _pickVideo(ImageSource.gallery);
                },
              ),

              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _pickImage(ImageSource.camera);
                },
              ),

              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Record video'),
                onTap: () async {
                  Navigator.pop(sheetContext);

                  await _pickVideo(ImageSource.camera);
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

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 92,
    );

    if (file == null || !mounted) {
      return;
    }

    setState(() {
      _mode = 'media';

      _mediaFile = file;

      _mediaIsVideo = false;
    });
  }

  //===================================================
  // PICK VIDEO
  //
  // VIDEO REMAINS 60 SEC.
  // VOICE IS NOW 5 MIN.
  //===================================================

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? file = await _imagePicker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );

    if (file == null) {
      return;
    }

    int durationSeconds = 15;

    try {
      final VideoPlayerController controller = VideoPlayerController.file(
        File(file.path),
      );

      await controller.initialize();

      durationSeconds = controller.value.duration.inSeconds
          .clamp(3, 60)
          .toInt();

      await controller.dispose();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      _mode = 'media';

      _mediaFile = file;

      _mediaIsVideo = true;

      _mediaVideoDurationSeconds = durationSeconds;
    });
  }

  //===================================================
  // DELETE SELECTED MEDIA
  //
  // AFTER DELETE, OTHER STORY MODES ARE UNLOCKED.
  //===================================================

  Future<void> _deleteSelectedMedia() async {
    if (_isVoicePlaying || _isVoicePaused) {
      await _audioPlayer.stop();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _mediaFile = null;

      _mediaIsVideo = false;

      _mediaVideoDurationSeconds = 15;
    });
  }

  //===================================================
  // PICK LAYOUT PHOTOS
  //===================================================

  Future<void> _pickLayoutImages() async {
    final List<XFile> files = await _imagePicker.pickMultiImage(
      imageQuality: 92,
    );

    if (files.isEmpty || !mounted) {
      return;
    }

    final List<XFile> limited = files.take(4).toList();

    setState(() {
      _mode = 'layout';

      _layoutFiles = limited;
    });
  }

  //===================================================
  // DELETE LAYOUT
  //
  // ONLY PHOTOS ARE REMOVED.
  // LAYOUT COUNT + STYLE ARE KEPT.
  //===================================================

  void _deleteLayout() {
    setState(() {
      //===================================================
      // REMOVE ONLY THE SELECTED PHOTOS.
      //
      // KEEP THE USER'S CHOSEN:
      // - 2 / 3 / 4 PANEL COUNT
      // - LAYOUT STYLE
      //
      // SO WHEN THEY PICK REPLACEMENT PHOTOS, THE SAME
      // LAYOUT DESIGN IS STILL SELECTED.
      //===================================================

      _layoutFiles = <XFile>[];
    });
  }

  //===================================================
  // LAYOUT FILE FOR SLOT
  //
  // 1 PHOTO IN 4 = 1 1 1 1
  // 2 PHOTOS IN 4 = 1 2 1 2
  // 3 PHOTOS IN 4 = 1 2 3 1
  //===================================================

  XFile _layoutFileForSlot(int index) {
    return _layoutFiles[index % _layoutFiles.length];
  }

  //===================================================
  // LAYOUT SETTINGS
  //===================================================

  Future<void> _showLayoutSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setSheetState,
              ) {
                void updateLayout({int? count, String? style}) {
                  setState(() {
                    if (count != null) {
                      _layoutCount = count;

                      _layoutStyle = _defaultLayoutStyle(count);
                    }

                    if (style != null) {
                      _layoutStyle = style;
                    }
                  });

                  setSheetState(() {});
                }

                final List<Map<String, String>> styles = _layoutStylesForCount(
                  _layoutCount,
                );

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Center(
                          child: Container(
                            width: 45,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'Layout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'Choose 2, 3 or 4 panels. One photo can fill every panel.',
                          style: TextStyle(color: Colors.white60),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: <Widget>[
                            for (final int count in <int>[2, 3, 4])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _layoutCount == count
                                          ? const Color(0xFF29B6F6)
                                          : Colors.white10,
                                    ),
                                    onPressed: () {
                                      updateLayout(count: count);
                                    },
                                    child: Text('$count'),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Style',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: styles.map((Map<String, String> item) {
                            final String id = item['id']!;

                            final bool selected = _layoutStyle == id;

                            return ChoiceChip(
                              selected: selected,
                              selectedColor: const Color(0xFF29B6F6),
                              backgroundColor: Colors.white10,
                              label: Text(
                                item['label']!,
                                style: TextStyle(
                                  color: selected ? Colors.black : Colors.white,
                                ),
                              ),
                              onSelected: (_) {
                                updateLayout(style: id);
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 22),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Done'),
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

  String _defaultLayoutStyle(int count) {
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

  List<Map<String, String>> _layoutStylesForCount(int count) {
    if (count == 2) {
      return const <Map<String, String>>[
        <String, String>{'id': 'vertical', 'label': 'Left / Right'},
        <String, String>{'id': 'horizontal', 'label': 'Top / Bottom'},
      ];
    }

    if (count == 3) {
      return const <Map<String, String>>[
        <String, String>{'id': 'big_top', 'label': 'Big Top'},
        <String, String>{'id': 'big_left', 'label': 'Big Left'},
        <String, String>{'id': 'three_vertical', 'label': '3 Vertical'},
        <String, String>{'id': 'three_horizontal', 'label': '3 Horizontal'},
      ];
    }

    return const <Map<String, String>>[
      <String, String>{'id': 'grid', 'label': '2 × 2'},
      <String, String>{'id': 'four_vertical', 'label': '4 Vertical'},
      <String, String>{'id': 'four_horizontal', 'label': '4 Horizontal'},
      <String, String>{'id': 'big_left_three', 'label': 'Big Left + 3'},
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

      final bool allowed = await _audioRecorder.hasPermission();

      if (!allowed) {
        _showMessage('Microphone permission is required.');

        return;
      }

      final Directory directory = await getTemporaryDirectory();

      final String path =
          '${directory.path}/nubify_story_'
          '${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,

          bitRate: 128000,

          sampleRate: 44100,

          numChannels: 1,

          //===================================================
          // ANDROID AUDIO
          //===================================================
          androidConfig: AndroidRecordConfig(manageBluetooth: true),
        ),

        path: path,
      );

      _voiceTimer?.cancel();

      _waveformTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _mode = 'voice';

        _voicePath = null;

        _voiceSeconds = 0;

        _voicePosition = Duration.zero;

        _voiceDuration = Duration.zero;

        _isRecording = true;

        _isVoicePlaying = false;

        _isVoicePaused = false;

        _voiceCompleted = false;

        for (int index = 0; index < _waveformHeights.length; index++) {
          _waveformHeights[index] = 10;
        }
      });

      //===================================================
      // RECORDING TIMER
      //
      // AUTO-STOPS AT 5:00
      //===================================================

      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        if (!mounted || !_isRecording) {
          return;
        }

        setState(() {
          _voiceSeconds++;
        });

        if (_voiceSeconds >= _maxVoiceSeconds) {
          _stopRecording();
        }
      });

      //===================================================
      // LIVE WAVEFORM
      //===================================================

      _waveformTimer = Timer.periodic(const Duration(milliseconds: 120), (
        Timer timer,
      ) async {
        if (!mounted || !_isRecording) {
          return;
        }

        try {
          final Amplitude amplitude = await _audioRecorder.getAmplitude();

          //===================================================
          // IMPORTANT:
          //
          // THE 60 BELOW IS AUDIO dB NORMALIZATION.
          // IT IS NOT THE 60-SECOND RECORD LIMIT.
          // DO NOT CHANGE THIS TO 300.
          //===================================================

          final double normalized = ((amplitude.current + 60) / 60)
              .clamp(0.0, 1.0)
              .toDouble();

          final double nextHeight = 10 + normalized * 48;

          if (!mounted || !_isRecording) {
            return;
          }

          setState(() {
            _waveformHeights.removeAt(0);

            _waveformHeights.add(nextHeight);
          });
        } catch (_) {}
      });
    } catch (error) {
      _voiceTimer?.cancel();

      _waveformTimer?.cancel();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      _showMessage('Unable to start voice recording: $error');
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
      final String? path = await _audioRecorder.stop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _voiceTimer?.cancel();

      _waveformTimer?.cancel();

      if (!mounted) {
        return;
      }

      if (path == null || path.trim().isEmpty) {
        setState(() {
          _isRecording = false;

          _voicePath = null;
        });

        _showMessage('No audio recording was created.');

        return;
      }

      final File file = File(path);

      if (!await file.exists() || await file.length() <= 0) {
        setState(() {
          _isRecording = false;

          _voicePath = null;
        });

        _showMessage('The recorded audio is empty.');

        return;
      }
      final int safeSeconds = _voiceSeconds < 1 ? 1 : _voiceSeconds;

      //===================================================
      // RETURN AUDIO TO SPEAKER / MEDIA MODE
      //===================================================

      await _configureVoicePlayback();

      setState(() {
        _isRecording = false;

        _isVoicePlaying = false;

        _isVoicePaused = false;

        _voiceCompleted = false;

        _voicePath = path;

        _voiceSeconds = safeSeconds;

        _voicePosition = Duration.zero;

        _voiceDuration = Duration(seconds: safeSeconds);
      });
    } catch (error) {
      _voiceTimer?.cancel();

      _waveformTimer?.cancel();

      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      _showMessage('Unable to stop voice recording: $error');
    }
  }

  //===================================================
  // PLAY / PAUSE VOICE REVIEW
  //===================================================

  Future<void> _toggleVoicePreview() async {
    final String? path = _voicePath;

    if (path == null || path.trim().isEmpty) {
      return;
    }

    final File file = File(path);

    if (!await file.exists()) {
      _showMessage('The recorded audio file is no longer available.');

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
          _isVoicePlaying = false;

          _isVoicePaused = true;
        });

        return;
      }

      //===================================================
      // PAUSED -> RESUME
      //===================================================

      if (_isVoicePaused && !_voiceCompleted) {
        await _audioPlayer.resume();

        if (!mounted) {
          return;
        }

        setState(() {
          _isVoicePlaying = true;

          _isVoicePaused = false;
        });

        return;
      }

      //===================================================
      // NEW PLAY / REPLAY
      //===================================================

      Duration startPosition = _voicePosition;

      if (_voiceCompleted ||
          (_voiceDuration > Duration.zero &&
              _voicePosition >= _voiceDuration)) {
        startPosition = Duration.zero;
      }

      //===================================================
      // MAKE SURE VOICE COMES FROM SPEAKER
      //===================================================

      await _configureVoicePlayback();

      await _audioPlayer.stop();

      await _audioPlayer.setVolume(1.0);

      await _audioPlayer.play(DeviceFileSource(path));

      if (startPosition > Duration.zero) {
        await _audioPlayer.seek(startPosition);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _voicePosition = startPosition;

        _isVoicePlaying = true;

        _isVoicePaused = false;

        _voiceCompleted = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isVoicePlaying = false;

        _isVoicePaused = false;
      });

      _showMessage('Unable to play recording: $error');
    }
  }

  //===================================================
  // SEEK VOICE
  //===================================================

  Future<void> _seekVoice(double value) async {
    final Duration duration = _effectiveVoiceDuration;

    if (duration <= Duration.zero) {
      return;
    }

    final Duration newPosition = Duration(
      milliseconds: (duration.inMilliseconds * value).round(),
    );

    setState(() {
      _voicePosition = newPosition;

      _voiceCompleted = false;
    });

    try {
      if (_isVoicePlaying || _isVoicePaused) {
        await _audioPlayer.seek(newPosition);
      }
    } catch (_) {}
  }

  //===================================================
  // EFFECTIVE VOICE DURATION
  //===================================================

  Duration get _effectiveVoiceDuration {
    if (_voiceDuration > Duration.zero) {
      return _voiceDuration;
    }

    return Duration(seconds: _voiceSeconds);
  }

  //===================================================
  // VOICE SLIDER
  //===================================================

  double get _voiceSliderValue {
    final Duration duration = _effectiveVoiceDuration;

    if (duration.inMilliseconds <= 0) {
      return 0;
    }

    return (_voicePosition.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
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
      _voicePath = null;

      _voiceSeconds = 0;

      _voicePosition = Duration.zero;

      _voiceDuration = Duration.zero;

      _isRecording = false;

      _isVoicePlaying = false;

      _isVoicePaused = false;

      _voiceCompleted = false;

      for (int index = 0; index < _waveformHeights.length; index++) {
        _waveformHeights[index] = 10;
      }
    });
  }

  //===================================================
  // DELETE TEMP VOICE FILE
  //===================================================

  Future<void> _deleteOldVoiceFileOnly() async {
    final String? path = _voicePath;

    if (path == null || path.trim().isEmpty) {
      return;
    }

    try {
      final File file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  //===================================================
  // TAG PEOPLE
  //===================================================

  Future<void> _pickTaggedPeople() async {
    final List<StoryPerson>? result = await Navigator.push<List<StoryPerson>>(
      context,
      MaterialPageRoute<List<StoryPerson>>(
        builder: (_) => StoryPeoplePickerScreen(
          title: 'Tag People',
          initialSelected: _taggedPeople,
          maxSelection: 20,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _taggedPeople = result;
    });
  }

  //===================================================
  // ADD POLL OPTION
  //===================================================

  void _addPollOption() {
    if (_pollOptionControllers.length >= 4) {
      _showMessage('A story poll can have up to 4 options.');

      return;
    }

    setState(() {
      _pollOptionControllers.add(TextEditingController());
    });
  }

  //===================================================
  // REMOVE POLL OPTION
  //===================================================

  void _removePollOption(int index) {
    if (_pollOptionControllers.length <= 2) {
      return;
    }

    final TextEditingController controller = _pollOptionControllers.removeAt(
      index,
    );

    controller.dispose();

    setState(() {});
  }

  //===================================================
  // CLEAR TEXT STORY
  //===================================================

  void _clearTextStory() {
    _storyTextController.clear();

    setState(() {});
  }

  //===================================================
  // CLEAR POLL STORY
  //===================================================

  void _clearPollStory() {
    _pollQuestionController.clear();

    for (final TextEditingController controller in _pollOptionControllers) {
      controller.clear();
    }

    setState(() {});
  }

  //===================================================
  // LOAD RECENT STICKERS
  //===================================================

  Future<void> _loadRecentStickers() async {
    final List<String> recent = await _storyStickerService.getRecentStickers();

    if (!mounted) {
      return;
    }

    setState(() {
      _recentStickers = recent;
    });
  }

  //===================================================
  // SELECT + REMEMBER STICKER
  //===================================================

  Future<void> _selectSticker(String sticker) async {
    final String cleanSticker = sticker.trim();

    if (cleanSticker.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _sticker = cleanSticker;
      });
    }

    try {
      final List<String> recent = await _storyStickerService.rememberSticker(
        cleanSticker,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recentStickers = recent;
      });
    } catch (_) {}
  }

  //===================================================
  // STICKERS
  //
  // TAB 1 = MANUALLY ARRANGED STANDARD EMOJIS
  // TAB 2 = RECENTLY SELECTED STICKERS
  //===================================================

  Future<void> _showStickers() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return DefaultTabController(
          length: 2,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.78,
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 10),

                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.emoji_emotions_outlined,
                          color: Color(0xFF29B6F6),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Story Stickers',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const TabBar(
                    indicatorColor: Color(0xFF29B6F6),
                    labelColor: Color(0xFF29B6F6),
                    unselectedLabelColor: Colors.white60,
                    tabs: <Tab>[
                      Tab(text: 'Stickers'),
                      Tab(text: 'Recent'),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        //===================================================
                        // MANUALLY ARRANGED EMOJI CATEGORIES
                        //===================================================

                        DefaultTabController(
                          length: _storyEmojiGroups.length,
                          child: Column(
                            children: <Widget>[
                              Container(
                                height: 49,
                                color: const Color(0xFF111111),
                                child: TabBar(
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  indicatorColor: const Color(0xFF29B6F6),
                                  labelColor: const Color(0xFF29B6F6),
                                  unselectedLabelColor: Colors.white60,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                  ),
                                  tabs: _storyEmojiGroups.keys
                                      .map((String group) => Tab(text: group))
                                      .toList(),
                                ),
                              ),

                              Expanded(
                                child: TabBarView(
                                  children: _storyEmojiGroups.entries.map((
                                    MapEntry<String, List<String>> entry,
                                  ) {
                                    final List<String> emojis = entry.value;

                                    return GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        14,
                                        12,
                                        18,
                                      ),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 7,
                                            mainAxisSpacing: 4,
                                            crossAxisSpacing: 4,
                                          ),
                                      itemCount: emojis.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final String emoji = emojis[index];

                                            return InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () async {
                                                await _selectSticker(emoji);

                                                if (sheetContext.mounted) {
                                                  Navigator.pop(sheetContext);
                                                }
                                              },
                                              child: Center(
                                                child: Text(
                                                  emoji,
                                                  style: const TextStyle(
                                                    fontSize: 31,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        //===================================================
                        // RECENT STICKERS
                        //===================================================
                        _recentStickers.isEmpty
                            ? const Center(
                                child: Text(
                                  'No recent stickers yet.\nChoose one from Stickers.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : Column(
                                children: <Widget>[
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () async {
                                        await _storyStickerService
                                            .clearRecentStickers();

                                        if (!mounted) {
                                          return;
                                        }

                                        setState(() {
                                          _recentStickers = <String>[];
                                        });
                                      },
                                      child: const Text('Clear recent'),
                                    ),
                                  ),

                                  Expanded(
                                    child: GridView.builder(
                                      padding: const EdgeInsets.all(14),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 7,
                                            mainAxisSpacing: 6,
                                            crossAxisSpacing: 6,
                                          ),
                                      itemCount: _recentStickers.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final String sticker =
                                                _recentStickers[index];

                                            return InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () async {
                                                await _selectSticker(sticker);

                                                if (sheetContext.mounted) {
                                                  Navigator.pop(sheetContext);
                                                }
                                              },
                                              child: Center(
                                                child: Text(
                                                  sticker,
                                                  style: const TextStyle(
                                                    fontSize: 31,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

    if (_mode == 'media' && _mediaFile == null) {
      _showMessage('Choose a photo or video first.');

      return;
    }

    if (_mode == 'layout' && _layoutFiles.isEmpty) {
      _showMessage('Choose at least 1 photo for your layout.');

      return;
    }

    if (_mode == 'text' && _storyTextController.text.trim().isEmpty) {
      _showMessage('Write something for your story.');

      return;
    }

    if (_mode == 'poll') {
      final String question = _pollQuestionController.text.trim();

      final List<String> options = _pollOptionControllers
          .map((TextEditingController controller) {
            return controller.text.trim();
          })
          .where((String text) {
            return text.isNotEmpty;
          })
          .toList();

      if (question.isEmpty || options.length < 2) {
        _showMessage('Add a poll question and at least 2 options.');

        return;
      }
    }

    if (_mode == 'voice' &&
        (_voicePath == null || _voicePath!.trim().isEmpty)) {
      _showMessage('Record your voice first.');

      return;
    }

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isVoicePlaying = false;

        _isVoicePaused = false;

        _isPosting = true;
      });
    }

    try {
      final String storyId = _storyService.newStoryId();

      String mediaUrl = '';
      String thumbnailUrl = '';

      final List<String> mediaUrls = <String>[];

      String type = _mode;

      StoryPoll? poll;

      int durationSeconds = 8;

      //===================================================
      // MEDIA
      //===================================================

      if (_mode == 'media') {
        mediaUrl = await _storyService.uploadStoryMedia(
          storyId: storyId,
          file: _mediaFile!,
        );

        type = _mediaIsVideo ? 'video' : 'image';
        if (_mediaIsVideo) {
          thumbnailUrl = await _storyService.uploadStoryVideoThumbnail(
            storyId: storyId,
            videoFile: _mediaFile!,
          );
        }

        durationSeconds = _mediaIsVideo ? _mediaVideoDurationSeconds : 8;
      }

      //===================================================
      // LAYOUT
      //===================================================

      if (_mode == 'layout') {
        for (int index = 0; index < _layoutFiles.length; index++) {
          final String url = await _storyService.uploadStoryMedia(
            storyId: storyId,
            file: _layoutFiles[index],
            folder: 'layout_$index',
          );

          mediaUrls.add(url);
        }

        type = 'layout';

        durationSeconds = 10;
      }

      //===================================================
      // VOICE
      //===================================================

      if (_mode == 'voice') {
        mediaUrl = await _storyService.uploadVoiceStory(
          storyId: storyId,
          filePath: _voicePath!,
        );

        type = 'voice';

        durationSeconds = _effectiveVoiceDuration.inSeconds > 0
            ? _effectiveVoiceDuration.inSeconds
                  .clamp(3, _maxVoiceSeconds)
                  .toInt()
            : _voiceSeconds.clamp(3, _maxVoiceSeconds).toInt();
      }

      //===================================================
      // POLL
      //===================================================

      if (_mode == 'poll') {
        final List<StoryPollOption> options = _pollOptionControllers
            .map((TextEditingController controller) {
              return controller.text.trim();
            })
            .where((String text) {
              return text.isNotEmpty;
            })
            .map((String text) {
              return StoryPollOption(text: text, votes: 0);
            })
            .toList();

        poll = StoryPoll(
          question: _pollQuestionController.text.trim(),
          options: options,
          totalVotes: 0,
        );

        durationSeconds = 15;
      }

      //===================================================
      // STORY TEXT
      //
      // STICKER IS NOW SAVED SEPARATELY SO ITS
      // POSITION + SIZE CAN BE PRESERVED.
      //===================================================

      final String storyText = _storyTextController.text.trim();

      //===================================================
      // CREATE STORY
      //===================================================

      await _storyService.createStory(
        storyId: storyId,
        type: type,
        mediaUrl: mediaUrl,
        mediaUrls: mediaUrls,
        text: storyText,
        linkUrl: _storyLinkUrl,
        linkStyle: _storyLinkStyle,
        linkX: _storyLinkX,
        linkY: _storyLinkY,
        linkScale: _storyLinkScale,
        thumbnailUrl: thumbnailUrl,
        //=============================
        // STICKER
        //=============================

        sticker: _sticker,

        stickerX: _stickerX,

        stickerY: _stickerY,

        stickerSize: _stickerSize,
        caption: _captionController.text.trim(),
        backgroundColor: _backgroundColor,
        textColor: _textColor,
        textStyle: _textStyle,
        textAlign: _textAlign,
        textSize: _textSize,
        durationSeconds: durationSeconds,
        layoutCount: _layoutCount,
        layoutStyle: _layoutStyle,
        taggedPeople: _taggedPeople,
        poll: poll,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      _showMessage('Unable to post story: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Create Story',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isPosting ? null : _postStory,
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF29B6F6),
                      ),
                    )
                  : const Text(
                      'Share',
                      style: TextStyle(
                        color: Color(0xFF29B6F6),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildModeBar(),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: double.infinity,
                    color: Color(_backgroundColor),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _buildCanvasContent(),

                        if ((_mode == 'media' || _mode == 'layout') &&
                            _storyTextController.text.trim().isNotEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                _storyTextController.text.trim(),
                                textAlign: _selectedTextAlign,
                                style: _buildTextStyle(),
                              ),
                            ),
                          ),
                        //=============================
                        // DRAGGABLE + RESIZABLE STICKER
                        //
                        // ONE FINGER = MOVE
                        // TWO FINGERS = RESIZE
                        //=============================

                        if (_sticker.isNotEmpty)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: <Widget>[
                                    Positioned(
                                      left: (_stickerX * constraints.maxWidth)
                                          .clamp(0.0, constraints.maxWidth)
                                          .toDouble(),

                                      top: (_stickerY * constraints.maxHeight)
                                          .clamp(0.0, constraints.maxHeight)
                                          .toDouble(),

                                      child: Transform.translate(
                                        offset: Offset(
                                          -_stickerSize * 0.55,
                                          -_stickerSize * 0.55,
                                        ),

                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,

                                          //=============================
                                          // START MOVE / RESIZE
                                          //=============================
                                          onScaleStart:
                                              (ScaleStartDetails details) {
                                                _stickerStartSize =
                                                    _stickerSize;
                                              },

                                          //=============================
                                          // MOVE + RESIZE
                                          //=============================
                                          onScaleUpdate: (ScaleUpdateDetails details) {
                                            if (!mounted) {
                                              return;
                                            }

                                            setState(() {
                                              if (constraints.maxWidth > 0) {
                                                _stickerX =
                                                    (_stickerX +
                                                            details
                                                                    .focalPointDelta
                                                                    .dx /
                                                                constraints
                                                                    .maxWidth)
                                                        .clamp(0.04, 0.96)
                                                        .toDouble();
                                              }

                                              if (constraints.maxHeight > 0) {
                                                _stickerY =
                                                    (_stickerY +
                                                            details
                                                                    .focalPointDelta
                                                                    .dy /
                                                                constraints
                                                                    .maxHeight)
                                                        .clamp(0.04, 0.96)
                                                        .toDouble();
                                              }

                                              _stickerSize =
                                                  (_stickerStartSize *
                                                          details.scale)
                                                      .clamp(28.0, 120.0)
                                                      .toDouble();
                                            });
                                          },

                                          //=============================
                                          // FINISH MOVE / RESIZE
                                          //=============================
                                          onScaleEnd:
                                              (ScaleEndDetails details) {
                                                _stickerStartSize =
                                                    _stickerSize;
                                              },

                                          child: Padding(
                                            padding: const EdgeInsets.all(12),

                                            child: Text(
                                              _sticker,

                                              style: TextStyle(
                                                fontSize: _stickerSize,

                                                height: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        if (_taggedPeople.isNotEmpty)
                          Positioned.fill(
                            child: DraggableStoryTags(
                              people: _taggedPeople,

                              editable: true,

                              onChanged: (List<StoryPerson> people) {
                                setState(() {
                                  _taggedPeople = people;
                                });
                              },
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
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
              child: TextField(
                controller: _captionController,
                maxLength: 160,
                maxLines: 1,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Add a caption...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
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
    final List<Map<String, dynamic>> modes = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'media',
        'label': 'Media',
        'icon': Icons.photo_camera_back_outlined,
      },
      <String, dynamic>{
        'id': 'layout',
        'label': 'Layout',
        'icon': Icons.grid_view_rounded,
      },
      <String, dynamic>{
        'id': 'text',
        'label': 'Text',
        'icon': Icons.text_fields_rounded,
      },
      <String, dynamic>{
        'id': 'poll',
        'label': 'Poll',
        'icon': Icons.poll_outlined,
      },
      <String, dynamic>{
        'id': 'voice',
        'label': 'Voice',
        'icon': Icons.mic_none_rounded,
      },
    ];

    return SizedBox(
      height: 68,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        itemCount: modes.length,
        itemBuilder: (BuildContext context, int index) {
          final String id = modes[index]['id'] as String;

          final bool selected = id == _mode;

          final bool locked = _modeHasContent(_mode) && id != _mode;

          return Opacity(
            opacity: locked ? 0.35 : 1,
            child: InkWell(
              onTap: locked
                  ? () {
                      _showMessage(
                        'Delete the current ${_modeLabel(_mode)} first before choosing ${_modeLabel(id)}.',
                      );
                    }
                  : () {
                      _selectMode(id);
                    },
              child: Container(
                width: 72,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF29B6F6).withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? const Color(0xFF29B6F6) : Colors.white12,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      modes[index]['icon'] as IconData,
                      color: selected
                          ? const Color(0xFF29B6F6)
                          : Colors.white70,
                    ),
                    Text(
                      modes[index]['label'] as String,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF29B6F6)
                            : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
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
    final XFile? file = _mediaFile;

    if (file == null) {
      return _emptyCanvasButton(
        icon: Icons.add_photo_alternate_outlined,
        label: 'Choose a photo or video',
        onTap: _showMediaPicker,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_mediaIsVideo)
          _LocalVideoPreview(filePath: file.path)
        else
          Image.file(File(file.path), fit: BoxFit.cover),

        Positioned(
          top: 12,
          left: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _smallGlassButton(
                icon: Icons.swap_horiz,
                label: 'Replace',
                onTap: _showMediaPicker,
              ),

              const SizedBox(width: 7),

              _smallGlassButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                onTap: _deleteSelectedMedia,
              ),
            ],
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
        icon: Icons.grid_view_rounded,
        label: 'Choose 1–4 photos',
        onTap: _pickLayoutImages,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildLayoutPreview(),

        Positioned(
          top: 12,
          left: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _smallGlassButton(
                icon: Icons.photo_library_outlined,
                label: 'Replace',
                onTap: _pickLayoutImages,
              ),

              const SizedBox(width: 7),

              _smallGlassButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                onTap: _deleteLayout,
              ),
            ],
          ),
        ),

        Positioned(
          top: 12,
          right: 12,
          child: _smallGlassButton(
            icon: Icons.dashboard_customize_outlined,
            label: '$_layoutCount panels',
            onTap: _showLayoutSettings,
          ),
        ),
      ],
    );
  }

  //===================================================
  // LAYOUT PREVIEW
  //===================================================

  Widget _buildLayoutPreview() {
    Widget slot(int index) {
      return Padding(
        padding: const EdgeInsets.all(1.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            File(_layoutFileForSlot(index).path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }

    //===================================================
    // 2 PANELS
    //===================================================

    if (_layoutCount == 2) {
      if (_layoutStyle == 'horizontal') {
        return Column(
          children: <Widget>[
            Expanded(child: slot(0)),
            Expanded(child: slot(1)),
          ],
        );
      }

      return Row(
        children: <Widget>[
          Expanded(child: slot(0)),
          Expanded(child: slot(1)),
        ],
      );
    }

    //===================================================
    // 3 PANELS
    //===================================================

    if (_layoutCount == 3) {
      if (_layoutStyle == 'big_left') {
        return Row(
          children: <Widget>[
            Expanded(flex: 2, child: slot(0)),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(child: slot(1)),
                  Expanded(child: slot(2)),
                ],
              ),
            ),
          ],
        );
      }

      if (_layoutStyle == 'three_vertical') {
        return Row(
          children: <Widget>[
            for (int index = 0; index < 3; index++)
              Expanded(child: slot(index)),
          ],
        );
      }

      if (_layoutStyle == 'three_horizontal') {
        return Column(
          children: <Widget>[
            for (int index = 0; index < 3; index++)
              Expanded(child: slot(index)),
          ],
        );
      }

      return Column(
        children: <Widget>[
          Expanded(flex: 2, child: slot(0)),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(child: slot(1)),
                Expanded(child: slot(2)),
              ],
            ),
          ),
        ],
      );
    }

    //===================================================
    // 4 PANELS
    //===================================================

    if (_layoutStyle == 'four_vertical') {
      return Row(
        children: <Widget>[
          for (int index = 0; index < 4; index++) Expanded(child: slot(index)),
        ],
      );
    }

    if (_layoutStyle == 'four_horizontal') {
      return Column(
        children: <Widget>[
          for (int index = 0; index < 4; index++) Expanded(child: slot(index)),
        ],
      );
    }

    if (_layoutStyle == 'big_left_three') {
      return Row(
        children: <Widget>[
          Expanded(flex: 2, child: slot(0)),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: slot(1)),
                Expanded(child: slot(2)),
                Expanded(child: slot(3)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(child: slot(0)),
              Expanded(child: slot(1)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(child: slot(2)),
              Expanded(child: slot(3)),
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
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _storyTextController,
              maxLength: 500,
              minLines: 1,
              maxLines: 8,
              textAlign: _selectedTextAlign,
              onChanged: (_) {
                setState(() {});
              },
              style: _buildTextStyle(),
              decoration: const InputDecoration(
                hintText: 'Type something...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ),

        if (_storyTextController.text.trim().isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: _smallGlassButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: _clearTextStory,
            ),
          ),
      ],
    );
  }

  //===================================================
  // POLL CANVAS
  //===================================================

  Widget _buildPollCanvas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 50, 24, 50),
      child: Column(
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: _smallGlassButton(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Poll',
              onTap: _clearPollStory,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _pollQuestionController,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            decoration: const InputDecoration(
              hintText: 'Ask a question...',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),

          const SizedBox(height: 20),

          for (int index = 0; index < _pollOptionControllers.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _pollOptionControllers[index],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Option ${index + 1}',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  if (_pollOptionControllers.length > 2)
                    IconButton(
                      onPressed: () {
                        _removePollOption(index);
                      },
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                ],
              ),
            ),

          TextButton.icon(
            onPressed: _addPollOption,
            icon: const Icon(Icons.add),
            label: const Text('Add option'),
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

    if (_voicePath == null && !_isRecording) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: const Color(0xFF29B6F6).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF29B6F6), width: 3),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Tap to record',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Maximum ${_formatDuration(Duration(seconds: _maxVoiceSeconds))}',
              style: const TextStyle(color: Colors.white54),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 3),
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    size: 57,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Recording...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              _buildWaveform(recording: true),

              const SizedBox(height: 12),

              Text(
                _formatDuration(Duration(seconds: _voiceSeconds)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Maximum ${_formatDuration(Duration(seconds: _maxVoiceSeconds))}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),

              const SizedBox(height: 12),

              const Text(
                'Tap the red button to stop',
                style: TextStyle(color: Colors.white54),
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
    final Duration total = _effectiveVoiceDuration;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                size: 46,
                color: Color(0xFF29B6F6),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Play Review',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            _buildWaveform(recording: false),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: <Widget>[
                  //===================================================
                  // PLAY / PAUSE
                  //===================================================

                  GestureDetector(
                    onTap: _toggleVoicePreview,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF29B6F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isVoicePlaying
                            ? Icons.pause_rounded
                            : _voiceCompleted
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  //===================================================
                  // SLIDER + TIME
                  //===================================================
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                            activeTrackColor: const Color(0xFF29B6F6),
                            thumbColor: const Color(0xFF29B6F6),
                            inactiveTrackColor: Colors.white24,
                          ),
                          child: Slider(
                            min: 0,
                            max: 1,
                            value: _voiceSliderValue,
                            onChanged: _seekVoice,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            children: <Widget>[
                              Text(
                                _formatDuration(_voicePosition),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const Spacer(),

                              Text(
                                _formatDuration(total),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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

            const SizedBox(height: 20),

            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: _startRecording,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Record Again'),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: _deleteVoiceRecording,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
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

  Widget _buildWaveform({required bool recording}) {
    return SizedBox(
      height: 62,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _waveformHeights.map((double height) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: recording ? height : height.clamp(10, 48).toDouble(),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: recording ? Colors.redAccent : const Color(0xFF29B6F6),
              borderRadius: BorderRadius.circular(5),
            ),
          );
        }).toList(),
      ),
    );
  }

  //===================================================
  // EDITING CONTROLS
  //===================================================

  Widget _buildEditingControls() {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: <Widget>[
          _controlButton(
            icon: Icons.person_add_alt,
            label: 'Tag',
            onTap: _pickTaggedPeople,
          ),

          _controlButton(
            icon: Icons.emoji_emotions_outlined,
            label: 'Sticker',
            onTap: _showStickers,
          ),

          if (_mode == 'layout')
            _controlButton(
              icon: Icons.dashboard_customize_outlined,
              label: 'Layout',
              onTap: _showLayoutSettings,
            ),
          _controlButton(
            icon: Icons.link_rounded,

            label: 'Link',

            onTap: _openStoryLinkPicker,
          ),

          _controlButton(
            icon: Icons.format_align_center,
            label: 'Align',
            onTap: _cycleTextAlignment,
          ),

          _controlButton(
            icon: Icons.format_bold,
            label: 'Style',
            onTap: _showTextStylePicker,
          ),

          _controlButton(
            icon: Icons.palette_outlined,
            label: 'Background',
            onTap: _showBackgroundColorPicker,
          ),

          _controlButton(
            icon: Icons.format_color_text,
            label: 'Text',
            onTap: _showTextColorPicker,
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
      onTap: onTap,
      child: Container(
        width: 78,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white70, size: 21),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
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
      color: Colors.black54,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
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
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white70, size: 58),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
      color: Color(_textColor),
      fontSize: _textSize,
      fontWeight: _textStyle == 'bold' ? FontWeight.w800 : FontWeight.w500,
      fontStyle: _textStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
      fontFamily: _textStyle == 'mono' ? 'monospace' : null,
      shadows: const <Shadow>[Shadow(color: Colors.black45, blurRadius: 5)],
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
      if (_textAlign == 'center') {
        _textAlign = 'left';
      } else if (_textAlign == 'left') {
        _textAlign = 'right';
      } else {
        _textAlign = 'center';
      }
    });
  }

  //===================================================
  // TEXT STYLE PICKER
  //
  // SHOW ALL AVAILABLE STYLES AT ONCE.
  //===================================================

  Future<void> _showTextStylePicker() async {
    final List<Map<String, dynamic>> styles = <Map<String, dynamic>>[
      <String, dynamic>{
        'value': 'regular',
        'label': 'Regular',
        'icon': Icons.text_fields_rounded,
      },
      <String, dynamic>{
        'value': 'bold',
        'label': 'Bold',
        'icon': Icons.format_bold_rounded,
      },
      <String, dynamic>{
        'value': 'italic',
        'label': 'Italic',
        'icon': Icons.format_italic_rounded,
      },
      <String, dynamic>{
        'value': 'mono',
        'label': 'Mono',
        'icon': Icons.code_rounded,
      },
    ];

    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Text Style',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 13),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: styles.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> item = styles[index];

                    final String value = item['value'] as String;

                    final String label = item['label'] as String;

                    final IconData icon = item['icon'] as IconData;

                    final bool active = _textStyle == value;

                    TextStyle previewStyle = const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                    );

                    if (value == 'bold') {
                      previewStyle = previewStyle.copyWith(
                        fontWeight: FontWeight.w800,
                      );
                    } else if (value == 'italic') {
                      previewStyle = previewStyle.copyWith(
                        fontStyle: FontStyle.italic,
                      );
                    } else if (value == 'mono') {
                      previewStyle = previewStyle.copyWith(
                        fontFamily: 'monospace',
                      );
                    }

                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        Navigator.pop(sheetContext, value);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF29B6F6).withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF29B6F6)
                                : Colors.white24,
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: <Widget>[
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    icon,
                                    color: active
                                        ? const Color(0xFF29B6F6)
                                        : Colors.white70,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(label, style: previewStyle),
                                ],
                              ),
                            ),
                            //===================================================
                            // STORY LINK PREVIEW
                            //===================================================

                            if (_storyLinkUrl.trim().isNotEmpty)
                              Positioned.fill(
                                child: StoryLinkPreviewOverlay(
                                  url: _storyLinkUrl,

                                  style: _storyLinkStyle,

                                  x: _storyLinkX,

                                  y: _storyLinkY,

                                  scale: _storyLinkScale,

                                  editable: true,

                                  onChanged:
                                      (double x, double y, double scale) {
                                        setState(() {
                                          _storyLinkX = x;

                                          _storyLinkY = y;

                                          _storyLinkScale = scale;
                                        });
                                      },
                                ),
                              ),

                            if (active)
                              const Positioned(
                                top: 7,
                                right: 7,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF29B6F6),
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _textStyle = selected;
    });
  }

  //===================================================
  // BACKGROUND COLOR PICKER
  //===================================================

  Future<void> _showBackgroundColorPicker() async {
    final int? selected = await _showColorPickerSheet(
      title: 'Background Color',
      colors: _backgroundColors,
      selectedColor: _backgroundColor,
      previewTextColor: Colors.white,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _backgroundColor = selected;
    });
  }

  //===================================================
  // TEXT COLOR PICKER
  //===================================================

  Future<void> _showTextColorPicker() async {
    final int? selected = await _showColorPickerSheet(
      title: 'Text Color',
      colors: _textColors,
      selectedColor: _textColor,
      previewTextColor: Color(_textColor),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _textColor = selected;
    });
  }

  //===================================================
  // SHARED COLOR PICKER SHEET
  //===================================================

  Future<int?> _showColorPickerSheet({
    required String title,
    required List<int> colors,
    required int selectedColor,
    required Color previewTextColor,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 13,
                    crossAxisSpacing: 13,
                    childAspectRatio: 1,
                  ),
                  itemCount: colors.length,
                  itemBuilder: (BuildContext context, int index) {
                    final int value = colors[index];

                    final Color color = Color(value);

                    final bool active = value == selectedColor;

                    final bool veryLight = color.computeLuminance() > 0.72;

                    return InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.pop(sheetContext, value);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active
                                ? const Color(0xFF29B6F6)
                                : Colors.white38,
                            width: active ? 4 : 1.5,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: active
                            ? Icon(
                                Icons.check_rounded,
                                color: veryLight ? Colors.black : Colors.white,
                                size: 27,
                              )
                            : null,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 17),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          color: Color(selectedColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38),
                        ),
                      ),

                      const SizedBox(width: 10),

                      const Expanded(
                        child: Text(
                          'Current selection',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //===================================================
  // FORMAT DURATION
  //
  // 0:01
  // 1:05
  // 2:30
  // 5:00
  //===================================================

  String _formatDuration(Duration duration) {
    int seconds = duration.inSeconds;

    if (seconds < 0) {
      seconds = 0;
    }

    final int minutes = seconds ~/ 60;

    final int remaining = seconds % 60;

    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  //===================================================
  // MESSAGE
  //===================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _voiceTimer?.cancel();

    _waveformTimer?.cancel();

    _voicePositionSubscription?.cancel();

    _voiceDurationSubscription?.cancel();

    _audioCompleteSubscription?.cancel();

    _audioPlayer.dispose();

    _audioRecorder.dispose();

    _storyTextController.dispose();

    _captionController.dispose();

    _pollQuestionController.dispose();

    for (final TextEditingController controller in _pollOptionControllers) {
      controller.dispose();
    }

    super.dispose();
  }
}

//===================================================
// LOCAL VIDEO PREVIEW
//===================================================

class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({required this.filePath});

  final String filePath;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;

  bool _loading = true;

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
      final VideoPlayerController controller = VideoPlayerController.file(
        File(widget.filePath),
      );

      await controller.initialize();

      await controller.setLooping(true);

      await controller.setVolume(1);

      await controller.play();

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _controller = controller;

        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;

    if (_loading || controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }

        setState(() {});
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
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

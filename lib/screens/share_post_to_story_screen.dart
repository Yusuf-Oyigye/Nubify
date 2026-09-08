import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import '../widgets/post_media_carousel.dart';
import '../widgets/shared_post_story_card.dart';
import 'story_people_picker_screen.dart';
import '../widgets/draggable_story_tags.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../services/story_sticker_service.dart';

//===================================================
// SHARE POST TO STORY SCREEN
//===================================================

class SharePostToStoryScreen
    extends StatefulWidget {
  final String postId;
  final bool isNubuzz;

  //=============================
  // INSTANT PREVIEW SOURCE
  //=============================

  final Post? initialPost;

  const SharePostToStoryScreen({
    super.key,
    required this.postId,
    this.isNubuzz = false,
    this.initialPost,
  });

  @override
  State<SharePostToStoryScreen> createState() =>
      _SharePostToStoryScreenState();
}

//===================================================
// SHARE POST TO STORY STATE
//===================================================

class _SharePostToStoryScreenState
    extends State<SharePostToStoryScreen> {
  final StoryStickerService
  _storyStickerService =
  StoryStickerService();

  final TextEditingController
  _stickerEmojiController =
  TextEditingController();

  List<String> _recentStickers =
  <String>[];
  //===================================================
  // SERVICES
  //===================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final StoryService _storyService =
      StoryService();

  //===================================================
  // CONTROLLERS
  //===================================================

  final TextEditingController
  _captionController =
      TextEditingController();

  //===================================================
  // STORY EDITOR STATE
  //===================================================

  bool _isPosting = false;

  //=============================
  // PRELOADED STORY OWNER
  //=============================

  StoryPerson? _storyOwnerProfile;

  int _backgroundColor =
      0xFF101114;

  //=============================
// STICKER STATE
//=============================

  String _sticker = '';

//=============================
// STICKER POSITION
//=============================

  double _stickerX =
  0.80;

  double _stickerY =
  0.14;

//=============================
// STICKER SIZE
//=============================

  double _stickerSize =
  54.0;

  double _stickerStartSize =
  54.0;

  List<StoryPerson> _taggedPeople =
  <StoryPerson>[];

  //===================================================
  // COLORS
  //===================================================

  static const List<int> _backgroundColors =
      <int>[
    0xFF101114,
    0xFF102A43,
    0xFF003B5C,
    0xFF5B2C83,
    0xFF7A1F3D,
    0xFF6B4F1D,
    0xFF00695C,
    0xFF263238,
    0xFF1B1B1B,
    0xFF0D47A1,
  ];

  //===================================================
  // STICKERS
  //===================================================

  static const List<String> _stickers =
      <String>[
    '😀',
    '😂',
    '🥰',
    '😍',
    '😎',
    '🔥',
    '❤️',
    '💙',
    '✨',
    '🎉',
    '👏',
    '💯',
    '🤍',
    '🤝',
    '🙌',
    '📚',
    '🎓',
    '🩺',
    '⚽',
    '🎵',
    '📍',
    '☀️',
    '🌙',
    '⭐',
    '✅',
    '💪',
    '🙏',
    '👀',
    '🥳',
    '😅',
  ];

  //=============================
// INIT STATE
//=============================

  @override
  void initState() {
    super.initState();

    // Load the owner while the user is editing the story.
    unawaited(
      _preloadStoryOwner(),
    );

    // Load recent stickers separately.
    unawaited(
      _loadRecentStickers(),
    );
  }
  //=============================
  // PRELOAD STORY OWNER
  //=============================

  Future<void> _preloadStoryOwner() async {
    try {
      final StoryPerson profile =
      await _storyService
          .getCurrentUserProfile();

      if (!mounted) {
        return;
      }

      _storyOwnerProfile =
      profile;
    } catch (error) {
      debugPrint(
        'Story owner preload error: $error',
      );
    }
  }

  //===================================================
// DISPOSE
//===================================================

  @override
  void dispose() {
    _captionController.dispose();
    _stickerEmojiController.dispose();

    super.dispose();
  }

//===================================================
// LOAD RECENT STICKERS
//===================================================

  Future<void> _loadRecentStickers() async {
    final List<String> recent =
    await _storyStickerService
        .getRecentStickers();

    if (!mounted) {
      return;
    }

    setState(() {
      _recentStickers =
          recent;
    });
  }

//===================================================
// SELECT STICKER
//===================================================

  Future<void> _selectSticker(
      String sticker,
      ) async {
    if (sticker.trim().isEmpty) {
      return;
    }

    setState(() {
      _sticker =
          sticker;
    });

    final List<String> recent =
    await _storyStickerService
        .rememberSticker(
      sticker,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _recentStickers =
          recent;
    });
  }
  //===================================================
  // PICK TAGGED PEOPLE
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

    if (!mounted ||
        result == null) {
      return;
    }

    setState(() {
      _taggedPeople =
          result;
    });
  }

  //===================================================
  // PICK BACKGROUND
  //===================================================

  void _pickBackground() {
    showModalBottomSheet<void>(
      context:
      context,
      showDragHandle:
      true,
      builder:
          (
          BuildContext
          sheetContext,
          ) {
        return SafeArea(
          child:
          Padding(
            padding:
            const EdgeInsets
                .fromLTRB(
              18,
              4,
              18,
              24,
            ),
            child:
            Column(
              mainAxisSize:
              MainAxisSize
                  .min,
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children:
              <Widget>[
                const Text(
                  'Story background',
                  style:
                  TextStyle(
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight
                        .bold,
                  ),
                ),

                const SizedBox(
                  height:
                  16,
                ),

                Wrap(
                  spacing:
                  12,
                  runSpacing:
                  12,
                  children:
                  _backgroundColors
                      .map(
                        (
                        int color,
                        ) {
                      final bool
                      selected =
                          _backgroundColor ==
                              color;

                      return GestureDetector(
                        onTap:
                            () {
                          setState(() {
                            _backgroundColor =
                                color;
                          });

                          Navigator.pop(
                            sheetContext,
                          );
                        },
                        child:
                        Container(
                          width:
                          48,
                          height:
                          48,
                          decoration:
                          BoxDecoration(
                            color:
                            Color(
                              color,
                            ),
                            shape:
                            BoxShape
                                .circle,
                            border:
                            Border.all(
                              color:
                              selected
                                  ? const Color(
                                0xFF29B6F6,
                              )
                                  : Colors
                                  .white24,
                              width:
                              selected
                                  ? 4
                                  : 1,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //===================================================
// COMPLETE STICKER PICKER
//===================================================

  void _pickSticker() {
    showModalBottomSheet<void>(
      context:
      context,

      isScrollControlled:
      true,

      showDragHandle:
      true,

      builder:
          (
          BuildContext sheetContext,
          ) {
        return DefaultTabController(
          length:
          2,

          child:
          SafeArea(
            child:
            SizedBox(
              height:
              MediaQuery.of(
                sheetContext,
              ).size.height *
                  0.72,

              child:
              Column(
                children:
                <Widget>[
                  Row(
                    children:
                    <Widget>[
                      const Expanded(
                        child:
                        Padding(
                          padding:
                          EdgeInsets.all(
                            16,
                          ),

                          child:
                          Text(
                            'Story Stickers',

                            style:
                            TextStyle(
                              fontSize:
                              19,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      if (_sticker.isNotEmpty)
                        TextButton(
                          onPressed:
                              () {
                            setState(() {
                              _sticker =
                              '';
                            });

                            Navigator.pop(
                              sheetContext,
                            );
                          },

                          child:
                          const Text(
                            'Remove',
                          ),
                        ),
                    ],
                  ),

                  const TabBar(
                    indicatorColor:
                    Color(
                      0xFF29B6F6,
                    ),

                    labelColor:
                    Color(
                      0xFF29B6F6,
                    ),

                    tabs:
                    <Widget>[
                      Tab(
                        text:
                        'Emojis',
                      ),

                      Tab(
                        text:
                        'Recent',
                      ),
                    ],
                  ),

                  Expanded(
                    child:
                    TabBarView(
                      children:
                      <Widget>[
                        //===================================================
                        // COMPLETE EMOJI COLLECTION
                        //===================================================

                        EmojiPicker(
                          textEditingController:
                          _stickerEmojiController,

                          onEmojiSelected:
                              (
                              Category?
                              category,
                              Emoji emoji,
                              ) async {
                            await _selectSticker(
                              emoji.emoji,
                            );

                            _stickerEmojiController
                                .clear();

                            if (sheetContext
                                .mounted) {
                              Navigator.pop(
                                sheetContext,
                              );
                            }
                          },

                          config:
                          const Config(
                            height:
                            420,

                            checkPlatformCompatibility:
                            true,

                            emojiViewConfig:
                            EmojiViewConfig(
                              emojiSizeMax:
                              34,
                            ),

                            viewOrderConfig:
                            ViewOrderConfig(
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
                            SkinToneConfig(),

                            categoryViewConfig:
                            CategoryViewConfig(),

                            bottomActionBarConfig:
                            BottomActionBarConfig(),

                            searchViewConfig:
                            SearchViewConfig(),
                          ),
                        ),

                        //===================================================
                        // RECENT
                        //===================================================

                        _recentStickers.isEmpty
                            ? const Center(
                          child:
                          Text(
                            'No recent stickers yet.',
                          ),
                        )
                            : GridView.builder(
                          padding:
                          const EdgeInsets.all(
                            16,
                          ),

                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                            7,
                          ),

                          itemCount:
                          _recentStickers.length,

                          itemBuilder:
                              (
                              BuildContext context,
                              int index,
                              ) {
                            final String sticker =
                            _recentStickers[
                            index];

                            return InkWell(
                              onTap:
                                  () async {
                                await _selectSticker(
                                  sticker,
                                );

                                if (sheetContext
                                    .mounted) {
                                  Navigator.pop(
                                    sheetContext,
                                  );
                                }
                              },

                              child:
                              Center(
                                child:
                                Text(
                                  sticker,

                                  style:
                                  const TextStyle(
                                    fontSize:
                                    31,
                                  ),
                                ),
                              ),
                            );
                          },
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

    final User? firebaseUser =
    FirebaseAuth.instance
        .currentUser;

    if (firebaseUser == null) {
      ScaffoldMessenger
          .of(
        context,
      )
          .showSnackBar(
        const SnackBar(
          content:
          Text(
            'Please sign in again before adding this story.',
          ),
        ),
      );

      return;
    }

    //=============================
    // BLOCK DOUBLE TAP WITHOUT SPINNER
    //=============================
    //
    // Do not rebuild the button into a loading indicator.
    // The optimistic Firestore write is queued immediately and
    // this screen closes as soon as the local write is created.

    _isPosting =
    true;

    //=============================
    // INSTANT STORY OWNER FALLBACK
    //=============================

    final String fallbackName =
    (firebaseUser.displayName ?? '')
        .trim();

    final StoryPerson owner =
    _storyOwnerProfile ??
        StoryPerson(
          uid:
          firebaseUser.uid,
          username:
          fallbackName.isNotEmpty
              ? fallbackName
              : 'user',
          fullName:
          fallbackName,
          photoUrl:
          (firebaseUser.photoURL ?? '')
              .trim(),
        );

    try {
      //=============================
      // OPTIMISTIC STORY CREATION
      //
      // The write is queued in Firestore immediately and this
      // screen closes without waiting for the server ACK.
      //=============================

      final String storyId =
      await _storyService
          .createStory(
        type:
        widget.isNubuzz
            ? 'videoShare'
            : 'postShare',
        postId:
        widget.postId,

//=============================
// STICKER CONTENT
//=============================

        text:
        _sticker,

//=============================
// STICKER POSITION
//=============================

        textAlign:
        _sticker.isEmpty
            ? 'center'
            : 'sticker:${_stickerX.toStringAsFixed(4)},${_stickerY.toStringAsFixed(4)}',

//=============================
// STICKER SIZE
//=============================

        textSize:
        _stickerSize,

        caption:
        _captionController
            .text
            .trim(),

        backgroundColor:
        _backgroundColor,

        taggedPeople:
        _taggedPeople,
        durationSeconds:
        widget.isNubuzz
            ? 15
            : 10,
        ownerProfile:
        owner,
        optimisticWrite:
        true,
      );

      //=============================
      // REFRESH FALLBACK OWNER DATA
      //=============================

      if (_storyOwnerProfile ==
          null) {
        unawaited(
          _refreshStoryOwnerAfterPost(
            storyId,
          ),
        );
      }

      //===================================================
      // SHARE COUNT IS BEST-EFFORT
      //===================================================

      unawaited(
        _firestore
            .collection(
          'posts',
        )
            .doc(
          widget.postId,
        )
            .update(
          <String, dynamic>{
            'shareCount':
            FieldValue
                .increment(
              1,
            ),
          },
        )
            .catchError(
          (
          Object error,
          ) {
            debugPrint(
              'Story share-count error: $error',
            );
          },
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPosting =
        false;
      });

      ScaffoldMessenger
          .of(
        context,
      )
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Unable to add story: $error',
          ),
        ),
      );
    }
  }

  //=============================
  // REFRESH STORY OWNER
  //=============================

  Future<void> _refreshStoryOwnerAfterPost(
      String storyId,
      ) async {
    try {
      final StoryPerson profile =
      await _storyService
          .getCurrentUserProfile();

      _storyOwnerProfile =
      profile;

      await _firestore
          .collection(
        'stories',
      )
          .doc(
        storyId,
      )
          .update(
        <String, dynamic>{
          'username':
          profile.username,
          'fullName':
          profile.fullName,
          'photoUrl':
          profile.photoUrl,
        },
      );
    } catch (error) {
      debugPrint(
        'Story owner refresh error: $error',
      );
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
        foregroundColor:
        Colors.white,
        title:
        const Text(
          'Share to Story',
        ),
        actions:
        <Widget>[
          Padding(
            padding:
            const EdgeInsets
                .only(
              right:
              10,
            ),
            child:
            FilledButton(
              onPressed:
              _isPosting
                  ? null
                  : _postStory,
              style:
              FilledButton
                  .styleFrom(
                backgroundColor:
                const Color(
                  0xFF29B6F6,
                ),
                foregroundColor:
                Colors.white,
              ),
              child:
              _isPosting
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
                  : const Text(
                'Add to Story',
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
            //===================================================
            // STORY PREVIEW
            //===================================================

            Expanded(
              child:
              Padding(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  14,
                  10,
                  14,
                  8,
                ),
                child:
                ClipRRect(
                  borderRadius:
                  BorderRadius
                      .circular(
                    24,
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
                      children:
                      <Widget>[
                        Positioned.fill(
                          child:
                          Align(
                            alignment:
                            Alignment.center,
                            child:
                            SingleChildScrollView(
                              padding:
                              const EdgeInsets
                                  .fromLTRB(
                                18,
                                60,
                                18,
                                120,
                              ),
                              child:
                              _buildSharedPostPreview(),
                            ),
                          ),
                        ),
//===================================================
// STICKER PREVIEW
//===================================================

                        if (_sticker.isNotEmpty)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                  ) {
                                return Stack(
                                  clipBehavior:
                                  Clip.none,
                                  children: <Widget>[
                                    Positioned(
                                      left:
                                      (_stickerX *
                                          constraints
                                              .maxWidth)
                                          .clamp(
                                        0.0,
                                        constraints
                                            .maxWidth,
                                      )
                                          .toDouble(),
                                      top:
                                      (_stickerY *
                                          constraints
                                              .maxHeight)
                                          .clamp(
                                        0.0,
                                        constraints
                                            .maxHeight,
                                      )
                                          .toDouble(),
                                      child:
                                      Transform.translate(
                                        offset: Offset(
                                          -_stickerSize *
                                              0.55,
                                          -_stickerSize *
                                              0.55,
                                        ),
                                        child:
                                        GestureDetector(
                                          behavior:
                                          HitTestBehavior
                                              .translucent,

                                          //=============================
                                          // START GESTURE
                                          //=============================

                                          onScaleStart:
                                              (
                                              ScaleStartDetails
                                              details,
                                              ) {
                                            _stickerStartSize =
                                                _stickerSize;
                                          },

                                          //=============================
                                          // DRAG + RESIZE
                                          //=============================

                                          onScaleUpdate:
                                              (
                                              ScaleUpdateDetails
                                              details,
                                              ) {
                                            if (!mounted) {
                                              return;
                                            }

                                            setState(() {
                                              if (constraints
                                                  .maxWidth >
                                                  0) {
                                                _stickerX =
                                                    (_stickerX +
                                                        details
                                                            .focalPointDelta
                                                            .dx /
                                                            constraints
                                                                .maxWidth)
                                                        .clamp(
                                                      0.04,
                                                      0.96,
                                                    )
                                                        .toDouble();
                                              }

                                              if (constraints
                                                  .maxHeight >
                                                  0) {
                                                _stickerY =
                                                    (_stickerY +
                                                        details
                                                            .focalPointDelta
                                                            .dy /
                                                            constraints
                                                                .maxHeight)
                                                        .clamp(
                                                      0.04,
                                                      0.96,
                                                    )
                                                        .toDouble();
                                              }

                                              _stickerSize =
                                                  (_stickerStartSize *
                                                      details
                                                          .scale)
                                                      .clamp(
                                                    28.0,
                                                    120.0,
                                                  )
                                                      .toDouble();
                                            });
                                          },

                                          //=============================
                                          // END GESTURE
                                          //=============================

                                          onScaleEnd:
                                              (
                                              ScaleEndDetails
                                              details,
                                              ) {
                                            _stickerStartSize =
                                                _stickerSize;
                                          },

                                          child: Padding(
                                            padding:
                                            const EdgeInsets
                                                .all(
                                              12,
                                            ),
                                            child: Text(
                                              _sticker,
                                              style:
                                              TextStyle(
                                                fontSize:
                                                _stickerSize,
                                                height:
                                                1,
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

                        //===================================================
// DRAGGABLE TAGGED PEOPLE
//===================================================

                        if (_taggedPeople.isNotEmpty)
                          Positioned.fill(
                            child:
                            DraggableStoryTags(
                              people:
                              _taggedPeople,

                              editable:
                              true,

                              onChanged:
                                  (
                                  List<StoryPerson>
                                  people,
                                  ) {
                                setState(() {
                                  _taggedPeople =
                                      people;
                                });
                              },
                            ),
                          ),

                        //===================================================
                        // CAPTION PREVIEW
                        //===================================================

                        Positioned(
                          left:
                          16,
                          right:
                          16,
                          bottom:
                          MediaQuery.of(
                            context,
                          ).padding.bottom +
                              18,
                          child:
                          TextField(
                            controller:
                            _captionController,
                            maxLines:
                            2,
                            textAlign:
                            TextAlign
                                .center,
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                            decoration:
                            InputDecoration(
                              hintText:
                              'Add a caption...',
                              hintStyle:
                              const TextStyle(
                                color:
                                Colors.white60,
                              ),
                              filled:
                              true,
                              fillColor:
                              Colors
                                  .black
                                  .withOpacity(
                                0.28,
                              ),
                              contentPadding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal:
                                14,
                                vertical:
                                10,
                              ),
                              border:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  18,
                                ),
                                borderSide:
                                BorderSide
                                    .none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            //===================================================
            // STORY EDITOR TOOLS
            //===================================================

            Container(
              padding:
              const EdgeInsets
                  .fromLTRB(
                12,
                8,
                12,
                12,
              ),
              color:
              Colors.black,
              child:
              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceEvenly,
                children:
                <Widget>[
                  _toolButton(
                    icon:
                    Icons
                        .palette_outlined,
                    label:
                    'Background',
                    onTap:
                    _pickBackground,
                  ),

                  _toolButton(
                    icon:
                    Icons
                        .emoji_emotions_outlined,
                    label:
                    'Sticker',
                    onTap:
                    _pickSticker,
                  ),

                  _toolButton(
                    icon:
                    Icons
                        .alternate_email,
                    label:
                    'Tag',
                    onTap:
                    _pickTaggedPeople,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // SHARED POST PREVIEW
  //===================================================

  Widget _buildSharedPostPreview() {
    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream:
      _firestore
          .collection(
        'posts',
      )
          .doc(
        widget.postId,
      )
          .snapshots(),
      builder:
          (
          BuildContext
          context,
          AsyncSnapshot<
              DocumentSnapshot<
                  Map<String, dynamic>>>
          snapshot,
          ) {
        if (!snapshot.hasData) {
          final Post? initialPost =
          widget.initialPost;

          if (initialPost !=
              null) {
            return _sharedFullPostCard(
              initialPost,
            );
          }

          return const Center(
            child:
            CircularProgressIndicator(
              color:
              Color(
                0xFF29B6F6,
              ),
            ),
          );
        }

        if (!snapshot.data!.exists ||
            snapshot.data!.data() ==
                null) {
          return _unavailableCard(
            'This post is no longer available.',
          );
        }

        try {
          final Post post =
          Post.fromFirestore(
            snapshot.data!,
          );

          return _sharedFullPostCard(
            post,
          );
        } catch (error) {
          return _unavailableCard(
            'Unable to preview this post.',
          );
        }
      },
    );
  }

  //=============================
  // FULL SHARED POST CARD
  //
  // Shows caption, poll, media, direct repost parent chain,
  // and Like / Comment / Repost / Share for every level.
  //=============================

  Widget _sharedFullPostCard(
      Post post,
      ) {
    return SharedPostStoryCard(
      post:
      post,
      maxWidth:
      430,
    );
  }

  //===================================================
  // SHARED POST CARD
  //===================================================

  Widget _sharedPostCard(
      Post post,
      ) {
    final String displayName =
    post.fullName
        .trim()
        .isNotEmpty
        ? post.fullName
        .trim()
        : post.username
        .trim()
        .isNotEmpty
        ? post.username
        .trim()
        : 'Nubify User';

    return Container(
      width:
      double.infinity,
      constraints:
      const BoxConstraints(
        maxWidth:
        430,
      ),
      clipBehavior:
      Clip.antiAlias,
      decoration:
      BoxDecoration(
        color:
        Theme.of(
          context,
        ).cardColor,
        borderRadius:
        BorderRadius
            .circular(
          20,
        ),
        border:
        Border.all(
          color:
          Colors.white24,
        ),
        boxShadow:
        <BoxShadow>[
          BoxShadow(
            color:
            Colors.black
                .withOpacity(
              0.22,
            ),
            blurRadius:
            18,
            offset:
            const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children:
        <Widget>[
          Padding(
            padding:
            const EdgeInsets
                .all(
              12,
            ),
            child:
            Row(
              children:
              <Widget>[
                CircleAvatar(
                  radius:
                  20,
                  backgroundImage:
                  post.photoUrl
                      .trim()
                      .isNotEmpty
                      ? NetworkImage(
                    post.photoUrl,
                  )
                      : null,
                  child:
                  post.photoUrl
                      .trim()
                      .isEmpty
                      ? const Icon(
                    Icons.person,
                  )
                      : null,
                ),

                const SizedBox(
                  width:
                  9,
                ),

                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children:
                    <Widget>[
                      Text(
                        displayName,
                        maxLines:
                        1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      Text(
                        '@${post.username}',
                        maxLines:
                        1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        TextStyle(
                          color:
                          Colors
                              .grey
                              .shade500,
                          fontSize:
                          12,
                        ),
                      ),
                    ],
                  ),
                ),

                if (post.isNUBuzz)
                  const Icon(
                    Icons
                        .play_circle_fill_rounded,
                    color:
                    Color(
                      0xFF29B6F6,
                    ),
                  ),
              ],
            ),
          ),

          if (post.caption
              .trim()
              .isNotEmpty)
            Padding(
              padding:
              const EdgeInsets
                  .fromLTRB(
                12,
                0,
                12,
                12,
              ),
              child:
              Text(
                post.caption
                    .trim(),
                maxLines:
                5,
                overflow:
                TextOverflow
                    .ellipsis,
                style:
                const TextStyle(
                  fontSize:
                  15,
                  height:
                  1.35,
                ),
              ),
            ),

          if (post.media
              .isNotEmpty)
            SizedBox(
              width:
              double.infinity,
              height:
              widget.isNubuzz
                  ? 330
                  : 280,
              child:
              PostMediaCarousel(
                media:
                post.media,
              ),
            ),

          Padding(
            padding:
            const EdgeInsets
                .fromLTRB(
              12,
              10,
              12,
              12,
            ),
            child:
            Row(
              children:
              <Widget>[
                const Icon(
                  Icons.favorite_border,
                  size:
                  18,
                ),

                const SizedBox(
                  width:
                  4,
                ),

                Text(
                  '${post.likeCount}',
                ),

                const SizedBox(
                  width:
                  16,
                ),

                const Icon(
                  Icons
                      .chat_bubble_outline,
                  size:
                  17,
                ),

                const SizedBox(
                  width:
                  4,
                ),

                Text(
                  '${post.commentCount}',
                ),

                const SizedBox(
                  width:
                  16,
                ),

                const Icon(
                  Icons
                      .repeat_rounded,
                  size:
                  19,
                ),

                const SizedBox(
                  width:
                  4,
                ),

                Text(
                  '${post.repostCount}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // UNAVAILABLE CARD
  //===================================================

  Widget _unavailableCard(
      String message,
      ) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets
          .all(
        24,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.black38,
        borderRadius:
        BorderRadius
            .circular(
          18,
        ),
        border:
        Border.all(
          color:
          Colors.white24,
        ),
      ),
      child:
      Column(
        mainAxisSize:
        MainAxisSize
            .min,
        children:
        <Widget>[
          const Icon(
            Icons
                .insert_drive_file_outlined,
            color:
            Colors.white70,
            size:
            42,
          ),

          const SizedBox(
            height:
            10,
          ),

          Text(
            message,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              color:
              Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // TOOL BUTTON
  //===================================================

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap:
      onTap,
      borderRadius:
      BorderRadius
          .circular(
        18,
      ),
      child:
      Padding(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal:
          12,
          vertical:
          8,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize
              .min,
          children:
          <Widget>[
            Container(
              width:
              44,
              height:
              44,
              decoration:
              BoxDecoration(
                color:
                Colors.white10,
                shape:
                BoxShape.circle,
                border:
                Border.all(
                  color:
                  Colors.white24,
                ),
              ),
              alignment:
              Alignment.center,
              child:
              Icon(
                icon,
                color:
                Colors.white,
              ),
            ),

            const SizedBox(
              height:
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

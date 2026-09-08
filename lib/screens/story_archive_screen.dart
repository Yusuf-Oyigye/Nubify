import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/post.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import 'story_viewer_screen.dart';
//============================
// STORY ARCHIVE SCREEN
//============================

class StoryArchiveScreen
    extends StatelessWidget {
  const StoryArchiveScreen({
    super.key,
  });

  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

  @override
  Widget build(
      BuildContext context,
      ) {
    final StoryService storyService =
    StoryService();

    return Scaffold(
      appBar:
      AppBar(
        title:
        const Text(
          'Story Archive',
          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body:
      StreamBuilder<List<NubifyStory>>(
        stream:
        storyService
            .watchMyStoryArchive(),

        builder:
            (
            BuildContext context,
            AsyncSnapshot<List<NubifyStory>>
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(
                color:
                _blue,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child:
              Text(
                'Unable to load Story Archive.\n'
                    '${snapshot.error}',
                textAlign:
                TextAlign.center,
              ),
            );
          }

          final List<NubifyStory> stories =
              snapshot.data ??
                  <NubifyStory>[];

          if (stories.isEmpty) {
            return const Center(
              child:
              Padding(
                padding:
                EdgeInsets.all(
                  30,
                ),
                child:
                Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children:
                  <Widget>[
                    Icon(
                      Icons
                          .archive_outlined,
                      color:
                      _blue,
                      size:
                      58,
                    ),

                    SizedBox(
                      height:
                      12,
                    ),

                    Text(
                      'No archived Stories yet',
                      style:
                      TextStyle(
                        fontSize:
                        17,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height:
                      5,
                    ),

                    Text(
                      'Stories you share will appear here.',
                      textAlign:
                      TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding:
            const EdgeInsets.all(
              12,
            ),

            itemCount:
            stories.length,

            separatorBuilder:
                (
                BuildContext context,
                int index,
                ) {
              return const SizedBox(
                height:
                8,
              );
            },

            itemBuilder:
                (
                BuildContext context,
                int index,
                ) {
              final NubifyStory story =
              stories[index];

              return _ArchiveStoryTile(
                story:
                story,

                onTap:
                    () {
                  Navigator.push(
                    context,

                    MaterialPageRoute<void>(
                      builder:
                          (_) =>
                          StoryViewerScreen(
                            stories:
                            <NubifyStory>[
                              story,
                            ],

                            allowExpiredStories:
                            true,
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

//============================
// ARCHIVE STORY TILE
//============================

class _ArchiveStoryTile
    extends StatelessWidget {
  const _ArchiveStoryTile({
    required this.story,
    required this.onTap,
  });

  final NubifyStory story;

  final VoidCallback onTap;

  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

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
      Container(
        padding:
        const EdgeInsets.all(
          12,
        ),

        decoration:
        BoxDecoration(
          borderRadius:
          BorderRadius.circular(
            16,
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
            //============================
            // PREVIEW
            //============================

            _buildPreview(),

            const SizedBox(
              width:
              12,
            ),

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children:
                <Widget>[
                  Text(
                    _storyTypeName(
                      story.type,
                    ),

                    style:
                    const TextStyle(
                      fontSize:
                      15,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                    4,
                  ),

                  Text(
                    _formatDate(
                      story.createdAt,
                    ),

                    style:
                    TextStyle(
                      color:
                      Colors.grey.shade500,
                      fontSize:
                      12,
                    ),
                  ),

                  if (story.caption
                      .trim()
                      .isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        top:
                        5,
                      ),

                      child:
                      Text(
                        story.caption.trim(),

                        maxLines:
                        2,

                        overflow:
                        TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(
              width:
              8,
            ),

            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal:
                8,
                vertical:
                4,
              ),

              decoration:
              BoxDecoration(
                color:
                story.isExpired
                    ? Colors.white10
                    : _blue.withOpacity(
                  0.15,
                ),

                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),

              child:
              Text(
                story.isExpired
                    ? 'Archived'
                    : 'Active',

                style:
                TextStyle(
                  color:
                  story.isExpired
                      ? Colors.grey
                      : _blue,

                  fontSize:
                  11,

                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

//============================
// REAL STORY PREVIEW
//============================

  Widget _buildPreview() {
    return ClipRRect(
      borderRadius:
      BorderRadius.circular(
        12,
      ),
      child:
      SizedBox(
        width:
        65,
        height:
        85,
        child:
        _ArchiveStoryPreview(
          story:
          story,
        ),
      ),
    );
  }
  String _storyTypeName(
      String type,
      ) {
    switch (type) {
      case 'image':
        return 'Photo Story';

      case 'video':
        return 'Video Story';

      case 'voice':
        return 'Voice Story';

      case 'layout':
        return 'Layout Story';

      case 'poll':
        return 'Poll Story';

      case 'postShare':
      case 'post_share':
        return 'Shared Post';

      case 'videoShare':
      case 'video_share':
        return 'Shared Video';

      case 'reshare':
        return 'Reshared Story';

      default:
        return 'Text Story';
    }
  }

  String _formatDate(
      DateTime date,
      ) {
    final int hour =
    date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final String minute =
    date.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    final String period =
    date.hour >= 12
        ? 'PM'
        : 'AM';

    return '${date.day}/${date.month}/${date.year} '
        '$hour:$minute $period';
  }
}
//===================================================
// ARCHIVE REAL STORY PREVIEW
//===================================================

class _ArchiveStoryPreview
    extends StatelessWidget {
  const _ArchiveStoryPreview({
    required this.story,
  });

  final NubifyStory story;

  @override
  Widget build(
      BuildContext context,
      ) {
    switch (story.type) {
    //============================
    // IMAGE STORY
    //============================

      case 'image':
        return _imagePreview(
          story.mediaUrl,
        );

    //============================
    // VIDEO STORY
    //============================

      case 'video':
        return _ArchiveVideoThumbnail(
          url:
          story.mediaUrl,
        );

    //============================
    // LAYOUT STORY
    //============================

      case 'layout':
        return _ArchiveLayoutThumbnail(
          story:
          story,
        );

    //============================
    // SHARED POST / REPOST
    //============================

      case 'postShare':
      case 'post_share':
      case 'videoShare':
      case 'video_share':
        return _ArchiveSharedPostThumbnail(
          postId:
          story.postId,

          backgroundColor:
          story.backgroundColor,
        );

    //============================
    // VOICE STORY
    //============================

      case 'voice':
        return Container(
          color:
          Color(
            story.backgroundColor,
          ),

          child:
          const Column(
            mainAxisAlignment:
            MainAxisAlignment.center,

            children:
            <Widget>[
              Icon(
                Icons.mic_rounded,
                color:
                Color(
                  0xFF29B6F6,
                ),
                size:
                26,
              ),

              SizedBox(
                height:
                8,
              ),

              Row(
                mainAxisAlignment:
                MainAxisAlignment.center,

                children:
                <Widget>[
                  _ArchiveWaveBar(
                    height:
                    10,
                  ),
                  _ArchiveWaveBar(
                    height:
                    18,
                  ),
                  _ArchiveWaveBar(
                    height:
                    13,
                  ),
                  _ArchiveWaveBar(
                    height:
                    22,
                  ),
                  _ArchiveWaveBar(
                    height:
                    15,
                  ),
                ],
              ),
            ],
          ),
        );

    //============================
    // POLL STORY
    //============================

      case 'poll':
        return _pollPreview();

    //============================
    // RESHARED STORY
    //============================

      case 'reshare':
        if (story.sourceMediaUrl
            .trim()
            .isNotEmpty) {
          if (story.sourceType ==
              'video') {
            return _ArchiveVideoThumbnail(
              url:
              story.sourceMediaUrl,
            );
          }

          return _imagePreview(
            story.sourceMediaUrl,
          );
        }

        return _textPreview(
          story.sourceText,
        );

    //============================
    // TEXT STORY
    //============================

      case 'text':
      default:
        return _textPreview(
          story.text,
        );
    }
  }

  //============================
  // IMAGE PREVIEW
  //============================

  Widget _imagePreview(
      String url,
      ) {
    if (url.trim().isEmpty) {
      return _textPreview(
        story.text,
      );
    }

    return Image.network(
      url,

      width:
      double.infinity,

      height:
      double.infinity,

      fit:
      BoxFit.cover,

      loadingBuilder:
          (
          BuildContext context,
          Widget child,
          ImageChunkEvent? loadingProgress,
          ) {
        if (loadingProgress ==
            null) {
          return child;
        }

        return Container(
          color:
          Colors.black,

          alignment:
          Alignment.center,

          child:
          const SizedBox(
            width:
            16,
            height:
            16,
            child:
            CircularProgressIndicator(
              strokeWidth:
              2,
              color:
              Color(
                0xFF29B6F6,
              ),
            ),
          ),
        );
      },

      errorBuilder:
          (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
          ) {
        return _textPreview(
          story.text,
        );
      },
    );
  }

  //============================
  // TEXT PREVIEW
  //============================

  Widget _textPreview(
      String text,
      ) {
    return Container(
      color:
      Color(
        story.backgroundColor,
      ),

      padding:
      const EdgeInsets.all(
        6,
      ),

      alignment:
      Alignment.center,

      child:
      Text(
        text.trim().isEmpty
            ? 'Story'
            : text.trim(),

        maxLines:
        5,

        overflow:
        TextOverflow.ellipsis,

        textAlign:
        TextAlign.center,

        style:
        TextStyle(
          color:
          Color(
            story.textColor,
          ),

          fontSize:
          9,

          fontWeight:
          FontWeight.bold,
        ),
      ),
    );
  }

  //============================
  // POLL PREVIEW
  //============================

  Widget _pollPreview() {
    final String question =
        story.poll
            ?.question
            .trim() ??
            '';

    return Container(
      color:
      Color(
        story.backgroundColor,
      ),

      padding:
      const EdgeInsets.all(
        6,
      ),

      child:
      Column(
        mainAxisAlignment:
        MainAxisAlignment.center,

        children:
        <Widget>[
          Text(
            question.isEmpty
                ? 'Poll'
                : question,

            maxLines:
            2,

            overflow:
            TextOverflow.ellipsis,

            textAlign:
            TextAlign.center,

            style:
            const TextStyle(
              color:
              Colors.white,

              fontSize:
              8,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            6,
          ),

          _pollBar(),

          const SizedBox(
            height:
            4,
          ),

          _pollBar(),
        ],
      ),
    );
  }

  Widget _pollBar() {
    return Container(
      height:
      9,

      decoration:
      BoxDecoration(
        color:
        Colors.white12,

        borderRadius:
        BorderRadius.circular(
          6,
        ),
      ),
    );
  }
}

//===================================================
// ARCHIVE VIDEO THUMBNAIL
//===================================================

class _ArchiveVideoThumbnail
    extends StatefulWidget {
  const _ArchiveVideoThumbnail({
    required this.url,
  });

  final String url;

  @override
  State<_ArchiveVideoThumbnail>
  createState() =>
      _ArchiveVideoThumbnailState();
}

class _ArchiveVideoThumbnailState
    extends State<
        _ArchiveVideoThumbnail> {
  VideoPlayerController?
  _controller;

  bool _ready =
  false;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    final String url =
    widget.url.trim();

    if (url.isEmpty) {
      return;
    }

    try {
      final VideoPlayerController controller =
      VideoPlayerController.networkUrl(
        Uri.parse(
          url,
        ),

        videoPlayerOptions:
        VideoPlayerOptions(
          mixWithOthers:
          true,
        ),
      );

      await controller.initialize();

      //============================
      // THUMBNAIL MUST BE SILENT
      //============================

      await controller.setVolume(
        0.0,
      );

      //============================
      // MOVE SLIGHTLY INTO VIDEO
      // SO WE GET A REAL FRAME
      // INSTEAD OF A BLACK FIRST FRAME
      //============================

      if (controller
          .value
          .duration
          .inMilliseconds >
          300) {
        await controller.seekTo(
          const Duration(
            milliseconds:
            200,
          ),
        );
      }

      await controller.pause();

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _controller =
            controller;

        _ready =
        true;
      });
    } catch (_) {}
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final VideoPlayerController? controller =
        _controller;

    if (!_ready ||
        controller ==
            null) {
      return Container(
        color:
        Colors.black,

        alignment:
        Alignment.center,

        child:
        const SizedBox(
          width:
          16,

          height:
          16,

          child:
          CircularProgressIndicator(
            strokeWidth:
            2,

            color:
            Color(
              0xFF29B6F6,
            ),
          ),
        ),
      );
    }

    return Stack(
      fit:
      StackFit.expand,

      children:
      <Widget>[
        FittedBox(
          fit:
          BoxFit.cover,

          child:
          SizedBox(
            width:
            controller
                .value
                .size
                .width,

            height:
            controller
                .value
                .size
                .height,

            child:
            VideoPlayer(
              controller,
            ),
          ),
        ),

        const Center(
          child:
          Icon(
            Icons
                .play_circle_fill_rounded,

            color:
            Colors.white,

            size:
            24,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();

    super.dispose();
  }
}

//===================================================
// ARCHIVE LAYOUT THUMBNAIL
//===================================================

class _ArchiveLayoutThumbnail
    extends StatelessWidget {
  const _ArchiveLayoutThumbnail({
    required this.story,
  });

  final NubifyStory story;

  @override
  Widget build(
      BuildContext context,
      ) {
    final List<String> urls =
    story.mediaUrls
        .map(
          (
          String url,
          ) =>
          url.trim(),
    )
        .where(
          (
          String url,
          ) =>
      url.isNotEmpty,
    )
        .take(
      4,
    )
        .toList();

    if (urls.isEmpty) {
      return Container(
        color:
        Color(
          story.backgroundColor,
        ),
      );
    }

    return GridView.builder(
      physics:
      const NeverScrollableScrollPhysics(),

      padding:
      EdgeInsets.zero,

      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
        2,
      ),

      itemCount:
      urls.length,

      itemBuilder:
          (
          BuildContext context,
          int index,
          ) {
        return Image.network(
          urls[index],

          fit:
          BoxFit.cover,
        );
      },
    );
  }
}

//===================================================
// ARCHIVE SHARED POST THUMBNAIL
//===================================================

class _ArchiveSharedPostThumbnail
    extends StatefulWidget {
  const _ArchiveSharedPostThumbnail({
    required this.postId,
    required this.backgroundColor,
  });

  final String postId;

  final int backgroundColor;

  @override
  State<_ArchiveSharedPostThumbnail>
  createState() =>
      _ArchiveSharedPostThumbnailState();
}

class _ArchiveSharedPostThumbnailState
    extends State<
        _ArchiveSharedPostThumbnail> {
  late Future<_ArchivePostPreview?>
  _future;

  @override
  void initState() {
    super.initState();

    _future =
        _loadPreview();
  }

  Future<_ArchivePostPreview?>
  _loadPreview() async {
    String currentPostId =
    widget.postId.trim();

    String displayName =
        '';

    String previewText =
        '';

    final Set<String> visited =
    <String>{};

    //============================
    // FOLLOW REPOST CHAIN
    // UNTIL REAL MEDIA IS FOUND
    //============================

    for (
    int depth = 0;
    depth < 6;
    depth++
    ) {
      if (currentPostId.isEmpty ||
          visited.contains(
            currentPostId,
          )) {
        break;
      }

      visited.add(
        currentPostId,
      );

      final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await FirebaseFirestore
          .instance
          .collection(
        'posts',
      )
          .doc(
        currentPostId,
      )
          .get();

      if (!snapshot.exists ||
          snapshot.data() ==
              null) {
        break;
      }

      final Post post =
      Post.fromFirestore(
        snapshot,
      );

      if (displayName.isEmpty) {
        displayName =
        post.fullName
            .trim()
            .isNotEmpty
            ? post.fullName.trim()
            : post.username.trim();
      }

      final String currentText =
      post.repostText
          .trim()
          .isNotEmpty
          ? post.repostText.trim()
          : post.caption.trim();

      if (previewText.isEmpty &&
          currentText.isNotEmpty) {
        previewText =
            currentText;
      }

      //============================
      // FOUND REAL MEDIA
      //============================

      if (post.media.isNotEmpty) {
        return _ArchivePostPreview(
          name:
          displayName,

          text:
          previewText,

          media:
          post.media.first,
        );
      }

      //============================
      // FOLLOW DIRECT PARENT
      //============================

      if (post.isRepost &&
          post.sourcePostId
              .trim()
              .isNotEmpty &&
          post.sourcePostId
              .trim() !=
              currentPostId) {
        currentPostId =
            post.sourcePostId.trim();

        continue;
      }

      break;
    }

    if (displayName.isEmpty &&
        previewText.isEmpty) {
      return null;
    }

    return _ArchivePostPreview(
      name:
      displayName,

      text:
      previewText,
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return FutureBuilder<
        _ArchivePostPreview?>(
      future:
      _future,

      builder:
          (
          BuildContext context,
          AsyncSnapshot<
              _ArchivePostPreview?>
          snapshot,
          ) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return _loadingBox();
        }

        final _ArchivePostPreview? preview =
            snapshot.data;

        if (preview ==
            null) {
          return Container(
            color:
            Color(
              widget.backgroundColor,
            ),
          );
        }

        final PostMedia? media =
            preview.media;

        if (media !=
            null) {
          if (media.isVideo) {
            return _ArchiveVideoThumbnail(
              url:
              media.url,
            );
          }

          return Stack(
            fit:
            StackFit.expand,

            children:
            <Widget>[
              Image.network(
                media.url,

                fit:
                BoxFit.cover,
              ),

              if (preview.text
                  .trim()
                  .isNotEmpty)
                Align(
                  alignment:
                  Alignment.bottomCenter,

                  child:
                  Container(
                    width:
                    double.infinity,

                    padding:
                    const EdgeInsets.all(
                      4,
                    ),

                    color:
                    Colors.black54,

                    child:
                    Text(
                      preview.text,

                      maxLines:
                      2,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        color:
                        Colors.white,

                        fontSize:
                        7,

                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        return Container(
          color:
          Color(
            widget.backgroundColor,
          ),

          padding:
          const EdgeInsets.all(
            6,
          ),

          alignment:
          Alignment.center,

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children:
            <Widget>[
              if (preview.name
                  .trim()
                  .isNotEmpty)
                Text(
                  preview.name,

                  maxLines:
                  1,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF29B6F6,
                    ),

                    fontSize:
                    8,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

              const SizedBox(
                height:
                4,
              ),

              Text(
                preview.text,

                maxLines:
                5,

                overflow:
                TextOverflow.ellipsis,

                textAlign:
                TextAlign.center,

                style:
                const TextStyle(
                  color:
                  Colors.white,

                  fontSize:
                  8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingBox() {
    return Container(
      color:
      Color(
        widget.backgroundColor,
      ),

      alignment:
      Alignment.center,

      child:
      const SizedBox(
        width:
        16,

        height:
        16,

        child:
        CircularProgressIndicator(
          strokeWidth:
          2,

          color:
          Color(
            0xFF29B6F6,
          ),
        ),
      ),
    );
  }
}

//===================================================
// ARCHIVE POST PREVIEW DATA
//===================================================

class _ArchivePostPreview {
  const _ArchivePostPreview({
    required this.name,
    required this.text,
    this.media,
  });

  final String name;

  final String text;

  final PostMedia? media;
}

//===================================================
// ARCHIVE VOICE WAVE BAR
//===================================================

class _ArchiveWaveBar
    extends StatelessWidget {
  const _ArchiveWaveBar({
    required this.height,
  });

  final double height;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      3,

      height:
      height,

      margin:
      const EdgeInsets.symmetric(
        horizontal:
        1.5,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFF29B6F6,
        ),

        borderRadius:
        BorderRadius.circular(
          4,
        ),
      ),
    );
  }
}
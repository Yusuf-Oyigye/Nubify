import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/post.dart';
import '../services/profile_activity_service.dart';

typedef ProfilePostOpenCallback = void Function(Post post, int index);

typedef ProfileCommentOpenCallback =
    void Function(ProfileCommentActivity activity, int index);

//===================================================
// NUBIFY REAL-CONTENT PROFILE GRID
//===================================================

class NubifyProfileGrid extends StatelessWidget {
  const NubifyProfileGrid({
    super.key,
    required this.posts,
    required this.title,
    required this.onOpen,
    this.pinnedPostIds = const <String>[],
  });

  final List<Post> posts;
  final String title;
  final ProfilePostOpenCallback onOpen;
  final List<String> pinnedPostIds;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: PageStorageKey<String>('profile-grid-$title'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _GridHeading(title: title, count: posts.length),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 0.76,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final Post post = posts[index];

              return _PostGridTile(
                key: ValueKey<String>('$title-${post.postId}'),
                post: post,
                pinned: pinnedPostIds.contains(post.postId),
                onTap: () => onOpen(post, index),
              );
            }, childCount: posts.length),
          ),
        ),
      ],
    );
  }
}

//===================================================
// COMMENTS GRID
//===================================================

class NubifyProfileCommentGrid extends StatelessWidget {
  const NubifyProfileCommentGrid({
    super.key,
    required this.activities,
    required this.onOpen,
  });

  final List<ProfileCommentActivity> activities;
  final ProfileCommentOpenCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('profile-comments'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _GridHeading(title: 'Comments', count: activities.length),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 0.76,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final activity = activities[index];

              return _CommentGridTile(
                key: ValueKey<String>(activity.activityId),
                activity: activity,
                onTap: () => onOpen(activity, index),
              );
            }, childCount: activities.length),
          ),
        ),
      ],
    );
  }
}

//===================================================
// REAL POST SOURCE LOOKUP
//===================================================

class _PostGridTile extends StatefulWidget {
  const _PostGridTile({
    super.key,
    required this.post,
    required this.pinned,
    required this.onTap,
  });

  final Post post;
  final bool pinned;
  final VoidCallback onTap;

  @override
  State<_PostGridTile> createState() => _PostGridTileState();
}

class _PostGridTileState extends State<_PostGridTile> {
  Future<Post?>? _sourceFuture;

  @override
  void initState() {
    super.initState();
    _prepareSource();
  }

  @override
  void didUpdateWidget(covariant _PostGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.postId != widget.post.postId ||
        oldWidget.post.sourcePostId != widget.post.sourcePostId ||
        oldWidget.post.rootPostId != widget.post.rootPostId) {
      _prepareSource();
    }
  }

  void _prepareSource() {
    _sourceFuture = widget.post.isRepost
        ? _loadReferencedPost(widget.post)
        : null;
  }

  Future<Post?> _loadReferencedPost(Post repost) async {
    //===================================================
    // PREFER ROOT ORIGINAL CONTENT
    //===================================================

    final List<String> candidates = <String>[
      repost.rootPostId,
      repost.sourcePostId,
    ];

    final Set<String> checked = <String>{};

    for (final String id in candidates) {
      final String postId = id.trim();

      if (postId.isEmpty || postId == repost.postId || !checked.add(postId)) {
        continue;
      }

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get();

        if (!snapshot.exists || snapshot.data() == null) {
          continue;
        }

        final Post source = Post.fromFirestore(snapshot);

        if (!source.isPubliclyVisible) {
          return null;
        }

        if (!source.isRepost) {
          return source;
        }

        // An older repost can contain its own media.
        if (source.media.isNotEmpty ||
            source.hasPoll ||
            source.thumbnailUrl.isNotEmpty) {
          return source;
        }
      } catch (error) {
        debugPrint('Profile source preview: $error');
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.post.isRepost) {
      return _ContentTile(
        post: widget.post,
        pinned: widget.pinned,
        onTap: widget.onTap,
      );
    }

    return FutureBuilder<Post?>(
      future: _sourceFuture,
      builder: (context, snapshot) {
        final bool waiting =
            snapshot.connectionState == ConnectionState.waiting;

        final Post? source = snapshot.data;

        return _ContentTile(
          post: source,
          outerPost: widget.post,
          pinned: widget.pinned,
          unavailable: !waiting && source == null,
          onTap: widget.onTap,
        );
      },
    );
  }
}

//===================================================
// COMMENTS: LOAD UNDERLYING POST
//===================================================

class _CommentGridTile extends StatefulWidget {
  const _CommentGridTile({
    super.key,
    required this.activity,
    required this.onTap,
  });

  final ProfileCommentActivity activity;
  final VoidCallback onTap;

  @override
  State<_CommentGridTile> createState() => _CommentGridTileState();
}

class _CommentGridTileState extends State<_CommentGridTile> {
  late Future<Post?> _postFuture;

  @override
  void initState() {
    super.initState();
    _postFuture = _loadPost();
  }

  @override
  void didUpdateWidget(covariant _CommentGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.activity.postId != widget.activity.postId) {
      _postFuture = _loadPost();
    }
  }
  //===================================================
  // LOAD POST CONTENT FOR COMMENT THUMBNAIL
  //===================================================

  Future<Post?> _loadPost() async {
    final String postId = widget.activity.postId.trim();

    if (postId.isEmpty) {
      return null;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      final snapshot = await firestore.collection('posts').doc(postId).get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final Post post = Post.fromFirestore(snapshot);

      if (!post.isPubliclyVisible) {
        return null;
      }

      //===================================================
      // NORMAL POST: DISPLAY ITS CONTENT
      //===================================================

      if (!post.isRepost) {
        return post;
      }

      //===================================================
      // REPOST: LOOK UP ORIGINAL CONTENT
      //===================================================

      final List<String> candidates = <String>[
        post.rootPostId,
        post.sourcePostId,
      ];

      final Set<String> checked = <String>{};

      for (final String candidate in candidates) {
        final String sourceId = candidate.trim();

        if (sourceId.isEmpty ||
            sourceId == post.postId ||
            !checked.add(sourceId)) {
          continue;
        }

        final sourceSnapshot = await firestore
            .collection('posts')
            .doc(sourceId)
            .get();

        if (!sourceSnapshot.exists || sourceSnapshot.data() == null) {
          continue;
        }

        final Post source = Post.fromFirestore(sourceSnapshot);

        if (!source.isPubliclyVisible) {
          return null;
        }

        if (!source.isRepost || source.media.isNotEmpty || source.hasPoll) {
          return source;
        }
      }

      // The original could not be resolved.
      // Only the repost's own information is available.
      return post;
    } catch (error) {
      debugPrint('Comment grid post loading failed: $error');

      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Post?>(
      future: _postFuture,
      builder: (context, snapshot) {
        final Post? post = snapshot.data;

        return _ContentTile(
          post: post,
          comment: true,
          fallbackText: widget.activity.text,
          unavailable:
              snapshot.connectionState != ConnectionState.waiting &&
              post == null,
          onTap: widget.onTap,
        );
      },
    );
  }
}

//===================================================
// MEDIA HELPERS
//===================================================

String nubifyPostCover(Post post) {
  final String cover = post.thumbnailUrl.trim();

  if (cover.isNotEmpty) return cover;

  final List<PostMedia> media = <PostMedia>[...post.media]
    ..sort((a, b) => a.order.compareTo(b.order));

  for (final PostMedia item in media) {
    if (item.isImage && item.url.trim().isNotEmpty) {
      return item.url.trim();
    }

    if (item.isVideo && item.thumbnailUrl.trim().isNotEmpty) {
      return item.thumbnailUrl.trim();
    }
  }

  return '';
}

String _realPostText(Post post) {
  final String caption = post.caption.trim();

  if (post.hasPoll && post.poll != null) {
    final String question = (post.poll!['question'] ?? '').toString().trim();

    final List<dynamic> options = post.poll!['options'] is List
        ? post.poll!['options'] as List<dynamic>
        : <dynamic>[];

    final String optionText = options
        .whereType<Map>()
        .take(3)
        .map((option) => (option['text'] ?? '').toString())
        .where((text) => text.trim().isNotEmpty)
        .join('\n');

    return <String>[
      if (caption.isNotEmpty) caption,
      if (question.isNotEmpty) question,
      if (optionText.isNotEmpty) optionText,
    ].join('\n\n');
  }

  if (caption.isNotEmpty) return caption;

  if (post.repostText.trim().isNotEmpty) {
    return post.repostText.trim();
  }

  if (post.originalCaption.trim().isNotEmpty) {
    return post.originalCaption.trim();
  }

  return '';
}

PostMedia? _legacyVideo(Post post) {
  final List<PostMedia> sorted = <PostMedia>[...post.media]
    ..sort((a, b) => a.order.compareTo(b.order));

  for (final PostMedia media in sorted) {
    if (media.isVideo && media.url.trim().isNotEmpty) {
      return media;
    }
  }

  return null;
}

//===================================================
// VIDEO COVER GENERATION FOR OLD POSTS
//===================================================

class _LegacyVideoCover extends StatelessWidget {
  const _LegacyVideoCover({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  static final Map<String, Future<Uint8List?>> _cache =
      <String, Future<Uint8List?>>{};

  static Future<Uint8List?> _thumbnail(String url) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 360,
        quality: 65,
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Limit temporary memory usage for long profile grids.
    if (_cache.length >= 60 && !_cache.containsKey(url)) {
      _cache.clear();
    }

    final Future<Uint8List?> future = _cache.putIfAbsent(
      url,
      () => _thumbnail(url),
    );

    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final Uint8List? bytes = snapshot.data;

        if (bytes == null || bytes.isEmpty) {
          return fallback;
        }

        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
//===================================================
// LOCATE THE STORAGE PATH OF A POST COVER
//===================================================

String _coverStoragePath(Post post, String coverUrl) {
  for (final PostMedia media in post.media) {
    if (media.isImage &&
        media.url.trim() == coverUrl.trim() &&
        media.storagePath.trim().isNotEmpty) {
      return media.storagePath.trim();
    }
  }

  return '';
}

//===================================================
// RECOVER POST IMAGE WHEN SAVED URL FAILS
//===================================================

class _RecoveringPostImage extends StatefulWidget {
  const _RecoveringPostImage({
    required this.imageUrl,
    required this.storagePath,
    required this.videoUrl,
    required this.fallback,
  });

  final String imageUrl;
  final String storagePath;
  final String videoUrl;
  final Widget fallback;

  @override
  State<_RecoveringPostImage> createState() => _RecoveringPostImageState();
}

class _RecoveringPostImageState extends State<_RecoveringPostImage> {
  Future<String?>? _recoveryFuture;

  @override
  void didUpdateWidget(covariant _RecoveringPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.storagePath != widget.storagePath) {
      _recoveryFuture = null;
    }
  }

  //===================================================
  // REQUEST FRESH FIREBASE STORAGE URL
  //===================================================

  Future<String?> _recoverUrl() async {
    if (widget.storagePath.trim().isEmpty) {
      return null;
    }

    try {
      return await FirebaseStorage.instance
          .ref()
          .child(widget.storagePath.trim())
          .getDownloadURL();
    } catch (error) {
      debugPrint(
        'Profile grid image recovery failed: '
        '${error.runtimeType}',
      );

      return null;
    }
  }

  //===================================================
  // RECOVER VIDEO FRAME OR SHOW CONTENT FALLBACK
  //===================================================

  Widget _mediaFallback() {
    if (widget.videoUrl.trim().isNotEmpty) {
      return _LegacyVideoCover(url: widget.videoUrl, fallback: widget.fallback);
    }

    return widget.fallback;
  }

  //===================================================
  // BUILD IMAGE
  //===================================================

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.trim().isEmpty) {
      return _mediaFallback();
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl.trim(),
      fit: BoxFit.cover,
      placeholder: (_, __) => widget.fallback,
      errorWidget: (_, __, error) {
        debugPrint(
          'Profile grid cover failed to load: '
          '${error.runtimeType}',
        );

        if (widget.storagePath.trim().isEmpty) {
          return _mediaFallback();
        }

        return FutureBuilder<String?>(
          future: _recoveryFuture ??= _recoverUrl(),
          builder: (context, snapshot) {
            final String freshUrl = snapshot.data?.trim() ?? '';

            if (freshUrl.isEmpty || freshUrl == widget.imageUrl.trim()) {
              return _mediaFallback();
            }

            return CachedNetworkImage(
              imageUrl: freshUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => widget.fallback,
              errorWidget: (_, __, ___) => _mediaFallback(),
            );
          },
        );
      },
    );
  }
}
//===================================================
// RICH CONTENT TILE
//===================================================

class _ContentTile extends StatelessWidget {
  const _ContentTile({
    required this.onTap,
    this.post,
    this.outerPost,
    this.pinned = false,
    this.comment = false,
    this.unavailable = false,
    this.fallbackText = '',
  });

  final Post? post;
  final Post? outerPost;
  final bool pinned;
  final bool comment;
  final bool unavailable;
  final String fallbackText;
  final VoidCallback onTap;

  String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final Post? content = post;
    final Post? wrapper = outerPost;

    final String text = unavailable
        ? 'Post unavailable'
        : content != null
        ? _realPostText(content)
        : fallbackText.trim().isNotEmpty
        ? fallbackText.trim()
        : wrapper?.originalCaption.trim().isNotEmpty == true
        ? wrapper!.originalCaption.trim()
        : 'Loading post...';

    final String cover = content == null ? '' : nubifyPostCover(content);

    final PostMedia? video = content == null ? null : _legacyVideo(content);

    final bool isVideo =
        content != null &&
        (content.isNUBuzz || content.media.any((media) => media.isVideo));

    final bool repost = wrapper?.isRepost == true || content?.isRepost == true;

    final bool isPoll = content?.hasPoll == true || content?.poll != null;

    final bool multiple = (content?.media.length ?? 0) > 1;

    final int count = isVideo
        ? (content?.viewCount ?? 0)
        : (content?.likeCount ?? 0);

    final Widget fallback = _RealTextCover(
      text: text.isNotEmpty
          ? text
          : unavailable
          ? 'Post unavailable'
          : 'Content unavailable',
      isPoll: isPoll,
      poll: content?.poll,
    );

    return Material(
      color: const Color(0xFF102438),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            //===================================================
            // DISPLAY REAL PHOTO OR VIDEO COVER
            //===================================================

            if (!isPoll &&
                content != null &&
                (cover.isNotEmpty || video != null))
              _RecoveringPostImage(
                imageUrl: cover,
                storagePath: _coverStoragePath(content, cover),
                videoUrl: video?.url ?? '',
                fallback: fallback,
              )
            else
              fallback,

            //===================================================
            // BOTTOM CONTRAST GRADIENT
            //===================================================
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0xB9000000)],
                ),
              ),
            ),
            //===================================================
            // QUOTE REPOST TEXT OVER ORIGINAL CONTENT
            //===================================================

            if (wrapper?.isQuoteRepost == true &&
                wrapper!.repostText.trim().isNotEmpty)
              Positioned(
                left: 5,
                right: 5,
                bottom: 29,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    wrapper.repostText.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            //===================================================
            // TYPE MARKER
            //===================================================

            Positioned(
              top: 7,
              right: 7,
              child: Icon(
                comment
                    ? Icons.mode_comment_outlined
                    : multiple
                    ? Icons.layers_rounded
                    : isVideo
                    ? Icons.play_arrow_rounded
                    : repost
                    ? Icons.repeat_rounded
                    : isPoll
                    ? Icons.poll_outlined
                    : Icons.image_outlined,
                size: 19,
                color: Colors.white,
                shadows: const <Shadow>[
                  Shadow(blurRadius: 5, color: Colors.black54),
                ],
              ),
            ),

            //===================================================
            // PINNED POST
            //===================================================
            if (pinned)
              const Positioned(
                top: 7,
                left: 7,
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 17,
                  color: Color(0xFF29B6F6),
                ),
              ),

            //===================================================
            // REPOST OR COMMENT INDICATOR
            //===================================================
            if (repost || comment)
              Positioned(
                top: 30,
                right: 5,
                child: Text(
                  comment ? 'COMMENT' : 'REPOST',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    shadows: <Shadow>[
                      Shadow(blurRadius: 5, color: Colors.black87),
                    ],
                  ),
                ),
              ),

            //===================================================
            // VIEW / LIKE COUNT
            //===================================================
            if (!comment && content != null)
              Positioned(
                left: 7,
                bottom: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isVideo
                          ? Icons.play_arrow_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _compact(count),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// ACTUAL TEXT AND POLL POST COVER
//===================================================

class _RealTextCover extends StatelessWidget {
  const _RealTextCover({required this.text, this.isPoll = false, this.poll});

  final String text;
  final bool isPoll;
  final Map<String, dynamic>? poll;

  //===================================================
  // POLL OPTIONS
  //===================================================

  List<Map<String, dynamic>> _options() {
    final dynamic raw = poll?['options'];

    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  //===================================================
  // BUILD THE THUMBNAIL
  //===================================================

  @override
  Widget build(BuildContext context) {
    final String question = (poll?['question'] ?? '').toString().trim();

    final List<Map<String, dynamic>> options = _options();

    final bool showPoll = isPoll && (question.isNotEmpty || options.isNotEmpty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF16476C),
            Color(0xFF102F4D),
            Color(0xFF071521),
          ],
        ),
      ),
      child: showPoll
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.poll_rounded,
                  size: 18,
                  color: Color(0xFF29B6F6),
                ),
                const SizedBox(height: 5),

                //===================================
                // ACTUAL POLL QUESTION
                //===================================
                Flexible(
                  child: Text(
                    question.isNotEmpty ? question : text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                //===================================
                // ACTUAL POLL OPTIONS
                //===================================
                for (final Map<String, dynamic> option in options.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF29B6F6).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: const Color(
                            0xFF29B6F6,
                          ).withValues(alpha: 0.55),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        (option['text'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          //===================================
          // ACTUAL TEXT-ONLY POST
          //===================================
          : Center(
              child: Text(
                text.trim().isNotEmpty ? text.trim() : 'Content unavailable',
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
    );
  }
}
//===================================================
// GRID TITLE
//===================================================

class _GridHeading extends StatelessWidget {
  const _GridHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(width: 7),
          Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF29B6F6),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

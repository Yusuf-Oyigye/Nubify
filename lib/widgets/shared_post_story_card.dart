import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../utils/nubify_time.dart';
import 'post_media_carousel.dart';

//=================================
// SHARED POST STORY CARD
//=================================

class SharedPostStoryCard extends StatelessWidget {
  //=================================
  // SHARED POST STORY CARD
  //=================================

  const SharedPostStoryCard({
    super.key,
    required this.post,
    this.onOpenPost,
    this.onOpenProfile,
    this.maxWidth = 440,
    this.maxDepth = 6,
    this.showEngagement = true,
    this.showReferencedPost = true,
    this.storyVideoPlayback = false,
    this.forcePaused = false,
    this.onVideoProgress,
    this.onVideoBufferingChanged,
    this.onVideoCompleted,
    this.onContentReady,
  });

  final Post post;

  final ValueChanged<String>? onOpenPost;

  final ValueChanged<String>? onOpenProfile;

  final double maxWidth;

  final int maxDepth;

  //=================================
  // STORY DISPLAY CONTROL
  //=================================

  final bool showEngagement;

  final bool showReferencedPost;
  //============================
  // STORY VIDEO PLAYBACK
  //============================

  final bool storyVideoPlayback;

  final bool forcePaused;

  final ValueChanged<double>? onVideoProgress;

  final ValueChanged<bool>? onVideoBufferingChanged;

  final VoidCallback? onVideoCompleted;
  //============================
  // STORY CONTENT READY
  //============================

  final VoidCallback? onContentReady;

  static const Color _blue = Color(0xFF29B6F6);
  //============================
  // REPORT CONTENT READY
  //============================

  void _notifyContentReady() {
    if (onContentReady == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onContentReady?.call();
    });
  }
  //=============================
  // BUILD
  //=============================

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _buildPostLevel(context, post, depth: 0, isRoot: true),
    );
  }

  //=============================
  // POST LEVEL
  //=============================

  Widget _buildPostLevel(
    BuildContext context,
    Post current, {
    required int depth,
    required bool isRoot,
  }) {
    final bool compact = depth > 0;
    //============================
    // DOES THIS POST STILL NEED
    // ITS DIRECT PARENT TO LOAD?
    //============================

    final bool waitsForReferencedPost =
        showReferencedPost &&
        current.isRepost &&
        current.sourcePostId.trim().isNotEmpty &&
        current.sourcePostId.trim() != current.postId &&
        depth < maxDepth;
    //============================
    // SHOW OWN MEDIA
    //============================
    //
    // IF THIS IS A REPOST THAT STILL
    // HAS A DIRECT PARENT TO DISPLAY,
    // DON'T SHOW ITS COPIED MEDIA HERE.
    //
    // THE DIRECT PARENT CARD BELOW
    // WILL SHOW THE MEDIA ONCE.
    //============================

    final bool showOwnMedia =
        current.media.isNotEmpty && !waitsForReferencedPost;

    //============================
    // STATIC POST READY
    //
    // IF THERE IS NO MEDIA AND NO
    // PARENT LEFT TO LOAD, THE CARD
    // IS READY.
    //============================
    if (!showOwnMedia && !waitsForReferencedPost) {
      _notifyContentReady();
    }

    final String displayName = current.fullName.trim().isNotEmpty
        ? current.fullName.trim()
        : current.username.trim().isNotEmpty
        ? current.username.trim()
        : 'Nubify User';

    final String ownText = current.isQuoteRepost
        ? current.repostText.trim().isNotEmpty
              ? current.repostText.trim()
              : current.caption.trim()
        : current.caption.trim();

    final BorderRadius radius = BorderRadius.circular(isRoot ? 22 : 16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onOpenPost == null
            ? null
            : () {
                onOpenPost!(current.postId);
              },
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: radius,
            border: Border.all(color: Colors.white24),
            boxShadow: isRoot
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              //=============================
              // AUTHOR
              //=============================

              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 11 : 13,
                  compact ? 11 : 13,
                  compact ? 11 : 13,
                  8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    //=============================
                    // PROFILE AVATAR
                    //=============================

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpenProfile == null || current.uid.trim().isEmpty
                          ? null
                          : () {
                              onOpenProfile!(current.uid.trim());
                            },
                      child: CircleAvatar(
                        radius: compact ? 18 : 21,
                        backgroundImage: current.photoUrl.trim().isNotEmpty
                            ? NetworkImage(current.photoUrl)
                            : null,
                        child: current.photoUrl.trim().isEmpty
                            ? Icon(Icons.person, size: compact ? 18 : 21)
                            : null,
                      ),
                    ),

                    const SizedBox(width: 9),
                    //=============================
                    // PROFILE NAME / USERNAME
                    //
                    // ONLY FULL NAME + USERNAME OPEN PROFILE.
                    //
                    // TIME + EMPTY SPACE + EVERY OTHER PART
                    // CONTINUE TO OPEN THE POST / REPOST.
                    //=============================

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          //=============================
                          // FULL NAME -> PROFILE
                          //=============================

                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap:
                                  onOpenProfile == null ||
                                      current.uid.trim().isEmpty
                                  ? null
                                  : () {
                                      onOpenProfile!(current.uid.trim());
                                    },
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: compact ? 14 : 15,
                                ),
                              ),
                            ),
                          ),

                          //=============================
                          // USERNAME + TIME
                          //=============================
                          Row(
                            children: <Widget>[
                              //=============================
                              // USERNAME -> PROFILE
                              //=============================

                              if (current.username.trim().isNotEmpty)
                                Flexible(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap:
                                        onOpenProfile == null ||
                                            current.uid.trim().isEmpty
                                        ? null
                                        : () {
                                            onOpenProfile!(current.uid.trim());
                                          },
                                    child: Text(
                                      '@${current.username.trim()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: compact ? 11 : 12,
                                      ),
                                    ),
                                  ),
                                ),

                              //=============================
                              // TIME SEPARATOR
                              //
                              // NOT PROFILE CLICKABLE.
                              //=============================
                              if (current.username.trim().isNotEmpty &&
                                  current.createdAt != null)
                                Text(
                                  ' · ',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),

                              //=============================
                              // TIME
                              //
                              // NOT PROFILE CLICKABLE.
                              // OUTER POST CARD HANDLES THE TAP.
                              //=============================
                              if (current.createdAt != null)
                                Flexible(
                                  child: NubifyTimeText.fromTimestamp(
                                    timestamp: current.createdAt,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: compact ? 10.5 : 11.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (current.isNUBuzz)
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: _blue,
                        size: 26,
                      ),
                  ],
                ),
              ),
              //=============================
              // REPOST LABEL
              //=============================

              if (current.isRepost)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 11 : 13,
                    0,
                    compact ? 11 : 13,
                    8,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.repeat_rounded, size: 17, color: _blue),

                      const SizedBox(width: 5),

                      Text(
                        current.isQuoteRepost ? 'Quote repost' : 'Reposted',
                        style: const TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              //=============================
              // CAPTION / QUOTE
              //=============================
              if (ownText.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 11 : 13,
                    0,
                    compact ? 11 : 13,
                    11,
                  ),
                  child: Text(
                    ownText,
                    style: TextStyle(
                      fontSize: compact ? 14 : 15.5,
                      height: 1.35,
                      fontWeight: current.isQuoteRepost
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),

              //=============================
              // POLL
              //=============================
              if (current.hasPoll && current.poll != null)
                _buildPoll(context, current.poll!, compact: compact),

              //=============================
              // MEDIA
              //=============================
              if (showOwnMedia)
                SizedBox(
                  width: double.infinity,
                  height: current.isNUBuzz
                      ? compact
                            ? 260
                            : 340
                      : compact
                      ? 220
                      : 290,
                  child: PostMediaCarousel(
                    media: current.media,

                    storyPlayback: storyVideoPlayback,

                    forcePaused: forcePaused,

                    onVideoProgress: onVideoProgress,

                    onVideoBufferingChanged: onVideoBufferingChanged,

                    onVideoCompleted: onVideoCompleted,

                    onContentReady: onContentReady,
                  ),
                ),

              //=============================
              // DIRECT REFERENCED REPOST
              //=============================
              //
              // STORY SHOWS ONLY THE POST THIS USER
              // DIRECTLY REPOSTED.
              //
              // DO NOT EXPAND THE FULL A -> B -> C -> D CHAIN.
              //=============================
              if (showReferencedPost &&
                  current.isRepost &&
                  current.sourcePostId.trim().isNotEmpty &&
                  current.sourcePostId.trim() != current.postId &&
                  depth < maxDepth)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 9 : 12,
                    0,
                    compact ? 9 : 12,
                    10,
                  ),
                  child: _ReferencedStoryPost(
                    storyVideoPlayback: storyVideoPlayback,

                    forcePaused: forcePaused,

                    onContentReady: onContentReady,

                    onVideoProgress: onVideoProgress,

                    onVideoBufferingChanged: onVideoBufferingChanged,

                    onVideoCompleted: onVideoCompleted,
                    postId: current.sourcePostId.trim(),
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    onOpenPost: onOpenPost,
                    onOpenProfile: onOpenProfile,
                  ),
                ),

              //=============================
              // FOUR ENGAGEMENT ICONS
              //=============================
              //
              // ONLY THE MAIN SHARED POST / REPOST
              // GETS THE ENGAGEMENT ROW.
              //
              // THE DIRECT PARENT PREVIEW STAYS SIMPLE.
              //=============================
              if (showEngagement)
                _buildEngagementRow(current, compact: compact),
            ],
          ),
        ),
      ),
    );
  }

  //=============================
  // POLL
  //=============================

  Widget _buildPoll(
    BuildContext context,
    Map<String, dynamic> poll, {
    required bool compact,
  }) {
    final String question = (poll['question'] ?? '').toString().trim();

    final List<dynamic> rawOptions = poll['options'] is List
        ? List<dynamic>.from(poll['options'] as List)
        : <dynamic>[];

    final List<Map<String, dynamic>> options = rawOptions
        .whereType<Map>()
        .map((Map option) => Map<String, dynamic>.from(option))
        .toList();

    int totalVotes = _toInt(poll['totalVotes']);

    if (totalVotes <= 0) {
      totalVotes = options.fold<int>(
        0,
        (int total, Map<String, dynamic> option) =>
            total + _toInt(option['votes']),
      );
    }

    final bool pollClosed = _isPollClosed(poll);

    final int? selectedIndex = _selectedPollOptionIndex(poll);

    final int? winnerIndex = pollClosed
        ? _winnerOptionIndex(poll, options)
        : null;

    if (question.isEmpty && rawOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 12, 0, compact ? 10 : 12, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (question.isNotEmpty)
              Text(
                question,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 13.5 : 14.5,
                ),
              ),

            if (question.isNotEmpty && rawOptions.isNotEmpty)
              const SizedBox(height: 9),

            ...options.asMap().entries.map((
              MapEntry<int, Map<String, dynamic>> entry,
            ) {
              final int index = entry.key;

              final Map<String, dynamic> option = entry.value;

              final String text = (option['text'] ?? '').toString().trim();

              final int votes = _toInt(option['votes']);

              final double progress = totalVotes <= 0
                  ? 0
                  : (votes / totalVotes).clamp(0.0, 1.0).toDouble();

              final bool selected = selectedIndex == index;

              final bool winner = winnerIndex == index;

              final bool highlighted = pollClosed ? winner : selected;

              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Container(
                  height: compact ? 40 : 44,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: highlighted
                          ? _blue
                          : Colors.grey.withValues(alpha: 0.30),
                      width: highlighted ? 1.5 : 1,
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      if (pollClosed)
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: ColoredBox(
                            color: _blue.withValues(
                              alpha: winner ? 0.88 : 0.58,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: <Widget>[
                            if (selected && !pollClosed)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.check_circle,
                                  color: _blue,
                                  size: 16,
                                ),
                              ),
                            if (winner)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 12.5 : 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (pollClosed)
                              Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 11.5,
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
            }),

            Text(
              '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  //=============================
  // ENGAGEMENT ROW
  //=============================

  Widget _buildEngagementRow(Post current, {required bool compact}) {
    final double gap = compact ? 14 : 18;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 13,
        9,
        compact ? 10 : 13,
        compact ? 10 : 13,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          //=============================
          // LIKE
          //=============================

          _metric(
            Icons.favorite_border_rounded,
            current.likeCount,
            compact: compact,
          ),

          SizedBox(width: gap),

          //=============================
          // COMMENT
          //=============================
          _metric(
            Icons.chat_bubble_outline_rounded,
            current.commentCount,
            compact: compact,
          ),

          SizedBox(width: gap),

          //=============================
          // REPOST
          //=============================
          _metric(Icons.repeat_rounded, current.repostCount, compact: compact),

          SizedBox(width: gap),

          //=============================
          // SHARE
          //=============================
          _metric(Icons.near_me_outlined, current.shareCount, compact: compact),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, int count, {required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: compact ? 16 : 18),

        const SizedBox(width: 4),

        Text('$count', style: TextStyle(fontSize: compact ? 11.5 : 12.5)),
      ],
    );
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _dateFromDynamic(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  bool _isPollClosed(Map<String, dynamic> poll) {
    if (poll['isClosed'] == true) {
      return true;
    }

    DateTime? expiresAt = _dateFromDynamic(poll['expiresAt']);

    expiresAt ??= _dateFromDynamic(
      poll['createdAt'],
    )?.add(const Duration(hours: 24));

    return expiresAt != null && !DateTime.now().isBefore(expiresAt);
  }

  int? _selectedPollOptionIndex(Map<String, dynamic> poll) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return null;
    }

    final List<dynamic> voters = poll['votedUserIds'] is List
        ? List<dynamic>.from(poll['votedUserIds'] as List)
        : <dynamic>[];

    for (final dynamic voter in voters) {
      if (voter is Map && (voter['uid'] ?? '').toString() == uid) {
        return _nullableInt(voter['optionIndex']);
      }
    }

    return null;
  }

  int? _winnerOptionIndex(
    Map<String, dynamic> poll,
    List<Map<String, dynamic>> options,
  ) {
    if (options.isEmpty) {
      return null;
    }

    int highestVotes = 0;
    final List<int> winners = <int>[];

    for (int index = 0; index < options.length; index++) {
      final int votes = _toInt(options[index]['votes']);

      if (votes > highestVotes) {
        highestVotes = votes;
        winners
          ..clear()
          ..add(index);
      } else if (votes == highestVotes && votes > 0) {
        winners.add(index);
      }
    }

    if (highestVotes <= 0 || winners.length != 1) {
      return null;
    }

    final int? storedWinner = _nullableInt(poll['winnerOptionIndex']);

    return storedWinner != null && winners.contains(storedWinner)
        ? storedWinner
        : winners.first;
  }

  int? _nullableInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}

//=================================
// REFERENCED STORY POST
//=================================
class _ReferencedStoryPost extends StatelessWidget {
  const _ReferencedStoryPost({
    required this.storyVideoPlayback,
    required this.forcePaused,
    required this.onContentReady,
    required this.onVideoProgress,
    required this.onVideoBufferingChanged,
    required this.onVideoCompleted,
    required this.postId,
    required this.depth,
    required this.maxDepth,
    required this.onOpenPost,
    required this.onOpenProfile,
  });
  final bool storyVideoPlayback;

  final bool forcePaused;
  final VoidCallback? onContentReady;

  final ValueChanged<double>? onVideoProgress;

  final ValueChanged<bool>? onVideoBufferingChanged;

  final VoidCallback? onVideoCompleted;

  final String postId;

  final int depth;

  final int maxDepth;

  final ValueChanged<String>? onOpenPost;

  final ValueChanged<String>? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF29B6F6),
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.data!.exists || snapshot.data!.data() == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onContentReady?.call();
              });
              return _unavailable('Referenced post is unavailable.');
            }

            final Map<String, dynamic> data = snapshot.data!.data()!;

            if (data['isHidden'] == true || data['isRootHidden'] == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onContentReady?.call();
              });
              return _unavailable('Referenced post is hidden.');
            }

            try {
              final Post post = Post.fromFirestore(snapshot.data!);
              //=================================
              // DIRECT PARENT ONLY
              //=================================
              //
              // SHOW THIS DIRECT PARENT POST,
              // BUT DO NOT LOAD ITS OWN PARENT.
              //
              // ALSO DO NOT SHOW ANOTHER ENGAGEMENT
              // ROW INSIDE THE EMBEDDED POST.
              //=================================

              return SharedPostStoryCard(
                storyVideoPlayback: storyVideoPlayback,

                forcePaused: forcePaused,

                onContentReady: onContentReady,

                onVideoProgress: onVideoProgress,

                onVideoBufferingChanged: onVideoBufferingChanged,

                onVideoCompleted: onVideoCompleted,
                post: post,

                onOpenPost: onOpenPost,

                onOpenProfile: onOpenProfile,

                maxWidth: double.infinity,

                maxDepth: 0,

                showReferencedPost: false,

                showEngagement: false,
              );
            } catch (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onContentReady?.call();
              });
              return _unavailable('Unable to display referenced post.');
            }
          },
    );
  }

  Widget _unavailable(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

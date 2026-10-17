import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/story.dart';
import '../services/notification_service.dart';
import '../services/story_service.dart';
import '../utils/nubify_time.dart';

import 'comment_screen.dart';
import 'story_viewer_screen.dart';

//===================================================
// NOTIFICATIONS SCREEN
//===================================================

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

//===================================================
// NOTIFICATIONS STATE
//===================================================

class _NotificationsScreenState extends State<NotificationsScreen> {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //===================================================
  // SERVICES
  //===================================================

  final NotificationService _notificationService = NotificationService();

  final StoryService _storyService = StoryService();

  //===================================================
  // STABLE STREAM
  //===================================================

  late Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream;

  //===================================================
  // COLORS
  //===================================================

  static const Color _blue = Color(0xFF29B6F6);

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _notificationsStream = _notificationService.getNotifications();
  }

  //===================================================
  // REFRESH
  //===================================================

  void _refresh() {
    setState(() {
      _notificationsStream = _notificationService.getNotifications();
    });
  }

  //===================================================
  // SORT NEWEST FIRST
  //===================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);

    documents.sort((
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
    ) {
      final DateTime aDate =
          _notificationDate(a.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final DateTime bDate =
          _notificationDate(b.data()['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return documents;
  }

  //===================================================
  // DATE
  //===================================================

  DateTime? _notificationDate(dynamic value) {
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

  //===================================================
  // MARK ALL
  //===================================================

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
    } catch (error) {
      _showMessage('Unable to mark notifications as read.');
    }
  }

  //===================================================
  // CLEAR ALL
  //===================================================

  Future<void> _clearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear Notifications?'),

          content: const Text('All your notifications will be removed.'),

          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _notificationService.deleteAllNotifications();

      if (mounted) {
        _showMessage('Notifications cleared.');
      }
    } catch (_) {
      _showMessage('Unable to clear notifications.');
    }
  }

  //===================================================
  // OPEN SENDER PROFILE
  //===================================================

  Future<void> _openProfile(String senderId) async {
    final String uid = senderId.trim();

    if (uid.isEmpty || !mounted) {
      return;
    }

    await Navigator.of(context).pushNamed('/profile', arguments: uid);
  }

  //===================================================
  // OPEN NOTIFICATION
  //===================================================

  Future<void> _openNotification({
    required String notificationId,
    required Map<String, dynamic> data,
  }) async {
    //===================================================
    // MARK READ FIRST
    //===================================================

    try {
      await _notificationService.markAsRead(notificationId);
    } catch (_) {}

    if (!mounted) {
      return;
    }

    final String type = (data['type'] ?? '').toString().trim();

    final String senderId = (data['senderId'] ?? data['senderUid'] ?? '')
        .toString()
        .trim();

    final String postId = (data['postId'] ?? '').toString().trim();

    final String repostPostId = (data['repostPostId'] ?? '').toString().trim();

    final String storyId = (data['storyId'] ?? '').toString().trim();

    if (type.startsWith('sellerVerification')) {
      await Navigator.pushNamed<void>(context, '/marketplace/verification');
      return;
    }

    //===================================================
    // STORY
    //===================================================

    if (type == 'storyTag' ||
        type == 'storyLike' ||
        type == 'storyReply' ||
        type == 'storyReshare') {
      await _openStory(storyId);

      return;
    }

    //===================================================
    // FOLLOW
    //===================================================

    if (type == 'follow') {
      await _openProfile(senderId);

      return;
    }

    //===================================================
    // REPOST / QUOTE REPOST
    //
    // Prefer actual wrapper post so the user sees:
    //
    // - reposter profile
    // - repost label
    // - quote text
    // - embedded root original
    //===================================================

    if (type == 'repost' || type == 'quoteRepost') {
      final String targetPostId = repostPostId.isNotEmpty
          ? repostPostId
          : postId;

      await _openPost(targetPostId);

      return;
    }

    //===================================================
    // POST LIKE / COMMENT / REPLY / TAG
    //
    // CommentsScreen already displays the complete post
    // at the top, followed by comments.
    //===================================================

    if (type == 'like' ||
        type == 'comment' ||
        type == 'reply' ||
        type == 'tag') {
      await _openPost(postId);

      return;
    }

    //===================================================
    // FALLBACK
    //===================================================

    if (postId.isNotEmpty) {
      await _openPost(postId);

      return;
    }

    if (storyId.isNotEmpty) {
      await _openStory(storyId);

      return;
    }

    if (senderId.isNotEmpty) {
      await _openProfile(senderId);
    }
  }

  //===================================================
  // OPEN POST / REPOST
  //===================================================

  Future<void> _openPost(String postId) async {
    final String cleanPostId = postId.trim();

    if (cleanPostId.isEmpty) {
      _showMessage('This post is unavailable.');

      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('posts')
          .doc(cleanPostId)
          .get();

      if (!mounted) {
        return;
      }

      if (!snapshot.exists || snapshot.data() == null) {
        _showMessage('This post was removed.');

        return;
      }

      final Map<String, dynamic> data = snapshot.data()!;

      //===================================================
      // HIDDEN POST
      //===================================================

      if (data['isHidden'] == true || data['isRootHidden'] == true) {
        _showMessage('This post is currently hidden.');

        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CommentsScreen(postId: cleanPostId),
        ),
      );
    } catch (_) {
      _showMessage('Unable to open this post.');
    }
  }

  //===================================================
  // OPEN STORY
  //===================================================

  Future<void> _openStory(String storyId) async {
    final String cleanStoryId = storyId.trim();

    if (cleanStoryId.isEmpty) {
      _showMessage('This story is unavailable.');

      return;
    }

    try {
      final NubifyStory? story = await _storyService.getStory(cleanStoryId);

      if (!mounted) {
        return;
      }

      if (story == null) {
        _showMessage('This story has expired or was removed.');

        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => StoryViewerScreen(stories: <NubifyStory>[story]),
        ),
      );
    } catch (_) {
      _showMessage('Unable to open this story.');
    }
  }

  //===================================================
  // DELETE SINGLE NOTIFICATION
  //===================================================

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
    } catch (_) {
      _showMessage('Unable to remove notification.');
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) async {
              if (value == 'read') {
                await _markAllAsRead();
              }

              if (value == 'clear') {
                await _clearAll();
              }
            },

            itemBuilder: (BuildContext context) {
              return const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'read',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.done_all_rounded),
                      SizedBox(width: 10),
                      Text('Mark all as read'),
                    ],
                  ),
                ),

                PopupMenuItem<String>(
                  value: 'clear',
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 10),
                      Text('Clear notifications'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();

          await Future<void>.delayed(const Duration(milliseconds: 300));
        },

        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _notificationsStream,

          builder:
              (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
              ) {
                //===================================================
                // LOADING
                //===================================================

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _blue),
                  );
                }

                //===================================================
                // ERROR
                //===================================================

                if (snapshot.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: const _NotificationsEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Unable to load notifications',
                          subtitle: 'Pull down to try again.',
                        ),
                      ),
                    ],
                  );
                }

                final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                documents = snapshot.hasData
                    ? _sortedNotifications(snapshot.data!)
                    : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                //===================================================
                // EMPTY
                //===================================================

                if (documents.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.58,
                        child: const _NotificationsEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No notifications yet',
                          subtitle:
                              'Likes, comments, replies, reposts, follows and story activity will appear here.',
                        ),
                      ),
                    ],
                  );
                }

                //===================================================
                // LIST
                //===================================================

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),

                  itemCount: documents.length,

                  separatorBuilder: (BuildContext context, int index) {
                    return const Divider(height: 1);
                  },

                  itemBuilder: (BuildContext context, int index) {
                    final QueryDocumentSnapshot<Map<String, dynamic>> document =
                        documents[index];

                    return _NotificationTile(
                      key: ValueKey<String>(document.id),

                      notificationId: document.id,

                      data: document.data(),

                      onOpen: () {
                        _openNotification(
                          notificationId: document.id,

                          data: document.data(),
                        );
                      },

                      onDelete: () {
                        _deleteNotification(document.id);
                      },

                      onOpenProfile: (String uid) {
                        _openProfile(uid);
                      },
                    );
                  },
                );
              },
        ),
      ),
    );
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
}

//===================================================
// NOTIFICATION TILE
//===================================================

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.notificationId,
    required this.data,
    required this.onOpen,
    required this.onDelete,
    required this.onOpenProfile,
  });

  final String notificationId;

  final Map<String, dynamic> data;

  final VoidCallback onOpen;

  final VoidCallback onDelete;

  final ValueChanged<String> onOpenProfile;

  //===================================================
  // FIREBASE
  //===================================================

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //===================================================
  // BLUE
  //===================================================

  static const Color _blue = Color(0xFF29B6F6);

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final String senderId = (data['senderId'] ?? data['senderUid'] ?? '')
        .toString()
        .trim();

    final String type = (data['type'] ?? '').toString().trim();

    final String message = (data['message'] ?? '').toString().trim();

    final bool isRead = data['isRead'] == true;

    final Timestamp? createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : null;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: senderId.isEmpty
          ? null
          : _firestore.collection('users').doc(senderId).get(),

      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> userData =
                snapshot.data?.data() ?? <String, dynamic>{};

            final String username = (userData['username'] ?? '')
                .toString()
                .trim();

            final String fullName = (userData['fullName'] ?? '')
                .toString()
                .trim();

            final String photoUrl = (userData['photoUrl'] ?? '')
                .toString()
                .trim();

            final String displayName = fullName.isNotEmpty
                ? fullName
                : username.isNotEmpty
                ? username
                : 'Someone';

            return Dismissible(
              key: ValueKey<String>('notification_$notificationId'),

              direction: DismissDirection.endToStart,

              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: Colors.redAccent,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                ),
              ),

              onDismissed: (_) {
                onDelete();
              },

              child: Material(
                color: isRead ? Colors.transparent : _blue.withOpacity(0.07),

                child: InkWell(
                  onTap: onOpen,

                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,

                      children: <Widget>[
                        //===================================================
                        // AVATAR
                        //===================================================

                        GestureDetector(
                          behavior: HitTestBehavior.opaque,

                          onTap: senderId.isEmpty
                              ? null
                              : () {
                                  onOpenProfile(senderId);
                                },

                          child: Stack(
                            clipBehavior: Clip.none,

                            children: <Widget>[
                              CircleAvatar(
                                radius: 25,

                                backgroundColor: _blue.withOpacity(0.16),

                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,

                                child: photoUrl.isEmpty
                                    ? const Icon(Icons.person_rounded)
                                    : null,
                              ),

                              Positioned(
                                right: -4,
                                bottom: -3,
                                child: Container(
                                  width: 23,
                                  height: 23,
                                  decoration: const BoxDecoration(
                                    color: _blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconForType(type),
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 13),

                        //===================================================
                        // TEXT
                        //===================================================
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: <Widget>[
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(
                                    context,
                                  ).style.copyWith(fontSize: 14),

                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    if (message.isNotEmpty)
                                      TextSpan(
                                        text: ' $message',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.82),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              if (username.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 2),

                                Text(
                                  '@$username',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 4),

                              Text(
                                NubifyTime.formatTimestamp(createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        //===================================================
                        // UNREAD DOT
                        //===================================================
                        if (!isRead)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.circle, color: _blue, size: 9),
                          )
                        else
                          const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
    );
  }

  //===================================================
  // ICON FOR TYPE
  //===================================================

  static IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;

      case 'comment':
        return Icons.chat_bubble_rounded;

      case 'reply':
        return Icons.reply_rounded;

      case 'repost':
        return Icons.repeat_rounded;

      case 'quoteRepost':
        return Icons.format_quote_rounded;

      case 'tag':
        return Icons.alternate_email_rounded;

      case 'follow':
        return Icons.person_add_alt_1_rounded;

      case 'storyTag':
        return Icons.alternate_email_rounded;

      case 'storyLike':
        return Icons.favorite_rounded;

      case 'storyReply':
        return Icons.reply_rounded;

      case 'storyReshare':
        return Icons.ios_share_rounded;

      case 'sellerVerificationApproved':
        return Icons.verified_rounded;

      case 'sellerVerificationRejected':
        return Icons.info_outline_rounded;

      case 'sellerVerificationSuspended':
        return Icons.block_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }
}

//===================================================
// EMPTY STATE
//===================================================

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;

  final String title;

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: <Widget>[
            Icon(icon, size: 56, color: const Color(0xFF29B6F6)),

            const SizedBox(height: 12),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../resources/auth_method.dart';
import '../services/profile_activity_service.dart';
import '../services/profile_service.dart';
import '../widgets/post_card.dart';
import 'comment_screen.dart';
import 'conversation_screen.dart';
import 'edit_profile_screen.dart';
import 'hidden_posts_screen.dart';
import 'story_archive_screen.dart';
import '../widgets/report_user_dialog.dart';
import '../widgets/universal_link_text.dart';
import '../widgets/nubify_profile_grid.dart';
import '../widgets/profile_vertical_feed.dart';

//===================================================
// PROFILE SCREEN
//===================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId, this.uid});

  //===================================================
  // SUPPORT BOTH OLD + NEW CALLERS
  //===================================================

  final String? userId;

  final String? uid;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

//===================================================
// PROFILE STATE
//===================================================

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  //===================================================
  // SERVICES
  //===================================================

  final ProfileService _profileService = ProfileService();

  final ProfileActivityService _profileActivityService =
      ProfileActivityService();

  //===================================================
  // TAB
  //===================================================

  TabController? _tabController;

  //===================================================
  // STABLE STREAMS
  //
  // EACH PROFILE TAB HAS ITS OWN STREAM.
  //
  // WE DO NOT PASS ONE SINGLE-SUBSCRIPTION STREAM
  // INTO MULTIPLE StreamBuilders.
  //===================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _postsStream;

  Stream<int>? _likesReceivedStream;

  Stream<List<Post>>? _savedPostsStream;

  Stream<List<Post>>? _likedPostsStream;

  Stream<List<ProfileCommentActivity>>? _commentsStream;

  //===================================================
  // STATE
  //===================================================

  bool _followLoading = false;

  final bool _menuLoading = false;

  bool _isBlocked = false;

  bool _historyPrepared = false;

  bool _profileRepairStarted = false;

  Object? _profileRepairError;

  //===================================================
  // COLOR
  //===================================================

  static const Color _blue = Color(0xFF29B6F6);

  //===================================================
  // PROFILE UID
  //===================================================

  String get _profileUid {
    final String userId = widget.userId?.trim() ?? '';

    if (userId.isNotEmpty) {
      return userId;
    }

    final String uid = widget.uid?.trim() ?? '';

    if (uid.isNotEmpty) {
      return uid;
    }

    return _auth.currentUser?.uid ?? '';
  }

  //===================================================
  // OWNER
  //===================================================

  bool get _isOwner {
    final String currentUid = _auth.currentUser?.uid ?? '';

    return currentUid.isNotEmpty && currentUid == _profileUid;
  }

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _configureProfile();
  }

  //===================================================
  // DID UPDATE
  //===================================================

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId || oldWidget.uid != widget.uid) {
      _tabController?.dispose();

      _historyPrepared = false;

      _configureProfile();

      if (mounted) {
        setState(() {});
      }
    }
  }

  //===================================================
  // CONFIGURE
  //===================================================

  void _configureProfile() {
    final String uid = _profileUid;

    _tabController = TabController(length: _isOwner ? 5 : 2, vsync: this);

    if (uid.isEmpty) {
      _userStream = null;

      _postsStream = null;

      _likesReceivedStream = null;

      _savedPostsStream = null;

      _likedPostsStream = null;

      _commentsStream = null;

      return;
    }

    _userStream = _profileService.userStream(uid);

    _postsStream = _profileService.postsStream(uid);

    _likesReceivedStream = _profileService.likesReceivedStream(uid);

    if (_isOwner) {
      _repairMissingOwnerProfile();

      _savedPostsStream = _profileService.savedPostsStream(uid);

      _likedPostsStream = _profileActivityService.likedPostsStream(uid);

      _commentsStream = _profileActivityService.commentsStream(uid);

      _prepareHistory();
    } else {
      _savedPostsStream = null;

      _likedPostsStream = null;

      _commentsStream = null;
    }

    _loadBlockedState();
  }

  //===================================================
  // REPAIR PARTIAL SIGNUP
  //===================================================

  Future<void> _repairMissingOwnerProfile() async {
    if (!_isOwner || _profileRepairStarted) {
      return;
    }

    _profileRepairStarted = true;
    _profileRepairError = null;

    try {
      await AuthMethods().ensureCurrentUserProfile();
    } catch (error) {
      _profileRepairError = error;

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _retryProfileRepair() {
    setState(() {
      _profileRepairStarted = false;
      _profileRepairError = null;
    });

    _repairMissingOwnerProfile();
  }

  //===================================================
  // PREPARE OLD LIKES + COMMENTS
  //===================================================

  void _prepareHistory() {
    if (!_isOwner || _historyPrepared || _profileUid.isEmpty) {
      return;
    }

    _historyPrepared = true;

    Future<void>.microtask(() async {
      try {
        await _profileActivityService.prepareOwnerHistory(_profileUid);
      } catch (error) {
        debugPrint('Profile history prepare error: $error');
      }
    });
  }

  //===================================================
  // BLOCKED STATE
  //===================================================

  Future<void> _loadBlockedState() async {
    if (_isOwner || _profileUid.isEmpty) {
      if (mounted) {
        setState(() {
          _isBlocked = false;
        });
      }

      return;
    }

    try {
      final bool blocked = await _profileService.isBlocked(_profileUid);

      if (!mounted) {
        return;
      }

      setState(() {
        _isBlocked = blocked;
      });
    } catch (_) {}
  }

  //===================================================
  // GO BACK
  //===================================================

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();

      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
  }

  //===================================================
  // PROFILE PICTURE FULLSCREEN
  //===================================================

  Future<void> _showFullProfilePhoto({
    required String photoUrl,
    required String displayName,
  }) async {
    if (photoUrl.trim().isEmpty) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,

      barrierDismissible: true,

      barrierLabel: 'Profile picture',

      barrierColor: Colors.black.withValues(alpha: 0.96),

      transitionDuration: const Duration(milliseconds: 180),

      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return Material(
              color: Colors.transparent,

              child: SafeArea(
                child: Stack(
                  fit: StackFit.expand,

                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,

                      onTap: () {
                        Navigator.of(dialogContext).pop();
                      },

                      child: const SizedBox.expand(),
                    ),

                    Center(
                      child: InteractiveViewer(
                        minScale: 1,

                        maxScale: 5,

                        child: Image.network(
                          photoUrl,

                          width: double.infinity,

                          fit: BoxFit.contain,

                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const Icon(
                                  Icons.person_rounded,

                                  color: Colors.white54,

                                  size: 110,
                                );
                              },
                        ),
                      ),
                    ),

                    Positioned(
                      top: 5,

                      left: 8,

                      right: 8,

                      child: Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },

                            icon: const Icon(
                              Icons.close,

                              color: Colors.white,

                              size: 30,
                            ),
                          ),

                          const SizedBox(width: 5),

                          Expanded(
                            child: Text(
                              displayName,

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: const TextStyle(
                                color: Colors.white,

                                fontWeight: FontWeight.bold,

                                fontSize: 17,
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
  // FOLLOW
  //===================================================

  Future<void> _toggleFollow() async {
    if (_followLoading || _isOwner) {
      return;
    }

    setState(() {
      _followLoading = true;
    });

    try {
      final bool nowFollowing = await _profileService.toggleFollow(_profileUid);

      if (!mounted) {
        return;
      }

      _showMessage(nowFollowing ? 'Following.' : 'Unfollowed.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _followLoading = false;
        });
      }
    }
  }

  //===================================================
  // MESSAGE USER
  //===================================================

  Future<void> _openChat(Map<String, dynamic> data) async {
    if (_isOwner) {
      return;
    }

    final String fullName = (data['fullName'] ?? '').toString().trim();

    final String username = (data['username'] ?? '').toString().trim();

    final String photoUrl = (data['photoUrl'] ?? '').toString().trim();

    await Navigator.push(
      context,

      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          otherUserId: _profileUid,

          otherName: fullName.isNotEmpty ? fullName : username,

          otherUsername: username,

          otherPhotoUrl: photoUrl,
        ),
      ),
    );
  }

  //===================================================
  // EDIT PROFILE
  //===================================================

  Future<void> _openEditProfile() async {
    if (!_isOwner) {
      return;
    }

    await Navigator.push<bool>(
      context,

      MaterialPageRoute<bool>(builder: (_) => const EditProfileScreen()),
    );
  }

  //===================================================
  // PROFILE MENU
  //===================================================

  Future<void> _showProfileMenu(Map<String, dynamic> data) async {
    if (_menuLoading) {
      return;
    }

    final String username = (data['username'] ?? '').toString().trim();

    await showModalBottomSheet<void>(
      context: context,

      showDragHandle: true,

      builder: (BuildContext sheetContext) {
        Future<void> closeThen(Future<void> Function() action) async {
          Navigator.pop(sheetContext);

          await Future<void>.delayed(const Duration(milliseconds: 180));

          if (!mounted) {
            return;
          }

          await action();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: <Widget>[
              //===================================================
              // SHARE PROFILE
              //===================================================

              ListTile(
                leading: const Icon(Icons.share_outlined),

                title: const Text('Share Profile'),

                onTap: () {
                  closeThen(() => _shareProfile(username));
                },
              ),

              //===================================================
              // COPY PROFILE LINK
              //===================================================
              ListTile(
                leading: const Icon(Icons.link_rounded),

                title: const Text('Copy Profile Link'),

                onTap: () {
                  closeThen(_copyProfileLink);
                },
              ),
              //============================
              // OWNER STORY ARCHIVE
              //============================

              if (_isOwner)
                ListTile(
                  leading: const Icon(Icons.archive_outlined),

                  title: const Text('Story Archive'),

                  subtitle: const Text('View Stories you have shared'),

                  onTap: () {
                    Navigator.pop(sheetContext);

                    Navigator.push(
                      context,

                      MaterialPageRoute<void>(
                        builder: (_) => const StoryArchiveScreen(),
                      ),
                    );
                  },
                ),
              //===================================================
              // OWNER HIDDEN POSTS
              //===================================================

              if (_isOwner)
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),

                  title: const Text('Hidden Posts'),

                  subtitle: const Text('View and unhide posts you hid'),

                  onTap: () {
                    Navigator.pop(sheetContext);

                    Navigator.push(
                      context,

                      MaterialPageRoute<void>(
                        builder: (_) => HiddenPostsScreen(userId: _profileUid),
                      ),
                    );
                  },
                ),

              if (!_isOwner) ...<Widget>[
                const Divider(),

                ListTile(
                  leading: const Icon(Icons.flag_outlined),

                  title: const Text('Report User'),

                  onTap: () {
                    closeThen(_reportUser);
                  },
                ),

                ListTile(
                  leading: Icon(
                    _isBlocked ? Icons.lock_open_rounded : Icons.block_outlined,

                    color: _isBlocked ? _blue : Colors.redAccent,
                  ),

                  title: Text(
                    _isBlocked ? 'Unblock User' : 'Block User',

                    style: TextStyle(
                      color: _isBlocked ? null : Colors.redAccent,
                    ),
                  ),

                  onTap: () {
                    closeThen(_toggleBlock);
                  },
                ),
              ],

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // SHARE PROFILE
  //===================================================

  Future<void> _shareProfile(String username) async {
    final String link = 'https://nubify.app/profile/$_profileUid';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: username.isEmpty
              ? link
              : 'Check out @$username on Nubify\n$link',
        ),
      );
    } catch (_) {
      _showMessage('Unable to share profile.');
    }
  }

  //===================================================
  // COPY PROFILE
  //===================================================

  Future<void> _copyProfileLink() async {
    final String link = 'https://nubify.app/profile/$_profileUid';

    await Clipboard.setData(ClipboardData(text: link));

    _showMessage('Profile link copied.');
  }

  //===================================================
  // REPORT USER
  //===================================================

  Future<void> _reportUser() async {
    if (_isOwner) {
      return;
    }

    try {
      await showReportUserDialog(context: context, targetUid: _profileUid);
    } catch (_) {
      _showMessage('Unable to report this user.');
    }
  }

  //===================================================
  // BLOCK / UNBLOCK
  //===================================================

  Future<void> _toggleBlock() async {
    if (_isOwner) {
      return;
    }

    if (_isBlocked) {
      try {
        await _profileService.unblockUser(_profileUid);

        if (!mounted) {
          return;
        }

        setState(() {
          _isBlocked = false;
        });

        _showMessage('User unblocked.');
      } catch (_) {
        _showMessage('Unable to unblock user.');
      }

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,

      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Block User?'),

          content: const Text(
            'You will stop seeing this user\'s content where your block filters are applied.',
          ),

          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Cancel'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),

              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text('Block'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _profileService.blockUser(_profileUid);

      if (!mounted) {
        return;
      }

      setState(() {
        _isBlocked = true;
      });

      _showMessage('User blocked.');
    } catch (_) {
      _showMessage('Unable to block user.');
    }
  }

  //===================================================
  // POST LIST FROM SNAPSHOT
  //===================================================

  List<Post> _postsFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<Post> posts = <Post>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      try {
        posts.add(Post.fromFirestore(document));
      } catch (error) {
        debugPrint('Profile post parse error ${document.id}: $error');
      }
    }

    posts.sort((Post a, Post b) {
      final DateTime aDate =
          a.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

      final DateTime bDate =
          b.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return posts;
  }

  //===================================================
  // VISIBLE ONLY
  //===================================================

  List<Post> _visiblePosts(List<Post> posts) {
    return posts.where((Post post) => post.isPubliclyVisible).toList();
  }

  //===================================================
  // ORIGINAL POSTS
  //===================================================

  List<Post> _originalPosts(List<Post> allPosts) {
    return _visiblePosts(
      allPosts,
    ).where((Post post) => !post.isRepost).toList();
  }

  //===================================================
  // REPOSTS
  //===================================================

  List<Post> _reposts(List<Post> allPosts) {
    return _visiblePosts(allPosts).where((Post post) => post.isRepost).toList();
  }

  //===================================================
  // PINNED FIRST
  //===================================================

  List<Post> _orderPinnedPosts(List<Post> posts, List<String> pinnedPostIds) {
    final Map<String, Post> remaining = <String, Post>{
      for (final Post post in posts) post.postId: post,
    };

    final List<Post> result = <Post>[];

    for (final String id in pinnedPostIds.take(3)) {
      final Post? post = remaining.remove(id);

      if (post != null) {
        result.add(post);
      }
    }

    result.addAll(remaining.values);

    return result;
  }

  //===================================================
  // PROFILE HEADER
  //===================================================

  Widget _buildProfileHeader(Map<String, dynamic> data) {
    final String fullName = (data['fullName'] ?? '').toString().trim();

    final String username = (data['username'] ?? '').toString().trim();

    final String photoUrl = (data['photoUrl'] ?? '').toString().trim();

    final String faculty = (data['faculty'] ?? '').toString().trim();

    final String hobbies = (data['hobbies'] ?? '').toString().trim();

    final String favoriteQuote = (data['favoriteQuote'] ?? '')
        .toString()
        .trim();

    final List<String> followers = List<String>.from(
      data['followers'] ?? <String>[],
    );

    final List<String> following = List<String>.from(
      data['following'] ?? <String>[],
    );

    final String currentUid = _auth.currentUser?.uid ?? '';

    final bool isFollowing = followers.contains(currentUid);

    final String displayName = fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
        ? username
        : 'Nubify User';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: <Widget>[
          Row(
            children: <Widget>[
              //===================================================
              // PROFILE PHOTO
              //===================================================

              GestureDetector(
                onTap: photoUrl.isEmpty
                    ? null
                    : () {
                        _showFullProfilePhoto(
                          photoUrl: photoUrl,

                          displayName: displayName,
                        );
                      },

                child: CircleAvatar(
                  radius: 43,

                  backgroundColor: _blue.withValues(alpha: 0.15),

                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,

                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person_rounded, size: 45)
                      : null,
                ),
              ),

              const SizedBox(width: 16),

              //===================================================
              // FOLLOWING / FOLLOWERS / LIKES RECEIVED
              //===================================================
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,

                  children: <Widget>[
                    _ProfileStat(
                      value: _compactNumber(following.length),

                      label: 'Following',
                    ),

                    _ProfileStat(
                      value: _compactNumber(followers.length),

                      label: 'Followers',
                    ),

                    StreamBuilder<int>(
                      stream: _likesReceivedStream,

                      builder:
                          (BuildContext context, AsyncSnapshot<int> snapshot) {
                            return _ProfileStat(
                              value: _compactNumber(snapshot.data ?? 0),

                              label: 'Likes',
                            );
                          },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            displayName,

            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),

          if (username.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),

            Text(
              '@$username',

              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],

          if (faculty.isNotEmpty || hobbies.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),

            Wrap(
              spacing: 7,

              runSpacing: 7,

              children: <Widget>[
                if (faculty.isNotEmpty)
                  _ProfileInfoChip(icon: Icons.school_outlined, text: faculty),

                if (hobbies.isNotEmpty)
                  _ProfileInfoChip(
                    icon: Icons.interests_outlined,

                    text: hobbies,
                  ),
              ],
            ),
          ],

          //===================================================
          // FAVORITE QUOTE
          //
          // WHITE + BOLD
          // NO UNDERLINE
          //
          // ONLY THE QUOTE ICONS ARE USED.
          //===================================================
          if (favoriteQuote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),

            UniversalLinkText(
              text: favoriteQuote,

              compactPreview: true,

              leadingSpan: const WidgetSpan(
                alignment: PlaceholderAlignment.middle,

                child: Padding(
                  padding: EdgeInsets.only(right: 3),

                  child: Icon(
                    Icons.format_quote_rounded,

                    color: _blue,

                    size: 15,
                  ),
                ),
              ),

              trailingSpan: const WidgetSpan(
                alignment: PlaceholderAlignment.middle,

                child: Padding(
                  padding: EdgeInsets.only(left: 3),

                  child: Icon(
                    Icons.format_quote_rounded,

                    color: _blue,

                    size: 15,
                  ),
                ),
              ),

              style: const TextStyle(
                fontSize: 16,

                fontStyle: FontStyle.italic,

                fontWeight: FontWeight.bold,

                color: Colors.white,

                height: 4,

                decoration: TextDecoration.none,
              ),
            ),
          ],

          const SizedBox(height: 16),

          //===================================================
          // BUTTONS
          //===================================================
          if (_isOwner)
            OutlinedButton.icon(
              onPressed: _openEditProfile,

              icon: const Icon(Icons.edit_outlined),

              label: const Text('Edit Profile'),

              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),

                foregroundColor: _blue,

                side: const BorderSide(color: _blue),
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _openChat(data);
                    },

                    icon: const Icon(Icons.chat_bubble_outline_rounded),

                    label: const Text('Message'),

                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: FilledButton.icon(
                    onPressed: _followLoading ? null : _toggleFollow,

                    icon: _followLoading
                        ? const SizedBox(
                            width: 16,

                            height: 16,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,

                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isFollowing
                                ? Icons.person_remove_outlined
                                : Icons.person_add_alt_1_rounded,
                          ),

                    label: Text(isFollowing ? 'Unfollow' : 'Follow'),

                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,

                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  //===================================================
  // OPEN A FULL POST FROM PROFILE GRID
  //===================================================

  void _openGridPostFeed({
    required List<Post> posts,
    required int initialIndex,
    required String title,
    bool isProfilePost = false,
    List<String> pinnedPostIds = const <String>[],
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileVerticalFeed<Post>(
          title: title,
          items: posts,
          initialIndex: initialIndex,
          itemBuilder: (BuildContext context, Post post, int index) {
            return PostCard(
              key: ValueKey<String>('grid-feed-${post.postId}'),
              post: post,
              isProfileScreen: isProfilePost,
              isPinnedToProfile: pinnedPostIds.contains(post.postId),
            );
          },
        ),
      ),
    );
  }

  //===================================================
  // OPEN THE ORIGINAL COMMENT ACTIVITY
  //===================================================

  void _openGridCommentFeed({
    required List<ProfileCommentActivity> activities,
    required int initialIndex,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileVerticalFeed<ProfileCommentActivity>(
          title: 'Comments',
          items: activities,
          initialIndex: initialIndex,
          itemBuilder:
              (
                BuildContext context,
                ProfileCommentActivity activity,
                int index,
              ) {
                return _ProfileCommentPost(
                  key: ValueKey<String>('comment-feed-${activity.activityId}'),
                  activity: activity,
                );
              },
        ),
      ),
    );
  }
  //===================================================
  // MODERN TIKTOK-STYLE PROFILE TAB BAR
  //===================================================

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController!,
      isScrollable: false,
      labelPadding: EdgeInsets.zero,
      indicatorColor: _blue,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerHeight: 0,
      labelColor: _blue,
      unselectedLabelColor: Colors.grey,
      tabs: <Widget>[
        //===================================================
        // POSTS
        //===================================================

        const Tab(
          height: 49,
          icon: Tooltip(message: 'Posts', child: Icon(Icons.grid_view_rounded)),
        ),

        //===================================================
        // REPOSTS
        //===================================================
        const Tab(
          height: 49,
          icon: Tooltip(message: 'Reposts', child: Icon(Icons.repeat_rounded)),
        ),

        //===================================================
        // SAVED
        //===================================================
        if (_isOwner)
          const Tab(
            height: 49,
            icon: Tooltip(
              message: 'Saved',
              child: Icon(Icons.bookmark_outline_rounded),
            ),
          ),

        //===================================================
        // COMMENTS
        //===================================================
        if (_isOwner)
          const Tab(
            height: 49,
            icon: Tooltip(
              message: 'Comments',
              child: Icon(Icons.mode_comment_outlined),
            ),
          ),

        //===================================================
        // LIKES
        //===================================================
        if (_isOwner)
          const Tab(
            height: 49,
            icon: Tooltip(
              message: 'Likes',
              child: Icon(Icons.favorite_border_rounded),
            ),
          ),
      ],
    );
  }
  //===================================================
  // POSTS - THUMBNAIL GRID
  //===================================================

  Widget _buildPostsTab({
    required List<Post> allPosts,
    required List<String> pinnedPostIds,
  }) {
    final List<Post> posts = _orderPinnedPosts(
      _originalPosts(allPosts),
      pinnedPostIds,
    );

    if (posts.isEmpty) {
      return _emptyTab(
        icon: Icons.grid_view_rounded,
        title: 'No posts yet',
        subtitle: _isOwner
            ? 'Your original posts will appear here.'
            : 'This user has not posted yet.',
      );
    }

    return NubifyProfileGrid(
      posts: posts,
      title: 'Posts',
      pinnedPostIds: pinnedPostIds,
      onOpen: (Post post, int index) {
        _openGridPostFeed(
          posts: posts,
          initialIndex: index,
          title: 'Post',
          isProfilePost: true,
          pinnedPostIds: pinnedPostIds,
        );
      },
    );
  }
  //===================================================
  // REPOSTS - THUMBNAIL GRID
  //===================================================

  Widget _buildRepostsTab(List<Post> allPosts) {
    final List<Post> reposts = _reposts(allPosts);

    if (reposts.isEmpty) {
      return _emptyTab(
        icon: Icons.repeat_rounded,
        title: 'No reposts yet',
        subtitle: _isOwner
            ? 'Posts you repost or quote repost will appear here.'
            : 'This user has not reposted anything yet.',
      );
    }

    return NubifyProfileGrid(
      posts: reposts,
      title: 'Reposts',
      onOpen: (Post post, int index) {
        _openGridPostFeed(
          posts: reposts,
          initialIndex: index,
          title: 'Repost',
          isProfilePost: true,
        );
      },
    );
  }
  //===================================================
  // SAVED POSTS - PRIVATE THUMBNAIL GRID
  //===================================================

  Widget _buildSavedTab() {
    final Stream<List<Post>>? stream = _savedPostsStream;

    if (!_isOwner || stream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Post>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyTab(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load saved posts',
            subtitle: '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final List<Post> posts = snapshot.data!;

        if (posts.isEmpty) {
          return _emptyTab(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved posts',
            subtitle: 'Posts you save are private and only visible to you.',
          );
        }

        return NubifyProfileGrid(
          posts: posts,
          title: 'Saved',
          onOpen: (Post post, int index) {
            _openGridPostFeed(
              posts: posts,
              initialIndex: index,
              title: 'Saved post',
            );
          },
        );
      },
    );
  }
  //===================================================
  // COMMENTS - THUMBNAIL GRID
  //===================================================

  Widget _buildCommentsTab() {
    final Stream<List<ProfileCommentActivity>>? stream = _commentsStream;

    if (!_isOwner || stream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<ProfileCommentActivity>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyTab(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load comments',
            subtitle: '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final List<ProfileCommentActivity> activities = snapshot.data!;

        if (activities.isEmpty) {
          return _emptyTab(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No comments yet',
            subtitle: 'Posts you comment or reply on will appear here.',
          );
        }

        return NubifyProfileCommentGrid(
          activities: activities,
          onOpen: (ProfileCommentActivity activity, int index) {
            _openGridCommentFeed(activities: activities, initialIndex: index);
          },
        );
      },
    );
  }
  //===================================================
  // LIKED POSTS - PRIVATE THUMBNAIL GRID
  //===================================================

  Widget _buildLikesTab() {
    final Stream<List<Post>>? stream = _likedPostsStream;

    if (!_isOwner || stream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Post>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyTab(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load likes',
            subtitle: '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final List<Post> posts = snapshot.data!;

        if (posts.isEmpty) {
          return _emptyTab(
            icon: Icons.favorite_border_rounded,
            title: 'No liked posts yet',
            subtitle:
                'Every post, repost and NUBuzz video you like will appear here.',
          );
        }

        return NubifyProfileGrid(
          posts: posts,
          title: 'Likes',
          onOpen: (Post post, int index) {
            _openGridPostFeed(
              posts: posts,
              initialIndex: index,
              title: 'Liked post',
            );
          },
        );
      },
    );
  }

  //===================================================
  // EMPTY TAB
  //===================================================

  Widget _emptyTab({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: <Widget>[
            Icon(icon, color: _blue, size: 50),

            const SizedBox(height: 12),

            Text(
              title,

              textAlign: TextAlign.center,

              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            Text(
              subtitle,

              textAlign: TextAlign.center,

              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // COMPACT NUMBER
  //===================================================

  String _compactNumber(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }

    return '$value';
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final String uid = _profileUid;

    final Stream<DocumentSnapshot<Map<String, dynamic>>>? userStream =
        _userStream;

    final Stream<QuerySnapshot<Map<String, dynamic>>>? postsStream =
        _postsStream;

    if (uid.isEmpty ||
        userStream == null ||
        postsStream == null ||
        _tabController == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _goBack,

            icon: const Icon(Icons.arrow_back_rounded),
          ),

          title: const Text('Profile'),
        ),

        body: const Center(child: Text('Profile unavailable.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,

      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> userSnapshot,
          ) {
            if (userSnapshot.connectionState == ConnectionState.waiting &&
                !userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: _blue)),
              );
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    onPressed: _goBack,

                    icon: const Icon(Icons.arrow_back_rounded),
                  ),

                  title: const Text('Profile'),
                ),

                body: Center(
                  child: Text(
                    'Unable to load profile.\n${userSnapshot.error}',

                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!userSnapshot.hasData ||
                !userSnapshot.data!.exists ||
                userSnapshot.data!.data() == null) {
              if (_isOwner) {
                final Object? repairError = _profileRepairError;

                return Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    title: const Text('Profile'),
                  ),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: repairError == null
                          ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                CircularProgressIndicator(color: _blue),
                                SizedBox(height: 16),
                                Text(
                                  'Finishing your profile setup...',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.person_off_outlined,
                                  color: _blue,
                                  size: 52,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Your profile setup needs another try.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$repairError',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _retryProfileRepair,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Try Again'),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              }

              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    onPressed: _goBack,

                    icon: const Icon(Icons.arrow_back_rounded),
                  ),

                  title: const Text('Profile'),
                ),

                body: const Center(child: Text('This profile is unavailable.')),
              );
            }

            final Map<String, dynamic> data = userSnapshot.data!.data()!;

            final List<String> pinnedPostIds = List<String>.from(
              data['pinnedPostIds'] ?? <String>[],
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: postsStream,

              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                    postsSnapshot,
                  ) {
                    final List<Post> allPosts = postsSnapshot.hasData
                        ? _postsFromSnapshot(postsSnapshot.data!)
                        : <Post>[];

                    return Scaffold(
                      appBar: AppBar(
                        leading: IconButton(
                          onPressed: _goBack,

                          icon: const Icon(Icons.arrow_back_rounded),
                        ),

                        //===================================================
                        // PROFILE TITLE
                        //===================================================
                        title: const Text(
                          'Profile',

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        actions: <Widget>[
                          IconButton(
                            onPressed: _menuLoading
                                ? null
                                : () {
                                    _showProfileMenu(data);
                                  },

                            icon: const Icon(Icons.more_vert_rounded),
                          ),
                        ],
                      ),

                      body: Column(
                        children: <Widget>[
                          _buildProfileHeader(data),

                          const Divider(height: 1),

                          //===================================================
                          // ALL TABS VISIBLE ON ONE ROW
                          //===================================================
                          _buildTabBar(),

                          const Divider(height: 1),

                          Expanded(
                            child:
                                postsSnapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !postsSnapshot.hasData
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: _blue,
                                    ),
                                  )
                                : TabBarView(
                                    controller: _tabController!,

                                    children: <Widget>[
                                      _buildPostsTab(
                                        allPosts: allPosts,

                                        pinnedPostIds: pinnedPostIds,
                                      ),

                                      _buildRepostsTab(allPosts),

                                      if (_isOwner) _buildSavedTab(),

                                      if (_isOwner) _buildCommentsTab(),

                                      if (_isOwner) _buildLikesTab(),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
            );
          },
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

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _tabController?.dispose();

    super.dispose();
  }
}

//===================================================
// PROFILE TAB
//
// FIVE OF THESE FIT ON ONE PHONE WIDTH.
//===================================================

// Retained for the compact labeled-tab variant.
// ignore: unused_element
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.icon, required this.label});

  final IconData icon;

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 53,

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: <Widget>[
          Icon(icon, size: 19),

          const SizedBox(height: 2),

          SizedBox(
            width: double.infinity,

            child: FittedBox(
              fit: BoxFit.scaleDown,

              child: Text(
                label,

                maxLines: 1,

                style: const TextStyle(
                  fontSize: 10.5,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// PROFILE STAT
//===================================================

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,

      children: <Widget>[
        Text(
          value,

          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 2),

        Text(
          label,

          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
      ],
    );
  }
}

//===================================================
// PROFILE INFO CHIP
//===================================================

class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({required this.icon, required this.text});

  final IconData icon;

  final String text;

  static const Color _blue = Color(0xFF29B6F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),

      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.09),

        borderRadius: BorderRadius.circular(17),

        border: Border.all(color: _blue.withValues(alpha: 0.30)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: <Widget>[
          Icon(icon, size: 16, color: _blue),

          const SizedBox(width: 5),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),

            child: Text(
              text,

              maxLines: 2,

              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                fontSize: 11.5,

                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// PROFILE COMMENT POST
//
// SHOW:
// 1. REAL POST / REPOST
// 2. USER'S COMMENT OR REPLY UNDER IT
//===================================================

class _ProfileCommentPost extends StatelessWidget {
  const _ProfileCommentPost({super.key, required this.activity});

  final ProfileCommentActivity activity;

  static const Color _blue = Color(0xFF29B6F6);

  @override
  Widget build(BuildContext context) {
    if (activity.postId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(activity.postId)
          .snapshots(),

      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),

                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (!snapshot.hasData ||
                !snapshot.data!.exists ||
                snapshot.data!.data() == null) {
              return const SizedBox.shrink();
            }

            final Map<String, dynamic> data = snapshot.data!.data()!;

            if (data['isHidden'] == true || data['isRootHidden'] == true) {
              return const SizedBox.shrink();
            }

            Post post;

            try {
              post = Post.fromFirestore(snapshot.data!);
            } catch (_) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: <Widget>[
                //===================================================
                // FULL POST CONTENT
                //===================================================

                PostCard(
                  key: ValueKey<String>(
                    'comment-activity-post-${activity.activityId}-${post.postId}',
                  ),

                  post: post,
                ),

                //===================================================
                // COMMENT USER MADE
                //===================================================
                GestureDetector(
                  behavior: HitTestBehavior.opaque,

                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute<void>(
                        builder: (_) => CommentsScreen(postId: activity.postId),
                      ),
                    );
                  },

                  child: Container(
                    width: double.infinity,

                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.08),

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: _blue.withValues(alpha: 0.30)),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              activity.isReply
                                  ? Icons.reply_rounded
                                  : Icons.chat_bubble_outline_rounded,

                              size: 17,

                              color: _blue,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              activity.isReply
                                  ? activity.replyToUsername.isNotEmpty
                                        ? 'You replied to @${activity.replyToUsername}'
                                        : 'You posted a reply'
                                  : 'You commented on this post',

                              style: const TextStyle(
                                color: _blue,

                                fontSize: 12,

                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const Spacer(),

                            if (activity.createdAt != null)
                              Text(
                                _profileActivityTime(activity.createdAt!),

                                style: TextStyle(
                                  color: Colors.grey.shade600,

                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),

                        if (activity.text.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 7),

                          Text(
                            activity.text,

                            style: const TextStyle(fontSize: 14, height: 1.35),
                          ),
                        ],

                        //===================================================
                        // COMMENT IMAGE
                        //===================================================
                        if (activity.imageUrl.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 9),

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),

                              child: Image.network(
                                activity.imageUrl,

                                width: 150,

                                height: 150,

                                fit: BoxFit.cover,

                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) {
                                      return const SizedBox.shrink();
                                    },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),
              ],
            );
          },
    );
  }
}

//===================================================
// PROFILE ACTIVITY TIME
//===================================================

String _profileActivityTime(DateTime date) {
  Duration difference = DateTime.now().difference(date);

  if (difference.isNegative) {
    difference = Duration.zero;
  }

  if (difference.inSeconds < 60) {
    return 'just now';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours}h';
  }

  if (difference.inDays <= 7) {
    return '${difference.inDays}d';
  }

  final int hour12 = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final String minute = date.minute.toString().padLeft(2, '0');

  final String period = date.hour >= 12 ? 'PM' : 'AM';

  return '${date.day}/${date.month}/${date.year} $hour12:$minute $period';
}

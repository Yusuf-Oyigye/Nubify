import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../services/profile_service.dart';
import '../widgets/post_card.dart';
import 'conversation_screen.dart';
import 'edit_profile_screen.dart';

//===================================================
// PROFILE SCREEN
//===================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.userId,
  });

  final String? userId;

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

//===================================================
// PROFILE STATE
//===================================================

class _ProfileScreenState
    extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===================================================
  // PROFILE SERVICE
  //===================================================

  final ProfileService _profileService =
  ProfileService();

  TabController? _tabController;

  bool _followLoading =
  false;

  bool _menuLoading =
  false;

  bool _isBlocked =
  false;

  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

  //===================================================
  // PROFILE UID
  //===================================================

  String get _profileUid {
    final String passed =
        widget.userId?.trim() ??
            '';

    if (passed.isNotEmpty) {
      return passed;
    }

    return _auth.currentUser?.uid ??
        '';
  }

  //===================================================
  // OWNER
  //===================================================

  bool get _isOwner {
    final String? currentUid =
        _auth.currentUser?.uid;

    return currentUid !=
        null &&
        currentUid.isNotEmpty &&
        currentUid ==
            _profileUid;
  }

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _createTabController();

    _loadBlockedState();
  }

  //===================================================
  // UPDATE
  //===================================================

  @override
  void didUpdateWidget(
      covariant ProfileScreen oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.userId !=
        widget.userId) {
      _tabController?.dispose();

      _createTabController();

      _loadBlockedState();
    }
  }

  //===================================================
  // TAB CONTROLLER
  //===================================================

  void _createTabController() {
    _tabController =
        TabController(
          length:
          _isOwner
              ? 3
              : 2,
          vsync:
          this,
        );
  }

  //===================================================
  // LOAD BLOCK STATE
  //===================================================

  Future<void> _loadBlockedState() async {
    if (_isOwner ||
        _profileUid.isEmpty) {
      return;
    }

    try {
      final bool blocked =
      await _profileService
          .isBlocked(
        _profileUid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isBlocked =
            blocked;
      });
    } catch (_) {}
  }

  //===================================================
  // BACK HOME
  //===================================================

  void _goHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();

      return;
    }

    Navigator.of(context)
        .pushNamedAndRemoveUntil(
      '/home',
          (
          Route<dynamic> route,
          ) =>
      false,
    );
  }

  //===================================================
  // FULL PROFILE PICTURE
  //
  // TAP PROFILE PICTURE -> FULLSCREEN
  // PINCH TO ZOOM
  //===================================================

  Future<void> _showFullProfilePhoto({
    required String photoUrl,
    required String displayName,
  }) async {
    if (photoUrl.trim().isEmpty) {
      return;
    }

    await showGeneralDialog<void>(
      context:
      context,
      barrierDismissible:
      true,
      barrierLabel:
      'Profile picture',
      barrierColor:
      Colors.black.withOpacity(
        0.96,
      ),
      transitionDuration:
      const Duration(
        milliseconds:
        180,
      ),
      pageBuilder:
          (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          ) {
        return Material(
          color:
          Colors.transparent,
          child:
          SafeArea(
            child:
            Stack(
              fit:
              StackFit.expand,
              children:
              <Widget>[
                //===================================================
                // TAP BACKGROUND TO CLOSE
                //===================================================

                GestureDetector(
                  behavior:
                  HitTestBehavior.opaque,
                  onTap:
                      () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child:
                  const SizedBox.expand(),
                ),

                //===================================================
                // FULL PHOTO
                //===================================================

                Center(
                  child:
                  GestureDetector(
                    onTap:
                        () {},
                    child:
                    InteractiveViewer(
                      minScale:
                      1,
                      maxScale:
                      5,
                      child:
                      Image.network(
                        photoUrl,
                        width:
                        double.infinity,
                        fit:
                        BoxFit.contain,
                        errorBuilder:
                            (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                            ) {
                          return const Icon(
                            Icons.person_rounded,
                            color:
                            Colors.white54,
                            size:
                            110,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                //===================================================
                // TOP BAR
                //===================================================

                Positioned(
                  left:
                  12,
                  right:
                  12,
                  top:
                  6,
                  child:
                  Row(
                    children:
                    <Widget>[
                      IconButton(
                        onPressed:
                            () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                        icon:
                        const Icon(
                          Icons.close_rounded,
                          color:
                          Colors.white,
                          size:
                          30,
                        ),
                      ),

                      const SizedBox(
                        width:
                        5,
                      ),

                      Expanded(
                        child:
                        Text(
                          displayName,
                          maxLines:
                          1,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          const TextStyle(
                            color:
                            Colors.white,
                            fontSize:
                            17,
                            fontWeight:
                            FontWeight.w700,
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
  // FOLLOW / UNFOLLOW
  //===================================================

  Future<void> _toggleFollow() async {
    if (_followLoading ||
        _isOwner) {
      return;
    }

    setState(() {
      _followLoading =
      true;
    });

    try {
      final bool nowFollowing =
      await _profileService
          .toggleFollow(
        _profileUid,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        nowFollowing
            ? 'Following.'
            : 'Unfollowed.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _followLoading =
          false;
        });
      }
    }
  }

  //===================================================
  // OPEN CHAT
  //===================================================

  Future<void> _openChat(
      Map<String, dynamic> data,
      ) async {
    if (_isOwner ||
        _profileUid.isEmpty) {
      return;
    }

    final String fullName =
    (data['fullName'] ?? '')
        .toString()
        .trim();

    final String username =
    (data['username'] ?? '')
        .toString()
        .trim();

    final String photoUrl =
    (data['photoUrl'] ?? '')
        .toString()
        .trim();

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder:
            (_) =>
            ConversationScreen(
              otherUserId:
              _profileUid,
              otherName:
              fullName.isNotEmpty
                  ? fullName
                  : username,
              otherUsername:
              username,
              otherPhotoUrl:
              photoUrl,
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
      MaterialPageRoute<bool>(
        builder:
            (_) =>
        const EditProfileScreen(),
      ),
    );
  }

  //===================================================
  // PROFILE MENU
  //===================================================

  Future<void> _showProfileMenu(
      Map<String, dynamic> data,
      ) async {
    if (_menuLoading) {
      return;
    }

    final String username =
    (data['username'] ?? '')
        .toString()
        .trim();

    await showModalBottomSheet<void>(
      context:
      context,
      showDragHandle:
      true,
      builder:
          (
          BuildContext sheetContext,
          ) {
        Future<void> closeThen(
            Future<void> Function() action,
            ) async {
          Navigator.pop(
            sheetContext,
          );

          await Future<void>.delayed(
            const Duration(
              milliseconds:
              180,
            ),
          );

          if (!mounted) {
            return;
          }

          await action();
        }

        return SafeArea(
          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,
            children:
            <Widget>[
              ListTile(
                leading:
                const Icon(
                  Icons.share_outlined,
                ),
                title:
                const Text(
                  'Share Profile',
                ),
                onTap:
                    () {
                  closeThen(
                        () =>
                        _shareProfile(
                          username,
                        ),
                  );
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.link_rounded,
                ),
                title:
                const Text(
                  'Copy Profile Link',
                ),
                onTap:
                    () {
                  closeThen(
                    _copyProfileLink,
                  );
                },
              ),

              if (!_isOwner)
                ...<Widget>[
                  const Divider(),

                  ListTile(
                    leading:
                    const Icon(
                      Icons.flag_outlined,
                    ),
                    title:
                    const Text(
                      'Report User',
                    ),
                    onTap:
                        () {
                      closeThen(
                        _reportUser,
                      );
                    },
                  ),

                  ListTile(
                    leading:
                    Icon(
                      _isBlocked
                          ? Icons
                          .lock_open_rounded
                          : Icons
                          .block_outlined,
                      color:
                      _isBlocked
                          ? _blue
                          : Colors.redAccent,
                    ),
                    title:
                    Text(
                      _isBlocked
                          ? 'Unblock User'
                          : 'Block User',
                      style:
                      TextStyle(
                        color:
                        _isBlocked
                            ? null
                            : Colors.redAccent,
                      ),
                    ),
                    onTap:
                        () {
                      closeThen(
                        _toggleBlock,
                      );
                    },
                  ),
                ],

              const SizedBox(
                height:
                10,
              ),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // SHARE PROFILE
  //===================================================

  Future<void> _shareProfile(
      String username,
      ) async {
    final String link =
        'https://nubify.app/profile/$_profileUid';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
          username.isEmpty
              ? link
              : 'Check out @$username on Nubify\n$link',
        ),
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to share profile.',
        );
      }
    }
  }

  //===================================================
  // COPY PROFILE LINK
  //===================================================

  Future<void> _copyProfileLink() async {
    final String link =
        'https://nubify.app/profile/$_profileUid';

    await Clipboard.setData(
      ClipboardData(
        text:
        link,
      ),
    );

    _showMessage(
      'Profile link copied.',
    );
  }

  //===================================================
  // REPORT USER
  //===================================================

  Future<void> _reportUser() async {
    if (_isOwner) {
      return;
    }

    const List<String> reasons =
    <String>[
      'Spam or fake account',
      'Harassment or bullying',
      'Hate or abusive behaviour',
      'Impersonation',
      'Scam or fraud',
      'Inappropriate content',
      'Other',
    ];

    final String? reason =
    await showDialog<String>(
      context:
      context,
      builder:
          (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Report User',
          ),
          content:
          SizedBox(
            width:
            double.maxFinite,
            child:
            ListView.separated(
              shrinkWrap:
              true,
              itemCount:
              reasons.length,
              separatorBuilder:
                  (
                  _,
                  __,
                  ) =>
              const Divider(
                height:
                1,
              ),
              itemBuilder:
                  (
                  _,
                  int index,
                  ) {
                return ListTile(
                  title:
                  Text(
                    reasons[index],
                  ),
                  onTap:
                      () {
                    Navigator.pop(
                      dialogContext,
                      reasons[index],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    setState(() {
      _menuLoading =
      true;
    });

    try {
      await _profileService.reportUser(
        targetUid:
        _profileUid,
        reason:
        reason,
      );

      if (mounted) {
        _showMessage(
          'Report submitted.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to report this user.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _menuLoading =
          false;
        });
      }
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
        await _profileService.unblockUser(
          _profileUid,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _isBlocked =
          false;
        });

        _showMessage(
          'User unblocked.',
        );
      } catch (_) {
        _showMessage(
          'Unable to unblock user.',
        );
      }

      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context:
      context,
      builder:
          (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Block User?',
          ),
          content:
          const Text(
            'You will stop seeing this user\'s content in places where your block filters are applied.',
          ),
          actions:
          <Widget>[
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                Colors.red,
              ),
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
              const Text(
                'Block',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed !=
        true ||
        !mounted) {
      return;
    }

    try {
      await _profileService.blockUser(
        _profileUid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isBlocked =
        true;
      });

      _showMessage(
        'User blocked.',
      );
    } catch (_) {
      _showMessage(
        'Unable to block user.',
      );
    }
  }

  //===================================================
  // COMPACT NUMBER
  //===================================================

  String _compactNumber(
      int value,
      ) {
    if (value >=
        1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }

    if (value >=
        1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }

    if (value >=
        1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }

    return '$value';
  }

  //===================================================
  // POSTS FROM SNAPSHOT
  //===================================================

  List<Post> _postsFromSnapshot(
      QuerySnapshot<
          Map<String, dynamic>>
      snapshot,
      ) {
    final List<Post> posts =
    snapshot.docs
        .map(
          (
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          document,
          ) =>
          Post.fromFirestore(
            document,
          ),
    )
        .toList();

    posts.sort(
          (
          Post a,
          Post b,
          ) {
        final DateTime aTime =
            a.createdAt
                ?.toDate() ??
                DateTime
                    .fromMillisecondsSinceEpoch(
                  0,
                );

        final DateTime bTime =
            b.createdAt
                ?.toDate() ??
                DateTime
                    .fromMillisecondsSinceEpoch(
                  0,
                );

        return bTime.compareTo(
          aTime,
        );
      },
    );

    return posts;
  }

  //===================================================
  // PINNED POSTS FIRST
  //===================================================

  List<Post> _orderPostsForProfile(
      List<Post> posts,
      List<String> pinnedPostIds,
      ) {
    final List<Post> originalPosts =
    posts
        .where(
          (
          Post post,
          ) =>
      !post.isRepost,
    )
        .toList();

    final Map<String, Post> byId =
    <String, Post>{
      for (
      final Post post
      in originalPosts
      )
        post.postId:
        post,
    };

    final List<Post> pinned =
    <Post>[];

    for (
    final String postId
    in pinnedPostIds.take(
      3,
    )
    ) {
      final Post? post =
      byId.remove(
        postId,
      );

      if (post != null) {
        pinned.add(
          post,
        );
      }
    }

    return <Post>[
      ...pinned,
      ...byId.values,
    ];
  }

  //===================================================
  // PROFILE HEADER
  //===================================================

  Widget _buildProfileHeader({
    required Map<String, dynamic> data,
    required List<Post> allPosts,
  }) {
    final String fullName =
    (data['fullName'] ?? '')
        .toString()
        .trim();

    final String username =
    (data['username'] ?? '')
        .toString()
        .trim();

    final String photoUrl =
    (data['photoUrl'] ?? '')
        .toString()
        .trim();

    final String faculty =
    (data['faculty'] ?? '')
        .toString()
        .trim();

    final String hobbies =
    (data['hobbies'] ?? '')
        .toString()
        .trim();

    final String quote =
    (data['favoriteQuote'] ??
        '')
        .toString()
        .trim();

    final List<String> followers =
    List<String>.from(
      data['followers'] ??
          <String>[],
    );

    final List<String> following =
    List<String>.from(
      data['following'] ??
          <String>[],
    );

    final String currentUid =
        _auth.currentUser?.uid ??
            '';

    final bool isFollowing =
    followers.contains(
      currentUid,
    );

    final int likes =
    allPosts.fold<int>(
      0,
          (
          int total,
          Post post,
          ) =>
      total +
          post.likeCount,
    );

    final String displayName =
    fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
        ? username
        : 'Nubify User';

    return Padding(
      padding:
      const EdgeInsets
          .fromLTRB(
        18,
        14,
        18,
        16,
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children:
        <Widget>[
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children:
            <Widget>[
              //===================================================
              // PROFILE PHOTO
              // TAP IT -> FULL SCREEN
              //===================================================

              GestureDetector(
                behavior:
                HitTestBehavior.opaque,
                onTap:
                photoUrl.isEmpty
                    ? null
                    : () {
                  _showFullProfilePhoto(
                    photoUrl:
                    photoUrl,
                    displayName:
                    displayName,
                  );
                },
                child:
                CircleAvatar(
                  radius:
                  45,
                  backgroundColor:
                  _blue.withOpacity(
                    0.18,
                  ),
                  backgroundImage:
                  photoUrl.isNotEmpty
                      ? NetworkImage(
                    photoUrl,
                  )
                      : null,
                  child:
                  photoUrl.isEmpty
                      ? const Icon(
                    Icons.person_rounded,
                    color:
                    Colors.white70,
                    size:
                    46,
                  )
                      : null,
                ),
              ),

              const SizedBox(
                width:
                20,
              ),

              Expanded(
                child:
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
                  children:
                  <Widget>[
                    _ProfileStat(
                      value:
                      _compactNumber(
                        following.length,
                      ),
                      label:
                      'Following',
                    ),
                    _ProfileStat(
                      value:
                      _compactNumber(
                        followers.length,
                      ),
                      label:
                      'Followers',
                    ),
                    _ProfileStat(
                      value:
                      _compactNumber(
                        likes,
                      ),
                      label:
                      'Likes',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            15,
          ),

          Text(
            displayName,
            style:
            const TextStyle(
              fontSize:
              19,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          if (username.isNotEmpty)
            ...<Widget>[
              const SizedBox(
                height:
                2,
              ),
              Text(
                '@$username',
                style:
                TextStyle(
                  color:
                  Colors.grey
                      .shade400,
                  fontSize:
                  13,
                ),
              ),
            ],

          const SizedBox(
            height:
            12,
          ),

          //===================================================
          // FACULTY + HOBBIES
          //===================================================

          Wrap(
            spacing:
            9,
            runSpacing:
            8,
            children:
            <Widget>[
              if (faculty.isNotEmpty)
                _ProfileInfoChip(
                  icon:
                  Icons
                      .school_outlined,
                  text:
                  faculty,
                ),
              if (hobbies.isNotEmpty)
                _ProfileInfoChip(
                  icon:
                  Icons
                      .interests_outlined,
                  text:
                  hobbies,
                ),
            ],
          ),

          //===================================================
          // QUOTE
          //===================================================

          if (quote.isNotEmpty)
            ...<Widget>[
              const SizedBox(
                height:
                13,
              ),
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children:
                <Widget>[
                  const Icon(
                    Icons
                        .format_quote_rounded,
                    color:
                    _blue,
                    size:
                    22,
                  ),
                  const SizedBox(
                    width:
                    5,
                  ),
                  Expanded(
                    child:
                    Text(
                      '“$quote”',
                      style:
                      const TextStyle(
                        fontSize:
                        14,
                        fontStyle:
                        FontStyle.italic,
                        height:
                        1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],

          const SizedBox(
            height:
            15,
          ),

          //===================================================
          // OWNER
          //===================================================

          if (_isOwner)
            OutlinedButton.icon(
              onPressed:
              _openEditProfile,
              icon:
              const Icon(
                Icons.edit_outlined,
              ),
              label:
              const Text(
                'Edit Profile',
              ),
              style:
              OutlinedButton
                  .styleFrom(
                minimumSize:
                const Size
                    .fromHeight(
                  45,
                ),
                side:
                const BorderSide(
                  color:
                  _blue,
                ),
                foregroundColor:
                _blue,
              ),
            )
          else

          //===================================================
          // OTHER USER
          //===================================================

            Row(
              children:
              <Widget>[
                Expanded(
                  child:
                  OutlinedButton.icon(
                    onPressed:
                        () {
                      _openChat(
                        data,
                      );
                    },
                    icon:
                    const Icon(
                      Icons
                          .chat_bubble_outline_rounded,
                    ),
                    label:
                    const Text(
                      'Message',
                    ),
                    style:
                    OutlinedButton
                        .styleFrom(
                      minimumSize:
                      const Size
                          .fromHeight(
                        45,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  10,
                ),

                Expanded(
                  child:
                  FilledButton.icon(
                    onPressed:
                    _followLoading
                        ? null
                        : _toggleFollow,
                    icon:
                    _followLoading
                        ? const SizedBox(
                      width:
                      16,
                      height:
                      16,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                        color:
                        Colors.white,
                      ),
                    )
                        : Icon(
                      isFollowing
                          ? Icons
                          .person_remove_outlined
                          : Icons
                          .person_add_alt_1_rounded,
                    ),
                    label:
                    Text(
                      isFollowing
                          ? 'Unfollow'
                          : 'Follow',
                    ),
                    style:
                    FilledButton
                        .styleFrom(
                      backgroundColor:
                      _blue,
                      minimumSize:
                      const Size
                          .fromHeight(
                        45,
                      ),
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
  // EMPTY TAB
  //===================================================

  Widget _emptyTab({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          28,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children:
          <Widget>[
            Icon(
              icon,
              color:
              _blue,
              size:
              52,
            ),
            const SizedBox(
              height:
              12,
            ),
            Text(
              title,
              style:
              const TextStyle(
                fontSize:
                17,
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(
              height:
              5,
            ),
            Text(
              subtitle,
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                Colors.grey
                    .shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // POSTS TAB
  //===================================================

  Widget _buildPostsTab({
    required List<Post> allPosts,
    required List<String> pinnedPostIds,
  }) {
    final List<Post> posts =
    _orderPostsForProfile(
      allPosts,
      pinnedPostIds,
    );

    if (posts.isEmpty) {
      return _emptyTab(
        icon:
        Icons
            .grid_view_rounded,
        title:
        'No posts yet',
        subtitle:
        _isOwner
            ? 'Your posts will appear here.'
            : 'This user has not posted yet.',
      );
    }

    return ListView.builder(
      padding:
      const EdgeInsets.only(
        bottom:
        25,
      ),
      itemCount:
      posts.length,
      itemBuilder:
          (
          BuildContext context,
          int index,
          ) {
        final Post post =
        posts[index];

        final bool pinned =
        pinnedPostIds.contains(
          post.postId,
        );

        return Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children:
          <Widget>[
            if (pinned)
              const Padding(
                padding:
                EdgeInsets
                    .fromLTRB(
                  14,
                  9,
                  14,
                  0,
                ),
                child:
                Row(
                  children:
                  <Widget>[
                    Icon(
                      Icons
                          .push_pin_outlined,
                      size:
                      15,
                      color:
                      _blue,
                    ),
                    SizedBox(
                      width:
                      5,
                    ),
                    Text(
                      'Pinned',
                      style:
                      TextStyle(
                        color:
                        _blue,
                        fontSize:
                        12,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            PostCard(
              post:
              post,
              isProfileScreen:
              true,
              isPinnedToProfile:
              pinned,
            ),
          ],
        );
      },
    );
  }

  //===================================================
  // REPOSTS TAB
  //===================================================

  Widget _buildRepostsTab(
      List<Post> allPosts,
      ) {
    final List<Post> reposts =
    allPosts
        .where(
          (
          Post post,
          ) =>
      post.isRepost,
    )
        .toList();

    if (reposts.isEmpty) {
      return _emptyTab(
        icon:
        Icons.repeat_rounded,
        title:
        'No reposts yet',
        subtitle:
        _isOwner
            ? 'Posts you repost will appear here.'
            : 'This user has not reposted anything yet.',
      );
    }

    return ListView.builder(
      padding:
      const EdgeInsets.only(
        bottom:
        25,
      ),
      itemCount:
      reposts.length,
      itemBuilder:
          (
          BuildContext context,
          int index,
          ) {
        return PostCard(
          post:
          reposts[index],
        );
      },
    );
  }

  //===================================================
  // SAVED TAB
  //===================================================

  Widget _buildSavedTab() {
    if (!_isOwner) {
      return const SizedBox
          .shrink();
    }

    return StreamBuilder<
        List<Post>>(
      stream:
      _profileService
          .savedPostsStream(
        _profileUid,
      ),
      builder:
          (
          BuildContext context,
          AsyncSnapshot<List<Post>>
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

        final List<Post> posts =
            snapshot.data ??
                <Post>[];

        if (posts.isEmpty) {
          return _emptyTab(
            icon:
            Icons
                .bookmark_border_rounded,
            title:
            'No saved posts',
            subtitle:
            'Posts you save are private and only visible to you.',
          );
        }

        return ListView.builder(
          padding:
          const EdgeInsets.only(
            bottom:
            25,
          ),
          itemCount:
          posts.length,
          itemBuilder:
              (
              BuildContext context,
              int index,
              ) {
            return PostCard(
              post:
              posts[index],
            );
          },
        );
      },
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_profileUid.isEmpty) {
      return Scaffold(
        appBar:
        AppBar(
          leading:
          IconButton(
            onPressed:
            _goHome,
            icon:
            const Icon(
              Icons
                  .arrow_back_rounded,
            ),
          ),
          title:
          const Text(
            'Profile',
          ),
        ),
        body:
        const Center(
          child:
          Text(
            'Profile unavailable.',
          ),
        ),
      );
    }

    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream:
      _profileService
          .userStream(
        _profileUid,
      ),
      builder:
          (
          BuildContext context,
          AsyncSnapshot<
              DocumentSnapshot<
                  Map<String, dynamic>>>
          userSnapshot,
          ) {
        if (userSnapshot
            .connectionState ==
            ConnectionState.waiting &&
            !userSnapshot.hasData) {
          return const Scaffold(
            body:
            Center(
              child:
              CircularProgressIndicator(
                color:
                _blue,
              ),
            ),
          );
        }

        if (!userSnapshot.hasData ||
            !userSnapshot
                .data!.exists ||
            userSnapshot.data!
                .data() ==
                null) {
          return Scaffold(
            appBar:
            AppBar(
              leading:
              IconButton(
                onPressed:
                _goHome,
                icon:
                const Icon(
                  Icons
                      .arrow_back_rounded,
                ),
              ),
              title:
              const Text(
                'Profile',
              ),
            ),
            body:
            const Center(
              child:
              Text(
                'This profile is unavailable.',
              ),
            ),
          );
        }

        final Map<String, dynamic> data =
        userSnapshot.data!
            .data()!;

        final List<String>
        pinnedPostIds =
        List<String>.from(
          data['pinnedPostIds'] ??
              <String>[],
        );

        return StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream:
          _profileService
              .postsStream(
            _profileUid,
          ),
          builder:
              (
              BuildContext context,
              AsyncSnapshot<
                  QuerySnapshot<
                      Map<String, dynamic>>>
              postsSnapshot,
              ) {
            final List<Post> allPosts =
            postsSnapshot.hasData
                ? _postsFromSnapshot(
              postsSnapshot.data!,
            )
                : <Post>[];

            final TabController tabController =
            _tabController!;

            return Scaffold(
              appBar:
              AppBar(
                leading:
                IconButton(
                  tooltip:
                  'Back to Home',
                  onPressed:
                  _goHome,
                  icon:
                  const Icon(
                    Icons
                        .arrow_back_rounded,
                  ),
                ),
                title:
                const Text(
                  'Profile',
                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                actions:
                <Widget>[
                  IconButton(
                    onPressed:
                    _menuLoading
                        ? null
                        : () {
                      _showProfileMenu(
                        data,
                      );
                    },
                    icon:
                    const Icon(
                      Icons
                          .more_vert_rounded,
                    ),
                  ),
                ],
              ),

              body:
              Column(
                children:
                <Widget>[
                  _buildProfileHeader(
                    data:
                    data,
                    allPosts:
                    allPosts,
                  ),

                  const Divider(
                    height:
                    1,
                  ),

                  TabBar(
                    controller:
                    tabController,
                    indicatorColor:
                    _blue,
                    labelColor:
                    _blue,
                    unselectedLabelColor:
                    Colors.grey,
                    tabs:
                    <Tab>[
                      const Tab(
                        icon:
                        Icon(
                          Icons
                              .grid_view_rounded,
                        ),
                        text:
                        'Posts',
                      ),
                      const Tab(
                        icon:
                        Icon(
                          Icons
                              .repeat_rounded,
                        ),
                        text:
                        'Reposts',
                      ),
                      if (_isOwner)
                        const Tab(
                          icon:
                          Icon(
                            Icons
                                .bookmark_rounded,
                          ),
                          text:
                          'Saved',
                        ),
                    ],
                  ),

                  Expanded(
                    child:
                    postsSnapshot
                        .connectionState ==
                        ConnectionState
                            .waiting &&
                        !postsSnapshot
                            .hasData
                        ? const Center(
                      child:
                      CircularProgressIndicator(
                        color:
                        _blue,
                      ),
                    )
                        : TabBarView(
                      controller:
                      tabController,
                      children:
                      <Widget>[
                        _buildPostsTab(
                          allPosts:
                          allPosts,
                          pinnedPostIds:
                          pinnedPostIds,
                        ),
                        _buildRepostsTab(
                          allPosts,
                        ),
                        if (_isOwner)
                          _buildSavedTab(),
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
    _tabController?.dispose();

    super.dispose();
  }
}

//===================================================
// PROFILE STAT
//===================================================

class _ProfileStat
    extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
  });

  final String value;

  final String label;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      mainAxisSize:
      MainAxisSize.min,
      children:
      <Widget>[
        Text(
          value,
          style:
          const TextStyle(
            fontSize:
            18,
            fontWeight:
            FontWeight.w800,
          ),
        ),
        const SizedBox(
          height:
          2,
        ),
        Text(
          label,
          style:
          TextStyle(
            color:
            Colors.grey
                .shade400,
            fontSize:
            12,
          ),
        ),
      ],
    );
  }
}

//===================================================
// PROFILE INFO CHIP
//===================================================

class _ProfileInfoChip
    extends StatelessWidget {
  const _ProfileInfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;

  final String text;

  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal:
        10,
        vertical:
        7,
      ),
      decoration:
      BoxDecoration(
        color:
        _blue.withOpacity(
          0.10,
        ),
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
          color:
          _blue.withOpacity(
            0.35,
          ),
        ),
      ),
      child:
      Row(
        mainAxisSize:
        MainAxisSize.min,
        children:
        <Widget>[
          Icon(
            icon,
            size:
            17,
            color:
            _blue,
          ),
          const SizedBox(
            width:
            6,
          ),
          ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth:
              230,
            ),
            child:
            Text(
              text,
              maxLines:
              2,
              overflow:
              TextOverflow.ellipsis,
              style:
              const TextStyle(
                fontSize:
                12,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
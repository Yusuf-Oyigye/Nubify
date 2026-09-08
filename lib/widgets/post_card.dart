import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../screens/comment_screen.dart';
import '../services/like_service.dart';
import '../services/post_actions_service.dart';
import '../services/repost_service.dart';
import '../utils/nubify_time.dart';
import 'post_media_carousel.dart';

//===================================================
// POST CARD
//===================================================

class PostCard extends StatefulWidget {
  final Post post;

  final bool inCommentsScreen;

  //===================================================
  // PROFILE SCREEN OPTIONS
  //===================================================

  final bool isProfileScreen;

  final bool isPinnedToProfile;

  const PostCard({
    super.key,
    required this.post,
    this.inCommentsScreen = false,
    this.isProfileScreen = false,
    this.isPinnedToProfile = false,
  });

  @override
  State<PostCard> createState() =>
      _PostCardState();
}

//===================================================
// POST CARD STATE
//===================================================

class _PostCardState extends State<PostCard> {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  //===================================================
  // SERVICES
  //===================================================

  final LikeService _likeService =
  LikeService();

  final PostActionsService _postActionsService =
  PostActionsService();

  final RepostService _repostService =
  RepostService();

  //===================================================
  // LIKE STATE
  //===================================================

  bool _isLiked = false;

  bool _isLikeLoading = false;

  int _likeCount = 0;

  //===================================================
  // OTHER STATE
  //===================================================

  bool _isSaved = false;

  bool _showHeartAnimation = false;

  String _caption = '';

  bool _isDeleted = false;

  //===================================================
  // VIEW STATE
  //===================================================

  int _viewCount = 0;

  bool _viewRecorded = false;

  //===================================================
  // POLL STATE
  //===================================================

  bool _hasPoll = false;

  String _pollQuestion = '';

  List<Map<String, dynamic>> _pollOptions =
  <Map<String, dynamic>>[];

  int _pollTotalVotes = 0;

  String? _selectedPollOption;

  bool _hasVoted = false;

  bool _isVoting = false;

  bool _pollLoading = true;

  //===================================================
  // POLL EXPIRY
  //===================================================

  DateTime? _pollExpiresAt;

  bool _pollClosed = false;

  int? _winnerOptionIndex;

  DateTime? _pollClosedAt;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _likeCount =
        widget.post.likeCount;

    _viewCount =
        widget.post.viewCount;

    _caption =
        widget.post.caption;

    _loadLikeStatus();

    _loadSavedStatus();

    _loadPoll();

    _recordView();

    _checkIfHidden();
  }

  //===================================================
  // OPEN AUTHOR PROFILE
  //===================================================

  Future<void> _openAuthorProfile() async {
    final String uid =
    widget.post.uid.trim();

    if (uid.isEmpty ||
        !mounted) {
      return;
    }

    await Navigator.of(context).pushNamed(
      '/profile',
      arguments: uid,
    );
  }

  //===================================================
  // LOAD LIKE STATUS
  //===================================================

  Future<void> _loadLikeStatus() async {
    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        return;
      }

      final bool liked =
      await _likeService.hasLiked(
        widget.post.postId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = liked;
      });
    } catch (error) {
      debugPrint(
        'Error loading like status: $error',
      );
    }
  }

  //===================================================
  // LIKE / UNLIKE
  //===================================================

  Future<void> _toggleLike() async {
    if (_isLikeLoading) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in to like this post.',
      );

      return;
    }

    setState(() {
      _isLikeLoading = true;
    });

    try {
      if (_isLiked) {
        await _likeService.unlikePost(
          widget.post.postId,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _isLiked = false;

          if (_likeCount > 0) {
            _likeCount--;
          }
        });
      } else {
        await _likeService.likePost(
          widget.post.postId,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _isLiked = true;

          _likeCount++;
        });
      }
    } catch (error) {
      debugPrint(
        'Like error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to update like.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  //===================================================
  // DOUBLE TAP LIKE
  //===================================================

  Future<void> _doubleTapLike() async {
    setState(() {
      _showHeartAnimation = true;
    });

    if (!_isLiked &&
        !_isLikeLoading) {
      await _toggleLike();
    }

    await Future<void>.delayed(
      const Duration(
        milliseconds: 650,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _showHeartAnimation = false;
    });
  }

  //===================================================
  // HIDDEN POST CHECK
  //===================================================

  Future<void> _checkIfHidden() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('hiddenPosts')
          .doc(widget.post.postId)
          .get();

      if (!mounted) {
        return;
      }

      if (snapshot.exists) {
        setState(() {
          _isDeleted = true;
        });
      }
    } catch (error) {
      debugPrint(
        'Check hidden post error: $error',
      );
    }
  }

  //===================================================
  // RECORD VIEW
  //
  // ONE VIEW PER USER
  //===================================================

  Future<void> _recordView() async {
    if (_viewRecorded) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    _viewRecorded = true;

    try {
      final DocumentReference<Map<String, dynamic>>
      postRef =
      _firestore
          .collection('posts')
          .doc(widget.post.postId);

      final DocumentReference<Map<String, dynamic>>
      viewRef =
      postRef
          .collection('views')
          .doc(user.uid);

      final DocumentSnapshot<Map<String, dynamic>>
      existingView =
      await viewRef.get();

      if (existingView.exists) {
        return;
      }

      bool added = false;

      await _firestore.runTransaction(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<Map<String, dynamic>>
          postSnapshot =
          await transaction.get(
            postRef,
          );

          final DocumentSnapshot<Map<String, dynamic>>
          viewSnapshot =
          await transaction.get(
            viewRef,
          );

          if (!postSnapshot.exists ||
              viewSnapshot.exists) {
            return;
          }

          final Map<String, dynamic> data =
              postSnapshot.data() ??
                  <String, dynamic>{};

          final int currentViews =
          _toInt(
            data['viewCount'],
          );

          transaction.update(
            postRef,
            <String, dynamic>{
              'viewCount':
              currentViews + 1,
            },
          );

          transaction.set(
            viewRef,
            <String, dynamic>{
              'uid':
              user.uid,
              'viewedAt':
              FieldValue.serverTimestamp(),
            },
          );

          added = true;
        },
      );

      if (!mounted ||
          !added) {
        return;
      }

      setState(() {
        _viewCount++;
      });
    } catch (error) {
      _viewRecorded = false;

      debugPrint(
        'Error recording view: $error',
      );
    }
  }

  //===================================================
  // SAVED STATUS
  //===================================================

  Future<void> _loadSavedStatus() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('savedPosts')
          .doc(widget.post.postId)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaved =
            snapshot.exists;
      });
    } catch (error) {
      debugPrint(
        'Load saved status error: $error',
      );
    }
  }

  //===================================================
  // SAVE / UNSAVE
  //===================================================

  Future<void> _toggleSave() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in to save posts.',
      );

      return;
    }

    final DocumentReference<Map<String, dynamic>>
    ref =
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedPosts')
        .doc(widget.post.postId);

    try {
      if (_isSaved) {
        await ref.delete();

        if (!mounted) {
          return;
        }

        setState(() {
          _isSaved = false;
        });

        _showMessage(
          'Post unsaved.',
        );
      } else {
        await ref.set(
          <String, dynamic>{
            'postId':
            widget.post.postId,
            'savedAt':
            FieldValue.serverTimestamp(),
          },
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _isSaved = true;
        });

        _showMessage(
          'Post saved.',
        );
      }
    } catch (error) {
      debugPrint(
        'Save post error: $error',
      );

      _showMessage(
        'Unable to update saved post.',
      );
    }
  }

  //===================================================
  // HIDE POST
  //===================================================

  Future<void> _hidePost() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in first.',
      );

      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('hiddenPosts')
          .doc(widget.post.postId)
          .set(
        <String, dynamic>{
          'postId':
          widget.post.postId,
          'hiddenAt':
          FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleted = true;
      });

      _showMessage(
        'Post hidden.',
      );
    } catch (error) {
      debugPrint(
        'Hide post error: $error',
      );

      _showMessage(
        'Unable to hide post.',
      );
    }
  }

  //===================================================
  // COPY POST LINK
  //===================================================

  Future<void> _copyPostLink() async {
    final String link =
        'https://nubify.app/post/${widget.post.postId}';

    await Clipboard.setData(
      ClipboardData(
        text: link,
      ),
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      'Post link copied.',
    );
  }

  //===================================================
  // SHARE POST
  //===================================================

  Future<void> _sharePost() async {
    final String postLink =
        'https://nubify.app/post/${widget.post.postId}';

    final String shareText =
    <String>[
      if (_caption.trim().isNotEmpty)
        _caption.trim(),
      'View this post by @${widget.post.username}:',
      postLink,
    ].join(
      '\n\n',
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
          shareText,
          title:
          'Share post',
          subject:
          'Post from Nubify',
        ),
      );

      try {
        await _firestore
            .collection('posts')
            .doc(widget.post.postId)
            .update(
          <String, dynamic>{
            'shareCount':
            FieldValue.increment(1),
          },
        );
      } catch (_) {}
    } catch (error) {
      debugPrint(
        'Share post error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to share this post.',
        );
      }
    }
  }

  //===================================================
  // SHARE OPTIONS
  //===================================================

  void _showShareOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                height: 6,
              ),

              const Text(
                'Share',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.share_outlined,
                ),
                title:
                const Text(
                  'Share to other apps',
                ),
                subtitle:
                const Text(
                  'WhatsApp, Instagram, Telegram and more',
                ),
                onTap: () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _sharePost();
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons
                      .add_to_photos_outlined,
                ),
                title:
                const Text(
                  'Share to Story',
                ),
                onTap: () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _sharePost();
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.send_outlined,
                ),
                title:
                const Text(
                  'Send to chat',
                ),
                onTap: () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _sharePost();
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.link,
                ),
                title:
                const Text(
                  'Copy Link',
                ),
                onTap: () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _copyPostLink();
                },
              ),

              const SizedBox(
                height: 8,
              ),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // REPOST OPTIONS
  //===================================================

  void _showRepostOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                height: 6,
              ),

              const Text(
                'Repost',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.repeat,
                ),
                title:
                const Text(
                  'Repost',
                ),
                subtitle:
                const Text(
                  'Share without adding anything',
                ),
                onTap: () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _repostOnly();
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons.format_quote,
                ),
                title:
                const Text(
                  'Quote Repost',
                ),
                subtitle:
                const Text(
                  'Repost and add your own message',
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _quoteRepost();
                },
              ),

              const SizedBox(
                height: 10,
              ),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // REPOST
  //===================================================

  Future<void> _repostOnly() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in to repost.',
      );

      return;
    }

    try {
      await _repostService.repost(
        widget.post.postId,
      );

      if (mounted) {
        _showMessage(
          'Reposted.',
        );
      }
    } catch (error) {
      debugPrint(
        'Repost error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to repost.',
        );
      }
    }
  }

  //===================================================
  // QUOTE REPOST
  //===================================================

  Future<void> _quoteRepost() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in to repost.',
      );

      return;
    }

    String text = '';

    final String? result =
    await showDialog<String>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Quote Repost',
          ),
          content:
          TextField(
            autofocus: true,
            maxLines: 5,
            maxLength: 5000,
            onChanged: (
                String value,
                ) {
              text = value;
            },
            decoration:
            const InputDecoration(
              hintText:
              'Add your message...',
              border:
              OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  text.trim(),
                );
              },
              child:
              const Text(
                'Repost',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        result == null) {
      return;
    }

    try {
      await _repostService.quoteRepost(
        originalPostId:
        widget.post.postId,
        text:
        result,
      );

      if (mounted) {
        _showMessage(
          'Quote reposted.',
        );
      }
    } catch (error) {
      debugPrint(
        'Quote repost error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to quote repost.',
        );
      }
    }
  }

  //===================================================
  // EDIT POST
  //===================================================

  Future<void> _editPost() async {
    final User? user =
        _auth.currentUser;

    if (user == null ||
        user.uid != widget.post.uid) {
      _showMessage(
        'Only the owner can edit this post.',
      );

      return;
    }

    String editedCaption =
        _caption;

    final String? newCaption =
    await showDialog<String>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Edit Post',
          ),
          content:
          TextFormField(
            initialValue:
            _caption,
            maxLines: 6,
            maxLength: 5000,
            autofocus: true,
            onChanged: (
                String value,
                ) {
              editedCaption =
                  value;
            },
            decoration:
            const InputDecoration(
              hintText:
              'Write a caption...',
              border:
              OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  editedCaption.trim(),
                );
              },
              child:
              const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        newCaption == null) {
      return;
    }

    try {
      await _firestore
          .collection('posts')
          .doc(widget.post.postId)
          .update(
        <String, dynamic>{
          'caption':
          newCaption,
          'edited':
          true,
          'editedAt':
          FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _caption =
            newCaption;
      });

      _showMessage(
        'Post updated.',
      );
    } catch (error) {
      debugPrint(
        'Edit post error: $error',
      );

      _showMessage(
        'Unable to edit this post.',
      );
    }
  }

  //===================================================
  // DELETE POST
  //===================================================

  Future<void> _deletePost() async {
    final User? user =
        _auth.currentUser;

    if (user == null ||
        user.uid != widget.post.uid) {
      _showMessage(
        'Only the owner can delete this post.',
      );

      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Delete Post?',
          ),
          content:
          const Text(
            'This post will be permanently deleted. This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
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
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },
              child:
              const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('posts')
          .doc(widget.post.postId)
          .delete();

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleted = true;
      });

      _showMessage(
        'Post deleted.',
      );
    } catch (error) {
      debugPrint(
        'Delete post error: $error',
      );

      _showMessage(
        'Unable to delete this post.',
      );
    }
  }

  //===================================================
  // REPORT POST
  //===================================================

  Future<void> _reportPost() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in to report a post.',
      );

      return;
    }

    if (user.uid ==
        widget.post.uid) {
      _showMessage(
        'You cannot report your own post.',
      );

      return;
    }

    const List<String> reasons =
    <String>[
      'Spam',
      'Harassment or bullying',
      'Hate or abusive content',
      'Violence or dangerous content',
      'Sexual content',
      'False or misleading information',
      'Scam or fraud',
      'Other',
    ];

    final String? reason =
    await showDialog<String>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Report Post',
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
                height: 1,
              ),
              itemBuilder:
                  (
                  BuildContext context,
                  int index,
                  ) {
                return ListTile(
                  title:
                  Text(
                    reasons[index],
                  ),
                  onTap: () {
                    Navigator.of(
                      dialogContext,
                    ).pop(
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

    if (!mounted ||
        reason == null) {
      return;
    }

    try {
      await _firestore
          .collection('reports')
          .add(
        <String, dynamic>{
          'postId':
          widget.post.postId,
          'reportedPostOwnerId':
          widget.post.uid,
          'reportedBy':
          user.uid,
          'reason':
          reason,
          'createdAt':
          FieldValue.serverTimestamp(),
          'type':
          'post',
          'status':
          'pending',
        },
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Report submitted. Thank you.',
      );
    } catch (error) {
      debugPrint(
        'Report post error: $error',
      );

      _showMessage(
        'Unable to submit report.',
      );
    }
  }

  //===================================================
  // BLOCK USER
  //===================================================

  Future<void> _blockUser() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in first.',
      );

      return;
    }

    if (user.uid ==
        widget.post.uid) {
      _showMessage(
        'You cannot block yourself.',
      );

      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Block User?',
          ),
          content:
          Text(
            'You will no longer see posts from @${widget.post.username}.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
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
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
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

    if (!mounted ||
        confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blockedUsers')
          .doc(widget.post.uid)
          .set(
        <String, dynamic>{
          'uid':
          widget.post.uid,
          'blockedAt':
          FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleted = true;
      });

      _showMessage(
        'User blocked.',
      );
    } catch (error) {
      debugPrint(
        'Block user error: $error',
      );

      _showMessage(
        'Unable to block user.',
      );
    }
  }

  //===================================================
  // PIN / UNPIN POST TO PROFILE
  //
  // MAXIMUM = 3
  //===================================================

  Future<void> _togglePinOnProfile() async {
    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null ||
        !widget.isProfileScreen ||
        currentUser.uid !=
            widget.post.uid ||
        widget.post.isRepost) {
      return;
    }

    final DocumentReference<Map<String, dynamic>>
    userRef =
    _firestore
        .collection('users')
        .doc(currentUser.uid);

    try {
      final bool pinned =
      await _firestore
          .runTransaction<bool>(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<Map<String, dynamic>>
          userSnapshot =
          await transaction.get(
            userRef,
          );

          final List<String> pinnedPostIds =
          List<String>.from(
            userSnapshot.data()?[
            'pinnedPostIds'] ??
                <String>[],
          );

          final bool alreadyPinned =
          pinnedPostIds.contains(
            widget.post.postId,
          );

          if (alreadyPinned) {
            pinnedPostIds.remove(
              widget.post.postId,
            );
          } else {
            if (pinnedPostIds.length >=
                3) {
              throw Exception(
                'You can pin only 3 posts to your profile.',
              );
            }

            pinnedPostIds.insert(
              0,
              widget.post.postId,
            );
          }

          transaction.set(
            userRef,
            <String, dynamic>{
              'pinnedPostIds':
              pinnedPostIds,
            },
            SetOptions(
              merge: true,
            ),
          );

          return !alreadyPinned;
        },
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        pinned
            ? 'Post pinned to profile.'
            : 'Post unpinned from profile.',
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
    }
  }

  //===================================================
  // POST MENU
  //===================================================

  void _showPostMenu() {
    final User? currentUser =
        _auth.currentUser;

    final bool isOwner =
        currentUser != null &&
            widget.post.uid ==
                currentUser.uid;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (
          BuildContext sheetContext,
          ) {
        Future<void> closeThen(
            Future<void> Function() action,
            ) async {
          Navigator.of(
            sheetContext,
          ).pop();

          await Future<void>.delayed(
            const Duration(
              milliseconds: 250,
            ),
          );

          if (!mounted) {
            return;
          }

          await action();
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading:
                  Icon(
                    _isSaved
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                  title:
                  Text(
                    _isSaved
                        ? 'Unsave Post'
                        : 'Save Post',
                  ),
                  onTap: () {
                    closeThen(
                      _toggleSave,
                    );
                  },
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.share_outlined,
                  ),
                  title:
                  const Text(
                    'Share',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    Future<void>.delayed(
                      const Duration(
                        milliseconds: 200,
                      ),
                          () {
                        if (mounted) {
                          _showShareOptions();
                        }
                      },
                    );
                  },
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.link,
                  ),
                  title:
                  const Text(
                    'Copy Link',
                  ),
                  onTap: () {
                    closeThen(
                      _copyPostLink,
                    );
                  },
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons
                        .visibility_off_outlined,
                  ),
                  title:
                  const Text(
                    'Hide Post',
                  ),
                  onTap: () {
                    closeThen(
                      _hidePost,
                    );
                  },
                ),

                if (!isOwner)
                  ListTile(
                    leading:
                    const Icon(
                      Icons.flag_outlined,
                    ),
                    title:
                    const Text(
                      'Report',
                    ),
                    onTap: () {
                      closeThen(
                        _reportPost,
                      );
                    },
                  ),

                if (!isOwner)
                  ListTile(
                    leading:
                    const Icon(
                      Icons.block_outlined,
                    ),
                    title:
                    const Text(
                      'Block User',
                    ),
                    onTap: () {
                      closeThen(
                        _blockUser,
                      );
                    },
                  ),

                if (isOwner) ...<Widget>[
                  const Divider(),

                  //===================================================
                  // PIN TO PROFILE
                  //===================================================

                  if (widget.isProfileScreen &&
                      !widget.post.isRepost)
                    ListTile(
                      leading:
                      Icon(
                        widget.isPinnedToProfile
                            ? Icons.push_pin
                            : Icons
                            .push_pin_outlined,
                        color:
                        widget.isPinnedToProfile
                            ? const Color(
                          0xFF29B6F6,
                        )
                            : null,
                      ),
                      title:
                      Text(
                        widget.isPinnedToProfile
                            ? 'Unpin Post from Profile'
                            : 'Pin Post to Profile',
                      ),
                      subtitle:
                      const Text(
                        'You can pin up to 3 posts.',
                      ),
                      onTap: () {
                        closeThen(
                          _togglePinOnProfile,
                        );
                      },
                    ),

                  ListTile(
                    leading:
                    const Icon(
                      Icons.edit_outlined,
                    ),
                    title:
                    const Text(
                      'Edit Post',
                    ),
                    onTap: () {
                      closeThen(
                        _editPost,
                      );
                    },
                  ),

                  ListTile(
                    leading:
                    const Icon(
                      Icons.delete_outline,
                      color:
                      Colors.red,
                    ),
                    title:
                    const Text(
                      'Delete Post',
                      style: TextStyle(
                        color:
                        Colors.red,
                      ),
                    ),
                    onTap: () {
                      closeThen(
                        _deletePost,
                      );
                    },
                  ),
                ],

                const SizedBox(
                  height: 12,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //===================================================
  // LOAD POLL
  //===================================================

  Future<void> _loadPoll() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection('posts')
          .doc(widget.post.postId)
          .get();

      if (!snapshot.exists) {
        if (!mounted) {
          return;
        }

        setState(() {
          _pollLoading = false;
        });

        return;
      }

      final Map<String, dynamic> data =
          snapshot.data() ??
              <String, dynamic>{};

      final bool hasPoll =
          data['hasPoll'] == true &&
              data['poll'] != null;

      if (!hasPoll) {
        if (!mounted) {
          return;
        }

        setState(() {
          _hasPoll = false;

          _pollLoading = false;
        });

        return;
      }

      final Map<String, dynamic> poll =
      Map<String, dynamic>.from(
        data['poll'] as Map,
      );

      final String question =
      (poll['question'] ?? '')
          .toString();

      final List<dynamic> rawOptions =
      List<dynamic>.from(
        poll['options'] ??
            <dynamic>[],
      );

      final List<Map<String, dynamic>>
      options =
      rawOptions.map(
            (
            dynamic raw,
            ) {
          final Map<String, dynamic> item =
          Map<String, dynamic>.from(
            raw as Map,
          );

          return <String, dynamic>{
            'text':
            (item['text'] ?? '')
                .toString(),
            'votes':
            _toInt(
              item['votes'],
            ),
          };
        },
      ).toList();

      int totalVotes =
      _toInt(
        poll['totalVotes'],
      );

      final int calculatedVotes =
      options.fold<int>(
        0,
            (
            int total,
            Map<String, dynamic> option,
            ) {
          return total +
              _toInt(
                option['votes'],
              );
        },
      );

      if (totalVotes !=
          calculatedVotes) {
        totalVotes =
            calculatedVotes;
      }

      DateTime? expiresAt =
      _dateFromDynamic(
        poll['expiresAt'],
      );

      if (expiresAt == null) {
        final DateTime? createdAt =
        _dateFromDynamic(
          poll['createdAt'],
        );

        if (createdAt != null) {
          expiresAt =
              createdAt.add(
                const Duration(
                  hours: 24,
                ),
              );
        }
      }

      bool pollClosed =
          poll['isClosed'] ==
              true;

      int? winnerIndex =
      _nullableInt(
        poll['winnerOptionIndex'],
      );

      DateTime? closedAt =
      _dateFromDynamic(
        poll['closedAt'],
      );

      if (!pollClosed &&
          expiresAt != null &&
          !DateTime.now().isBefore(
            expiresAt,
          )) {
        final PollResult result =
        _calculateWinner(
          options,
        );

        pollClosed = true;

        winnerIndex =
            result.winnerIndex;

        closedAt =
            DateTime.now();

        await _closePollInFirestore(
          winnerIndex:
          winnerIndex,
          closedAt:
          closedAt,
        );
      }

      final User? currentUser =
          _auth.currentUser;

      final List<dynamic> voterIds =
      List<dynamic>.from(
        poll['votedUserIds'] ??
            <dynamic>[],
      );

      bool hasVoted = false;

      String? selectedOption;

      if (currentUser != null) {
        for (final dynamic voter
        in voterIds) {
          if (voter is Map) {
            final String voterUid =
            (voter['uid'] ?? '')
                .toString();

            if (voterUid ==
                currentUser.uid) {
              hasVoted = true;

              selectedOption =
                  voter['optionIndex']
                      ?.toString();

              break;
            }
          } else if (voter.toString() ==
              currentUser.uid) {
            hasVoted = true;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPoll = true;

        _pollQuestion =
            question;

        _pollOptions =
            options;

        _pollTotalVotes =
            totalVotes;

        _pollExpiresAt =
            expiresAt;

        _pollClosed =
            pollClosed;

        _winnerOptionIndex =
            winnerIndex;

        _pollClosedAt =
            closedAt;

        _hasVoted =
            hasVoted;

        _selectedPollOption =
            selectedOption;

        _pollLoading = false;
      });
    } catch (error) {
      debugPrint(
        'Error loading poll: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pollLoading = false;
      });
    }
  }

  //===================================================
  // POLL DATE HELPERS
  //===================================================

  DateTime? _dateFromDynamic(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }

  int? _nullableInt(
      dynamic value,
      ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
    );
  }

  //===================================================
  // CLOSE POLL
  //===================================================

  Future<void> _closePollInFirestore({
    required int? winnerIndex,
    required DateTime closedAt,
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>>
      postRef =
      _firestore
          .collection('posts')
          .doc(widget.post.postId);

      await _firestore.runTransaction(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<Map<String, dynamic>>
          snapshot =
          await transaction.get(
            postRef,
          );

          if (!snapshot.exists ||
              snapshot.data() == null) {
            return;
          }

          final Map<String, dynamic> data =
          snapshot.data()!;

          if (data['poll'] == null) {
            return;
          }

          final Map<String, dynamic> poll =
          Map<String, dynamic>.from(
            data['poll'] as Map,
          );

          if (poll['isClosed'] ==
              true) {
            return;
          }

          poll['isClosed'] =
          true;

          poll['winnerOptionIndex'] =
              winnerIndex;

          poll['closedAt'] =
              Timestamp.fromDate(
                closedAt,
              );

          transaction.update(
            postRef,
            <String, dynamic>{
              'poll':
              poll,
            },
          );
        },
      );
    } catch (error) {
      debugPrint(
        'Error closing poll: $error',
      );
    }
  }

  //===================================================
  // POLL EXPIRED
  //===================================================

  bool get _isPollExpired {
    final DateTime? expiresAt =
        _pollExpiresAt;

    if (expiresAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(
      expiresAt,
    );
  }

  //===================================================
  // VOTE POLL
  //===================================================

  Future<void> _votePoll(
      int optionIndex,
      ) async {
    if (_isVoting ||
        _hasVoted ||
        _pollClosed ||
        _isPollExpired) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in to vote.',
      );

      return;
    }

    if (optionIndex < 0 ||
        optionIndex >=
            _pollOptions.length) {
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>>
      postRef =
      _firestore
          .collection('posts')
          .doc(widget.post.postId);

      await _firestore.runTransaction(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<Map<String, dynamic>>
          snapshot =
          await transaction.get(
            postRef,
          );

          if (!snapshot.exists ||
              snapshot.data() == null) {
            throw Exception(
              'Post no longer exists.',
            );
          }

          final Map<String, dynamic> data =
          snapshot.data()!;

          if (data['poll'] == null) {
            throw Exception(
              'Poll no longer exists.',
            );
          }

          final Map<String, dynamic> poll =
          Map<String, dynamic>.from(
            data['poll'] as Map,
          );

          DateTime? expiresAt =
          _dateFromDynamic(
            poll['expiresAt'],
          );

          if (expiresAt != null &&
              !DateTime.now().isBefore(
                expiresAt,
              )) {
            throw Exception(
              'Voting has ended.',
            );
          }

          if (poll['isClosed'] ==
              true) {
            throw Exception(
              'Voting has ended.',
            );
          }

          final List<dynamic> rawOptions =
          List<dynamic>.from(
            poll['options'] ??
                <dynamic>[],
          );

          final List<Map<String, dynamic>>
          updatedOptions =
          rawOptions.map(
                (
                dynamic option,
                ) {
              return Map<String, dynamic>.from(
                option as Map,
              );
            },
          ).toList();

          if (optionIndex >=
              updatedOptions.length) {
            throw Exception(
              'Invalid poll option.',
            );
          }

          final List<dynamic> voterIds =
          List<dynamic>.from(
            poll['votedUserIds'] ??
                <dynamic>[],
          );

          for (final dynamic voter
          in voterIds) {
            if (voter is Map &&
                (voter['uid'] ?? '')
                    .toString() ==
                    user.uid) {
              throw Exception(
                'ALREADY_VOTED',
              );
            }

            if (voter is String &&
                voter ==
                    user.uid) {
              throw Exception(
                'ALREADY_VOTED',
              );
            }
          }

          final Map<String, dynamic>
          selectedOption =
          updatedOptions[
          optionIndex];

          final int currentVotes =
          _toInt(
            selectedOption['votes'],
          );

          selectedOption['votes'] =
              currentVotes + 1;

          voterIds.add(
            <String, dynamic>{
              'uid':
              user.uid,
              'optionIndex':
              optionIndex,
              'votedAt':
              Timestamp.now(),
            },
          );

          final int newTotal =
          updatedOptions.fold<int>(
            0,
                (
                int sum,
                Map<String, dynamic> option,
                ) {
              return sum +
                  _toInt(
                    option['votes'],
                  );
            },
          );

          poll['options'] =
              updatedOptions;

          poll['totalVotes'] =
              newTotal;

          poll['votedUserIds'] =
              voterIds;

          transaction.update(
            postRef,
            <String, dynamic>{
              'poll':
              poll,
            },
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final List<Map<String, dynamic>>
        newOptions =
        _pollOptions.map(
              (
              Map<String, dynamic> option,
              ) {
            return Map<String, dynamic>.from(
              option,
            );
          },
        ).toList();

        final int currentVotes =
        _toInt(
          newOptions[optionIndex]
          ['votes'],
        );

        newOptions[optionIndex]
        ['votes'] =
            currentVotes + 1;

        _pollOptions =
            newOptions;

        _selectedPollOption =
            optionIndex.toString();

        _hasVoted = true;

        _pollTotalVotes =
            newOptions.fold<int>(
              0,
                  (
                  int total,
                  Map<String, dynamic> option,
                  ) {
                return total +
                    _toInt(
                      option['votes'],
                    );
              },
            );
      });

      _showMessage(
        'Vote submitted successfully.',
      );
    } catch (error) {
      debugPrint(
        'Poll vote error: $error',
      );

      if (!mounted) {
        return;
      }

      final String message =
      error.toString();

      if (message.contains(
        'ALREADY_VOTED',
      )) {
        await _loadPoll();

        if (mounted) {
          _showMessage(
            'You have already voted. Your vote cannot be changed.',
          );
        }
      } else if (message.contains(
        'Voting has ended',
      )) {
        await _loadPoll();

        if (mounted) {
          _showMessage(
            'Voting has ended.',
          );
        }
      } else {
        _showMessage(
          'Unable to submit your vote.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  //===================================================
  // CALCULATE WINNER
  //===================================================

  PollResult _calculateWinner(
      List<Map<String, dynamic>> options,
      ) {
    if (options.isEmpty) {
      return const PollResult(
        winnerIndex: null,
        isTie: false,
      );
    }

    int highestVotes = -1;

    final List<int> winners =
    <int>[];

    for (int index = 0;
    index < options.length;
    index++) {
      final int votes =
      _toInt(
        options[index]['votes'],
      );

      if (votes >
          highestVotes) {
        highestVotes =
            votes;

        winners
          ..clear()
          ..add(
            index,
          );
      } else if (votes ==
          highestVotes) {
        winners.add(
          index,
        );
      }
    }

    if (highestVotes <= 0) {
      return const PollResult(
        winnerIndex: null,
        isTie: false,
      );
    }

    return PollResult(
      winnerIndex:
      winners.first,
      isTie:
      winners.length > 1,
    );
  }

  //===================================================
  // POLL PERCENTAGE
  //===================================================

  double _getPollPercentage(
      int votes,
      ) {
    if (_pollTotalVotes <= 0) {
      return 0;
    }

    return (votes /
        _pollTotalVotes)
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();
  }

  int _getPollPercentageNumber(
      int votes,
      ) {
    return (_getPollPercentage(
      votes,
    ) *
        100)
        .round();
  }

  //===================================================
  // POLL TIME
  //===================================================

  String _pollTimeText() {
    if (_pollExpiresAt ==
        null) {
      return '';
    }

    if (_isPollExpired ||
        _pollClosed) {
      return 'Voting closed';
    }

    final Duration remaining =
    _pollExpiresAt!.difference(
      DateTime.now(),
    );

    if (remaining.isNegative) {
      return 'Voting closed';
    }

    final int hours =
        remaining.inHours;

    final int minutes =
        remaining.inMinutes %
            60;

    if (hours > 0) {
      return '$hours h $minutes min left';
    }

    return '$minutes min left';
  }

  //===================================================
  // WINNER TEXT
  //===================================================

  Widget _buildWinnerText() {
    if (!_pollClosed ||
        _pollOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final PollResult result =
    _calculateWinner(
      _pollOptions,
    );

    if (result.winnerIndex ==
        null) {
      return const Padding(
        padding:
        EdgeInsets.only(
          top: 8,
        ),
        child: Text(
          'Poll ended with no votes.',
          style: TextStyle(
            fontWeight:
            FontWeight.w600,
          ),
        ),
      );
    }

    if (result.isTie) {
      return const Padding(
        padding:
        EdgeInsets.only(
          top: 8,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons
                  .emoji_events_outlined,
              size: 18,
            ),
            SizedBox(
              width: 6,
            ),
            Text(
              'Poll ended in a tie',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final int index =
    result.winnerIndex!;

    if (index < 0 ||
        index >=
            _pollOptions.length) {
      return const SizedBox.shrink();
    }

    final String winner =
    (_pollOptions[index]
    ['text'] ??
        '')
        .toString();

    final int percentage =
    _getPollPercentageNumber(
      _toInt(
        _pollOptions[index]
        ['votes'],
      ),
    );

    return Padding(
      padding:
      const EdgeInsets.only(
        top: 8,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.emoji_events,
            color:
            Colors.amber,
            size: 19,
          ),

          const SizedBox(
            width: 6,
          ),

          Expanded(
            child: Text(
              'Winner: $winner $percentage%',
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // POLL UI
  //===================================================

  Widget _buildPoll() {
    if (_pollLoading) {
      return const Padding(
        padding:
        EdgeInsets.all(
          16,
        ),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (!_hasPoll) {
      return const SizedBox.shrink();
    }

    final bool showResults =
        _hasVoted ||
            _pollClosed;

    return Container(
      width:
      double.infinity,
      margin:
      const EdgeInsets.only(
        top: 8,
        bottom: 12,
      ),
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        border:
        Border.all(
          color:
          Colors.grey.shade700,
        ),
        borderRadius:
        BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                const EdgeInsets.all(
                  7,
                ),
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFF29B6F6,
                  ).withOpacity(
                    0.15,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    8,
                  ),
                ),
                child:
                const Icon(
                  Icons.poll_outlined,
                  color:
                  Color(
                    0xFF29B6F6,
                  ),
                  size: 20,
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              const Text(
                'Poll',
                style:
                TextStyle(
                  fontSize: 17,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const Spacer(),

              if (!_pollClosed &&
                  _pollExpiresAt !=
                      null)
                Text(
                  _pollTimeText(),
                  style:
                  TextStyle(
                    color:
                    Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            _pollQuestion,
            style:
            const TextStyle(
              fontSize: 17,
              fontWeight:
              FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          ...List<Widget>.generate(
            _pollOptions.length,
                (
                int index,
                ) {
              final Map<String, dynamic>
              option =
              _pollOptions[index];

              final String text =
              (option['text'] ?? '')
                  .toString();

              final int votes =
              _toInt(
                option['votes'],
              );

              final double percentage =
              _getPollPercentage(
                votes,
              );

              final int percentageNumber =
              _getPollPercentageNumber(
                votes,
              );

              final bool selected =
                  _selectedPollOption ==
                      index.toString();

              final bool winner =
                  _pollClosed &&
                      _winnerOptionIndex ==
                          index;

              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 9,
                ),
                child: InkWell(
                  onTap:
                  _pollClosed ||
                      _hasVoted ||
                      _isVoting
                      ? null
                      : () {
                    _votePoll(
                      index,
                    );
                  },
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  child: Container(
                    height: 56,
                    clipBehavior:
                    Clip.antiAlias,
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.grey.shade900,
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                      border:
                      Border.all(
                        color:
                        selected
                            ? const Color(
                          0xFF29B6F6,
                        )
                            : Colors
                            .grey
                            .shade700,
                        width:
                        selected
                            ? 1.5
                            : 1,
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        if (showResults)
                          FractionallySizedBox(
                            alignment:
                            Alignment.centerLeft,
                            widthFactor:
                            percentage,
                            child: Container(
                              color:
                              const Color(
                                0xFF29B6F6,
                              ).withOpacity(
                                selected
                                    ? 0.35
                                    : 0.18,
                              ),
                            ),
                          ),

                        Padding(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          child: Row(
                            children: <Widget>[
                              if (selected)
                                const Padding(
                                  padding:
                                  EdgeInsets.only(
                                    right: 7,
                                  ),
                                  child: Icon(
                                    Icons
                                        .check_circle,
                                    color:
                                    Color(
                                      0xFF29B6F6,
                                    ),
                                    size: 20,
                                  ),
                                ),

                              if (winner)
                                const Padding(
                                  padding:
                                  EdgeInsets.only(
                                    right: 7,
                                  ),
                                  child: Icon(
                                    Icons
                                        .emoji_events,
                                    color:
                                    Colors.amber,
                                    size: 20,
                                  ),
                                ),

                              Expanded(
                                child: Text(
                                  text,
                                  maxLines: 2,
                                  overflow:
                                  TextOverflow.ellipsis,
                                  style:
                                  const TextStyle(
                                    color:
                                    Colors.white,
                                    fontSize: 15,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ),

                              if (showResults)
                                Text(
                                  '$percentageNumber%',
                                  style:
                                  const TextStyle(
                                    color:
                                    Colors.white,
                                    fontSize: 14,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
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
          ),

          Text(
            '$_pollTotalVotes ${_pollTotalVotes == 1 ? 'vote' : 'votes'}',
            style:
            TextStyle(
              color:
              Colors.grey.shade500,
              fontSize: 13,
            ),
          ),

          if (!_hasVoted &&
              !_pollClosed &&
              !_isVoting)
            Padding(
              padding:
              const EdgeInsets.only(
                top: 5,
              ),
              child: Text(
                'Tap an option to vote',
                style:
                TextStyle(
                  color:
                  Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),

          if (_hasVoted)
            Padding(
              padding:
              const EdgeInsets.only(
                top: 5,
              ),
              child: Text(
                'You have already voted. Your vote cannot be changed.',
                style:
                TextStyle(
                  color:
                  Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),

          _buildWinnerText(),
        ],
      ),
    );
  }

  //===================================================
  // HEADER
  //===================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: <Widget>[
        //===================================================
        // AVATAR -> PROFILE
        //===================================================

        GestureDetector(
          behavior:
          HitTestBehavior.opaque,
          onTap:
          _openAuthorProfile,
          child: CircleAvatar(
            radius: 24,
            backgroundImage:
            widget.post.photoUrl
                .isNotEmpty
                ? NetworkImage(
              widget.post.photoUrl,
            )
                : null,
            child:
            widget.post.photoUrl
                .isEmpty
                ? const Icon(
              Icons.person,
            )
                : null,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        //===================================================
        // NAME -> PROFILE
        //===================================================

        Expanded(
          child: GestureDetector(
            behavior:
            HitTestBehavior.opaque,
            onTap:
            _openAuthorProfile,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.post.fullName
                      .isNotEmpty
                      ? widget.post.fullName
                      : widget.post.username,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  '@${widget.post.username}',
                  style:
                  TextStyle(
                    color:
                    Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),

                if (widget.post.createdAt !=
                    null)
                  NubifyTimeText.fromTimestamp(
                    timestamp:
                    widget.post.createdAt,
                    style:
                    TextStyle(
                      color:
                      Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),

        IconButton(
          onPressed:
          _showPostMenu,
          icon:
          const Icon(
            Icons.more_vert,
          ),
        ),
      ],
    );
  }

  //===================================================
  // CAPTION
  //===================================================

  Widget _buildCaption() {
    if (_caption.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
      const EdgeInsets.only(
        top: 12,
        bottom: 10,
      ),
      child: Text(
        _caption,
        style:
        const TextStyle(
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }

  //===================================================
  // ACTIONS
  //===================================================

  Widget _buildActions() {
    return Row(
      children: <Widget>[
        InkWell(
          onTap:
          _toggleLike,
          borderRadius:
          BorderRadius.circular(
            30,
          ),
          child: Padding(
            padding:
            const EdgeInsets.all(
              8,
            ),
            child: Row(
              children: <Widget>[
                _isLikeLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : Icon(
                  _isLiked
                      ? Icons.favorite
                      : Icons
                      .favorite_border,
                  color:
                  _isLiked
                      ? const Color(
                    0xFF29B6F6,
                  )
                      : null,
                ),

                const SizedBox(
                  width: 5,
                ),

                Text(
                  '$_likeCount',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        InkWell(
          onTap: () {
            if (widget.inCommentsScreen) {
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (
                    BuildContext context,
                    ) {
                  return CommentsScreen(
                    postId:
                    widget.post.postId,
                  );
                },
              ),
            );
          },
          borderRadius:
          BorderRadius.circular(
            30,
          ),
          child: Padding(
            padding:
            const EdgeInsets.all(
              8,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons
                      .chat_bubble_outline,
                ),

                const SizedBox(
                  width: 5,
                ),

                Text(
                  '${widget.post.commentCount}',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        InkWell(
          onTap:
          _showRepostOptions,
          borderRadius:
          BorderRadius.circular(
            30,
          ),
          child: Padding(
            padding:
            const EdgeInsets.all(
              8,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.repeat,
                ),

                const SizedBox(
                  width: 5,
                ),

                Text(
                  '${widget.post.repostCount}',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(
          width: 4,
        ),

        InkWell(
          onTap:
          _showShareOptions,
          borderRadius:
          BorderRadius.circular(
            30,
          ),
          child:
          const Padding(
            padding:
            EdgeInsets.all(
              8,
            ),
            child: Icon(
              Icons.near_me_outlined,
              size: 27,
            ),
          ),
        ),
      ],
    );
  }

  //===================================================
  // VIEWS
  //===================================================

  Widget _buildViews() {
    return Padding(
      padding:
      const EdgeInsets.only(
        left: 8,
        bottom: 4,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.visibility_outlined,
            size: 16,
            color:
            Colors.grey.shade600,
          ),

          const SizedBox(
            width: 4,
          ),

          Text(
            '$_viewCount ${_viewCount == 1 ? 'view' : 'views'}',
            style:
            TextStyle(
              color:
              Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // TO INT
  //===================================================

  int _toInt(
      dynamic value,
      ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
    ) ??
        0;
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
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_isDeleted) {
      return const SizedBox.shrink();
    }

    final bool hasMedia =
        widget.post.media.isNotEmpty;

    return GestureDetector(
      onDoubleTap:
      hasMedia
          ? _doubleTapLike
          : null,
      child: Container(
        width:
        double.infinity,
        color:
        Theme.of(context)
            .scaffoldBackgroundColor,
        padding:
        const EdgeInsets.only(
          top: 12,
          bottom: 4,
        ),
        child: Stack(
          alignment:
          Alignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  child:
                  _buildHeader(),
                ),

                Padding(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  child:
                  _buildCaption(),
                ),

                Padding(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  child:
                  _buildPoll(),
                ),

                if (hasMedia)
                  SizedBox(
                    width:
                    double.infinity,
                    height:
                    430,
                    child:
                    PostMediaCarousel(
                      media:
                      widget.post.media,
                    ),
                  ),

                Padding(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child:
                  _buildActions(),
                ),

                _buildViews(),

                const Divider(
                  height: 1,
                ),
              ],
            ),

            if (_showHeartAnimation)
              IgnorePointer(
                child:
                TweenAnimationBuilder<double>(
                  tween:
                  Tween<double>(
                    begin: 0.5,
                    end: 1.2,
                  ),
                  duration:
                  const Duration(
                    milliseconds: 450,
                  ),
                  builder: (
                      BuildContext context,
                      double scale,
                      Widget? child,
                      ) {
                    return Transform.scale(
                      scale:
                      scale,
                      child:
                      const Icon(
                        Icons.favorite,
                        color:
                        Color(
                          0xFF29B6F6,
                        ),
                        size: 110,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// POLL RESULT
//===================================================

class PollResult {
  final int? winnerIndex;

  final bool isTie;

  const PollResult({
    required this.winnerIndex,
    required this.isTie,
  });
}
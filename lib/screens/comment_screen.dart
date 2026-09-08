import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/comment_service.dart';
import '../utils/nubify_time.dart';
import '../widgets/post_card.dart';

//===================================================
// COMMENTS SCREEN
//===================================================

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({
    super.key,
    required this.postId,
  });

  @override
  State<CommentsScreen> createState() =>
      _CommentsScreenState();
}

//===================================================
// COMMENTS STATE
//===================================================

class _CommentsScreenState
    extends State<CommentsScreen> {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===================================================
  // COMMENT SERVICE
  //===================================================

  final CommentService _commentService =
  CommentService();

  //===================================================
  // INPUT
  //===================================================

  final TextEditingController _commentController =
  TextEditingController();

  final FocusNode _commentFocusNode =
  FocusNode();

  //===================================================
  // REPLY STATE
  //===================================================

  String? _replyingToCommentId;
  String? _replyingToUsername;

  bool _isSending = false;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _repairOldComments();
  }

  //===================================================
  // REPAIR OLD COMMENT PROFILES
  //===================================================

  Future<void> _repairOldComments() async {
    try {
      await _commentService
          .repairMissingCommentProfiles(
        widget.postId,
      );
    } catch (error) {
      debugPrint(
        'Repair comments error: $error',
      );
    }
  }

  //===================================================
  // OPEN USER PROFILE
  //===================================================

  Future<void> _openUserProfile(
      String uid,
      ) async {
    final String cleanUid =
    uid.trim();

    if (cleanUid.isEmpty ||
        !mounted) {
      return;
    }

    await Navigator.of(context).pushNamed(
      '/profile',
      arguments:
      cleanUid,
    );
  }

  //===================================================
  // INT HELPER
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
  // SEND COMMENT / REPLY
  //===================================================

  Future<void> _sendComment() async {
    final String text =
    _commentController.text
        .trim();

    if (text.isEmpty ||
        _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      if (_replyingToCommentId !=
          null) {
        await _commentService.addReply(
          postId:
          widget.postId,
          commentId:
          _replyingToCommentId!,
          text:
          text,
        );
      } else {
        await _commentService.addComment(
          postId:
          widget.postId,
          text:
          text,
        );
      }

      if (!mounted) {
        return;
      }

      _commentController.clear();

      setState(() {
        _replyingToCommentId =
        null;

        _replyingToUsername =
        null;
      });

      FocusScope.of(context)
          .unfocus();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not send: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  //===================================================
  // START REPLY
  //===================================================

  void _startReply({
    required String commentId,
    required String username,
  }) {
    final String safeUsername =
    username.trim().isNotEmpty
        ? username.trim()
        : 'user';

    setState(() {
      _replyingToCommentId =
          commentId;

      _replyingToUsername =
          safeUsername;
    });

    _commentController.text =
    '@$safeUsername ';

    _commentController.selection =
        TextSelection.fromPosition(
          TextPosition(
            offset:
            _commentController
                .text
                .length,
          ),
        );

    _commentFocusNode.requestFocus();
  }

  //===================================================
  // CANCEL REPLY
  //===================================================

  void _cancelReply() {
    setState(() {
      _replyingToCommentId =
      null;

      _replyingToUsername =
      null;
    });

    _commentController.clear();

    FocusScope.of(context)
        .unfocus();
  }

  //===================================================
  // FIND COMMENT DOCUMENT
  //
  // SUPPORTS CURRENT NESTED COMMENTS AND OLD GLOBAL
  // COMMENT DOCUMENTS.
  //===================================================

  Future<DocumentReference<Map<String, dynamic>>>
  _resolveCommentReference(
      String commentId,
      ) async {
    final DocumentReference<
        Map<String, dynamic>>
    nestedReference =
    _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      nestedSnapshot =
      await nestedReference.get();

      if (nestedSnapshot.exists) {
        return nestedReference;
      }
    } catch (_) {}

    final DocumentReference<
        Map<String, dynamic>>
    globalReference =
    _firestore
        .collection('comments')
        .doc(commentId);

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      globalSnapshot =
      await globalReference.get();

      if (globalSnapshot.exists) {
        return globalReference;
      }
    } catch (_) {}

    return nestedReference;
  }

  //===================================================
  // EDIT COMMENT
  //===================================================

  Future<void> _editComment({
    required String commentId,
    required String currentText,
    required String ownerUid,
  }) async {
    final User? user =
        _auth.currentUser;

    if (user == null ||
        user.uid != ownerUid) {
      _showMessage(
        'You can only edit your own comment.',
      );

      return;
    }

    String editedText =
        currentText;

    final String? result =
    await showDialog<String>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Edit Comment',
          ),
          content: TextFormField(
            initialValue:
            currentText,
            autofocus:
            true,
            maxLines:
            5,
            maxLength:
            2000,
            onChanged: (
                String value,
                ) {
              editedText =
                  value;
            },
            decoration:
            const InputDecoration(
              hintText:
              'Edit your comment...',
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
                final String value =
                editedText.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
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
        result == null ||
        result.trim().isEmpty) {
      return;
    }

    try {
      final DocumentReference<
          Map<String, dynamic>>
      commentRef =
      await _resolveCommentReference(
        commentId,
      );

      await commentRef.update(
        <String, dynamic>{
          'text':
          result.trim(),
          'edited':
          true,
          'editedAt':
          FieldValue.serverTimestamp(),
        },
      );

      if (mounted) {
        _showMessage(
          'Comment updated.',
        );
      }
    } catch (error) {
      debugPrint(
        'Edit comment error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to edit comment.',
        );
      }
    }
  }

  //===================================================
  // DELETE COMMENT
  //===================================================

  Future<void> _deleteComment({
    required String commentId,
    required String ownerUid,
  }) async {
    final User? user =
        _auth.currentUser;

    if (user == null ||
        user.uid != ownerUid) {
      _showMessage(
        'You can only delete your own comment.',
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
            'Delete Comment?',
          ),
          content:
          const Text(
            'This comment and its replies will be permanently deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
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
      final DocumentReference<
          Map<String, dynamic>>
      commentRef =
      await _resolveCommentReference(
        commentId,
      );

      //===================================================
      // DELETE NESTED REPLIES
      //===================================================

      try {
        final QuerySnapshot<
            Map<String, dynamic>>
        repliesSnapshot =
        await commentRef
            .collection('replies')
            .get();

        for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        reply in repliesSnapshot.docs) {
          await reply.reference.delete();
        }
      } catch (error) {
        debugPrint(
          'Nested reply cleanup error: $error',
        );
      }

      //===================================================
      // DELETE OLD GLOBAL REPLIES IF ANY
      //===================================================

      try {
        final QuerySnapshot<
            Map<String, dynamic>>
        oldReplies =
        await _firestore
            .collection('comments')
            .where(
          'parentCommentId',
          isEqualTo:
          commentId,
        )
            .get();

        for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        reply in oldReplies.docs) {
          await reply.reference.delete();
        }
      } catch (error) {
        debugPrint(
          'Old reply cleanup error: $error',
        );
      }

      await commentRef.delete();

      await _decreasePostCommentCount();

      if (!mounted) {
        return;
      }

      if (_replyingToCommentId ==
          commentId) {
        _cancelReply();
      }

      _showMessage(
        'Comment deleted.',
      );
    } catch (error) {
      debugPrint(
        'Delete comment error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to delete comment.',
        );
      }
    }
  }

  //===================================================
  // DECREASE POST COMMENT COUNT
  //===================================================

  Future<void> _decreasePostCommentCount() async {
    final DocumentReference<
        Map<String, dynamic>>
    postRef =
    _firestore
        .collection('posts')
        .doc(widget.postId);

    try {
      await _firestore.runTransaction(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<
              Map<String, dynamic>>
          snapshot =
          await transaction.get(
            postRef,
          );

          if (!snapshot.exists) {
            return;
          }

          final int currentCount =
          _toInt(
            snapshot.data()?[
            'commentCount'],
          );

          transaction.update(
            postRef,
            <String, dynamic>{
              'commentCount':
              currentCount > 0
                  ? currentCount - 1
                  : 0,
            },
          );
        },
      );
    } catch (error) {
      debugPrint(
        'Comment count update error: $error',
      );
    }
  }

  //===================================================
  // COMMENT OWNER MENU
  //===================================================

  void _showCommentMenu({
    required String commentId,
    required String text,
    required String ownerUid,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle:
      true,
      builder: (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading:
                const Icon(
                  Icons.edit_outlined,
                ),
                title:
                const Text(
                  'Edit Comment',
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _editComment(
                    commentId:
                    commentId,
                    currentText:
                    text,
                    ownerUid:
                    ownerUid,
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
                  'Delete Comment',
                  style:
                  TextStyle(
                    color:
                    Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _deleteComment(
                    commentId:
                    commentId,
                    ownerUid:
                    ownerUid,
                  );
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
  // BUILD COMMENT
  //===================================================

  Widget _buildComment(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    final Map<String, dynamic> data =
    document.data();

    final String commentId =
        document.id;

    final String uid =
    (data['uid'] ??
        data['userId'] ??
        '')
        .toString()
        .trim();

    final String username =
    (data['username'] ?? '')
        .toString()
        .trim();

    final String fullName =
    (data['fullName'] ?? '')
        .toString()
        .trim();

    final String photoUrl =
    (data['photoUrl'] ?? '')
        .toString()
        .trim();

    final String text =
    (data['text'] ?? '')
        .toString();

    final int likeCount =
    _toInt(
      data['likeCount'],
    );

    final int replyCount =
    _toInt(
      data['replyCount'],
    );

    final bool edited =
        data['edited'] == true;

    final Timestamp? createdAt =
    data['createdAt']
    is Timestamp
        ? data['createdAt']
    as Timestamp
        : null;

    final String displayName =
    fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
        ? username
        : 'Nubify User';

    final bool isOwner =
        _auth.currentUser != null &&
            uid.isNotEmpty &&
            _auth.currentUser!.uid ==
                uid;

    return Padding(
      padding:
      const EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: <Widget>[
              //===================================================
              // PROFILE PICTURE
              //===================================================

              GestureDetector(
                behavior:
                HitTestBehavior.opaque,
                onTap:
                uid.isEmpty
                    ? null
                    : () {
                  _openUserProfile(
                    uid,
                  );
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor:
                  const Color(
                    0xFF29B6F6,
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
                    Icons.person,
                    size: 20,
                    color:
                    Colors.white,
                  )
                      : null,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: <Widget>[
                    //===================================================
                    // NAME + USERNAME
                    //===================================================

                    GestureDetector(
                      behavior:
                      HitTestBehavior.opaque,
                      onTap:
                      uid.isEmpty
                          ? null
                          : () {
                        _openUserProfile(
                          uid,
                        );
                      },
                      child: Wrap(
                        crossAxisAlignment:
                        WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: <Widget>[
                          Text(
                            displayName,
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),

                          if (username.isNotEmpty)
                            Text(
                              '@$username',
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

                    const SizedBox(
                      height: 3,
                    ),

                    //===================================================
                    // COMMENT TEXT
                    //===================================================

                    Text(
                      text,
                      style:
                      const TextStyle(
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    //===================================================
                    // TIME + EDITED + REPLY + LIKE
                    //===================================================

                    Wrap(
                      crossAxisAlignment:
                      WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 5,
                      children: <Widget>[
                        NubifyTimeText.fromTimestamp(
                          timestamp:
                          createdAt,
                          style:
                          TextStyle(
                            color:
                            Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),

                        if (edited)
                          Text(
                            'edited',
                            style:
                            TextStyle(
                              color:
                              Colors.grey.shade500,
                              fontSize: 11,
                              fontStyle:
                              FontStyle.italic,
                            ),
                          ),

                        GestureDetector(
                          onTap: () {
                            _startReply(
                              commentId:
                              commentId,
                              username:
                              username,
                            );
                          },
                          child: Text(
                            'Reply',
                            style:
                            TextStyle(
                              color:
                              Colors.grey.shade700,
                              fontWeight:
                              FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        _CommentLikeButton(
                          postId:
                          widget.postId,
                          commentId:
                          commentId,
                          likeCount:
                          likeCount,
                          commentService:
                          _commentService,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              //===================================================
              // OWNER MENU
              //===================================================

              if (isOwner)
                IconButton(
                  visualDensity:
                  VisualDensity.compact,
                  onPressed: () {
                    _showCommentMenu(
                      commentId:
                      commentId,
                      text:
                      text,
                      ownerUid:
                      uid,
                    );
                  },
                  icon:
                  const Icon(
                    Icons.more_vert,
                    size: 20,
                  ),
                ),
            ],
          ),

          //===================================================
          // REPLIES
          //===================================================

          if (replyCount > 0)
            _RepliesSection(
              postId:
              widget.postId,
              commentId:
              commentId,
              replyCount:
              replyCount,
              commentService:
              _commentService,
              onReply: (
                  String username,
                  ) {
                _startReply(
                  commentId:
                  commentId,
                  username:
                  username,
                );
              },
            ),
        ],
      ),
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

    ScaffoldMessenger.of(context)
        .showSnackBar(
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
    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'Comments',
        ),
      ),
      body: Column(
        children: <Widget>[
          //===================================================
          // ORIGINAL POST + COMMENTS
          //===================================================

          Expanded(
            child: StreamBuilder<
                DocumentSnapshot<
                    Map<String, dynamic>>>(
              stream:
              _firestore
                  .collection('posts')
                  .doc(widget.postId)
                  .snapshots(),
              builder: (
                  BuildContext context,
                  AsyncSnapshot<
                      DocumentSnapshot<
                          Map<String, dynamic>>>
                  postSnapshot,
                  ) {
                return StreamBuilder<
                    QuerySnapshot<
                        Map<String, dynamic>>>(
                  stream:
                  _commentService
                      .getComments(
                    widget.postId,
                  ),
                  builder: (
                      BuildContext context,
                      AsyncSnapshot<
                          QuerySnapshot<
                              Map<String, dynamic>>>
                      commentSnapshot,
                      ) {
                    if (commentSnapshot
                        .hasError) {
                      return const Center(
                        child: Text(
                          'Unable to load comments.',
                        ),
                      );
                    }

                    if (!commentSnapshot
                        .hasData) {
                      return const Center(
                        child:
                        CircularProgressIndicator(),
                      );
                    }

                    final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    comments =
                        commentSnapshot
                            .data!
                            .docs;

                    return ListView(
                      padding:
                      EdgeInsets.zero,
                      children: <Widget>[
                        //===================================================
                        // ORIGINAL POST
                        //===================================================

                        if (postSnapshot.hasData &&
                            postSnapshot.data !=
                                null &&
                            postSnapshot
                                .data!.exists)
                          Builder(
                            builder: (
                                BuildContext context,
                                ) {
                              try {
                                final Post post =
                                Post.fromFirestore(
                                  postSnapshot
                                      .data!,
                                );

                                return PostCard(
                                  key:
                                  ValueKey<String>(
                                    'comments-post-${post.postId}',
                                  ),
                                  post:
                                  post,
                                  inCommentsScreen:
                                  true,
                                );
                              } catch (error) {
                                debugPrint(
                                  'Comment post parse error: $error',
                                );

                                return const Padding(
                                  padding:
                                  EdgeInsets.all(
                                    16,
                                  ),
                                  child: Text(
                                    'Unable to display the original post.',
                                    textAlign:
                                    TextAlign.center,
                                  ),
                                );
                              }
                            },
                          )
                        else if (postSnapshot
                            .connectionState ==
                            ConnectionState
                                .waiting)
                          const Padding(
                            padding:
                            EdgeInsets.symmetric(
                              vertical: 28,
                            ),
                            child: Center(
                              child:
                              CircularProgressIndicator(),
                            ),
                          ),

                        //===================================================
                        // COMMENTS HEADER
                        //===================================================

                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(
                            14,
                            18,
                            14,
                            8,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  'Comments',
                                  style:
                                  TextStyle(
                                    fontSize: 22,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                              ),

                              Text(
                                '${comments.length} ${comments.length == 1 ? 'comment' : 'comments'}',
                                style:
                                TextStyle(
                                  color:
                                  Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        //===================================================
                        // COMMENTS
                        //===================================================

                        if (comments.isEmpty)
                          const Padding(
                            padding:
                            EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 35,
                            ),
                            child: Column(
                              children: <Widget>[
                                Icon(
                                  Icons
                                      .chat_bubble_outline,
                                  size: 42,
                                  color:
                                  Colors.grey,
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  'No comments yet.',
                                  style:
                                  TextStyle(
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  'Be the first to comment.',
                                  style:
                                  TextStyle(
                                    color:
                                    Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...comments.map(
                                (
                                QueryDocumentSnapshot<
                                    Map<String, dynamic>>
                                comment,
                                ) {
                              return _buildComment(
                                comment,
                              );
                            },
                          ),

                        const SizedBox(
                          height: 20,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          //===================================================
          // REPLY INDICATOR
          //===================================================

          if (_replyingToCommentId !=
              null)
            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              color:
              Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Replying to @$_replyingToUsername',
                      style:
                      TextStyle(
                        color:
                        Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed:
                    _cancelReply,
                    icon:
                    const Icon(
                      Icons.close,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

          //===================================================
          // COMMENT INPUT
          //===================================================

          SafeArea(
            top: false,
            child: Container(
              padding:
              const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                8,
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller:
                      _commentController,
                      focusNode:
                      _commentFocusNode,
                      minLines:
                      1,
                      maxLines:
                      5,
                      textInputAction:
                      TextInputAction.newline,
                      decoration:
                      InputDecoration(
                        hintText:
                        _replyingToCommentId !=
                            null
                            ? 'Write a reply...'
                            : 'Write a comment...',
                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            24,
                          ),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            24,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            Color(
                              0xFF29B6F6,
                            ),
                            width:
                            1.5,
                          ),
                        ),
                        contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 6,
                  ),

                  IconButton(
                    onPressed:
                    _isSending
                        ? null
                        : _sendComment,
                    icon:
                    _isSending
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.send,
                      color:
                      Color(
                        0xFF29B6F6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();

    super.dispose();
  }
}

//===================================================
// COMMENT LIKE BUTTON
//===================================================

class _CommentLikeButton
    extends StatefulWidget {
  final String postId;
  final String commentId;
  final int likeCount;
  final CommentService commentService;

  const _CommentLikeButton({
    required this.postId,
    required this.commentId,
    required this.likeCount,
    required this.commentService,
  });

  @override
  State<_CommentLikeButton> createState() =>
      _CommentLikeButtonState();
}

//===================================================
// COMMENT LIKE STATE
//===================================================

class _CommentLikeButtonState
    extends State<_CommentLikeButton> {
  bool _isLiked = false;
  bool _loading = false;

  late int _count;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _count =
        widget.likeCount;

    _loadLike();
  }

  //===================================================
  // LOAD LIKE
  //===================================================

  Future<void> _loadLike() async {
    try {
      final bool liked =
      await widget.commentService
          .hasLikedComment(
        postId:
        widget.postId,
        commentId:
        widget.commentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = liked;
      });
    } catch (_) {}
  }

  //===================================================
  // TOGGLE LIKE
  //===================================================

  Future<void> _toggleLike() async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await widget.commentService
          .toggleCommentLike(
        postId:
        widget.postId,
        commentId:
        widget.commentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked =
        !_isLiked;

        if (_isLiked) {
          _count++;
        } else if (_count > 0) {
          _count--;
        }
      });
    } catch (error) {
      debugPrint(
        'Comment like error: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      onTap:
      _loading
          ? null
          : _toggleLike,
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: <Widget>[
          Icon(
            _isLiked
                ? Icons.favorite
                : Icons.favorite_border,
            size: 15,
            color:
            _isLiked
                ? const Color(
              0xFF29B6F6,
            )
                : Colors
                .grey
                .shade600,
          ),

          const SizedBox(
            width: 3,
          ),

          Text(
            '$_count',
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
}

//===================================================
// REPLIES SECTION
//===================================================

class _RepliesSection
    extends StatefulWidget {
  final String postId;
  final String commentId;
  final int replyCount;
  final CommentService commentService;
  final Function(String username) onReply;

  const _RepliesSection({
    required this.postId,
    required this.commentId,
    required this.replyCount,
    required this.commentService,
    required this.onReply,
  });

  @override
  State<_RepliesSection> createState() =>
      _RepliesSectionState();
}

//===================================================
// REPLIES STATE
//===================================================

class _RepliesSectionState
    extends State<_RepliesSection> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  int _visibleReplies = 3;

  //===================================================
  // INT HELPER
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
  // OPEN PROFILE
  //===================================================

  Future<void> _openUserProfile(
      String uid,
      ) async {
    final String cleanUid =
    uid.trim();

    if (cleanUid.isEmpty ||
        !mounted) {
      return;
    }

    await Navigator.of(context).pushNamed(
      '/profile',
      arguments:
      cleanUid,
    );
  }

  //===================================================
  // RESOLVE COMMENT REFERENCE
  //===================================================

  Future<DocumentReference<Map<String, dynamic>>>
  _resolveCommentReference() async {
    final DocumentReference<
        Map<String, dynamic>>
    nestedReference =
    _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(widget.commentId);

    try {
      if ((await nestedReference.get())
          .exists) {
        return nestedReference;
      }
    } catch (_) {}

    final DocumentReference<
        Map<String, dynamic>>
    globalReference =
    _firestore
        .collection('comments')
        .doc(widget.commentId);

    try {
      if ((await globalReference.get())
          .exists) {
        return globalReference;
      }
    } catch (_) {}

    return nestedReference;
  }

  //===================================================
  // RESOLVE REPLY REFERENCE
  //===================================================

  Future<DocumentReference<Map<String, dynamic>>>
  _resolveReplyReference(
      String replyId,
      ) async {
    final DocumentReference<
        Map<String, dynamic>>
    commentRef =
    await _resolveCommentReference();

    final DocumentReference<
        Map<String, dynamic>>
    nestedReplyRef =
    commentRef
        .collection('replies')
        .doc(replyId);

    try {
      if ((await nestedReplyRef.get())
          .exists) {
        return nestedReplyRef;
      }
    } catch (_) {}

    final DocumentReference<
        Map<String, dynamic>>
    globalCommentRef =
    _firestore
        .collection('comments')
        .doc(replyId);

    try {
      if ((await globalCommentRef.get())
          .exists) {
        return globalCommentRef;
      }
    } catch (_) {}

    final DocumentReference<
        Map<String, dynamic>>
    globalReplyRef =
    _firestore
        .collection('replies')
        .doc(replyId);

    try {
      if ((await globalReplyRef.get())
          .exists) {
        return globalReplyRef;
      }
    } catch (_) {}

    return nestedReplyRef;
  }

  //===================================================
  // EDIT REPLY
  //===================================================

  Future<void> _editReply({
    required String replyId,
    required String currentText,
    required String ownerUid,
  }) async {
    final User? user =
        _auth.currentUser;

    if (user == null ||
        user.uid != ownerUid) {
      return;
    }

    String editedText =
        currentText;

    final String? result =
    await showDialog<String>(
      context: context,
      builder: (
          BuildContext dialogContext,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Edit Reply',
          ),
          content: TextFormField(
            initialValue:
            currentText,
            autofocus:
            true,
            maxLines:
            5,
            maxLength:
            2000,
            onChanged: (
                String value,
                ) {
              editedText =
                  value;
            },
            decoration:
            const InputDecoration(
              hintText:
              'Edit your reply...',
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
                final String value =
                editedText.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
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
        result == null ||
        result.trim().isEmpty) {
      return;
    }

    try {
      final DocumentReference<
          Map<String, dynamic>>
      replyRef =
      await _resolveReplyReference(
        replyId,
      );

      await replyRef.update(
        <String, dynamic>{
          'text':
          result.trim(),
          'edited':
          true,
          'editedAt':
          FieldValue.serverTimestamp(),
        },
      );

      if (mounted) {
        _showMessage(
          'Reply updated.',
        );
      }
    } catch (error) {
      debugPrint(
        'Edit reply error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to edit reply.',
        );
      }
    }
  }

  //===================================================
  // DELETE REPLY
  //===================================================

  Future<void> _deleteReply({
    required String replyId,
    required String ownerUid,
  }) async {
    final User? user =
        _auth.currentUser;

    if (user == null ||
        user.uid != ownerUid) {
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
            'Delete Reply?',
          ),
          content:
          const Text(
            'This reply will be permanently deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
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
              onPressed: () {
                Navigator.pop(
                  dialogContext,
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
      final DocumentReference<
          Map<String, dynamic>>
      replyRef =
      await _resolveReplyReference(
        replyId,
      );

      await replyRef.delete();

      await _decreaseReplyCount();

      if (mounted) {
        _showMessage(
          'Reply deleted.',
        );
      }
    } catch (error) {
      debugPrint(
        'Delete reply error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to delete reply.',
        );
      }
    }
  }

  //===================================================
  // DECREASE REPLY COUNT
  //===================================================

  Future<void> _decreaseReplyCount() async {
    try {
      final DocumentReference<
          Map<String, dynamic>>
      commentRef =
      await _resolveCommentReference();

      await _firestore.runTransaction(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<
              Map<String, dynamic>>
          snapshot =
          await transaction.get(
            commentRef,
          );

          if (!snapshot.exists) {
            return;
          }

          final int current =
          _toInt(
            snapshot.data()?[
            'replyCount'],
          );

          transaction.update(
            commentRef,
            <String, dynamic>{
              'replyCount':
              current > 0
                  ? current - 1
                  : 0,
            },
          );
        },
      );
    } catch (error) {
      debugPrint(
        'Reply count error: $error',
      );
    }
  }

  //===================================================
  // REPLY OWNER MENU
  //===================================================

  void _showReplyMenu({
    required String replyId,
    required String text,
    required String ownerUid,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle:
      true,
      builder: (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading:
                const Icon(
                  Icons.edit_outlined,
                ),
                title:
                const Text(
                  'Edit Reply',
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _editReply(
                    replyId:
                    replyId,
                    currentText:
                    text,
                    ownerUid:
                    ownerUid,
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
                  'Delete Reply',
                  style:
                  TextStyle(
                    color:
                    Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _deleteReply(
                    replyId:
                    replyId,
                    ownerUid:
                    ownerUid,
                  );
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
  // MESSAGE
  //===================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
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
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream:
      widget.commentService
          .getReplies(
        postId:
        widget.postId,
        commentId:
        widget.commentId,
      ),
      builder: (
          BuildContext context,
          AsyncSnapshot<
              QuerySnapshot<
                  Map<String, dynamic>>>
          snapshot,
          ) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        replies =
            snapshot.data!.docs;

        if (replies.isEmpty) {
          return const SizedBox.shrink();
        }

        final int visibleCount =
        _visibleReplies >
            replies.length
            ? replies.length
            : _visibleReplies;

        return Padding(
          padding:
          const EdgeInsets.only(
            left: 18,
            top: 8,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: <Widget>[
              for (int index = 0;
              index < visibleCount;
              index++)
                _buildReply(
                  replies[index],
                ),

              if (replies.length >
                  visibleCount)
                Padding(
                  padding:
                  const EdgeInsets.only(
                    left: 38,
                    top: 5,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _visibleReplies += 3;
                      });
                    },
                    child: Text(
                      'View more replies',
                      style:
                      TextStyle(
                        color:
                        Colors.grey.shade700,
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // BUILD REPLY
  //===================================================

  Widget _buildReply(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    final Map<String, dynamic> data =
    document.data();

    final String replyId =
        document.id;

    final String uid =
    (data['uid'] ??
        data['userId'] ??
        '')
        .toString()
        .trim();

    final String username =
    (data['username'] ?? '')
        .toString()
        .trim();

    final String fullName =
    (data['fullName'] ?? '')
        .toString()
        .trim();

    final String photoUrl =
    (data['photoUrl'] ?? '')
        .toString()
        .trim();

    final String text =
    (data['text'] ?? '')
        .toString();

    final int likeCount =
    _toInt(
      data['likeCount'],
    );

    final bool edited =
        data['edited'] == true;

    final Timestamp? createdAt =
    data['createdAt']
    is Timestamp
        ? data['createdAt']
    as Timestamp
        : null;

    final String displayName =
    fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
        ? username
        : 'Nubify User';

    final bool isOwner =
        _auth.currentUser != null &&
            uid.isNotEmpty &&
            _auth.currentUser!.uid ==
                uid;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: <Widget>[
          //===================================================
          // VERTICAL REPLY LINE
          //===================================================

          Container(
            width: 2,
            margin:
            const EdgeInsets.only(
              right: 12,
            ),
            color:
            Colors.grey.shade600,
          ),

          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.only(
                bottom: 12,
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: <Widget>[
                  //===================================================
                  // REPLY PROFILE PICTURE
                  //===================================================

                  GestureDetector(
                    behavior:
                    HitTestBehavior.opaque,
                    onTap:
                    uid.isEmpty
                        ? null
                        : () {
                      _openUserProfile(
                        uid,
                      );
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                      const Color(
                        0xFF29B6F6,
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
                        Icons.person,
                        size: 16,
                        color:
                        Colors.white,
                      )
                          : null,
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: <Widget>[
                        //===================================================
                        // NAME / USERNAME
                        //===================================================

                        GestureDetector(
                          behavior:
                          HitTestBehavior.opaque,
                          onTap:
                          uid.isEmpty
                              ? null
                              : () {
                            _openUserProfile(
                              uid,
                            );
                          },
                          child: Wrap(
                            crossAxisAlignment:
                            WrapCrossAlignment.center,
                            spacing: 5,
                            runSpacing: 2,
                            children: <Widget>[
                              Text(
                                displayName,
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),

                              if (username.isNotEmpty)
                                Text(
                                  '@$username',
                                  style:
                                  TextStyle(
                                    color:
                                    Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 2,
                        ),

                        Text(
                          text,
                          style:
                          const TextStyle(
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Wrap(
                          crossAxisAlignment:
                          WrapCrossAlignment.center,
                          spacing: 11,
                          runSpacing: 4,
                          children: <Widget>[
                            NubifyTimeText.fromTimestamp(
                              timestamp:
                              createdAt,
                              style:
                              TextStyle(
                                color:
                                Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),

                            if (edited)
                              Text(
                                'edited',
                                style:
                                TextStyle(
                                  color:
                                  Colors.grey.shade500,
                                  fontSize: 10,
                                  fontStyle:
                                  FontStyle.italic,
                                ),
                              ),

                            GestureDetector(
                              onTap: () {
                                widget.onReply(
                                  username,
                                );
                              },
                              child: Text(
                                'Reply',
                                style:
                                TextStyle(
                                  color:
                                  Colors.grey.shade700,
                                  fontWeight:
                                  FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),

                            _ReplyLikeButton(
                              postId:
                              widget.postId,
                              commentId:
                              widget.commentId,
                              replyId:
                              replyId,
                              likeCount:
                              likeCount,
                              commentService:
                              widget.commentService,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  //===================================================
                  // REPLY OWNER MENU
                  //===================================================

                  if (isOwner)
                    IconButton(
                      visualDensity:
                      VisualDensity.compact,
                      onPressed: () {
                        _showReplyMenu(
                          replyId:
                          replyId,
                          text:
                          text,
                          ownerUid:
                          uid,
                        );
                      },
                      icon:
                      const Icon(
                        Icons.more_vert,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// REPLY LIKE BUTTON
//===================================================

class _ReplyLikeButton
    extends StatefulWidget {
  final String postId;
  final String commentId;
  final String replyId;
  final int likeCount;
  final CommentService commentService;

  const _ReplyLikeButton({
    required this.postId,
    required this.commentId,
    required this.replyId,
    required this.likeCount,
    required this.commentService,
  });

  @override
  State<_ReplyLikeButton> createState() =>
      _ReplyLikeButtonState();
}

//===================================================
// REPLY LIKE STATE
//===================================================

class _ReplyLikeButtonState
    extends State<_ReplyLikeButton> {
  bool _isLiked = false;
  bool _loading = false;

  late int _count;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _count =
        widget.likeCount;

    _loadLike();
  }

  //===================================================
  // LOAD LIKE
  //===================================================

  Future<void> _loadLike() async {
    try {
      final bool liked =
      await widget.commentService
          .hasLikedReply(
        postId:
        widget.postId,
        commentId:
        widget.commentId,
        replyId:
        widget.replyId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = liked;
      });
    } catch (_) {}
  }

  //===================================================
  // TOGGLE LIKE
  //===================================================

  Future<void> _toggleLike() async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await widget.commentService
          .toggleReplyLike(
        postId:
        widget.postId,
        commentId:
        widget.commentId,
        replyId:
        widget.replyId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked =
        !_isLiked;

        if (_isLiked) {
          _count++;
        } else if (_count > 0) {
          _count--;
        }
      });
    } catch (error) {
      debugPrint(
        'Reply like error: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      onTap:
      _loading
          ? null
          : _toggleLike,
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: <Widget>[
          Icon(
            _isLiked
                ? Icons.favorite
                : Icons.favorite_border,
            size: 14,
            color:
            _isLiked
                ? const Color(
              0xFF29B6F6,
            )
                : Colors
                .grey
                .shade600,
          ),

          const SizedBox(
            width: 3,
          ),

          Text(
            '$_count',
            style:
            TextStyle(
              color:
              Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
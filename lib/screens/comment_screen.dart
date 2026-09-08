import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../services/comment_service.dart';
import '../utils/nubify_time.dart';
import '../widgets/post_card.dart';
import '../widgets/universal_link_text.dart';

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
  // COMMENT IMAGE
  //===================================================

  final ImagePicker _imagePicker =
  ImagePicker();

  XFile? _selectedCommentImage;

  bool _isPickingImage =
  false;

  //===================================================
  // REPLY STATE
  //===================================================
  String? _replyingToCommentId;

  String? _replyingToReplyId;

  String? _replyingToUsername;
  bool _isSending =
  false;

  //===================================================
  // POST MEDIA PLAYBACK WHILE READING COMMENTS
  //===================================================

  bool _isPostMediaPaused = false;

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
  //
  // USER CAN SEND:
  // - TEXT ONLY
  // - IMAGE ONLY
  // - TEXT + IMAGE
  //===================================================

  Future<void> _sendComment() async {
    final String text =
    _commentController.text
        .trim();

    final String? imagePath =
    _selectedCommentImage
        ?.path
        .trim();

    final bool hasImage =
        imagePath != null &&
            imagePath.isNotEmpty;

    if ((text.isEmpty &&
        !hasImage) ||
        _isSending) {
      return;
    }

    final String? replyCommentId =
        _replyingToCommentId;

    final String? replyParentId =
        _replyingToReplyId;

    final String? replyUsername =
        _replyingToUsername;

    //===================================================
    // RELEASE THE SEND ARROW IMMEDIATELY
    //
    // FIRESTORE CAN SHOW THE LOCAL COMMENT BEFORE THE
    // SERVER ACKNOWLEDGES THE WRITE. THE OLD CODE AWAITED
    // THAT ACKNOWLEDGEMENT, SO THE ARROW KEPT SPINNING
    // EVEN AFTER THE COMMENT WAS ALREADY VISIBLE.
    //===================================================

    setState(() {
      _isSending =
      true;
    });

    _commentController.clear();

    setState(() {
      _replyingToCommentId =
      null;

      _replyingToReplyId =
      null;

      _replyingToUsername =
      null;

      _selectedCommentImage =
      null;

      _isSending =
      false;
    });

    FocusScope.of(context)
        .unfocus();

    //===================================================
    // SEND IN BACKGROUND
    //===================================================

    unawaited(
      _sendCommentInBackground(
        text:
        text,
        imagePath:
        hasImage
            ? imagePath
            : null,
        replyCommentId:
        replyCommentId,

        replyParentId:
        replyParentId,

        replyToUsername:
        replyUsername,
      ),
    );
  }

  //===================================================
  // SEND COMMENT IN BACKGROUND
  //===================================================

  Future<void> _sendCommentInBackground({
    required String text,
    required String? imagePath,
    required String? replyCommentId,
    required String? replyParentId,
    required String? replyToUsername,
  }) async {
    try {
      if (replyCommentId !=
          null) {
        await _commentService.addReply(
          postId:
          widget.postId,

          commentId:
          replyCommentId,

          parentReplyId:
          replyParentId ?? '',

          replyToUsername:
          replyToUsername ?? '',

          text:
          text,

          imagePath:
          imagePath,
        );

        if (mounted) {
          final String target = (replyToUsername ?? '').trim();

          _showMessage(
            target.isEmpty
                ? 'You posted a reply.'
                : 'You replied to @$target.',
          );
        }
      } else {
        await _commentService.addComment(
          postId:
          widget.postId,
          text:
          text,
          imagePath:
          imagePath,
        );

        if (mounted) {
          _showMessage(
            'You commented on this post.',
          );
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not send: $error',
      );
    }
  }

  //===================================================
  // PAUSE MEDIA WHEN SCROLLING DOWN TO COMMENTS
  //
  // SCROLLING DOWN PAUSES THE VIDEO/AUDIO. SCROLLING
  // BACK UP RESUMES IT ONLY IF IT WAS PLAYING BEFORE.
  //===================================================

  bool _handleCommentScroll(
    UserScrollNotification notification,
  ) {
    if (notification.metrics.axis != Axis.vertical ||
        notification.direction == ScrollDirection.idle) {
      return false;
    }

    final bool shouldPause =
        notification.direction == ScrollDirection.reverse;

    if (shouldPause != _isPostMediaPaused && mounted) {
      setState(() {
        _isPostMediaPaused = shouldPause;
      });
    }

    return false;
  }

  //===================================================
// START REPLY
//===================================================

  void _startReply({
    required String commentId,
    required String username,
    String? parentReplyId,
  }) {
    final String safeUsername =
    username.trim().isNotEmpty
        ? username.trim()
        : 'user';

    setState(() {
      _replyingToCommentId =
          commentId;

      _replyingToReplyId =
          parentReplyId;

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
                .text.length,
          ),
        );

    _commentFocusNode
        .requestFocus();
  }

  //===================================================
  // CANCEL REPLY
  //===================================================

  void _cancelReply() {
    setState(() {
      _replyingToCommentId =
      null;

      _replyingToReplyId =
      null;

      _replyingToUsername =
      null;

      _selectedCommentImage =
      null;
    });

    _commentController.clear();

    FocusScope.of(context)
        .unfocus();
  }

  //===================================================
// PICK COMMENT IMAGE
//===================================================

  Future<void> _pickCommentImage(
      ImageSource source,
      ) async {
    if (_isSending) {
      return;
    }

    try {
      final XFile? image =
      await _imagePicker.pickImage(
        source:
        source,

        imageQuality:
        88,

        maxWidth:
        2200,

        maxHeight:
        2200,
      );

      if (image == null ||
          !mounted) {
        return;
      }

      setState(() {
        _selectedCommentImage =
            image;
      });

      _commentFocusNode
          .requestFocus();
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Could not select picture: $error',
        );
      }
    }
  }

  //===================================================
  // COMMENT IMAGE OPTIONS
  //===================================================

  Future<void> _showCommentImageOptions() async {
    if (_isPickingImage ||
        _isSending) {
      return;
    }

    await showModalBottomSheet<void>(
      context:
      context,
      showDragHandle:
      true,
      builder:
          (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children:
            <Widget>[
              const Padding(
                padding:
                EdgeInsets.only(
                  bottom:
                  8,
                ),
                child:
                Text(
                  'Add a picture',
                  style:
                  TextStyle(
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              ListTile(
                leading:
                const Icon(
                  Icons
                      .photo_library_outlined,
                  color:
                  Color(
                    0xFF29B6F6,
                  ),
                ),
                title:
                const Text(
                  'Choose from gallery',
                ),
                onTap:
                    () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _pickCommentImage(
                    ImageSource.gallery,
                  );
                },
              ),

              ListTile(
                leading:
                const Icon(
                  Icons
                      .camera_alt_outlined,
                  color:
                  Color(
                    0xFF29B6F6,
                  ),
                ),
                title:
                const Text(
                  'Take a picture',
                ),
                onTap:
                    () async {
                  Navigator.pop(
                    sheetContext,
                  );

                  await _pickCommentImage(
                    ImageSource.camera,
                  );
                },
              ),

              if (_selectedCommentImage !=
                  null)
                ListTile(
                  leading:
                  const Icon(
                    Icons
                        .delete_outline_rounded,
                    color:
                    Colors.redAccent,
                  ),
                  title:
                  const Text(
                    'Remove selected picture',
                    style:
                    TextStyle(
                      color:
                      Colors.redAccent,
                    ),
                  ),
                  onTap:
                      () {
                    Navigator.pop(
                      sheetContext,
                    );

                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _selectedCommentImage =
                      null;
                    });
                  },
                ),

              const SizedBox(
                height:
                8,
              ),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // REMOVE SELECTED COMMENT IMAGE
  //===================================================

  void _removeSelectedCommentImage() {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedCommentImage =
      null;
    });
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
        Map<String, dynamic>> nestedReference =
    _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    try {
      final DocumentSnapshot<
          Map<String, dynamic>> nestedSnapshot =
      await nestedReference.get();

      if (nestedSnapshot.exists) {
        return nestedReference;
      }
    } catch (_) {}

    final DocumentReference<
        Map<String, dynamic>> globalReference =
    _firestore
        .collection('comments')
        .doc(commentId);

    try {
      final DocumentSnapshot<
          Map<String, dynamic>> globalSnapshot =
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
        user.uid !=
            ownerUid) {
      _showMessage(
        'You can only edit your own comment.',
      );

      return;
    }

    String editedText =
        currentText;

    final String? result =
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
            'Edit Comment',
          ),
          content:
          TextFormField(
            initialValue:
            currentText,
            autofocus:
            true,
            maxLines:
            5,
            maxLength:
            2000,
            onChanged:
                (
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
          actions:
          <Widget>[
            TextButton(
              onPressed:
                  () {
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
              onPressed:
                  () {
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
          Map<String, dynamic>> commentRef =
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

      //===================================================
      // KEEP PROFILE -> COMMENTS TAB IN SYNC
      //===================================================

      await _commentService
          .updateCommentActivity(
        uid:
        ownerUid,
        commentId:
        commentId,
        text:
        result.trim(),
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
        user.uid !=
            ownerUid) {
      _showMessage(
        'You can only delete your own comment.',
      );

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
            'Delete Comment?',
          ),
          content:
          const Text(
            'This comment and its replies will be permanently deleted.',
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
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        confirmed !=
            true) {
      return;
    }

    try {
      final DocumentReference<
          Map<String, dynamic>> commentRef =
      await _resolveCommentReference(
        commentId,
      );

      //===================================================
      // NEW NESTED NUBIFY COMMENT
      //
      // USE THE SERVICE SO:
      // - COMMENT IMAGE IS DELETED FROM STORAGE
      // - REPLY IMAGES ARE DELETED
      // - PROFILE COMMENT HISTORY IS REMOVED
      // - POST COMMENT COUNT IS UPDATED
      //===================================================

      if (commentRef.path.startsWith(
        'posts/',
      )) {
        await _commentService.deleteComment(
          postId:
          widget.postId,
          commentId:
          commentId,
        );
      } else {
        //===================================================
        // OLD GLOBAL COMMENT FALLBACK
        //===================================================

        int deletedLegacyReplyCount = 0;

        try {
          final QuerySnapshot<
              Map<String, dynamic>> repliesSnapshot =
          await commentRef
              .collection('replies')
              .get();

          for (
          final QueryDocumentSnapshot<
              Map<String, dynamic>> reply
          in repliesSnapshot.docs
          ) {
            await reply.reference.delete();

            deletedLegacyReplyCount++;
          }
        } catch (error) {
          debugPrint(
            'Nested reply cleanup error: $error',
          );
        }

        try {
          final QuerySnapshot<
              Map<String, dynamic>> oldReplies =
          await _firestore
              .collection('comments')
              .where(
            'parentCommentId',
            isEqualTo:
            commentId,
          )
              .get();

          for (
          final QueryDocumentSnapshot<
              Map<String, dynamic>> reply
          in oldReplies.docs
          ) {
            await reply.reference.delete();

            deletedLegacyReplyCount++;
          }
        } catch (error) {
          debugPrint(
            'Old reply cleanup error: $error',
          );
        }

        await commentRef.delete();

        await _commentService
            .removeCommentActivity(
          uid:
          ownerUid,
          commentId:
          commentId,
        );

        await _decreasePostCommentCount(
          by: 1 + deletedLegacyReplyCount,
        );
      }

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

  Future<void> _decreasePostCommentCount({
    int by = 1,
  }) async {
    final DocumentReference<
        Map<String, dynamic>> postRef =
    _firestore
        .collection('posts')
        .doc(widget.postId);

    try {
      await _firestore.runTransaction(
            (
            Transaction transaction,
            ) async {
          final DocumentSnapshot<
              Map<String, dynamic>> snapshot =
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
              currentCount > by
                  ? currentCount - by
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
      context:
      context,
      showDragHandle:
      true,
      builder:
          (
          BuildContext sheetContext,
          ) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children:
            <Widget>[
              ListTile(
                leading:
                const Icon(
                  Icons.edit_outlined,
                ),
                title:
                const Text(
                  'Edit Comment',
                ),
                onTap:
                    () {
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
                onTap:
                    () {
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
                height:
                8,
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
          Map<String, dynamic>> document,
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

    final String imageUrl =
    (data['imageUrl'] ??
        data['mediaUrl'] ??
        '')
        .toString()
        .trim();

    final int likeCount =
    _toInt(
      data['likeCount'],
    );

    final int replyCount =
    _toInt(
      data['replyCount'],
    );

    final bool edited =
        data['edited'] ==
            true;

    final Timestamp? createdAt =
    data['createdAt'] is Timestamp
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
        _auth.currentUser !=
            null &&
            uid.isNotEmpty &&
            _auth.currentUser!.uid ==
                uid;

    return Padding(
      padding:
      const EdgeInsets.only(
        left:
        12,
        right:
        12,
        top:
        12,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children:
        <Widget>[
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children:
            <Widget>[
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
                child:
                CircleAvatar(
                  radius:
                  20,
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
                    size:
                    20,
                    color:
                    Colors.white,
                  )
                      : null,
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children:
                  <Widget>[
                    //===================================================
                    // NAME + USERNAME
                    //===================================================

                    GestureDetector(
                      behavior:
                      HitTestBehavior
                          .opaque,
                      onTap:
                      uid.isEmpty
                          ? null
                          : () {
                        _openUserProfile(
                          uid,
                        );
                      },
                      child:
                      Wrap(
                        crossAxisAlignment:
                        WrapCrossAlignment
                            .center,
                        spacing:
                        6,
                        runSpacing:
                        2,
                        children:
                        <Widget>[
                          Text(
                            displayName,
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold,
                              fontSize:
                              14,
                            ),
                          ),

                          if (username
                              .isNotEmpty)
                            Text(
                              '@$username',
                              style:
                              TextStyle(
                                color:
                                Colors.grey
                                    .shade600,
                                fontSize:
                                12,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                      3,
                    ),

                    //===================================================
                    // COMMENT TEXT
                    //===================================================

                    if (text
                        .trim()
                        .isNotEmpty)
                      UniversalLinkText(
                        text:
                        text,

                        compactPreview:
                        true,

                        style:
                        const TextStyle(
                          fontSize:
                          15,
                        ),
                      ),

                    //===================================================
                    // COMMENT PICTURE
                    //===================================================

                    if (imageUrl.isNotEmpty)
                      Padding(
                        padding:
                        EdgeInsets.only(
                          top:
                          text
                              .trim()
                              .isNotEmpty
                              ? 8
                              : 2,
                        ),
                        child:
                        _CommentNetworkImage(
                          imageUrl:
                          imageUrl,
                        ),
                      ),

                    const SizedBox(
                      height:
                      5,
                    ),

                    //===================================================
                    // TIME + EDITED + REPLY + LIKE
                    //===================================================

                    Wrap(
                      crossAxisAlignment:
                      WrapCrossAlignment
                          .center,
                      spacing:
                      12,
                      runSpacing:
                      5,
                      children:
                      <Widget>[
                        NubifyTimeText
                            .fromTimestamp(
                          timestamp:
                          createdAt,
                          showWeeksForOlderDates:
                          true,
                          style:
                          TextStyle(
                            color:
                            Colors.grey
                                .shade600,
                            fontSize:
                            12,
                          ),
                        ),

                        if (edited)
                          Text(
                            'edited',
                            style:
                            TextStyle(
                              color:
                              Colors.grey
                                  .shade500,
                              fontSize:
                              11,
                              fontStyle:
                              FontStyle
                                  .italic,
                            ),
                          ),

                        GestureDetector(
                          onTap:
                              () {
                            _startReply(
                              commentId:
                              commentId,
                              username:
                              username,
                            );
                          },
                          child:
                          Text(
                            'Reply',
                            style:
                            TextStyle(
                              color:
                              Colors.grey
                                  .shade700,
                              fontWeight:
                              FontWeight
                                  .bold,
                              fontSize:
                              12,
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
                  onPressed:
                      () {
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
                    size:
                    20,
                  ),
                ),
            ],
          ),

          //===================================================
          // REPLIES
          //===================================================

          if (replyCount >
              0)
            _RepliesSection(
              postId:
              widget.postId,
              commentId:
              commentId,
              replyCount:
              replyCount,
              commentService:
              _commentService,
              onReply:
                  (
                  String parentReplyId,
                  String username,
                  ) {
                _startReply(
                  commentId:
                  commentId,

                  parentReplyId:
                  parentReplyId,

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
      appBar:
      AppBar(),
      body:
      Column(
        children:
        <Widget>[
          //===================================================
          // ORIGINAL POST + COMMENTS
          //===================================================

          Expanded(
            child:
            StreamBuilder<
                DocumentSnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
              _firestore
                  .collection('posts')
                  .doc(
                widget.postId,
              )
                  .snapshots(),
              builder:
                  (
                  BuildContext context,
                  AsyncSnapshot<
                      DocumentSnapshot<
                          Map<String,
                              dynamic>>>
                  postSnapshot,
                  ) {
                return StreamBuilder<
                    QuerySnapshot<
                        Map<String,
                            dynamic>>>(
                  stream:
                  _commentService
                      .getComments(
                    widget.postId,
                  ),
                  builder:
                      (
                      BuildContext context,
                      AsyncSnapshot<
                          QuerySnapshot<
                              Map<String,
                                  dynamic>>>
                      commentSnapshot,
                      ) {
                    if (commentSnapshot
                        .hasError) {
                      return const Center(
                        child:
                        Text(
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
                            Map<String,
                                dynamic>>>
                    comments =
                        commentSnapshot
                            .data!
                            .docs;

                    final int storedCommentTotal =
                        _toInt(postSnapshot.data?.data()?['commentCount']);

                    final int totalCommentCount =
                        storedCommentTotal < comments.length
                            ? comments.length
                            : storedCommentTotal;

                    return NotificationListener<UserScrollNotification>(
                      onNotification: _handleCommentScroll,
                      child: ListView(
                        padding:
                        EdgeInsets.zero,
                        children:
                        <Widget>[
                        //===================================================
                        // ORIGINAL POST
                        //===================================================

                        if (postSnapshot
                            .hasData &&
                            postSnapshot
                                .data !=
                                null &&
                            postSnapshot.data!
                                .exists)
                          Builder(
                            builder:
                                (
                                BuildContext
                                context,
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
                                  forceMediaPaused:
                                  _isPostMediaPaused,
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
                                  child:
                                  Text(
                                    'Unable to display the original post.',
                                    textAlign:
                                    TextAlign
                                        .center,
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
                              vertical:
                              28,
                            ),
                            child:
                            Center(
                              child:
                              CircularProgressIndicator(),
                            ),
                          ),

                        //===================================================
                        // COMMENTS HEADER
                        //===================================================

                        Padding(
                          padding:
                          const EdgeInsets
                              .fromLTRB(
                            14,
                            18,
                            14,
                            8,
                          ),
                          child:
                          Row(
                            children:
                            <Widget>[
                              const Expanded(
                                child:
                                Text(
                                  'Comments',
                                  style:
                                  TextStyle(
                                    fontSize:
                                    22,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                              ),

                              Text(
                                '$totalCommentCount ${totalCommentCount == 1 ? 'comment' : 'comments'}',
                                style:
                                TextStyle(
                                  color:
                                  Colors.grey
                                      .shade600,
                                  fontSize:
                                  13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        //===================================================
                        // COMMENTS
                        //===================================================

                        if (comments
                            .isEmpty)
                          const Padding(
                            padding:
                            EdgeInsets.symmetric(
                              horizontal:
                              20,
                              vertical:
                              35,
                            ),
                            child:
                            Column(
                              children:
                              <Widget>[
                                Icon(
                                  Icons
                                      .chat_bubble_outline,
                                  size:
                                  42,
                                  color:
                                  Colors.grey,
                                ),
                                SizedBox(
                                  height:
                                  10,
                                ),
                                Text(
                                  'No comments yet.',
                                  style:
                                  TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                  4,
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
                                    Map<String,
                                        dynamic>>
                                comment,
                                ) {
                              return _buildComment(
                                comment,
                              );
                            },
                          ),

                        const SizedBox(
                          height:
                          20,
                        ),
                        ],
                      ),
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
                horizontal:
                12,
                vertical:
                8,
              ),
              color:
              Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              child:
              Row(
                children:
                <Widget>[
                  Expanded(
                    child:
                    Text(
                      'Replying to @$_replyingToUsername',
                      style:
                      TextStyle(
                        color:
                        Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize:
                        13,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed:
                    _cancelReply,
                    icon:
                    const Icon(
                      Icons.close,
                      size:
                      20,
                    ),
                  ),
                ],
              ),
            ),

          //===================================================
          // SELECTED COMMENT / REPLY IMAGE PREVIEW
          //===================================================

          if (_selectedCommentImage !=
              null)
            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                4,
              ),
              child:
              Align(
                alignment:
                Alignment.centerLeft,
                child:
                Stack(
                  clipBehavior:
                  Clip.none,
                  children:
                  <Widget>[
                    ClipRRect(
                      borderRadius:
                      BorderRadius
                          .circular(
                        14,
                      ),
                      child:
                      Image.file(
                        File(
                          _selectedCommentImage!
                              .path,
                        ),
                        width:
                        110,
                        height:
                        110,
                        fit:
                        BoxFit.cover,
                      ),
                    ),

                    Positioned(
                      top:
                      -7,
                      right:
                      -7,
                      child:
                      Material(
                        color:
                        Colors.black87,
                        shape:
                        const CircleBorder(),
                        child:
                        InkWell(
                          customBorder:
                          const CircleBorder(),
                          onTap:
                          _removeSelectedCommentImage,
                          child:
                          const Padding(
                            padding:
                            EdgeInsets.all(
                              5,
                            ),
                            child:
                            Icon(
                              Icons
                                  .close_rounded,
                              color:
                              Colors.white,
                              size:
                              17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          //===================================================
          // COMMENT INPUT
          //
          // PHOTO BUTTON IS ALWAYS VISIBLE FOR BOTH:
          // - NORMAL COMMENT
          // - REPLY
          //===================================================

          SafeArea(
            top:
            false,
            child:
            Container(
              padding:
              const EdgeInsets
                  .fromLTRB(
                8,
                8,
                8,
                8,
              ),
              child:
              Row(
                crossAxisAlignment:
                CrossAxisAlignment
                    .end,
                children:
                <Widget>[
                  //===================================================
                  // ADD PICTURE
                  //===================================================

                  IconButton(
                    tooltip:
                    'Add picture',
                    onPressed:
                    _isSending
                        ? null
                        : _showCommentImageOptions,
                    icon:
                    Icon(
                      _selectedCommentImage !=
                          null
                          ? Icons.image_rounded
                          : Icons
                          .add_photo_alternate_outlined,

                      color:
                      const Color(
                        0xFF29B6F6,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width:
                    2,
                  ),

                  Expanded(
                    child:
                    TextField(
                      controller:
                      _commentController,
                      focusNode:
                      _commentFocusNode,
                      minLines:
                      1,
                      maxLines:
                      5,
                      textInputAction:
                      TextInputAction
                          .newline,
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
                          BorderRadius
                              .circular(
                            24,
                          ),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
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
                        const EdgeInsets
                            .symmetric(
                          horizontal:
                          16,
                          vertical:
                          10,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width:
                    4,
                  ),

                  IconButton(
                    tooltip:
                    _replyingToCommentId !=
                        null
                        ? 'Send reply'
                        : 'Send comment',
                    onPressed:
                    _isSending
                        ? null
                        : _sendComment,
                    icon:
                    _isSending
                        ? const SizedBox(
                      width:
                      20,
                      height:
                      20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
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
// COMMENT NETWORK IMAGE
//===================================================

class _CommentNetworkImage
    extends StatelessWidget {
  const _CommentNetworkImage({
    required this.imageUrl,
    this.maxHeight = 280,
  });

  final String imageUrl;

  final double maxHeight;

  @override
  Widget build(
      BuildContext context,
      ) {
    final String url =
    imageUrl.trim();

    if (url.isEmpty) {
      return const SizedBox
          .shrink();
    }

    return GestureDetector(
      onTap:
          () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder:
                (_) =>
                _CommentImageViewer(
                  imageUrl:
                  url,
                ),
          ),
        );
      },
      child:
      ConstrainedBox(
        constraints:
        BoxConstraints(
          maxWidth:
          310,
          maxHeight:
          maxHeight,
        ),
        child:
        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          child:
          Image.network(
            url,
            fit:
            BoxFit.cover,
            loadingBuilder:
                (
                BuildContext context,
                Widget child,
                ImageChunkEvent?
                progress,
                ) {
              if (progress ==
                  null) {
                return child;
              }

              return Container(
                width:
                220,
                height:
                180,
                alignment:
                Alignment.center,
                color:
                Colors.grey
                    .withOpacity(
                  0.12,
                ),
                child:
                const CircularProgressIndicator(
                  strokeWidth:
                  2,
                  color:
                  Color(
                    0xFF29B6F6,
                  ),
                ),
              );
            },
            errorBuilder:
                (
                BuildContext context,
                Object error,
                StackTrace?
                stackTrace,
                ) {
              return Container(
                width:
                220,
                height:
                150,
                alignment:
                Alignment.center,
                color:
                Colors.grey
                    .withOpacity(
                  0.12,
                ),
                child:
                const Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children:
                  <Widget>[
                    Icon(
                      Icons
                          .broken_image_outlined,
                      color:
                      Colors.grey,
                    ),
                    SizedBox(
                      height:
                      5,
                    ),
                    Text(
                      'Unable to load picture',
                      style:
                      TextStyle(
                        color:
                        Colors.grey,
                        fontSize:
                        11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

//===================================================
// COMMENT IMAGE FULLSCREEN VIEWER
//===================================================

class _CommentImageViewer
    extends StatelessWidget {
  const _CommentImageViewer({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      Colors.black,
      body:
      SafeArea(
        child:
        Stack(
          fit:
          StackFit.expand,
          children:
          <Widget>[
            Center(
              child:
              InteractiveViewer(
                minScale:
                1,
                maxScale:
                5,
                child:
                Image.network(
                  imageUrl,
                  fit:
                  BoxFit.contain,
                  errorBuilder:
                      (
                      BuildContext context,
                      Object error,
                      StackTrace?
                      stackTrace,
                      ) {
                    return const Center(
                      child:
                      Text(
                        'Unable to load picture',
                        style:
                        TextStyle(
                          color:
                          Colors.white70,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            Positioned(
              top:
              4,
              left:
              4,
              child:
              Material(
                color:
                Colors.black54,
                shape:
                const CircleBorder(),
                child:
                IconButton(
                  onPressed:
                      () {
                    Navigator.of(context)
                        .pop();
                  },
                  icon:
                  const Icon(
                    Icons
                        .close_rounded,
                    color:
                    Colors.white,
                    size:
                    28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
  bool _isLiked =
  false;

  bool _loading =
  false;

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
  // KEEP LIVE FIRESTORE COUNT IN SYNC
  //===================================================

  @override
  void didUpdateWidget(
      covariant _CommentLikeButton oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.likeCount !=
        widget.likeCount &&
        !_loading) {
      _count =
          widget.likeCount;
    }
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
        _isLiked =
            liked;
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

    final bool oldLiked =
        _isLiked;

    final int oldCount =
        _count;

    //===================================================
    // OPTIMISTIC COMMENT LIKE
    //
    // CHANGE HEART + COUNT FIRST. FIRESTORE SYNCS AFTER.
    //===================================================

    setState(() {
      _loading =
      true;

      _isLiked =
      !oldLiked;

      if (_isLiked) {
        _count =
            oldCount +
                1;
      } else {
        _count =
        oldCount > 0
            ? oldCount -
            1
            : 0;
      }
    });

    //===================================================
    // DO NOT SHOW A LONG SPINNER
    //===================================================

    await Future<void>.delayed(
      const Duration(
        milliseconds:
        120,
      ),
    );

    if (mounted) {
      setState(() {
        _loading =
        false;
      });
    }

    unawaited(
      widget.commentService
          .toggleCommentLike(
        postId:
        widget.postId,
        commentId:
        widget.commentId,
      )
          .catchError(
        (
        Object error,
        ) {
          debugPrint(
            'Comment like error: $error',
          );

          if (!mounted) {
            return;
          }

          setState(() {
            _isLiked =
                oldLiked;

            _count =
                oldCount;
          });
        },
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
    return GestureDetector(
      onTap:
      _loading
          ? null
          : _toggleLike,
      child:
      Row(
        mainAxisSize:
        MainAxisSize.min,
        children:
        <Widget>[
          Icon(
            _isLiked
                ? Icons.favorite
                : Icons
                .favorite_border,
            size:
            15,
            color:
            _isLiked
                ? const Color(
              0xFF29B6F6,
            )
                : Colors.grey
                .shade600,
          ),

          const SizedBox(
            width:
            3,
          ),

          Text(
            '$_count',
            style:
            TextStyle(
              color:
              Colors.grey
                  .shade600,
              fontSize:
              12,
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

  final Function(
      String parentReplyId,
      String username,
      ) onReply;

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
// THREADED REPLY ITEM
//===================================================

class _ThreadedReplyItem {
  const _ThreadedReplyItem({
    required this.document,
    required this.depth,
    required this.childCount,
  });

  final QueryDocumentSnapshot<
      Map<String, dynamic>>
  document;

  final int depth;

  final int childCount;
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

  int _visibleReplies =
  3;
  final Set<String>
  _expandedReplyIds =
  <String>{};

  //===================================================
  // INT HELPER
  //===================================================

  int _toInt(dynamic value,) {
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

  Future<void> _openUserProfile(String uid,) async {
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
        Map<String, dynamic>> nestedReference =
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
        Map<String, dynamic>> globalReference =
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
  _resolveReplyReference(String replyId,) async {
    final DocumentReference<
        Map<String, dynamic>> commentRef =
    await _resolveCommentReference();

    final DocumentReference<
        Map<String, dynamic>> nestedReplyRef =
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
        Map<String, dynamic>> globalCommentRef =
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
        Map<String, dynamic>> globalReplyRef =
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
        user.uid !=
            ownerUid) {
      return;
    }

    String editedText =
        currentText;

    final String? result =
    await showDialog<String>(
      context:
      context,
      builder:
          (BuildContext dialogContext,) {
        return AlertDialog(
          title:
          const Text(
            'Edit Reply',
          ),
          content:
          TextFormField(
            initialValue:
            currentText,
            autofocus:
            true,
            maxLines:
            5,
            maxLength:
            2000,
            onChanged:
                (String value,) {
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
          actions:
          <Widget>[
            TextButton(
              onPressed:
                  () {
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
              onPressed:
                  () {
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
        result
            .trim()
            .isEmpty) {
      return;
    }

    try {
      final DocumentReference<
          Map<String, dynamic>> replyRef =
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

      //===================================================
      // KEEP PROFILE -> COMMENTS TAB IN SYNC
      //===================================================

      await widget.commentService
          .updateReplyActivity(
        uid:
        ownerUid,
        replyId:
        replyId,
        text:
        result.trim(),
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
        user.uid !=
            ownerUid) {
      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context:
      context,
      builder:
          (BuildContext dialogContext,) {
        return AlertDialog(
          title:
          const Text(
            'Delete Reply?',
          ),
          content:
          const Text(
            'This reply will be permanently deleted.',
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
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        confirmed !=
            true) {
      return;
    }

    try {
      final DocumentReference<
          Map<String, dynamic>> replyRef =
      await _resolveReplyReference(
        replyId,
      );

      //===================================================
      // NEW NESTED REPLY
      //
      // SERVICE ALSO CLEANS STORAGE + PROFILE HISTORY.
      //===================================================

      if (replyRef.path.startsWith(
        'posts/',
      )) {
        await widget.commentService.deleteReply(
          postId:
          widget.postId,
          commentId:
          widget.commentId,
          replyId:
          replyId,
        );
      } else {
        await replyRef.delete();

        await widget.commentService
            .removeReplyActivity(
          uid:
          ownerUid,
          replyId:
          replyId,
        );

        await _decreaseReplyCount();

        await _decreasePostTotalCommentCount();
      }

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
          Map<String, dynamic>> commentRef =
      await _resolveCommentReference();

      await _firestore.runTransaction(
            (Transaction transaction,) async {
          final DocumentSnapshot<
              Map<String, dynamic>> snapshot =
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
              current >
                  0
                  ? current -
                  1
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
  // LEGACY REPLY: DECREASE POST'S COMMENT + REPLY TOTAL
  //===================================================

  Future<void> _decreasePostTotalCommentCount() async {
    try {
      final DocumentReference<Map<String, dynamic>> postRef = _firestore
          .collection('posts')
          .doc(widget.postId);

      await _firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(postRef);

        if (!snapshot.exists) {
          return;
        }

        final int current = _toInt(snapshot.data()?['commentCount']);

        transaction.update(postRef, <String, dynamic>{
          'commentCount': current > 0 ? current - 1 : 0,
        });
      });
    } catch (error) {
      debugPrint('Post comment total error: $error');
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
      context:
      context,
      showDragHandle:
      true,
      builder:
          (BuildContext sheetContext,) {
        return SafeArea(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children:
            <Widget>[
              ListTile(
                leading:
                const Icon(
                  Icons.edit_outlined,
                ),
                title:
                const Text(
                  'Edit Reply',
                ),
                onTap:
                    () {
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
                onTap:
                    () {
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
                height:
                8,
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

  void _showMessage(String message,) {
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
// BUILD THREADED REPLY ORDER
//===================================================

  List<_ThreadedReplyItem>
  _buildThreadedReplies(List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>>
  replies,) {
    final Set<String> ids =
    replies
        .map(
          (document) =>
      document.id,
    )
        .toSet();

    final Map<
        String,
        List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>>
    children =
    <String,
        List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>>{};

    for (final document
    in replies) {
      String parentId =
      (document.data()[
      'parentReplyId'] ??
          '')
          .toString()
          .trim();

      // Old replies and orphan replies
      // behave as direct replies.
      if (parentId.isNotEmpty &&
          !ids.contains(
            parentId,
          )) {
        parentId =
        '';
      }

      children
          .putIfAbsent(
        parentId,
            () =>
        <QueryDocumentSnapshot<
            Map<String, dynamic>>>[],
      )
          .add(
        document,
      );
    }

    final List<
        QueryDocumentSnapshot<
            Map<String, dynamic>>>
    roots =
        children[''] ??
            <QueryDocumentSnapshot<
                Map<String, dynamic>>>[];

    final int rootLimit =
    _visibleReplies >
        roots.length
        ? roots.length
        : _visibleReplies;

    final List<_ThreadedReplyItem>
    output =
    <_ThreadedReplyItem>[];

    void addNode(QueryDocumentSnapshot<
        Map<String, dynamic>>
    document,
        int depth,) {
      final List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>
      nodeChildren =
          children[document.id] ??
              <QueryDocumentSnapshot<
                  Map<String, dynamic>>>[];

      output.add(
        _ThreadedReplyItem(
          document:
          document,

          depth:
          depth,

          childCount:
          nodeChildren.length,
        ),
      );

      if (!_expandedReplyIds.contains(
        document.id,
      )) {
        return;
      }

      for (final child
      in nodeChildren) {
        addNode(
          child,
          depth + 1,
        );
      }
    }

    for (
    int index = 0;
    index < rootLimit;
    index++
    ) {
      addNode(
        roots[index],
        0,
      );
    }

    return output;
  }

  //===================================================
// BUILD
//===================================================

  @override
  Widget build(BuildContext context,) {
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

      builder:
          (BuildContext context,
          AsyncSnapshot<
              QuerySnapshot<
                  Map<String, dynamic>>>
          snapshot,) {
        if (!snapshot.hasData) {
          return const SizedBox
              .shrink();
        }

        final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        replies =
            snapshot.data!
                .docs;

        if (replies.isEmpty) {
          return const SizedBox
              .shrink();
        }

        //===================================================
        // BUILD DIRECT-PARENT TREE
        //===================================================

        final List<_ThreadedReplyItem>
        threadedReplies =
        _buildThreadedReplies(
          replies,
        );

        final int directReplyCount =
            replies
                .where(
                  (QueryDocumentSnapshot<
                  Map<String, dynamic>>
              document,) {
                final String parent =
                (document.data()[
                'parentReplyId'] ??
                    '')
                    .toString()
                    .trim();

                return parent.isEmpty;
              },
            )
                .length;

        return Padding(
          padding:
          const EdgeInsets.only(
            left:
            18,

            top:
            8,
          ),

          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children:
            <Widget>[
              for (
              final _ThreadedReplyItem item
              in threadedReplies
              )
                _buildReply(
                  item,
                ),

              if (directReplyCount >
                  _visibleReplies)
                Padding(
                  padding:
                  const EdgeInsets.only(
                    left:
                    38,

                    top:
                    5,
                  ),

                  child:
                  GestureDetector(
                    onTap:
                        () {
                      setState(() {
                        _visibleReplies +=
                        3;
                      });
                    },

                    child:
                    Text(
                      'View more replies',

                      style:
                      TextStyle(
                        color:
                        Colors.grey
                            .shade700,

                        fontWeight:
                        FontWeight.bold,

                        fontSize:
                        13,
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

  Widget _buildReply(_ThreadedReplyItem item,) {
    final QueryDocumentSnapshot<
        Map<String, dynamic>>
    document =
        item.document;

    final int depth =
        item.depth;

    final int childCount =
        item.childCount;

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

    final String imageUrl =
    (data['imageUrl'] ??
        data['mediaUrl'] ??
        '')
        .toString()
        .trim();

    final int likeCount =
    _toInt(
      data['likeCount'],
    );

    final bool edited =
        data['edited'] ==
            true;

    final Timestamp? createdAt =
    data['createdAt'] is Timestamp
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
        _auth.currentUser !=
            null &&
            uid.isNotEmpty &&
            _auth.currentUser!.uid ==
                uid;

    final double threadIndent =
        depth * 22.0;

    return Padding(
      padding:
      EdgeInsets.only(
        left:
        threadIndent,
      ),

      child:
      IntrinsicHeight(
        child:
        Row(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,

          children:
          <Widget>[
//===================================================
// VERTICAL REPLY LINE
//===================================================

            Container(
              width:
              2,

              margin:
              const EdgeInsets.only(
                right:
                10,
              ),

              color:
              Colors.grey.shade600,
            ),

//===================================================
// REPLY PROFILE PICTURE
//===================================================

            Align(
              alignment:
              Alignment.topCenter,

              child:
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

                child:
                CircleAvatar(
                  radius:
                  16,

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

                    size:
                    16,

                    color:
                    Colors.white,
                  )
                      : null,
                ),
              ),
            ),

            const SizedBox(
              width:
              8,
            ),

//===================================================
// REPLY CONTENT
//===================================================

            Expanded(
              child:
              Padding(
                padding:
                const EdgeInsets.only(
                  bottom:
                  10,
                ),

                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children:
                  <Widget>[
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

                      child:
                      Wrap(
                        crossAxisAlignment:
                        WrapCrossAlignment.center,

                        spacing:
                        5,

                        runSpacing:
                        2,

                        children:
                        <Widget>[
                          Text(
                            displayName,

                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight.bold,

                              fontSize:
                              13,
                            ),
                          ),

                          if (username.isNotEmpty)
                            Text(
                              '@$username',

                              style:
                              TextStyle(
                                color:
                                Colors.grey.shade600,

                                fontSize:
                                11,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height:
                      2,
                    ),

                  //===================================================
                  // REPLY TEXT
                    // ===================================================

                    if (text
                        .trim()
                        .isNotEmpty)
                      UniversalLinkText(
                        text:
                        text,

                        compactPreview:
                        true,

                        style:
                        const TextStyle(
                          fontSize:
                          14,
                        ),
                      ),
//===================================================
// REPLY IMAGE
//===================================================

                    if (imageUrl.isNotEmpty)
                      Padding(
                        padding:
                        EdgeInsets.only(
                          top:
                          text
                              .trim()
                              .isNotEmpty
                              ? 7
                              : 2,
                        ),

                        child:
                        _CommentNetworkImage(
                          imageUrl:
                          imageUrl,

                          maxHeight:
                          220,
                        ),
                      ),

                    const SizedBox(
                      height:
                      4,
                    ),

//===================================================
// TIME + EDITED + REPLY + LIKE
//===================================================

                    Wrap(
                      crossAxisAlignment:
                      WrapCrossAlignment.center,

                      spacing:
                      11,

                      runSpacing:
                      4,

                      children:
                      <Widget>[
                        NubifyTimeText
                            .fromTimestamp(
                          timestamp:
                          createdAt,

                          showWeeksForOlderDates:
                          true,

                          style:
                          TextStyle(
                            color:
                            Colors.grey.shade600,

                            fontSize:
                            11,
                          ),
                        ),

                        if (edited)
                          Text(
                            'edited',

                            style:
                            TextStyle(
                              color:
                              Colors.grey.shade500,

                              fontSize:
                              10,

                              fontStyle:
                              FontStyle.italic,
                            ),
                          ),

//===================================================
// REPLY TO EXACT PARENT
//===================================================

                        GestureDetector(
                          onTap:
                              () {
                            widget.onReply(
                              replyId,
                              username,
                            );
                          },

                          child:
                          Text(
                            'Reply',

                            style:
                            TextStyle(
                              color:
                              Colors.grey.shade700,

                              fontWeight:
                              FontWeight.bold,

                              fontSize:
                              11,
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

//===================================================
// CHILD REPLY COUNT
//===================================================

                    if (childCount > 0)
                      Padding(
                        padding:
                        const EdgeInsets.only(
                          top:
                          6,
                        ),

                        child:
                        GestureDetector(
                          onTap:
                              () {
                            setState(() {
                              if (_expandedReplyIds
                                  .contains(
                                replyId,
                              )) {
                                _expandedReplyIds
                                    .remove(
                                  replyId,
                                );
                              } else {
                                _expandedReplyIds
                                    .add(
                                  replyId,
                                );
                              }
                            });
                          },

                          child:
                          Text(
                            _expandedReplyIds
                                .contains(
                              replyId,
                            )
                                ? 'Hide replies'
                                : 'View $childCount ${childCount == 1
                                ? 'reply'
                                : 'replies'}',

                            style:
                            const TextStyle(
                              color:
                              Color(
                                0xFF29B6F6,
                              ),

                              fontWeight:
                              FontWeight.w700,

                              fontSize:
                              11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

//===================================================
// OWNER MENU
//===================================================

            if (isOwner)
              Align(
                alignment:
                Alignment.topCenter,

                child:
                IconButton(
                  visualDensity:
                  VisualDensity.compact,

                  onPressed:
                      () {
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

                    size:
                    18,
                  ),
                ),
              ),
          ],
        ),
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
  bool _isLiked =
  false;

  bool _loading =
  false;

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
  // KEEP LIVE FIRESTORE COUNT IN SYNC
  //===================================================

  @override
  void didUpdateWidget(
      covariant _ReplyLikeButton oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.likeCount !=
        widget.likeCount &&
        !_loading) {
      _count =
          widget.likeCount;
    }
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
        _isLiked =
            liked;
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

    final bool oldLiked =
        _isLiked;

    final int oldCount =
        _count;

    setState(() {
      _loading =
      true;

      _isLiked =
      !oldLiked;

      if (_isLiked) {
        _count =
            oldCount +
                1;
      } else {
        _count =
        oldCount > 0
            ? oldCount -
            1
            : 0;
      }
    });

    await Future<void>.delayed(
      const Duration(
        milliseconds:
        120,
      ),
    );

    if (mounted) {
      setState(() {
        _loading =
        false;
      });
    }

    unawaited(
      widget.commentService
          .toggleReplyLike(
        postId:
        widget.postId,
        commentId:
        widget.commentId,
        replyId:
        widget.replyId,
      )
          .catchError(
        (
        Object error,
        ) {
          debugPrint(
            'Reply like error: $error',
          );

          if (!mounted) {
            return;
          }

          setState(() {
            _isLiked =
                oldLiked;

            _count =
                oldCount;
          });
        },
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
    return GestureDetector(
      onTap:
      _loading
          ? null
          : _toggleLike,
      child:
      Row(
        mainAxisSize:
        MainAxisSize.min,
        children:
        <Widget>[
          Icon(
            _isLiked
                ? Icons.favorite
                : Icons
                .favorite_border,
            size:
            14,
            color:
            _isLiked
                ? const Color(
              0xFF29B6F6,
            )
                : Colors.grey
                .shade600,
          ),

          const SizedBox(
            width:
            3,
          ),

          Text(
            '$_count',
            style:
            TextStyle(
              color:
              Colors.grey
                  .shade600,
              fontSize:
              11,
            ),
          ),
        ],
      ),
    );
  }
}

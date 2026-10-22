import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() =>
      _CreatePostScreenState();
}

class _CreatePostScreenState
    extends State<CreatePostScreen> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _captionController =
  TextEditingController();

  final TextEditingController _pollQuestionController =
  TextEditingController();

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  final ImagePicker _imagePicker =
  ImagePicker();

  // ============================================================
  // MEDIA
  // ============================================================

  List<XFile> _selectedMedia = [];

  // ============================================================
  // POLL
  // ============================================================

  bool _createPoll = false;

  final List<TextEditingController>
  _pollOptionControllers = [];

  // ============================================================
  // TAGS
  // ============================================================

  final List<String> _taggedUserIds = [];

  final List<String> _taggedUserNames = [];

  // ============================================================
  // LOADING
  // ============================================================

  bool _isPosting = false;

  // ============================================================
  // CONSTANTS
  // ============================================================

  static const int _maxMedia = 10;

  static const int _minPollOptions = 2;

  static const int _maxPollOptions = 10;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _addPollOption();
    _addPollOption();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _captionController.dispose();

    _pollQuestionController.dispose();

    for (final controller
    in _pollOptionControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // ADD POLL OPTION
  // ============================================================

  void _addPollOption() {
    if (_pollOptionControllers.length >=
        _maxPollOptions) {
      return;
    }

    setState(() {
      _pollOptionControllers.add(
        TextEditingController(),
      );
    });
  }

  // ============================================================
  // REMOVE POLL OPTION
  // ============================================================

  void _removePollOption(int index) {
    if (_pollOptionControllers.length <=
        _minPollOptions) {
      return;
    }

    final controller =
    _pollOptionControllers.removeAt(index);

    controller.dispose();

    setState(() {});
  }

  // ============================================================
  // MEDIA TYPE
  // ============================================================

  bool _isVideo(XFile file) {
    final String path =
    file.path.toLowerCase();

    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.mkv') ||
        path.endsWith('.webm');
  }

  // ============================================================
  // NUBUZZ DETECTION
  //
  // EXACTLY ONE VIDEO = NUBUZZ
  //
  // 1 image            -> Feed
  // Multiple images    -> Feed
  // 1 video            -> Feed + NUBUZZ
  // Multiple videos    -> Feed
  // Image + video      -> Feed
  // ============================================================

  bool _detectNUBuzz() {
    if (_selectedMedia.length != 1) {
      return false;
    }

    return _isVideo(
      _selectedMedia.first,
    );
  }

  // ============================================================
  // SELECT MEDIA
  // ============================================================

  Future<void> _selectMedia() async {
    try {
      final List<XFile> files =
      await _imagePicker.pickMultipleMedia();

      if (files.isEmpty) {
        return;
      }

      if (files.length > _maxMedia) {
        _showMessage(
          'You can select up to $_maxMedia photos/videos.',
        );
      }

      final List<XFile> limitedFiles =
      files.take(_maxMedia).toList();

      setState(() {
        _selectedMedia = limitedFiles;
      });
    } catch (e) {
      debugPrint(
        'Media selection error: $e',
      );

      _showMessage(
        'Unable to select media.',
      );
    }
  }

  // ============================================================
  // REMOVE MEDIA
  // ============================================================

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  // ============================================================
  // VALIDATE POLL
  // ============================================================

  bool _validatePoll() {
    if (!_createPoll) {
      return true;
    }

    final String question =
    _pollQuestionController.text.trim();

    if (question.isEmpty) {
      _showMessage(
        'Please enter a poll question.',
      );

      return false;
    }

    if (_pollOptionControllers.length <
        _minPollOptions) {
      _showMessage(
        'A poll needs at least 2 options.',
      );

      return false;
    }

    final List<String> options =
    _pollOptionControllers
        .map(
          (controller) =>
          controller.text.trim(),
    )
        .where(
          (text) => text.isNotEmpty,
    )
        .toList();

    if (options.length < 2) {
      _showMessage(
        'Please enter at least 2 poll options.',
      );

      return false;
    }

    final Set<String> uniqueOptions =
    options
        .map(
          (option) =>
          option.toLowerCase(),
    )
        .toSet();

    if (uniqueOptions.length !=
        options.length) {
      _showMessage(
        'Poll options must be different.',
      );

      return false;
    }

    return true;
  }

  //===================================================
// UPLOAD MEDIA + VIDEO THUMBNAILS
//===================================================

  Future<List<Map<String, dynamic>>>
  _uploadMedia() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final List<Map<String, dynamic>>
    uploadedMedia =
    <Map<String, dynamic>>[];

    for (
    int i = 0;
    i < _selectedMedia.length;
    i++
    ) {
      final XFile file =
      _selectedMedia[i];

      final bool video =
      _isVideo(
        file,
      );

      final String extension =
          file.path
              .split('.')
              .last;

      final String baseName =
          '${DateTime.now().microsecondsSinceEpoch}_$i';

      final String fileName =
          '$baseName.$extension';

      final String path =
          'posts/${user.uid}/$fileName';

      final Reference reference =
      _storage
          .ref()
          .child(
        path,
      );

      final TaskSnapshot snapshot =
      await reference.putFile(
        File(
          file.path,
        ),
      );

      final String downloadUrl =
      await snapshot.ref
          .getDownloadURL();

      String thumbnailUrl =
          '';

      //===================================================
      // VIDEO THUMBNAIL
      //===================================================

      if (video) {
        try {
          final Directory temp =
          await getTemporaryDirectory();

          final String? thumbnailPath =
          await VideoThumbnail
              .thumbnailFile(
            video:
            file.path,

            thumbnailPath:
            temp.path,

            imageFormat:
            ImageFormat.JPEG,

            maxWidth:
            720,

            quality:
            82,
          );

          if (thumbnailPath !=
              null) {
            final File thumbFile =
            File(
              thumbnailPath,
            );

            if (await thumbFile
                .exists()) {
              final String thumbStoragePath =
                  'posts/${user.uid}/thumbnails/$baseName.jpg';

              final TaskSnapshot thumbSnapshot =
              await _storage
                  .ref()
                  .child(
                thumbStoragePath,
              )
                  .putFile(
                thumbFile,

                SettableMetadata(
                  contentType:
                  'image/jpeg',
                ),
              );

              thumbnailUrl =
              await thumbSnapshot.ref
                  .getDownloadURL();
            }
          }
        } catch (error) {
          debugPrint(
            'Post thumbnail error: $error',
          );
        }
      }

      uploadedMedia.add(
        <String, dynamic>{
          'url':
          downloadUrl,

          'type':
          video
              ? 'video'
              : 'image',

          'path':
          path,

          'storagePath':
          path,

          'fileName':
          fileName,

          'order':
          i,

          'thumbnailUrl':
          thumbnailUrl,
        },
      );
    }

    return uploadedMedia;
  }
  // ============================================================
  // CREATE POLL DATA
  // ============================================================

  Map<String, dynamic>? _buildPollData() {
    if (!_createPoll) {
      return null;
    }

    final List<Map<String, dynamic>>
    options = [];

    for (final controller
    in _pollOptionControllers) {
      final String text =
      controller.text.trim();

      if (text.isEmpty) {
        continue;
      }

      options.add({
        'text': text,
        'votes': 0,
      });
    }

    final Timestamp now =
    Timestamp.now();

    final Timestamp expiresAt =
    Timestamp.fromDate(
      DateTime.now().add(
        const Duration(hours: 24),
      ),
    );

    return {
      'question':
      _pollQuestionController.text.trim(),
      'options': options,
      'totalVotes': 0,
      'votedUserIds': [],
      'createdAt': now,
      'expiresAt': expiresAt,
      'isExpired': false,
      'winnerOptionIndex': null,
      'winnerText': null,
      'winnerVotes': 0,
    };
  }

  // ============================================================
  // CREATE POST
  // ============================================================

  Future<void> _createPost() async {
    if (_isPosting) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in first.',
      );

      return;
    }

    if (!_validatePoll()) {
      return;
    }

    final String caption =
    _captionController.text.trim();

    if (caption.isEmpty &&
        _selectedMedia.isEmpty &&
        !_createPoll) {
      _showMessage(
        'Write something or add media.',
      );

      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // ----------------------------------------------------------
      // USER DATA
      // ----------------------------------------------------------

      final DocumentSnapshot userSnapshot =
      await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final Map<String, dynamic>
      userData =
      userSnapshot.exists
          ? Map<String, dynamic>.from(
        userSnapshot.data()
        as Map,
      )
          : {};

      final String username =
          userData['username']
              ?.toString() ??
              '';

      final String fullName =
          userData['fullName']
              ?.toString() ??
              '';

      final String photoUrl =
          userData['photoUrl']
              ?.toString() ??
              '';

      // ----------------------------------------------------------
      // POST ID
      // ----------------------------------------------------------

      final DocumentReference postRef =
      _firestore
          .collection('posts')
          .doc();

      final String postId =
          postRef.id;

      // ----------------------------------------------------------
      // UPLOAD MEDIA
      // ----------------------------------------------------------

      final List<Map<String, dynamic>>
      uploadedMedia =
      await _uploadMedia();

      // ----------------------------------------------------------
      // NUBUZZ
      // ----------------------------------------------------------

      final bool isNUBuzz =
      _detectNUBuzz();

      // ----------------------------------------------------------
      // POLL
      // ----------------------------------------------------------

      final Map<String, dynamic>?
      pollData =
      _buildPollData();

      // ----------------------------------------------------------
      // POST TYPE
      // ----------------------------------------------------------

      String postType = 'text';

      if (uploadedMedia.isNotEmpty) {
        postType = isNUBuzz
            ? 'nubuzz'
            : 'media';
      }

      if (pollData != null) {
        postType = 'poll';
      }

      // ----------------------------------------------------------
      // FIRESTORE DATA
      // ----------------------------------------------------------

      final Map<String, dynamic>
      postData = {
        'postId': postId,
        'uid': user.uid,
        'username': username,
        'fullName': fullName,
        'photoUrl': photoUrl,
        'caption': caption,
        'media': uploadedMedia,
        'mediaCount':
        uploadedMedia.length,
        'isNUBuzz': isNUBuzz,
        'postType': postType,
        'hasPoll':
        pollData != null,
        'poll': pollData,
        'taggedUsers':
        _taggedUserNames,
        'taggedUserIds':
        _taggedUserIds,
        'likes': [],
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'repostCount': 0,
        'viewCount': 0,

//==========================
// POST TIME
//==========================

        'createdAt':
        FieldValue.serverTimestamp(),

        'clientCreatedAt':
        Timestamp.now(),
      };

      // ----------------------------------------------------------
      // SAVE POST
      // ----------------------------------------------------------

      await postRef.set(
        postData,
      );
      if (!mounted) {
        return;
      }

//==========================
// RETURN NEW POST ID
//==========================

      Navigator.pop<String>(
        context,
        postId,
      );
    } catch (e) {
      debugPrint(
        'Create post error: $e',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to create post.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // ============================================================
  // TAG USERS
  // ============================================================

  Future<void> _showTagUsers() async {
    final QuerySnapshot snapshot =
    await _firestore
        .collection('users')
        .limit(100)
        .get();

    final List<Map<String, dynamic>>
    users = snapshot.docs.map(
          (doc) {
        final data =
        Map<String, dynamic>.from(
          doc.data() as Map,
        );

        return {
          'uid': doc.id,
          'username':
          data['username']
              ?.toString() ??
              '',
          'fullName':
          data['fullName']
              ?.toString() ??
              '',
          'photoUrl':
          data['photoUrl']
              ?.toString() ??
              '',
        };
      },
    ).toList();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height:
                MediaQuery.of(context)
                    .size
                    .height *
                    0.75,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 12,
                    ),

                    const Text(
                      'Tag People',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Expanded(
                      child:
                      ListView.builder(
                        itemCount:
                        users.length,
                        itemBuilder:
                            (context, index) {
                          final user =
                          users[index];

                          final String uid =
                          user['uid'];

                          final bool selected =
                          _taggedUserIds
                              .contains(
                            uid,
                          );

                          return ListTile(
                            leading:
                            CircleAvatar(
                              backgroundImage:
                              user['photoUrl']
                                  .toString()
                                  .isNotEmpty
                                  ? NetworkImage(
                                user[
                                'photoUrl'],
                              )
                                  : null,
                              child: user[
                              'photoUrl']
                                  .toString()
                                  .isEmpty
                                  ? const Icon(
                                Icons
                                    .person,
                              )
                                  : null,
                            ),

                            title: Text(
                              user['fullName']
                                  .toString()
                                  .isNotEmpty
                                  ? user[
                              'fullName']
                                  : user[
                              'username'],
                            ),

                            subtitle:
                            Text(
                              '@${user['username']}',
                            ),

                            trailing:
                            Icon(
                              selected
                                  ? Icons
                                  .check_circle
                                  : Icons
                                  .radio_button_unchecked,
                              color: selected
                                  ? const Color(
                                0xFF29B6F6,
                              )
                                  : null,
                            ),

                            onTap: () {
                              setModalState(
                                    () {
                                  if (selected) {
                                    _taggedUserIds
                                        .remove(
                                      uid,
                                    );

                                    _taggedUserNames
                                        .remove(
                                      user[
                                      'username'],
                                    );
                                  } else {
                                    _taggedUserIds
                                        .add(
                                      uid,
                                    );

                                    _taggedUserNames
                                        .add(
                                      user[
                                      'username'],
                                    );
                                  }
                                },
                              );

                              setState(
                                    () {},
                              );
                            },
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding:
                      const EdgeInsets.all(
                        16,
                      ),
                      child: SizedBox(
                        width:
                        double.infinity,
                        child:
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );
                          },
                          child:
                          const Text(
                            'Done',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // MEDIA PREVIEW
  // ============================================================

  Widget _buildMediaPreview() {
    if (_selectedMedia.isEmpty) {
      return const SizedBox();
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection:
        Axis.horizontal,
        itemCount:
        _selectedMedia.length,
        itemBuilder:
            (context, index) {
          final XFile file =
          _selectedMedia[index];

          return Container(
            width: 150,
            margin:
            const EdgeInsets.only(
              right: 10,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                  child: _isVideo(file)
                      ? Container(
                    width: 150,
                    height: 180,
                    color: Colors
                        .grey
                        .shade900,
                    child:
                    const Center(
                      child: Icon(
                        Icons
                            .play_circle_fill,
                        color:
                        Colors.white,
                        size: 50,
                      ),
                    ),
                  )
                      : Image.file(
                    File(file.path),
                    width: 150,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),

                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.black
                          .withValues(
                        alpha: 0.65,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        8,
                      ),
                    ),
                    child: Text(
                      '${index + 1}/${_selectedMedia.length}',
                      style:
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),

                if (_isVideo(file))
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration:
                      BoxDecoration(
                        color: Colors.black
                            .withValues(
                          alpha: 0.65,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          8,
                        ),
                      ),
                      child:
                      const Text(
                        'VIDEO',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontSize: 10,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  top: 6,
                  right: 6,
                  child:
                  GestureDetector(
                    onTap: () {
                      _removeMedia(
                        index,
                      );
                    },
                    child: Container(
                      padding:
                      const EdgeInsets
                          .all(
                        5,
                      ),
                      decoration:
                      const BoxDecoration(
                        color: Colors.black54,
                        shape:
                        BoxShape.circle,
                      ),
                      child:
                      const Icon(
                        Icons.close,
                        color:
                        Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // POLL UI
  // ============================================================

  Widget _buildPollSection() {
    if (!_createPoll) {
      return const SizedBox();
    }

    return Container(
      margin:
      const EdgeInsets.only(
        top: 12,
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
        children: [
          // ------------------------------------------------------
          // POLL HEADER
          // ------------------------------------------------------

          Row(
            children: [
              const Icon(
                Icons.poll_outlined,
                color:
                Color(0xFF29B6F6),
              ),

              const SizedBox(
                width: 8,
              ),

              const Expanded(
                child: Text(
                  'Poll',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                onPressed: () {
                  setState(() {
                    _createPoll = false;
                  });
                },
                icon:
                const Icon(
                  Icons.close,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          // ------------------------------------------------------
          // QUESTION
          // ------------------------------------------------------

          TextField(
            controller:
            _pollQuestionController,
            maxLength: 200,
            decoration:
            InputDecoration(
              hintText:
              'Ask a question...',
              border:
              OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          // ------------------------------------------------------
          // OPTIONS
          // ------------------------------------------------------

          ...List.generate(
            _pollOptionControllers.length,
                (index) {
              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 9,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child:
                      TextField(
                        controller:
                        _pollOptionControllers[
                        index],
                        maxLength: 100,
                        decoration:
                        InputDecoration(
                          counterText:
                          '',
                          hintText:
                          'Option ${index + 1}',
                          prefixIcon:
                          const Icon(
                            Icons
                                .radio_button_unchecked,
                          ),
                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_pollOptionControllers
                        .length >
                        _minPollOptions)
                      IconButton(
                        onPressed: () {
                          _removePollOption(
                            index,
                          );
                        },
                        icon:
                        const Icon(
                          Icons
                              .remove_circle_outline,
                          color:
                          Colors.redAccent,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // ------------------------------------------------------
          // ADD OPTION
          // ------------------------------------------------------

          if (_pollOptionControllers.length <
              _maxPollOptions)
            TextButton.icon(
              onPressed:
              _addPollOption,
              icon:
              const Icon(
                Icons.add,
              ),
              label:
              Text(
                'Add option (${_pollOptionControllers.length}/$_maxPollOptions)',
              ),
            ),

          const SizedBox(
            height: 5,
          ),

          // ------------------------------------------------------
          // POLL DURATION
          // ------------------------------------------------------

          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color:
                Colors.grey.shade600,
                size: 19,
              ),

              const SizedBox(
                width: 7,
              ),

              Text(
                'Voting lasts 24 hours',
                style:
                TextStyle(
                  color:
                  Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isNUBuzz =
    _detectNUBuzz();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
        false,

        leading: IconButton(
          icon: const Icon(
            Icons.close,
          ),
          onPressed: _isPosting
              ? null
              : () {
            Navigator.pop(
              context,
            );
          },
        ),

        title: const Text(
          'Create Post',
          style: TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        actions: [
          Padding(
            padding:
            const EdgeInsets.only(
              right: 10,
            ),
            child:
            TextButton(
              onPressed: _isPosting
                  ? null
                  : _createPost,

              child: _isPosting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Post',
                style:
                TextStyle(
                  color:
                  Color(0xFF29B6F6),
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // MAIN POST AREA
            // ==================================================

            Expanded(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    // ==========================================
                    // CAPTION
                    // ==========================================

                    TextField(
                      controller:
                      _captionController,
                      maxLines: null,
                      minLines: 8,
                      maxLength: 5000,
                      textAlignVertical:
                      TextAlignVertical
                          .top,

                      decoration:
                      InputDecoration(
                        hintText:
                        'What is happening on campus?',

                        hintStyle:
                        TextStyle(
                          color: Colors
                              .grey
                              .shade500,
                          fontSize: 16,
                        ),

                        border:
                        InputBorder
                            .none,

                        counterText: '',
                      ),
                    ),

                    // ==========================================
                    // MEDIA PREVIEW
                    // ==========================================

                    _buildMediaPreview(),

                    // ==========================================
                    // NUBUZZ NOTICE
                    // ==========================================

                    if (isNUBuzz)
                      Container(
                        margin:
                        const EdgeInsets
                            .only(
                          top: 12,
                        ),

                        padding:
                        const EdgeInsets
                            .all(
                          12,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          const Color(
                            0xFF29B6F6,
                          ).withValues(
                            alpha: 0.10,
                          ),

                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                        ),

                        child:
                        const Row(
                          children: [
                            Icon(
                              Icons
                                  .play_circle_outline,
                              color:
                              Color(
                                0xFF29B6F6,
                              ),
                            ),

                            SizedBox(
                              width: 8,
                            ),

                            Expanded(
                              child:
                              Text(
                                'This single video will also appear in NUBuzz.',
                                style:
                                TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ==========================================
                    // POLL
                    // ==========================================

                    _buildPollSection(),
                  ],
                ),
              ),
            ),

            // ==================================================
            // BOTTOM CREATE POST OPTIONS
            // ==================================================

            Container(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 18,
                vertical: 12,
              ),

              decoration:
              BoxDecoration(
                border:
                Border(
                  top:
                  BorderSide(
                    color: Colors
                        .grey
                        .shade800,
                  ),
                ),
              ),

              child: Row(
                children: [
                  // ============================================
                  // PHOTO / VIDEO
                  // ============================================

                  GestureDetector(
                    onTap: _isPosting
                        ? null
                        : _selectMedia,

                    child: Row(
                      mainAxisSize:
                      MainAxisSize
                          .min,

                      children: [
                        const Icon(
                          Icons
                              .photo_library_outlined,
                          color:
                          Color(
                            0xFF29B6F6,
                          ),
                          size: 20,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        const Text(
                          'Photo/Video',
                          style:
                          TextStyle(
                            color:
                            Color(
                              0xFF29B6F6,
                            ),
                            fontSize: 12,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 16,
                  ),

                  // ============================================
                  // TAG PEOPLE
                  // ============================================

                  GestureDetector(
                    onTap: _isPosting
                        ? null
                        : _showTagUsers,

                    child: Row(
                      mainAxisSize:
                      MainAxisSize
                          .min,

                      children: [
                        const Icon(
                          Icons
                              .person_add_alt_1,
                          color:
                          Color(
                            0xFF29B6F6,
                          ),
                          size: 20,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        const Text(
                          'Tag People',
                          style:
                          TextStyle(
                            color:
                            Color(
                              0xFF29B6F6,
                            ),
                            fontSize: 12,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 16,
                  ),

                  // ============================================
                  // POLL
                  // ============================================

                  GestureDetector(
                    onTap: _isPosting
                        ? null
                        : () {
                      setState(() {
                        _createPoll =
                        !_createPoll;
                      });
                    },

                    child: Row(
                      mainAxisSize:
                      MainAxisSize
                          .min,

                      children: [
                        Icon(
                          Icons
                              .poll_outlined,

                          color: _createPoll
                              ? Colors.white
                              : const Color(
                            0xFF29B6F6,
                          ),

                          size: 20,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Text(
                          'Poll',

                          style:
                          TextStyle(
                            color: _createPoll
                                ? Colors
                                .white
                                : const Color(
                              0xFF29B6F6,
                            ),

                            fontSize: 12,

                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ============================================
                  // MEDIA COUNT
                  // ============================================

                  if (_selectedMedia
                      .isNotEmpty)
                    Text(
                      '${_selectedMedia.length}/$_maxMedia',

                      style:
                      TextStyle(
                        color: Colors
                            .grey
                            .shade500,
                        fontSize: 12,
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

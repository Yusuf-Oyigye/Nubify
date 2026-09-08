import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/post_actions_service.dart';
import '../widgets/post_card.dart';

//===================================================
// HIDDEN POSTS SCREEN
//===================================================

class HiddenPostsScreen extends StatefulWidget {
  const HiddenPostsScreen({
    super.key,
    this.userId,
  });

  //===================================================
  // Normally null.
  //
  // Current logged-in user is used automatically.
  //===================================================

  final String? userId;

  @override
  State<HiddenPostsScreen> createState() =>
      _HiddenPostsScreenState();
}

//===================================================
// HIDDEN POSTS STATE
//===================================================

class _HiddenPostsScreenState
    extends State<HiddenPostsScreen> {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  //===================================================
  // SERVICE
  //===================================================

  final PostActionsService
  _postActionsService =
  PostActionsService();

  //===================================================
  // STABLE STREAM
  //
  // CREATED ONLY ONCE.
  //
  // THIS ALSO HELPS PREVENT THE:
  // "Stream has already been listened to"
  // PROBLEM.
  //===================================================

  Stream<
      QuerySnapshot<
          Map<String, dynamic>>>?
  _hiddenStream;

  String _uid =
      '';

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _setup();
  }

  //===================================================
  // DID UPDATE
  //===================================================

  @override
  void didUpdateWidget(
      covariant HiddenPostsScreen oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.userId !=
        widget.userId) {
      _setup();

      if (mounted) {
        setState(() {});
      }
    }
  }

  //===================================================
  // SETUP
  //===================================================

  void _setup() {
    _uid =
        (widget.userId ??
            _auth.currentUser?.uid ??
            '')
            .trim();

    if (_uid.isEmpty) {
      _hiddenStream =
      null;

      return;
    }

    _hiddenStream =
        _postActionsService
            .hiddenPostsStream(
          _uid,
        );
  }

  //===================================================
  // IS OWNER
  //===================================================

  bool get _isOwner {
    final String currentUid =
        _auth.currentUser?.uid ??
            '';

    return currentUid.isNotEmpty &&
        currentUid ==
            _uid;
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    //===================================================
    // NOT LOGGED IN
    //===================================================

    if (_uid.isEmpty) {
      return const Scaffold(
        body:
        Center(
          child:
          Text(
            'Please log in to view hidden posts.',
          ),
        ),
      );
    }

    //===================================================
    // PRIVATE PAGE
    //===================================================

    if (!_isOwner) {
      return Scaffold(
        appBar:
        AppBar(
          title:
          const Text(
            'Hidden Posts',
          ),
        ),

        body:
        const Center(
          child:
          Padding(
            padding:
            EdgeInsets.all(
              24,
            ),

            child:
            Text(
              'Hidden posts are private.',

              textAlign:
              TextAlign.center,
            ),
          ),
        ),
      );
    }

    final Stream<
        QuerySnapshot<
            Map<String, dynamic>>>?
    stream =
        _hiddenStream;

    if (stream == null) {
      return const Scaffold(
        body:
        Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar:
      AppBar(
        title:
        const Text(
          'Hidden Posts',

          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body:
      StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream:
        stream,

        builder:
            (
            BuildContext context,
            AsyncSnapshot<
                QuerySnapshot<
                    Map<String, dynamic>>>
            snapshot,
            ) {
          //===================================================
          // LOADING
          //===================================================

          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          //===================================================
          // ERROR
          //===================================================

          if (snapshot.hasError) {
            return _HiddenEmptyState(
              icon:
              Icons
                  .error_outline,

              title:
              'Unable to load hidden posts',

              subtitle:
              '${snapshot.error}',
            );
          }

          final List<
              QueryDocumentSnapshot<
                  Map<String, dynamic>>>
          references =
              snapshot.data?.docs ??
                  <QueryDocumentSnapshot<
                      Map<String, dynamic>>>[];

          //===================================================
          // EMPTY
          //===================================================

          if (references.isEmpty) {
            return const _HiddenEmptyState(
              icon:
              Icons
                  .visibility_outlined,

              title:
              'No hidden posts',

              subtitle:
              'Posts you hide will appear here so you can unhide them later.',
            );
          }

          //===================================================
          // HIDDEN LIST
          //===================================================

          return ListView.builder(
            padding:
            EdgeInsets.zero,

            itemCount:
            references.length,

            itemBuilder:
                (
                BuildContext context,
                int index,
                ) {
              final QueryDocumentSnapshot<
                  Map<String, dynamic>>
              hiddenDocument =
              references[index];

              final Map<String, dynamic>
              hiddenData =
              hiddenDocument.data();

              final String postId =
              (hiddenData['postId'] ??
                  hiddenDocument.id)
                  .toString()
                  .trim();

              if (postId.isEmpty) {
                return const SizedBox
                    .shrink();
              }

              return _HiddenPostLoader(
                key:
                ValueKey<String>(
                  'hidden_$postId',
                ),

                postId:
                postId,

                ownerUid:
                _uid,
              );
            },
          );
        },
      ),
    );
  }
}

//===================================================
// HIDDEN POST LOADER
//===================================================

class _HiddenPostLoader
    extends StatelessWidget {
  const _HiddenPostLoader({
    super.key,
    required this.postId,
    required this.ownerUid,
  });

  final String postId;
  final String ownerUid;

  @override
  Widget build(
      BuildContext context,
      ) {
    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream:
      FirebaseFirestore
          .instance
          .collection(
        'posts',
      )
          .doc(
        postId,
      )
          .snapshots(),

      builder:
          (
          BuildContext context,
          AsyncSnapshot<
              DocumentSnapshot<
                  Map<String, dynamic>>>
          snapshot,
          ) {
        //===================================================
        // LOADING
        //===================================================

        if (snapshot.connectionState ==
            ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding:
            EdgeInsets.all(
              20,
            ),

            child:
            Center(
              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
              ),
            ),
          );
        }

        //===================================================
        // POST WAS DELETED
        //===================================================

        if (!snapshot.hasData ||
            !snapshot.data!.exists ||
            snapshot.data!.data() ==
                null) {
          return _DeletedHiddenReference(
            postId:
            postId,

            ownerUid:
            ownerUid,
          );
        }

        final DocumentSnapshot<
            Map<String, dynamic>>
        document =
        snapshot.data!;

        final Map<String, dynamic> data =
        document.data()!;

        final String postOwnerUid =
        (data['uid'] ?? '')
            .toString()
            .trim();

        //===================================================
        // SECURITY SAFETY
        //
        // DO NOT DISPLAY SOMEBODY ELSE'S POST IN THIS
        // USER'S HIDDEN MANAGEMENT PAGE.
        //===================================================

        if (postOwnerUid !=
            ownerUid) {
          return const SizedBox
              .shrink();
        }

        //===================================================
        // POST WAS ALREADY UNHIDDEN BUT STALE REFERENCE
        // REMAINS.
        //===================================================

        if (data['isHidden'] !=
            true) {
          return _StaleHiddenReference(
            postId:
            postId,

            ownerUid:
            ownerUid,
          );
        }

        try {
          final Post post =
          Post.fromFirestore(
            document,
          );

          //===================================================
          // showHiddenPost = true
          //
          // OTHERWISE PostCard WILL CORRECTLY HIDE IT.
          //===================================================

          return PostCard(
            key:
            ValueKey<String>(
              post.postId,
            ),

            post:
            post,

            isProfileScreen:
            true,

            showHiddenPost:
            true,
          );
        } catch (error) {
          return Padding(
            padding:
            const EdgeInsets.all(
              16,
            ),

            child:
            Text(
              'Unable to display hidden post:\n$error',
            ),
          );
        }
      },
    );
  }
}

//===================================================
// DELETED HIDDEN REFERENCE
//===================================================

class _DeletedHiddenReference
    extends StatelessWidget {
  const _DeletedHiddenReference({
    required this.postId,
    required this.ownerUid,
  });

  final String postId;
  final String ownerUid;

  @override
  Widget build(
      BuildContext context,
      ) {
    return ListTile(
      leading:
      const Icon(
        Icons
            .delete_outline_rounded,
      ),

      title:
      const Text(
        'This post was deleted',
      ),

      subtitle:
      const Text(
        'Remove the old hidden-post reference.',
      ),

      trailing:
      TextButton(
        onPressed:
            () async {
          try {
            await FirebaseFirestore
                .instance
                .collection(
              'users',
            )
                .doc(
              ownerUid,
            )
                .collection(
              'hiddenPosts',
            )
                .doc(
              postId,
            )
                .delete();
          } catch (_) {}
        },

        child:
        const Text(
          'Remove',
        ),
      ),
    );
  }
}

//===================================================
// STALE HIDDEN REFERENCE
//===================================================

class _StaleHiddenReference
    extends StatelessWidget {
  const _StaleHiddenReference({
    required this.postId,
    required this.ownerUid,
  });

  final String postId;
  final String ownerUid;

  @override
  Widget build(
      BuildContext context,
      ) {
    return ListTile(
      leading:
      const Icon(
        Icons
            .visibility_outlined,
      ),

      title:
      const Text(
        'Post is already visible',
      ),

      subtitle:
      const Text(
        'Cleaning old Hidden Posts reference.',
      ),

      trailing:
      TextButton(
        onPressed:
            () async {
          try {
            await FirebaseFirestore
                .instance
                .collection(
              'users',
            )
                .doc(
              ownerUid,
            )
                .collection(
              'hiddenPosts',
            )
                .doc(
              postId,
            )
                .delete();
          } catch (_) {}
        },

        child:
        const Text(
          'Remove',
        ),
      ),
    );
  }
}

//===================================================
// EMPTY STATE
//===================================================

class _HiddenEmptyState
    extends StatelessWidget {
  const _HiddenEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal:
          30,
        ),

        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children:
          <Widget>[
            Icon(
              icon,

              size:
              60,

              color:
              Colors.grey,
            ),

            const SizedBox(
              height:
              12,
            ),

            Text(
              title,

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                fontSize:
                18,

                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
              7,
            ),

            Text(
              subtitle,

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                Colors.grey
                    .shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
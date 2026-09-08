import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/feed_service.dart';
import 'post_card.dart';

class FeedPostList extends StatefulWidget {
  const FeedPostList({
    super.key,
  });

  @override
  State<FeedPostList> createState() =>
      FeedPostListState();
}

class FeedPostListState
    extends State<FeedPostList> {
  final FeedService _feedService =
  FeedService();

  final ScrollController _scrollController =
  ScrollController();

  int _shuffleSeed =
      DateTime.now()
          .microsecondsSinceEpoch;
  //==========================
// NEW POST FOCUS
//==========================

  String _pendingFocusPostId =
      '';

  //===================================================
  // 24-HOUR HOME RULE
  //
  // Posts/reposts from the last 24 hours:
  // - stay first
  // - newest first
  //
  // Posts/reposts older than 24 hours:
  // - are shuffled randomly
  // - reshuffle when Home is tapped
  // - reshuffle on pull-to-refresh
  //
  // Reposts are treated exactly like feed posts.
  // Their own createdAt/repostedAt determines where
  // the repost appears in Home.
  //===================================================

  List<QueryDocumentSnapshot>
  _arrangePosts(
      List<QueryDocumentSnapshot>
      documents,
      ) {
    final DateTime cutoff =
    DateTime.now().subtract(
      const Duration(
        hours: 24,
      ),
    );

    final List<QueryDocumentSnapshot>
    freshPosts =
    <QueryDocumentSnapshot>[];

    final List<QueryDocumentSnapshot>
    olderPosts =
    <QueryDocumentSnapshot>[];

    for (
    final QueryDocumentSnapshot
    document
    in documents
    ) {
      final DateTime createdAt =
      _getCreatedAt(
        document,
      );

      if (!createdAt.isBefore(
        cutoff,
      )) {
        freshPosts.add(
          document,
        );
      } else {
        olderPosts.add(
          document,
        );
      }
    }

    //===================================================
    // FRESH:
    // NEWEST FIRST
    //===================================================

    freshPosts.sort(
          (
          QueryDocumentSnapshot a,
          QueryDocumentSnapshot b,
          ) {
        return _getCreatedAt(
          b,
        ).compareTo(
          _getCreatedAt(
            a,
          ),
        );
      },
    );

    //===================================================
    // OLD:
    // RANDOM UNTIL NEXT DELIBERATE RESHUFFLE
    //===================================================

    olderPosts.shuffle(
      Random(
        _shuffleSeed,
      ),
    );

    return <QueryDocumentSnapshot>[
      ...freshPosts,
      ...olderPosts,
    ];
  }

  //===================================================
  // FILTER PUBLICLY VISIBLE POSTS
  //
  // OWNER HIDE IS GLOBAL.
  //
  // isHidden = this post/repost itself is hidden.
  //
  // isRootHidden = this repost references an original
  // post that its real owner has hidden.
  //===================================================

  List<QueryDocumentSnapshot>
  _visiblePosts(
      List<QueryDocumentSnapshot>
      documents,
      ) {
    return documents.where(
          (
          QueryDocumentSnapshot
          document,
          ) {
        final dynamic raw =
        document.data();

        if (raw is! Map) {
          return false;
        }

        final Map<String, dynamic>
        data =
        Map<String, dynamic>.from(
          raw as Map,
        );

        return _feedService
            .isPubliclyVisible(
          data,
        );
      },
    ).toList();
  }

  //===================================================
  // CREATED AT HELPER
  //===================================================

  DateTime _getCreatedAt(
      QueryDocumentSnapshot document,
      ) {
    final dynamic rawData =
    document.data();

    if (rawData
    is Map<String, dynamic>) {
      dynamic createdAt =
      rawData['createdAt'];

      //===================================================
      // REPOST FALLBACK
      //
      // FOR OLDER/TRANSITION REPOST DOCUMENTS THAT MAY
      // HAVE repostedAt BUT NO createdAt.
      //===================================================

      createdAt ??=
      rawData['clientCreatedAt'] ??
          rawData['repostedAt'];

      if (createdAt
      is Timestamp) {
        return createdAt.toDate();
      }

      if (createdAt
      is DateTime) {
        return createdAt;
      }

      if (createdAt
      is String) {
        return DateTime.tryParse(
          createdAt,
        ) ??
            DateTime
                .fromMillisecondsSinceEpoch(
              0,
            );
      }
    }

    if (rawData is Map) {
      final Map<String, dynamic>
      data =
      Map<String, dynamic>.from(
        rawData,
      );

      dynamic createdAt =
          data['createdAt'] ??
              data['clientCreatedAt'] ??
              data['repostedAt'];

      if (createdAt
      is Timestamp) {
        return createdAt.toDate();
      }

      if (createdAt
      is DateTime) {
        return createdAt;
      }

      if (createdAt
      is String) {
        return DateTime.tryParse(
          createdAt,
        ) ??
            DateTime
                .fromMillisecondsSinceEpoch(
              0,
            );
      }
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      0,
    );
  }
//==========================
// SHOW NEW POST
//
// USED AFTER:
// POST
// REPOST
// QUOTE REPOST
//==========================

  void showNewPost(
      String postId,
      ) {
    final String cleanPostId =
    postId.trim();

    if (!mounted ||
        cleanPostId.isEmpty) {
      return;
    }

    setState(() {
      _pendingFocusPostId =
          cleanPostId;

      _shuffleSeed =
          DateTime.now()
              .microsecondsSinceEpoch;
    });

    //==========================
    // MOVE FEED TO TOP
    //==========================

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        if (!mounted ||
            !_scrollController
                .hasClients) {
          return;
        }

        _scrollController.animateTo(
          0,
          duration:
          const Duration(
            milliseconds:
            300,
          ),
          curve:
          Curves.easeOut,
        );
      },
    );
  }
  //===================================================
  // PUBLIC RESHUFFLE
  //
  // MobileScreenLayout/Home can continue calling this
  // when the Home icon is tapped.
  //===================================================

  Future<void> reshuffleFeed({
    bool scrollToTop = false,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _shuffleSeed =
          DateTime.now()
              .microsecondsSinceEpoch;
    });

    if (scrollToTop) {
      WidgetsBinding.instance
          .addPostFrameCallback(
            (_) {
          if (!mounted ||
              !_scrollController
                  .hasClients) {
            return;
          }

          _scrollController.animateTo(
            0,
            duration:
            const Duration(
              milliseconds:
              300,
            ),
            curve:
            Curves.easeOut,
          );
        },
      );
    }

    await Future<void>.delayed(
      const Duration(
        milliseconds:
        250,
      ),
    );
  }

  //===================================================
  // PULL TO REFRESH
  //===================================================

  Future<void> _onRefresh() async {
    await reshuffleFeed(
      scrollToTop:
      true,
    );
  }

  //===================================================
  // EMPTY FEED
  //===================================================

  Widget _emptyFeed(
      String message,
      ) {
    return RefreshIndicator(
      onRefresh:
      _onRefresh,
      child: ListView(
        controller:
        _scrollController,
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(
            height:
            180,
          ),
          Center(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal:
                20,
              ),
              child: Text(
                message,
                textAlign:
                TextAlign.center,
                style:
                const TextStyle(
                  fontSize:
                  16,
                ),
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
    _scrollController.dispose();

    super.dispose();
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return StreamBuilder<QuerySnapshot>(
      stream:
      _feedService.getPosts(),
      builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot>
          snapshot,
          ) {
        //===================================================
        // LOADING
        //===================================================

        if (snapshot.connectionState ==
            ConnectionState
                .waiting &&
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
          return RefreshIndicator(
            onRefresh:
            _onRefresh,
            child: ListView(
              controller:
              _scrollController,
              physics:
              const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                const SizedBox(
                  height:
                  180,
                ),
                Padding(
                  padding:
                  const EdgeInsets.all(
                    20,
                  ),
                  child: Text(
                    'Something went wrong:\n${snapshot.error}',
                    textAlign:
                    TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        //===================================================
        // NO DATA
        //===================================================

        if (!snapshot.hasData) {
          return _emptyFeed(
            'No posts yet.',
          );
        }

        //===================================================
        // ALL FIRESTORE DOCUMENTS
        //===================================================

        final List<
            QueryDocumentSnapshot>
        allDocuments =
        List<QueryDocumentSnapshot>.from(
          snapshot.data!.docs,
        );

        if (allDocuments.isEmpty) {
          return _emptyFeed(
            'No posts yet.',
          );
        }

        //===================================================
        // REMOVE GLOBALLY HIDDEN POSTS
        //
        // IMPORTANT:
        // WE DO THIS BEFORE 24-HOUR SORTING/SHUFFLING.
        //===================================================

        final List<
            QueryDocumentSnapshot>
        visibleDocuments =
        _visiblePosts(
          allDocuments,
        );

        if (visibleDocuments.isEmpty) {
          return _emptyFeed(
            'No visible posts yet.',
          );
        }
        //===================================================
       // APPLY HOME 24-HOUR RULE
      //===================================================

        final List<
            QueryDocumentSnapshot>
        arrangedDocuments =
        _arrangePosts(
          List<
              QueryDocumentSnapshot>.from(
            visibleDocuments,
          ),
        );

        //==========================
// FOCUS NEW POST
//
// FIRESTORE MAY TAKE A MOMENT TO SEND THE NEW
// DOCUMENT. WHEN IT ARRIVES, PUT THAT EXACT POST
// FIRST AND MOVE THE FEED TO IT.
//==========================

        final String pendingPostId =
            _pendingFocusPostId;

        if (pendingPostId.isNotEmpty) {
          final int pendingIndex =
          arrangedDocuments.indexWhere(
                (
                QueryDocumentSnapshot document,
                ) {
              return document.id ==
                  pendingPostId;
            },
          );

          if (pendingIndex >= 0) {
            //==========================
            // MOVE EXACT POST FIRST
            //==========================

            if (pendingIndex != 0) {
              final QueryDocumentSnapshot
              pendingDocument =
              arrangedDocuments.removeAt(
                pendingIndex,
              );

              arrangedDocuments.insert(
                0,
                pendingDocument,
              );
            }

            //==========================
            // SCROLL TO NEW POST
            //==========================

            WidgetsBinding.instance
                .addPostFrameCallback(
                  (_) {
                if (!mounted) {
                  return;
                }

                if (_scrollController
                    .hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration:
                    const Duration(
                      milliseconds:
                      300,
                    ),
                    curve:
                    Curves.easeOut,
                  );
                }

                //==========================
                // FOCUS COMPLETED
                //==========================

                if (_pendingFocusPostId ==
                    pendingPostId) {
                  setState(() {
                    _pendingFocusPostId =
                    '';
                  });
                }
              },
            );
          }
        }

        //===================================================
        // SCROLLABLE FEED
        //
        // IMPORTANT:
        // NORMAL POSTS + PLAIN REPOSTS + QUOTE REPOSTS
        // ALL ENTER THIS SAME LIST.
        //
        // PostCard decides how each type is rendered.
        //===================================================

        return RefreshIndicator(
          onRefresh:
          _onRefresh,
          child: ListView.builder(
            controller:
            _scrollController,
            padding:
            EdgeInsets.zero,

            physics:
            const AlwaysScrollableScrollPhysics(),

            shrinkWrap:
            false,

            itemCount:
            arrangedDocuments
                .length,

            itemBuilder: (
                BuildContext context,
                int index,
                ) {
              final QueryDocumentSnapshot
              document =
              arrangedDocuments[
              index];

              //===================================================
              // CONVERT FIRESTORE -> POST
              //===================================================

              try {
                final Post post =
                Post.fromFirestore(
                  document,
                );

                //===================================================
                // SECOND VISIBILITY SAFETY
                //===================================================

                if (!post
                    .isPubliclyVisible) {
                  return const SizedBox
                      .shrink();
                }

                //===================================================
                // SAME POSTCARD FOR:
                //
                // NORMAL POST
                // REPOST
                // QUOTE REPOST
                //
                // The upcoming PostCard will render reposts in
                // the Twitter/X/Facebook-style format you showed.
                //===================================================

                return PostCard(
                  key:
                  ValueKey<String>(
                    post.postId,
                  ),

                  post:
                  post,

                  //==========================
                  // NEW REPOST / QUOTE
                  //==========================

                  onNewPostCreated:
                  showNewPost,
                );
              } catch (error) {
                return Padding(
                  padding:
                  const EdgeInsets.all(
                    16,
                  ),
                  child: Text(
                    'Could not display this post:\n$error',
                    style:
                    TextStyle(
                      color:
                      Colors.red
                          .shade700,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}
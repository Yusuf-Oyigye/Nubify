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
  State<FeedPostList> createState() => FeedPostListState();
}

class FeedPostListState extends State<FeedPostList> {
  final FeedService _feedService = FeedService();

  final ScrollController _scrollController =
  ScrollController();

  int _shuffleSeed =
      DateTime.now().microsecondsSinceEpoch;

  // ============================================================
  // 24-HOUR HOME RULE
  //
  // Posts from the last 24 hours:
  // - stay first
  // - newest first
  //
  // Posts older than 24 hours:
  // - are shuffled randomly
  // - reshuffle when Home is tapped or the feed is refreshed
  // ============================================================

  List<QueryDocumentSnapshot> _arrangePosts(
      List<QueryDocumentSnapshot> documents,
      ) {
    final DateTime cutoff =
    DateTime.now().subtract(
      const Duration(hours: 24),
    );

    final List<QueryDocumentSnapshot> freshPosts =
    <QueryDocumentSnapshot>[];

    final List<QueryDocumentSnapshot> olderPosts =
    <QueryDocumentSnapshot>[];

    for (final QueryDocumentSnapshot document in documents) {
      final DateTime createdAt =
      _getCreatedAt(document);

      if (!createdAt.isBefore(cutoff)) {
        freshPosts.add(document);
      } else {
        olderPosts.add(document);
      }
    }

    // Fresh posts remain newest first.
    freshPosts.sort(
          (
          QueryDocumentSnapshot a,
          QueryDocumentSnapshot b,
          ) {
        return _getCreatedAt(b).compareTo(
          _getCreatedAt(a),
        );
      },
    );

    // A fixed seed keeps the random order stable until the user
    // deliberately refreshes or taps Home again.
    olderPosts.shuffle(
      Random(_shuffleSeed),
    );

    return <QueryDocumentSnapshot>[
      ...freshPosts,
      ...olderPosts,
    ];
  }

  // ============================================================
  // CREATED AT HELPER
  // ============================================================

  DateTime _getCreatedAt(
      QueryDocumentSnapshot document,
      ) {
    final dynamic rawData = document.data();

    if (rawData is Map<String, dynamic>) {
      final dynamic createdAt = rawData['createdAt'];

      if (createdAt is Timestamp) {
        return createdAt.toDate();
      }

      if (createdAt is DateTime) {
        return createdAt;
      }

      if (createdAt is String) {
        return DateTime.tryParse(createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // PUBLIC RESHUFFLE
  // ============================================================

  Future<void> reshuffleFeed({
    bool scrollToTop = false,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _shuffleSeed =
          DateTime.now().microsecondsSinceEpoch;
    });

    if (scrollToTop) {
      WidgetsBinding.instance.addPostFrameCallback(
            (_) {
          if (!mounted ||
              !_scrollController.hasClients) {
            return;
          }

          _scrollController.animateTo(
            0,
            duration: const Duration(
              milliseconds: 300,
            ),
            curve: Curves.easeOut,
          );
        },
      );
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 250),
    );
  }

  // ============================================================
  // PULL TO REFRESH
  // ============================================================

  Future<void> _onRefresh() async {
    await reshuffleFeed(
      scrollToTop: true,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _feedService.getPosts(),
      builder: (
          context,
          snapshot,
          ) {
        // ============================================================
        // LOADING
        // ============================================================

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // ============================================================
        // ERROR
        // ============================================================

        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              controller: _scrollController,
              physics:
              const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 180),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Something went wrong:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        // ============================================================
        // NO DATA
        // ============================================================

        if (!snapshot.hasData) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              controller: _scrollController,
              physics:
              const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(
                  child: Text(
                    'No posts yet.',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ============================================================
        // POSTS
        // ============================================================

        final List<QueryDocumentSnapshot> documents =
            snapshot.data!.docs;

        if (documents.isEmpty) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              controller: _scrollController,
              physics:
              const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(
                  child: Text(
                    'No posts yet.',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final List<QueryDocumentSnapshot> arrangedDocuments =
        _arrangePosts(
          List<QueryDocumentSnapshot>.from(documents),
        );

        // ============================================================
        // SCROLLABLE FEED
        // ============================================================

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,

            // Makes sure the ListView can scroll normally.
            physics:
            const AlwaysScrollableScrollPhysics(),

            // Prevents unnecessary overscroll behavior.
            shrinkWrap: false,

            itemCount: arrangedDocuments.length,

            itemBuilder: (
                context,
                index,
                ) {
              final QueryDocumentSnapshot document =
              arrangedDocuments[index];

              // ========================================================
              // CONVERT FIRESTORE DATA TO POST
              // ========================================================

              try {
                final Post post =
                Post.fromFirestore(document);

                return PostCard(
                  key: ValueKey(post.postId),
                  post: post,
                );
              } catch (e) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not display this post:\n$e',
                    style: TextStyle(
                      color: Colors.red.shade700,
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/repost_service.dart';
import '../utils/nubify_time.dart';
import '../widgets/post_card.dart';

//===================================================
// POST ENGAGEMENTS SCREEN
//===================================================

class PostEngagementsScreen extends StatefulWidget {
  const PostEngagementsScreen({
    super.key,
    required this.postId,
    this.initialTab = 0,
  });

  //===================================================
  // IMPORTANT
  //
  // postId MUST BE THE ROOT ORIGINAL POST ID.
  //
  // PostCard already sends:
  // widget.post.rootPostId
  //===================================================

  final String postId;

  //===================================================
  // 0 = QUOTES
  // 1 = REPOSTED BY
  //===================================================

  final int initialTab;

  @override
  State<PostEngagementsScreen> createState() => _PostEngagementsScreenState();
}

//===================================================
// POST ENGAGEMENTS STATE
//===================================================

class _PostEngagementsScreenState extends State<PostEngagementsScreen>
    with SingleTickerProviderStateMixin {
  //===================================================
  // SERVICE
  //===================================================

  final RepostService _repostService = RepostService();

  //===================================================
  // TAB
  //===================================================

  late TabController _tabController;

  //===================================================
  // STABLE STREAMS
  //
  // IMPORTANT:
  // THESE ARE CREATED ONCE.
  //
  // DO NOT CREATE ONE SINGLE-SUBSCRIPTION STREAM AND
  // GIVE IT TO MULTIPLE StreamBuilders.
  //
  // THIS AVOIDS:
  // Bad state: Stream has already been listened to
  //===================================================

  late Stream<List<Map<String, dynamic>>> _quotesStream;

  late Stream<List<Map<String, dynamic>>> _repostedByStream;

  late Stream<List<Map<String, dynamic>>> _allEngagementsStream;

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

    final int safeInitialTab = widget.initialTab.clamp(0, 1).toInt();

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: safeInitialTab,
    );

    _createStreams();
  }

  //===================================================
  // DID UPDATE
  //===================================================

  @override
  void didUpdateWidget(covariant PostEngagementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.postId != widget.postId) {
      _createStreams();

      if (mounted) {
        setState(() {});
      }
    }
  }

  //===================================================
  // CREATE STABLE STREAMS
  //===================================================

  void _createStreams() {
    // One shared Firestore listener supplies both tabs and
    // both tab counters. This prevents duplicate reads when
    // the title and the list are visible at the same time.
    _allEngagementsStream = _repostService.watchRepostEngagements(
      widget.postId,
    );

    _quotesStream = _allEngagementsStream.map((
      List<Map<String, dynamic>> engagements,
    ) {
      return engagements.where(_isQuoteEngagement).toList();
    }).asBroadcastStream();

    _repostedByStream = _allEngagementsStream.map((
      List<Map<String, dynamic>> engagements,
    ) {
      return engagements
          .where((Map<String, dynamic> data) => !_isQuoteEngagement(data))
          .toList();
    }).asBroadcastStream();
  }

  bool _isQuoteEngagement(Map<String, dynamic> data) {
    final String type = (data['repostType'] ?? '').toString().trim();

    final String quote = (data['repostText'] ?? data['repostCaption'] ?? '')
        .toString()
        .trim();

    return type == 'quote' || quote.isNotEmpty;
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post Engagements',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(53),
          child: TabBar(
            controller: _tabController,
            indicatorColor: _blue,
            indicatorWeight: 3,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Colors.grey,
            tabs: <Widget>[
              _EngagementTabTitle(
                stream: _quotesStream,
                label: 'Quotes',
                icon: Icons.edit_outlined,
              ),

              _EngagementTabTitle(
                stream: _repostedByStream,
                label: 'Reposted by',
                icon: Icons.repeat_rounded,
              ),
            ],
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          //===================================================
          // QUOTES
          //===================================================

          _QuotesTab(stream: _quotesStream),

          //===================================================
          // REPOSTED BY
          //===================================================
          _RepostedByTab(rootPostId: widget.postId, stream: _repostedByStream),
        ],
      ),
    );
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }
}

//===================================================
// ENGAGEMENT TAB TITLE
//===================================================

class _EngagementTabTitle extends StatelessWidget {
  const _EngagementTabTitle({
    required this.stream,
    required this.label,
    required this.icon,
  });

  final Stream<List<Map<String, dynamic>>> stream;

  final String label;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            final int count = snapshot.data?.length ?? 0;

            return Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 19),

                  const SizedBox(width: 6),

                  Flexible(
                    child: Text(
                      '$label $count',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }
}

//===================================================
// QUOTES TAB
//===================================================

class _QuotesTab extends StatelessWidget {
  const _QuotesTab({required this.stream});

  final Stream<List<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            //===================================================
            // LOADING
            //===================================================

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            //===================================================
            // ERROR
            //===================================================

            if (snapshot.hasError) {
              return _EngagementEmptyState(
                icon: Icons.error_outline,
                message: 'Unable to load quotes.\n${snapshot.error}',
              );
            }

            final List<Map<String, dynamic>> quotes =
                snapshot.data ?? <Map<String, dynamic>>[];

            //===================================================
            // EMPTY
            //===================================================

            if (quotes.isEmpty) {
              return const _EngagementEmptyState(
                icon: Icons.format_quote_outlined,
                message: 'No quote reposts yet.',
              );
            }

            //===================================================
            // QUOTE LIST
            //
            // EACH QUOTE REPOST IS ITS OWN REAL POST.
            //===================================================

            return ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: quotes.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> quote = quotes[index];

                final String quotePostId = (quote['postId'] ?? '')
                    .toString()
                    .trim();

                if (quotePostId.isEmpty) {
                  return const SizedBox.shrink();
                }

                // The engagement query already contains the full,
                // live quote post. Build it directly instead of
                // opening another Firestore listener for every row.
                try {
                  final Post post = Post.fromMap(
                    quote,
                    documentId: quotePostId,
                  );

                  return PostCard(
                    key: ValueKey<String>('quote_${post.postId}'),
                    post: post,
                  );
                } catch (error) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Unable to display this quote repost:\n$error'),
                  );
                }
              },
            );
          },
    );
  }
}

//===================================================
// REPOSTED BY TAB
//===================================================

class _RepostedByTab extends StatelessWidget {
  const _RepostedByTab({required this.rootPostId, required this.stream});

  final String rootPostId;

  final Stream<List<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _EngagementEmptyState(
                icon: Icons.error_outline,
                message: 'Unable to load reposts.\n${snapshot.error}',
              );
            }

            final List<Map<String, dynamic>> reposts =
                snapshot.data ?? <Map<String, dynamic>>[];

            if (reposts.isEmpty) {
              return const _EngagementEmptyState(
                icon: Icons.repeat_rounded,
                message: 'Nobody has reposted this post yet.',
              );
            }

            return ListView.separated(
              itemCount: reposts.length,

              separatorBuilder: (BuildContext context, int index) {
                return const Divider(height: 1);
              },

              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> repost = reposts[index];

                return _RepostedByTile(data: repost, rootPostId: rootPostId);
              },
            );
          },
    );
  }
}

//===================================================
// REPOSTED BY TILE
//===================================================

class _RepostedByTile extends StatelessWidget {
  const _RepostedByTile({required this.data, required this.rootPostId});

  final Map<String, dynamic> data;

  final String rootPostId;

  @override
  Widget build(BuildContext context) {
    final String uid = (data['uid'] ?? data['repostedByUid'] ?? '')
        .toString()
        .trim();

    final String fullName =
        (data['fullName'] ?? data['repostedByFullName'] ?? '')
            .toString()
            .trim();

    final String username =
        (data['username'] ?? data['repostedByUsername'] ?? '')
            .toString()
            .trim();

    final String photoUrl =
        (data['photoUrl'] ?? data['repostedByPhotoUrl'] ?? '')
            .toString()
            .trim();

    final dynamic repostedAt = data['repostedAt'] ?? data['createdAt'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),

      onTap: uid.isEmpty
          ? null
          : () {
              Navigator.of(context).pushNamed('/profile', arguments: uid);
            },

      //===================================================
      // USER AVATAR
      //===================================================
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
      ),

      //===================================================
      // FULL NAME
      //===================================================
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              fullName.isNotEmpty
                  ? fullName
                  : username.isNotEmpty
                  ? username
                  : 'Nubify User',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),

          const SizedBox(width: 6),

          const Icon(Icons.repeat_rounded, color: Color(0xFF29B6F6), size: 17),
        ],
      ),

      //===================================================
      // USERNAME + TIME
      //===================================================
      subtitle: Row(
        children: <Widget>[
          if (username.isNotEmpty)
            Flexible(
              child: Text(
                '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          if (username.isNotEmpty && repostedAt != null) const Text(' · '),

          if (repostedAt is Timestamp)
            Flexible(
              child: NubifyTimeText.fromTimestamp(
                timestamp: repostedAt,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
        ],
      ),

      trailing: const Icon(Icons.chevron_right),
    );
  }
}

//===================================================
// EMPTY STATE
//===================================================

class _EngagementEmptyState extends StatelessWidget {
  const _EngagementEmptyState({required this.icon, required this.message});

  final IconData icon;

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: Colors.grey),

            const SizedBox(height: 12),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

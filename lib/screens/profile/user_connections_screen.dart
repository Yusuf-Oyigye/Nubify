import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/profile/username_rules.dart';

import '../../services/profile/profile_service.dart';
import 'profile_screen.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// FOLLOWERS / FOLLOWING
//===================================================

class UserConnectionsScreen extends StatelessWidget {
  const UserConnectionsScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  final String userId;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Connections'),
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: context.tr('Followers')),
              Tab(text: context.tr('Following')),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _ConnectionList(userId: userId, field: 'followers'),
            _ConnectionList(userId: userId, field: 'following'),
          ],
        ),
      ),
    );
  }
}

class _ConnectionList extends StatefulWidget {
  const _ConnectionList({required this.userId, required this.field});

  final String userId;
  final String field;

  @override
  State<_ConnectionList> createState() => _ConnectionListState();
}

class _ConnectionListState extends State<_ConnectionList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final String next = UsernameRules.searchKey(_searchController.text);
    if (next == _query || !mounted) {
      return;
    }
    setState(() => _query = next);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(widget.userId).snapshots(),
      builder: (context, profileSnapshot) {
        if (!profileSnapshot.hasData &&
            profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (profileSnapshot.hasError) {
          return _ConnectionsErrorState(
            message: context.tr('Could not load this profile\'s connections.'),
            onRetry: () => setState(() {}),
          );
        }

        final Map<String, dynamic> data =
            profileSnapshot.data?.data() ?? <String, dynamic>{};
        final List<String> ids = data[widget.field] is List
            ? (data[widget.field] as List<dynamic>)
                  .map((item) => item.toString().trim())
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .toList()
            : <String>[];

        if (ids.isEmpty) {
          return _connectionBody(<_ConnectionUser>[]);
        }

        final Set<String> connectionIds = ids.toSet();

        // Use the same live users collection already used by Nubify's chat and
        // people pickers. This avoids one failed document request making the
        // complete followers/following list appear empty.
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData &&
                usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (usersSnapshot.hasError) {
              return _ConnectionsErrorState(
                message: context.tr('Could not load users right now.'),
                onRetry: () => setState(() {}),
              );
            }

            final List<_ConnectionUser> allUsers =
                (usersSnapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .where((document) => connectionIds.contains(document.id))
                    .map(_ConnectionUser.fromSnapshot)
                    .toList()
                  ..sort(
                    (a, b) => a.displayName.toLowerCase().compareTo(
                      b.displayName.toLowerCase(),
                    ),
                  );

            return _connectionBody(allUsers);
          },
        );
      },
    );
  }

  Widget _connectionBody(List<_ConnectionUser> allUsers) {
    final List<_ConnectionUser> users = _query.isEmpty
        ? allUsers
        : allUsers.where((user) {
            return user.displayName.toLowerCase().contains(_query) ||
                user.username.toLowerCase().contains(_query);
          }).toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.field == 'followers'
                  ? context.tr('Search followers')
                  : context.tr('Search following'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? _ConnectionsEmptyState(
                  searching: _query.isNotEmpty,
                  followers: widget.field == 'followers',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: users.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 78),
                  itemBuilder: (context, index) =>
                      _ConnectionUserTile(user: users[index]),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }
}

//===================================================
// FIND FRIENDS / USERS
//===================================================

class UserDirectoryScreen extends StatefulWidget {
  const UserDirectoryScreen({super.key});

  @override
  State<UserDirectoryScreen> createState() => _UserDirectoryScreenState();
}

class _UserDirectoryScreenState extends State<UserDirectoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final Random _random = Random.secure();
  final Map<String, double> _randomOrder = <String, double>{};
  String _query = '';
  bool _showGrid = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final String next = UsernameRules.searchKey(_searchController.text);
    if (next == _query || !mounted) {
      return;
    }
    setState(() => _query = next);
  }

  double _orderFor(String uid) {
    return _randomOrder.putIfAbsent(uid, _random.nextDouble);
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Discover'),
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: currentUid.isEmpty
            ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
            : _firestore.collection('users').doc(currentUid).snapshots(),
        builder: (context, currentUserSnapshot) {
          final Map<String, dynamic> currentData =
              currentUserSnapshot.data?.data() ?? <String, dynamic>{};
          final Set<String> followingIds = currentData['following'] is List
              ? (currentData['following'] as List<dynamic>)
                    .map((dynamic value) => value.toString())
                    .toSet()
              : <String>{};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _ConnectionsErrorState(
                  message: context.tr('Could not load people right now.'),
                  onRetry: () => setState(() {}),
                );
              }

              final List<_ConnectionUser> allUsers =
                  (snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      .where((document) => document.id != currentUid)
                      .map(_ConnectionUser.fromSnapshot)
                      .toList()
                    ..sort(
                      (a, b) => _orderFor(a.uid).compareTo(_orderFor(b.uid)),
                    );

              final List<_ConnectionUser> users = _query.isEmpty
                  ? allUsers
                  : allUsers.where((user) {
                      return user.displayName.toLowerCase().contains(_query) ||
                          user.username.toLowerCase().contains(_query);
                    }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(context.tr('Find friend and connect'),
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 13),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: context.tr('Search people'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest.withValues(
                          alpha: 0.72,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 19,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _DirectoryViewSwitcher(
                        showGrid: _showGrid,
                        onChanged: (bool showGrid) {
                          if (showGrid != _showGrid) {
                            setState(() => _showGrid = showGrid);
                          }
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: users.isEmpty
                        ? _ConnectionsEmptyState(
                            searching: _query.isNotEmpty,
                            followers: false,
                            directory: true,
                          )
                        : _showGrid
                        ? GridView.builder(
                            key: const PageStorageKey<String>('directory-grid'),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 244,
                                ),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final _ConnectionUser user = users[index];
                              return _DirectoryUserCard(
                                key: ValueKey<String>('grid-${user.uid}'),
                                user: user,
                                isFollowing: followingIds.contains(user.uid),
                              );
                            },
                          )
                        : ListView.separated(
                            key: const PageStorageKey<String>('directory-list'),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                            itemCount: users.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final _ConnectionUser user = users[index];
                              return _DirectoryUserCard(
                                key: ValueKey<String>('list-${user.uid}'),
                                user: user,
                                isFollowing: followingIds.contains(user.uid),
                                compact: true,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }
}

class _DirectoryViewSwitcher extends StatelessWidget {
  const _DirectoryViewSwitcher({
    required this.showGrid,
    required this.onChanged,
  });

  final bool showGrid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _DirectoryViewButton(
            icon: Icons.view_list_rounded,
            tooltip: context.tr('List view'),
            selected: !showGrid,
            onTap: () => onChanged(false),
          ),
          _DirectoryViewButton(
            icon: Icons.grid_view_rounded,
            tooltip: context.tr('Grid view'),
            selected: showGrid,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _DirectoryViewButton extends StatelessWidget {
  const _DirectoryViewButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryUserCard extends StatefulWidget {
  const _DirectoryUserCard({
    super.key,
    required this.user,
    required this.isFollowing,
    this.compact = false,
  });

  final _ConnectionUser user;
  final bool isFollowing;
  final bool compact;

  @override
  State<_DirectoryUserCard> createState() => _DirectoryUserCardState();
}

class _DirectoryUserCardState extends State<_DirectoryUserCard> {
  final ProfileService _profileService = ProfileService();
  bool _busy = false;

  Future<void> _toggleFollow() async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _profileService.toggleFollow(widget.user.uid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Could not update this follow right now.')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _openProfile() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(userId: widget.user.uid),
      ),
    );
  }

  Widget _followButton(ColorScheme colors, {required bool compact}) {
    return FilledButton(
      onPressed: _busy ? null : _toggleFollow,
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
        backgroundColor: widget.isFollowing
            ? colors.secondaryContainer
            : colors.primary,
        foregroundColor: widget.isFollowing
            ? colors.onSecondaryContainer
            : colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (compact) ...<Widget>[
                  Icon(
                    widget.isFollowing
                        ? Icons.check_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    widget.isFollowing ? context.tr('Following') : context.tr('Follow'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (widget.compact) {
      return Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: <Widget>[
                _DirectoryAvatar(user: widget.user, size: 58),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.user.username.isEmpty
                            ? context.tr('View profile')
                            : '@${widget.user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 116,
                  height: 44,
                  child: _followButton(colors, compact: true),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openProfile,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 13),
          child: Column(
            children: <Widget>[
              _DirectoryAvatar(user: widget.user),
              const SizedBox(height: 13),
              Text(
                widget.user.displayName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.user.username.isEmpty
                    ? context.tr('View profile')
                    : '@${widget.user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: _followButton(colors, compact: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryAvatar extends StatelessWidget {
  const _DirectoryAvatar({required this.user, this.size = 78});

  final _ConnectionUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget fallback = Center(
      child: Text(
        user.displayName.isEmpty ? '?' : user.displayName[0].toUpperCase(),
        style: TextStyle(
          color: colors.primary,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer.withValues(alpha: 0.42),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: user.photoUrl.isEmpty
          ? fallback
          : Image.network(
              user.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _ConnectionUser {
  const _ConnectionUser({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String username;
  final String photoUrl;

  factory _ConnectionUser.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final String fullName =
        <dynamic>[data['fullName'], data['name'], data['displayName']]
            .map((dynamic value) => (value ?? '').toString().trim())
            .firstWhere((String value) => value.isNotEmpty, orElse: () => '');
    final String username = (data['username'] ?? '').toString().trim();

    return _ConnectionUser(
      uid: snapshot.id,
      displayName: fullName.isNotEmpty
          ? fullName
          : username.isNotEmpty
          ? username
          : NubifyText.tr('Nubify user'),
      username: username,
      photoUrl: (data['photoUrl'] ?? '').toString().trim(),
    );
  }
}

class _ConnectionUserTile extends StatelessWidget {
  const _ConnectionUserTile({required this.user});

  final _ConnectionUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF29B6F6).withValues(alpha: 0.14),
        backgroundImage: user.photoUrl.isEmpty
            ? null
            : NetworkImage(user.photoUrl),
        child: user.photoUrl.isEmpty
            ? const Icon(Icons.person_rounded, color: Color(0xFF29B6F6))
            : null,
      ),
      title: Text(
        user.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: user.username.isEmpty
          ? null
          : Text(
              '@${user.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ProfileScreen(userId: user.uid),
          ),
        );
      },
    );
  }
}

class _ConnectionsEmptyState extends StatelessWidget {
  const _ConnectionsEmptyState({
    required this.searching,
    required this.followers,
    this.directory = false,
  });

  final bool searching;
  final bool followers;
  final bool directory;

  @override
  Widget build(BuildContext context) {
    final String title = searching
        ? context.tr('No matching users')
        : directory
        ? context.tr('No users available yet')
        : followers
        ? context.tr('No followers yet')
        : context.tr('Not following anyone yet');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.people_outline_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 13),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionsErrorState extends StatelessWidget {
  const _ConnectionsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_rounded,
              size: 50,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 13),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}

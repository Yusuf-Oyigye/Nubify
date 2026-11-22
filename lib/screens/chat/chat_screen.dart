import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/profile/username_rules.dart';

import '../../models/chat/chat_group.dart';
import '../../models/stories/story.dart';
import '../../services/chat/chat_badge_service.dart';
import '../../services/chat/chat_privacy_service.dart';
import '../../services/chat/chat_sevice.dart';
import '../../services/chat/group_chat_service.dart';
import '../../services/stories/story_service.dart';
import '../../widgets/chat/chat_story_avatar.dart';
import '../../widgets/common/nubify_count_badge.dart';
import '../../utils/common/nubify_time.dart';
import 'blocked_users_screen.dart';
import 'conversation_screen.dart';
import 'new_chat_screen.dart';
import 'groups/create_group_screen.dart';
import 'groups/group_chat_screen.dart';
import '../../widgets/common/search_highlight_text.dart';
import 'calls/call_history_tab.dart';
import 'calls/new_call_screen.dart';
import '../../widgets/common/full_photo_viewer.dart';
import '../../widgets/chat/nubify_chat_style.dart';

class _ChatPalette {
  const _ChatPalette({
    required this.canvas,
    required this.surface,
    required this.field,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.divider,
  });

  final Color canvas;
  final Color surface;
  final Color field;
  final Color text;
  final Color muted;
  final Color subtle;
  final Color divider;

  factory _ChatPalette.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;

    return _ChatPalette(
      canvas: theme.scaffoldBackgroundColor,
      surface: scheme.surface,
      field: dark ? const Color(0xFF1A2228) : scheme.surfaceContainerHighest,
      text: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      subtle: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      divider: scheme.outlineVariant,
    );
  }
}

//===============================
// CHAT SCREEN
//===============================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

//===============================
// CHAT SCREEN STATE
//===============================

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ChatService _chatService = ChatService();

  final GroupChatService _groupService = GroupChatService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _conversationsStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _groupsStream;

  final ChatPrivacyService _privacyService = ChatPrivacyService();

  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  late final Stream<List<NubifyStory>> _storiesStream;

  String _search = '';

  int _tabIndex = 0;

  //===============================
  // TAB COUNTS
  //
  // Unread messages, unread group messages and missed
  // calls. They go down as each one is read or seen.
  //===============================

  final List<StreamSubscription<int>> _countSubscriptions =
      <StreamSubscription<int>>[];

  int _messagesUnread = 0;

  int _groupsUnread = 0;

  int _missedCalls = 0;

  void _listenToCounts() {
    _countSubscriptions.addAll(<StreamSubscription<int>>[
      _chatService.totalUnreadCountStream().listen((int count) {
        if (mounted) setState(() => _messagesUnread = count);
      }, onError: (Object _) {}),
      _groupService.totalUnreadCountStream().listen((int count) {
        if (mounted) setState(() => _groupsUnread = count);
      }, onError: (Object _) {}),
      ChatBadgeService.instance.missedCallsStream().listen((int count) {
        if (!mounted) return;
        setState(() => _missedCalls = count);

        // A call missed while you are looking at Calls is seen.
        if (count > 0 && _tabIndex == 2) {
          ChatBadgeService.instance.markCallsSeen();
        }
      }, onError: (Object _) {}),
    ]);
  }
  //===============================
  // USER CACHE
  //===============================

  static final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
  _sharedUserFutureCache =
      <String, Future<DocumentSnapshot<Map<String, dynamic>>>>{};

  //===============================
  // GET CACHED USER
  //===============================

  Future<DocumentSnapshot<Map<String, dynamic>>> _cachedUser(String uid) {
    return _sharedUserFutureCache.putIfAbsent(uid, () async {
      final DocumentReference<Map<String, dynamic>> reference = _firestore
          .collection('users')
          .doc(uid);

      // Paint a previously loaded identity immediately from Firestore's
      // local database, then use the network only when no cached copy exists.
      try {
        final DocumentSnapshot<Map<String, dynamic>> cached = await reference
            .get(const GetOptions(source: Source.cache));
        if (cached.exists) {
          return cached;
        }
      } catch (_) {}

      return reference.get(const GetOptions(source: Source.serverAndCache));
    });
  }

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();
    _conversationsStream = _chatService.getConversations();

    _groupsStream = _groupService.getGroups();

    _storiesStream = StoryService().watchActiveStories();
    _privacyService.ensureSettingsExist();

    _listenToCounts();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (mounted) {
          setState(() {
            _tabIndex = _tabController.index;
          });
        }

        // Opening Calls marks missed calls as seen.
        if (_tabController.index == 2) {
          ChatBadgeService.instance.markCallsSeen();
        }
      }
    });

    _searchController.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _search = UsernameRules.searchKey(_searchController.text);
      });
    });
  }

  //===============================
  // OPEN PRIVACY MENU
  //===============================

  //===============================
  // OPEN PRIVACY MENU
  //===============================

  Future<void> _showPrivacyMenu() async {
    bool current = await _privacyService.getReadReceiptsEnabled(
      _auth.currentUser?.uid ?? '',
    );

    if (!mounted) {
      return;
    }

    final _ChatPalette palette = _ChatPalette.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setSheetState,
              ) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const ListTile(
                        title: Text(
                          'Chat privacy',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          'Control read receipts and online visibility.',
                        ),
                      ),

                      SwitchListTile(
                        value: current,
                        activeThumbColor: NubifyChatStyle.readGreenOnSurface,
                        secondary: Icon(
                          Icons.done_all_rounded,
                          color: current
                              ? NubifyChatStyle.readGreenOnSurface
                              : palette.subtle,
                        ),
                        title: const Text('Read receipts'),
                        subtitle: Text(
                          current
                              ? 'Read receipts are on. Messages you have read show green ticks.'
                              : 'Read receipts and online visibility are hidden for both sides.',
                        ),
                        onChanged: (bool value) async {
                          setSheetState(() {
                            current = value;
                          });

                          await _privacyService.setReadReceiptsEnabled(value);
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.block_rounded),
                        title: const Text('Blocked users'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);

                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                              builder: (_) => BlockedUsersScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
        );
      },
    );
  }
  //===============================
  // OPEN NEW MESSAGE
  //===============================

  void _openNewMessage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
  }

  void _openNewCall() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewCallScreen()),
    );
  }

  //===============================
  // DIRECT CHAT LIST
  //===============================

  Widget _buildMessages() {
    final String currentUid = _auth.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _conversationsStream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            //===================================================
            // SORT DIRECT CONVERSATIONS BY LATEST MESSAGE
            //===================================================

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                <QueryDocumentSnapshot<Map<String, dynamic>>>[
                  ...?snapshot.data?.docs,
                ];

            // GET CONVERSATION ACTIVITY TIME
            int activityTime(Map<String, dynamic> data) {
              final dynamic timestamp =
                  data['lastMessageAt'] ??
                  data['createdAt'] ??
                  data['updatedAt'];

              if (timestamp is Timestamp) {
                return timestamp.millisecondsSinceEpoch;
              }

              if (timestamp is DateTime) {
                return timestamp.millisecondsSinceEpoch;
              }

              return 0;
            }

            // NEWEST CONVERSATION FIRST
            docs.sort((a, b) {
              final int aTime = activityTime(a.data());
              final int bTime = activityTime(b.data());

              final int result = bTime.compareTo(aTime);

              return result != 0 ? result : a.id.compareTo(b.id);
            });
            if (docs.isEmpty) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Never present an unexplained blank page while Firestore
                // restores the locally cached conversations.
                return _emptyMessages();
              }

              //===============================
              // SEARCH WITH NO RESULT
              //===============================

              if (_search.isNotEmpty) {
                return _emptyMessages(
                  title: 'No matching conversations',
                  message: 'Try another name or message.',
                  showAction: false,
                );
              }

              return _emptyMessages();
            }

            return StreamBuilder<List<NubifyStory>>(
              stream: _storiesStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<NubifyStory>> storySnapshot,
                  ) {
                    final List<NubifyStory> stories =
                        storySnapshot.data ?? const <NubifyStory>[];

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),

                      itemCount: docs.length,

                      itemBuilder: (BuildContext context, int index) {
                        final QueryDocumentSnapshot<Map<String, dynamic>>
                        document = docs[index];

                        final Map<String, dynamic> data = document.data();

                        final List<String> participants =
                            data['participants'] is List
                            ? (data['participants'] as List)
                                  .map((dynamic item) => item.toString())
                                  .toList()
                            : data['participantIds'] is List
                            ? (data['participantIds'] as List)
                                  .map((dynamic item) => item.toString())
                                  .toList()
                            : <String>[];

                        String otherUid = '';

                        for (final String uid in participants) {
                          if (uid != currentUid) {
                            otherUid = uid;

                            break;
                          }
                        }

                        if (otherUid.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return _DirectConversationTile(
                          conversation: data,

                          otherUid: otherUid,

                          currentUid: currentUid,

                          search: _search,

                          userFuture: _cachedUser(otherUid),

                          privacyService: _privacyService,

                          stories: stories,
                        );
                      },
                    );
                  },
            );
          },
    );
  }
  //===============================
  // GROUPS LIST
  //===============================

  Widget _buildGroups() {
    final _ChatPalette palette = _ChatPalette.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _groupsStream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final groups =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map((document) => ChatGroup.fromDocument(document))
                    .where(
                      (ChatGroup group) =>
                          _search.isEmpty ||
                          group.name.toLowerCase().contains(_search) ||
                          group.lastMessage.toLowerCase().contains(_search),
                    )
                    .toList();
            groups.sort((a, b) {
              final Timestamp? aTimestamp = a.lastMessageAt ?? a.createdAt;

              final Timestamp? bTimestamp = b.lastMessageAt ?? b.createdAt;

              final int aTime = aTimestamp?.millisecondsSinceEpoch ?? 0;

              final int bTime = bTimestamp?.millisecondsSinceEpoch ?? 0;

              final int result = bTime.compareTo(aTime);

              return result != 0 ? result : a.groupId.compareTo(b.groupId);
            });

            //===============================
            // EMPTY GROUPS
            //===============================

            if (groups.isEmpty) {
              if (_search.isNotEmpty) {
                return _emptyMessages(
                  title: 'No matching groups',
                  message: 'Try another group name or message.',
                  showAction: false,
                );
              }
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const NubifyChatEmptyIcon(icon: Icons.groups_2_rounded),

                    const SizedBox(height: 16),

                    Text(
                      'No groups yet',
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Bring your classmates together in one place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.muted),
                    ),

                    const SizedBox(height: 8),

                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateGroupScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.group_add_rounded),
                      label: const Text('Create group'),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.only(top: 4, bottom: 100),
              itemCount: groups.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 88,
                endIndent: 16,
                color: palette.divider.withValues(alpha: 0.45),
              ),
              itemBuilder: (BuildContext context, int index) {
                final ChatGroup group = groups[index];

                return StreamBuilder<int>(
                  stream: _groupService.unreadCountStream(
                    group.groupId,
                    knownGroup: group,
                  ),
                  builder: (context, unreadSnapshot) {
                    final int unread = unreadSnapshot.data ?? 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      leading: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => FullPhotoViewer(
                                title: group.name,
                                photoUrl: group.photoUrl,
                                group: true,
                              ),
                            ),
                          );
                        },
                        child: NubifyChatAvatar(
                          photoUrl: group.photoUrl,
                          radius: 25,
                          group: true,
                        ),
                      ),
                      title: SearchHighlightText(
                        text: group.name,
                        query: _search,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: unread > 0
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                      subtitle: SearchHighlightText(
                        text: group.lastMessage.trim().isNotEmpty
                            ? group.lastMessage
                            : '${group.memberIds.length} members',
                        query: _search,
                        style: TextStyle(
                          color: unread > 0 ? palette.text : palette.muted,
                          fontWeight: unread > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: SizedBox(
                        width: 72,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            if (group.lastMessageAt != null)
                              Text(
                                NubifyTime.formatTimestamp(group.lastMessageAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread > 0
                                      ? NubifyChatStyle.royal
                                      : palette.subtle,
                                  fontSize: 10.5,
                                  fontWeight: unread > 0
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            if (unread > 0) ...<Widget>[
                              const SizedBox(height: 6),
                              NubifyUnreadBadge(count: unread),
                            ],
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupChatScreen(
                              groupId: group.groupId,
                              initialGroup: group,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
    );
  }

  //===============================
  // EMPTY MESSAGES
  //===============================

  Widget _emptyMessages({
    String title = 'No conversations yet',
    String message = 'Start chatting with another Nubify user.',
    bool showAction = true,
  }) {
    final _ChatPalette palette = _ChatPalette.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const NubifyChatEmptyIcon(icon: Icons.forum_rounded),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
          if (showAction) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openNewMessage,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('New message'),
            ),
          ],
        ],
      ),
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final _ChatPalette palette = _ChatPalette.of(context);

    return Scaffold(
      backgroundColor: palette.canvas,

      //===============================
      // APP BAR
      //===============================
      appBar: AppBar(
        backgroundColor: palette.canvas,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: NubifyChatStyle.navyGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: NubifyChatStyle.navy.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            const Text(
              'Chats',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 25,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton.filledTonal(
              tooltip: 'Chat privacy',
              style: IconButton.styleFrom(
                backgroundColor: palette.field,
                foregroundColor: palette.text,
              ),
              onPressed: _showPrivacyMenu,
              icon: const Icon(Icons.tune_rounded, size: 21),
            ),
          ),
        ],
        //===============================
        // TABS
        //===============================

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Column(
            children: <Widget>[
              //===============================
              // SEARCH
              //===============================

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search people, chats or groups',
                    hintStyle: TextStyle(fontSize: 13.5, color: palette.subtle),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: NubifyChatStyle.royal,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    filled: true,
                    fillColor: palette.field,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: NubifyChatStyle.royal.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              //===============================
              // CHAT TABS
              //===============================

              Container(
                height: 48,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: palette.field,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,

                  indicator: BoxDecoration(
                    gradient: NubifyChatStyle.navyGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: NubifyChatStyle.navy.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),

                  indicatorSize: TabBarIndicatorSize.tab,

                  labelColor: Colors.white,

                  unselectedLabelColor: palette.muted,

                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),

                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),

                  dividerColor: Colors.transparent,

                  splashBorderRadius: BorderRadius.circular(12),

                  tabs: <Widget>[
                    _ChatTab(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Messages',
                      count: _messagesUnread,
                    ),
                    _ChatTab(
                      icon: Icons.groups_2_rounded,
                      label: 'Groups',
                      count: _groupsUnread,
                    ),
                    _ChatTab(
                      icon: Icons.call_rounded,
                      label: 'Calls',
                      count: _missedCalls,
                    ),
                  ],
                ),
              ),

              //===============================
              // CLOSE APP BAR TAB COLUMN
              //===============================
            ],
          ),
        ),
      ),

      //===============================
      // BODY
      //===============================
      body: TabBarView(
        controller: _tabController,

        children: <Widget>[
          _buildMessages(),

          _buildGroups(),

          const CallHistoryTab(),
        ],
      ),

      //===============================
      // FLOATING ACTION
      //===============================
      floatingActionButton: NubifyGradientFab(
        tooltip: _tabIndex == 0
            ? 'New message'
            : _tabIndex == 2
            ? 'New call'
            : 'New group',

        onPressed: _tabIndex == 0
            ? _openNewMessage
            : _tabIndex == 2
            ? _openNewCall
            : () {
                Navigator.push(
                  context,

                  MaterialPageRoute<void>(
                    builder: (_) => const CreateGroupScreen(),
                  ),
                );
              },

        icon: _tabIndex == 0
            ? Icons.add_comment_rounded
            : _tabIndex == 2
            ? Icons.add_call
            : Icons.group_add_rounded,
      ),
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    for (final StreamSubscription<int> subscription in _countSubscriptions) {
      subscription.cancel();
    }

    _tabController.dispose();

    _searchController.dispose();

    super.dispose();
  }
}

//===============================
// PILL TAB: ICON + LABEL
//===============================

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;

  // Pending items, shown as a small red number on the icon.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 40,
      child: Semantics(
        label: count > 0 ? '$label, $count new' : label,
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(icon, size: 17),
                if (count > 0)
                  Positioned(
                    top: -7,
                    right: -10,
                    child: NubifyCountBadge(count: count, small: true),
                  ),
              ],
            ),
            SizedBox(width: count > 0 ? 11 : 6),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
//===============================
// DIRECT CONVERSATION TILE
//===============================

class _DirectConversationTile extends StatelessWidget {
  const _DirectConversationTile({
    required this.conversation,
    required this.otherUid,
    required this.currentUid,
    required this.search,
    required this.userFuture,
    required this.privacyService,
    required this.stories,
  });

  final Map<String, dynamic> conversation;

  final String otherUid;

  final String currentUid;

  final String search;

  final Future<DocumentSnapshot<Map<String, dynamic>>> userFuture;

  final ChatPrivacyService privacyService;

  // Active stories, for the ring around the photo.
  final List<NubifyStory> stories;

  //===============================
  // STRING LIST
  //===============================

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.map((dynamic item) => item.toString()).toList();
  }

  //===============================
  // UNREAD COUNT
  //===============================

  int _unreadCount() {
    final dynamic rawCounts = conversation['unreadCounts'];

    if (rawCounts is Map) {
      final dynamic value = rawCounts[currentUid];

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      return int.tryParse(value?.toString() ?? '0') ?? 0;
    }

    //===============================
    // LEGACY CONVERSATION FALLBACK
    //===============================

    final String lastSender =
        (conversation['lastMessageSenderId'] ??
                conversation['lastSenderId'] ??
                '')
            .toString();

    final List<String> readBy = _stringList(conversation['lastMessageReadBy']);

    if (lastSender.isNotEmpty &&
        lastSender != currentUid &&
        !readBy.contains(currentUid)) {
      return 1;
    }

    return 0;
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final _ChatPalette palette = _ChatPalette.of(context);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: userFuture,

      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> user =
                snapshot.data?.data() ?? <String, dynamic>{};

            final String username = (user['username'] ?? '').toString();

            final String fullName = (user['fullName'] ?? '').toString();

            final String photoUrl = (user['photoUrl'] ?? '').toString();

            final String name = fullName.trim().isNotEmpty
                ? fullName
                : username.trim().isNotEmpty
                ? username
                : 'Nubify user';

            final String lastMessage = (conversation['lastMessage'] ?? '')
                .toString();

            if (search.isNotEmpty &&
                !name.toLowerCase().contains(search) &&
                !username.toLowerCase().contains(search) &&
                !lastMessage.toLowerCase().contains(search)) {
              return const SizedBox.shrink();
            }

            final Timestamp? lastMessageAt =
                conversation['lastMessageAt'] is Timestamp
                ? conversation['lastMessageAt'] as Timestamp
                : null;

            final String lastSender =
                (conversation['lastMessageSenderId'] ??
                        conversation['lastSenderId'] ??
                        '')
                    .toString();

            final bool mine = lastSender == currentUid;

            final int unread = _unreadCount();

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 5,
              ),
              leading: NubifyChatStoryAvatar(
                uid: otherUid,
                name: name,
                photoUrl: photoUrl,
                stories: stories,
              ),
              title: SearchHighlightText(
                text: name,

                query: search,

                style: TextStyle(
                  color: palette.text,

                  fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                ),
              ),

              subtitle: Row(
                children: <Widget>[
                  if (mine)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),

                      child: _ConversationStatus(
                        conversation: conversation,

                        otherUid: otherUid,

                        privacyService: privacyService,
                      ),
                    ),

                  Expanded(
                    child: SearchHighlightText(
                      text: lastMessage,

                      query: search,

                      style: TextStyle(
                        color: unread > 0 ? palette.text : palette.muted,

                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

              // ListTile gives trailing children a loose width constraint.
              // An old absolute date (for example "25/10/2026 • 8:20 PM")
              // could therefore claim the whole row and make Flutter reject
              // every conversation tile. Keep this area deliberately compact.
              trailing: SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      NubifyTime.formatTimestamp(lastMessageAt),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: unread > 0
                            ? NubifyChatStyle.royal
                            : palette.subtle,
                        fontSize: 10.5,
                        fontWeight: unread > 0
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    if (unread > 0) ...<Widget>[
                      const SizedBox(height: 6),
                      NubifyUnreadBadge(count: unread),
                    ],
                  ],
                ),
              ),

              onTap: () {
                Navigator.push(
                  context,

                  MaterialPageRoute<void>(
                    builder: (_) => ConversationScreen(
                      otherUserId: otherUid,

                      otherName: name,

                      otherUsername: username,

                      otherPhotoUrl: photoUrl,
                    ),
                  ),
                );
              },
            );
          },
    );
  }
}
//===============================
// CONVERSATION STATUS
//===============================

class _ConversationStatus extends StatelessWidget {
  const _ConversationStatus({
    required this.conversation,
    required this.otherUid,
    required this.privacyService,
  });

  final Map<String, dynamic> conversation;

  final String otherUid;

  final ChatPrivacyService privacyService;

  //===============================
  // STRING LIST
  //===============================

  List<String> _list(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.map((dynamic item) => item.toString()).toList();
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final _ChatPalette palette = _ChatPalette.of(context);
    final List<String> delivered = _list(
      conversation['lastMessageDeliveredTo'],
    );

    final List<String> read = _list(conversation['lastMessageReadBy']);

    if (read.contains(otherUid)) {
      return StreamBuilder<bool>(
        stream: privacyService.mutualActivityStream(otherUid),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          return Icon(
            Icons.done_all_rounded,
            size: 16,
            color: snapshot.data == true
                ? NubifyChatStyle.readGreenOnSurface
                : palette.subtle,
          );
        },
      );
    }

    if (delivered.contains(otherUid)) {
      return Icon(Icons.done_all_rounded, size: 16, color: palette.subtle);
    }

    return Icon(Icons.done_rounded, size: 16, color: palette.subtle);
  }
}

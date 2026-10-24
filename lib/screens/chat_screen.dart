import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_group.dart';
import '../services/chat_privacy_service.dart';
import '../services/chat_sevice.dart';
import '../services/group_chat_service.dart';
import '../utils/nubify_time.dart';
import 'blocked_users_screen.dart';
import 'conversation_screen.dart';
import 'new_chat_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';
import '../widgets/search_highlight_text.dart';
import 'call_history_tab.dart';
import '../widgets/full_photo_viewer.dart';

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
  static const Color _blue = Color(0xFF29B6F6);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ChatService _chatService = ChatService();

  final GroupChatService _groupService = GroupChatService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _conversationsStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _groupsStream;

  final ChatPrivacyService _privacyService = ChatPrivacyService();

  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabController;

  String _search = '';

  int _tabIndex = 0;
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
    _privacyService.ensureSettingsExist();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (mounted) {
          setState(() {
            _tabIndex = _tabController.index;
          });
        }
      }
    });

    _searchController.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _search = _searchController.text.trim().toLowerCase();
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

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151D23),
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
                        activeThumbColor: const Color(0xFFFFC107),
                        secondary: Icon(
                          Icons.done_all_rounded,
                          color: current
                              ? const Color(0xFFFFC107)
                              : Colors.grey,
                        ),
                        title: const Text('Read receipts'),
                        subtitle: Text(
                          current
                              ? 'Read receipts are on. The yellow privacy control shows this setting is active.'
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
                return const SizedBox.shrink();
              }

              return _emptyMessages();
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),

              itemCount: docs.length,

              itemBuilder: (BuildContext context, int index) {
                final QueryDocumentSnapshot<Map<String, dynamic>> document =
                    docs[index];

                final Map<String, dynamic> data = document.data();

                final List<String> participants = data['participants'] is List
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
                return const SizedBox.shrink();
              }
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.groups_2_outlined,
                      color: Colors.white30,
                      size: 54,
                    ),

                    const SizedBox(height: 11),

                    const Text(
                      'No groups yet.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

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
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: groups.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 82, color: Colors.white10),
              itemBuilder: (BuildContext context, int index) {
                final ChatGroup group = groups[index];

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
                    child: CircleAvatar(
                      radius: 27,
                      backgroundColor: const Color(0xFF1B2830),
                      backgroundImage: group.photoUrl.trim().isNotEmpty
                          ? CachedNetworkImageProvider(group.photoUrl)
                          : null,
                      child: group.photoUrl.trim().isEmpty
                          ? const Icon(
                              Icons.groups_rounded,
                              color: Color(0xFF29B6F6),
                            )
                          : null,
                    ),
                  ),
                  title: SearchHighlightText(
                    text: group.name,

                    query: _search,

                    style: const TextStyle(
                      color: Colors.white,

                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: SearchHighlightText(
                    text: group.lastMessage.trim().isNotEmpty
                        ? group.lastMessage
                        : '${group.memberIds.length} members',

                    query: _search,

                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: group.lastMessageAt != null
                      ? Text(
                          NubifyTime.formatTimestamp(group.lastMessageAt),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        )
                      : null,
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
  }

  //===============================
  // EMPTY MESSAGES
  //===============================

  Widget _emptyMessages() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined, color: _blue, size: 39),
          ),
          const SizedBox(height: 14),
          const Text(
            'No conversations yet',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Start chatting with another Nubify user.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openNewMessage,
            icon: const Icon(Icons.add_comment_rounded),
            label: const Text('New message'),
          ),
        ],
      ),
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1116),

      //===============================
      // APP BAR
      //===============================
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1116),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 3,
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _showPrivacyMenu,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
        //===============================
        // TABS
        //===============================

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: <Widget>[
              //===============================
              // SEARCH
              //===============================

              Padding(
                padding: const EdgeInsets.fromLTRB(13, 5, 13, 9),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users, conversations or groups',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1A2228),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              //===============================
              // CHAT TABS
              //===============================

              TabBar(
                controller: _tabController,

                indicatorColor: _blue,

                indicatorWeight: 3,

                labelColor: _blue,

                unselectedLabelColor: Colors.white54,

                dividerColor: Colors.white10,

                tabs: const <Widget>[
                  Tab(
                    icon: Icon(Icons.chat_bubble_rounded, size: 20),

                    text: 'Messages',
                  ),

                  Tab(
                    icon: Icon(Icons.groups_2_rounded, size: 22),

                    text: 'Groups',
                  ),

                  Tab(icon: Icon(Icons.call_rounded, size: 21), text: 'Calls'),
                ],
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
      floatingActionButton: _tabIndex == 2
          ? null
          : FloatingActionButton(
              heroTag: 'chat_fab',

              backgroundColor: _blue,

              foregroundColor: Colors.white,

              onPressed: _tabIndex == 0
                  ? _openNewMessage
                  : () {
                      Navigator.push(
                        context,

                        MaterialPageRoute<void>(
                          builder: (_) => const CreateGroupScreen(),
                        ),
                      );
                    },

              child: Icon(
                _tabIndex == 0
                    ? Icons.add_comment_rounded
                    : Icons.group_add_rounded,
              ),
            ),
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _tabController.dispose();

    _searchController.dispose();

    super.dispose();
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
  });

  final Map<String, dynamic> conversation;

  final String otherUid;

  final String currentUid;

  final String search;

  final Future<DocumentSnapshot<Map<String, dynamic>>> userFuture;

  final ChatPrivacyService privacyService;

  static const Color _blue = Color(0xFF29B6F6);

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
              leading: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FullPhotoViewer(title: name, photoUrl: photoUrl),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 27,
                  backgroundColor: Colors.white10,
                  backgroundImage: photoUrl.trim().isNotEmpty
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: photoUrl.trim().isEmpty
                      ? const Icon(Icons.person_rounded)
                      : null,
                ),
              ),
              title: SearchHighlightText(
                text: name,

                query: search,

                style: TextStyle(
                  color: Colors.white,

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
                        color: unread > 0 ? Colors.white70 : Colors.white54,

                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                crossAxisAlignment: CrossAxisAlignment.end,

                children: <Widget>[
                  Text(
                    NubifyTime.formatTimestamp(lastMessageAt),

                    style: TextStyle(
                      color: unread > 0 ? _blue : Colors.white38,

                      fontSize: 10,

                      fontWeight: unread > 0
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),

                  if (unread > 0) ...<Widget>[
                    const SizedBox(height: 5),

                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),

                      padding: const EdgeInsets.symmetric(horizontal: 6),

                      alignment: Alignment.center,

                      decoration: const BoxDecoration(
                        color: _blue,

                        shape: BoxShape.circle,
                      ),

                      child: Text(
                        unread > 99 ? '99+' : '$unread',

                        style: const TextStyle(
                          color: Colors.white,

                          fontSize: 9,

                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
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
                ? const Color(0xFF25D366)
                : Colors.white38,
          );
        },
      );
    }

    if (delivered.contains(otherUid)) {
      return const Icon(
        Icons.done_all_rounded,
        size: 16,
        color: Colors.white38,
      );
    }

    return const Icon(Icons.done_rounded, size: 16, color: Colors.white38);
  }
}

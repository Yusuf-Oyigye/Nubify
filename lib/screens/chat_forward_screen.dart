import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_group.dart';
import '../models/chat_message.dart';
import '../services/chat_sevice.dart';
import '../services/chat_share_service.dart';
import '../services/group_chat_service.dart';

//===================================================
// CHAT FORWARD / SHARE SCREEN
//===================================================

class ChatForwardScreen extends StatefulWidget {
  const ChatForwardScreen({
    super.key,
    this.message,
    this.text = '',

    this.postId = '',
    this.postOwnerId = '',
    this.postUsername = '',
    this.postFullName = '',
    this.postCaption = '',
    this.postPreviewUrl = '',

    this.storyId = '',
    this.storyOwnerId = '',
    this.storyUsername = '',
    this.storyPreviewUrl = '',
    this.storyType = '',

    this.productId = '',
    this.productSellerId = '',
    this.productName = '',
    this.productImageUrl = '',
    this.productPrice = '',
  });

  //===================================================
  // NORMAL MESSAGE / LINK
  //===================================================

  final ChatMessage? message;
  final String text;

  //===================================================
  // POST
  //===================================================

  final String postId;
  final String postOwnerId;
  final String postUsername;
  final String postFullName;
  final String postCaption;
  final String postPreviewUrl;

  //===================================================
  // STORY
  //===================================================

  final String storyId;
  final String storyOwnerId;
  final String storyUsername;
  final String storyPreviewUrl;
  final String storyType;

  //===================================================
  // MARKETPLACE PRODUCT
  //===================================================

  final String productId;
  final String productSellerId;
  final String productName;
  final String productImageUrl;
  final String productPrice;

  @override
  State<ChatForwardScreen> createState() => _ChatForwardScreenState();
}

//===================================================
// CHAT FORWARD STATE
//===================================================

class _ChatForwardScreenState extends State<ChatForwardScreen> {
  static const Color _blue = Color(0xFF29B6F6);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ChatService _chatService = ChatService();

  final GroupChatService _groupService = GroupChatService();

  final ChatShareService _shareService = ChatShareService();

  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedUsers = <String>{};

  final Set<String> _selectedGroups = <String>{};

  String _search = '';

  bool _sending = false;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  //===================================================
  // TOGGLE USER
  //===================================================

  void _toggleUser(String uid) {
    setState(() {
      if (_selectedUsers.contains(uid)) {
        _selectedUsers.remove(uid);
      } else {
        _selectedUsers.add(uid);
      }
    });
  }

  //===================================================
  // TOGGLE GROUP
  //===================================================

  void _toggleGroup(String groupId) {
    setState(() {
      if (_selectedGroups.contains(groupId)) {
        _selectedGroups.remove(groupId);
      } else {
        _selectedGroups.add(groupId);
      }
    });
  }

  //===================================================
  // SEND TO ONE USER
  //===================================================

  Future<void> _sendToUser(String uid) async {
    if (widget.message != null) {
      await _chatService.forwardMessage(
        receiverId: uid,

        message: widget.message!,
      );

      return;
    }

    if (widget.postId.trim().isNotEmpty) {
      await _shareService.sendPostToUser(
        receiverId: uid,

        postId: widget.postId,

        postOwnerId: widget.postOwnerId,

        postUsername: widget.postUsername,

        postFullName: widget.postFullName,

        postCaption: widget.postCaption,

        postPreviewUrl: widget.postPreviewUrl,
      );

      return;
    }

    if (widget.storyId.trim().isNotEmpty) {
      await _shareService.sendStoryToUser(
        receiverId: uid,

        storyId: widget.storyId,

        storyOwnerId: widget.storyOwnerId,

        storyUsername: widget.storyUsername,

        storyPreviewUrl: widget.storyPreviewUrl,

        storyType: widget.storyType,
      );

      return;
    }

    if (widget.productId.trim().isNotEmpty) {
      await _shareService.sendProductToUser(
        receiverId: uid,
        productId: widget.productId,
        productSellerId: widget.productSellerId,
        productName: widget.productName,
        productImageUrl: widget.productImageUrl,
        productPrice: widget.productPrice,
      );
      return;
    }

    if (widget.text.trim().isNotEmpty) {
      await _chatService.sendMessage(receiverId: uid, text: widget.text.trim());
    }
  }

  //===================================================
  // SEND TO ONE GROUP
  //===================================================

  Future<void> _sendToGroup(String groupId) async {
    if (widget.message != null) {
      await _groupService.forwardMessage(
        groupId: groupId,

        message: widget.message!,
      );

      return;
    }

    if (widget.postId.trim().isNotEmpty) {
      await _shareService.sendPostToGroup(
        groupId: groupId,

        postId: widget.postId,

        postOwnerId: widget.postOwnerId,

        postUsername: widget.postUsername,

        postFullName: widget.postFullName,

        postCaption: widget.postCaption,

        postPreviewUrl: widget.postPreviewUrl,
      );

      return;
    }

    if (widget.storyId.trim().isNotEmpty) {
      await _shareService.sendStoryToGroup(
        groupId: groupId,

        storyId: widget.storyId,

        storyOwnerId: widget.storyOwnerId,

        storyUsername: widget.storyUsername,

        storyPreviewUrl: widget.storyPreviewUrl,

        storyType: widget.storyType,
      );

      return;
    }

    if (widget.productId.trim().isNotEmpty) {
      await _shareService.sendProductToGroup(
        groupId: groupId,
        productId: widget.productId,
        productSellerId: widget.productSellerId,
        productName: widget.productName,
        productImageUrl: widget.productImageUrl,
        productPrice: widget.productPrice,
      );
      return;
    }

    if (widget.text.trim().isNotEmpty) {
      await _groupService.sendMessage(
        groupId: groupId,

        text: widget.text.trim(),
      );
    }
  }

  //===================================================
  // SEND TO ALL SELECTED
  //===================================================

  Future<void> _sendSelected() async {
    if (_sending || (_selectedUsers.isEmpty && _selectedGroups.isEmpty)) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      for (final String uid in _selectedUsers) {
        await _sendToUser(uid);
      }

      for (final String groupId in _selectedGroups) {
        await _sendToGroup(groupId);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to send: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  //===================================================
  // USERS
  //===================================================

  Widget _users() {
    final String currentUid = _auth.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').snapshots(),

      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final documents =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .where((document) {
                      if (document.id == currentUid) {
                        return false;
                      }

                      final data = document.data();

                      final String fullName = (data['fullName'] ?? '')
                          .toString();

                      final String username = (data['username'] ?? '')
                          .toString();

                      final String searchable = '$fullName $username'
                          .toLowerCase();

                      return _search.isEmpty || searchable.contains(_search);
                    })
                    .toList();

            if (documents.isEmpty) {
              return const Center(child: Text('No users found.'));
            }

            return ListView.builder(
              itemCount: documents.length,

              itemBuilder: (BuildContext context, int index) {
                final document = documents[index];

                final data = document.data();

                final String fullName = (data['fullName'] ?? '').toString();

                final String username = (data['username'] ?? '').toString();

                final String photoUrl = (data['photoUrl'] ?? '').toString();

                final String name = fullName.trim().isNotEmpty
                    ? fullName
                    : username.trim().isNotEmpty
                    ? username
                    : 'Nubify user';

                final bool selected = _selectedUsers.contains(document.id);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: photoUrl.trim().isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,

                    child: photoUrl.trim().isEmpty
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),

                  title: Text(name),

                  subtitle: username.trim().isNotEmpty
                      ? Text('@$username')
                      : null,

                  trailing: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,

                    color: selected ? _blue : Colors.grey,
                  ),

                  onTap: () {
                    _toggleUser(document.id);
                  },
                );
              },
            );
          },
    );
  }

  //===================================================
  // GROUPS
  //===================================================

  Widget _groups() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _groupService.getGroups(),

      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final List<ChatGroup> groups =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map((document) => ChatGroup.fromDocument(document))
                    .where(
                      (ChatGroup group) =>
                          _search.isEmpty ||
                          group.name.toLowerCase().contains(_search),
                    )
                    .toList();

            if (groups.isEmpty) {
              return const Center(child: Text('No groups found.'));
            }

            return ListView.builder(
              itemCount: groups.length,

              itemBuilder: (BuildContext context, int index) {
                final ChatGroup group = groups[index];

                final bool selected = _selectedGroups.contains(group.groupId);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: group.photoUrl.trim().isNotEmpty
                        ? NetworkImage(group.photoUrl)
                        : null,

                    child: group.photoUrl.trim().isEmpty
                        ? const Icon(Icons.groups_rounded)
                        : null,
                  ),

                  title: Text(group.name),

                  subtitle: Text('${group.memberIds.length} members'),

                  trailing: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,

                    color: selected ? _blue : Colors.grey,
                  ),

                  onTap: () {
                    _toggleGroup(group.groupId);
                  },
                );
              },
            );
          },
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final int selectedCount = _selectedUsers.length + _selectedGroups.length;

    return DefaultTabController(
      length: 2,

      child: Scaffold(
        backgroundColor: const Color(0xFF0B1116),

        appBar: AppBar(
          backgroundColor: const Color(0xFF0B1116),

          title: const Text('Send to chat'),

          bottom: const TabBar(
            indicatorColor: _blue,

            labelColor: _blue,

            tabs: <Widget>[
              Tab(icon: Icon(Icons.person_rounded), text: 'Users'),

              Tab(icon: Icon(Icons.groups_rounded), text: 'Groups'),
            ],
          ),
        ),

        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),

              child: TextField(
                controller: _searchController,

                decoration: InputDecoration(
                  hintText: 'Search users or groups',

                  prefixIcon: const Icon(Icons.search_rounded),

                  filled: true,

                  fillColor: Colors.white10,

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),

                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            if (selectedCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),

                child: Align(
                  alignment: Alignment.centerLeft,

                  child: Text(
                    '$selectedCount selected',

                    style: const TextStyle(
                      color: _blue,

                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            Expanded(
              child: TabBarView(children: <Widget>[_users(), _groups()]),
            ),

            SafeArea(
              top: false,

              child: Padding(
                padding: const EdgeInsets.all(12),

                child: SizedBox(
                  width: double.infinity,

                  child: FilledButton.icon(
                    onPressed: selectedCount == 0 || _sending
                        ? null
                        : _sendSelected,

                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,

                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),

                    label: Text(
                      _sending
                          ? 'Sending...'
                          : selectedCount == 0
                          ? 'Select users or groups'
                          : 'Send to $selectedCount',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // DISPOSE
  //===================================================

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'audio_call_screen.dart';
import '../../profile/profile_screen.dart';

//===================================================
// DIRECT NEW CALL PICKER
//===================================================

class NewCallScreen extends StatefulWidget {
  const NewCallScreen({super.key});

  @override
  State<NewCallScreen> createState() => _NewCallScreenState();
}

class _NewCallScreenState extends State<NewCallScreen> {
  static const Color _blue = Color(0xFF29B6F6);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final String next = _searchController.text.trim().toLowerCase();
    if (!mounted || next == _search) {
      return;
    }
    setState(() => _search = next);
  }

  void _startCall({
    required String uid,
    required String name,
    required String photoUrl,
  }) {
    if (uid.isEmpty || uid == _auth.currentUser?.uid) {
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AudioCallScreen(
          otherUserId: uid,
          otherName: name,
          otherPhotoUrl: photoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String currentUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New call',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 11),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search users to call',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<QueryDocumentSnapshot<Map<String, dynamic>>> users =
                    (snapshot.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                        .where((document) {
                          if (document.id == currentUid) {
                            return false;
                          }
                          final Map<String, dynamic> user = document.data();
                          final String name = (user['fullName'] ?? '')
                              .toString()
                              .toLowerCase();
                          final String username = (user['username'] ?? '')
                              .toString()
                              .toLowerCase();
                          return _search.isEmpty ||
                              name.contains(_search) ||
                              username.contains(_search);
                        })
                        .toList()
                      ..sort((a, b) {
                        final String aName = (a.data()['fullName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final String bName = (b.data()['fullName'] ?? '')
                            .toString()
                            .toLowerCase();
                        return aName.compareTo(bName);
                      });

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _search.isEmpty
                          ? 'No users available to call.'
                          : 'No matching users.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 78,
                    color: scheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final QueryDocumentSnapshot<Map<String, dynamic>> document =
                        users[index];
                    final Map<String, dynamic> user = document.data();
                    final String fullName = (user['fullName'] ?? '')
                        .toString()
                        .trim();
                    final String username = (user['username'] ?? '')
                        .toString()
                        .trim();
                    final String photoUrl = (user['photoUrl'] ?? '')
                        .toString()
                        .trim();
                    final String name = fullName.isNotEmpty
                        ? fullName
                        : username.isNotEmpty
                        ? username
                        : 'Nubify user';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProfileScreen(userId: document.id),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: _blue.withValues(alpha: 0.13),
                          backgroundImage: photoUrl.isEmpty
                              ? null
                              : NetworkImage(photoUrl),
                          child: photoUrl.isEmpty
                              ? const Icon(Icons.person_rounded, color: _blue)
                              : null,
                        ),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: username.isEmpty
                          ? null
                          : Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: IconButton.filledTonal(
                        tooltip: 'Call $name',
                        onPressed: () {
                          _startCall(
                            uid: document.id,
                            name: name,
                            photoUrl: photoUrl,
                          );
                        },
                        icon: const Icon(Icons.call_rounded, color: _blue),
                      ),
                      onTap: () {
                        _startCall(
                          uid: document.id,
                          name: name,
                          photoUrl: photoUrl,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
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

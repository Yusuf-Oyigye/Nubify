import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'conversation_screen.dart';
import '../widgets/search_highlight_text.dart';

//===============================
// NEW CHAT SCREEN
//===============================

class NewChatScreen
    extends StatefulWidget {
  const NewChatScreen({
    super.key,
  });

  @override
  State<NewChatScreen>
  createState() =>
      _NewChatScreenState();
}

//===============================
// NEW CHAT STATE
//===============================

class _NewChatScreenState
    extends State<
        NewChatScreen> {
  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  final TextEditingController
  _searchController =
  TextEditingController();

  final Set<String>
  _priorityIds =
  <String>{};

  final Set<String>
  _blockedIds =
  <String>{};

  bool _loading =
  true;

  String _search =
      '';

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();

    _loadUserLists();

    _searchController
        .addListener(
          () {
        if (!mounted) {
          return;
        }

        setState(() {
          _search =
              _searchController
                  .text
                  .trim()
                  .toLowerCase();
        });
      },
    );
  }

  //===============================
  // LOAD PRIORITY + BLOCKED
  //===============================

  Future<void>
  _loadUserLists() async {
    final String? uid =
        _auth.currentUser
            ?.uid;

    if (uid == null) {
      return;
    }

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      userSnapshot =
      await _firestore
          .collection(
        'users',
      )
          .doc(
        uid,
      )
          .get();

      final Map<String, dynamic>
      user =
          userSnapshot
              .data() ??
              <String, dynamic>{};

      final List<String>
      followers =
      List<String>.from(
        user['followers'] ??
            <String>[],
      );

      final List<String>
      following =
      List<String>.from(
        user['following'] ??
            <String>[],
      );

      _priorityIds
        ..clear()
        ..addAll(
          followers,
        )
        ..addAll(
          following,
        );

      final QuerySnapshot<
          Map<String, dynamic>>
      blocked =
      await _firestore
          .collection(
        'users',
      )
          .doc(
        uid,
      )
          .collection(
        'blockedUsers',
      )
          .get();

      _blockedIds
        ..clear()
        ..addAll(
          blocked.docs.map(
                (
                QueryDocumentSnapshot<
                    Map<String,
                        dynamic>>
                document,
                ) =>
            document.id,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _loading =
          false;
        });
      }
    }
  }

  //===============================
  // MATCH SEARCH
  //===============================

  bool _matches(
      Map<String, dynamic> user,
      ) {
    if (_search.isEmpty) {
      return true;
    }

    final String fullName =
    (user['fullName'] ??
        '')
        .toString()
        .toLowerCase();

    final String username =
    (user['username'] ??
        '')
        .toString()
        .toLowerCase();

    return fullName.contains(
      _search,
    ) ||
        username.contains(
          _search,
        );
  }

  //===============================
  // OPEN CHAT
  //===============================

  void _openChat(
      Map<String, dynamic> user,
      String uid,
      ) {
    final String username =
    (user['username'] ??
        '')
        .toString();

    final String fullName =
    (user['fullName'] ??
        '')
        .toString();

    final String photoUrl =
    (user['photoUrl'] ??
        '')
        .toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
            ConversationScreen(
              otherUserId:
              uid,
              otherName:
              fullName
                  .trim()
                  .isNotEmpty
                  ? fullName
                  : username
                  .trim()
                  .isNotEmpty
                  ? username
                  : 'Nubify user',
              otherUsername:
              username,
              otherPhotoUrl:
              photoUrl,
            ),
      ),
    );
  }

  //===============================
  // USER TILE
  //===============================

  Widget _userTile(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    final Map<String, dynamic>
    user =
    document.data();

    final String fullName =
    (user['fullName'] ??
        '')
        .toString();

    final String username =
    (user['username'] ??
        '')
        .toString();

    final String photoUrl =
    (user['photoUrl'] ??
        '')
        .toString();

    final String name =
    fullName
        .trim()
        .isNotEmpty
        ? fullName
        : username
        .trim()
        .isNotEmpty
        ? username
        : 'Nubify user';

    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal:
        16,
        vertical:
        3,
      ),
      leading:
      CircleAvatar(
        radius:
        25,
        backgroundColor:
        Colors.white10,
        backgroundImage:
        photoUrl
            .trim()
            .isNotEmpty
            ? NetworkImage(
          photoUrl,
        )
            : null,
        child:
        photoUrl
            .trim()
            .isEmpty
            ? const Icon(
          Icons
              .person_rounded,
          color:
          Colors.white70,
        )
            : null,
      ),
      title:
      SearchHighlightText(
        text:
        name,

        query:
        _search,

        style:
        const TextStyle(
          color:
          Colors.white,

          fontWeight:
          FontWeight.w700,
        ),
      ),
      subtitle:
      username
          .trim()
          .isNotEmpty
          ? SearchHighlightText(
        text:
        '@$username',

        query:
        _search,

        style:
        const TextStyle(
          color:
          Colors.white54,
        ),
      ):
           null,
      trailing:
      const Icon(
        Icons
            .chevron_right_rounded,
        color:
        Colors.white30,
      ),
      onTap:
          () {
        _openChat(
          user,
          document.id,
        );
      },
    );
  }

  //===============================
  // SECTION
  //===============================

  Widget _section({
    required String title,
    required List<
        QueryDocumentSnapshot<
            Map<String,
                dynamic>>>
    users,
  }) {
    if (users.isEmpty) {
      return const SizedBox
          .shrink();
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children:
      <Widget>[
        Padding(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            15,
            16,
            6,
          ),
          child:
          Text(
            title,
            style:
            const TextStyle(
              color:
              Color(
                0xFF29B6F6,
              ),
              fontWeight:
              FontWeight.w700,
              fontSize:
              13,
            ),
          ),
        ),

        ...users.map(
          _userTile,
        ),
      ],
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    final String? currentUid =
        _auth.currentUser
            ?.uid;

    return Scaffold(
      backgroundColor:
      const Color(
        0xFF0B1116,
      ),
      appBar:
      AppBar(
        backgroundColor:
        const Color(
          0xFF0B1116,
        ),
        title:
        const Text(
          'New message',
          style:
          TextStyle(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body:
      Column(
        children:
        <Widget>[
          //===============================
          // SEARCH
          //===============================

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              14,
              6,
              14,
              10,
            ),
            child:
            TextField(
              controller:
              _searchController,
              decoration:
              InputDecoration(
                hintText:
                'Search users',
                prefixIcon:
                const Icon(
                  Icons
                      .search_rounded,
                ),
                suffixIcon:
                _searchController
                    .text
                    .isNotEmpty
                    ? IconButton(
                  onPressed:
                      () {
                    _searchController
                        .clear();
                  },
                  icon:
                  const Icon(
                    Icons
                        .close_rounded,
                  ),
                )
                    : null,
                filled:
                true,
                fillColor:
                const Color(
                  0xFF192126,
                ),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    26,
                  ),
                  borderSide:
                  BorderSide
                      .none,
                ),
              ),
            ),
          ),

          if (_loading)
            const Expanded(
              child:
              Center(
                child:
                CircularProgressIndicator(
                  color:
                  Color(
                    0xFF29B6F6,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child:
              StreamBuilder<
                  QuerySnapshot<
                      Map<String,
                          dynamic>>>(
                stream:
                _firestore
                    .collection(
                  'users',
                )
                    .snapshots(),
                builder:
                    (
                    BuildContext
                    context,
                    AsyncSnapshot<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>
                    snapshot,
                    ) {
                  if (snapshot
                      .connectionState ==
                      ConnectionState
                          .waiting) {
                    return const Center(
                      child:
                      CircularProgressIndicator(
                        color:
                        Color(
                          0xFF29B6F6,
                        ),
                      ),
                    );
                  }

                  final List<
                      QueryDocumentSnapshot<
                          Map<String,
                              dynamic>>>
                  all =
                      snapshot
                          .data
                          ?.docs ??
                          <QueryDocumentSnapshot<
                              Map<String,
                                  dynamic>>>[];

                  final List<
                      QueryDocumentSnapshot<
                          Map<String,
                              dynamic>>>
                  visible =
                  all.where(
                        (
                        QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>
                        document,
                        ) {
                      if (document.id ==
                          currentUid) {
                        return false;
                      }

                      if (_blockedIds
                          .contains(
                        document.id,
                      )) {
                        return false;
                      }

                      return _matches(
                        document.data(),
                      );
                    },
                  ).toList();

                  visible.sort(
                        (
                        QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>
                        a,
                        QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>
                        b,
                        ) {
                      final String
                      aName =
                      (a.data()[
                      'fullName'] ??
                          a.data()[
                          'username'] ??
                          '')
                          .toString()
                          .toLowerCase();

                      final String
                      bName =
                      (b.data()[
                      'fullName'] ??
                          b.data()[
                          'username'] ??
                          '')
                          .toString()
                          .toLowerCase();

                      return aName
                          .compareTo(
                        bName,
                      );
                    },
                  );

                  final List<
                      QueryDocumentSnapshot<
                          Map<String,
                              dynamic>>>
                  priority =
                  visible
                      .where(
                        (
                        document,
                        ) =>
                        _priorityIds
                            .contains(
                          document.id,
                        ),
                  )
                      .toList();

                  final List<
                      QueryDocumentSnapshot<
                          Map<String,
                              dynamic>>>
                  others =
                  visible
                      .where(
                        (
                        document,
                        ) =>
                    !_priorityIds
                        .contains(
                      document.id,
                    ),
                  )
                      .toList();

                  if (priority
                      .isEmpty &&
                      others
                          .isEmpty) {
                    return const Center(
                      child:
                      Text(
                        'No users found.',
                        style:
                        TextStyle(
                          color:
                          Colors.white54,
                        ),
                      ),
                    );
                  }

                  return ListView(
                    children:
                    <Widget>[
                      _section(
                        title:
                        'People you follow / who follow you',
                        users:
                        priority,
                      ),

                      if (priority
                          .isNotEmpty &&
                          others
                              .isNotEmpty)
                        const Divider(
                          color:
                          Colors.white10,
                          height:
                          20,
                        ),

                      _section(
                        title:
                        'Other Nubify users',
                        users:
                        others,
                      ),

                      const SizedBox(
                        height:
                        30,
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _searchController
        .dispose();

    super.dispose();
  }
}
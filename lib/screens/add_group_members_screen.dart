import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_group.dart';
import '../services/group_chat_service.dart';

//===============================
// ADD GROUP MEMBERS SCREEN
//===============================

class AddGroupMembersScreen
    extends StatefulWidget {
  const AddGroupMembersScreen({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<AddGroupMembersScreen>
  createState() =>
      _AddGroupMembersScreenState();
}

//===============================
// ADD MEMBERS STATE
//===============================

class _AddGroupMembersScreenState
    extends State<
        AddGroupMembersScreen> {
  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  final GroupChatService
  _groupService =
  GroupChatService();

  final TextEditingController
  _searchController =
  TextEditingController();

  final Set<String>
  _selected =
  <String>{};

  String _search =
      '';

  bool _adding =
  false;

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
          () {
        if (!mounted) {
          return;
        }

        setState(() {
          _search =
              _searchController.text
                  .trim()
                  .toLowerCase();
        });
      },
    );
  }

  //===============================
  // ADD MEMBERS
  //===============================

  Future<void> _addMembers() async {
    if (_selected.isEmpty ||
        _adding) {
      return;
    }

    setState(() {
      _adding =
      true;
    });

    try {
      await _groupService.addMembers(
        groupId:
        widget.groupId,
        userIds:
        _selected.toList(),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
          Text(
            error
                .toString()
                .replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _adding =
          false;
        });
      }
    }
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
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
          'Add members',
          style:
          TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
        actions:
        <Widget>[
          TextButton(
            onPressed:
            _selected.isEmpty ||
                _adding
                ? null
                : _addMembers,
            child:
            _adding
                ? const SizedBox(
              width:
              18,
              height:
              18,
              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
                color:
                _blue,
              ),
            )
                : Text(
              'Add (${_selected.length})',
              style:
              const TextStyle(
                color:
                _blue,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body:
      StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream:
        _groupService.groupStream(
          widget.groupId,
        ),
        builder:
            (
            BuildContext context,
            AsyncSnapshot<
                DocumentSnapshot<
                    Map<String, dynamic>>>
            groupSnapshot,
            ) {
          if (!groupSnapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(
                color:
                _blue,
              ),
            );
          }

          if (!groupSnapshot.data!.exists) {
            return const Center(
              child:
              Text(
                'Group not found.',
              ),
            );
          }

          final ChatGroup group =
          ChatGroup.fromDocument(
            groupSnapshot.data!,
          );

          final String? uid =
              _auth.currentUser?.uid;

          final bool canAdd =
              uid != null &&
                  (group.isAdmin(
                    uid,
                  ) ||
                      group.permissions
                          .membersCanAddMembers);

          if (!canAdd) {
            return const Center(
              child:
              Padding(
                padding:
                EdgeInsets.all(
                  30,
                ),
                child:
                Text(
                  'Only admins can add members because the group admin has disabled member adding.',
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    color:
                    Colors.white60,
                  ),
                ),
              ),
            );
          }

          return Column(
            children:
            <Widget>[
              Padding(
                padding:
                const EdgeInsets.fromLTRB(
                  14,
                  8,
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
                      Icons.search_rounded,
                    ),
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
                        25,
                      ),
                      borderSide:
                      BorderSide.none,
                    ),
                  ),
                ),
              ),

              Expanded(
                child:
                StreamBuilder<
                    QuerySnapshot<
                        Map<String, dynamic>>>(
                  stream:
                  _firestore
                      .collection(
                    'users',
                  )
                      .snapshots(),
                  builder:
                      (
                      BuildContext context,
                      AsyncSnapshot<
                          QuerySnapshot<
                              Map<String, dynamic>>>
                      snapshot,
                      ) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child:
                        CircularProgressIndicator(
                          color:
                          _blue,
                        ),
                      );
                    }

                    final users =
                    snapshot.data!.docs
                        .where(
                          (
                          QueryDocumentSnapshot<
                              Map<String, dynamic>>
                          document,
                          ) {
                        if (document.id ==
                            uid) {
                          return false;
                        }

                        if (group.memberIds.contains(
                          document.id,
                        )) {
                          return false;
                        }

                        final Map<String, dynamic>
                        user =
                        document.data();

                        if (_search.isEmpty) {
                          return true;
                        }

                        final String fullName =
                        (user['fullName'] ?? '')
                            .toString()
                            .toLowerCase();

                        final String username =
                        (user['username'] ?? '')
                            .toString()
                            .toLowerCase();

                        return fullName.contains(
                          _search,
                        ) ||
                            username.contains(
                              _search,
                            );
                      },
                    )
                        .toList();

                    if (users.isEmpty) {
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

                    return ListView.builder(
                      itemCount:
                      users.length,
                      itemBuilder:
                          (
                          BuildContext context,
                          int index,
                          ) {
                        final document =
                        users[index];

                        final data =
                        document.data();

                        final String fullName =
                        (data['fullName'] ?? '')
                            .toString();

                        final String username =
                        (data['username'] ?? '')
                            .toString();

                        final String photoUrl =
                        (data['photoUrl'] ?? '')
                            .toString();

                        final bool selected =
                        _selected.contains(
                          document.id,
                        );

                        return ListTile(
                          onTap:
                              () {
                            setState(() {
                              if (selected) {
                                _selected.remove(
                                  document.id,
                                );
                              } else {
                                _selected.add(
                                  document.id,
                                );
                              }
                            });
                          },
                          leading:
                          CircleAvatar(
                            radius:
                            24,
                            backgroundImage:
                            photoUrl.trim().isNotEmpty
                                ? NetworkImage(
                              photoUrl,
                            )
                                : null,
                            child:
                            photoUrl.trim().isEmpty
                                ? const Icon(
                              Icons.person_rounded,
                            )
                                : null,
                          ),
                          title:
                          Text(
                            fullName.trim().isNotEmpty
                                ? fullName
                                : username,
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                          subtitle:
                          username.trim().isNotEmpty
                              ? Text(
                            '@$username',
                            style:
                            const TextStyle(
                              color:
                              Colors.white54,
                            ),
                          )
                              : null,
                          trailing:
                          Checkbox(
                            value:
                            selected,
                            activeColor:
                            _blue,
                            onChanged:
                                (_) {
                              setState(() {
                                if (selected) {
                                  _selected.remove(
                                    document.id,
                                  );
                                } else {
                                  _selected.add(
                                    document.id,
                                  );
                                }
                              });
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';

//===============================
// BLOCKED USERS SCREEN
//===============================

class BlockedUsersScreen
    extends StatelessWidget {
  BlockedUsersScreen({
    super.key,
  });

  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  final ProfileService
  _profileService =
  ProfileService();

  //===============================
  // UNBLOCK
  //===============================

  Future<void> _unblock(
      BuildContext context,
      String uid,
      String name,
      ) async {
    final bool? confirmed =
    await showDialog<bool>(
      context:
      context,
      builder:
          (
          BuildContext context,
          ) {
        return AlertDialog(
          title:
          const Text(
            'Unblock user?',
          ),
          content:
          Text(
            'Unblock $name?',
          ),
          actions:
          <Widget>[
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
              const Text(
                'Unblock',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed !=
        true) {
      return;
    }

    await _profileService
        .unblockUser(
      uid,
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    final String? uid =
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
          'Blocked users',
          style:
          TextStyle(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body:
      uid == null
          ? const Center(
        child:
        Text(
          'Please log in.',
        ),
      )
          : StreamBuilder<
          QuerySnapshot<
              Map<String,
                  dynamic>>>(
        stream:
        _firestore
            .collection(
          'users',
        )
            .doc(
          uid,
        )
            .collection(
          'blockedUsers',
        )
            .orderBy(
          'blockedAt',
          descending:
          true,
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

          final docs =
              snapshot
                  .data
                  ?.docs ??
                  [];

          if (docs
              .isEmpty) {
            return const Center(
              child:
              Column(
                mainAxisSize:
                MainAxisSize
                    .min,
                children:
                <Widget>[
                  Icon(
                    Icons
                        .block_rounded,
                    color:
                    Colors.white38,
                    size:
                    48,
                  ),
                  SizedBox(
                    height:
                    10,
                  ),
                  Text(
                    'No blocked users',
                    style:
                    TextStyle(
                      color:
                      Colors.white70,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount:
            docs.length,
            separatorBuilder:
                (
                _,
                __,
                ) =>
            const Divider(
              height:
              1,
              color:
              Colors.white10,
            ),
            itemBuilder:
                (
                BuildContext
                context,
                int index,
                ) {
              final String
              blockedUid =
                  docs[index]
                      .id;

              return FutureBuilder<
                  DocumentSnapshot<
                      Map<String,
                          dynamic>>>(
                future:
                _firestore
                    .collection(
                  'users',
                )
                    .doc(
                  blockedUid,
                )
                    .get(),
                builder:
                    (
                    BuildContext
                    context,
                    AsyncSnapshot<
                        DocumentSnapshot<
                            Map<String,
                                dynamic>>>
                    userSnapshot,
                    ) {
                  final user =
                      userSnapshot
                          .data
                          ?.data() ??
                          <String,
                              dynamic>{};

                  final String
                  fullName =
                  (user['fullName'] ??
                      '')
                      .toString();

                  final String
                  username =
                  (user['username'] ??
                      '')
                      .toString();

                  final String
                  photoUrl =
                  (user['photoUrl'] ??
                      '')
                      .toString();

                  final String
                  name =
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
                      4,
                    ),
                    leading:
                    CircleAvatar(
                      radius:
                      24,
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
                      )
                          : null,
                    ),
                    title:
                    Text(
                      name,
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
                    TextButton(
                      onPressed:
                          () {
                        _unblock(
                          context,
                          blockedUid,
                          name,
                        );
                      },
                      child:
                      const Text(
                        'Unblock',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
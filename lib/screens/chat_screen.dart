import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_sevice.dart';
import '../utils/nubify_time.dart';
import 'conversation_screen.dart';

class ChatScreen
    extends StatelessWidget {
  const ChatScreen({
    super.key,
  });

  //===========================================================
  // BUILD
  //===========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final ChatService
    chatService =
    ChatService();

    final FirebaseFirestore
    firestore =
        FirebaseFirestore
            .instance;

    final String? currentUid =
        FirebaseAuth
            .instance
            .currentUser
            ?.uid;

    return Scaffold(
      appBar:
      AppBar(
        title:
        const Text(
          'Chats',

          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body:
      StreamBuilder<
          QuerySnapshot>(
        stream:
        chatService
            .getConversations(),

        builder:
            (
            BuildContext context,

            AsyncSnapshot<
                QuerySnapshot>
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
              QueryDocumentSnapshot>
          conversations =
              snapshot
                  .data
                  ?.docs ??
                  <QueryDocumentSnapshot>[];

          if (conversations
              .isEmpty) {
            return const Center(
              child:
              Column(
                mainAxisSize:
                MainAxisSize.min,

                children:
                <Widget>[
                  Icon(
                    Icons
                        .chat_bubble_outline_rounded,

                    color:
                    Color(
                      0xFF29B6F6,
                    ),

                    size:
                    54,
                  ),

                  SizedBox(
                    height:
                    12,
                  ),

                  Text(
                    'No chats yet.',

                    style:
                    TextStyle(
                      fontSize:
                      17,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  SizedBox(
                    height:
                    5,
                  ),

                  Text(
                    'Story replies and shared stories will appear here.',

                    textAlign:
                    TextAlign.center,

                    style:
                    TextStyle(
                      color:
                      Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView
              .separated(
            itemCount:
            conversations
                .length,

            separatorBuilder:
                (_, __) =>
            const Divider(
              height:
              1,
            ),

            itemBuilder:
                (
                BuildContext context,
                int index,
                ) {
              final QueryDocumentSnapshot
              doc =
              conversations[
              index];

              final Map<String, dynamic>
              data =
              Map<String,
                  dynamic>.from(
                doc.data()
                as Map,
              );

              final List<String>
              participants =
              data['participants']
              is List
                  ? (data['participants']
              as List)
                  .map(
                    (item) =>
                    item.toString(),
              )
                  .toList()
                  : <String>[];

              String otherUid =
                  '';

              for (final String uid
              in participants) {
                if (uid !=
                    currentUid) {
                  otherUid =
                      uid;

                  break;
                }
              }

              if (otherUid.isEmpty) {
                return const SizedBox
                    .shrink();
              }

              final String
              lastMessage =
              (data['lastMessage'] ??
                  '')
                  .toString();

              final Timestamp?
              lastMessageAt =
              data['lastMessageAt']
              is Timestamp
                  ? data['lastMessageAt']
              as Timestamp
                  : null;

              return FutureBuilder<
                  DocumentSnapshot<
                      Map<String,
                          dynamic>>>(
                future:
                firestore
                    .collection(
                  'users',
                )
                    .doc(
                  otherUid,
                )
                    .get(),

                builder:
                    (
                    BuildContext context,

                    AsyncSnapshot<
                        DocumentSnapshot<
                            Map<String,
                                dynamic>>>
                    userSnapshot,
                    ) {
                  final Map<String,
                      dynamic>
                  user =
                      userSnapshot
                          .data
                          ?.data() ??
                          <String,
                              dynamic>{};

                  final String
                  username =
                  (user['username'] ??
                      '')
                      .toString();

                  final String
                  fullName =
                  (user['fullName'] ??
                      '')
                      .toString();

                  final String
                  photoUrl =
                  (user['photoUrl'] ??
                      '')
                      .toString();

                  final String
                  displayName =
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
                    const EdgeInsets
                        .symmetric(
                      horizontal:
                      14,

                      vertical:
                      4,
                    ),

                    leading:
                    CircleAvatar(
                      radius:
                      25,

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
                        Icons.person,
                      )
                          : null,
                    ),

                    title:
                    Text(
                      displayName,

                      maxLines:
                      1,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    subtitle:
                    Text(
                      lastMessage,

                      maxLines:
                      1,

                      overflow:
                      TextOverflow.ellipsis,
                    ),

                    trailing:
                    Text(
                      NubifyTime
                          .formatTimestamp(
                        lastMessageAt,
                      ),

                      style:
                      const TextStyle(
                        color:
                        Colors.grey,

                        fontSize:
                        11,
                      ),
                    ),

                    onTap:
                        () {
                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder:
                              (_) =>
                              ConversationScreen(
                                otherUserId:
                                otherUid,

                                otherName:
                                displayName,

                                otherUsername:
                                username,

                                otherPhotoUrl:
                                photoUrl,
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
      ),
    );
  }
}
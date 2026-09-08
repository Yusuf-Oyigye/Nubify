import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/story_service.dart';
import '../utils/nubify_time.dart';

class StoryViewersScreen
    extends StatelessWidget {
  StoryViewersScreen({
    super.key,
    required this.storyId,
  });

  final String storyId;

  final StoryService
  _storyService =
  StoryService();

  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  //===========================================================
  // BUILD
  //===========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar:
      AppBar(
        title:
        const Text(
          'Story Viewers',

          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),

      body:
      StreamBuilder<
          QuerySnapshot<
              Map<String,
                  dynamic>>>(
        stream:
        _storyService
            .streamViewers(
          storyId,
        ),

        builder:
            (
            BuildContext context,

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
          docs =
              snapshot
                  .data
                  ?.docs ??
                  <QueryDocumentSnapshot<
                      Map<String,
                          dynamic>>>[];

          if (docs.isEmpty) {
            return const Center(
              child:
              Text(
                'No views yet.',
              ),
            );
          }

          return ListView
              .separated(
            itemCount:
            docs.length,

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
              final QueryDocumentSnapshot<
                  Map<String, dynamic>>
              viewDoc =
              docs[index];

              final Map<String, dynamic>
              viewData =
              viewDoc.data();

              final String uid =
              (viewData['uid'] ??
                  viewDoc.id)
                  .toString();

              final Timestamp?
              viewedAt =
              viewData['viewedAt']
              is Timestamp
                  ? viewData['viewedAt']
              as Timestamp
                  : null;

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
                  uid,
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
                  userData =
                      userSnapshot
                          .data
                          ?.data() ??
                          <String,
                              dynamic>{};

                  final String
                  username =
                  (userData['username'] ??
                      '')
                      .toString();

                  final String
                  fullName =
                  (userData['fullName'] ??
                      '')
                      .toString();

                  final String
                  photoUrl =
                  (userData['photoUrl'] ??
                      '')
                      .toString();

                  return ListTile(
                    leading:
                    CircleAvatar(
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
                      fullName
                          .trim()
                          .isNotEmpty
                          ? fullName
                          : username
                          .trim()
                          .isNotEmpty
                          ? username
                          : 'Nubify user',
                    ),

                    subtitle:
                    Text(
                      username
                          .trim()
                          .isEmpty
                          ? ''
                          : '@$username',
                    ),

                    trailing:
                    Text(
                      NubifyTime
                          .formatTimestamp(
                        viewedAt,
                      ),

                      style:
                      const TextStyle(
                        color:
                        Colors.grey,

                        fontSize:
                        12,
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
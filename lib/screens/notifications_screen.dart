import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/story.dart';
import '../services/notification_service.dart';
import '../services/story_service.dart';
import '../utils/nubify_time.dart';
import 'story_viewer_screen.dart';

class NotificationsScreen
    extends StatelessWidget {
  const NotificationsScreen({
    super.key,
  });

  //===========================================================
  // BUILD
  //===========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final NotificationService
    notificationService =
    NotificationService();

    final StoryService
    storyService =
    StoryService();

    final FirebaseFirestore
    firestore =
        FirebaseFirestore
            .instance;

    return Scaffold(
      appBar:
      AppBar(
        title:
        const Text(
          'Notifications',

          style:
          TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        actions:
        <Widget>[
          TextButton(
            onPressed:
            notificationService
                .markAllAsRead,

            child:
            const Text(
              'Read all',

              style:
              TextStyle(
                color:
                Color(
                  0xFF29B6F6,
                ),

                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),

      body:
      StreamBuilder<
          QuerySnapshot>(
        stream:
        notificationService
            .getNotifications(),

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
          docs =
              snapshot
                  .data
                  ?.docs ??
                  <QueryDocumentSnapshot>[];

          if (docs.isEmpty) {
            return const Center(
              child:
              Column(
                mainAxisSize:
                MainAxisSize.min,

                children:
                <Widget>[
                  Icon(
                    Icons
                        .notifications_none_rounded,

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
                    'No notifications yet.',

                    style:
                    TextStyle(
                      fontSize:
                      17,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
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
              final QueryDocumentSnapshot
              doc =
              docs[index];

              final Map<String, dynamic>
              data =
              Map<String,
                  dynamic>.from(
                doc.data()
                as Map,
              );

              final String senderId =
              (data['senderId'] ??
                  '')
                  .toString();

              final String type =
              (data['type'] ?? '')
                  .toString();

              final String message =
              (data['message'] ??
                  '')
                  .toString();

              final String storyId =
              (data['storyId'] ??
                  '')
                  .toString();

              final bool isRead =
                  data['isRead'] ==
                      true;

              final Timestamp?
              createdAt =
              data['createdAt']
              is Timestamp
                  ? data['createdAt']
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
                  senderId,
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
                      : 'Someone';

                  return Container(
                    color:
                    isRead
                        ? Colors.transparent
                        : const Color(
                      0xFF29B6F6,
                    ).withOpacity(
                      0.06,
                    ),

                    child:
                    ListTile(
                      contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        14,

                        vertical:
                        6,
                      ),

                      leading:
                      Stack(
                        clipBehavior:
                        Clip.none,

                        children:
                        <Widget>[
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

                          Positioned(
                            right:
                            -3,

                            bottom:
                            -2,

                            child:
                            Container(
                              width:
                              22,

                              height:
                              22,

                              decoration:
                              const BoxDecoration(
                                color:
                                Color(
                                  0xFF29B6F6,
                                ),

                                shape:
                                BoxShape.circle,
                              ),

                              child:
                              Icon(
                                _iconForType(
                                  type,
                                ),

                                color:
                                Colors.white,

                                size:
                                13,
                              ),
                            ),
                          ),
                        ],
                      ),

                      title:
                      RichText(
                        text:
                        TextSpan(
                          style:
                          DefaultTextStyle.of(
                            context,
                          ).style,

                          children:
                          <InlineSpan>[
                            TextSpan(
                              text:
                              displayName,

                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            TextSpan(
                              text:
                              ' $message',

                              style:
                              TextStyle(
                                color:
                                Colors.grey.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),

                      subtitle:
                      Text(
                        NubifyTime
                            .formatTimestamp(
                          createdAt,
                        ),

                        style:
                        const TextStyle(
                          color:
                          Colors.grey,

                          fontSize:
                          11,
                        ),
                      ),

                      trailing:
                      !isRead
                          ? const Icon(
                        Icons.circle,

                        color:
                        Color(
                          0xFF29B6F6,
                        ),

                        size:
                        9,
                      )
                          : null,

                      onTap:
                          () async {
                        await notificationService
                            .markAsRead(
                          doc.id,
                        );

                        if (!context
                            .mounted) {
                          return;
                        }

                        if (storyId
                            .trim()
                            .isNotEmpty &&
                            (type ==
                                'storyTag' ||
                                type ==
                                    'storyLike' ||
                                type ==
                                    'storyReply')) {
                          final NubifyStory?
                          story =
                          await storyService
                              .getStory(
                            storyId,
                          );

                          if (!context
                              .mounted) {
                            return;
                          }

                          if (story ==
                              null) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content:
                                Text(
                                  'This story has expired or was removed.',
                                ),
                              ),
                            );

                            return;
                          }

                          await Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                  StoryViewerScreen(
                                    stories:
                                    <NubifyStory>[
                                      story,
                                    ],
                                  ),
                            ),
                          );
                        }
                      },
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

  //===========================================================
  // TYPE ICON
  //===========================================================

  static IconData
  _iconForType(
      String type,
      ) {
    switch (type) {
      case 'storyTag':
        return Icons
            .alternate_email;

      case 'storyLike':
        return Icons
            .favorite;

      case 'storyReply':
        return Icons
            .reply_rounded;

      case 'like':
        return Icons
            .favorite;

      case 'comment':
        return Icons
            .mode_comment_outlined;

      case 'reply':
        return Icons
            .reply_rounded;

      case 'repost':
      case 'quoteRepost':
        return Icons
            .repeat_rounded;

      case 'follow':
        return Icons
            .person_add_alt_1;

      default:
        return Icons
            .notifications;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/story.dart';
import '../services/chat_sevice.dart';
import '../services/story_service.dart';
import '../utils/nubify_time.dart';
import 'story_viewer_screen.dart';

class ConversationScreen
    extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
    required this.otherUsername,
    required this.otherPhotoUrl,
  });

  final String otherUserId;
  final String otherName;
  final String otherUsername;
  final String otherPhotoUrl;

  @override
  State<ConversationScreen>
  createState() =>
      _ConversationScreenState();
}

class _ConversationScreenState
    extends State<
        ConversationScreen> {
  final ChatService
  _chatService =
  ChatService();

  final StoryService
  _storyService =
  StoryService();

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final TextEditingController
  _messageController =
  TextEditingController();

  bool _sending =
  false;

  //===========================================================
  // SEND MESSAGE
  //===========================================================

  Future<void>
  _sendMessage() async {
    final String text =
    _messageController
        .text
        .trim();

    if (text.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending =
      true;
    });

    try {
      await _chatService
          .sendMessage(
        receiverId:
        widget.otherUserId,

        text:
        text,
      );

      _messageController
          .clear();
    } finally {
      if (mounted) {
        setState(() {
          _sending =
          false;
        });
      }
    }
  }

  //===========================================================
  // OPEN STORY FROM CHAT
  //===========================================================

  Future<void> _openStory(
      String storyId,
      ) async {
    if (storyId
        .trim()
        .isEmpty) {
      return;
    }

    final NubifyStory? story =
    await _storyService
        .getStory(
      storyId,
    );

    if (!mounted) {
      return;
    }

    if (story == null) {
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

  //===========================================================
  // MARK INCOMING MESSAGE AS READ
  //===========================================================

  void _markAsReadIfNeeded({
    required String messageId,
    required Map<String, dynamic>
    data,
  }) {
    final String? currentUid =
        _auth
            .currentUser
            ?.uid;

    final String senderId =
    (data['senderId'] ?? '')
        .toString();

    final bool isRead =
        data['isRead'] ==
            true;

    if (currentUid == null ||
        senderId ==
            currentUid ||
        isRead) {
      return;
    }

    WidgetsBinding.instance
        .addPostFrameCallback(
          (_) {
        _chatService
            .markMessageAsRead(
          otherUserId:
          widget.otherUserId,

          messageId:
          messageId,
        );
      },
    );
  }

  //===========================================================
  // BUILD
  //===========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final String? currentUid =
        _auth
            .currentUser
            ?.uid;

    return Scaffold(
      appBar:
      AppBar(
        titleSpacing:
        0,

        title:
        Row(
          children:
          <Widget>[
            CircleAvatar(
              radius:
              18,

              backgroundImage:
              widget.otherPhotoUrl
                  .trim()
                  .isNotEmpty
                  ? NetworkImage(
                widget.otherPhotoUrl,
              )
                  : null,

              child:
              widget.otherPhotoUrl
                  .trim()
                  .isEmpty
                  ? const Icon(
                Icons.person,
              )
                  : null,
            ),

            const SizedBox(
              width:
              9,
            ),

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,

                mainAxisSize:
                MainAxisSize.min,

                children:
                <Widget>[
                  Text(
                    widget.otherName,

                    maxLines:
                    1,

                    overflow:
                    TextOverflow.ellipsis,

                    style:
                    const TextStyle(
                      fontSize:
                      15,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  if (widget
                      .otherUsername
                      .trim()
                      .isNotEmpty)
                    Text(
                      '@${widget.otherUsername}',

                      maxLines:
                      1,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(
                        fontSize:
                        11,

                        color:
                        Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      body:
      SafeArea(
        child:
        Column(
          children:
          <Widget>[
            //===================================================
            // MESSAGES
            //===================================================

            Expanded(
              child:
              StreamBuilder<
                  QuerySnapshot>(
                stream:
                _chatService
                    .getMessages(
                  widget
                      .otherUserId,
                ),

                builder:
                    (
                    BuildContext
                    context,

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
                      Text(
                        'Start the conversation.',

                        style:
                        TextStyle(
                          color:
                          Colors.grey,
                        ),
                      ),
                    );
                  }

                  return ListView
                      .builder(
                    reverse:
                    true,

                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal:
                      12,

                      vertical:
                      14,
                    ),

                    itemCount:
                    docs.length,

                    itemBuilder:
                        (
                        BuildContext
                        context,
                        int index,
                        ) {
                      final QueryDocumentSnapshot
                      doc =
                      docs[index];

                      final Map<
                          String,
                          dynamic>
                      data =
                      Map<String,
                          dynamic>.from(
                        doc.data()
                        as Map,
                      );

                      _markAsReadIfNeeded(
                        messageId:
                        doc.id,

                        data:
                        data,
                      );

                      final bool mine =
                          (data['senderId'] ??
                              '')
                              .toString() ==
                              currentUid;

                      return _buildMessageBubble(
                        data:
                        data,

                        mine:
                        mine,
                      );
                    },
                  );
                },
              ),
            ),

            //===================================================
            // MESSAGE INPUT
            //===================================================

            Container(
              padding:
              const EdgeInsets
                  .fromLTRB(
                10,
                8,
                10,
                8,
              ),

              decoration:
              const BoxDecoration(
                border:
                Border(
                  top:
                  BorderSide(
                    color:
                    Colors.white10,
                  ),
                ),
              ),

              child:
              Row(
                children:
                <Widget>[
                  Expanded(
                    child:
                    TextField(
                      controller:
                      _messageController,

                      maxLines:
                      5,

                      minLines:
                      1,

                      textInputAction:
                      TextInputAction.send,

                      onSubmitted:
                          (_) {
                        _sendMessage();
                      },

                      decoration:
                      InputDecoration(
                        hintText:
                        'Message...',

                        filled:
                        true,

                        fillColor:
                        Colors.white10,

                        contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal:
                          16,

                          vertical:
                          11,
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

                  const SizedBox(
                    width:
                    5,
                  ),

                  IconButton(
                    onPressed:
                    _sending
                        ? null
                        : _sendMessage,

                    icon:
                    _sending
                        ? const SizedBox(
                      width:
                      20,

                      height:
                      20,

                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,

                        color:
                        Color(
                          0xFF29B6F6,
                        ),
                      ),
                    )
                        : const Icon(
                      Icons.send_rounded,

                      color:
                      Color(
                        0xFF29B6F6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===========================================================
  // MESSAGE BUBBLE
  //===========================================================

  Widget _buildMessageBubble({
    required Map<String, dynamic>
    data,
    required bool mine,
  }) {
    final String type =
    (data['type'] ?? 'text')
        .toString();

    final String text =
    (data['text'] ?? '')
        .toString();

    final Timestamp? createdAt =
    data['createdAt']
    is Timestamp
        ? data['createdAt']
    as Timestamp
        : null;

    return Align(
      alignment:
      mine
          ? Alignment.centerRight
          : Alignment.centerLeft,

      child:
      Container(
        constraints:
        BoxConstraints(
          maxWidth:
          MediaQuery.of(
            context,
          ).size.width *
              0.78,
        ),

        margin:
        const EdgeInsets
            .only(
          bottom:
          8,
        ),

        padding:
        type ==
            'storyReply' ||
            type ==
                'storyShare'
            ? const EdgeInsets
            .all(
          7,
        )
            : const EdgeInsets
            .symmetric(
          horizontal:
          13,

          vertical:
          9,
        ),

        decoration:
        BoxDecoration(
          color:
          mine
              ? const Color(
            0xFF29B6F6,
          ).withOpacity(
            0.24,
          )
              : Colors.white10,

          borderRadius:
          BorderRadius.only(
            topLeft:
            const Radius.circular(
              18,
            ),

            topRight:
            const Radius.circular(
              18,
            ),

            bottomLeft:
            Radius.circular(
              mine
                  ? 18
                  : 4,
            ),

            bottomRight:
            Radius.circular(
              mine
                  ? 4
                  : 18,
            ),
          ),

          border:
          mine
              ? Border.all(
            color:
            const Color(
              0xFF29B6F6,
            ).withOpacity(
              0.35,
            ),
          )
              : null,
        ),

        child:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,

          mainAxisSize:
          MainAxisSize.min,

          children:
          <Widget>[
            if (type ==
                'storyReply' ||
                type ==
                    'storyShare')
              _buildStoryMessageCard(
                data:
                data,

                reply:
                type ==
                    'storyReply',
              )
            else if (type ==
                'image')
              _buildChatImage(
                (data['mediaUrl'] ??
                    '')
                    .toString(),
              )
            else if (type ==
                  'video')
                _buildVideoPlaceholder()
              else
                Text(
                  text,

                  style:
                  const TextStyle(
                    color:
                    Colors.white,

                    fontSize:
                    15,
                  ),
                ),

            if ((type ==
                'storyReply') &&
                text
                    .trim()
                    .isNotEmpty) ...<Widget>[
              const SizedBox(
                height:
                7,
              ),

              Padding(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal:
                  5,
                ),

                child:
                Text(
                  text,

                  style:
                  const TextStyle(
                    color:
                    Colors.white,

                    fontSize:
                    15,
                  ),
                ),
              ),
            ],

            const SizedBox(
              height:
              4,
            ),

            Padding(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal:
                4,
              ),

              child:
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
                  10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===========================================================
  // STORY MESSAGE CARD
  //===========================================================

  Widget _buildStoryMessageCard({
    required Map<String, dynamic>
    data,
    required bool reply,
  }) {
    final String storyId =
    (data['storyId'] ?? '')
        .toString();

    final String previewUrl =
    (data['storyPreviewUrl'] ??
        '')
        .toString();

    return InkWell(
      onTap:
          () {
        _openStory(
          storyId,
        );
      },

      borderRadius:
      BorderRadius.circular(
        14,
      ),

      child:
      Container(
        width:
        220,

        decoration:
        BoxDecoration(
          color:
          Colors.black38,

          borderRadius:
          BorderRadius.circular(
            14,
          ),

          border:
          Border.all(
            color:
            Colors.white12,
          ),
        ),

        clipBehavior:
        Clip.antiAlias,

        child:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,

          children:
          <Widget>[
            if (previewUrl
                .trim()
                .isNotEmpty)
              SizedBox(
                height:
                145,

                width:
                double.infinity,

                child:
                Image.network(
                  previewUrl,

                  fit:
                  BoxFit.cover,

                  errorBuilder:
                      (_, __, ___) =>
                      _storyFallback(),
                ),
              )
            else
              SizedBox(
                height:
                110,

                width:
                double.infinity,

                child:
                _storyFallback(),
              ),

            Padding(
              padding:
              const EdgeInsets
                  .all(
                10,
              ),

              child:
              Row(
                children:
                <Widget>[
                  const Icon(
                    Icons.favorite,

                    color:
                    Color(
                      0xFF29B6F6,
                    ),

                    size:
                    18,
                  ),

                  const SizedBox(
                    width:
                    6,
                  ),

                  Expanded(
                    child:
                    Text(
                      reply
                          ? 'Story reply'
                          : 'Shared story',

                      style:
                      const TextStyle(
                        color:
                        Colors.white,

                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===========================================================
  // STORY FALLBACK
  //===========================================================

  Widget _storyFallback() {
    return Container(
      color:
      const Color(
        0xFF16232B,
      ),

      alignment:
      Alignment.center,

      child:
      const Column(
        mainAxisAlignment:
        MainAxisAlignment.center,

        children:
        <Widget>[
          Icon(
            Icons.favorite,

            color:
            Color(
              0xFF29B6F6,
            ),

            size:
            38,
          ),

          SizedBox(
            height:
            6,
          ),

          Text(
            'Nubify Story',

            style:
            TextStyle(
              color:
              Colors.white,

              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  //===========================================================
  // CHAT IMAGE
  //===========================================================

  Widget _buildChatImage(
      String url,
      ) {
    return ClipRRect(
      borderRadius:
      BorderRadius.circular(
        12,
      ),

      child:
      Image.network(
        url,

        width:
        220,

        height:
        220,

        fit:
        BoxFit.cover,
      ),
    );
  }

  //===========================================================
  // VIDEO PLACEHOLDER
  //===========================================================

  Widget _buildVideoPlaceholder() {
    return Container(
      width:
      220,

      height:
      160,

      alignment:
      Alignment.center,

      decoration:
      BoxDecoration(
        color:
        Colors.black45,

        borderRadius:
        BorderRadius.circular(
          12,
        ),
      ),

      child:
      const Icon(
        Icons
            .play_circle_fill_rounded,

        color:
        Colors.white,

        size:
        52,
      ),
    );
  }

  //===========================================================
  // DISPOSE
  //===========================================================

  @override
  void dispose() {
    _messageController
        .dispose();

    super.dispose();
  }
}
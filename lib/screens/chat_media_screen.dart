import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../services/chat_sevice.dart';

//===============================
// CHAT MEDIA SCREEN
//===============================

class ChatMediaScreen
    extends StatelessWidget {
  ChatMediaScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
  });

  final String otherUserId;

  final String otherName;

  final ChatService
  _chatService =
  ChatService();

  //===============================
  // URL REGEX
  //===============================

  final RegExp _urlRegex =
  RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive:
    false,
  );

  //===============================
  // OPEN URL
  //===============================

  Future<void> _openUrl(
      String url,
      ) async {
    final Uri? uri =
    Uri.tryParse(
      url,
    );

    if (uri == null) {
      return;
    }

    if (await canLaunchUrl(
      uri,
    )) {
      await launchUrl(
        uri,
        mode:
        LaunchMode
            .externalApplication,
      );
    }
  }

  //===============================
  // MEDIA
  //===============================

  Widget _mediaTab(
      List<ChatMessage>
      messages,
      ) {
    final List<ChatMessage>
    media =
    messages
        .where(
          (
          ChatMessage
          message,
          ) =>
      message.isImage ||
          message.isVideo,
    )
        .toList();

    if (media.isEmpty) {
      return _empty(
        'No media sent yet.',
        Icons
            .photo_library_outlined,
      );
    }

    return GridView.builder(
      padding:
      const EdgeInsets.all(
        2,
      ),
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
        3,
        mainAxisSpacing:
        2,
        crossAxisSpacing:
        2,
      ),
      itemCount:
      media.length,
      itemBuilder:
          (
          BuildContext context,
          int index,
          ) {
        final ChatMessage
        message =
        media[index];

        if (message.isVideo) {
          return GestureDetector(
            onTap:
                () {
              _openUrl(
                message.mediaUrl,
              );
            },
            child:
            Container(
              color:
              Colors.white10,
              child:
              Stack(
                alignment:
                Alignment.center,
                children:
                <Widget>[
                  const Positioned.fill(
                    child:
                    Icon(
                      Icons
                          .videocam_rounded,
                      color:
                      Colors.white24,
                      size:
                      42,
                    ),
                  ),
                  Container(
                    width:
                    42,
                    height:
                    42,
                    decoration:
                    const BoxDecoration(
                      color:
                      Colors.black54,
                      shape:
                      BoxShape.circle,
                    ),
                    child:
                    const Icon(
                      Icons
                          .play_arrow_rounded,
                      color:
                      Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap:
              () {
            _openUrl(
              message.mediaUrl,
            );
          },
          child:
          Image.network(
            message.mediaUrl,
            fit:
            BoxFit.cover,
            errorBuilder:
                (
                _,
                __,
                ___,
                ) =>
                Container(
                  color:
                  Colors.white10,
                  child:
                  const Icon(
                    Icons
                        .broken_image_outlined,
                    color:
                    Colors.white38,
                  ),
                ),
          ),
        );
      },
    );
  }

  //===============================
  // LINKS
  //===============================

  Widget _linksTab(
      List<ChatMessage>
      messages,
      ) {
    final List<String>
    links =
    <String>[];

    for (final ChatMessage
    message
    in messages) {
      links.addAll(
        _urlRegex
            .allMatches(
          message.text,
        )
            .map(
              (
              RegExpMatch match,
              ) =>
          match.group(
            0,
          ) ??
              '',
        )
            .where(
              (
              String item,
              ) =>
          item.isNotEmpty,
        ),
      );
    }

    if (links.isEmpty) {
      return _empty(
        'No links sent yet.',
        Icons.link_rounded,
      );
    }

    return ListView.separated(
      itemCount:
      links.length,
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
          BuildContext context,
          int index,
          ) {
        final String link =
        links[index];

        return ListTile(
          leading:
          Container(
            width:
            44,
            height:
            44,
            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFF29B6F6,
              ).withOpacity(
                0.12,
              ),
              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),
            child:
            const Icon(
              Icons
                  .link_rounded,
              color:
              Color(
                0xFF29B6F6,
              ),
            ),
          ),
          title:
          Text(
            link,
            maxLines:
            2,
            overflow:
            TextOverflow
                .ellipsis,
            style:
            const TextStyle(
              color:
              Colors.white,
            ),
          ),
          onTap:
              () {
            _openUrl(
              link,
            );
          },
        );
      },
    );
  }

  //===============================
  // DOCUMENTS
  //===============================

  Widget _documentsTab(
      List<ChatMessage>
      messages,
      ) {
    final List<ChatMessage>
    documents =
    messages
        .where(
          (
          ChatMessage
          message,
          ) =>
      message.isDocument,
    )
        .toList();

    if (documents.isEmpty) {
      return _empty(
        'No documents sent yet.',
        Icons
            .description_outlined,
      );
    }

    return ListView.separated(
      itemCount:
      documents.length,
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
          BuildContext context,
          int index,
          ) {
        final ChatMessage
        message =
        documents[index];

        return ListTile(
          leading:
          Container(
            width:
            44,
            height:
            44,
            decoration:
            BoxDecoration(
              color:
              Colors.white10,
              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),
            child:
            const Icon(
              Icons
                  .description_rounded,
              color:
              Color(
                0xFF29B6F6,
              ),
            ),
          ),
          title:
          Text(
            message.fileName
                .trim()
                .isNotEmpty
                ? message
                .fileName
                : 'Document',
            maxLines:
            2,
            overflow:
            TextOverflow
                .ellipsis,
            style:
            const TextStyle(
              color:
              Colors.white,
            ),
          ),
          onTap:
              () {
            _openUrl(
              message.mediaUrl,
            );
          },
        );
      },
    );
  }

  //===============================
  // EMPTY
  //===============================

  Widget _empty(
      String text,
      IconData icon,
      ) {
    return Center(
      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,
        children:
        <Widget>[
          Icon(
            icon,
            color:
            Colors.white30,
            size:
            48,
          ),
          const SizedBox(
            height:
            10,
          ),
          Text(
            text,
            style:
            const TextStyle(
              color:
              Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    return DefaultTabController(
      length:
      3,
      child:
      Scaffold(
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
          Text(
            'Media with $otherName',
            maxLines:
            1,
            overflow:
            TextOverflow
                .ellipsis,
          ),
          bottom:
          const TabBar(
            indicatorColor:
            Color(
              0xFF29B6F6,
            ),
            labelColor:
            Color(
              0xFF29B6F6,
            ),
            unselectedLabelColor:
            Colors.white54,
            tabs:
            <Widget>[
              Tab(
                text:
                'Media',
              ),
              Tab(
                text:
                'Links',
              ),
              Tab(
                text:
                'Docs',
              ),
            ],
          ),
        ),
        body:
        StreamBuilder<
            QuerySnapshot<
                Map<String,
                    dynamic>>>(
          stream:
          _chatService
              .getMessages(
            otherUserId,
          ),
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

            final List<ChatMessage>
            messages =
            (snapshot.data
                ?.docs ??
                <QueryDocumentSnapshot<
                    Map<String,
                        dynamic>>>[])
                .map(
                  (
                  document,
                  ) =>
                  ChatMessage.fromDocument(
                    document,
                  ),
            )
                .toList();

            return TabBarView(
              children:
              <Widget>[
                _mediaTab(
                  messages,
                ),
                _linksTab(
                  messages,
                ),
                _documentsTab(
                  messages,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
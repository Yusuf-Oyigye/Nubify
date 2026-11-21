import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_message.dart';
import '../services/chat_sevice.dart';
import '../widgets/full_photo_viewer.dart';
import '../widgets/nubify_chat_style.dart';

//===============================
// CHAT MEDIA SCREEN
//
// Every photo, video, link and document shared in a
// chat, split into three tabs.
//===============================

class ChatMediaScreen extends StatefulWidget {
  const ChatMediaScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
    this.initialTab = 0,
  });

  final String otherUserId;

  final String otherName;

  // 0 = Media, 1 = Links, 2 = Docs.
  final int initialTab;

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  final ChatService _chatService = ChatService();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream =
      _chatService.getMessages(widget.otherUserId);

  //===============================
  // OPEN URL
  //===============================

  Future<void> _openUrl(String url) async {
    final Uri? uri = Uri.tryParse(url);

    if (uri == null) {
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openPhoto(String url) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FullPhotoViewer(title: widget.otherName, photoUrl: url),
      ),
    );
  }

  //===============================
  // MEDIA
  //===============================

  Widget _mediaTab(List<ChatMessage> messages) {
    final bool dark = NubifyChatStyle.isDark(context);

    final List<ChatMessage> media = messages
        .where(
          (ChatMessage message) =>
              (message.isImage || message.isVideo) &&
              message.mediaUrl.trim().isNotEmpty,
        )
        .toList();

    if (media.isEmpty) {
      return _empty('No media sent yet.', Icons.photo_library_rounded);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: media.length,
      itemBuilder: (BuildContext context, int index) {
        final ChatMessage message = media[index];

        return Semantics(
          button: true,
          label: message.isVideo ? 'Open video' : 'Open photo',
          child: GestureDetector(
            onTap: () {
              if (message.isVideo) {
                _openUrl(message.mediaUrl);
              } else {
                _openPhoto(message.mediaUrl);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: message.isVideo
                  ? DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: NubifyChatStyle.outgoing,
                      ),
                      child: Center(
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      message.mediaUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: dark
                            ? const Color(0xFF223042)
                            : const Color(0xFFE7EEF8),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey,
                        ),
                      ),
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

  Widget _linksTab(List<ChatMessage> messages) {
    final List<String> links = <String>[
      for (final ChatMessage message in messages)
        for (final RegExpMatch match in _urlRegex.allMatches(message.text))
          if ((match.group(0) ?? '').isNotEmpty) match.group(0)!,
    ];

    if (links.isEmpty) {
      return _empty('No links sent yet.', Icons.link_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: links.length,
      itemBuilder: (BuildContext context, int index) {
        final String link = links[index];

        return _rowCard(
          icon: Icons.link_rounded,
          title: link,
          onTap: () {
            _openUrl(link);
          },
        );
      },
    );
  }

  //===============================
  // DOCUMENTS
  //===============================

  Widget _documentsTab(List<ChatMessage> messages) {
    final List<ChatMessage> documents = messages
        .where((ChatMessage message) => message.isDocument)
        .toList();

    if (documents.isEmpty) {
      return _empty('No documents sent yet.', Icons.description_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: documents.length,
      itemBuilder: (BuildContext context, int index) {
        final ChatMessage message = documents[index];

        return _rowCard(
          icon: Icons.description_rounded,
          title: message.fileName.trim().isNotEmpty
              ? message.fileName
              : 'Document',
          onTap: () {
            _openUrl(message.mediaUrl);
          },
        );
      },
    );
  }

  //===============================
  // ROW CARD
  //===============================

  Widget _rowCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final bool dark = NubifyChatStyle.isDark(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(18);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE3E9F3),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: NubifyChatStyle.brand,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  //===============================
  // EMPTY
  //===============================

  Widget _empty(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          NubifyChatEmptyIcon(icon: icon),
          const SizedBox(height: 14),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  //===============================
  // PILL TABS
  //===============================

  PreferredSizeWidget _tabs() {
    final bool dark = NubifyChatStyle.isDark(context);

    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        height: 44,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1C2735) : const Color(0xFFE8EEF7),
          borderRadius: BorderRadius.circular(22),
        ),
        child: TabBar(
          indicator: BoxDecoration(
            gradient: NubifyChatStyle.brand,
            borderRadius: BorderRadius.circular(18),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: const <Widget>[
            Tab(text: 'Media'),
            Tab(text: 'Links'),
            Tab(text: 'Docs'),
          ],
        ),
      ),
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Media with ${widget.otherName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: _tabs(),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _messagesStream,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: NubifyChatStyle.royal,
                    ),
                  );
                }

                final List<ChatMessage> messages =
                    (snapshot.data?.docs ??
                            <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                        .map(ChatMessage.fromDocument)
                        .toList();

                return TabBarView(
                  children: <Widget>[
                    _mediaTab(messages),
                    _linksTab(messages),
                    _documentsTab(messages),
                  ],
                );
              },
        ),
      ),
    );
  }
}

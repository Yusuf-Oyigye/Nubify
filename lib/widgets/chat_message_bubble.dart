import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/chat_message.dart';
import 'chat_message_status.dart';
import 'chat_voice_message.dart';
import 'chat_link_text.dart';
import 'nubify_shared_chat_card.dart';

//===============================
// CHAT MESSAGE BUBBLE
//===============================

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.otherUserId,
    required this.canShowReadReceipt,
    this.onOpenStory,
    this.onOpenPost,
    this.onOpenProduct,
    this.onReply,
    this.onLongPress,
  });

  final ChatMessage message;

  final bool mine;

  final String otherUserId;

  final bool canShowReadReceipt;

  final VoidCallback? onOpenStory;

  final VoidCallback? onOpenPost;

  final VoidCallback? onOpenProduct;

  final VoidCallback? onReply;

  final VoidCallback? onLongPress;

  static const Color _blue = Color(0xFF29B6F6);
  //===============================
  // MESSAGE BUBBLE COLORS
  //===============================

  static const Color _outgoing = Color(0xFF0D3B66);

  static const Color _incoming = Color(0xFF242B31);

  //===============================
  // TIME
  //===============================

  String _time() {
    final DateTime date =
        message.createdAt?.toDate().toLocal() ?? DateTime.now();

    return DateFormat('h:mm a').format(date);
  }

  //===============================
  // DOCUMENT
  //===============================

  Future<void> _openDocument() async {
    final String url = message.mediaUrl.trim();

    if (url.isEmpty) {
      return;
    }

    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  //===============================
  // IMAGE
  //===============================

  void _openImage(BuildContext context) {
    if (message.mediaUrl.trim().isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(message.mediaUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  //===============================
  // REPLY PREVIEW
  //===============================

  Widget _buildReplyPreview() {
    if (message.replyToMessageId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final String preview = message.replyToText.trim().isNotEmpty
        ? message.replyToText
        : message.replyToType.trim().isNotEmpty
        ? message.replyToType
        : 'Message';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
        border: const Border(left: BorderSide(color: Colors.white70, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (message.replyToSenderName.trim().isNotEmpty)
            Text(
              message.replyToSenderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  //===============================
  // STORY CARD
  //===============================

  // Retained as a fallback renderer for legacy message documents.
  // ignore: unused_element
  Widget _buildStoryCard() {
    return InkWell(
      onTap: onOpenStory,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (message.storyPreviewUrl.trim().isNotEmpty)
              Image.network(
                message.storyPreviewUrl,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _storyFallback(),
              )
            else
              _storyFallback(),

            Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message.isStoryReply
                          ? 'Replied to story'
                          : 'Shared story',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

  //===============================
  // STORY FALLBACK
  //===============================

  Widget _storyFallback() {
    return Container(
      height: 115,
      width: double.infinity,
      color: const Color(0xFF14242E),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.auto_stories_rounded, color: _blue, size: 34),
          SizedBox(height: 5),
          Text(
            'Nubify Story',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  //===============================
  // POST CARD
  //===============================

  // Retained as a fallback renderer for legacy message documents.
  // ignore: unused_element
  Widget _buildPostCard() {
    final String name = message.postFullName.trim().isNotEmpty
        ? message.postFullName
        : message.postUsername.trim().isNotEmpty
        ? '@${message.postUsername}'
        : 'Nubify post';

    return InkWell(
      onTap: onOpenPost,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white12,
                    child: Icon(Icons.person, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (message.postUsername.trim().isNotEmpty)
                          Text(
                            '@${message.postUsername}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (message.postPreviewUrl.trim().isNotEmpty)
              Image.network(
                message.postPreviewUrl,
                width: double.infinity,
                height: 145,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),

            if (message.postCaption.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  message.postCaption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),

            const Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: <Widget>[
                  Icon(Icons.dynamic_feed_rounded, color: _blue, size: 16),
                  SizedBox(width: 5),
                  Text(
                    'Nubify post',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  //===============================
  // PRODUCT CARD
  //===============================

  // Retained as a fallback renderer for legacy message documents.
  // ignore: unused_element
  Widget _buildProductCard() {
    return InkWell(
      onTap: onOpenProduct,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (message.productImageUrl.trim().isNotEmpty)
              Image.network(
                message.productImageUrl,
                width: double.infinity,
                height: 145,
                fit: BoxFit.cover,
              )
            else
              Container(
                width: double.infinity,
                height: 100,
                color: Colors.white10,
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 40,
                  color: _blue,
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.productName.trim().isNotEmpty
                        ? message.productName
                        : 'Marketplace product',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  if (message.productPrice.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      message.productPrice,
                      style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 7),

                  const Row(
                    children: <Widget>[
                      Icon(
                        Icons.storefront_rounded,
                        color: Colors.white60,
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Nubify Marketplace',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===============================
  // CONTENT
  //===============================

  Widget _buildContent(BuildContext context) {
    if (message.deletedForEveryone) {
      return const Row(
        mainAxisSize: MainAxisSize.min,

        children: <Widget>[
          Icon(Icons.block_rounded, size: 17, color: Colors.white54),

          SizedBox(width: 6),

          Text(
            'This message was deleted',
            style: TextStyle(
              color: Colors.white60,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    if (message.isImage) {
      return GestureDetector(
        onTap: () {
          _openImage(context);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.network(
            message.mediaUrl,
            width: 230,
            height: 230,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 230,
              height: 150,
              alignment: Alignment.center,
              color: Colors.white10,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Colors.white60,
              ),
            ),
          ),
        ),
      );
    }

    if (message.isVideo) {
      return _InlineChatVideo(url: message.mediaUrl);
    }

    if (message.isVoice) {
      return ChatVoiceMessage(
        url: message.mediaUrl,
        mine: mine,
        durationMs: message.durationMs,
      );
    }

    if (message.isDocument) {
      return InkWell(
        onTap: _openDocument,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message.fileName.trim().isNotEmpty
                      ? message.fileName
                      : 'Document',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.isSticker) {
      return Text(message.text, style: const TextStyle(fontSize: 52));
    }

    //===========================================
    // SHARED STORY PREVIEW
    //===========================================

    if (message.isStoryShare || message.isStoryReply) {
      return NubifySharedChatCard(message: message, onTap: onOpenStory);
    }

    //===========================================
    // SHARED POST / NUBUZZ PREVIEW
    //===========================================

    if (message.isPost) {
      return NubifySharedChatCard(message: message, onTap: onOpenPost);
    }

    //===========================================
    // SHARED MARKETPLACE PREVIEW
    //===========================================

    if (message.isProduct) {
      return NubifySharedChatCard(message: message, onTap: onOpenProduct);
    }

    return ChatLinkText(
      text: message.text,
      showPreview: !message.linkPreviewDisabled,

      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.32),
    );
  }
  //===============================
  // REACTIONS
  //===============================

  Widget _reactions() {
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<String, int> counts = <String, int>{};

    for (final String emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5),

      child: Wrap(
        spacing: 4,

        children: counts.entries
            .map(
              (entry) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                decoration: BoxDecoration(
                  color: Colors.black26,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Text(
                  entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,

                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final bool sticker = message.isSticker;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress ?? onReply,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.80,
          ),
          margin: EdgeInsets.only(
            left: mine ? 45 : 3,
            right: mine ? 3 : 45,
            bottom: 3,
          ),
          padding: sticker
              ? const EdgeInsets.fromLTRB(5, 2, 5, 3)
              : const EdgeInsets.fromLTRB(9, 8, 9, 5),
          decoration: sticker
              ? null
              : BoxDecoration(
                  color: mine ? _outgoing : _incoming,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 18),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (message.isForwarded)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    '↪ Forwarded',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              _buildReplyPreview(),

              _buildContent(context),
              _reactions(),

              if (message.isStoryReply &&
                  message.text.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 7),
                Text(
                  message.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],

              const SizedBox(height: 4),

              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _time(),
                      style: TextStyle(
                        color: sticker ? Colors.white54 : Colors.white70,
                        fontSize: 9,
                      ),
                    ),

                    if (mine) ...<Widget>[
                      const SizedBox(width: 3),
                      ChatMessageStatus(
                        message: message,
                        targetUserId: otherUserId,
                        canShowReadReceipt: canShowReadReceipt,
                        size: 15,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//===============================
// INLINE CHAT VIDEO
//===============================

class _InlineChatVideo extends StatefulWidget {
  const _InlineChatVideo({required this.url});

  final String url;

  @override
  State<_InlineChatVideo> createState() => _InlineChatVideoState();
}

//===============================
// INLINE CHAT VIDEO STATE
//===============================

class _InlineChatVideoState extends State<_InlineChatVideo> {
  VideoPlayerController? _controller;

  bool _ready = false;

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  //===============================
  // INITIALIZE
  //===============================

  Future<void> _initialize() async {
    if (widget.url.trim().isEmpty) {
      return;
    }

    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );

    _controller = controller;

    try {
      await controller.initialize();

      await controller.setLooping(false);

      if (!mounted) {
        return;
      }

      setState(() {
        _ready = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _ready = false;
      });
    }
  }

  //===============================
  // TOGGLE
  //===============================

  Future<void> _toggle() async {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !_ready) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;

    if (!_ready || controller == null) {
      return Container(
        width: 230,
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    final double ratio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;

    return GestureDetector(
      onTap: _toggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 230,
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(child: VideoPlayer(controller)),

                if (!controller.value.isPlaying)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _controller?.dispose();

    super.dispose();
  }
}

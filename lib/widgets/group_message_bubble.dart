import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/chat_message.dart';
import '../widgets/chat_voice_message.dart';
import '../widgets/chat_link_text.dart';
import 'nubify_shared_chat_card.dart';

//===============================
// GROUP MESSAGE BUBBLE
//===============================

class GroupMessageBubble extends StatelessWidget {
  const GroupMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.memberIds,
    this.onReply,
    this.onLongPress,
    this.onSenderPhotoTap,
  });

  final ChatMessage message;

  final bool mine;

  final String senderName;

  final String senderPhotoUrl;

  final List<String> memberIds;

  final VoidCallback? onReply;

  final VoidCallback? onLongPress;

  final VoidCallback? onSenderPhotoTap;

  static const Color _blue = Color(0xFF29B6F6);

  static const Color _incoming = Color(0xFF242B31);
  //===============================
  // MESSAGE BUBBLE COLORS
  //===============================

  static const Color _outgoing = Color(0xFF0D3B66);

  //===============================
  // TIME
  //===============================

  String _time() {
    return DateFormat(
      'h:mm a',
    ).format(message.createdAt?.toDate().toLocal() ?? DateTime.now());
  }

  //===============================
  // STATUS
  //===============================

  Widget _status() {
    final bool allRead =
        memberIds.isNotEmpty &&
        memberIds.every((String uid) => message.readBy.contains(uid));

    final bool allDelivered =
        memberIds.isNotEmpty &&
        memberIds.every((String uid) => message.deliveredTo.contains(uid));
    if (allRead) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF25D366),
      );
    }

    if (allDelivered) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Colors.white60,
      );
    }

    return const Icon(Icons.done_rounded, size: 15, color: Colors.white60);
  }

  //===============================
  // OPEN URL
  //===============================

  Future<void> _openUrl(String value) async {
    final Uri? uri = Uri.tryParse(value);

    if (uri == null) {
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  //===============================
  // REPLY PREVIEW
  //===============================

  Widget _replyPreview() {
    if (message.replyToMessageId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.17),
        borderRadius: BorderRadius.circular(9),
        border: const Border(left: BorderSide(color: Colors.white70, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (message.replyToSenderName.trim().isNotEmpty)
            Text(
              message.replyToSenderName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),

          Text(
            message.replyToText.trim().isNotEmpty
                ? message.replyToText
                : 'Message',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  //===============================
  // SHARED CARD
  //===============================

  Widget _sharedCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String previewUrl,
  }) {
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (previewUrl.trim().isNotEmpty)
            Image.network(
              previewUrl,
              width: double.infinity,
              height: 135,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: _blue, size: 19),

                const SizedBox(width: 7),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),

                      if (subtitle.trim().isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //===============================
  // CONTENT
  //===============================

  Widget _content() {
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          message.mediaUrl,
          width: 230,
          height: 230,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 230,
            height: 150,
            alignment: Alignment.center,
            color: Colors.white10,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    if (message.isVideo) {
      return _GroupVideo(url: message.mediaUrl);
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
        onTap: () {
          _openUrl(message.mediaUrl);
        },
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: 31,
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Text(
                  message.fileName.trim().isNotEmpty
                      ? message.fileName
                      : 'Document',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
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
    // SHARED CONTENT IN GROUP CHATS
    //===========================================

    if (message.isPost ||
        message.isStoryShare ||
        message.isStoryReply ||
        message.isProduct) {
      return NubifySharedChatCard(message: message);
    }
    return ChatLinkText(
      text: message.text,
      showPreview: !message.linkPreviewDisabled,

      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.33),
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

        runSpacing: 4,

        children: counts.entries
            .map(
              (MapEntry<String, int> entry) => Container(
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

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(BuildContext context) {
    final bool sticker = message.isSticker;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: <Widget>[
          if (!mine) ...<Widget>[
            GestureDetector(
              onTap: onSenderPhotoTap,

              child: CircleAvatar(
                radius: 16,

                backgroundColor: Colors.white10,

                backgroundImage: senderPhotoUrl.trim().isNotEmpty
                    ? NetworkImage(senderPhotoUrl)
                    : null,

                child: senderPhotoUrl.trim().isEmpty
                    ? const Icon(Icons.person_rounded, size: 17)
                    : null,
              ),
            ),

            const SizedBox(width: 6),
          ],

          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress ?? onReply,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.77,
                ),
                padding: sticker
                    ? const EdgeInsets.all(3)
                    : const EdgeInsets.fromLTRB(9, 7, 9, 5),
                decoration: sticker
                    ? null
                    : BoxDecoration(
                        color: mine ? _outgoing : _incoming,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(17),
                          topRight: const Radius.circular(17),
                          bottomLeft: Radius.circular(mine ? 17 : 5),
                          bottomRight: Radius.circular(mine ? 5 : 17),
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!mine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderName,
                          style: const TextStyle(
                            color: Color(0xFF81D4FA),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
                    _replyPreview(),

                    _content(),
                    _reactions(),

                    const SizedBox(height: 4),

                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _time(),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 9,
                            ),
                          ),

                          if (mine) ...<Widget>[
                            const SizedBox(width: 3),

                            _status(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//===============================
// GROUP VIDEO
//===============================

class _GroupVideo extends StatefulWidget {
  const _GroupVideo({required this.url});

  final String url;

  @override
  State<_GroupVideo> createState() => _GroupVideoState();
}

//===============================
// GROUP VIDEO STATE
//===============================

class _GroupVideoState extends State<_GroupVideo> {
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

      if (!mounted) {
        return;
      }

      setState(() {
        _ready = true;
      });
    } catch (_) {}
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
        height: 150,
        alignment: Alignment.center,
        color: Colors.black38,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 230,
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(child: VideoPlayer(controller)),

                if (!controller.value.isPlaying)
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
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

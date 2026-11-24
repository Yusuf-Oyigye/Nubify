import 'package:flutter/material.dart';

import '../../models/huddles/huddle.dart';
import '../../services/huddles/huddle_service.dart';
import '../../widgets/huddles/huddle_ui.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// NUB HUDDLES — LIVE CHAT
//
// Belongs only to this Huddle (not your DMs or
// groups) and is deleted when the Huddle ends.
//===================================================

class HuddleChatSheet extends StatefulWidget {
  const HuddleChatSheet({
    super.key,
    required this.huddleId,
    required this.role,
  });

  final String huddleId;
  final HuddleRole role;

  static Future<void> show(
      BuildContext context, {
        required String huddleId,
        required HuddleRole role,
      }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HuddleColors.stageSoft,
      // Keep the presentation visible above the chat.
      barrierColor: Colors.black26,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .62,
        child: HuddleChatSheet(huddleId: huddleId, role: role),
      ),
    );
  }

  @override
  State<HuddleChatSheet> createState() => _HuddleChatSheetState();
}

class _HuddleChatSheetState extends State<HuddleChatSheet> {
  final HuddleService _service = HuddleService.instance;
  final TextEditingController _text = TextEditingController();

  late final Stream<Huddle?> _huddle = _service.watchHuddle(widget.huddleId);
  late final Stream<List<HuddleChatMessage>> _messages = _service.watchChat(
    widget.huddleId,
  );

  HuddleChatMessage? _replyTo;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _text.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await _service.sendChat(widget.huddleId, text, replyTo: _replyTo);
      _text.clear();
      setState(() => _replyTo = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Message not sent. Chat may be off.'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _options(HuddleChatMessage message) async {
    final bool mine = message.uid == _service.uid;
    final bool canDelete = mine || widget.role.canManage;

    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HuddleColors.stageCard,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.white70),
              title: Text(context.tr('Reply'), style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: HuddleColors.live,
                ),
                title: Text(context.tr('Delete'),
                  style: TextStyle(color: HuddleColors.live),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
          ],
        ),
      ),
    );

    if (choice == 'reply') {
      setState(() => _replyTo = message);
    } else if (choice == 'delete') {
      await _service.deleteChat(widget.huddleId, message.id).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Huddle?>(
      stream: _huddle,
      builder: (context, huddleSnap) {
        final bool chatOn = huddleSnap.data?.chatEnabled ?? true;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.tr('Huddle chat'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<HuddleChatMessage>>(
                  stream: _messages,
                  builder: (context, snapshot) {
                    final List<HuddleChatMessage> messages =
                        snapshot.data ?? const <HuddleChatMessage>[];
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(context.tr('No messages yet. Say hi 👋'),
                          style: TextStyle(color: Colors.white38),
                        ),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) => _Bubble(
                        message: messages[index],
                        onLongPress: () => _options(messages[index]),
                      ),
                    );
                  },
                ),
              ),
              if (!chatOn)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(context.tr('The host has turned off chat.'),
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                _composer(),
            ],
          ),
        );
      },
    );
  }

  Widget _composer() {
    final HuddleChatMessage? reply = _replyTo;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HuddleColors.stageLine)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reply != null)
              Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    size: 16,
                    color: HuddleColors.sky,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr('Replying to {name}: {text}', {'name': reply.name, 'text': reply.text}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _replyTo = null),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: context.tr('Message the Huddle…'),
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: HuddleColors.stageCard,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: HuddleColors.sky,
                  ),
                  onPressed: _sending ? null : _send,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: HuddleColors.stage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onLongPress});

  final HuddleChatMessage message;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HuddleAvatar(
              name: message.name,
              photoUrl: message.photoUrl,
              size: 28,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.name,
                    style: const TextStyle(
                      color: HuddleColors.sky,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message.replyToName.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: HuddleColors.stageCard,
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(color: HuddleColors.sky, width: 2),
                        ),
                      ),
                      child: Text(
                        '${message.replyToName}: ${message.replyToText}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.35,
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
}
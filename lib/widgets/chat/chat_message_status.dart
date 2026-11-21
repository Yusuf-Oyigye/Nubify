import 'package:flutter/material.dart';

import '../../models/chat/chat_message.dart';
import 'nubify_chat_style.dart';

//===============================
// CHAT MESSAGE STATUS
//===============================

class ChatMessageStatus
    extends StatelessWidget {
  const ChatMessageStatus({
    super.key,
    required this.message,
    required this.targetUserId,
    required this.canShowReadReceipt,
    this.size = 16,
  });

  final ChatMessage message;

  final String targetUserId;

  final bool canShowReadReceipt;

  final double size;

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool read =
    message.isReadBy(
      targetUserId,
    );

    final bool delivered =
    message.isDeliveredTo(
      targetUserId,
    );

    //===============================
// READ
//===============================

    if (read) {
      return Icon(
        Icons.done_all_rounded,
        size:
        size,
        color:
        canShowReadReceipt
            ? NubifyChatStyle.readGreen
            : Colors.white60,
        shadows:
        canShowReadReceipt
            ? NubifyChatStyle.tickShadow
            : null,
      );
    }
    //===============================
    // DELIVERED
    //===============================

    if (delivered) {
      return Icon(
        Icons.done_all_rounded,
        size:
        size,
        color:
        Colors.white60,
      );
    }

    //===============================
    // SENT
    //===============================

    return Icon(
      Icons.done_rounded,
      size:
      size,
      color:
      Colors.white60,
    );
  }
}

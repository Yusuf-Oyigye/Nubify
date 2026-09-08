import 'package:flutter/material.dart';

//===============================
// MESSAGE ACTION RESULT
//===============================

class ChatMessageActionResult {
  const ChatMessageActionResult({
    required this.action,
    this.emoji = '',
  });

  final String action;

  final String emoji;
}

//===============================
// MESSAGE ACTIONS
//===============================

Future<ChatMessageActionResult?>
showChatMessageActions({
  required BuildContext context,
  required bool mine,
}) {
  const List<String>
  reactions =
  <String>[
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  return showModalBottomSheet<
      ChatMessageActionResult>(
    context:
    context,
    showDragHandle:
    true,
    backgroundColor:
    const Color(
      0xFF182027,
    ),
    builder:
        (
        BuildContext context,
        ) {
      return SafeArea(
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children:
          <Widget>[
            //===============================
            // REACTIONS
            //===============================

            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal:
                12,
                vertical:
                8,
              ),
              child:
              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceAround,
                children:
                reactions
                    .map(
                      (
                      String emoji,
                      ) =>
                      InkWell(
                        borderRadius:
                        BorderRadius
                            .circular(
                          30,
                        ),
                        onTap:
                            () {
                          Navigator.pop(
                            context,
                            ChatMessageActionResult(
                              action:
                              'react',
                              emoji:
                              emoji,
                            ),
                          );
                        },
                        child:
                        Padding(
                          padding:
                          const EdgeInsets.all(
                            8,
                          ),
                          child:
                          Text(
                            emoji,
                            style:
                            const TextStyle(
                              fontSize:
                              28,
                            ),
                          ),
                        ),
                      ),
                )
                    .toList(),
              ),
            ),

            const Divider(
              height:
              1,
            ),

            ListTile(
              leading:
              const Icon(
                Icons
                    .reply_rounded,
              ),
              title:
              const Text(
                'Reply',
              ),
              onTap:
                  () {
                Navigator.pop(
                  context,
                  const ChatMessageActionResult(
                    action:
                    'reply',
                  ),
                );
              },
            ),

            ListTile(
              leading:
              const Icon(
                Icons
                    .forward_rounded,
              ),
              title:
              const Text(
                'Forward',
              ),
              onTap:
                  () {
                Navigator.pop(
                  context,
                  const ChatMessageActionResult(
                    action:
                    'forward',
                  ),
                );
              },
            ),

            ListTile(
              leading:
              const Icon(
                Icons
                    .delete_outline_rounded,
                color:
                Colors.redAccent,
              ),
              title:
              const Text(
                'Delete',
                style:
                TextStyle(
                  color:
                  Colors.redAccent,
                ),
              ),
              onTap:
                  () {
                Navigator.pop(
                  context,
                  const ChatMessageActionResult(
                    action:
                    'delete',
                  ),
                );
              },
            ),

            const SizedBox(
              height:
              8,
            ),
          ],
        ),
      );
    },
  );
}

//===============================
// DELETE MESSAGE DIALOG
//===============================

Future<String?>
showDeleteMessageDialog({
  required BuildContext context,
  required bool mine,
}) {
  return showDialog<String>(
    context:
    context,
    builder:
        (
        BuildContext context,
        ) {
      return AlertDialog(
        title:
        const Text(
          'Delete message?',
        ),
        actions:
        <Widget>[
          TextButton(
            onPressed:
                () {
              Navigator.pop(
                context,
              );
            },
            child:
            const Text(
              'Cancel',
            ),
          ),

          TextButton(
            onPressed:
                () {
              Navigator.pop(
                context,
                'me',
              );
            },
            child:
            const Text(
              'Delete for me',
            ),
          ),

          if (mine)
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  context,
                  'everyone',
                );
              },
              child:
              const Text(
                'Delete for everyone',
                style:
                TextStyle(
                  color:
                  Colors.redAccent,
                ),
              ),
            ),
        ],
      );
    },
  );
}
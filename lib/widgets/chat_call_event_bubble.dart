import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/nubify_call_display.dart';

//===================================================
// CHAT CALL EVENT BUBBLE
//===================================================

class ChatCallEventBubble extends StatelessWidget {
  const ChatCallEventBubble({
    super.key,
    required this.call,
    required this.viewerId,
    required this.onCall,
  });

  final Map<String, dynamic> call;
  final String viewerId;
  final VoidCallback onCall;

  //===================================================
  // BUILD CALL BUBBLE
  //===================================================

  @override
  Widget build(BuildContext context) {
    final bool outgoing =
        (call['callerId'] ?? '').toString() == viewerId;

    final bool missed =
    NubifyCallDisplay.isMissedFor(call, viewerId);

    final String label =
    NubifyCallDisplay.label(call, viewerId);

    final String duration =
    NubifyCallDisplay.duration(call);

    final Color accent =
    NubifyCallDisplay.color(call, viewerId);

    final String time = DateFormat('h:mm a').format(
      NubifyCallDisplay.time(call),
    );

    return Align(
        alignment: outgoing
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onCall,
          child: Container(
        constraints: const BoxConstraints(
          maxWidth: 270,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
        padding: const EdgeInsets.fromLTRB(
          12,
          11,
          6,
          9,
        ),
        decoration: BoxDecoration(
          color: outgoing
              ? const Color(0xFF0D3B66)
              : const Color(0xFF242B31),
          borderRadius: BorderRadius.circular(15),
          border: missed
              ? Border.all(
            color: Colors.redAccent.withValues(
              alpha: 0.45,
            ),
          )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            //===================================================
            // CALL STATUS ICON
            //===================================================

            Container(
              width: 39,
              height: 39,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                NubifyCallDisplay.icon(call, viewerId),
                color: accent,
                size: 21,
              ),
            ),

            const SizedBox(width: 9),

            //===================================================
            // CALL DETAILS
            //===================================================

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: missed
                          ? Colors.redAccent
                          : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    duration.isNotEmpty
                        ? '$duration · $time'
                        : time,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            //===================================================
            // CALL AGAIN BUTTON
            //===================================================

            IconButton(
              tooltip: 'Call again',
              visualDensity: VisualDensity.compact,
              onPressed: onCall,
              icon: const Icon(
                Icons.call_rounded,
                size: 19,
                color: NubifyCallDisplay.blue,
              ),
            ),
          ],
        ),
      ),
        ),
    );
  }
}
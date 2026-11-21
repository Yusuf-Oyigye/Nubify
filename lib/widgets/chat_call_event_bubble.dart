import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/nubify_call_display.dart';
import 'nubify_chat_style.dart';

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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
    final bool outgoing = (call['callerId'] ?? '').toString() == viewerId;

    final bool missed = NubifyCallDisplay.isMissedFor(call, viewerId);

    final String label = NubifyCallDisplay.label(call, viewerId);

    final String duration = NubifyCallDisplay.duration(call);

    final Color accent = NubifyCallDisplay.color(call, viewerId);

    final String time = DateFormat(
      'h:mm a',
    ).format(NubifyCallDisplay.time(call));

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCall,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 270),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 11, 6, 9),
          decoration: BoxDecoration(
            gradient: outgoing ? NubifyChatStyle.outgoing : null,
            color: outgoing
                ? null
                : (dark ? const Color(0xFF1D2836) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: missed
                ? Border.all(color: Colors.redAccent.withValues(alpha: 0.45))
                : (outgoing
                      ? null
                      : Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFE1E8F2),
                        )),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.28 : 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
                  color: outgoing && !missed
                      ? Colors.white.withValues(alpha: 0.18)
                      : accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  NubifyCallDisplay.icon(call, viewerId),
                  color: outgoing && !missed ? Colors.white : accent,
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
                            : (outgoing ? Colors.white : scheme.onSurface),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration.isNotEmpty ? '$duration · $time' : time,
                      style: TextStyle(
                        color: outgoing
                            ? Colors.white70
                            : scheme.onSurfaceVariant,
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
                icon: Icon(
                  Icons.call_rounded,
                  size: 19,
                  color: outgoing ? Colors.white : NubifyCallDisplay.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../screens/huddles/huddle_room_screen.dart';
import '../services/huddle_session.dart';
import 'huddle_ui.dart';

//===================================================
// NUB HUDDLES — MINIMISED HUDDLE BAR
//
// Shows while you are in a Huddle and browsing the
// rest of Nubify. Tap it to go back. Invisible (zero
// size) when you are not in a Huddle.
//===================================================

class HuddleMiniBar extends StatelessWidget {
  const HuddleMiniBar({super.key, this.inline = false});

  // true inside a page; false docked above the tabs.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final HuddleSession session = HuddleSession.instance;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final String? id = session.huddleId;
        if (id == null || !session.isActive) {
          return const SizedBox.shrink();
        }

        final String status = switch (session.connection) {
          HuddleConnection.connecting => 'Connecting…',
          HuddleConnection.reconnecting => 'Reconnecting…',
          HuddleConnection.poor => 'Poor connection',
          _ =>
          session.sharingScreen
              ? 'You are presenting'
              : session.micOn
              ? 'Your mic is on'
              : 'Listening',
        };

        return Material(
          color: HuddleColors.stage,
          borderRadius: inline ? BorderRadius.circular(18) : null,
          child: InkWell(
            borderRadius: inline ? BorderRadius.circular(18) : null,
            onTap: () => Navigator.of(context).push(HuddleRoomScreen.route(id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: HuddleColors.speaking,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (session.micOn)
                    IconButton(
                      tooltip: 'Mute',
                      onPressed: session.toggleMic,
                      icon: const Icon(Icons.mic_rounded, color: Colors.white),
                    ),
                  TextButton(
                    onPressed: session.leave,
                    child: const Text(
                      'Leave',
                      style: TextStyle(
                        color: HuddleColors.live,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
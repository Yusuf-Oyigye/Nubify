import 'package:flutter/material.dart';

import '../../models/huddles/huddle.dart';
import '../../services/huddles/huddle_service.dart';
import '../../services/huddles/huddle_session.dart';
import 'huddle_ended_screen.dart';
import 'huddle_room_screen.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// OPEN ANY HUDDLE
//
// Used by Huddle cards, links, notifications and the
// mini bar, so every entry point behaves the same:
// - already inside → go back to the room
// - ended → friendly "This Huddle has ended" page
// - live → join as a listener
//===================================================

Future<void> openHuddle(BuildContext context, String huddleId) async {
  final HuddleSession session = HuddleSession.instance;
  final NavigatorState navigator = Navigator.of(context);

  if (session.isIn(huddleId)) {
    await navigator.push(HuddleRoomScreen.route(huddleId));
    return;
  }

  Huddle? huddle;
  try {
    huddle = await HuddleService.instance.getHuddle(huddleId);
  } catch (_) {
    if (context.mounted) {
      _snack(context, context.tr('Could not open this Huddle. Check your connection.'));
    }
    return;
  }

  if (!context.mounted) {
    return;
  }

  if (huddle == null || !huddle.isLive) {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => HuddleEndedScreen(huddle: huddle),
      ),
    );
    return;
  }

  // Only one Huddle at a time.
  if (session.isActive) {
    final bool? switchHuddle = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Leave your current Huddle?')),
        content: Text(
          context.tr('You are in "{title}". Leave it to join "{title2}"?', {'title': session.title, 'title2': huddle!.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Stay')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Leave and join')),
          ),
        ],
      ),
    );
    if (switchHuddle != true) {
      return;
    }
    await session.leave();
  }

  await navigator.push(HuddleRoomScreen.route(huddleId));
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../screens/chat/conversation_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../services/notifications/push_notifications.dart';

//===================================================
// PHONE NOTIFICATION GATE
//
// Wraps the signed-in home. Starts phone notifications
// (asks "Allow notifications?" a moment after the home
// opens) and opens what a tapped notification is about:
//
// - chat: the conversation with the sender
// - group: the group chat
// - notification: the post, story, profile, Huddle
//   or listing, the same way as the Notifications tab
//===================================================

class NubifyPushGate extends StatefulWidget {
  const NubifyPushGate({super.key, required this.child});

  final Widget child;

  @override
  State<NubifyPushGate> createState() => _NubifyPushGateState();
}

class _NubifyPushGateState extends State<NubifyPushGate> {
  StreamSubscription<Map<String, dynamic>>? _taps;

  @override
  void initState() {
    super.initState();
    _taps = PushNotifications.instance.taps.listen(_open);
    _start();
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    // Let the home appear first (and skip the brief
    // sign-in during signup).
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    await PushNotifications.instance.start();

    final Map<String, dynamic>? launch = await PushNotifications.instance
        .launchTap();
    if (launch != null) {
      await _open(launch);
    }
  }

  Future<void> _open(Map<String, dynamic> data) async {
    if (!mounted) {
      return;
    }

    String value(String key) => (data[key] ?? '').toString().trim();

    final NavigatorState navigator = Navigator.of(context);

    switch (value('kind')) {
      case 'chat':
        if (value('senderId').isEmpty) {
          return;
        }
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ConversationScreen(
              otherUserId: value('senderId'),
              otherName: value('senderName'),
              otherUsername: value('senderUsername'),
              otherPhotoUrl: value('senderPhotoUrl'),
            ),
          ),
        );

      case 'group':
        if (value('groupId').isEmpty) {
          return;
        }
        await navigator.pushNamed('/group', arguments: value('groupId'));

      case 'notification':
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => NotificationsScreen(
              openNotificationId: value('notificationId'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

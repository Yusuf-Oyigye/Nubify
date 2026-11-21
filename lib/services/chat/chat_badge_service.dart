import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/chat/nubify_call_display.dart';
import 'chat_sevice.dart';
import 'group_chat_service.dart';

//===================================================
// CHAT BADGE SERVICE
//
// Counts everything still waiting in Chat:
// - unread direct messages
// - unread group messages
// - missed calls you have not looked at yet
//
// Messages go down as you read each chat. Missed calls
// go down when you open the Calls tab. That moment is
// saved on this phone.
//===================================================

class ChatBadgeService {
  ChatBadgeService._();

  static final ChatBadgeService instance = ChatBadgeService._();

  static const String _callsSeenKeyPrefix = 'nubify_calls_seen_at_v1_';

  final ValueNotifier<DateTime?> _callsSeenAt = ValueNotifier<DateTime?>(null);

  String _callsSeenUid = '';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  //===================================================
  // LOAD "CALLS SEEN AT"
  //===================================================

  Future<void> _loadCallsSeenAt(String uid) async {
    if (_callsSeenUid == uid && _callsSeenAt.value != null) {
      return;
    }

    DateTime seenAt = DateTime.now();

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final int? saved = preferences.getInt('$_callsSeenKeyPrefix$uid');

      if (saved != null) {
        seenAt = DateTime.fromMillisecondsSinceEpoch(saved);
      } else {
        // First time: only calls missed from now on count.
        await preferences.setInt(
          '$_callsSeenKeyPrefix$uid',
          seenAt.millisecondsSinceEpoch,
        );
      }
    } catch (_) {}

    _callsSeenUid = uid;
    _callsSeenAt.value = seenAt;
  }

  //===================================================
  // MARK CALLS SEEN
  //===================================================

  Future<void> markCallsSeen() async {
    final String uid = _uid;

    if (uid.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();

    _callsSeenUid = uid;
    _callsSeenAt.value = now;

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setInt(
        '$_callsSeenKeyPrefix$uid',
        now.millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  //===================================================
  // MISSED CALLS NOT SEEN YET
  //===================================================

  Stream<int> missedCallsStream() {
    final String uid = _uid;

    if (uid.isEmpty) {
      return Stream<int>.value(0);
    }

    late final StreamController<int> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? calls;
    List<Map<String, dynamic>> latest = <Map<String, dynamic>>[];
    bool seenLoaded = false;
    bool callsLoaded = false;

    void emit() {
      if (!seenLoaded || !callsLoaded || controller.isClosed) {
        return;
      }

      final DateTime seenAt = _callsSeenAt.value ?? DateTime.now();
      int count = 0;

      for (final Map<String, dynamic> call in latest) {
        if (!NubifyCallDisplay.isMissedFor(call, uid)) {
          continue;
        }

        final dynamic time = call['createdAt'] ?? call['updatedAt'];

        if (time is Timestamp && time.toDate().isAfter(seenAt)) {
          count++;
        }
      }

      controller.add(count);
    }

    controller = StreamController<int>(
      onListen: () {
        _callsSeenAt.addListener(emit);

        _loadCallsSeenAt(uid).then((_) {
          seenLoaded = true;
          emit();
        });

        calls = FirebaseFirestore.instance
            .collection('calls')
            .where('calleeId', isEqualTo: uid)
            .snapshots()
            .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
              latest = snapshot.docs
                  .map(
                    (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                        document.data(),
                  )
                  .toList();
              callsLoaded = true;
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        _callsSeenAt.removeListener(emit);
        await calls?.cancel();
      },
    );

    return controller.stream.distinct();
  }

  //===================================================
  // EVERYTHING PENDING IN CHAT
  //
  // Unread messages + unread group messages + missed
  // calls. A part that fails to load counts as 0.
  //===================================================

  Stream<int> totalPendingStream() {
    late final StreamController<int> controller;
    final List<StreamSubscription<int>> subscriptions =
        <StreamSubscription<int>>[];
    final List<int?> parts = <int?>[null, null, null];

    void emit() {
      if (controller.isClosed || parts.contains(null)) {
        return;
      }

      controller.add(
        parts.fold<int>(0, (int total, int? part) => total + part!),
      );
    }

    controller = StreamController<int>(
      onListen: () {
        final List<Stream<int>> sources = <Stream<int>>[
          ChatService().totalUnreadCountStream(),
          GroupChatService().totalUnreadCountStream(),
          missedCallsStream(),
        ];

        for (int index = 0; index < sources.length; index++) {
          subscriptions.add(
            sources[index].listen(
              (int count) {
                parts[index] = count;
                emit();
              },
              onError: (Object error) {
                debugPrint('Chat badge part unavailable: $error');
                parts[index] = 0;
                emit();
              },
            ),
          );
        }
      },
      onCancel: () async {
        for (final StreamSubscription<int> subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream.distinct();
  }
}

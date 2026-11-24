import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/stories/story.dart';
import '../../../services/stories/story_service.dart';
import '../../../utils/chat/nubify_call_display.dart';
import '../../../widgets/chat/chat_story_avatar.dart';
import '../../../widgets/chat/nubify_chat_style.dart';
import 'audio_call_screen.dart';
import '../conversation_screen.dart';
import '../../../l10n/nubify_text.dart';

//===================================================
// CALL HISTORY TAB
//===================================================

class CallHistoryTab extends StatefulWidget {
  const CallHistoryTab({super.key});

  @override
  State<CallHistoryTab> createState() => _CallHistoryTabState();
}

class _CallHistoryTabState extends State<CallHistoryTab> {
  static const Color _blue = Color(0xFF29B6F6);

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _outgoingCallsStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _incomingCallsStream;

  // Active stories, for the ring around each photo.
  StreamSubscription<List<NubifyStory>>? _storiesSubscription;

  List<NubifyStory> _stories = const <NubifyStory>[];

  @override
  void initState() {
    super.initState();

    _storiesSubscription = StoryService().watchActiveStories().listen((
      List<NubifyStory> stories,
    ) {
      if (mounted) {
        setState(() => _stories = stories);
      }
    }, onError: (Object _) {});

    final String uid = _auth.currentUser?.uid ?? '';

    _outgoingCallsStream = _firestore
        .collection('calls')
        .where('callerId', isEqualTo: uid)
        .snapshots();

    _incomingCallsStream = _firestore
        .collection('calls')
        .where('calleeId', isEqualTo: uid)
        .snapshots();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>> _users =
      <String, Future<DocumentSnapshot<Map<String, dynamic>>>>{};

  String get _uid => _auth.currentUser?.uid ?? '';

  Future<DocumentSnapshot<Map<String, dynamic>>> _user(String uid) {
    return _users.putIfAbsent(uid, () async {
      final DocumentReference<Map<String, dynamic>> reference = _firestore
          .collection('users')
          .doc(uid);

      try {
        final DocumentSnapshot<Map<String, dynamic>> cached = await reference
            .get(const GetOptions(source: Source.cache));
        if (cached.exists) {
          return cached;
        }
      } catch (_) {}

      return reference.get(const GetOptions(source: Source.serverAndCache));
    });
  }

  DateTime _time(Map<String, dynamic> data) {
    final dynamic raw =
        data['endedAt'] ??
        data['answeredAt'] ??
        data['updatedAt'] ??
        data['createdAt'];

    return raw is Timestamp
        ? raw.toDate().toLocal()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _timeText(DateTime value) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);

    final DateTime day = DateTime(value.year, value.month, value.day);

    final int hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final String clock =
        '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';

    if (day == today) {
      return clock;
    }

    if (day == today.subtract(const Duration(days: 1))) {
      return NubifyText.tr('Yesterday, {time}', {'time': clock});
    }

    return '${value.day}/${value.month}/${value.year}';
  }

  //===================================================
  // DETECT MISSED CALLS
  //===================================================

  bool _missed(Map<String, dynamic> data) {
    return NubifyCallDisplay.isMissedFor(data, _uid);
  }

  //===================================================
  // DISPLAY CALL LABEL
  //===================================================

  String _label(Map<String, dynamic> data) {
    return NubifyCallDisplay.label(data, _uid);
  }

  //===================================================
  // DISPLAY CALL ICON
  //===================================================

  IconData _icon(Map<String, dynamic> data) {
    return NubifyCallDisplay.icon(data, _uid);
  }

  //===================================================
  // OPEN USER CONVERSATION
  //===================================================

  Future<void> _openConversation({
    required String uid,
    required String name,
    required String username,
    required String photoUrl,
    bool startCall = false,
  }) async {
    if (!mounted || uid.isEmpty || uid == _uid) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          otherUserId: uid,
          otherName: name,
          otherUsername: username,
          otherPhotoUrl: photoUrl,
          startCallOnOpen: startCall,
        ),
      ),
    );
  }

  //===================================================
  // START CALL FROM CALL HISTORY
  //===================================================

  Future<void> _call({
    required String uid,
    required String name,
    required String username,
    required String photoUrl,
  }) async {
    if (!mounted || uid.isEmpty || uid == _uid) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AudioCallScreen(
          otherUserId: uid,
          otherName: name,
          otherPhotoUrl: photoUrl,
        ),
      ),
    );
  }

  //===================================================
  // CALL TILE
  //===================================================

  Widget _tile(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Map<String, dynamic> data = document.data();

    final String caller = (data['callerId'] ?? '').toString();

    final String callee = (data['calleeId'] ?? '').toString();

    final String otherUid = caller == _uid ? callee : caller;

    final bool missed = _missed(data);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _user(otherUid),

      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> user =
                snapshot.data?.data() ?? <String, dynamic>{};

            final String fullName = (user['fullName'] ?? '').toString().trim();

            final String username = (user['username'] ?? '').toString().trim();

            final String photo = (user['photoUrl'] ?? '').toString().trim();

            final String name = fullName.isNotEmpty
                ? fullName
                : username.isNotEmpty
                ? username
                : context.tr('Nubify user');

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,

                vertical: 4,
              ),

              //===================================================
              // TAP PHOTO TO VIEW FULL IMAGE
              //===================================================
              leading: NubifyChatStoryAvatar(
                uid: otherUid,
                name: name,
                photoUrl: photo,
                stories: _stories,
                radius: 23,
              ),
              title: Text(
                name,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: TextStyle(
                  color: scheme.onSurface,

                  fontWeight: FontWeight.w700,
                ),
              ),

              subtitle: Row(
                children: <Widget>[
                  Icon(
                    _icon(data),

                    size: 15,

                    color: missed ? Colors.redAccent : _blue,
                  ),

                  const SizedBox(width: 5),

                  Expanded(
                    child: Text(
                      _label(data),

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: missed
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,

                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Text(
                    _timeText(_time(data)),

                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              //===================================================
              // CALL ICON - START CALL
              //===================================================
              trailing: IconButton(
                tooltip: context.tr('Call {name}', {'name': name}),
                onPressed: () {
                  _call(
                    uid: otherUid,
                    name: name,
                    username: username,
                    photoUrl: photo,
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: NubifyChatStyle.royal.withValues(
                    alpha: 0.12,
                  ),
                ),
                icon: const Icon(
                  Icons.call_rounded,
                  color: NubifyChatStyle.royal,
                  size: 21,
                ),
              ),

              //===================================================
              // ROW BODY - OPEN CONVERSATION
              //===================================================
              onTap: () {
                _openConversation(
                  uid: otherUid,
                  name: name,
                  username: username,
                  photoUrl: photo,
                );
              },
            );
          },
    );
  }

  //===================================================
  // MERGED CALL LIST
  //===================================================

  Widget _list({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> outgoing,

    required List<QueryDocumentSnapshot<Map<String, dynamic>>> incoming,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> unique =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in outgoing) {
      unique[document.id] = document;
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in incoming) {
      unique[document.id] = document;
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> calls =
        unique.values.toList()
          ..sort((a, b) => _time(b.data()).compareTo(_time(a.data())));

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> visible = calls;

    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const NubifyChatEmptyIcon(icon: Icons.call_rounded),
            const SizedBox(height: 16),
            Text(context.tr('No recent calls'),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(context.tr('Your voice calls will show up here.'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 90),

      itemCount: visible.length,

      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 84,
        endIndent: 16,
        color: scheme.outlineVariant.withValues(alpha: 0.45),
      ),

      itemBuilder: (_, int index) => _tile(visible[index]),
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final String uid = _uid;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (uid.isEmpty) {
      return Center(child: Text(context.tr('Please log in to view calls.')));
    }

    //===================================================
    // ALL RECENT + MISSED CALLS TOGETHER
    //===================================================

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _outgoingCallsStream,

      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> outgoing,
          ) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _incomingCallsStream,

              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> incoming,
                  ) {
                    if (outgoing.hasError || incoming.hasError) {
                      return Center(
                        child: Text(context.tr('Unable to load call history.'),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      );
                    }

                    return _list(
                      outgoing:
                          outgoing.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                      incoming:
                          incoming.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                    );
                  },
            );
          },
    );
  }

  @override
  void dispose() {
    _storiesSubscription?.cancel();

    super.dispose();
  }

  //===================================================
  // END CALL HISTORY STATE
  //===================================================
}

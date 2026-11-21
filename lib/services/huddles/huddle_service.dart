import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/huddles/huddle.dart';
import '../chat/chat_sevice.dart';
import '../chat/group_chat_service.dart';

//===================================================
// A FRIENDLY ERROR TO SHOW PEOPLE
//===================================================

class HuddleException implements Exception {
  const HuddleException(this.message, {this.ended = false, this.huddleId});

  final String message;

  // True when the Huddle has already ended.
  final bool ended;

  // Set when you already host another live Huddle.
  final String? huddleId;

  @override
  String toString() => message;
}

//===================================================
// NUB HUDDLES — FIRESTORE + BACKEND CALLS
//===================================================

class HuddleService {
  HuddleService._();

  static final HuddleService instance = HuddleService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _huddles =>
      _db.collection('huddles');

  Map<String, String>? _me;

  //===================================================
  // READING
  //===================================================

  // Live Huddles, busiest first.
  Stream<List<Huddle>> watchLive() {
    return _huddles
        .where('status', isEqualTo: 'live')
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final List<Huddle> list = snapshot.docs.map(Huddle.fromDoc).toList()
        ..sort((a, b) => b.participantCount.compareTo(a.participantCount));
      return list;
    });
  }

  Stream<Huddle?> watchHuddle(String huddleId) {
    return _huddles
        .doc(huddleId)
        .snapshots()
        .map((doc) => doc.exists ? Huddle.fromDoc(doc) : null);
  }

  Future<Huddle?> getHuddle(String huddleId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _huddles
        .doc(huddleId)
        .get();
    return doc.exists ? Huddle.fromDoc(doc) : null;
  }

  Stream<List<HuddleParticipant>> watchParticipants(String huddleId) {
    return _huddles
        .doc(huddleId)
        .collection('participants')
        .limit(500)
        .snapshots()
        .map(
          (snapshot) =>
      snapshot.docs.map(HuddleParticipant.fromDoc).toList()
        ..sort(HuddleParticipant.compare),
    );
  }

  // Newest first.
  Stream<List<HuddleChatMessage>> watchChat(String huddleId) {
    return _huddles
        .doc(huddleId)
        .collection('chat')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(HuddleChatMessage.fromDoc).toList(),
    );
  }

  //===================================================
  // BACKEND CALLS
  //===================================================

  Future<HuddleTicket> create({
    required String title,
    required String description,
    required String topic,
    required bool withVideo,
    required HuddlePrivacy privacy,
    required bool allowSpeakerRequests,
    required bool allowVideo,
    required bool allowScreenShare,
    required bool chatEnabled,
  }) async {
    final Map<String, dynamic> result = await _call('huddleCreate', {
      'title': title,
      'description': description,
      'topic': topic,
      'mode': withVideo ? 'video' : 'audio',
      'privacy': privacy.value,
      'allowSpeakerRequests': allowSpeakerRequests,
      'allowVideo': allowVideo,
      'allowScreenShare': allowScreenShare,
      'chatEnabled': chatEnabled,
    });
    return HuddleTicket.fromMap(result);
  }

  Future<HuddleTicket> join(String huddleId) async {
    final Map<String, dynamic> result = await _call('huddleJoin', {
      'huddleId': huddleId,
    });
    return HuddleTicket.fromMap(result);
  }

  // Every in-Huddle action goes through one backend
  // function, which checks the person's role first.
  Future<void> action(
      String huddleId,
      String action, {
        String? targetUid,
        Map<String, Object?> extra = const {},
      }) async {
    await _call('huddleAction', {
      'huddleId': huddleId,
      'action': action,
      'targetUid': ?targetUid,
      ...extra,
    });
  }

  Future<Map<String, dynamic>> _call(
      String name,
      Map<String, Object?> data,
      ) async {
    try {
      final HttpsCallableResult<dynamic> result =
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable(name).call<dynamic>(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final Map<dynamic, dynamic> details = error.details is Map
          ? error.details as Map<dynamic, dynamic>
          : const {};

      throw HuddleException(
        _friendly(error),
        ended: details['ended'] == true,
        huddleId: details['huddleId']?.toString(),
      );
    } catch (_) {
      throw const HuddleException(
        'Could not reach Nubify. Check your connection and try again.',
      );
    }
  }

  String _friendly(FirebaseFunctionsException error) {
    final String message = error.message ?? '';

    // The backend function itself isn't deployed yet.
    if (error.code == 'not-found' && message.toUpperCase() == 'NOT_FOUND') {
      return 'NUB Huddles is not switched on yet.';
    }

    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
        return 'Could not reach Nubify. Check your connection and try again.';
      default:
        return message.isEmpty ? 'Something went wrong. Try again.' : message;
    }
  }

  //===================================================
  // CHAT
  //===================================================

  Future<Map<String, String>> _myProfile() async {
    final Map<String, String>? cached = _me;
    if (cached != null && cached['uid'] == uid) {
      return cached;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc = await _db
        .collection('users')
        .doc(uid)
        .get();
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};

    final Map<String, String> profile = {
      'uid': uid,
      'name': (data['fullName'] ?? data['username'] ?? 'Nubify user')
          .toString(),
      'photoUrl': (data['photoUrl'] ?? '').toString(),
    };
    _me = profile;
    return profile;
  }

  Future<void> sendChat(
      String huddleId,
      String text, {
        HuddleChatMessage? replyTo,
      }) async {
    final String clean = text.trim();
    if (clean.isEmpty) {
      return;
    }

    final Map<String, String> me = await _myProfile();

    await _huddles.doc(huddleId).collection('chat').add({
      'uid': uid,
      'name': me['name'],
      'photoUrl': me['photoUrl'],
      'text': clean.length > 500 ? clean.substring(0, 500) : clean,
      'replyToId': replyTo?.id ?? '',
      'replyToName': replyTo?.name ?? '',
      'replyToText': replyTo == null
          ? ''
          : replyTo.text.length > 120
          ? '${replyTo.text.substring(0, 120)}…'
          : replyTo.text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteChat(String huddleId, String messageId) {
    return _huddles.doc(huddleId).collection('chat').doc(messageId).delete();
  }

  //===================================================
  // INVITES AND SHARING
  //
  // An invite only lets someone join as a listener. It
  // never makes them a speaker or co-host.
  //===================================================

  String inviteText(Huddle huddle) =>
      '🎙️ ${huddle.title}\nLive now on NUB Huddles. Join here:\n${huddle.link}';

  Future<void> invitePeople(
      Huddle huddle, {
        required List<String> userIds,
        required List<String> groupIds,
      }) async {
    final Map<String, String> me = await _myProfile();
    final String text = inviteText(huddle);
    final WriteBatch batch = _db.batch();

    for (final String receiverId in userIds) {
      if (receiverId == uid) {
        continue;
      }

      // Lets them into invite-only Huddles.
      batch.set(_huddles.doc(huddle.id).collection('invites').doc(receiverId), {
        'invitedBy': uid,
        'invitedAt': FieldValue.serverTimestamp(),
      });

      // Shows in their Nubify notifications.
      final DocumentReference<Map<String, dynamic>> note = _db
          .collection('notifications')
          .doc();
      batch.set(note, {
        'notificationId': note.id,
        'receiverId': receiverId,
        'senderId': uid,
        'type': 'huddleInvite',
        'message': '${me['name']} invited you to a Huddle: ${huddle.title}',
        'huddleId': huddle.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Also drop the link into their chats.
    final ChatService chats = ChatService();
    final GroupChatService groups = GroupChatService();

    await Future.wait<void>([
      for (final String receiverId in userIds)
        if (receiverId != uid)
          chats.sendMessage(receiverId: receiverId, text: text),
      for (final String groupId in groupIds)
        groups.sendMessage(groupId: groupId, text: text),
    ]);
  }
}
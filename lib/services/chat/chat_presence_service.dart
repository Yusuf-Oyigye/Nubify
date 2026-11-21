import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

//===============================
// CHAT PRESENCE SERVICE
//===============================

class ChatPresenceService {
  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  Timer? _heartbeatTimer;

  //===============================
  // CURRENT UID
  //===============================

  String? get currentUid =>
      _auth.currentUser?.uid;

  //===============================
  // PRESENCE REFERENCE
  //===============================

  DocumentReference<
      Map<String, dynamic>>
  _presenceReference(
      String uid,
      ) {
    return _firestore
        .collection(
      'userPresence',
    )
        .doc(
      uid,
    );
  }

  //===============================
  // GO ONLINE
  //===============================

  Future<void>
  setOnline() async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    await _presenceReference(
      uid,
    ).set(
      <String, dynamic>{
        'uid':
        uid,

        'online':
        true,

        'lastSeenAt':
        FieldValue
            .serverTimestamp(),

        'updatedAt':
        FieldValue
            .serverTimestamp(),
      },

      SetOptions(
        merge:
        true,
      ),
    );
  }

  //===============================
  // GO OFFLINE
  //===============================

  Future<void>
  setOffline() async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    _heartbeatTimer
        ?.cancel();

    _heartbeatTimer =
    null;

    await _presenceReference(
      uid,
    ).set(
      <String, dynamic>{
        'uid':
        uid,

        'online':
        false,

        'lastSeenAt':
        FieldValue
            .serverTimestamp(),

        'updatedAt':
        FieldValue
            .serverTimestamp(),
      },

      SetOptions(
        merge:
        true,
      ),
    );
  }

  //===============================
  // START HEARTBEAT
  //===============================

  Future<void>
  startHeartbeat() async {
    await setOnline();

    _heartbeatTimer
        ?.cancel();

    _heartbeatTimer =
        Timer.periodic(
          const Duration(
            seconds:
            45,
          ),
              (_) async {
            await setOnline();
          },
        );
  }

  //===============================
  // STOP HEARTBEAT
  //===============================

  Future<void>
  stopHeartbeat() async {
    _heartbeatTimer
        ?.cancel();

    _heartbeatTimer =
    null;

    await setOffline();
  }

  //===============================
  // PRESENCE STREAM
  //===============================

  Stream<DocumentSnapshot<
      Map<String, dynamic>>>
  presenceStream(
      String uid,
      ) {
    return _presenceReference(
      uid,
    ).snapshots();
  }

  //===============================
  // SET TYPING
  //===============================

  Future<void> setTyping({
    required String conversationId,
    required bool typing,
  }) async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty ||
        conversationId
            .trim()
            .isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    reference =
    _firestore
        .collection(
      'conversations',
    )
        .doc(
      conversationId,
    )
        .collection(
      'typing',
    )
        .doc(
      uid,
    );

    if (!typing) {
      await reference.delete();

      return;
    }

    await reference.set(
      <String, dynamic>{
        'uid':
        uid,

        'typing':
        true,

        'updatedAt':
        FieldValue
            .serverTimestamp(),
      },
    );
  }

  //===============================
  // SET RECORDING
  //===============================

  Future<void> setRecording({
    required String conversationId,
    required bool recording,
  }) async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty ||
        conversationId
            .trim()
            .isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    reference =
    _firestore
        .collection(
      'conversations',
    )
        .doc(
      conversationId,
    )
        .collection(
      'recording',
    )
        .doc(
      uid,
    );

    if (!recording) {
      await reference.delete();

      return;
    }

    await reference.set(
      <String, dynamic>{
        'uid':
        uid,

        'recording':
        true,

        'updatedAt':
        FieldValue
            .serverTimestamp(),
      },
    );
  }

  //===============================
  // TYPING STREAM
  //===============================

  Stream<bool> typingStream({
    required String conversationId,
    required String otherUid,
  }) {
    if (conversationId
        .trim()
        .isEmpty ||
        otherUid
            .trim()
            .isEmpty) {
      return Stream<bool>.value(
        false,
      );
    }

    return _firestore
        .collection(
      'conversations',
    )
        .doc(
      conversationId,
    )
        .collection(
      'typing',
    )
        .doc(
      otherUid,
    )
        .snapshots()
        .map(
          (
          DocumentSnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        if (!snapshot.exists) {
          return false;
        }

        final Timestamp?
        updatedAt =
        snapshot.data()?[
        'updatedAt']
        is Timestamp
            ? snapshot.data()![
        'updatedAt']
        as Timestamp
            : null;

        if (updatedAt ==
            null) {
          return false;
        }

        final Duration age =
        DateTime.now()
            .difference(
          updatedAt
              .toDate(),
        );

        return snapshot.data()?[
        'typing'] ==
            true &&
            age.inSeconds <
                15;
      },
    );
  }

  //===============================
  // RECORDING STREAM
  //===============================

  Stream<bool> recordingStream({
    required String conversationId,
    required String otherUid,
  }) {
    if (conversationId
        .trim()
        .isEmpty ||
        otherUid
            .trim()
            .isEmpty) {
      return Stream<bool>.value(
        false,
      );
    }

    return _firestore
        .collection(
      'conversations',
    )
        .doc(
      conversationId,
    )
        .collection(
      'recording',
    )
        .doc(
      otherUid,
    )
        .snapshots()
        .map(
          (
          DocumentSnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        if (!snapshot.exists) {
          return false;
        }

        final Timestamp?
        updatedAt =
        snapshot.data()?[
        'updatedAt']
        is Timestamp
            ? snapshot.data()![
        'updatedAt']
        as Timestamp
            : null;

        if (updatedAt ==
            null) {
          return false;
        }

        final Duration age =
        DateTime.now()
            .difference(
          updatedAt
              .toDate(),
        );

        return snapshot.data()?[
        'recording'] ==
            true &&
            age.inSeconds <
                15;
      },
    );
  }

  //===============================
  // DISPOSE
  //===============================

  void dispose() {
    _heartbeatTimer
        ?.cancel();

    _heartbeatTimer =
    null;
  }
}
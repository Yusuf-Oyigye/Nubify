import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

//===============================
// CHAT PRIVACY SERVICE
//===============================

class ChatPrivacyService {
  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  //===============================
  // CURRENT UID
  //===============================

  String? get currentUid =>
      _auth.currentUser?.uid;

  //===============================
  // SETTINGS REFERENCE
  //===============================

  DocumentReference<
      Map<String, dynamic>>
  _settingsReference(
      String uid,
      ) {
    return _firestore
        .collection(
      'users',
    )
        .doc(
      uid,
    )
        .collection(
      'chatSettings',
    )
        .doc(
      'privacy',
    );
  }

  //===============================
  // ENSURE SETTINGS
  //===============================

  Future<void>
  ensureSettingsExist() async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    final DocumentReference<
        Map<String, dynamic>>
    reference =
    _settingsReference(
      uid,
    );

    final DocumentSnapshot<
        Map<String, dynamic>>
    snapshot =
    await reference.get();

    if (snapshot.exists) {
      return;
    }

    await reference.set(
      <String, dynamic>{
        'readReceiptsEnabled':
        true,

        'updatedAt':
        FieldValue
            .serverTimestamp(),
      },
    );
  }

  //===============================
  // GET READ RECEIPTS
  //===============================

  Future<bool>
  getReadReceiptsEnabled(
      String uid,
      ) async {
    if (uid.trim().isEmpty) {
      return false;
    }

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await _settingsReference(
        uid,
      ).get();

      if (!snapshot.exists) {
        return true;
      }

      final Map<String, dynamic>
      data =
          snapshot.data() ??
              <String, dynamic>{};

      return data[
      'readReceiptsEnabled'] !=
          false;
    } catch (_) {
      return true;
    }
  }

  //===============================
  // OWN READ RECEIPTS STREAM
  //===============================

  Stream<bool>
  ownReadReceiptsStream() {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty) {
      return Stream<bool>.value(
        false,
      );
    }

    return _settingsReference(
      uid,
    )
        .snapshots()
        .map(
          (
          DocumentSnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        if (!snapshot.exists) {
          return true;
        }

        return snapshot.data()?[
        'readReceiptsEnabled'] !=
            false;
      },
    )
        .distinct();
  }

  //===============================
  // USER READ RECEIPTS STREAM
  //===============================

  Stream<bool>
  userReadReceiptsStream(
      String uid,
      ) {
    if (uid.trim().isEmpty) {
      return Stream<bool>.value(
        false,
      );
    }

    return _settingsReference(
      uid,
    )
        .snapshots()
        .map(
          (
          DocumentSnapshot<
              Map<String, dynamic>>
          snapshot,
          ) {
        if (!snapshot.exists) {
          return true;
        }

        return snapshot.data()?[
        'readReceiptsEnabled'] !=
            false;
      },
    )
        .distinct();
  }

  //===============================
  // MUTUAL PRIVACY STREAM
  //===============================

  Stream<bool>
  mutualActivityStream(
      String otherUid,
      ) {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty ||
        otherUid.trim().isEmpty ||
        otherUid == uid) {
      return Stream<bool>.value(
        false,
      );
    }

    late StreamController<bool>
    controller;

    StreamSubscription<bool>?
    ownSubscription;

    StreamSubscription<bool>?
    otherSubscription;

    bool ownEnabled =
    true;

    bool otherEnabled =
    true;

    bool ownLoaded =
    false;

    bool otherLoaded =
    false;

    void emit() {
      if (!ownLoaded ||
          !otherLoaded ||
          controller.isClosed) {
        return;
      }

      controller.add(
        ownEnabled &&
            otherEnabled,
      );
    }

    controller =
        StreamController<bool>(
          onListen: () {
            ownSubscription =
                ownReadReceiptsStream()
                    .listen(
                      (
                      bool value,
                      ) {
                    ownEnabled =
                        value;

                    ownLoaded =
                    true;

                    emit();
                  },
                );

            otherSubscription =
                userReadReceiptsStream(
                  otherUid,
                ).listen(
                      (
                      bool value,
                      ) {
                    otherEnabled =
                        value;

                    otherLoaded =
                    true;

                    emit();
                  },
                );
          },

          onCancel: () async {
            await ownSubscription
                ?.cancel();

            await otherSubscription
                ?.cancel();
          },
        );

    return controller
        .stream
        .distinct();
  }

  //===============================
  // MUTUAL PRIVACY CHECK
  //===============================

  Future<bool>
  canShowMutualActivity(
      String otherUid,
      ) async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty ||
        otherUid.trim().isEmpty ||
        otherUid == uid) {
      return false;
    }

    final List<bool> values =
    await Future.wait(
      <Future<bool>>[
        getReadReceiptsEnabled(
          uid,
        ),

        getReadReceiptsEnabled(
          otherUid,
        ),
      ],
    );

    return values[0] &&
        values[1];
  }

  //===============================
  // SET READ RECEIPTS
  //===============================

  Future<void>
  setReadReceiptsEnabled(
      bool enabled,
      ) async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    await _settingsReference(
      uid,
    ).set(
      <String, dynamic>{
        'readReceiptsEnabled':
        enabled,

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
  // TOGGLE READ RECEIPTS
  //===============================

  Future<void>
  toggleReadReceipts() async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty) {
      return;
    }

    final bool current =
    await getReadReceiptsEnabled(
      uid,
    );

    await setReadReceiptsEnabled(
      !current,
    );
  }
}
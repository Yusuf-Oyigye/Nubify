import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../utils/profile/username_rules.dart';

//===================================================
// USERNAME SERVICE
//
// Usernames are unique, case-insensitive and claimed
// atomically.
//
// - users/{uid}.username keeps the user's own casing,
//   users/{uid}.usernameLower the lowercase form.
// - usernames/{lowercase} is a small "lock" document
//   holding the uid that owns that name. It is created
//   in the same Firestore transaction as the profile
//   change, so two people can never claim one name.
// - Firestore security rules re-check every claim; the
//   UID stays everyone's permanent identity.
//===================================================

enum UsernameStatus { empty, invalid, checking, available, taken, unknown }

class UsernameCheck {
  const UsernameCheck(this.status, this.message);

  final UsernameStatus status;
  final String message;

  bool get isAvailable => status == UsernameStatus.available;

  bool get isTaken => status == UsernameStatus.taken;

  static const UsernameCheck empty = UsernameCheck(UsernameStatus.empty, '');
}

class UsernameTakenException implements Exception {
  const UsernameTakenException();

  @override
  String toString() => UsernameRules.taken;
}

class UsernameService {
  UsernameService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String collection = 'usernames';

  DocumentReference<Map<String, dynamic>> lockFor(String lower) =>
      _firestore.collection(collection).doc(lower);

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  //===================================================
  // CHECK (WHILE TYPING)
  //===================================================

  /// Rules first, then whether someone already owns the
  /// name. [currentUid] is the person checking, so their
  /// own current username counts as available.
  Future<UsernameCheck> check(String input, {String? currentUid}) async {
    if (UsernameRules.clean(input).isEmpty) return UsernameCheck.empty;

    final String? error = UsernameRules.validate(input);
    if (error != null) {
      return UsernameCheck(UsernameStatus.invalid, error);
    }

    final String lower = UsernameRules.normalize(input);

    try {
      final DocumentSnapshot<Map<String, dynamic>> lock = await lockFor(
        lower,
      ).get();

      if (lock.exists && lock.data()?['uid'] != currentUid) {
        return const UsernameCheck(UsernameStatus.taken, UsernameRules.taken);
      }

      // Profiles made before the lock collection existed.
      if (_auth.currentUser != null) {
        final QuerySnapshot<Map<String, dynamic>> older = await _firestore
            .collection('users')
            .where('usernameLower', isEqualTo: lower)
            .limit(2)
            .get();

        if (older.docs.any((doc) => doc.id != currentUid)) {
          return const UsernameCheck(UsernameStatus.taken, UsernameRules.taken);
        }
      }

      return const UsernameCheck(
        UsernameStatus.available,
        UsernameRules.available,
      );
    } on FirebaseException catch (error) {
      debugPrint('Username check unavailable: ${error.code}');
      return const UsernameCheck(
        UsernameStatus.unknown,
        'Could not check right now. We will check again when you continue.',
      );
    }
  }

  //===================================================
  // FINAL CHECK (BEFORE SAVING)
  //===================================================

  /// [check] plus a scan for very old profiles saved before
  /// usernameLower existed. Only runs when saving.
  /// Throws [UsernameTakenException] if the name is used.
  Future<void> ensureAvailable(String username, {required String uid}) async {
    final UsernameCheck result = await check(username, currentUid: uid);

    if (result.isTaken) throw const UsernameTakenException();
    if (result.status == UsernameStatus.invalid) {
      throw Exception(result.message);
    }

    final String lower = UsernameRules.normalize(username);

    try {
      final QuerySnapshot<Map<String, dynamic>> all = await _firestore
          .collection('users')
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in all.docs) {
        if (doc.id == uid || doc.data().containsKey('usernameLower')) continue;

        final String existing = (doc.data()['username'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (existing == lower) throw const UsernameTakenException();
      }
    } on FirebaseException catch (error) {
      // The atomic claim below still protects uniqueness.
      debugPrint('Old-profile username scan skipped: ${error.code}');
    }
  }

  //===================================================
  // CLAIM (INSIDE A TRANSACTION)
  //===================================================

  /// Claims [username] for [uid] inside [transaction] and
  /// releases [previousLower] if [uid] owned it.
  ///
  /// Firestore transactions must read before they write,
  /// so call this before the transaction's own writes.
  /// Throws [UsernameTakenException] if someone else owns
  /// the name, even if they claimed it a moment ago.
  Future<void> claimInTransaction(
    Transaction transaction, {
    required String uid,
    required String username,
    String previousLower = '',
  }) async {
    final String lower = UsernameRules.normalize(username);
    final String previous = previousLower.trim().toLowerCase();

    final DocumentSnapshot<Map<String, dynamic>> lock = await transaction.get(
      lockFor(lower),
    );

    if (lock.exists && lock.data()?['uid'] != uid) {
      throw const UsernameTakenException();
    }

    DocumentSnapshot<Map<String, dynamic>>? oldLock;
    if (previous.isNotEmpty && previous != lower && !previous.contains('/')) {
      oldLock = await transaction.get(lockFor(previous));
    }

    if (!lock.exists) {
      transaction.set(lockFor(lower), <String, dynamic>{
        'uid': uid,
        'username': UsernameRules.clean(username),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (oldLock != null && oldLock.exists && oldLock.data()?['uid'] == uid) {
      transaction.delete(oldLock.reference);
    }
  }

  //===================================================
  // CLAIM AN EXISTING USER'S CURRENT USERNAME
  //
  // People who joined before the lock collection get a
  // lock for their current username the next time they
  // log in. Invalid or already-locked names are skipped
  // (they can pick a new one in Edit Profile).
  //===================================================

  Future<void> claimMyCurrentUsername() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> profile = await transaction
            .get(_user(uid));
        final String username = (profile.data()?['username'] ?? '').toString();

        if (!profile.exists || !UsernameRules.isValid(username)) return;

        final String lower = UsernameRules.normalize(username);
        final DocumentSnapshot<Map<String, dynamic>> lock = await transaction
            .get(lockFor(lower));

        if (lock.exists) return;

        transaction.set(lockFor(lower), <String, dynamic>{
          'uid': uid,
          'username': UsernameRules.clean(username),
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (profile.data()?['usernameLower'] != lower) {
          transaction.update(_user(uid), <String, dynamic>{
            'usernameLower': lower,
          });
        }
      });
    } catch (error) {
      debugPrint('Username lock not claimed: $error');
    }
  }

  //===================================================
  // FREE USERNAME FROM SOME TEXT
  //===================================================

  /// A valid, free username based on [seed] (for example
  /// the part of an email before "@").
  Future<String> freeUsernameFrom(String seed, {required String uid}) async {
    String base = UsernameRules.suggestFrom(seed);
    if (base.isEmpty) {
      base = 'user${uid.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    }
    if (base.length > 16) base = base.substring(0, 16);

    for (int attempt = 0; attempt < 6; attempt++) {
      final String candidate = attempt == 0
          ? base
          : '$base${DateTime.now().microsecond % 1000}';
      final UsernameCheck result = await check(candidate, currentUid: uid);
      if (result.isAvailable || result.status == UsernameStatus.unknown) {
        return candidate;
      }
    }

    return '${base.substring(0, base.length > 12 ? 12 : base.length)}${uid.substring(0, 6).toLowerCase()}';
  }
}

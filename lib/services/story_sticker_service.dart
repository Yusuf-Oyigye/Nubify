import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoryStickerService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===================================================
  // LOAD RECENT STICKERS
  //===================================================

  Future<List<String>>
  getRecentStickers() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return <String>[];
    }

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final dynamic value =
      snapshot.data()?[
      'recentStoryStickers'];

      if (value is! List) {
        return <String>[];
      }

      return value
          .map(
            (dynamic e) =>
            e.toString(),
      )
          .where(
            (String e) =>
        e.trim().isNotEmpty,
      )
          .take(40)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  //===================================================
  // REMEMBER STICKER
  //===================================================

  Future<List<String>>
  rememberSticker(
      String emoji,
      ) async {
    final User? user =
        _auth.currentUser;

    if (user == null ||
        emoji.trim().isEmpty) {
      return <String>[];
    }

    final List<String> recent =
    await getRecentStickers();

    recent.removeWhere(
          (String item) =>
      item == emoji,
    );

    recent.insert(
      0,
      emoji,
    );

    if (recent.length > 40) {
      recent.removeRange(
        40,
        recent.length,
      );
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
      <String, dynamic>{
        'recentStoryStickers':
        recent,
      },
      SetOptions(
        merge: true,
      ),
    );

    return recent;
  }

  //===================================================
  // CLEAR RECENT
  //===================================================

  Future<void>
  clearRecentStickers() async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
      <String, dynamic>{
        'recentStoryStickers':
        <String>[],
      },
      SetOptions(
        merge: true,
      ),
    );
  }
}
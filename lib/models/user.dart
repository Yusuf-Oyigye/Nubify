import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// NUBIFY USER MODEL
//===================================================

class User {
  final String email;
  final String uid;
  final String photoUrl;
  final String username;
  final String fullName;
  final String faculty;
  final String hobbies;
  final String favoriteQuote;

  final List<String> followers;
  final List<String> following;

  final List<String> pinnedPostIds;

  const User({
    required this.email,
    required this.uid,
    required this.photoUrl,
    required this.username,
    required this.fullName,
    required this.faculty,
    required this.hobbies,
    required this.favoriteQuote,
    required this.followers,
    required this.following,
    this.pinnedPostIds =
    const <String>[],
  });

  //===================================================
  // TO JSON
  //===================================================

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username':
      username,

      'usernameLower':
      username
          .trim()
          .toLowerCase(),

      'fullName':
      fullName,

      'uid':
      uid,

      'email':
      email,

      'photoUrl':
      photoUrl,

      'faculty':
      faculty,

      'hobbies':
      hobbies,

      'favoriteQuote':
      favoriteQuote,

      'followers':
      followers,

      'following':
      following,

      'pinnedPostIds':
      pinnedPostIds,
    };
  }

  //===================================================
  // FROM FIRESTORE
  //===================================================

  static User fromSnap(
      DocumentSnapshot snap,
      ) {
    final Map<String, dynamic>
    snapshot =
        (snap.data()
        as Map<String, dynamic>?) ??
            <String, dynamic>{};

    return User(
      username:
      (snapshot['username'] ??
          '')
          .toString(),

      fullName:
      (snapshot['fullName'] ??
          '')
          .toString(),

      uid:
      (snapshot['uid'] ??
          snap.id)
          .toString(),

      email:
      (snapshot['email'] ??
          '')
          .toString(),

      photoUrl:
      (snapshot['photoUrl'] ??
          '')
          .toString(),

      faculty:
      (snapshot['faculty'] ??
          '')
          .toString(),

      hobbies:
      (snapshot['hobbies'] ??
          '')
          .toString(),

      favoriteQuote:
      (snapshot[
      'favoriteQuote'] ??
          '')
          .toString(),

      followers:
      List<String>.from(
        snapshot['followers'] ??
            <String>[],
      ),

      following:
      List<String>.from(
        snapshot['following'] ??
            <String>[],
      ),

      pinnedPostIds:
      List<String>.from(
        snapshot[
        'pinnedPostIds'] ??
            <String>[],
      ),
    );
  }
}
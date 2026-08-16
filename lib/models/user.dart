import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String email;
  final String uid;
  final String photoUrl;
  final String username;
  final String fullName;
  final String faculty;
  final String hobbies;
  final String favoriteQuote;
  final List followers;
  final List following;

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
  });

  Map<String, dynamic> toJson() => {
    "username": username,
    "fullName": fullName,
    "uid": uid,
    "email": email,
    "photoUrl": photoUrl,
    "faculty": faculty,
    "hobbies": hobbies,
    "favoriteQuote": favoriteQuote,
    "followers": followers,
    "following": following,
  };

  static User fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    return User(
      username: snapshot['username'] ?? '',
      fullName: snapshot['fullName'] ?? '',
      uid: snapshot['uid'] ?? '',
      email: snapshot['email'] ?? '',
      photoUrl: snapshot['photoUrl'] ?? '',
      faculty: snapshot['faculty'] ?? '',
      hobbies: snapshot['hobbies'] ?? '',
      favoriteQuote: snapshot['favoriteQuote'] ?? '',
      followers: snapshot['followers'] ?? [],
      following: snapshot['following'] ?? [],
    );
  }
}
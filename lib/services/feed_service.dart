import 'package:cloud_firestore/cloud_firestore.dart';

class FeedService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // GET ALL POSTS
  // ============================================================

  Stream<QuerySnapshot> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ============================================================
  // GET POSTS ONCE
  // ============================================================

  Future<QuerySnapshot> getPostsOnce() async {
    return await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .get();
  }
}
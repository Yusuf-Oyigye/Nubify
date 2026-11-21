import 'package:cloud_firestore/cloud_firestore.dart';

class FeedService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  //===================================================
  // GET ALL POSTS
  //
  // IMPORTANT:
  // DO NOT QUERY:
  // .where('isHidden', isEqualTo: false)
  //
  // Old Nubify posts may not yet contain isHidden,
  // and Firestore would exclude documents where the
  // field does not exist.
  //
  // We therefore read the feed normally and filter
  // visibility inside FeedPostList.
  //===================================================

  Stream<QuerySnapshot> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy(
      'createdAt',
      descending: true,
    )
        .snapshots();
  }

  //===================================================
  // GET POSTS ONCE
  //===================================================

  Future<QuerySnapshot> getPostsOnce() async {
    return await _firestore
        .collection('posts')
        .orderBy(
      'createdAt',
      descending: true,
    )
        .get();
  }

  //===================================================
  // GET ONE POST
  //===================================================

  Future<DocumentSnapshot<Map<String, dynamic>>>
  getPost(
      String postId,
      ) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .get();
  }

  //===================================================
  // WATCH ONE POST
  //
  // USED BY REPOST CARDS SO ORIGINAL CONTENT CAN
  // REMAIN LIVE LIKE X/TWITTER.
  //===================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>>
  watchPost(
      String postId,
      ) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots();
  }

  //===================================================
  // IS PUBLICLY VISIBLE
  //
  // A POST IS HIDDEN FROM EVERYBODY WHEN:
  //
  // isHidden == true
  //
  // A REPOST IS ALSO HIDDEN WHEN ITS REAL ORIGINAL
  // POST HAS BEEN HIDDEN:
  //
  // isRootHidden == true
  //===================================================

  bool isPubliclyVisible(
      Map<String, dynamic> data,
      ) {
    if (data['isHidden'] ==
        true) {
      return false;
    }

    if (data['isRootHidden'] ==
        true) {
      return false;
    }

    return true;
  }

  //===================================================
  // IS ORIGINAL POST
  //===================================================

  bool isOriginalPost(
      Map<String, dynamic> data,
      ) {
    return data['isRepost'] !=
        true;
  }

  //===================================================
  // IS REPOST
  //===================================================

  bool isRepost(
      Map<String, dynamic> data,
      ) {
    return data['isRepost'] ==
        true;
  }

  //===================================================
  // IS QUOTE REPOST
  //===================================================

  bool isQuoteRepost(
      Map<String, dynamic> data,
      ) {
    if (data['isRepost'] !=
        true) {
      return false;
    }

    final String repostType =
    (data['repostType'] ?? '')
        .toString();

    final String repostText =
    (data['repostText'] ??
        data['repostCaption'] ??
        '')
        .toString()
        .trim();

    return repostType ==
        'quote' ||
        repostText.isNotEmpty;
  }
}
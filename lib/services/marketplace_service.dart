import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/marketplace_filter.dart';
import '../models/marketplace_listing.dart';
import '../utils/marketplace_constants.dart';

//===================================================
// MARKETPLACE DATA SERVICE
//===================================================

class MarketplaceListingPage {
  const MarketplaceListingPage({
    required this.listings,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<MarketplaceListing> listings;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class MarketplaceService {
  MarketplaceService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection('marketplaceProducts');

  Stream<List<MarketplaceListing>> watchAvailable({
    String? category,
    String? sellerId,
    int limit = MarketplaceConstants.pageSize,
  }) {
    return _availableQuery(
      category: category,
      sellerId: sellerId,
    ).limit(limit).snapshots().map(_mapListings);
  }

  Future<MarketplaceListingPage> fetchAvailablePage({
    String? category,
    String? sellerId,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = MarketplaceConstants.pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _availableQuery(
      category: category,
      sellerId: sellerId,
    );
    if (after != null) {
      query = query.startAfterDocument(after);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query
        .limit(limit)
        .get();
    return _pageFromSnapshot(snapshot, limit: limit);
  }

  Stream<List<MarketplaceListing>> watchSearch(MarketplaceFilter filter) {
    return _searchQuery(
      filter,
    ).limit(MarketplaceConstants.pageSize).snapshots().map(_mapListings);
  }

  Future<MarketplaceListingPage> fetchSearchPage(
    MarketplaceFilter filter, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = MarketplaceConstants.pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _searchQuery(filter);
    if (after != null) {
      query = query.startAfterDocument(after);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query
        .limit(limit)
        .get();
    return _pageFromSnapshot(snapshot, limit: limit);
  }

  Query<Map<String, dynamic>> _availableQuery({
    String? category,
    String? sellerId,
  }) {
    Query<Map<String, dynamic>> query = _listings
        .where('status', isEqualTo: 'available')
        .where('publicVisible', isEqualTo: true);
    if (category != null && category.trim().isNotEmpty) {
      query = query.where('category', isEqualTo: category.trim());
    }
    if (sellerId != null && sellerId.trim().isNotEmpty) {
      query = query.where('sellerId', isEqualTo: sellerId.trim());
    }
    return query.orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _searchQuery(MarketplaceFilter filter) {
    Query<Map<String, dynamic>> query = _listings
        .where('status', isEqualTo: 'available')
        .where('publicVisible', isEqualTo: true);
    if (filter.category != null) {
      query = query.where('category', isEqualTo: filter.category);
    }
    if (filter.condition != null) {
      query = query.where('condition', isEqualTo: filter.condition);
    }
    final String normalized = filter.query.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      query = query.where('searchPrefixes', arrayContains: normalized);
    }
    if (filter.minimumPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: filter.minimumPrice);
    }
    if (filter.maximumPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: filter.maximumPrice);
    }

    final bool hasPriceRange =
        filter.minimumPrice != null || filter.maximumPrice != null;
    final MarketplaceSort effectiveSort = hasPriceRange
        ? switch (filter.sort) {
            MarketplaceSort.priceHighToLow => MarketplaceSort.priceHighToLow,
            _ => MarketplaceSort.priceLowToHigh,
          }
        : filter.sort;
    switch (effectiveSort) {
      case MarketplaceSort.oldest:
        query = query.orderBy('createdAt');
        break;
      case MarketplaceSort.priceLowToHigh:
        query = query.orderBy('price');
        break;
      case MarketplaceSort.priceHighToLow:
        query = query.orderBy('price', descending: true);
        break;
      case MarketplaceSort.newest:
        query = query.orderBy('createdAt', descending: true);
        break;
    }
    return query;
  }

  Stream<List<MarketplaceListing>> watchMine({String? status}) {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<List<MarketplaceListing>>.empty();
    }
    return _mineQuery(
      uid: uid,
      status: status,
    ).limit(MarketplaceConstants.pageSize).snapshots().map(_mapListings);
  }

  Future<MarketplaceListingPage> fetchMinePage({
    String? status,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = MarketplaceConstants.pageSize,
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to manage your Marketplace listings.');
    }
    Query<Map<String, dynamic>> query = _mineQuery(uid: uid, status: status);
    if (after != null) {
      query = query.startAfterDocument(after);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query
        .limit(limit)
        .get();
    return _pageFromSnapshot(snapshot, limit: limit);
  }

  Future<Map<String, int>> myListingCounts() async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('getMyMarketplaceListingCounts')
        .call<dynamic>();
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      result.data as Map,
    );
    return <String, int>{
      for (final String status in MarketplaceConstants.listingStatuses)
        status: data[status] is num ? (data[status] as num).toInt() : 0,
    };
  }

  Query<Map<String, dynamic>> _mineQuery({
    required String uid,
    String? status,
  }) {
    Query<Map<String, dynamic>> query = _listings.where(
      'sellerId',
      isEqualTo: uid,
    );
    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }
    return query.orderBy('updatedAt', descending: true);
  }

  Stream<MarketplaceListing?> watchListing(String listingId) {
    return _listings
        .doc(listingId)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) => snapshot.exists
              ? MarketplaceListing.fromFirestore(snapshot)
              : null,
        );
  }

  Future<MarketplaceListing?> getListing(String listingId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _listings
        .doc(listingId)
        .get();
    return snapshot.exists ? MarketplaceListing.fromFirestore(snapshot) : null;
  }

  Stream<Set<String>> watchSavedIds() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream<Set<String>>.value(<String>{});
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('savedMarketplaceListings')
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
              .toSet(),
        );
  }

  Stream<List<MarketplaceListing>> watchSavedListings() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<List<MarketplaceListing>>.empty();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('savedMarketplaceListings')
        .orderBy('savedAt', descending: true)
        .limit(MarketplaceConstants.pageSize)
        .snapshots()
        .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
          final List<MarketplaceListing?> loaded = await Future.wait(
            snapshot.docs.map((
              QueryDocumentSnapshot<Map<String, dynamic>> saved,
            ) async {
              try {
                return await getListing(saved.id);
              } on FirebaseException {
                // A seller can return an archived item to a private draft.
                // That one inaccessible item must not prevent every other
                // saved item from loading. Its save marker stays removable.
                return null;
              }
            }),
          );
          return loaded.whereType<MarketplaceListing>().toList(growable: false);
        });
  }

  Future<MarketplaceListingPage> fetchSavedPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = MarketplaceConstants.pageSize,
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to view saved Marketplace listings.');
    }
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(uid)
        .collection('savedMarketplaceListings')
        .orderBy('savedAt', descending: true);
    if (after != null) {
      query = query.startAfterDocument(after);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query
        .limit(limit)
        .get();
    final List<MarketplaceListing?> loaded = await Future.wait(
      snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> marker,
      ) async {
        try {
          return await getListing(marker.id);
        } on FirebaseException {
          return null;
        }
      }),
    );
    return MarketplaceListingPage(
      listings: loaded.whereType<MarketplaceListing>().toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<void> setSaved(String listingId, {required bool saved}) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to save Marketplace listings.');
    }
    final DocumentReference<Map<String, dynamic>> reference = _firestore
        .collection('users')
        .doc(uid)
        .collection('savedMarketplaceListings')
        .doc(listingId);
    if (saved) {
      await reference.set(<String, dynamic>{
        'listingId': listingId,
        'ownerUid': uid,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reference.delete();
    }
  }

  Future<void> reportListing({
    required MarketplaceListing listing,
    required String reason,
    String explanation = '',
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to report this listing.');
    }
    if (uid == listing.sellerId) {
      throw StateError('You cannot report your own listing.');
    }
    if (!MarketplaceConstants.reportReasons.contains(reason)) {
      throw ArgumentError.value(reason, 'reason', 'Choose a valid reason.');
    }
    final String cleanExplanation = explanation.trim();
    if (reason == 'Other' && cleanExplanation.isEmpty) {
      throw const FormatException(
        'Explain why you are reporting this listing.',
      );
    }
    final String reportId = '${uid}_${listing.listingId}';
    final DocumentReference<Map<String, dynamic>> reference = _firestore
        .collection('marketplaceReports')
        .doc(reportId);
    if ((await reference.get()).exists) {
      throw StateError('You already reported this listing.');
    }
    await reference.set(<String, dynamic>{
      'reportId': reportId,
      'reporterId': uid,
      'listingId': listing.listingId,
      'sellerId': listing.sellerId,
      'reason': reason,
      'explanation': cleanExplanation,
      'status': 'submitted',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': '',
      'resolutionNote': '',
    });
  }

  Future<void> publish(String listingId) async {
    await _functions.httpsCallable('publishMarketplaceListing').call<void>(
      <String, dynamic>{'listingId': listingId},
    );
  }

  Future<void> updateStatus(String listingId, String status) async {
    await _functions.httpsCallable('updateMarketplaceListingStatus').call<void>(
      <String, dynamic>{'listingId': listingId, 'status': status},
    );
  }

  Future<void> deleteListing(MarketplaceListing listing) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid != listing.sellerId) {
      throw StateError('Only the listing owner can delete this listing.');
    }
    await _listings.doc(listing.listingId).delete();
  }

  List<MarketplaceListing> _mapListings(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(MarketplaceListing.fromFirestore)
        .toList(growable: false);
  }

  MarketplaceListingPage _pageFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required int limit,
  }) {
    return MarketplaceListingPage(
      listings: _mapListings(snapshot),
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }
}

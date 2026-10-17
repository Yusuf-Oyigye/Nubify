import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/marketplace_filter.dart';
import '../models/marketplace_listing.dart';
import '../utils/marketplace_constants.dart';

//===================================================
// MARKETPLACE DATA SERVICE
//===================================================

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
    Query<Map<String, dynamic>> query = _listings
        .where('status', isEqualTo: 'available')
        .where('publicVisible', isEqualTo: true);
    if (category != null && category.trim().isNotEmpty) {
      query = query.where('category', isEqualTo: category.trim());
    }
    if (sellerId != null && sellerId.trim().isNotEmpty) {
      query = query.where('sellerId', isEqualTo: sellerId.trim());
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapListings);
  }

  Stream<List<MarketplaceListing>> watchSearch(MarketplaceFilter filter) {
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
    if (hasPriceRange) {
      query = query.orderBy(
        'price',
        descending: filter.sort == MarketplaceSort.priceHighToLow,
      );
    } else {
      switch (filter.sort) {
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
    }
    return query.limit(MarketplaceConstants.pageSize).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<MarketplaceListing> listings = _mapListings(snapshot);
      if (hasPriceRange &&
          (filter.sort == MarketplaceSort.newest ||
              filter.sort == MarketplaceSort.oldest)) {
        listings.sort((MarketplaceListing a, MarketplaceListing b) {
          final DateTime first =
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime second =
              b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return filter.sort == MarketplaceSort.newest
              ? second.compareTo(first)
              : first.compareTo(second);
        });
      }
      return listings;
    });
  }

  Stream<List<MarketplaceListing>> watchMine({String? status}) {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream<List<MarketplaceListing>>.empty();
    }
    Query<Map<String, dynamic>> query = _listings.where(
      'sellerId',
      isEqualTo: uid,
    );
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.limit(MarketplaceConstants.pageSize).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<MarketplaceListing> result = _mapListings(snapshot);
      result.sort(
        (MarketplaceListing a, MarketplaceListing b) =>
            (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
      );
      return result;
    });
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
          final List<MarketplaceListing> listings = <MarketplaceListing>[];
          for (final QueryDocumentSnapshot<Map<String, dynamic>> saved
              in snapshot.docs) {
            final MarketplaceListing? listing = await getListing(saved.id);
            if (listing != null) {
              listings.add(listing);
            }
          }
          return listings;
        });
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
}

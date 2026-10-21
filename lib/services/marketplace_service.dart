import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/marketplace_filter.dart';
import '../models/marketplace_listing.dart';
import '../utils/marketplace_constants.dart';
import 'marketplace_media_service.dart';

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

class MarketplaceSellerSummary {
  const MarketplaceSellerSummary({
    required this.sellerId,
    required this.sellerName,
    required this.sellerPhotoUrl,
    required this.availableListingCount,
  });

  factory MarketplaceSellerSummary.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data();
    final dynamic rawCount = data['availableListingCount'];
    return MarketplaceSellerSummary(
      sellerId: (data['sellerId'] ?? snapshot.id).toString(),
      sellerName: (data['sellerName'] ?? 'Student seller').toString(),
      sellerPhotoUrl: (data['sellerPhotoUrl'] ?? '').toString(),
      availableListingCount: rawCount is num ? rawCount.toInt() : 0,
    );
  }

  final String sellerId;
  final String sellerName;
  final String sellerPhotoUrl;
  final int availableListingCount;
}

class MarketplaceHomeDiscovery {
  const MarketplaceHomeDiscovery({
    required this.userId,
    required this.categoryCounts,
    required this.campusSellers,
  });

  final String userId;
  final Map<String, int> categoryCounts;
  final List<MarketplaceSellerSummary> campusSellers;
}

class MarketplaceService {
  MarketplaceService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    MarketplaceMediaService? mediaService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _mediaService = mediaService ?? MarketplaceMediaService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final MarketplaceMediaService _mediaService;

  static MarketplaceListingPage? _cachedFreshPage;
  static MarketplaceHomeDiscovery? _cachedHomeDiscovery;

  MarketplaceListingPage? get cachedFreshPage => _cachedFreshPage;

  MarketplaceHomeDiscovery? get cachedHomeDiscovery {
    final MarketplaceHomeDiscovery? cached = _cachedHomeDiscovery;
    final String uid = _auth.currentUser?.uid ?? '';
    return cached != null && cached.userId == uid ? cached : null;
  }

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
    final MarketplaceListingPage page = _pageFromSnapshot(
      snapshot,
      limit: limit,
    );
    if (after == null &&
        (category == null || category.trim().isEmpty) &&
        (sellerId == null || sellerId.trim().isEmpty)) {
      _cachedFreshPage = page;
    }
    return page;
  }

  /// Loads the small discovery datasets used at the top of Marketplace in
  /// two parallel one-time reads. Previously the home screen maintained 14
  /// separate live listeners for this data, including one per category.
  Future<MarketplaceHomeDiscovery> fetchHomeDiscovery({
    int sellerLimit = 10,
  }) async {
    final String uid = _auth.currentUser?.uid ?? '';
    Query<Map<String, dynamic>> sellerQuery = _firestore.collection(
      'marketplaceSellerStats',
    );
    sellerQuery = sellerQuery.where('availableListingCount', isGreaterThan: 0);
    sellerQuery = sellerQuery.orderBy(
      'availableListingCount',
      descending: true,
    );

    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _optionalRead(
        _firestore
            .collection('marketplaceCategoryStats')
            .limit(MarketplaceConstants.categories.length)
            .get(),
      ),
      _optionalRead(sellerQuery.limit(sellerLimit).get()),
    ]);

    final QuerySnapshot<Map<String, dynamic>>? categorySnapshot =
        results[0] as QuerySnapshot<Map<String, dynamic>>?;
    final QuerySnapshot<Map<String, dynamic>>? sellerSnapshot =
        results[1] as QuerySnapshot<Map<String, dynamic>>?;

    final Map<String, int> categoryCounts = <String, int>{
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in categorySnapshot?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
        document.id: document.data()['availableListingCount'] is num
            ? (document.data()['availableListingCount'] as num).toInt()
            : 0,
    };
    final MarketplaceHomeDiscovery discovery = MarketplaceHomeDiscovery(
      userId: uid,
      categoryCounts: Map<String, int>.unmodifiable(categoryCounts),
      campusSellers: List<MarketplaceSellerSummary>.unmodifiable(
        (sellerSnapshot?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map(MarketplaceSellerSummary.fromFirestore),
      ),
    );
    _cachedHomeDiscovery = discovery;
    return discovery;
  }

  Future<T?> _optionalRead<T>(Future<T> read) async {
    try {
      return await read;
    } on FirebaseException {
      return null;
    }
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
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to manage your Marketplace listings.');
    }
    final List<AggregateQuerySnapshot> snapshots =
        await Future.wait<AggregateQuerySnapshot>(
          MarketplaceConstants.listingStatuses.map(
            (String status) => _listings
                .where('sellerId', isEqualTo: uid)
                .where('status', isEqualTo: status)
                .limit(50)
                .count()
                .get(),
          ),
        );
    return <String, int>{
      for (
        int index = 0;
        index < MarketplaceConstants.listingStatuses.length;
        index++
      )
        MarketplaceConstants.listingStatuses[index]:
            snapshots[index].count ?? 0,
    };
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _ownedListing(
    Transaction transaction,
    String listingId,
    String uid,
  ) async {
    final DocumentReference<Map<String, dynamic>> reference = _listings.doc(
      listingId,
    );
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
        .get(reference);
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('This Marketplace listing no longer exists.');
    }
    if ((data['sellerId'] ?? '').toString() != uid) {
      throw StateError('Only the listing owner can manage this listing.');
    }
    return snapshot;
  }

  Future<Map<String, String>> _ownerProfile(
    Transaction transaction,
    String uid,
  ) async {
    final DocumentSnapshot<Map<String, dynamic>> profile = await transaction
        .get(_firestore.collection('users').doc(uid));
    final Map<String, dynamic>? data = profile.data();
    if (!profile.exists || data == null) {
      throw StateError('Complete your Nubify profile before selling.');
    }
    final String fullName = (data['fullName'] ?? '').toString().trim();
    final String username = (data['username'] ?? '').toString().trim();
    final String sellerName = fullName.isNotEmpty ? fullName : username;
    if (sellerName.isEmpty) {
      throw StateError(
        'Add your name or username in Edit Profile before selling.',
      );
    }
    return <String, String>{
      'sellerName': sellerName,
      'sellerPhotoUrl': (data['photoUrl'] ?? '').toString(),
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
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in before publishing a listing.');
    }
    await _firestore.runTransaction<void>((Transaction transaction) async {
      final Map<String, String> profile = await _ownerProfile(transaction, uid);
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _ownedListing(transaction, listingId, uid);
      final Map<String, dynamic> listing = snapshot.data()!;
      final String currentStatus = (listing['status'] ?? 'draft').toString();
      if (currentStatus == 'available') {
        return;
      }
      if (!<String>{
        'draft',
        'unavailable',
        'archived',
      }.contains(currentStatus)) {
        throw StateError(
          'This listing cannot be published from its current state.',
        );
      }
      transaction.update(snapshot.reference, <String, dynamic>{
        'status': 'available',
        'publicVisible': true,
        ...profile,
        'searchPrefixes': MarketplaceConstants.buildSearchPrefixes(<String>[
          (listing['title'] ?? '').toString(),
          (listing['description'] ?? '').toString(),
          (listing['category'] ?? '').toString(),
          profile['sellerName']!,
        ]),
        'publishedAt': FieldValue.serverTimestamp(),
        'soldAt': null,
        'unavailableAt': null,
        'archivedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    _cachedFreshPage = null;
    _cachedHomeDiscovery = null;
  }

  Future<void> updateStatus(String listingId, String status) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in to manage this listing.');
    }
    if (!<String>{
      'available',
      'sold',
      'unavailable',
      'archived',
    }.contains(status)) {
      throw ArgumentError.value(
        status,
        'status',
        'Unsupported listing status.',
      );
    }
    await _firestore.runTransaction<void>((Transaction transaction) async {
      final Map<String, String> profile = await _ownerProfile(transaction, uid);
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _ownedListing(transaction, listingId, uid);
      final Map<String, dynamic> listing = snapshot.data()!;
      final String currentStatus = (listing['status'] ?? 'draft').toString();
      if (currentStatus == status) {
        return;
      }
      const Map<String, Set<String>> allowed = <String, Set<String>>{
        'draft': <String>{'available', 'archived'},
        'available': <String>{'sold', 'unavailable', 'archived'},
        'unavailable': <String>{'available', 'archived'},
        'sold': <String>{'archived'},
        'archived': <String>{'available'},
      };
      if (!(allowed[currentStatus] ?? const <String>{}).contains(status)) {
        throw StateError(
          'This listing cannot move from $currentStatus to $status.',
        );
      }

      final Map<String, dynamic> changes = <String, dynamic>{
        'status': status,
        'publicVisible': status == 'available',
        ...profile,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      switch (status) {
        case 'available':
          changes.addAll(<String, dynamic>{
            'searchPrefixes': MarketplaceConstants.buildSearchPrefixes(<String>[
              (listing['title'] ?? '').toString(),
              (listing['description'] ?? '').toString(),
              (listing['category'] ?? '').toString(),
              profile['sellerName']!,
            ]),
            'publishedAt': FieldValue.serverTimestamp(),
            'soldAt': null,
            'unavailableAt': null,
            'archivedAt': null,
          });
        case 'sold':
          changes['soldAt'] = FieldValue.serverTimestamp();
        case 'unavailable':
          changes['unavailableAt'] = FieldValue.serverTimestamp();
        case 'archived':
          changes['archivedAt'] = FieldValue.serverTimestamp();
      }
      transaction.update(snapshot.reference, changes);
    });
    _cachedFreshPage = null;
    _cachedHomeDiscovery = null;
  }

  Future<void> deleteListing(MarketplaceListing listing) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid != listing.sellerId) {
      throw StateError('Only the listing owner can delete this listing.');
    }
    await _listings.doc(listing.listingId).delete();
    await _mediaService.deleteUploadedMedia(listing.media);
    _cachedFreshPage = null;
    _cachedHomeDiscovery = null;
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

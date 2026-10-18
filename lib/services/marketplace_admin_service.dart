import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/marketplace_admin_audit.dart';

//===================================================
// TRUSTED MARKETPLACE ACCESS STATE
//===================================================

class MarketplaceAdminAccess {
  const MarketplaceAdminAccess({
    required this.isOwner,
    required this.isAdmin,
    required this.isModerator,
    required this.isReviewer,
  });

  final bool isOwner;
  final bool isAdmin;
  final bool isModerator;
  final bool isReviewer;

  bool get canReview => isOwner || isAdmin || isModerator || isReviewer;
  bool get canManageStaff => isOwner;
}

//===================================================
// MARKETPLACE ADMIN SERVICE
//===================================================

class MarketplaceAdminService {
  MarketplaceAdminService({
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
  final Map<String, String> _userLabelCache = <String, String>{};

  Future<MarketplaceAdminAccess> access({bool forceRefresh = false}) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const MarketplaceAdminAccess(
        isOwner: false,
        isAdmin: false,
        isModerator: false,
        isReviewer: false,
      );
    }
    final IdTokenResult result = await user.getIdTokenResult(forceRefresh);
    final Map<String, dynamic> claims = result.claims ?? <String, dynamic>{};
    return MarketplaceAdminAccess(
      isOwner: claims['marketplaceOwner'] == true,
      isAdmin: claims['admin'] == true,
      isModerator: claims['moderator'] == true,
      isReviewer: claims['marketplaceReviewer'] == true,
    );
  }

  Stream<List<MarketplaceAdminAudit>> watchAuditLog() {
    return _firestore
        .collection('marketplaceAdminAudit')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(MarketplaceAdminAudit.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<String> userLabel(String uid) async {
    final String cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      return 'System';
    }
    final String? cached = _userLabelCache[cleanUid];
    if (cached != null) {
      return cached;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(cleanUid)
          .get();
      final Map<String, dynamic> data =
          snapshot.data() ?? const <String, dynamic>{};
      final String name = (data['fullName'] ?? data['username'] ?? '')
          .toString()
          .trim();
      final String label = name.isEmpty ? cleanUid : '$name · $cleanUid';
      _userLabelCache[cleanUid] = label;
      return label;
    } catch (_) {
      return cleanUid;
    }
  }

  Future<Map<String, dynamic>> findUserByEmail(String email) async {
    final HttpsCallable callable = _functions.httpsCallable(
      'findMarketplaceUserByEmail',
    );
    final HttpsCallableResult<dynamic> result = await callable.call<dynamic>(
      <String, dynamic>{'email': email.trim().toLowerCase()},
    );
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> setStaffRole({
    required String uid,
    required String role,
    required bool enabled,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable(
      'setMarketplaceStaffRole',
    );
    await callable.call<void>(<String, dynamic>{
      'uid': uid.trim(),
      'role': role,
      'enabled': enabled,
    });
  }

  Future<void> transferOwnership(String newOwnerUid) async {
    final HttpsCallable callable = _functions.httpsCallable(
      'transferMarketplaceOwnership',
    );
    await callable.call<void>(<String, dynamic>{
      'newOwnerUid': newOwnerUid.trim(),
    });
    await _auth.currentUser?.getIdToken(true);
  }

  Stream<List<Map<String, dynamic>>> watchReports() {
    return _firestore
        .collection('marketplaceReports')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                    <String, dynamic>{
                      ...document.data(),
                      'reportId': document.id,
                    },
              )
              .toList(growable: false),
        );
  }

  Future<void> reviewReport({
    required String reportId,
    required String decision,
    String resolutionNote = '',
  }) async {
    await _functions
        .httpsCallable('reviewMarketplaceReport')
        .call<void>(<String, dynamic>{
          'reportId': reportId.trim(),
          'decision': decision,
          'resolutionNote': resolutionNote.trim(),
        });
  }
}

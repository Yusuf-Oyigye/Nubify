import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// OWNER-ONLY PRIVATE PROFILE DATA
//===================================================

class PrivateUserProfile {
  const PrivateUserProfile({
    required this.uid,
    required this.phoneE164,
    required this.allowMarketplaceCalls,
    this.updatedAt,
  });

  final String uid;
  final String phoneE164;
  final bool allowMarketplaceCalls;
  final DateTime? updatedAt;

  factory PrivateUserProfile.empty(String uid) {
    return PrivateUserProfile(
      uid: uid,
      phoneE164: '',
      allowMarketplaceCalls: false,
    );
  }

  factory PrivateUserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final dynamic rawUpdatedAt = data['updatedAt'];
    return PrivateUserProfile(
      uid: (data['uid'] ?? snapshot.id).toString(),
      phoneE164: (data['phoneE164'] ?? '').toString(),
      allowMarketplaceCalls: data['allowMarketplaceCalls'] == true,
      updatedAt: rawUpdatedAt is Timestamp ? rawUpdatedAt.toDate() : null,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// PRIVATE SELLER VERIFICATION HISTORY EVENT
//===================================================

class SellerVerificationHistory {
  const SellerVerificationHistory({
    required this.eventId,
    required this.uid,
    required this.verificationId,
    required this.action,
    required this.actorUid,
    required this.reason,
    this.createdAt,
  });

  final String eventId;
  final String uid;
  final String verificationId;
  final String action;
  final String actorUid;
  final String reason;
  final DateTime? createdAt;

  factory SellerVerificationHistory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final dynamic createdAt = data['createdAt'];
    return SellerVerificationHistory(
      eventId: snapshot.id,
      uid: (data['uid'] ?? '').toString(),
      verificationId: (data['verificationId'] ?? '').toString(),
      action: (data['action'] ?? 'updated').toString(),
      actorUid: (data['actorUid'] ?? '').toString(),
      reason: (data['reason'] ?? '').toString(),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

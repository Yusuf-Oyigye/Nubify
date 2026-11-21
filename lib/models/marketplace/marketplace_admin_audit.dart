import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// SERVER-WRITTEN MARKETPLACE ADMIN AUDIT EVENT
//===================================================

class MarketplaceAdminAudit {
  const MarketplaceAdminAudit({
    required this.eventId,
    required this.actorUid,
    required this.action,
    required this.targetUid,
    required this.details,
    this.createdAt,
  });

  final String eventId;
  final String actorUid;
  final String action;
  final String targetUid;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  factory MarketplaceAdminAudit.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final dynamic rawDetails = data['details'];
    final dynamic createdAt = data['createdAt'];
    return MarketplaceAdminAudit(
      eventId: snapshot.id,
      actorUid: (data['actorUid'] ?? '').toString(),
      action: (data['action'] ?? 'admin_action').toString(),
      targetUid: (data['targetUid'] ?? '').toString(),
      details: rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : const <String, dynamic>{},
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// SELLER VERIFICATION MODEL
//===================================================

class SellerVerification {
  const SellerVerification({
    required this.uid,
    required this.fullName,
    required this.studentIdNumber,
    required this.studentIdStoragePath,
    required this.verificationId,
    required this.status,
    this.rejectionReason = '',
    this.suspensionReason = '',
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy = '',
  });

  final String uid;
  final String fullName;
  final String studentIdNumber;
  final String studentIdStoragePath;
  final String verificationId;
  final String status;
  final String rejectionReason;
  final String suspensionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String reviewedBy;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get canResubmit => status == 'notSubmitted' || status == 'rejected';

  factory SellerVerification.notSubmitted(String uid) {
    return SellerVerification(
      uid: uid,
      fullName: '',
      studentIdNumber: '',
      studentIdStoragePath: '',
      verificationId: '',
      status: 'notSubmitted',
    );
  }

  factory SellerVerification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    return SellerVerification(
      uid: (data['uid'] ?? snapshot.id).toString(),
      fullName: (data['fullName'] ?? '').toString(),
      studentIdNumber: (data['studentIdNumber'] ?? '').toString(),
      studentIdStoragePath: (data['studentIdStoragePath'] ?? '').toString(),
      verificationId: (data['verificationId'] ?? '').toString(),
      status: (data['status'] ?? 'notSubmitted').toString(),
      rejectionReason: (data['rejectionReason'] ?? '').toString(),
      suspensionReason: (data['suspensionReason'] ?? '').toString(),
      submittedAt: _date(data['submittedAt']),
      reviewedAt: _date(data['reviewedAt']),
      reviewedBy: (data['reviewedBy'] ?? '').toString(),
    );
  }

  static DateTime? _date(dynamic value) {
    return value is Timestamp ? value.toDate() : null;
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CellularCallService {
  CellularCallService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  static const MethodChannel _channel = MethodChannel(
    'com.nubify.app/cellular_call',
  );
  final FirebaseFunctions _functions;

  Future<String> getSellerPhone(String listingId) async {
    final HttpsCallableResult<dynamic> result = await _functions
        .httpsCallable('getMarketplaceSellerContact')
        .call<dynamic>(<String, dynamic>{'listingId': listingId});
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      result.data as Map,
    );
    final String phone = (data['phoneE164'] ?? '').toString().trim();
    if (phone.isEmpty) {
      throw StateError('This seller has not enabled phone contact.');
    }
    return phone;
  }

  Future<void> callSeller(String listingId) async {
    final String phone = await getSellerPhone(listingId);
    final PermissionStatus status = await Permission.phone.request();
    await _channel.invokeMethod<void>('placeCall', <String, dynamic>{
      'phone': phone,
      'direct': status.isGranted,
    });
  }
}

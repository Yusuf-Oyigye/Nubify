import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/services/marketplace_media_service.dart';

void main() {
  test(
    'Marketplace upload cancellation remains cancelled once requested',
    () async {
      final MarketplaceUploadCancellation cancellation =
          MarketplaceUploadCancellation();

      expect(cancellation.isCancelled, isFalse);

      await cancellation.cancel();

      expect(cancellation.isCancelled, isTrue);
      expect(
        cancellation.throwIfCancelled,
        throwsA(isA<MarketplaceUploadCancelledException>()),
      );
    },
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/marketplace_theme.dart';

//===================================================
// LIVE VERIFIED SELLER BADGE
//===================================================

class MarketplaceVerifiedSellerBadge extends StatelessWidget {
  const MarketplaceVerifiedSellerBadge({
    super.key,
    required this.sellerId,
    this.fallbackText = '',
  });

  final String sellerId;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('marketplaceSellerStats')
          .doc(sellerId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? const <String, dynamic>{};
            final bool verified =
                data['verifiedSeller'] == true &&
                data['verificationStatus'] == 'approved';
            if (!verified) {
              return fallbackText.trim().isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      fallbackText,
                      style: Theme.of(context).textTheme.bodySmall,
                    );
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MarketplaceTheme.sky.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: MarketplaceTheme.sky.withValues(alpha: 0.55),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.verified_rounded,
                    size: 15,
                    color: MarketplaceTheme.sky,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Verified Seller',
                    style: TextStyle(
                      color: MarketplaceTheme.sky,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }
}

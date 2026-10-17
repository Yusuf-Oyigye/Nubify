import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// MARKETPLACE MEDIA
//===================================================

class MarketplaceMedia {
  const MarketplaceMedia({
    required this.type,
    required this.url,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.displayOrder,
    required this.storagePath,
  });

  final String type;
  final String url;
  final String thumbnailUrl;
  final int durationMs;
  final int displayOrder;
  final String storagePath;

  bool get isVideo => type == 'video';

  factory MarketplaceMedia.fromMap(Map<String, dynamic> data) {
    return MarketplaceMedia(
      type: (data['type'] ?? 'image').toString(),
      url: (data['url'] ?? '').toString(),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString(),
      durationMs: _asInt(data['durationMs']),
      displayOrder: _asInt(data['displayOrder']),
      storagePath: (data['storagePath'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'durationMs': durationMs,
      'displayOrder': displayOrder,
      'storagePath': storagePath,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

//===================================================
// MARKETPLACE LISTING
//===================================================

class MarketplaceListing {
  const MarketplaceListing({
    required this.listingId,
    required this.sellerId,
    required this.sellerName,
    required this.sellerPhotoUrl,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.priceType,
    required this.price,
    required this.currency,
    required this.media,
    required this.coverMediaIndex,
    required this.thumbnailUrl,
    required this.status,
    required this.publicVisible,
    required this.allowMessages,
    required this.allowCalls,
    required this.searchPrefixes,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.soldAt,
    this.unavailableAt,
    this.archivedAt,
  });

  final String listingId;
  final String sellerId;
  final String sellerName;
  final String sellerPhotoUrl;
  final String title;
  final String description;
  final String category;
  final String condition;
  final String priceType;
  final double? price;
  final String currency;
  final List<MarketplaceMedia> media;
  final int coverMediaIndex;
  final String thumbnailUrl;
  final String status;
  final bool publicVisible;
  final bool allowMessages;
  final bool allowCalls;
  final List<String> searchPrefixes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? soldAt;
  final DateTime? unavailableAt;
  final DateTime? archivedAt;

  bool get isAvailable => status == 'available' && publicVisible;
  bool get hasVideo => media.any((MarketplaceMedia item) => item.isVideo);
  int get mediaCount => media.length;

  String get priceLabel {
    switch (priceType) {
      case 'free':
        return 'Free';
      case 'contact':
        return 'Contact for Price';
      case 'negotiable':
        return price == null
            ? 'Negotiable'
            : '$currency ${_formatPrice(price!)} · Negotiable';
      case 'fixed':
      default:
        return price == null
            ? 'Price unavailable'
            : '$currency ${_formatPrice(price!)}';
    }
  }

  String get coverUrl {
    if (thumbnailUrl.trim().isNotEmpty) {
      return thumbnailUrl;
    }
    if (media.isEmpty) {
      return '';
    }
    final int safeIndex = coverMediaIndex >= 0 && coverMediaIndex < media.length
        ? coverMediaIndex
        : 0;
    final MarketplaceMedia selected = media[safeIndex];
    return selected.thumbnailUrl.trim().isNotEmpty
        ? selected.thumbnailUrl
        : selected.url;
  }

  factory MarketplaceListing.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final List<MarketplaceMedia> media = _readMedia(data);
    final Map<String, dynamic> contact = data['contactPreferences'] is Map
        ? Map<String, dynamic>.from(data['contactPreferences'] as Map)
        : <String, dynamic>{};
    final dynamic rawPrice = data['price'];

    return MarketplaceListing(
      listingId: (data['listingId'] ?? snapshot.id).toString(),
      sellerId: (data['sellerId'] ?? '').toString(),
      sellerName: (data['sellerName'] ?? '').toString(),
      sellerPhotoUrl: (data['sellerPhotoUrl'] ?? '').toString(),
      title: (data['title'] ?? data['name'] ?? 'Listing').toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? 'other').toString(),
      condition: (data['condition'] ?? 'used').toString(),
      priceType: (data['priceType'] ?? 'fixed').toString(),
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('$rawPrice'),
      currency: (data['currency'] ?? 'EGP').toString(),
      media: media,
      coverMediaIndex: _asInt(data['coverMediaIndex']),
      thumbnailUrl: (data['thumbnailUrl'] ?? data['imageUrl'] ?? '').toString(),
      status:
          (data['status'] ??
                  (data['isAvailable'] == false ? 'unavailable' : 'available'))
              .toString(),
      publicVisible:
          data['publicVisible'] == true ||
          (data['publicVisible'] == null && data['isAvailable'] != false),
      allowMessages: contact['allowMessages'] != false,
      allowCalls: contact['allowCalls'] == true,
      searchPrefixes: List<String>.from(
        data['searchPrefixes'] ?? const <String>[],
      ),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      publishedAt: _date(data['publishedAt']),
      soldAt: _date(data['soldAt']),
      unavailableAt: _date(data['unavailableAt']),
      archivedAt: _date(data['archivedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'listingId': listingId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerPhotoUrl': sellerPhotoUrl,
      'title': title,
      'description': description,
      'category': category,
      'condition': condition,
      'priceType': priceType,
      'price': price,
      'currency': currency,
      'media': media.map((MarketplaceMedia item) => item.toMap()).toList(),
      'mediaCount': media.length,
      'coverMediaIndex': coverMediaIndex,
      'thumbnailUrl': thumbnailUrl,
      'status': status,
      'publicVisible': publicVisible,
      'contactPreferences': <String, dynamic>{
        'allowMessages': allowMessages,
        'allowCalls': allowCalls,
      },
      'searchPrefixes': searchPrefixes,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      'publishedAt': publishedAt == null
          ? null
          : Timestamp.fromDate(publishedAt!),
      'soldAt': soldAt == null ? null : Timestamp.fromDate(soldAt!),
      'unavailableAt': unavailableAt == null
          ? null
          : Timestamp.fromDate(unavailableAt!),
      'archivedAt': archivedAt == null ? null : Timestamp.fromDate(archivedAt!),
    };
  }

  static List<MarketplaceMedia> _readMedia(Map<String, dynamic> data) {
    final dynamic raw = data['media'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (Map item) =>
                MarketplaceMedia.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList()
        ..sort(
          (MarketplaceMedia a, MarketplaceMedia b) =>
              a.displayOrder.compareTo(b.displayOrder),
        );
    }

    final String legacyImage = (data['imageUrl'] ?? '').toString();
    if (legacyImage.isEmpty) {
      return const <MarketplaceMedia>[];
    }
    return <MarketplaceMedia>[
      MarketplaceMedia(
        type: 'image',
        url: legacyImage,
        thumbnailUrl: legacyImage,
        durationMs: 0,
        displayOrder: 0,
        storagePath: '',
      ),
    ];
  }

  static DateTime? _date(dynamic value) {
    return value is Timestamp ? value.toDate() : null;
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}

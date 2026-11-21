import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// LINK PREVIEW MODEL
//===================================================

class LinkPreview {
  const LinkPreview({
    required this.url,
    required this.resolvedUrl,
    required this.canonicalUrl,
    required this.title,
    required this.description,
    required this.siteName,
    required this.domain,
    required this.imageUrl,
    required this.faviconUrl,
    required this.contentType,
    required this.provider,
    required this.creator,
    required this.price,
    required this.statusText,
    required this.internalType,
    required this.internalId,
    required this.isInternal,
    required this.isAvailable,
    required this.actionLabel,
    this.cachedAt,
    this.expiresAt,
  });

  final String url;
  final String resolvedUrl;
  final String canonicalUrl;

  final String title;
  final String description;

  final String siteName;
  final String domain;

  final String imageUrl;
  final String faviconUrl;

  final String contentType;
  final String provider;
  final String creator;
  final String price;
  final String statusText;

  final String internalType;
  final String internalId;

  final bool isInternal;
  final bool isAvailable;

  final String actionLabel;

  final Timestamp? cachedAt;
  final Timestamp? expiresAt;

  //===================================================
  // EMPTY / SAFE FALLBACK
  //===================================================

  factory LinkPreview.fallback(
      String url,
      ) {
    final Uri? uri =
    Uri.tryParse(
      url,
    );

    final String domain =
        uri?.host
            .replaceFirst(
          'www.',
          '',
        ) ??
            'Link';

    return LinkPreview(
      url:
      url,

      resolvedUrl:
      url,

      canonicalUrl:
      url,

      title:
      domain,

      description:
      'Open this link',

      siteName:
      domain,

      domain:
      domain,

      imageUrl:
      '',

      faviconUrl:
      uri == null
          ? ''
          : '${uri.scheme}://${uri.host}/favicon.ico',

      contentType:
      'website',

      provider:
      domain,

      creator:
      '',

      price:
      '',

      statusText:
      '',

      internalType:
      '',

      internalId:
      '',

      isInternal:
      false,

      isAvailable:
      true,

      actionLabel:
      'Open link',
    );
  }

  //===================================================
  // TIMESTAMP
  //===================================================

  static Timestamp? _timestamp(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value;
    }

    if (value is int) {
      return Timestamp.fromMillisecondsSinceEpoch(
        value,
      );
    }

    if (value is num) {
      return Timestamp.fromMillisecondsSinceEpoch(
        value.toInt(),
      );
    }

    if (value is DateTime) {
      return Timestamp.fromDate(
        value,
      );
    }

    if (value is String) {
      final DateTime? parsed =
      DateTime.tryParse(
        value,
      );

      if (parsed != null) {
        return Timestamp.fromDate(
          parsed,
        );
      }
    }

    return null;
  }

  //===================================================
  // FROM MAP
  //===================================================

  factory LinkPreview.fromMap(
      Map<String, dynamic> map,
      ) {
    return LinkPreview(
      url:
      (map['url'] ?? '')
          .toString(),

      resolvedUrl:
      (map['resolvedUrl'] ??
          map['url'] ??
          '')
          .toString(),

      canonicalUrl:
      (map['canonicalUrl'] ??
          map['resolvedUrl'] ??
          map['url'] ??
          '')
          .toString(),

      title:
      (map['title'] ?? '')
          .toString(),

      description:
      (map['description'] ?? '')
          .toString(),

      siteName:
      (map['siteName'] ??
          map['domain'] ??
          '')
          .toString(),

      domain:
      (map['domain'] ?? '')
          .toString(),

      imageUrl:
      (map['imageUrl'] ?? '')
          .toString(),

      faviconUrl:
      (map['faviconUrl'] ?? '')
          .toString(),

      contentType:
      (map['contentType'] ??
          'website')
          .toString(),

      provider:
      (map['provider'] ?? '')
          .toString(),

      creator:
      (map['creator'] ?? '')
          .toString(),

      price:
      (map['price'] ?? '')
          .toString(),

      statusText:
      (map['statusText'] ?? '')
          .toString(),

      internalType:
      (map['internalType'] ?? '')
          .toString(),

      internalId:
      (map['internalId'] ?? '')
          .toString(),

      isInternal:
      map['isInternal'] ==
          true,

      isAvailable:
      map['isAvailable'] !=
          false,

      actionLabel:
      (map['actionLabel'] ??
          'Open link')
          .toString(),

      cachedAt:
      _timestamp(
        map['cachedAt'],
      ),

      expiresAt:
      _timestamp(
        map['expiresAt'],
      ),
    );
  }

  //===================================================
  // TO MAP
  //===================================================

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'url':
      url,

      'resolvedUrl':
      resolvedUrl,

      'canonicalUrl':
      canonicalUrl,

      'title':
      title,

      'description':
      description,

      'siteName':
      siteName,

      'domain':
      domain,

      'imageUrl':
      imageUrl,

      'faviconUrl':
      faviconUrl,

      'contentType':
      contentType,

      'provider':
      provider,

      'creator':
      creator,

      'price':
      price,

      'statusText':
      statusText,

      'internalType':
      internalType,

      'internalId':
      internalId,

      'isInternal':
      isInternal,

      'isAvailable':
      isAvailable,

      'actionLabel':
      actionLabel,

      if (cachedAt != null)
        'cachedAt':
        cachedAt,

      if (expiresAt != null)
        'expiresAt':
        expiresAt,
    };
  }
}
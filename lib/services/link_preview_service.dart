import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';

import '../models/link_preview.dart';
import '../utils/link_detector.dart';

//===================================================
// UNIVERSAL LINK PREVIEW SERVICE
//===================================================

class LinkPreviewService {
  LinkPreviewService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static final Map<String, Future<LinkPreview>> _memoryCache =
  <String, Future<LinkPreview>>{};
  static final Map<String, DateTime> _cacheStartedAt =
  <String, DateTime>{};

//===================================================
// GET PREVIEW WITH EXPIRATION-AWARE CACHE
//===================================================

  Future<LinkPreview> getPreview(String rawUrl, {
    bool forceRefresh = false,
  }) {
    final String url = LinkDetector.cleanUrl(rawUrl);
    final DateTime now = DateTime.now();

    final bool storyLink =
        LinkDetector.isNubifyUrl(url) &&
            Uri
                .tryParse(url)
                ?.pathSegments
                .any((part) => part.toLowerCase() == 'story') ==
                true;

    final Duration lifetime = storyLink
        ? const Duration(seconds: 30)
        : const Duration(minutes: 3);

    final DateTime? started = _cacheStartedAt[url];

    if (forceRefresh ||
        started == null ||
        now.difference(started) >= lifetime) {
      _memoryCache.remove(url);
      _cacheStartedAt[url] = now;
    }

    return _memoryCache.putIfAbsent(
      url,
          () => _load(url, forceRefresh: forceRefresh),
    );
  }

  //===================================================
  // LOAD
  //===================================================

  Future<LinkPreview> _load(String url, {required bool forceRefresh}) async {
    if (!LinkDetector.isValidHttpUrl(url)) {
      return LinkPreview.fallback(url);
    }

    if (LinkDetector.isNubifyUrl(url)) {
      try {
        final LinkPreview? internal = await _internalPreview(url);

        if (internal != null) {
          return internal;
        }
      } catch (_) {
        return _restrictedInternal(url);
      }
    }

    if (!forceRefresh) {
      final LinkPreview? cached = await _firestoreCache(url);

      if (cached != null) {
        return cached;
      }
    }

    //===================================================
    // SECURE CLOUD FUNCTION
    //===================================================

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final HttpsCallable callable = _functions.httpsCallable(
          'getLinkPreview',
        );

        final HttpsCallableResult<dynamic> result = await callable.call(
          <String, dynamic>{'url': url, 'forceRefresh': forceRefresh},
        );

        if (result.data is Map) {
          return LinkPreview.fromMap(
            Map<String, dynamic>.from(result.data as Map),
          );
        }
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    }

    return LinkPreview.fallback(url);
  }

  //===================================================
  // FIRESTORE CACHE
  //===================================================

  Future<LinkPreview?> _firestoreCache(String url) async {
    try {
      final String id = _cacheId(url);

      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('linkPreviews')
          .doc(id)
          .get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      final LinkPreview preview = LinkPreview.fromMap(document.data()!);

      final Timestamp? expires = preview.expiresAt;

      if (expires != null && expires.toDate().isBefore(DateTime.now())) {
        return null;
      }

      return preview;
    } catch (_) {
      return null;
    }
  }

  //===================================================
  // INTERNAL NUBIFY LINK
  //===================================================

  Future<LinkPreview?> _internalPreview(String url) async {
    final Uri uri = Uri.parse(url);

    final List<String> parts = uri.pathSegments
        .where((String part) =>
    part
        .trim()
        .isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return null;
    }

    final String type = parts.first.toLowerCase();

    //===================================================
    // POST / NUBUZZ
    //===================================================

    if ((type == 'post' || type == 'nubuzz') && parts.length >= 2) {
      return _postPreview(
        url: url,

        postId: parts[1],

        forceNubuzz: type == 'nubuzz',
      );
    }

    //===================================================
    // STORY
    //===================================================

    if (type == 'story' && parts.length >= 2) {
      return _storyPreview(url, parts[1]);
    }

    //===================================================
    // PROFILE
    //===================================================

    if (type == 'profile' && parts.length >= 2) {
      return _profilePreview(url, parts[1]);
    }

    //===================================================
    // GROUP INVITE
    //===================================================

    if (type == 'group' &&
        parts.length >= 3 &&
        parts[1].toLowerCase() == 'join') {
      return _groupInvitePreview(url, parts[2]);
    }

    //===================================================
    // GROUP
    //===================================================

    if (type == 'group' && parts.length >= 2) {
      return _groupPreview(url, parts[1]);
    }

    //===================================================
    // MARKETPLACE
    //===================================================

    if ((type == 'marketplace' || type == 'product') && parts.length >= 2) {
      return _marketplacePreview(url, parts[1]);
    }

    return null;
  }

  //===================================================
  // POST / NUBUZZ PREVIEW
  //===================================================

  Future<LinkPreview> _postPreview({
    required String url,
    required String postId,
    required bool forceNubuzz,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('posts')
        .doc(postId)
        .get();

    if (!document.exists || document.data() == null) {
      return _unavailable(
        url: url,

        internalType: forceNubuzz ? 'nubuzz' : 'post',

        internalId: postId,

        title: forceNubuzz ? 'NUBuzz unavailable' : 'Post unavailable',
      );
    }

    final Map<String, dynamic> data = document.data()!;

    //===========================================
    // HIDDEN CONTENT PROTECTION
    //===========================================

    if (data['isHidden'] == true || data['isRootHidden'] == true) {
      return _unavailable(
        url: url,
        internalType: forceNubuzz ? 'nubuzz' : 'post',
        internalId: postId,
        title: 'Post unavailable',
      );
    }

    final bool isNubuzz = forceNubuzz || data['isNUBuzz'] == true;

    final String fullName = (data['fullName'] ?? '').toString().trim();

    final String username = (data['username'] ?? '').toString().trim();

    final String author = fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
        ? '@$username'
        : 'Nubify user';

    final String caption = (data['caption'] ?? '').toString().trim();
    String imageUrl = (data['thumbnailUrl'] ?? '').toString().trim();

    final dynamic media = data['media'];

    // Only search media when there is no saved thumbnail.
    if (imageUrl.isEmpty && media is List) {
      for (final dynamic raw in media) {
        if (raw is! Map) {
          continue;
        }

        final Map<String, dynamic> item = Map<String, dynamic>.from(raw);

        final String thumbnail = (item['thumbnailUrl'] ?? '').toString().trim();

        if (thumbnail.isNotEmpty) {
          imageUrl = thumbnail;

          break;
        }

        final String mediaType = (item['type'] ?? '').toString().toLowerCase();

        final String mediaUrl = (item['url'] ?? item['downloadUrl'] ?? '')
            .toString()
            .trim();

        if (mediaType != 'video' && mediaUrl.isNotEmpty) {
          imageUrl = mediaUrl;

          break;
        }
      }
    }

    return LinkPreview(
      url: url,

      resolvedUrl: url,

      canonicalUrl: url,

      title: isNubuzz ? 'NUBuzz • $author' : 'Nubify Post • $author',

      description: caption.isEmpty
          ? isNubuzz
          ? 'Watch this NUBuzz'
          : 'View this Nubify post'
          : caption,

      siteName: 'Nubify',

      domain: 'nubify.app',

      imageUrl: imageUrl,

      faviconUrl: (data['photoUrl'] ?? '').toString(),

      contentType: isNubuzz ? 'video' : 'post',

      provider: 'Nubify',

      creator: author,

      price: '',

      statusText: '',

      internalType: isNubuzz ? 'nubuzz' : 'post',

      internalId: postId,

      isInternal: true,

      isAvailable: data['isHidden'] != true,

      actionLabel: isNubuzz ? 'Watch NUBuzz' : 'View post',
    );
  }

  //===================================================
  // STORY PREVIEW
  //===================================================

  Future<LinkPreview> _storyPreview(String url, String storyId) async {
    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('stories')
        .doc(storyId)
        .get();

    if (!document.exists || document.data() == null) {
      return _unavailable(
        url: url,

        internalType: 'story',

        internalId: storyId,

        title: 'Story unavailable',
      );
    }

    final Map<String, dynamic> data = document.data()!;
    //===================================================
// VERIFY STORY EXPIRATION
//===================================================

    DateTime? expiresAt;

    final dynamic savedExpiry = data['expiresAt'];

    if (savedExpiry is Timestamp) {
      expiresAt = savedExpiry.toDate();
    } else if (savedExpiry is DateTime) {
      expiresAt = savedExpiry;
    }

    if (expiresAt == null) {
      final dynamic created = data['createdAt'];

      if (created is Timestamp) {
        expiresAt = created
            .toDate()
            .add(const Duration(hours: 24));
      }
    }

    if (expiresAt != null &&
        !expiresAt.isAfter(DateTime.now())) {
      return _unavailable(
        url: url,
        internalType: 'story',
        internalId: storyId,
        title: 'Story expired',
      );
    }

    final String fullName = (data['fullName'] ?? '').toString().trim();

    final String username = (data['username'] ?? '').toString().trim();

    final String owner = fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
        ? '@$username'
        : 'Nubify user';

    final String storyType = (data['type'] ?? '').toString().toLowerCase();

    String imageUrl = (data['thumbnailUrl'] ?? '').toString().trim();

    if (imageUrl.isEmpty && storyType != 'video' && storyType != 'voice') {
      imageUrl = (data['mediaUrl'] ?? '').toString().trim();
    }

    //===========================================
    // STORY IMAGE FALLBACK
    //===========================================

    if (imageUrl.isEmpty &&
        storyType != 'video' &&
        storyType != 'voice' &&
        data['mediaUrls'] is List) {
      final List<dynamic> urls = data['mediaUrls'] as List<dynamic>;

      for (final dynamic value in urls) {
        final String candidate = value.toString().trim();
        final String lower = candidate.toLowerCase();

        if (candidate.isEmpty ||
            lower.contains('.mp4') ||
            lower.contains('.mov') ||
            lower.contains('.webm')) {
          continue;
        }

        imageUrl = candidate;
        break;
      }
    }
    final String caption = (data['caption'] ?? data['text'] ?? '')
        .toString()
        .trim();

    return LinkPreview(
      url: url,

      resolvedUrl: url,

      canonicalUrl: url,

      title: 'Nubify Story • $owner',

      description: caption.isEmpty ? 'View this Story' : caption,

      siteName: 'Nubify',

      domain: 'nubify.app',

      imageUrl: imageUrl,

      faviconUrl: (data['photoUrl'] ?? '').toString(),

      contentType: 'story',

      provider: 'Nubify',

      creator: owner,

      price: '',

      statusText: '',

      internalType: 'story',

      internalId: storyId,

      isInternal: true,

      isAvailable: true,

      actionLabel: 'View Story',
    );
  }

  //===================================================
  // PROFILE PREVIEW
  //===================================================

  Future<LinkPreview> _profilePreview(String url, String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('users')
        .doc(uid)
        .get();

    if (!document.exists || document.data() == null) {
      return _unavailable(
        url: url,

        internalType: 'profile',

        internalId: uid,

        title: 'Profile unavailable',
      );
    }

    final Map<String, dynamic> data = document.data()!;
    //===========================================
    // STORY EXPIRATION
    //===========================================

    final dynamic expiry = data['expiresAt'];

    final bool storyAvailable = expiry is Timestamp
        ? expiry.toDate().isAfter(DateTime.now())
        : true;

    final String fullName = (data['fullName'] ?? '').toString().trim();

    final String username = (data['username'] ?? '').toString().trim();

    final String faculty = (data['faculty'] ?? '').toString().trim();

    final String bio = (data['bio'] ?? data['favoriteQuote'] ?? '')
        .toString()
        .trim();

    String description = bio;

    if (description.isEmpty) {
      description = faculty;
    }

    if (description.isEmpty) {
      description = 'Nubify profile';
    }

    return LinkPreview(
      url: url,

      resolvedUrl: url,

      canonicalUrl: url,

      title: fullName.isNotEmpty
          ? fullName
          : username.isNotEmpty
          ? username
          : 'Nubify user',

      description: username.isNotEmpty
          ? '@$username • $description'
          : description,

      siteName: 'Nubify',

      domain: 'nubify.app',

      imageUrl: (data['photoUrl'] ?? '').toString(),

      faviconUrl: '',

      contentType: 'profile',

      provider: 'Nubify',

      creator: fullName,

      price: '',

      statusText: faculty,

      internalType: 'profile',

      internalId: uid,

      isInternal: true,

      isAvailable: storyAvailable,

      actionLabel: 'View profile',
    );
  }


  //===================================================
  // SECURE GROUP INVITATION PREVIEW
  //===================================================

  Future<LinkPreview> _groupInvitePreview(String url,
      String token,) async {
    try {
      final HttpsCallable callable =
      _functions.httpsCallable(
        'getGroupInvitePreview',
      );

      final HttpsCallableResult<dynamic> result =
      await callable.call(
        <String, dynamic>{
          'token': token,
        },
      );

      if (result.data is! Map) {
        throw Exception(
          'Invalid group preview response.',
        );
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(
        result.data as Map,
      );

      final String name =
      (data['name'] ?? 'Nubify Group')
          .toString();

      final String description =
      (data['description'] ?? '')
          .toString()
          .trim();

      final String photoUrl =
      (data['photoUrl'] ?? '')
          .toString();

      final int members =
      (data['memberCount'] is num)
          ? (data['memberCount'] as num).toInt()
          : 0;

      final bool approvalRequired =
          data['adminApprovalRequired'] == true;

      return LinkPreview(
        url: url,
        resolvedUrl: url,
        canonicalUrl: url,

        title: name,

        description: description.isNotEmpty
            ? description
            : '$members members • Group invitation',

        siteName: 'Nubify',
        domain: 'nubify.app',

        imageUrl: photoUrl,
        faviconUrl: '',

        contentType: 'groupInvite',
        provider: 'Nubify',

        creator: '',
        price: '',

        statusText: approvalRequired
            ? 'Admin approval required'
            : '$members members',

        internalType: 'groupInvite',
        internalId: token,

        isInternal: true,
        isAvailable: true,

        actionLabel: approvalRequired
            ? 'Request to join'
            : 'Join group',
      );
    } catch (_) {
      return _unavailable(
        url: url,
        internalType: 'groupInvite',
        internalId: token,
        title: 'Group invitation unavailable',
      );
    }
  }

  //===================================================
  // GROUP PREVIEW
  //===================================================

  Future<LinkPreview> _groupPreview(String url, String groupId) async {
    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('chatGroups')
        .doc(groupId)
        .get();

    if (!document.exists || document.data() == null) {
      return _unavailable(
        url: url,

        internalType: 'group',

        internalId: groupId,

        title: 'Group unavailable',
      );
    }

    final Map<String, dynamic> data = document.data()!;

    final dynamic rawMembers = data['memberIds'] ?? data['members'];

    final int members = rawMembers is List ? rawMembers.length : 0;

    return LinkPreview(
      url: url,

      resolvedUrl: url,

      canonicalUrl: url,

      title: (data['name'] ?? 'Nubify Group').toString(),

      description: (data['description'] ?? '')
          .toString()
          .trim()
          .isNotEmpty
          ? (data['description'] ?? '').toString()
          : '$members members',

      siteName: 'Nubify',

      domain: 'nubify.app',

      imageUrl: (data['photoUrl'] ?? '').toString(),

      faviconUrl: '',

      contentType: 'group',

      provider: 'Nubify',

      creator: '',

      price: '',

      statusText: '$members members',

      internalType: 'group',

      internalId: groupId,

      isInternal: true,

      isAvailable: true,

      actionLabel: 'Open group',
    );
  }

  //===================================================
  // MARKETPLACE PREVIEW
  //===================================================

  Future<LinkPreview> _marketplacePreview(String url, String productId) async {
    final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
        .collection('marketplaceProducts')
        .doc(productId)
        .get();

    if (!document.exists || document.data() == null) {
      return _unavailable(
        url: url,

        internalType: 'marketplace',

        internalId: productId,

        title: 'Marketplace item unavailable',
      );
    }

    final Map<String, dynamic> data = document.data()!;

    final String title = (data['title'] ?? data['name'] ?? 'Marketplace item')
        .toString();

    final String description = (data['description'] ?? '').toString();

    String imageUrl = (data['imageUrl'] ?? '').toString();

    if (imageUrl.isEmpty &&
        data['images'] is List &&
        (data['images'] as List).isNotEmpty) {
      imageUrl = (data['images'] as List).first.toString();
    }

    final String price = data['price'] == null ? '' : data['price'].toString();

    final bool available = data['isAvailable'] != false && data['sold'] != true;

    return LinkPreview(
      url: url,

      resolvedUrl: url,

      canonicalUrl: url,

      title: title,

      description: description,

      siteName: 'Nubify Marketplace',

      domain: 'nubify.app',

      imageUrl: imageUrl,

      faviconUrl: '',

      contentType: 'marketplace',

      provider: 'Nubify',

      creator: '',

      price: price,

      statusText: available ? 'Available' : 'No longer available',

      internalType: 'marketplace',

      internalId: productId,

      isInternal: true,

      isAvailable: available,

      actionLabel: available ? 'View listing' : 'Unavailable',
    );
  }

  //===================================================
  // RESTRICTED INTERNAL CONTENT
  //===================================================

  LinkPreview _restrictedInternal(String url) {
    return LinkPreview(
      url: url,

      resolvedUrl: url,

      canonicalUrl: url,

      title: 'Nubify content',

      description:
      'This content is unavailable or you do not have permission to view it.',

      siteName: 'Nubify',

      domain: 'nubify.app',

      imageUrl: '',

      faviconUrl: '',

      contentType: 'internal',

      provider: 'Nubify',

      creator: '',

      price: '',

      statusText: 'Restricted',

      internalType: '',

      internalId: '',

      isInternal: true,

      isAvailable: false,

      actionLabel: 'Unavailable',
    );
  }

  //===================================================
  // UNAVAILABLE
  //===================================================

  LinkPreview _unavailable({
    required String url,
    required String internalType,
    required String internalId,
    required String title,
  }) {
    return LinkPreview(
      url: url,

      resolvedUrl: url,

      canonicalUrl: url,

      title: title,

      description:
      'This content may have been deleted, expired, restricted, or is no longer available.',

      siteName: 'Nubify',

      domain: 'nubify.app',

      imageUrl: '',

      faviconUrl: '',

      contentType: internalType,

      provider: 'Nubify',

      creator: '',

      price: '',

      statusText: 'Unavailable',

      internalType: internalType,

      internalId: internalId,

      isInternal: true,

      isAvailable: false,

      actionLabel: 'Unavailable',
    );
  }

  //===================================================
  // CACHE ID
  //===================================================

  String _cacheId(String url) {
    return sha256.convert(utf8.encode(url)).toString();
  }

  static void clearMemoryCache() {
    _memoryCache.clear();
    _cacheStartedAt.clear();
  }
}
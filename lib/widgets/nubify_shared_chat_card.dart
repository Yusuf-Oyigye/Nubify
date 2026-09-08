import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/link_preview.dart';
import '../services/link_preview_service.dart';
import 'universal_link_preview_card.dart';

//===========================================
// NUBIFY SHARED CHAT CARD
//===========================================

class NubifySharedChatCard extends StatefulWidget {
  const NubifySharedChatCard({super.key, required this.message, this.onTap});

  final ChatMessage message;
  final VoidCallback? onTap;

  @override
  State<NubifySharedChatCard> createState() => _NubifySharedChatCardState();
}

class _NubifySharedChatCardState extends State<NubifySharedChatCard> {
  final LinkPreviewService _service = LinkPreviewService();

  late Future<LinkPreview> _future;

  static const Color _blue = Color(0xFF29B6F6);

  //===========================================
  // CONTENT URL
  //===========================================

  String get _url {
    final ChatMessage m = widget.message;

    if (m.isPost && m.postId
        .trim()
        .isNotEmpty) {
      return 'https://nubify.app/post/${Uri.encodeComponent(m.postId)}';
    }

    if ((m.isStoryShare || m.isStoryReply) && m.storyId
        .trim()
        .isNotEmpty) {
      return 'https://nubify.app/story/${Uri.encodeComponent(m.storyId)}';
    }

    if (m.isProduct && m.productId
        .trim()
        .isNotEmpty) {
      return 'https://nubify.app/product/${Uri.encodeComponent(m.productId)}';
    }

    return '';
  }

  //===========================================
  // SAVED TITLE
  //===========================================

  String get _title {
    final ChatMessage m = widget.message;

    if (m.isPost) {
      final String author = m.postFullName
          .trim()
          .isNotEmpty
          ? m.postFullName.trim()
          : m.postUsername.trim();

      return author.isEmpty ? 'Nubify post' : 'Post by $author';
    }

    if (m.isStoryShare || m.isStoryReply) {
      return m.storyUsername
          .trim()
          .isNotEmpty
          ? 'Story by ${m.storyUsername}'
          : 'Nubify Story';
    }

    if (m.isProduct) {
      return m.productName
          .trim()
          .isNotEmpty
          ? m.productName.trim()
          : 'Marketplace listing';
    }

    return 'Nubify content';
  }

  //===========================================
  // SAVED DESCRIPTION
  //===========================================

  String get _description {
    final ChatMessage m = widget.message;

    if (m.isPost) {
      return m.postCaption
          .trim()
          .isNotEmpty
          ? m.postCaption.trim()
          : 'View this Nubify post';
    }

    if (m.isStoryReply) {
      return m.text
          .trim()
          .isNotEmpty ? m.text.trim() : 'Replied to a story';
    }

    if (m.isStoryShare) {
      return 'Tap to view this story';
    }

    if (m.isProduct) {
      return m.productPrice.trim();
    }

    return '';
  }

  //===========================================
  // IMAGE VALIDATION
  //===========================================

  bool _looksLikeVideo(String value) {
    final String lower = value.toLowerCase();

    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.webm') ||
        lower.contains('.m4v');
  }

  String get _savedImage {
    final ChatMessage m = widget.message;

    final String image = m.isPost
        ? m.postPreviewUrl
        : (m.isStoryShare || m.isStoryReply)
        ? m.storyPreviewUrl
        : m.productImageUrl;

    final String clean = image.trim();

    if (_looksLikeVideo(clean)) {
      return '';
    }

    return clean;
  }

  //===========================================
  // CONTENT TYPE
  //===========================================

  String get _contentType {
    if (widget.message.isPost) return 'post';

    if (widget.message.isStoryShare || widget.message.isStoryReply) {
      return 'story';
    }

    if (widget.message.isProduct) return 'product';

    return 'website';
  }

  //===========================================
  // SAVED PREVIEW FALLBACK
  //===========================================

  LinkPreview _savedPreview() {
    final LinkPreview fallback = LinkPreview.fallback(_url);

    return LinkPreview.fromMap({
      ...fallback.toMap(),
      'url': _url,
      'resolvedUrl': _url,
      'canonicalUrl': _url,
      'title': _title,
      'description': _description,
      'siteName': 'Nubify',
      'domain': 'nubify.app',
      'imageUrl': _savedImage,
      'contentType': _contentType,
      'provider': 'Nubify',
      'isInternal': true,
      'isAvailable': true,
      'actionLabel': 'View content',
    });
  }

  //===========================================
  // FETCH ACTUAL CONTENT PREVIEW
  //===========================================

  Future<LinkPreview> _load() async {
    if (_url.isEmpty) {
      return _savedPreview();
    }

    try {
      final LinkPreview remote = await _service.getPreview(_url);

      // The source no longer exists or cannot be accessed.
      if (!remote.isAvailable) {
        return remote;
      }

      final String remoteImage = remote.imageUrl.trim();

      final String usableImage =
      remoteImage.isNotEmpty && !_looksLikeVideo(remoteImage)
          ? remoteImage
          : _savedImage;

      final String resolvedTitle = remote.title
          .trim()
          .isNotEmpty
          ? remote.title
          : _title;

      final String resolvedDescription = remote.description
          .trim()
          .isNotEmpty
          ? remote.description
          : _description;

      return LinkPreview.fromMap({
        ...remote.toMap(),
        'imageUrl': usableImage,
        'title': resolvedTitle,
        'description': resolvedDescription,
        'canonicalUrl': _url,
        'url': _url,
      });
    } catch (_) {
      return _savedPreview();
    }
  }

  //===========================================
  // INITIALIZATION
  //===========================================

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant NubifySharedChatCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.message.messageId != widget.message.messageId ||
        oldWidget.message.postId != widget.message.postId ||
        oldWidget.message.storyId != widget.message.storyId ||
        oldWidget.message.productId != widget.message.productId ||
        oldWidget.message.postPreviewUrl != widget.message.postPreviewUrl ||
        oldWidget.message.storyPreviewUrl != widget.message.storyPreviewUrl) {
      _future = _load();
    }
  }

  //===========================================
  // BUILD
  //===========================================

  @override
  Widget build(BuildContext context) {
    if
    (
    _url
        .
    isEmpty
    ) {
      return
        Text
          (
          _title
          ,
          style
              :
          const
          TextStyle
            (
            color
                :
            Colors
                .
            white
            ,
            fontWeight
                :
            FontWeight
                .
            w600
            ,
          )
          ,
        );
    }

//===================================================
// SHOW SAVED PREVIEW WITHOUT WAITING
//===================================================

    return
      SizedBox
        (
        width
            :
        265
        ,
        child
            :
        FutureBuilder
        <
            LinkPreview
        >
          (
          future
              :
          _future
          ,
          initialData
              :
          _savedPreview
            (
          )
          ,
          builder
              :
              (context
              ,
              snapshot) {
            final
            LinkPreview
            preview
            =
                snapshot
                    .
                data
                    ??
                    _savedPreview
                      (
                    );

            return
              UniversalLinkPreviewCard
                (
                preview
                    :
                preview
                ,
                compact
                    :
                true
                ,
                onTap
                    :
                widget
                    .
                onTap
                ,
              );
          }
          ,
        )
        ,
      );
  }
}
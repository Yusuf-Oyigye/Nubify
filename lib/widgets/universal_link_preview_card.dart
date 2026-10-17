import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/link_preview.dart';
import '../services/nubify_link_router.dart';

//===================================================
// UNIVERSAL LINK PREVIEW CARD
//===================================================

class UniversalLinkPreviewCard extends StatelessWidget {
  const UniversalLinkPreviewCard({
    super.key,
    required this.preview,
    this.compact = false,
    this.interactive = true,
    this.onTap,
    this.onRemove,
  });

  final LinkPreview preview;
  final bool compact;
  final bool interactive;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  static const Color _blue = Color(0xFF29B6F6);

  //===================================================
  // ORIGINAL LINK
  //===================================================

  String get _originalUrl {
    if (preview.canonicalUrl.trim().isNotEmpty) {
      return preview.canonicalUrl.trim();
    }

    if (preview.resolvedUrl.trim().isNotEmpty) {
      return preview.resolvedUrl.trim();
    }

    return preview.url.trim();
  }

  //===================================================
  // CONTENT TYPE ICON
  //===================================================

  IconData get _contentIcon {
    final String type = preview.contentType.toLowerCase();
    final String internal = preview.internalType.toLowerCase();

    if (type == 'video' || internal == 'nubuzz') {
      return Icons.play_circle_fill_rounded;
    }

    if (type == 'story') {
      return Icons.auto_stories_rounded;
    }

    if (type == 'post') {
      return Icons.dynamic_feed_rounded;
    }

    if (type == 'group' || type == 'groupinvite') {
      return Icons.groups_rounded;
    }

    if (type == 'product' || type == 'marketplace') {
      return Icons.storefront_rounded;
    }

    if (type == 'profile') {
      return Icons.person_rounded;
    }

    if (type == 'document') {
      return Icons.description_rounded;
    }

    return Icons.language_rounded;
  }

  bool get _isVideo {
    return preview.contentType.toLowerCase() == 'video' ||
        preview.internalType.toLowerCase() == 'nubuzz';
  }

  //===================================================
  // OPEN ORIGINAL CONTENT
  //===================================================

  void _open(BuildContext context) {
    if (!interactive || !preview.isAvailable) {
      return;
    }

    if (onTap != null) {
      onTap!();
      return;
    }

    if (_originalUrl.isNotEmpty) {
      NubifyLinkRouter.open(context, _originalUrl);
    }
  }

  //===================================================
  // COPY ORIGINAL LINK
  //===================================================

  Future<void> _copyLink(BuildContext context) async {
    if (_originalUrl.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _originalUrl));

    if (!context.mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Link copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  //===================================================
  // MAIN IMAGE
  //===================================================

  Widget _hero(bool dark) {
    final String unavailableLabel =
        preview.statusText.trim().isNotEmpty &&
            preview.statusText.toLowerCase() != 'restricted'
        ? preview.statusText.trim()
        : 'Content unavailable';
    return AspectRatio(
      aspectRatio: compact ? 1.65 : 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (preview.imageUrl.trim().isNotEmpty && preview.isAvailable)
            CachedNetworkImage(
              imageUrl: preview.imageUrl.trim(),
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => _heroFallback(),
              errorWidget: (_, _, _) => _heroFallback(),
            )
          else
            _heroFallback(),

          if (_isVideo && preview.isAvailable)
            Center(
              child: Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.70),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 1),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ),

          if (!preview.isAvailable)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      unavailableLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  //===================================================
// RICH CONTENT FALLBACK
//===================================================

  Widget _heroFallback() {
    final bool expiredStory =
        preview.internalType.toLowerCase() == 'story' &&
            !preview.isAvailable &&
            preview.title.toLowerCase().contains('expired');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF173B60),
            Color(0xFF0E2035),
            Color(0xFF07131F),
          ],
        ),
      ),
      child: Center(
        child: expiredStory
            ? const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_stories_rounded,
              color: Colors.white70,
              size: 43,
            ),
            SizedBox(height: 10),
            Text(
              'Story expired',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              preview.title.trim().isNotEmpty
                  ? preview.title.trim()
                  : _sourceName,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (preview.description.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                preview.description.trim(),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  //===================================================
  // SOURCE INFORMATION
  //===================================================

  String get _sourceName {
    if (preview.siteName.trim().isNotEmpty) {
      return preview.siteName.trim();
    }

    if (preview.domain.trim().isNotEmpty) {
      return preview.domain.trim();
    }

    return 'Link';
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color background = dark
        ? const Color(0xFF19232D)
        : const Color(0xFFF3F7FA);

    final Color titleColor = dark ? Colors.white : const Color(0xFF14202C);

    final Color subtitleColor = dark ? Colors.white70 : const Color(0xFF526171);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: interactive && preview.isAvailable ? () => _open(context) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: preview.isAvailable
                  ? _blue.withValues(alpha: 0.20)
                  : Colors.redAccent.withValues(alpha: 0.30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //===================================================
              // IMAGE OR VIDEO COVER
              //===================================================

              _hero(dark),

              //===================================================
              // PREVIEW INFORMATION
              //===================================================
              Padding(
                padding: EdgeInsets.all(compact ? 11 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_contentIcon, color: _blue, size: 17),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _sourceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        if (onRemove != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Remove preview',
                            onPressed: onRemove,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: subtitleColor,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      preview.title.trim().isNotEmpty
                          ? preview.title.trim()
                          : _sourceName,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: preview.isAvailable
                            ? titleColor
                            : Colors.redAccent,
                        fontSize: compact ? 15 : 17,
                        fontWeight: FontWeight.w800,
                        height: 1.23,
                      ),
                    ),

                    if (preview.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        preview.description.trim(),
                        maxLines: compact ? 4 : 6,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: compact ? 12.5 : 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],

                    if (preview.price.trim().isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        preview.price.trim(),
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],

                    if (preview.statusText.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        preview.statusText.trim(),
                        style: TextStyle(
                          color: preview.isAvailable
                              ? subtitleColor
                              : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              //===================================================
              // CLICKABLE ORIGINAL URL
              //===================================================
              if (_originalUrl.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(11, 8, 7, 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: dark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, color: _blue, size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _originalUrl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                            decorationColor: _blue,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copyLink(context),
                        tooltip: 'Copy link',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.copy_rounded,
                          color: subtitleColor,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

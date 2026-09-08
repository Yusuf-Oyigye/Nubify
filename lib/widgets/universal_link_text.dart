import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/link_preview.dart';

import '../services/link_preview_service.dart';
import '../services/nubify_link_router.dart';

import '../utils/link_detector.dart';

import 'universal_link_preview_card.dart';

//===================================================
// UNIVERSAL LINK TEXT
//===================================================

class UniversalLinkText extends StatefulWidget {
  const UniversalLinkText({
    super.key,
    required this.text,
    this.style,
    this.showPreview = true,
    this.compactPreview = false,
    this.maxLines,
    this.overflow,
    this.leadingSpan,
    this.trailingSpan,
  });

  final String text;

  final TextStyle? style;

  final bool showPreview;
  final bool compactPreview;

  final int? maxLines;
  final TextOverflow? overflow;
  final InlineSpan? leadingSpan;
  final InlineSpan? trailingSpan;

  @override
  State<UniversalLinkText> createState() => _UniversalLinkTextState();
}

class _UniversalLinkTextState extends State<UniversalLinkText> {
  LinkPreviewService? _service;

  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  Future<LinkPreview>? _previewFuture;

  String? _url;

  static final RegExp _pattern = RegExp(
    r'((?:https?:\/\/|www\.)[^\s]+)',
    caseSensitive: false,
  );

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _prepare();
  }

  @override
  void didUpdateWidget(covariant UniversalLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text ||
        oldWidget.showPreview != widget.showPreview) {
      _prepare();
    }
  }

  //===================================================
  // PREPARE
  //===================================================

  void _prepare() {
    _url = LinkDetector.firstLink(widget.text);

    if (_url == null || !widget.showPreview) {
      _previewFuture = null;

      return;
    }

    _previewFuture = (_service ??= LinkPreviewService()).getPreview(_url!);
  }

  //===================================================
  // LINK SPANS
  //===================================================

  List<InlineSpan> _spans() {
    for (final TapGestureRecognizer item in _recognizers) {
      item.dispose();
    }

    _recognizers.clear();

    final List<InlineSpan> result = <InlineSpan>[];

    int start = 0;

    for (final RegExpMatch match in _pattern.allMatches(widget.text)) {
      if (match.start > start) {
        result.add(TextSpan(text: widget.text.substring(start, match.start)));
      }

      final String raw = match.group(0) ?? '';

      final String clean = LinkDetector.cleanUrl(raw);

      final String trailing = raw.substring(clean.length.clamp(0, raw.length));

      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () {
          NubifyLinkRouter.open(context, clean);
        };

      _recognizers.add(recognizer);

      result.add(
        TextSpan(
          text: clean,

          recognizer: recognizer,

          style: const TextStyle(
            color: Color(0xFF80D8FF),

            decoration: TextDecoration.underline,

            decorationColor: Color(0xFF80D8FF),

            fontWeight: FontWeight.w600,
          ),
        ),
      );

      if (trailing.isNotEmpty) {
        result.add(TextSpan(text: trailing));
      }

      start = match.end;
    }

    if (start < widget.text.length) {
      result.add(TextSpan(text: widget.text.substring(start)));
    }

    return result;
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    //===========================================
    // CHECK IF MESSAGE IS ONLY A LINK
    //===========================================

    final String? onlyUrl = _url;

    final bool isLinkOnly =
        widget.showPreview &&
        widget.leadingSpan == null &&
        widget.trailingSpan == null &&
        onlyUrl != null &&
        LinkDetector.cleanUrl(widget.text.trim()) == onlyUrl;
    final Widget textWidget = Text.rich(
      TextSpan(
        style: widget.style,
        children: <InlineSpan>[
          if (widget.leadingSpan != null) widget.leadingSpan!,
          ..._spans(),
          if (widget.trailingSpan != null) widget.trailingSpan!,
        ],
      ),

      maxLines: widget.maxLines,

      overflow: widget.overflow ?? TextOverflow.clip,
    );

    if (_previewFuture == null) {
      return textWidget;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!isLinkOnly) ...<Widget>[textWidget, const SizedBox(height: 8)],

        FutureBuilder<LinkPreview>(
          future: _previewFuture,

          builder: (BuildContext context, AsyncSnapshot<LinkPreview> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _PreviewSkeleton(compact: widget.compactPreview);
            }

            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            return UniversalLinkPreviewCard(
              preview: snapshot.data!,

              compact: widget.compactPreview,
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final TapGestureRecognizer item in _recognizers) {
      item.dispose();
    }

    _recognizers.clear();

    super.dispose();
  }
}

//===================================================
// LOADING PREVIEW
//===================================================

class _PreviewSkeleton extends StatefulWidget {
  const _PreviewSkeleton({required this.compact});

  final bool compact;

  @override
  State<_PreviewSkeleton> createState() => _PreviewSkeletonState();
}

class _PreviewSkeletonState extends State<_PreviewSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,

      builder: (_, __) {
        final double opacity = 0.07 + _controller.value * 0.08;

        return Container(
          width: double.infinity,

          height: widget.compact ? 88 : 145,

          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),

            borderRadius: BorderRadius.circular(17),

            border: Border.all(color: Colors.white10),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }
}

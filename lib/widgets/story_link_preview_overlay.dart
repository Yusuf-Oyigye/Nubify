import 'package:flutter/material.dart';

import '../models/link_preview.dart';
import '../services/link_preview_service.dart';
import 'universal_link_preview_card.dart';

//===================================================
// STORY LINK PREVIEW
//===================================================

class StoryLinkPreviewOverlay extends StatefulWidget {
  const StoryLinkPreviewOverlay({
    super.key,
    required this.url,
    required this.style,
    required this.x,
    required this.y,
    required this.scale,
    required this.editable,
    this.onChanged,
    this.onOpen,
  });

  final String url;

  final String style;

  final double x;
  final double y;
  final double scale;

  final bool editable;

  final void Function(double x, double y, double scale)? onChanged;

  final VoidCallback? onOpen;

  @override
  State<StoryLinkPreviewOverlay> createState() =>
      _StoryLinkPreviewOverlayState();
}

//===================================================
// STORY LINK STATE
//===================================================

class _StoryLinkPreviewOverlayState extends State<StoryLinkPreviewOverlay> {
  final LinkPreviewService _service = LinkPreviewService();

  late Future<LinkPreview> _future;

  double _scaleStart = 1.0;

  @override
  void initState() {
    super.initState();

    _future = _service.getPreview(widget.url);
  }

  @override
  void didUpdateWidget(covariant StoryLinkPreviewOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url) {
      _future = _service.getPreview(widget.url);
    }
  }

  //===================================================
  // CARD
  //===================================================

  Widget _card(LinkPreview preview) {
    if (widget.style == 'compact') {
      return Container(
        constraints: const BoxConstraints(maxWidth: 230),

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        decoration: BoxDecoration(
          color: const Color(0xE6171E24),

          borderRadius: BorderRadius.circular(25),

          border: Border.all(color: const Color(0xFF29B6F6)),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: <Widget>[
            const Icon(Icons.link_rounded, color: Color(0xFF29B6F6)),

            const SizedBox(width: 7),

            Flexible(
              child: Text(
                preview.title.trim().isNotEmpty
                    ? preview.title
                    : preview.domain,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  color: Colors.white,

                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: widget.style == 'large' ? 320 : 270,

      child: UniversalLinkPreviewCard(
        preview: preview,

        compact: widget.style != 'large',

        interactive: false,
      ),
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return FutureBuilder<LinkPreview>(
          future: _future,

          builder: (BuildContext context, AsyncSnapshot<LinkPreview> snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            return Stack(
              children: <Widget>[
                Positioned(
                  left: widget.x * constraints.maxWidth,

                  top: widget.y * constraints.maxHeight,

                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),

                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,

                      onTap: widget.editable ? null : widget.onOpen,

                      onScaleStart: !widget.editable
                          ? null
                          : (ScaleStartDetails details) {
                              _scaleStart = widget.scale;
                            },

                      onScaleUpdate:
                          !widget.editable || widget.onChanged == null
                          ? null
                          : (ScaleUpdateDetails details) {
                              final double nextX =
                                  (widget.x +
                                          details.focalPointDelta.dx /
                                              constraints.maxWidth)
                                      .clamp(0.08, 0.92)
                                      .toDouble();

                              final double nextY =
                                  (widget.y +
                                          details.focalPointDelta.dy /
                                              constraints.maxHeight)
                                      .clamp(0.10, 0.88)
                                      .toDouble();

                              final double nextScale =
                                  (_scaleStart * details.scale)
                                      .clamp(0.60, 1.50)
                                      .toDouble();

                              widget.onChanged!(nextX, nextY, nextScale);
                            },

                      child: Transform.scale(
                        scale: widget.scale,

                        child: _card(snapshot.data!),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

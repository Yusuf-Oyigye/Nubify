import 'package:flutter/material.dart';

import '../models/link_preview.dart';
import '../services/link_preview_service.dart';
import '../utils/link_detector.dart';

import 'universal_link_preview_card.dart';

//===================================================
// UNIVERSAL COMPOSER PREVIEW
//===================================================

class UniversalLinkComposerPreview
    extends StatefulWidget {
  const UniversalLinkComposerPreview({
    super.key,
    required this.controller,
    this.onSuppressedChanged,
  });

  final TextEditingController
  controller;

  final ValueChanged<bool>?
  onSuppressedChanged;

  @override
  State<UniversalLinkComposerPreview>
  createState() =>
      _UniversalLinkComposerPreviewState();
}

class _UniversalLinkComposerPreviewState
    extends State<
        UniversalLinkComposerPreview> {
  final LinkPreviewService
  _service =
  LinkPreviewService();

  List<String> _links =
  <String>[];

  int _selectedIndex =
  0;

  bool _suppressed =
  false;

  String _lastPrimary =
      '';

  Future<LinkPreview>?
  _future;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(
      _changed,
    );

    _changed();
  }

  @override
  void didUpdateWidget(
      covariant UniversalLinkComposerPreview
      oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.controller !=
        widget.controller) {
      oldWidget.controller.removeListener(
        _changed,
      );

      widget.controller.addListener(
        _changed,
      );

      _changed();
    }
  }

  //===================================================
  // TEXT CHANGED
  //===================================================

  void _changed() {
    final List<String> links =
    LinkDetector.extractLinks(
      widget.controller.text,
    );

    final String primary =
    links.isEmpty
        ? ''
        : links.first;

    if (primary !=
        _lastPrimary) {
      _suppressed =
      false;

      _selectedIndex =
      0;

      _lastPrimary =
          primary;

      widget.onSuppressedChanged
          ?.call(
        false,
      );
    }

    _links =
        links;

    if (_selectedIndex >=
        _links.length) {
      _selectedIndex =
      0;
    }

    _prepareFuture();

    if (mounted) {
      setState(() {});
    }
  }

  //===================================================
  // PREPARE
  //===================================================

  void _prepareFuture() {
    if (_suppressed ||
        _links.isEmpty) {
      _future =
      null;

      return;
    }

    _future =
        _service.getPreview(
          _links[_selectedIndex],
        );
  }

  //===================================================
  // SELECT LINK
  //===================================================

  void _select(
      int index,
      ) {
    if (index < 0 ||
        index >=
            _links.length) {
      return;
    }

    setState(() {
      _selectedIndex =
          index;

      _suppressed =
      false;

      _prepareFuture();
    });

    widget.onSuppressedChanged
        ?.call(
      false,
    );
  }

  //===================================================
  // REMOVE PREVIEW
  //===================================================

  void _remove() {
    setState(() {
      _suppressed =
      true;

      _future =
      null;
    });

    widget.onSuppressedChanged
        ?.call(
      true,
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_links.isEmpty ||
        _suppressed ||
        _future ==
            null) {
      return const SizedBox
          .shrink();
    }

    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        10,
        6,
        10,
        4,
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children:
        <Widget>[
          if (_links.length >
              1)
            SizedBox(
              height:
              34,

              child:
              ListView.separated(
                scrollDirection:
                Axis.horizontal,

                itemCount:
                _links.length,

                separatorBuilder:
                    (
                    _,
                    __,
                    ) =>
                const SizedBox(
                  width:
                  6,
                ),

                itemBuilder:
                    (
                    _,
                    int index,
                    ) {
                  final Uri? uri =
                  Uri.tryParse(
                    _links[index],
                  );

                  return ChoiceChip(
                    selected:
                    index ==
                        _selectedIndex,

                    onSelected:
                        (_) {
                      _select(
                        index,
                      );
                    },

                    label:
                    Text(
                      uri?.host
                          .replaceFirst(
                        'www.',
                        '',
                      ) ??
                          'Link ${index + 1}',

                      maxLines:
                      1,
                    ),
                  );
                },
              ),
            ),

          if (_links.length >
              1)
            const SizedBox(
              height:
              6,
            ),

          FutureBuilder<LinkPreview>(
            future:
            _future,

            builder:
                (
                BuildContext context,
                AsyncSnapshot<LinkPreview>
                snapshot,
                ) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return Container(
                  height:
                  88,

                  decoration:
                  BoxDecoration(
                    color:
                    Colors.white10,

                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                  ),

                  alignment:
                  Alignment.center,

                  child:
                  const CircularProgressIndicator(
                    strokeWidth:
                    2,

                    color:
                    Color(
                      0xFF29B6F6,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox
                    .shrink();
              }

              return UniversalLinkPreviewCard(
                preview:
                snapshot.data!,

                compact:
                true,

                interactive:
                false,

                onRemove:
                _remove,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(
      _changed,
    );

    super.dispose();
  }
}
import 'package:flutter/material.dart';

import 'universal_link_text.dart';

//===================================================
// CHAT LINK TEXT
//===================================================

class ChatLinkText
    extends StatelessWidget {
  const ChatLinkText({
    super.key,
    required this.text,
    this.style,
    this.showPreview = true,
  });

  final String text;

  final TextStyle? style;

  final bool showPreview;

  @override
  Widget build(
      BuildContext context,
      ) {
    return UniversalLinkText(
      text:
      text,

      style:
      style,

      showPreview:
      showPreview,

      compactPreview:
      true,
    );
  }
}
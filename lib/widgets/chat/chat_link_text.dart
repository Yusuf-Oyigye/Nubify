import 'package:flutter/material.dart';

import '../common/translatable_text.dart';
import '../links/universal_link_text.dart';

//===================================================
// CHAT LINK TEXT
//
// Every chat and group message. Messages in another
// language get the blue "Translate" link.
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
    return TranslatableText(
      text: text,
      builder: (String shown) => UniversalLinkText(
        text:
        shown,

        style:
        style,

        showPreview:
        showPreview,

        compactPreview:
        true,
      ),
    );
  }
}
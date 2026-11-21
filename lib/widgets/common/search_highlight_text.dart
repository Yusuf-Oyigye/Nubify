import 'package:flutter/material.dart';

//===================================================
// SEARCH HIGHLIGHT TEXT
//===================================================

class SearchHighlightText
    extends StatelessWidget {
  const SearchHighlightText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(
      BuildContext context,
      ) {
    final String cleanQuery =
    query.trim();

    if (cleanQuery.isEmpty) {
      return Text(
        text,
        maxLines:
        maxLines,
        overflow:
        TextOverflow.ellipsis,
        style:
        style,
      );
    }

    final String lowerText =
    text.toLowerCase();

    final String lowerQuery =
    cleanQuery.toLowerCase();

    final List<TextSpan> spans =
    <TextSpan>[];

    int start =
    0;

    while (true) {
      final int index =
      lowerText.indexOf(
        lowerQuery,
        start,
      );

      if (index < 0) {
        if (start <
            text.length) {
          spans.add(
            TextSpan(
              text:
              text.substring(
                start,
              ),

              style:
              style,
            ),
          );
        }

        break;
      }

      if (index >
          start) {
        spans.add(
          TextSpan(
            text:
            text.substring(
              start,
              index,
            ),

            style:
            style,
          ),
        );
      }

      spans.add(
        TextSpan(
          text:
          text.substring(
            index,
            index +
                cleanQuery.length,
          ),

          style:
          (style ??
              const TextStyle())
              .copyWith(
            color:
            const Color(
              0xFF25D366,
            ),

            backgroundColor:
            const Color(
              0x3325D366,
            ),

            fontWeight:
            FontWeight.w800,
          ),
        ),
      );

      start =
          index +
              cleanQuery.length;
    }

    return Text.rich(
      TextSpan(
        children:
        spans,
      ),

      maxLines:
      maxLines,

      overflow:
      TextOverflow.ellipsis,
    );
  }
}
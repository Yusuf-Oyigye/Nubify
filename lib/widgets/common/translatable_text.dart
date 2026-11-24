import 'package:flutter/material.dart';

import '../../l10n/nubify_text.dart';
import '../../services/common/translation_service.dart';
import '../../utils/common/language_guess.dart';

//===================================================
// TEXT PEOPLE WROTE, WITH A "TRANSLATE" LINK
//
// Wrap a comment, reply, marketplace description or
// NUBuzz caption with this. When the text looks like
// another language, a small blue "Translate" link (in
// the reader's own language) shows under it. Tapping it
// shows the translation; "Show original" switches back.
//
//   TranslatableText(
//     text: text,
//     builder: (String shown) => Text(shown),
//   )
//===================================================

class TranslatableText extends StatefulWidget {
  const TranslatableText({
    super.key,
    required this.text,
    required this.builder,
    this.linkColor = const Color(0xFF1D9BF0),
  });

  /// What the person wrote.
  final String text;

  /// Draws the text (original or translated) exactly the
  /// way the screen already did.
  final Widget Function(String text) builder;

  final Color linkColor;

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  String? _translation;
  String _translatedText = '';
  String _translatedLanguage = '';
  bool _showTranslation = false;
  bool _loading = false;

  String get _language => Localizations.localeOf(context).languageCode;

  bool get _hasTranslation =>
      _translation != null &&
          _translatedText == widget.text &&
          _translatedLanguage == _language;

  bool get _shown => _showTranslation && _hasTranslation;

  Future<void> _toggle() async {
    if (_hasTranslation) {
      setState(() => _showTranslation = !_showTranslation);
      return;
    }
    if (_loading) return;

    final String language = _language;
    final String text = widget.text;

    // Read these now: the screen may close while waiting.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String downloading = context.tr(
      'Downloading the language for translation (about 30 MB)…',
    );
    final String unknown = context.tr(
      'This language cannot be translated on your phone yet.',
    );
    final String failed = context.tr('Could not translate. Please try again.');

    setState(() => _loading = true);

    try {
      final String translation = await TranslationService.instance.translate(
        text.trim(),
        language,
        onDownload: () =>
            messenger.showSnackBar(SnackBar(content: Text(downloading))),
      );

      if (!mounted) return;

      setState(() {
        _translation = translation;
        _translatedText = text;
        _translatedLanguage = language;
        _showTranslation = true;
      });
    } on TranslationException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.problem == TranslationProblem.unknownLanguage
                ? unknown
                : failed,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Translate failed: $error');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String language = _language;
    final Widget shownText = widget.builder(
      _shown ? _translation! : widget.text,
    );

    final bool offer =
        TranslationService.canTranslateInto(language) &&
            TranslationService.canTranslateFrom(LanguageGuess.of(widget.text)) &&
            LanguageGuess.shouldOffer(widget.text, language);

    if (!offer) return shownText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        shownText,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: _loading
                ? SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.linkColor,
              ),
            )
                : Text(
              context.tr(_shown ? 'Show original' : 'Translate'),
              style: TextStyle(
                color: widget.linkColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
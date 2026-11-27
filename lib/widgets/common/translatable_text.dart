import 'package:flutter/material.dart';

import '../../l10n/nubify_text.dart';
import '../../services/common/translation_service.dart';
import '../../utils/common/language_guess.dart';

//===================================================
// TEXT PEOPLE WROTE, WITH A "TRANSLATE" BUTTON
//
// "Translate", in the reader's own language, shows on
// posts, quotes, comments, replies, chats, Marketplace
// descriptions, NUBuzz captions and profile quotes
// written in another language. Tapping it shows the
// translation; "Show original" switches back. English,
// Arabic, French and Hindi only: no button for Hausa or
// Yoruba.
//
// - Posts put a small pill in their header (next to ⋮)
//   with a [TranslationController] + [TranslateButton].
// - Everything else wraps the text and gets sky-blue
//   "Translate" under it:
//
//   TranslatableText(
//     text: text,
//     builder: (String shown) => Text(shown),
//   )
//===================================================

//===================================================
// ONE PIECE OF TEXT AND ITS TRANSLATION
//===================================================

class TranslationController extends ChangeNotifier {
  String _text = '';
  String? _translation;
  String _translatedText = '';
  String _translatedLanguage = '';
  bool _showTranslation = false;
  bool _loading = false;
  bool _disposed = false;

  /// What the person wrote.
  String get text => _text;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // The post may scroll away while translating.
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool get loading => _loading;

  /// Sets the text (from build). A different text forgets
  /// the old translation without redrawing anything.
  void update(String text) {
    if (text == _text) return;
    _text = text;
    _showTranslation = false;
  }

  /// True when [appLanguage] readers should see the button.
  /// Never for Hausa or Yoruba readers, and never on text
  /// written in Hausa or Yoruba: the phone cannot translate
  /// those.
  static bool offers(String text, String appLanguage) =>
      TranslationService.canTranslateInto(appLanguage) &&
      TranslationService.canTranslateFrom(LanguageGuess.of(text)) &&
      LanguageGuess.shouldOffer(text, appLanguage);

  bool _hasTranslation(String target) =>
      _translation != null &&
      _translatedText == _text &&
      _translatedLanguage == target;

  /// True while the translation is on screen.
  bool shownIn(String appLanguage) =>
      _showTranslation && _hasTranslation(appLanguage);

  /// The text to draw: the translation or the original.
  String shownText(String appLanguage) =>
      shownIn(appLanguage) ? _translation! : _text;

  Future<void> toggle(BuildContext context) async {
    final String target = Localizations.localeOf(context).languageCode;

    if (_hasTranslation(target)) {
      _showTranslation = !_showTranslation;
      _changed();
      return;
    }
    if (_loading) return;

    final String text = _text;

    // Read these now: the screen may close while waiting.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String downloading = context.tr(
      'Downloading the language for translation (about 30 MB)…',
    );
    final String unknown = context.tr(
      'This language cannot be translated on your phone yet.',
    );
    final String failed = context.tr('Could not translate. Please try again.');

    _loading = true;
    _changed();

    try {
      final String translation = await TranslationService.instance.translate(
        text.trim(),
        target,
        onDownload: () =>
            messenger.showSnackBar(SnackBar(content: Text(downloading))),
      );

      _translation = translation;
      _translatedText = text;
      _translatedLanguage = target;
      _showTranslation = true;
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
      _loading = false;
      _changed();
    }
  }
}

//===================================================
// THE "TRANSLATE" BUTTON, TWO LOOKS
//
// - pill: a small outlined "文A Translate", in post and
//   quoted-post headers (next to ⋮) and beside the
//   Marketplace "Description" title.
// - link: plain sky-blue "Translate" under comments,
//   replies, chat messages, NUBuzz captions and profile
//   quotes.
//
// Hidden when the text is already in the reader's
// language, and for Hausa and Yoruba (the phone cannot
// translate those).
//===================================================

enum TranslateLook { pill, link }

class TranslateButton extends StatelessWidget {
  const TranslateButton({
    super.key,
    required this.controller,
    this.look = TranslateLook.pill,
    this.compact = false,
    this.color = const Color(0xFF1D9BF0),
  });

  final TranslationController controller;

  final TranslateLook look;

  /// Smaller link text (comments, chat bubbles).
  final bool compact;

  /// Sky blue, or white on chat bubbles and NUBuzz.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;

    if (!TranslationController.offers(controller.text, language)) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final String label = context.tr(
          controller.shownIn(language) ? 'Show original' : 'Translate',
        );

        return look == TranslateLook.pill
            ? _pill(context, label)
            : _link(context, label);
      },
    );
  }

  // About 60% of the first pill's height and half its
  // size. Any smaller and the word gets hard to read.
  Widget _pill(BuildContext context, String label) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color line = dark ? const Color(0xFF8FD8FF) : color;
    final Color ink = dark ? Colors.white : color;
    final BorderRadius round = BorderRadius.circular(7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: round,
        onTap: () => controller.toggle(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: line, width: 1.1),
            borderRadius: round,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (controller.loading)
                SizedBox.square(
                  dimension: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: ink,
                  ),
                )
              else
                Icon(Icons.translate_rounded, size: 12, color: ink),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _link(BuildContext context, String label) {
    final double size = compact ? 12.5 : 13.5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => controller.toggle(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: controller.loading
            ? SizedBox.square(
                dimension: size,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

//===================================================
// TEXT WITH THE SKY-BLUE "TRANSLATE" UNDER IT
//
// With a [heading] (like Marketplace "Description"),
// the small pill sits at the end of the heading instead.
//===================================================

class TranslatableText extends StatefulWidget {
  const TranslatableText({
    super.key,
    required this.text,
    required this.builder,
    this.linkColor = const Color(0xFF1D9BF0),
    this.compact = false,
    this.heading,
    this.headingGap = 9,
  });

  /// What the person wrote.
  final String text;

  /// Draws the text (original or translated) exactly the
  /// way the screen already did.
  final Widget Function(String text) builder;

  final Color linkColor;

  /// Smaller link text (comments, chat bubbles).
  final bool compact;

  /// A title above the text; the pill goes beside it.
  final Widget? heading;

  /// Space between [heading] and the text.
  final double headingGap;

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  final TranslationController _controller = TranslationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;
    _controller.update(widget.text);
    final Widget? heading = widget.heading;

    if (heading != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: heading),
              TranslateButton(
                controller: _controller,
                color: widget.linkColor,
              ),
            ],
          ),
          SizedBox(height: widget.headingGap),
          ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext context, _) =>
                widget.builder(_controller.shownText(language)),
          ),
        ],
      );
    }

    if (!TranslationController.offers(widget.text, language)) {
      return widget.builder(widget.text);
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          widget.builder(_controller.shownText(language)),
          Padding(
            padding: EdgeInsets.only(top: widget.compact ? 2 : 4),
            child: TranslateButton(
              controller: _controller,
              look: TranslateLook.link,
              compact: widget.compact,
              color: widget.linkColor,
            ),
          ),
        ],
      ),
    );
  }
}

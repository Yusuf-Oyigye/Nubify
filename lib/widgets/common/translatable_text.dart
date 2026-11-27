import 'package:flutter/material.dart';

import '../../l10n/nubify_text.dart';
import '../../services/common/translation_service.dart';
import '../../utils/common/language_guess.dart';

//===================================================
// TEXT PEOPLE WROTE, WITH A "TRANSLATE" BUTTON
//
// The outlined "文A Translate" button, in the reader's
// own language, shows on posts, quotes, comments,
// replies, chats, Marketplace descriptions, NUBuzz
// captions and profile quotes written in another
// language. Tapping it shows the translation; "Show
// original" switches back.
//
// - Posts put the button in their header (next to ⋮)
//   with a [TranslationController] + [TranslateButton].
// - Everything else wraps the text:
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
  static bool offers(String text, String appLanguage) {
    final String target = TranslationService.targetFor(appLanguage);
    return TranslationService.canTranslateFrom(LanguageGuess.of(text)) &&
        LanguageGuess.shouldOffer(text, target);
  }

  bool _hasTranslation(String target) =>
      _translation != null &&
      _translatedText == _text &&
      _translatedLanguage == target;

  /// True while the translation is on screen.
  bool shownIn(String appLanguage) =>
      _showTranslation &&
      _hasTranslation(TranslationService.targetFor(appLanguage));

  /// The text to draw: the translation or the original.
  String shownText(String appLanguage) =>
      shownIn(appLanguage) ? _translation! : _text;

  Future<void> toggle(BuildContext context) async {
    final String target = TranslationService.targetFor(
      Localizations.localeOf(context).languageCode,
    );

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
// THE OUTLINED "文A Translate" BUTTON
//
// Hidden when the text is already in the reader's
// language. Hausa and Yoruba readers get the English
// translation (the phone cannot translate into Hausa or
// Yoruba).
//===================================================

class TranslateButton extends StatelessWidget {
  const TranslateButton({
    super.key,
    required this.controller,
    this.compact = false,
    this.color = const Color(0xFF1D9BF0),
  });

  final TranslationController controller;

  /// Smaller, for chat bubbles and quoted posts.
  final bool compact;

  /// Outline and text colour on light screens.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;

    if (!TranslationController.offers(controller.text, language)) {
      return const SizedBox.shrink();
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color line = dark ? const Color(0xFF8FD8FF) : color;
    final Color ink = dark ? Colors.white : color;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final String label = context.tr(
          controller.shownIn(language) ? 'Show original' : 'Translate',
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 8 : 10),
            onTap: () => controller.toggle(context),
            child: Container(
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
                  : const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: line, width: 1.3),
                borderRadius: BorderRadius.circular(compact ? 8 : 10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (controller.loading)
                    SizedBox.square(
                      dimension: compact ? 12 : 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ink,
                      ),
                    )
                  else
                    Icon(
                      Icons.translate_rounded,
                      size: compact ? 14 : 17,
                      color: ink,
                    ),
                  SizedBox(width: compact ? 5 : 7),
                  Text(
                    label,
                    style: TextStyle(
                      color: ink,
                      fontSize: compact ? 12 : 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

//===================================================
// TEXT WITH THE BUTTON UNDER IT
//
// With a [heading] (like Marketplace "Description"),
// the button sits at the end of the heading instead.
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

  /// Smaller button (comments, chat bubbles).
  final bool compact;

  /// A title above the text; the button goes beside it.
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
                compact: widget.compact,
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
            padding: EdgeInsets.only(top: widget.compact ? 5 : 7, bottom: 2),
            child: TranslateButton(
              controller: _controller,
              compact: widget.compact,
              color: widget.linkColor,
            ),
          ),
        ],
      ),
    );
  }
}

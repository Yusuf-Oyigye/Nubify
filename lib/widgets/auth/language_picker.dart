import 'package:flutter/material.dart';

import '../../services/common/language_preference.dart';
import 'nubify_auth_style.dart';

//===================================================
// LANGUAGE PICKER (LOGIN AND SIGNUP)
//
// compact: a small globe pill for the login screen.
// Otherwise a full-width row like a text field.
// Both say "Choose language" in English and Arabic;
// tapping opens the list with English ticked by default.
// Every name shows in English and Arabic together.
//===================================================

class NubifyLanguagePicker extends StatelessWidget {
  const NubifyLanguagePicker({
    super.key,
    required this.code,
    required this.onChanged,
    this.compact = false,
  });

  final String code;
  final ValueChanged<String> onChanged;
  final bool compact;

  Future<void> _choose(BuildContext context) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: NubifyAuthColors.night,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.translate_rounded,
                        color: NubifyAuthColors.sky,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              LanguagePreference.chooseTitle,
                              style: TextStyle(
                                color: NubifyAuthColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              LanguagePreference.chooseTitleArabic,
                              style: TextStyle(
                                color: NubifyAuthColors.muted,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                for (final NubifyLanguage option in LanguagePreference.options)
                  ListTile(
                    onTap: () => Navigator.pop(sheetContext, option.code),
                    title: Text(
                      option.nativeAndArabic,
                      style: const TextStyle(
                        color: NubifyAuthColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: option.englishUnder == null
                        ? null
                        : Text(
                            option.englishUnder!,
                            style: const TextStyle(
                              color: NubifyAuthColors.muted,
                            ),
                          ),
                    trailing: option.code == code
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: NubifyAuthColors.sky,
                          )
                        : null,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && picked != code) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final NubifyLanguage language = LanguagePreference.byCode(code);

    if (compact) {
      return Semantics(
        button: true,
        label: 'Choose language. Current: ${language.label}',
        excludeSemantics: true,
        // Solid dark so it stands out on the blue logo.
        child: Material(
          color: NubifyAuthColors.black.withValues(alpha: 0.82),
          elevation: 4,
          shadowColor: Colors.black,
          shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _choose(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.language_rounded,
                    color: NubifyAuthColors.sky,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    LanguagePreference.chooseLanguage,
                    style: TextStyle(
                      color: NubifyAuthColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: NubifyAuthColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Choose language. Current: ${language.label}',
      excludeSemantics: true,
      child: Material(
        color: NubifyAuthColors.glass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: NubifyAuthColors.glassEdge),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _choose(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: <Widget>[
                const Icon(Icons.language_rounded, color: NubifyAuthColors.sky),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        LanguagePreference.chooseLanguage,
                        style: TextStyle(
                          color: NubifyAuthColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // The current choice, small underneath.
                      Text(
                        language.nativeAndArabic,
                        style: const TextStyle(
                          color: NubifyAuthColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  color: NubifyAuthColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

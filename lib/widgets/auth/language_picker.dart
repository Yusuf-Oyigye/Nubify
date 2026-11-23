import 'package:flutter/material.dart';

import '../../services/common/language_preference.dart';
import 'nubify_auth_style.dart';

//===================================================
// LANGUAGE PICKER (LOGIN AND SIGNUP)
//
// compact: a small globe pill for the login screen.
// Otherwise a full-width row like a text field.
// Tapping either opens the language list.
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
      backgroundColor: NubifyAuthColors.night,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.translate_rounded, color: NubifyAuthColors.sky),
                    SizedBox(width: 10),
                    Text(
                      'Choose your language',
                      style: TextStyle(
                        color: NubifyAuthColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              for (final NubifyLanguage option in LanguagePreference.options)
                ListTile(
                  onTap: () => Navigator.pop(sheetContext, option.code),
                  title: Text(
                    option.label,
                    style: const TextStyle(
                      color: NubifyAuthColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: option.nativeName == option.label
                      ? null
                      : Text(
                          option.nativeName,
                          style: const TextStyle(color: NubifyAuthColors.muted),
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
        label: 'Language: ${language.label}. Change language',
        excludeSemantics: true,
        child: Material(
          color: NubifyAuthColors.glass,
          shape: const StadiumBorder(
            side: BorderSide(color: NubifyAuthColors.glassEdge),
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
                  Text(
                    language.label,
                    style: const TextStyle(
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
      label: 'Language: ${language.label}. Change language',
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
                        'Language',
                        style: TextStyle(
                          color: NubifyAuthColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        language.nativeName == language.label
                            ? language.label
                            : '${language.label} · ${language.nativeName}',
                        style: const TextStyle(
                          color: NubifyAuthColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
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

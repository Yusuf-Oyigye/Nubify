# Translating a screen

Run from the project root, for the files of one feature:

1. `node tool/l10n/wrap_tr.js lib/screens/<feature>/<file>.dart ...`
   wraps plain English UI text in `context.tr('...')` and adds the import.
2. `node tool/l10n/fix_const.js <same files>`
   removes any `const` that the wrapping made invalid (runs `dart analyze`).
3. `node tool/l10n/missing_keys.js <same files>`
   lists the phrases that still need translations.
4. Add them to `lib/l10n/translations/<feature>.dart` for ar, fr, ha, yo, hi
   (see `lib/l10n/nubify_text.dart`). Brand names (Nubify, NUBi, NUBuzz,
   WhatsApp...) stay as they are.

Text with names or numbers inside (`'Hello $name'`) is skipped by step 1;
change it to `context.tr('Hello {name}', {'name': name})` by hand.

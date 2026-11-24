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

Notes from the chat/marketplace batch:
- Where there is no `context` (a helper in a StatelessWidget, a model,
  a field initializer, or after an `await`), use `NubifyText.tr('...')`.
- After step 2, check the diff for a removed `const` on a constructor
  declaration (`const MyScreen({super.key})`) and put it back.
- Never translate text that is saved to Firestore (it would be stored in
  the sender's language); translate it where it is shown instead.
- `test/translations_test.dart` checks every phrase has all five
  languages and keeps its `{placeholders}`.

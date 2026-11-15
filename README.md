# Nubify

Nubify is a campus social app for the Nahda University (NUB) student community. It is a Flutter app for Android and iOS on a Firebase backend.

## Features

- **Home:** posts with photos, video, polls and link previews, nested comments, likes, reposts and stories.
- **NUBi:** an AI study assistant. Upload a lecture (PDF, DOCX, PPTX or TXT, up to 20 MB) to get a section-by-section tutor, MCQ quizzes, flashcards, XP and leaderboards. Includes MindRush, a live quiz room for up to five players.
- **NUBuzz:** a short-video feed.
- **EGP Arabic:** Egyptian Arabic flashcards with spaced repetition.
- **Marketplace:** campus listings priced in EGP, seller storefronts, reports and admin tools.
- **Chat:** one-to-one and group chats, voice notes, media and audio calls.

## Project layout

| Path | Contents |
| --- | --- |
| `lib/` | Flutter app: `screens/`, `widgets/`, `services/`, `models/`, `utils/` |
| `functions/` | Cloud Functions (Node 24): link previews, marketplace, NUBi and MindRush |
| `firestore.rules`, `storage.rules` | Security rules |
| `firestore.indexes.json` | Firestore composite indexes |
| `test/` | Unit and widget tests |

## Running the app

```
flutter pub get
flutter run
```

Run the checks before committing:

```
flutter analyze
flutter test
```

## Deploying the backend

The Firebase project is `nubify-af91b`. NUBi needs a Gemini API key stored as the `GEMINI_API_KEY` secret.

```
cd functions
npm install
npm run lint
cd ..
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

`firebase deploy` runs `npm run lint` first and stops on any lint error. `npx eslint . --fix` inside `functions/` fixes formatting errors, including Windows line endings in newly created files.

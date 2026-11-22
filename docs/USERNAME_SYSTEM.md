# Nubify usernames, signup and avatars

This explains the username system, the new signup flow and the faculty avatars:
what each file does, and the exact steps to switch everything on.

## How usernames work

| Where | What it holds |
| --- | --- |
| `users/{uid}.username` | The name as the person typed it, e.g. `Muhammad.Ali` |
| `users/{uid}.usernameLower` | The lowercase form, e.g. `muhammad.ali` |
| `usernames/{lowercase}` | A **lock**: `{ uid, username, createdAt }`. One lock per name. |

- The **UID is everyone's permanent identity.** Posts, comments, chats, follows and
  tags all point to the UID, so changing a username never breaks anything.
- A username is claimed by creating its lock **in the same Firestore transaction**
  as the profile change. Two people can never claim the same name, even at the
  same moment, and `Muhammad`, `MUHAMMAD` and `muhammad` count as the same name.
- **Firestore security rules** check every claim again, so a modified app cannot
  skip the rules or steal a name.

### Rules (same in the app, the security rules and the server)

- 3 to 20 characters
- only English letters `a-z A-Z`, numbers `0-9`, `_` and `.`
- must start with an English letter
- no `..`, no `__`, cannot end with `.`
- not allowed: spaces, `-`, `@`, emojis, Arabic letters, `! $ % & * + /` and other symbols

The app always shows `@` in front of usernames; nobody types it.

## Files

### New files

| File | What it does |
| --- | --- |
| `lib/utils/profile/username_rules.dart` | Every username rule and message, plus `normalize`, `at` (adds `@`) and `searchKey`. |
| `lib/services/profile/username_service.dart` | Checks if a name is free, claims it inside a transaction, and claims existing users' current names at login. |
| `lib/widgets/profile/username_field.dart` | The username box: `@` in front, live messages while typing ("Username is available." etc.). Used by signup and Edit Profile. |
| `lib/utils/common/email_check.dart` | Email must have `@` and a real-looking format, catches typos like `gmial.com`, and checks the domain can receive mail. |
| `lib/widgets/profile/nubify_avatar.dart` | Male and female avatars in faculty colours (`NubifyAvatarColors`), and saving one as a picture. |
| `functions/usernames.js` | Server side: updates every copy of a username after a change, frees names of deleted profiles, and gives older accounts a lock every night. |
| `test/username_rules_test.dart` | Tests for the username and email rules. |

### Changed files

| File | What changed |
| --- | --- |
| `lib/screens/auth/signup_screen.dart` | 5 steps: (1) email + optional phone, (2) full name + username + male/female, (3) faculty + hobbies + quote, (4) password, (5) profile picture (gallery, camera, or the faculty avatar). |
| `lib/services/auth/auth_method.dart` | Signup checks the email and username, makes the phone optional, saves gender, claims the username atomically, and uploads the photo or the avatar. Login claims older users' current username. |
| `lib/models/profile/user.dart` | New `gender` field (`male` / `female`). |
| `lib/services/profile/profile_service.dart` | Changing a username in Edit Profile is validated and swapped atomically (new lock created, old lock released). |
| `lib/screens/profile/edit_profile_screen.dart` | Uses the new username field with live feedback. |
| `lib/services/profile/account_deletion_service.dart` | Deleting an account frees the username. |
| `firestore.rules` | New `usernames` rules; a profile may only use a username whose lock it owns. |
| `functions/index.js` | Loads `usernames.js`. |
| Display and search screens | Usernames show with `@`; searching `@name` finds `name`. |

## Switch it on (deploy)

The app works before you deploy, but uniqueness is only **enforced** after the
rules are deployed. Run these from the project folder in Android Studio's terminal:

```bash
firebase deploy --only firestore:rules
```

```bash
firebase deploy --only functions:nubifyUsernameSync,functions:nubifyUsernameRelease,functions:nubifyUsernameBackfill
```

After deploying:

1. Existing users get a lock for their current username the next time they log in,
   or overnight from `nubifyUsernameBackfill` (oldest accounts keep a name first).
2. People whose old username breaks the new rules keep it until they change it in
   Edit Profile; the new rules apply to every new or changed username.

## Faculty avatar colours

Change the colours in `NubifyAvatarColors.byFacultyId` in
`lib/widgets/profile/nubify_avatar.dart`. New students who skip the photo get the
avatar saved as their profile picture, so a colour change applies to new signups.

## Test checklist

- Signup with `yusufgmail.com` shows "Your email must contain "@"."
- Signup with `name@gmial.com` suggests `gmail.com`.
- Username `1abc`, `ab`, `ab..c`, `abc.`, `ab c`, `ab😀` each show their message.
- Two phones trying the same username: only the first one gets it.
- Edit Profile: change username, then search for the old and new name.

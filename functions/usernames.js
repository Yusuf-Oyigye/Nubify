"use strict";

//===================================================
// NUBIFY USERNAMES (server side)
//
// The app claims usernames/{lowercase} locks in a
// transaction and Firestore rules enforce them. These
// functions do the work the app cannot do alone:
//
// 1. nubifyUsernameSync: after a username change, update
//    every copy of it (posts, stories, comments,
//    replies, tags). The UID never changes.
// 2. nubifyUsernameRelease: free the name when a
//    profile is deleted.
// 3. nubifyUsernameBackfill: once a day, give people who
//    joined before locks existed a lock for their name.
//===================================================

const {
  onDocumentUpdated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const REGION = "europe-west1";

const db = () => getFirestore();

// One failed write must not stop the others.
function logWriteError(error) {
  logger.warn("Username write failed", {message: error.message});
}

// Same rules as lib/utils/profile/username_rules.dart.
function isValidUsername(lower) {
  return typeof lower === "string" &&
    /^[a-z][a-z0-9._]{2,19}$/.test(lower) &&
    !lower.includes("..") &&
    !lower.includes("__") &&
    !lower.endsWith(".");
}

//===================================================
// 1. KEEP USERNAME COPIES IN SYNC
//===================================================

exports.nubifyUsernameSync = onDocumentUpdated(
  {
    document: "users/{uid}",
    region: REGION,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const uid = event.params.uid;
    const username = String(after.username || "").trim();

    if (!username || before.username === after.username) return;

    const writer = db().bulkWriter();
    let updated = 0;

    // Documents written by this user.
    const owned = [
      db().collection("posts").where("uid", "==", uid),
      db().collection("stories").where("uid", "==", uid),
      db().collectionGroup("comments").where("uid", "==", uid),
      db().collectionGroup("replies").where("uid", "==", uid),
    ];

    for (const query of owned) {
      const snapshot = await query.get();
      for (const doc of snapshot.docs) {
        if (doc.get("username") === username) continue;
        writer.update(doc.ref, {username}).catch(logWriteError);
        updated++;
      }
    }

    // Tags: posts and stories this user is tagged in.
    for (const name of ["posts", "stories"]) {
      const tagged = await db()
          .collection(name)
          .where("taggedUserIds", "array-contains", uid)
          .get();

      for (const doc of tagged.docs) {
        const tags = doc.get("taggedUsers");
        if (!Array.isArray(tags)) continue;

        let changed = false;
        const next = tags.map((tag) => {
          if (tag && tag.uid === uid && tag.username !== username) {
            changed = true;
            return {...tag, username};
          }
          return tag;
        });

        if (changed) {
          writer.update(doc.ref, {taggedUsers: next}).catch(logWriteError);
          updated++;
        }
      }
    }

    await writer.close();
    logger.info("Username synced", {uid, username, updated});
  },
);

//===================================================
// 2. FREE THE NAME WHEN A PROFILE IS DELETED
//===================================================

exports.nubifyUsernameRelease = onDocumentDeleted(
  {document: "users/{uid}", region: REGION},
  async (event) => {
    const uid = event.params.uid;
    const locks = await db()
        .collection("usernames")
        .where("uid", "==", uid)
        .get();

    await Promise.all(locks.docs.map((doc) => doc.ref.delete()));
  },
);

//===================================================
// 3. LOCKS FOR PEOPLE WHO JOINED BEFORE
//
// Oldest accounts first, so whoever had a name first
// keeps it. Clashing or invalid names are only logged;
// those people can pick a new name in Edit Profile.
//===================================================

exports.nubifyUsernameBackfill = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "Africa/Cairo",
    region: REGION,
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const users = await db().collection("users").get();
    const locks = await db().collection("usernames").get();

    const owner = new Map(locks.docs.map((doc) => [doc.id, doc.get("uid")]));

    const sorted = users.docs.sort((a, b) => {
      const at = a.get("createdAt")?.toMillis?.() ?? 0;
      const bt = b.get("createdAt")?.toMillis?.() ?? 0;
      return at - bt;
    });

    const writer = db().bulkWriter();
    let claimed = 0;
    const skipped = [];

    for (const doc of sorted) {
      const username = String(doc.get("username") || "").trim();
      const lower = username.toLowerCase();

      if (!isValidUsername(lower)) {
        if (username) skipped.push({uid: doc.id, reason: "invalid"});
        continue;
      }

      const current = owner.get(lower);
      if (current === doc.id) continue;
      if (current) {
        skipped.push({uid: doc.id, reason: "taken"});
        continue;
      }

      owner.set(lower, doc.id);
      writer.create(db().collection("usernames").doc(lower), {
        uid: doc.id,
        username,
        createdAt: FieldValue.serverTimestamp(),
      }).catch(logWriteError);
      if (doc.get("usernameLower") !== lower) {
        writer.update(doc.ref, {usernameLower: lower}).catch(logWriteError);
      }
      claimed++;
    }

    await writer.close();
    logger.info("Username backfill finished", {claimed, skipped});
  },
);

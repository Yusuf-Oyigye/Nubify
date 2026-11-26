"use strict";

//===================================================
// NUBIFY PHONE NOTIFICATIONS (server side)
//
// Sends pop-ups to a person's phones. The app saves
// each phone's push address and language in
// pushTokens/{uid} (lib/services/notifications/
// push_notifications.dart).
//
// 1. nubifyPushNotification: every new
//    notifications/{id}: likes, comments, replies,
//    reposts, quotes, tags, follows, stories, Huddles,
//    MindRush and Marketplace.
// 2. nubifyPushDirectMessage: every new chat message.
// 3. nubifyPushGroupMessage: every new group message,
//    to every member except the sender.
//
// Text is in each phone's app language. Android puts
// the Nubify logo and name on top (AndroidManifest.xml
// default icon) and the channel makes it pop up.
// Phones that no longer exist are forgotten.
//===================================================

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const {
  getFirestore,
  FieldPath,
  FieldValue,
} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {
  LANGUAGES,
  ACTIONS,
  words,
  clip,
  messageText,
} = require("./push_words");

const REGION = "europe-west1";

// Same id as the app (push_notifications.dart).
const CHANNEL_ID = "nubify_alerts";
const COLOR = "#1546C9";

const db = () => getFirestore();

//===================================================
// PEOPLE
//===================================================

async function profile(uid) {
  if (!uid || uid === "system") return null;
  const snapshot = await db().collection("users").doc(uid).get();
  if (!snapshot.exists) return null;
  const data = snapshot.data() || {};
  const username = String(data.username || "").trim();
  return {
    uid,
    name: String(data.fullName || "").trim() || username || "Nubify",
    username,
    photoUrl: String(data.photoUrl || ""),
    female: data.gender === "female",
  };
}

/** True when [uid] has blocked [otherUid]. */
async function hasBlocked(uid, otherUid) {
  if (!otherUid || otherUid === "system") return false;
  const snapshot = await db()
      .collection("users").doc(uid)
      .collection("blockedUsers").doc(otherUid)
      .get();
  return snapshot.exists;
}

//===================================================
// SEND
//
// [text](language) gives {title, body}. Sends one batch
// per language to every phone of [uids].
//===================================================

async function sendToPeople(uids, text, data) {
  const people = [...new Set(uids.filter(Boolean))];
  if (people.length === 0) return;

  // Every phone, grouped by its language.
  const byLanguage = {};
  const owner = {};

  for (let i = 0; i < people.length; i += 300) {
    const refs = people.slice(i, i + 300)
        .map((uid) => db().collection("pushTokens").doc(uid));
    const snapshots = await db().getAll(...refs);

    for (const snapshot of snapshots) {
      const tokens = (snapshot.exists && snapshot.data().tokens) || {};
      for (const [token, phone] of Object.entries(tokens)) {
        const language = LANGUAGES.includes(phone && phone.language) ?
          phone.language : "en";
        (byLanguage[language] = byLanguage[language] || []).push(token);
        owner[token] = snapshot.id;
      }
    }
  }

  const gone = [];
  let sent = 0;
  const errors = [];

  for (const [language, tokens] of Object.entries(byLanguage)) {
    const {title, body} = text(language);

    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const result = await getMessaging().sendEachForMulticast({
        tokens: batch,
        notification: {title, body},
        data,
        android: {
          priority: "high",
          notification: {
            channelId: CHANNEL_ID,
            icon: "ic_stat_nubify",
            color: COLOR,
            defaultSound: true,
          },
        },
        apns: {payload: {aps: {sound: "default"}}},
      });

      sent += result.successCount;
      result.responses.forEach((response, index) => {
        const code = response.error && response.error.code;
        if (code) errors.push(code);
        if (code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token") {
          gone.push(batch[index]);
        }
      });
    }
  }

  // One line per notification, to check delivery in the logs.
  logger.info("Push sent", {
    kind: data.kind,
    people: people.length,
    phones: Object.keys(owner).length,
    sent,
    errors,
  });

  // Forget phones that no longer exist.
  await Promise.all(gone.map((token) =>
    db().collection("pushTokens").doc(owner[token])
        .update(new FieldPath("tokens", token), FieldValue.delete())
        .catch((error) => logger.warn("Old phone not removed", {
          message: error.message,
        })),
  ));
}

//===================================================
// 1. NOTIFICATIONS (likes, comments, follows ...)
//===================================================

exports.nubifyPushNotification = onDocumentCreated(
    {
      document: "notifications/{notificationId}",
      region: REGION,
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (event) => {
      const notification = (event.data && event.data.data()) || {};
      const receiverId = String(notification.receiverId || "");
      const senderId = String(notification.senderId || "");
      const type = String(notification.type || "");

      if (!receiverId || receiverId === senderId) return;
      if (await hasBlocked(receiverId, senderId)) return;

      const sender = await profile(senderId);
      const action = ACTIONS[type];

      try {
        await sendToPeople(
            [receiverId],
            (language) => ({
              // Huddles, MindRush and Marketplace write their
              // own sentence.
              title: action ? "" : (sender ? sender.name : "Nubify"),
              body: action && sender ?
                words(action, language, sender) :
                clip(notification.message),
            }),
            {
              kind: "notification",
              notificationId: event.params.notificationId,
              type,
              senderId,
            },
        );
      } catch (error) {
        logger.error("Notification push failed", {message: error.message});
      }
    },
);

//===================================================
// 2. CHAT MESSAGES
//===================================================

exports.nubifyPushDirectMessage = onDocumentCreated(
    {
      document: "conversations/{conversationId}/messages/{messageId}",
      region: REGION,
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (event) => {
      const message = (event.data && event.data.data()) || {};
      const senderId = String(message.senderId || message.senderUid || "");
      const receiverId = String(message.receiverId || message.recipientId || "");
      const conversationId = event.params.conversationId;

      if (!senderId || !receiverId || senderId === receiverId) return;
      if (await hasBlocked(receiverId, senderId)) return;

      // Muted chat.
      const muted = await db()
          .collection("users").doc(receiverId)
          .collection("mutedConversations").doc(conversationId)
          .get();
      if (muted.exists) return;

      const sender = await profile(senderId);
      if (!sender) return;

      try {
        await sendToPeople(
            [receiverId],
            (language) => ({
              title: sender.name,
              body: messageText(message, language, sender),
            }),
            {
              kind: "chat",
              chatId: conversationId,
              senderId,
              senderName: sender.name,
              senderUsername: sender.username,
              senderPhotoUrl: sender.photoUrl,
            },
        );
      } catch (error) {
        logger.error("Chat push failed", {message: error.message});
      }
    },
);

//===================================================
// 3. GROUP MESSAGES
//===================================================

exports.nubifyPushGroupMessage = onDocumentCreated(
    {
      document: "chatGroups/{groupId}/messages/{messageId}",
      region: REGION,
      timeoutSeconds: 300,
      memory: "512MiB",
    },
    async (event) => {
      const message = (event.data && event.data.data()) || {};
      const senderId = String(message.senderId || message.senderUid || "");
      const groupId = event.params.groupId;

      if (!senderId) return;

      const group = await db().collection("chatGroups").doc(groupId).get();
      if (!group.exists) return;

      const data = group.data() || {};
      const members = (data.memberIds || data.members || [])
          .map(String)
          .filter((uid) => uid && uid !== senderId);
      if (members.length === 0) return;

      const sender = await profile(senderId);
      if (!sender) return;

      const groupName = clip(data.name, 60) || "Nubify";

      try {
        await sendToPeople(
            members,
            (language) => ({
              title: groupName,
              body: `${sender.name}: ${messageText(message, language, sender)}`,
            }),
            {
              kind: "group",
              chatId: groupId,
              groupId,
              senderId,
            },
        );
      } catch (error) {
        logger.error("Group push failed", {message: error.message});
      }
    },
);

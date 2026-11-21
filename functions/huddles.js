//===================================================
// NUB HUDDLES BACKEND
//
// Firestore keeps the Huddle's state: who is inside,
// their roles, speaker requests and chat.
// LiveKit (a media server) carries the live audio,
// video and screen sharing. Firestore never carries
// any audio or video.
//===================================================

const {onCall, onRequest, HttpsError} =
  require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {defineSecret, defineString} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {
  AccessToken,
  RoomServiceClient,
  TrackSource,
  WebhookReceiver,
} = require("livekit-server-sdk");

const REGION = "europe-west1";

// wss://your-project.livekit.cloud (set in functions/.env)
const LIVEKIT_URL = defineString("LIVEKIT_URL");
const LIVEKIT_API_KEY = defineSecret("LIVEKIT_API_KEY");
const LIVEKIT_API_SECRET = defineSecret("LIVEKIT_API_SECRET");

const OPTIONS = {
  region: REGION,
  timeoutSeconds: 30,
  memory: "256MiB",
  secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET],
};

const HOST_GRACE_MS = 3 * 60 * 1000;
const HOST_GIVE_UP_MS = 10 * 60 * 1000;
const START_NOTIFY_GAP_MS = 30 * 60 * 1000;
const MAX_START_NOTIFICATIONS = 300;

//===================================================
// SMALL HELPERS
//===================================================

const db = () => getFirestore();

function huddleRef(huddleId) {
  return db().collection("huddles").doc(huddleId);
}

function requireUid(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in again.");
  }
  return request.auth.uid;
}

function cleanText(value, max) {
  return String(value || "").replace(/\s+/g, " ").trim().slice(0, max);
}

function cleanId(value) {
  const id = String(value || "").trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) {
    throw new HttpsError("invalid-argument", "That Huddle link is not valid.");
  }
  return id;
}

function need(ok, message) {
  if (!ok) {
    throw new HttpsError("permission-denied", message);
  }
}

// LiveKit's server API uses https:// while apps connect with wss://.
function rooms() {
  const host = LIVEKIT_URL.value()
      .replace(/^wss:/, "https:")
      .replace(/^ws:/, "http:");
  return new RoomServiceClient(
      host,
      LIVEKIT_API_KEY.value(),
      LIVEKIT_API_SECRET.value(),
  );
}

async function profileOf(uid) {
  const snap = await db().collection("users").doc(uid).get();
  const data = snap.data() || {};

  return {
    name: cleanText(data.fullName || data.username || "Nubify user", 60),
    username: cleanText(data.username, 40),
    photoUrl: String(data.photoUrl || ""),
    followers: Array.isArray(data.followers) ? data.followers : [],
    following: Array.isArray(data.following) ? data.following : [],
  };
}

function participantDoc(uid, profile, role) {
  return {
    uid,
    name: profile.name,
    username: profile.username,
    photoUrl: profile.photoUrl,
    role,
    connected: false,
    handRaisedAt: null,
    speakerInviteBy: "",
    speakerInviteByName: "",
    joinedAt: FieldValue.serverTimestamp(),
    lastActiveAt: FieldValue.serverTimestamp(),
  };
}

//===================================================
// MEDIA PERMISSIONS PER ROLE
//
// Listeners can only listen, watch, chat and react.
// The media server itself blocks them from sending
// audio or video, so nobody can take the stage
// without permission.
//===================================================

function permissionFor(role, huddle) {
  const sources = [];

  if (role !== "listener") {
    sources.push(TrackSource.MICROPHONE);

    if (role === "host" || huddle.allowVideo) {
      sources.push(TrackSource.CAMERA);
    }
    if (role === "host" || huddle.allowScreenShare) {
      sources.push(TrackSource.SCREEN_SHARE, TrackSource.SCREEN_SHARE_AUDIO);
    }
  }

  return {
    canSubscribe: true,
    canPublishData: true,
    canPublish: sources.length > 0,
    canPublishSources: sources,
    canUpdateMetadata: false,
    hidden: false,
  };
}

async function tokenFor(huddleId, huddle, uid, name, role) {
  const permission = permissionFor(role, huddle);
  const token = new AccessToken(
      LIVEKIT_API_KEY.value(),
      LIVEKIT_API_SECRET.value(),
      {identity: uid, name, ttl: "6h"},
  );

  token.addGrant({
    roomJoin: true,
    room: huddleId,
    canSubscribe: true,
    canPublishData: true,
    canPublish: permission.canPublish,
    canPublishSources: permission.canPublishSources,
  });

  return token.toJwt();
}

// Changes what someone can send while they are connected.
async function applyLiveRole(huddleId, huddle, uid, role) {
  try {
    await rooms().updateParticipant(huddleId, uid, {
      permission: permissionFor(role, huddle),
    });
  } catch (error) {
    // Not connected right now; their next join token decides.
  }
}

async function muteTrack(huddleId, uid, source) {
  try {
    const info = await rooms().getParticipant(huddleId, uid);
    const tracks = (info.tracks || []).filter((t) => t.source === source);

    await Promise.all(
        tracks.map((t) => rooms().mutePublishedTrack(huddleId, uid, t.sid, true)),
    );
  } catch (error) {
    logger.info("huddles: nothing to mute", {huddleId, uid});
  }
}

//===================================================
// COUNTS SHOWN ON CARDS
//===================================================

async function refreshCounts(huddleId) {
  const ref = huddleRef(huddleId);
  const people = ref.collection("participants");

  const [all, listeners, first, snap] = await Promise.all([
    people.count().get(),
    people.where("role", "==", "listener").count().get(),
    people.orderBy("joinedAt").limit(5).get(),
    ref.get(),
  ]);

  if (!snap.exists || snap.data().status !== "live") {
    return;
  }

  const total = all.data().count;

  await ref.update({
    participantCount: total,
    speakerCount: total - listeners.data().count,
    peakParticipants: Math.max(snap.data().peakParticipants || 0, total),
    previewPhotos: first.docs
        .map((doc) => String(doc.data().photoUrl || ""))
        .filter((url) => url.startsWith("http")),
  });
}

//===================================================
// ROLE CHANGES
//===================================================

async function setRole(huddleId, huddle, uid, role) {
  const ref = huddleRef(huddleId);

  await ref.collection("participants").doc(uid).update({
    role,
    handRaisedAt: null,
    speakerInviteBy: "",
    speakerInviteByName: "",
  });

  const patch = role === "cohost" ?
    {coHostIds: FieldValue.arrayUnion(uid)} :
    {coHostIds: FieldValue.arrayRemove(uid)};

  if (role === "listener" && huddle.screenSharerId === uid) {
    patch.screenSharerId = "";
    patch.screenSharerName = "";
  }

  await ref.update(patch);
  await applyLiveRole(huddleId, huddle, uid, role);
}

async function transferHost(huddleId, huddle, newHostUid) {
  const ref = huddleRef(huddleId);
  const people = ref.collection("participants");
  const next = await people.doc(newHostUid).get();

  if (!next.exists) {
    return false;
  }

  await ref.update({
    hostId: newHostUid,
    hostName: next.data().name || "",
    hostPhotoUrl: next.data().photoUrl || "",
    hostAwaySince: null,
    coHostIds: FieldValue.arrayRemove(newHostUid),
  });
  await people.doc(newHostUid).update({role: "host"});
  await applyLiveRole(huddleId, huddle, newHostUid, "host");

  // The previous host, if still inside, becomes a co-host.
  const old = await people.doc(huddle.hostId).get();
  if (old.exists) {
    await people.doc(huddle.hostId).update({role: "cohost"});
    await ref.update({coHostIds: FieldValue.arrayUnion(huddle.hostId)});
    await applyLiveRole(huddleId, huddle, huddle.hostId, "cohost");
  }

  return true;
}

// Earliest co-host first, then the earliest speaker.
async function pickNextHost(huddleId) {
  const people = huddleRef(huddleId).collection("participants");

  for (const role of ["cohost", "speaker"]) {
    const snap = await people.where("role", "==", role).get();
    const sorted = snap.docs.sort((a, b) => {
      const ta = a.data().joinedAt ? a.data().joinedAt.toMillis() : 0;
      const tb = b.data().joinedAt ? b.data().joinedAt.toMillis() : 0;
      return ta - tb;
    });
    if (sorted.length) {
      return sorted[0].id;
    }
  }
  return null;
}

//===================================================
// ENDING
//
// Keeps a short summary (title, host, times, peak
// count). Live data like chat and participants is
// removed. Nothing is ever recorded.
//===================================================

async function deleteCollection(collection) {
  for (;;) {
    const page = await collection.limit(300).get();
    if (page.empty) {
      return;
    }
    const batch = db().batch();
    page.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function endHuddle(huddleId, reason) {
  const ref = huddleRef(huddleId);
  const snap = await ref.get();

  if (!snap.exists || snap.data().status !== "live") {
    return;
  }

  const started = snap.data().startedAt ?
    snap.data().startedAt.toMillis() :
    Date.now();

  await ref.update({
    status: "ended",
    endedAt: FieldValue.serverTimestamp(),
    endedReason: reason,
    durationSeconds: Math.max(0, Math.round((Date.now() - started) / 1000)),
    participantCount: 0,
    speakerCount: 0,
    screenSharerId: "",
    screenSharerName: "",
  });

  try {
    await rooms().deleteRoom(huddleId);
  } catch (error) {
    // Already closed.
  }

  await deleteCollection(ref.collection("participants"));
  await deleteCollection(ref.collection("chat"));
  await deleteCollection(ref.collection("invites"));
}

//===================================================
// WHO CAN JOIN
//===================================================

async function assertCanJoin(huddleId, huddle, uid, profile) {
  if (uid === huddle.hostId || (huddle.coHostIds || []).includes(uid)) {
    return;
  }

  const invited = await huddleRef(huddleId)
      .collection("invites").doc(uid).get();

  if (invited.exists || huddle.privacy === "everyone") {
    return;
  }

  if (huddle.privacy === "followers") {
    const connected = profile.following.includes(huddle.hostId) ||
      profile.followers.includes(huddle.hostId);
    need(connected, "This Huddle is only for people connected to the host.");
    return;
  }

  need(false, "This Huddle is invite only.");
}

//===================================================
// "YUSUF STARTED A HUDDLE" NOTIFICATIONS
//
// Only followers, at most 300, and at most once every
// 30 minutes per host, so nobody gets spammed.
//===================================================

async function notifyFollowersOfStart(huddleId, uid, profile, title, privacy) {
  if (privacy === "invite" || !profile.followers.length) {
    return;
  }

  const statsRef = db().collection("huddleHostStats").doc(uid);
  const stats = await statsRef.get();
  const last = stats.exists && stats.data().lastNotifiedAt ?
    stats.data().lastNotifiedAt.toMillis() :
    0;

  if (Date.now() - last < START_NOTIFY_GAP_MS) {
    return;
  }

  const receivers = profile.followers
      .filter((id) => typeof id === "string" && id && id !== uid)
      .slice(0, MAX_START_NOTIFICATIONS);

  for (let i = 0; i < receivers.length; i += 400) {
    const batch = db().batch();

    receivers.slice(i, i + 400).forEach((receiverId) => {
      const ref = db().collection("notifications").doc();
      batch.set(ref, {
        notificationId: ref.id,
        receiverId,
        senderId: uid,
        type: "huddleStarted",
        message: `${profile.name} started a Huddle: ${title}`,
        huddleId,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
  }

  await statsRef.set(
      {lastNotifiedAt: FieldValue.serverTimestamp()},
      {merge: true},
  );
}

//===================================================
// CREATE A HUDDLE
//===================================================

exports.huddleCreate = onCall(OPTIONS, async (request) => {
  const uid = requireUid(request);
  const data = request.data || {};
  const title = cleanText(data.title, 80);

  if (title.length < 3) {
    throw new HttpsError("invalid-argument", "Give your Huddle a title.");
  }

  // One live Huddle per host at a time.
  const existing = await db().collection("huddles")
      .where("hostId", "==", uid)
      .where("status", "==", "live")
      .limit(1)
      .get();

  if (!existing.empty) {
    throw new HttpsError(
        "failed-precondition",
        "You already have a live Huddle. End it before starting another.",
        {huddleId: existing.docs[0].id},
    );
  }

  const profile = await profileOf(uid);
  const ref = db().collection("huddles").doc();
  const privacy = ["everyone", "followers", "invite"].includes(data.privacy) ?
    data.privacy :
    "everyone";

  const huddle = {
    huddleId: ref.id,
    title,
    description: cleanText(data.description, 300),
    topic: cleanText(data.topic, 40),
    mode: data.mode === "video" ? "video" : "audio",
    privacy,
    hostId: uid,
    hostName: profile.name,
    hostPhotoUrl: profile.photoUrl,
    originalHostId: uid,
    coHostIds: [],
    bannedIds: [],
    status: "live",
    allowSpeakerRequests: data.allowSpeakerRequests !== false,
    allowVideo: data.allowVideo !== false,
    allowScreenShare: data.allowScreenShare !== false,
    chatEnabled: data.chatEnabled !== false,
    participantCount: 1,
    speakerCount: 1,
    peakParticipants: 1,
    previewPhotos: profile.photoUrl ? [profile.photoUrl] : [],
    screenSharerId: "",
    screenSharerName: "",
    hostAwaySince: null,
    recording: false,
    createdAt: FieldValue.serverTimestamp(),
    startedAt: FieldValue.serverTimestamp(),
    endedAt: null,
  };

  await rooms().createRoom({
    name: ref.id,
    emptyTimeout: 10 * 60,
    departureTimeout: 60,
    maxParticipants: 500,
  });

  const batch = db().batch();
  batch.set(ref, huddle);
  batch.set(
      ref.collection("participants").doc(uid),
      participantDoc(uid, profile, "host"),
  );
  await batch.commit();

  try {
    await notifyFollowersOfStart(ref.id, uid, profile, title, privacy);
  } catch (error) {
    logger.warn("huddles: start notifications failed", error);
  }

  return {
    huddleId: ref.id,
    url: LIVEKIT_URL.value(),
    token: await tokenFor(ref.id, huddle, uid, profile.name, "host"),
    role: "host",
  };
});

//===================================================
// JOIN A HUDDLE (always as a listener, unless you are
// the host or a co-host coming back)
//===================================================

exports.huddleJoin = onCall(OPTIONS, async (request) => {
  const uid = requireUid(request);
  const huddleId = cleanId(request.data && request.data.huddleId);
  const ref = huddleRef(huddleId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "This Huddle has ended.", {ended: true});
  }

  const huddle = snap.data();

  if (huddle.status !== "live") {
    throw new HttpsError(
        "failed-precondition",
        "This Huddle has ended.",
        {ended: true},
    );
  }

  need(
      !(huddle.bannedIds || []).includes(uid),
      "You were removed from this Huddle.",
  );

  const profile = await profileOf(uid);
  await assertCanJoin(huddleId, huddle, uid, profile);

  let role = "listener";
  if (uid === huddle.hostId) {
    role = "host";
  } else if ((huddle.coHostIds || []).includes(uid)) {
    role = "cohost";
  }

  const personRef = ref.collection("participants").doc(uid);
  const before = await personRef.get();
  const doc = participantDoc(uid, profile, role);

  if (before.exists && before.data().joinedAt) {
    doc.joinedAt = before.data().joinedAt;
  }

  await personRef.set(doc);

  if (role === "host") {
    await ref.update({hostAwaySince: null});
  }

  await refreshCounts(huddleId);

  return {
    huddleId,
    url: LIVEKIT_URL.value(),
    token: await tokenFor(huddleId, huddle, uid, profile.name, role),
    role,
  };
});

//===================================================
// EVERYTHING ELSE PEOPLE DO INSIDE A HUDDLE
//===================================================

exports.huddleAction = onCall(OPTIONS, async (request) => {
  const uid = requireUid(request);
  const data = request.data || {};
  const huddleId = cleanId(data.huddleId);
  const action = String(data.action || "");
  const ref = huddleRef(huddleId);
  const snap = await ref.get();

  if (!snap.exists || snap.data().status !== "live") {
    throw new HttpsError(
        "failed-precondition",
        "This Huddle has ended.",
        {ended: true},
    );
  }

  const huddle = snap.data();
  const people = ref.collection("participants");
  const meSnap = await people.doc(uid).get();
  const me = meSnap.exists ? meSnap.data() : null;
  const myRole = me ? me.role : "";
  const isHost = uid === huddle.hostId;
  const isManager = isHost || myRole === "cohost";

  if (action === "leave") {
    await people.doc(uid).delete();

    const patch = {};
    if (isHost) {
      patch.hostAwaySince = FieldValue.serverTimestamp();
    }
    if (huddle.screenSharerId === uid) {
      patch.screenSharerId = "";
      patch.screenSharerName = "";
    }
    if (Object.keys(patch).length) {
      await ref.update(patch);
    }

    await refreshCounts(huddleId);
    return {ok: true};
  }

  need(me !== null, "Join the Huddle first.");

  const targetUid = data.targetUid ? cleanId(data.targetUid) : uid;
  const targetRef = people.doc(targetUid);
  const targetSnap = targetUid === uid ? meSnap : await targetRef.get();
  const target = targetSnap.exists ? targetSnap.data() : null;

  const needTarget = () => {
    if (!target) {
      throw new HttpsError("not-found", "That person has left the Huddle.");
    }
  };

  // Co-hosts can manage speakers and listeners, but never
  // the host or other co-hosts.
  const canModerate = (role) => isHost ?
    role !== "host" :
    myRole === "cohost" && (role === "speaker" || role === "listener");

  switch (action) {
    case "raiseHand":
      need(huddle.allowSpeakerRequests, "Speaker requests are turned off.");
      need(myRole === "listener", "You can already speak.");
      await people.doc(uid).update({handRaisedAt: FieldValue.serverTimestamp()});
      break;

    case "lowerHand":
      await people.doc(uid).update({handRaisedAt: null});
      break;

    case "approveRequest":
      need(isManager, "Only the host or a co-host can do that.");
      needTarget();
      need(target.role === "listener", "They can already speak.");
      await setRole(huddleId, huddle, targetUid, "speaker");
      break;

    case "declineRequest":
      need(isManager, "Only the host or a co-host can do that.");
      needTarget();
      await targetRef.update({handRaisedAt: null});
      break;

    case "inviteToSpeak":
      need(isManager, "Only the host or a co-host can invite speakers.");
      needTarget();
      need(target.role === "listener", "They can already speak.");
      await targetRef.update({
        speakerInviteBy: uid,
        speakerInviteByName: me.name || "",
      });
      break;

    case "acceptSpeakerInvite":
      need(Boolean(me.speakerInviteBy), "This invitation has expired.");
      need(myRole === "listener", "You can already speak.");
      await setRole(huddleId, huddle, uid, "speaker");
      break;

    case "declineSpeakerInvite":
      await people.doc(uid).update({
        speakerInviteBy: "",
        speakerInviteByName: "",
      });
      break;

    case "leaveAsSpeaker":
      need(!isHost, "As the host, hand the Huddle over or end it instead.");
      need(myRole !== "listener", "You are already listening.");
      await setRole(huddleId, huddle, uid, "listener");
      break;

    case "moveToListeners":
      needTarget();
      need(target.role !== "listener" && canModerate(target.role),
          "You can't move this person.");
      await setRole(huddleId, huddle, targetUid, "listener");
      break;

    case "muteSpeaker":
      needTarget();
      need(canModerate(target.role), "You can't mute this person.");
      await muteTrack(huddleId, targetUid, TrackSource.MICROPHONE);
      break;

    case "claimScreenShare": {
      need(myRole !== "listener", "Only speakers can share their screen.");
      need(isHost || huddle.allowScreenShare,
          "The host has turned off screen sharing.");

      const current = huddle.screenSharerId || "";
      if (current && current !== uid) {
        const sharer = await people.doc(current).get();
        if (sharer.exists) {
          throw new HttpsError(
              "failed-precondition",
              `${huddle.screenSharerName || "Someone"} is already presenting.`,
          );
        }
      }
      await ref.update({screenSharerId: uid, screenSharerName: me.name || ""});
      break;
    }

    case "releaseScreenShare":
      if (huddle.screenSharerId === uid) {
        await ref.update({screenSharerId: "", screenSharerName: ""});
      }
      break;

    case "stopScreenShare":
      needTarget();
      need(canModerate(target.role), "You can't stop this presentation.");
      await muteTrack(huddleId, targetUid, TrackSource.SCREEN_SHARE);
      if (huddle.screenSharerId === targetUid) {
        await ref.update({screenSharerId: "", screenSharerName: ""});
      }
      break;

    case "makeCoHost":
      need(isHost, "Only the host can add co-hosts.");
      needTarget();
      need(target.role !== "host", "That's already the host.");
      await setRole(huddleId, huddle, targetUid, "cohost");
      break;

    case "removeCoHost":
      need(isHost, "Only the host can remove co-hosts.");
      needTarget();
      need(target.role === "cohost", "They are not a co-host.");
      await setRole(huddleId, huddle, targetUid, "speaker");
      break;

    case "makeHost":
      need(isHost, "Only the host can hand over the Huddle.");
      needTarget();
      need(target.role !== "host" && target.role !== "listener",
          "Make them a speaker or co-host first.");
      await transferHost(huddleId, huddle, targetUid);
      break;

    case "removeParticipant":
      needTarget();
      need(canModerate(target.role), "You can't remove this person.");
      if (data.block === true) {
        await ref.update({
          bannedIds: FieldValue.arrayUnion(targetUid),
          coHostIds: FieldValue.arrayRemove(targetUid),
        });
      }
      if (huddle.screenSharerId === targetUid) {
        await ref.update({screenSharerId: "", screenSharerName: ""});
      }
      await targetRef.delete();
      try {
        await rooms().removeParticipant(huddleId, targetUid);
      } catch (error) {
        // Already disconnected.
      }
      break;

    case "updateSettings": {
      need(isHost, "Only the host can change Huddle settings.");

      const patch = {};
      for (const key of [
        "chatEnabled",
        "allowSpeakerRequests",
        "allowScreenShare",
        "allowVideo",
      ]) {
        if (typeof data[key] === "boolean") {
          patch[key] = data[key];
        }
      }
      if (!Object.keys(patch).length) {
        break;
      }
      await ref.update(patch);

      // Update what current speakers are allowed to send.
      const fresh = {...huddle, ...patch};
      const speakers = await people
          .where("role", "in", ["cohost", "speaker"])
          .get();
      await Promise.all(speakers.docs.map((doc) =>
        applyLiveRole(huddleId, fresh, doc.id, doc.data().role)));
      break;
    }

    case "end":
      need(isHost, "Only the host can end this Huddle.");
      await endHuddle(huddleId, "host");
      return {ok: true};

    default:
      throw new HttpsError("invalid-argument", "Unknown Huddle action.");
  }

  await refreshCounts(huddleId);
  return {ok: true};
});

//===================================================
// LIVEKIT WEBHOOK — instant presence updates
//
// LiveKit calls this when people connect or drop.
// "participant_left" only arrives after LiveKit's own
// reconnection window, so short network blips do not
// remove anyone.
//===================================================

exports.huddleWebhook = onRequest(
    {region: REGION, secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET]},
    async (req, res) => {
      let event;
      try {
        const receiver = new WebhookReceiver(
            LIVEKIT_API_KEY.value(),
            LIVEKIT_API_SECRET.value(),
        );
        event = await receiver.receive(
            req.rawBody.toString("utf8"),
            req.get("Authorization"),
        );
      } catch (error) {
        res.status(401).send("invalid signature");
        return;
      }

      const huddleId = event.room && event.room.name;
      const uid = event.participant && event.participant.identity;

      if (!huddleId || !/^[A-Za-z0-9_-]{1,128}$/.test(huddleId)) {
        res.status(200).send("ok");
        return;
      }

      const ref = huddleRef(huddleId);

      try {
        if (event.event === "room_finished") {
          await endHuddle(huddleId, "empty");
        } else if (event.event === "participant_joined" && uid) {
          const [person, snap] = await Promise.all([
            ref.collection("participants").doc(uid).get(),
            ref.get(),
          ]);
          const huddle = snap.data();
          const allowed = person.exists && huddle &&
            huddle.status === "live" &&
            !(huddle.bannedIds || []).includes(uid);

          if (!allowed) {
            // Someone reused an old token after being removed.
            await rooms().removeParticipant(huddleId, uid).catch(() => null);
          } else {
            await person.ref.update({
              connected: true,
              lastActiveAt: FieldValue.serverTimestamp(),
            });
            if (uid === huddle.hostId) {
              await ref.update({hostAwaySince: null});
            }
          }
        } else if (
          (event.event === "participant_left" ||
            event.event === "participant_connection_aborted") && uid
        ) {
          const snap = await ref.get();
          const huddle = snap.data();
          await ref.collection("participants").doc(uid).delete();

          if (huddle && huddle.status === "live") {
            const patch = {};
            if (uid === huddle.hostId) {
              patch.hostAwaySince = FieldValue.serverTimestamp();
            }
            if (huddle.screenSharerId === uid) {
              patch.screenSharerId = "";
              patch.screenSharerName = "";
            }
            if (Object.keys(patch).length) {
              await ref.update(patch);
            }
            await refreshCounts(huddleId);
          }
        }
      } catch (error) {
        logger.warn("huddles: webhook handling failed", error);
      }

      res.status(200).send("ok");
    },
);

//===================================================
// SAFETY NET — every 2 minutes
//
// 1. Removes "ghost" participants whose phone died or
//    lost signal (in case a webhook was missed).
// 2. If the host has been gone for 3 minutes, a
//    co-host (or the longest speaker) takes over.
// 3. Ends Huddles whose host never came back and
//    nobody else could take over.
//===================================================

exports.huddleMaintenance = onSchedule(
    {
      region: REGION,
      schedule: "every 2 minutes",
      secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET],
    },
    async () => {
      const live = await db().collection("huddles")
          .where("status", "==", "live")
          .limit(100)
          .get();

      for (const doc of live.docs) {
        const huddleId = doc.id;
        let huddle = doc.data();

        try {
          let inRoom;
          try {
            const present = await rooms().listParticipants(huddleId);
            inRoom = new Set(present.map((p) => p.identity));
          } catch (error) {
            // The media room is gone, so the Huddle is over.
            await endHuddle(huddleId, "closed");
            continue;
          }

          const people = await doc.ref.collection("participants").get();
          const cutoff = Date.now() - 90 * 1000;
          let hostGone = false;

          for (const person of people.docs) {
            const joined = person.data().joinedAt ?
              person.data().joinedAt.toMillis() :
              0;
            if (!inRoom.has(person.id) && joined < cutoff) {
              await person.ref.delete();
              if (person.id === huddle.hostId) {
                hostGone = true;
              }
            }
          }

          if (hostGone && !huddle.hostAwaySince) {
            await doc.ref.update({hostAwaySince: FieldValue.serverTimestamp()});
            continue;
          }

          huddle = (await doc.ref.get()).data();
          const away = huddle.hostAwaySince ?
            Date.now() - huddle.hostAwaySince.toMillis() :
            0;

          if (away > HOST_GRACE_MS) {
            const next = await pickNextHost(huddleId);
            if (next) {
              await transferHost(huddleId, huddle, next);
            } else if (away > HOST_GIVE_UP_MS) {
              await endHuddle(huddleId, "host-left");
              continue;
            }
          }

          await refreshCounts(huddleId);
        } catch (error) {
          logger.warn("huddles: maintenance failed", {huddleId, error});
        }
      }
    },
);
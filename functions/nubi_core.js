
"use strict";

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const {GoogleGenAI} = require("@google/genai");
const {HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const now = () => admin.firestore.FieldValue.serverTimestamp();
const secret = defineSecret("GEMINI_API_KEY");

const REGION = "europe-west1";
const MODEL = process.env.NUBI_MODEL ||
  "gemini-3.5-flash-lite";

const MAX_FILE_BYTES = 20 * 1024 * 1024;
const MAX_TEXT_CHARS = 90000;
const MAX_DAILY_AI = 30;
const MAX_GLOBAL_DAILY_AI = 2000;
const MAX_DAILY_XP = 1500;

const XP = Object.freeze({
  tutorSection: 20,
  checkpoint: 30,
  mcq: 20,
  flashcard: 5,
  group: 20,
  mindrush: 100,
  steal: 50,
  streak3: 50,
  streak5: 100,
});

const callableOptions = {
  region: REGION,
  enforceAppCheck: true,
  secrets: [secret],
  memory: "1GiB",
  timeoutSeconds: 180,
  maxInstances: 4,
};

function userId(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "Please sign in to Nubify.",
    );
  }
  return uid;
}

function stringValue(value, max = 500) {
  return typeof value === "string"
    ? value.trim().slice(0, max)
    : "";
}

function hash(value) {
  return crypto
    .createHash("sha256")
    .update(value)
    .digest("hex");
}

function userRef(uid) {
  return db.doc(`users/${uid}`);
}

function sourceRef(uid, id) {
  return db.doc(
    `users/${uid}/learningSources/${id}`,
  );
}

function dayKey() {
  return new Date().toISOString().slice(0, 10);
}

function weekKey() {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  const day = (d.getUTCDay() + 6) % 7;
  d.setUTCDate(d.getUTCDate() - day);
  return d.toISOString().slice(0, 10);
}

function periods() {
  const day = dayKey();
  const month = day.slice(0, 7);
  return [
    `day_${day}`,
    `week_${weekKey()}`,
    `month_${month}`,
    "all",
  ];
}

async function reserveAiUsage(uid) {
  const userQuota = db.doc(
    `nubiQuotas/${uid}_${dayKey()}`,
  );
  const globalQuota = db.doc(
    `nubiGlobalQuotas/${dayKey()}`,
  );

  await db.runTransaction(async (tx) => {
    const [a, b] = await Promise.all([
      tx.get(userQuota),
      tx.get(globalQuota),
    ]);

    const userUsed = a.data()?.count || 0;
    const globalUsed = b.data()?.count || 0;

    if (userUsed >= MAX_DAILY_AI ||
        globalUsed >= MAX_GLOBAL_DAILY_AI) {
      throw new HttpsError(
        "resource-exhausted",
        "NUBi AI daily limit reached.",
      );
    }

    tx.set(
      userQuota,
      {count: userUsed + 1, updatedAt: now()},
      {merge: true},
    );
    tx.set(
      globalQuota,
      {count: globalUsed + 1, updatedAt: now()},
      {merge: true},
    );
  });
}

async function generateText(uid, prompt, limit = 1100) {
  await reserveAiUsage(uid);

  const ai = new GoogleGenAI({
    apiKey: secret.value(),
  });

  const result = await ai.models.generateContent({
    model: MODEL,
    contents: prompt,
    config: {
      maxOutputTokens: limit,
      temperature: 0.2,
    },
  });

  return String(result.text || "").trim();
}

async function generateJson(uid, prompt, limit = 2500) {
  await reserveAiUsage(uid);

  const ai = new GoogleGenAI({
    apiKey: secret.value(),
  });

  const result = await ai.models.generateContent({
    model: MODEL,
    contents: prompt,
    config: {
      responseMimeType: "application/json",
      maxOutputTokens: limit,
      temperature: 0.2,
    },
  });

  try {
    return JSON.parse(result.text || "{}");
  } catch (_) {
    throw new HttpsError(
      "internal",
      "NUBi could not validate the AI response.",
    );
  }
}

async function extractDocument(filename, buffer) {
  const extension =
    filename.toLowerCase().split(".").pop();

  if (!buffer.length ||
      buffer.length > MAX_FILE_BYTES) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid or oversized document.",
    );
  }

  let text = "";
  let pages = 0;

  if (extension === "txt") {
    text = buffer.toString("utf8");
  } else if (extension === "pdf") {
    if (buffer.subarray(0, 5).toString() !== "%PDF-") {
      throw new HttpsError(
        "invalid-argument",
        "Invalid PDF file.",
      );
    }

    const parsePdf = require("pdf-parse");
    const result = await parsePdf(buffer);
    pages = result.numpages || 0;
    text = result.text || "";
  } else if (extension === "docx") {
    const mammoth = require("mammoth");
    const result = await mammoth.extractRawText({
      buffer,
    });
    text = result.value || "";
  } else if (extension === "pptx") {
    const JSZip = require("jszip");
    const zip = await JSZip.loadAsync(buffer);

    const slideNames = Object.keys(zip.files)
      .filter((name) =>
        /^ppt\/slides\/slide\d+\.xml$/.test(name),
      );

    pages = slideNames.length;

    if (pages > 60) {
      throw new HttpsError(
        "invalid-argument",
        "Maximum 60 slides.",
      );
    }

    for (const name of slideNames) {
      const xml = await zip.files[name].async("string");
      const matches = [
        ...xml.matchAll(/<a:t>([\s\S]*?)<\/a:t>/g),
      ];

      text += matches.map((m) => m[1]
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"'),
      ).join(" ") + "\n";

      if (text.length > MAX_TEXT_CHARS) break;
    }
  } else {
    throw new HttpsError(
      "invalid-argument",
      "Supported: PDF, DOCX, PPTX, TXT.",
    );
  }

  if (pages > 60) {
    throw new HttpsError(
      "invalid-argument",
      "Maximum 60 pages.",
    );
  }

  text = text.replace(/\s+/g, " ").trim();

  if (text.length < 80) {
    throw new HttpsError(
      "failed-precondition",
      "Not enough extractable text. "
      + "Scanned documents need OCR support.",
    );
  }

  if (text.length > MAX_TEXT_CHARS) {
    throw new HttpsError(
      "resource-exhausted",
      "This document exceeds the current "
      + "text-processing budget.",
    );
  }

  return {text, pages};
}

// Server-authoritative XP with idempotent events.
async function grantXp(uid, eventId, kind, amount) {
  if (!Number.isInteger(amount) ||
      amount < 1 || amount > 200) {
    throw new Error("Invalid XP amount");
  }

  const eventRef = db.doc(
    `users/${uid}/xpEvents/${hash(eventId)}`,
  );
  const summaryRef = db.doc(
    `users/${uid}/xpSummary/current`,
  );
  const settingsRef = db.doc(
    `users/${uid}/nubiSettings/current`,
  );
  const memberRef = db.doc(`nubiMembership/${uid}`);

  const periodIds = periods();
  const rankRefs = periodIds.map((period) =>
    db.doc(
      `nubiRankings/${period}/players/${uid}`,
    ),
  );

  return db.runTransaction(async (tx) => {
    const refs = [
      eventRef,
      summaryRef,
      settingsRef,
      memberRef,
      userRef(uid),
      ...rankRefs,
    ];

    const docs = await Promise.all(
      refs.map((ref) => tx.get(ref)),
    );

    if (docs[0].exists) return 0;

    const old = docs[1].data() || {};
    const today = dayKey();
    const week = weekKey();
    const month = today.slice(0, 7);

    const daily = old.dayKey === today
      ? old.daily || 0 : 0;
    const weekly = old.weekKey === week
      ? old.weekly || 0 : 0;
    const monthly = old.monthKey === month
      ? old.monthly || 0 : 0;

    const allowed = Math.min(
      amount,
      MAX_DAILY_XP - daily,
    );

    if (allowed <= 0) return 0;

    tx.create(eventRef, {
      kind,
      amount: allowed,
      createdAt: now(),
    });

    tx.set(summaryRef, {
      lifetime: (old.lifetime || 0) + allowed,
      daily: daily + allowed,
      weekly: weekly + allowed,
      monthly: monthly + allowed,
      dayKey: today,
      weekKey: week,
      monthKey: month,
      updatedAt: now(),
    }, {merge: true});

    const publicOptIn =
      docs[2].data()?.leaderboardOptIn === true;
    const membership = docs[3].data() || {};
    const profile = docs[4].data() || {};

    if (publicOptIn &&
        membership.verified === true &&
        typeof membership.faculty === "string") {
      const displayName =
        stringValue(profile.fullName, 80) ||
        "NUBi Student";

      for (let i = 0; i < periodIds.length; i++) {
        const previous = docs[5 + i].data() || {};
        tx.set(rankRefs[i], {
          uid,
          displayName,
          faculty: membership.faculty,
          photoUrl: stringValue(
            profile.photoUrl, 500,
          ),
          xp: (previous.xp || 0) + allowed,
          updatedAt: now(),
        }, {merge: true});
      }
    }

    return allowed;
  });
}

module.exports = {
  admin,
  db,
  now,
  secret,
  callableOptions,
  userId,
  userRef,
  sourceRef,
  stringValue,
  hash,
  generateText,
  generateJson,
  extractDocument,
  grantXp,
  XP,
  periods,
};

const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");
const {
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {
  getAuth,
} = require("firebase-admin/auth");
const {
  getFirestore,
  Timestamp,
} = require("firebase-admin/firestore");

const db = getFirestore();
const auth = getAuth();

const REGION = "europe-west1";
const LISTINGS = "marketplaceProducts";
const ALLOWED_CATEGORIES = new Set([
  "rent_housing",
  "food_snacks",
  "electrical_gadgets",
  "textbooks_books",
  "medical_laboratory",
  "printing_photocopying",
  "clothes_fashion",
  "furniture_room",
  "watches_accessories",
  "student_services",
  "beauty_personal_care",
  "other",
]);
const ALLOWED_CONDITIONS = new Set(["new", "used", "service"]);
const ALLOWED_PRICE_TYPES = new Set([
  "fixed",
  "negotiable",
  "free",
  "contact",
]);

function requireAuthenticated(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to continue.");
  }
  return uid;
}

function isMarketplaceOwner(request) {
  return request.auth?.token?.marketplaceOwner === true;
}

function isReviewer(request) {
  const token = request.auth?.token || {};
  return token.marketplaceOwner === true ||
    token.admin === true ||
    token.moderator === true ||
    token.marketplaceReviewer === true;
}

function requireReviewer(request) {
  requireAuthenticated(request);
  if (!isReviewer(request)) {
    throw new HttpsError(
      "permission-denied",
      "Marketplace reviewer access is required.",
    );
  }
}

function requireOwner(request) {
  requireAuthenticated(request);
  if (!isMarketplaceOwner(request)) {
    throw new HttpsError(
      "permission-denied",
      "Only the Marketplace owner can manage staff.",
    );
  }
}

function cleanString(value, name, minLength, maxLength) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${name} is required.`);
  }
  const clean = value.trim();
  if (clean.length < minLength || clean.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${name} must contain ${minLength}-${maxLength} characters.`,
    );
  }
  return clean;
}

function optionalString(value, maxLength) {
  if (value == null) {
    return "";
  }
  if (typeof value !== "string" || value.trim().length > maxLength) {
    throw new HttpsError("invalid-argument", "Invalid text value.");
  }
  return value.trim();
}

function buildSearchPrefixes(parts) {
  const words = parts
    .join(" ")
    .toLowerCase()
    .replace(/[^a-z0-9\u0600-\u06ff ]/gu, " ")
    .split(/\s+/u)
    .filter((word) => word.length > 0)
    .slice(0, 30);
  const prefixes = new Set();
  for (const word of words) {
    const maximum = Math.min(word.length, 30);
    for (let size = 1; size <= maximum; size += 1) {
      prefixes.add(word.slice(0, size));
      if (prefixes.size >= 20) {
        return Array.from(prefixes);
      }
    }
  }
  return Array.from(prefixes);
}

function validateListingForPublish(data, uid) {
  if (!data || data.sellerId !== uid) {
    throw new HttpsError(
      "permission-denied",
      "Only the listing owner can publish it.",
    );
  }
  cleanString(data.title, "Title", 2, 120);
  cleanString(data.description, "Description", 3, 5000);
  if (!ALLOWED_CATEGORIES.has(data.category)) {
    throw new HttpsError("invalid-argument", "Choose a valid category.");
  }
  if (!ALLOWED_CONDITIONS.has(data.condition)) {
    throw new HttpsError("invalid-argument", "Choose a valid condition.");
  }
  if (!ALLOWED_PRICE_TYPES.has(data.priceType)) {
    throw new HttpsError("invalid-argument", "Choose a valid price type.");
  }
  if (
    (data.priceType === "fixed" || data.priceType === "negotiable") &&
    (typeof data.price !== "number" || data.price <= 0 || data.price > 1e8)
  ) {
    throw new HttpsError("invalid-argument", "Enter a valid price.");
  }
  if (!Array.isArray(data.media) || data.media.length < 1 ||
      data.media.length > 5) {
    throw new HttpsError(
      "invalid-argument",
      "A listing needs between one and five media files.",
    );
  }
  for (const item of data.media) {
    if (!item || !["image", "video"].includes(item.type) ||
        typeof item.url !== "string" || item.url.length > 2048 ||
        typeof item.storagePath !== "string" ||
        !item.storagePath.startsWith(`marketplace/${uid}/`)) {
      throw new HttpsError("invalid-argument", "Invalid listing media.");
    }
  }
}

async function addAudit({actorUid, action, targetUid, details = {}}) {
  await db.collection("marketplaceAdminAudit").add({
    actorUid,
    action,
    targetUid,
    details,
    createdAt: Timestamp.now(),
  });
}

async function addNotification(receiverId, type, message, extra = {}) {
  const reference = db.collection("notifications").doc();
  await reference.set({
    notificationId: reference.id,
    receiverId,
    senderId: "system",
    type,
    message,
    postId: null,
    repostPostId: null,
    commentId: null,
    replyId: null,
    storyId: null,
    marketplacePath: "/marketplace",
    isRead: false,
    createdAt: Timestamp.now(),
    ...extra,
  });
}

exports.getMyMarketplaceListingCounts = onCall(
  {region: REGION, timeoutSeconds: 30, memory: "256MiB"},
  async (request) => {
    requireAuthenticated(request);
    const uid = request.auth.uid;
    const statuses = [
      "available",
      "sold",
      "unavailable",
      "draft",
      "archived",
    ];
    const snapshots = await Promise.all(
      statuses.map((status) => db.collection(LISTINGS)
        .where("sellerId", "==", uid)
        .where("status", "==", status)
        .count()
        .get()),
    );
    return Object.fromEntries(
      statuses.map((status, index) => [
        status,
        snapshots[index].data().count,
      ]),
    );
  },
);

exports.publishMarketplaceListing = onCall(
  {region: REGION, timeoutSeconds: 30, memory: "256MiB"},
  async (request) => {
    const uid = requireAuthenticated(request);
    const listingId = cleanString(
      request.data?.listingId,
      "Listing ID",
      10,
      100,
    );
    const reference = db.collection(LISTINGS).doc(listingId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Listing not found.");
      }
      const data = snapshot.data();
      validateListingForPublish(data, uid);
      if (!["draft", "unavailable", "archived"].includes(data.status)) {
        throw new HttpsError(
          "failed-precondition",
          "This listing cannot be published from its current state.",
        );
      }
      const now = Timestamp.now();
      transaction.update(reference, {
        status: "available",
        publicVisible: true,
        searchPrefixes: buildSearchPrefixes([
          data.title,
          data.description,
          data.category,
          data.sellerName || "",
        ]),
        publishedAt: data.publishedAt || now,
        unavailableAt: null,
        archivedAt: null,
        updatedAt: now,
      });
    });
    return {listingId, status: "available"};
  },
);

exports.updateMarketplaceListingStatus = onCall(
  {region: REGION, timeoutSeconds: 30, memory: "256MiB"},
  async (request) => {
    const uid = requireAuthenticated(request);
    const listingId = cleanString(
      request.data?.listingId,
      "Listing ID",
      10,
      100,
    );
    const targetStatus = cleanString(
      request.data?.status,
      "Status",
      4,
      20,
    );
    if (!["available", "sold", "unavailable", "archived"].includes(
      targetStatus,
    )) {
      throw new HttpsError("invalid-argument", "Invalid listing status.");
    }
    const reference = db.collection(LISTINGS).doc(listingId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists || snapshot.data()?.sellerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Only the listing owner can change availability.",
        );
      }
      const data = snapshot.data();
      const allowedTransitions = {
        draft: new Set(["archived"]),
        available: new Set(["sold", "unavailable", "archived"]),
        sold: new Set(["archived"]),
        unavailable: new Set(["available", "archived"]),
        archived: new Set(["available"]),
      };
      if (!allowedTransitions[data.status]?.has(targetStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `Cannot change ${data.status || "unknown"} to ${targetStatus}.`,
        );
      }
      if (targetStatus === "available") {
        validateListingForPublish(data, uid);
      }
      const now = Timestamp.now();
      transaction.update(reference, {
        status: targetStatus,
        publicVisible: targetStatus === "available",
        soldAt: targetStatus === "sold" ? now : null,
        unavailableAt: targetStatus === "unavailable" ? now : null,
        archivedAt: targetStatus === "archived" ? now : null,
        updatedAt: now,
      });
    });
    return {listingId, status: targetStatus};
  },
);

exports.getMarketplaceSellerContact = onCall(
  {region: REGION, timeoutSeconds: 15, memory: "256MiB"},
  async (request) => {
    requireAuthenticated(request);
    const listingId = cleanString(
      request.data?.listingId,
      "Listing ID",
      10,
      100,
    );
    const listing = await db.collection(LISTINGS).doc(listingId).get();
    const data = listing.data();
    if (!listing.exists || data?.status !== "available" ||
        data?.publicVisible !== true ||
        data?.contactPreferences?.allowCalls !== true) {
      throw new HttpsError(
        "failed-precondition",
        "Phone contact is not available for this listing.",
      );
    }
    const contact = await db.collection("userPrivate")
      .doc(data.sellerId)
      .get();
    const phone = contact.data()?.phoneE164;
    if (contact.data()?.allowMarketplaceCalls !== true ||
        typeof phone !== "string" ||
        !/^\+201[0125]\d{8}$/u.test(phone)) {
      throw new HttpsError(
        "failed-precondition",
        "This seller has not enabled phone contact.",
      );
    }
    return {phoneE164: phone};
  },
);

exports.findMarketplaceUserByEmail = onCall(
  {region: REGION, timeoutSeconds: 15, memory: "256MiB"},
  async (request) => {
    requireOwner(request);
    const email = cleanString(request.data?.email, "Email", 5, 254)
      .toLowerCase();
    let record;
    try {
      record = await auth.getUserByEmail(email);
    } catch (_) {
      throw new HttpsError("not-found", "No Nubify account uses that email.");
    }
    const profile = await db.collection("users").doc(record.uid).get();
    const claims = record.customClaims || {};
    return {
      uid: record.uid,
      email: record.email || "",
      fullName: String(profile.data()?.fullName || "").slice(0, 100),
      username: String(profile.data()?.username || "").slice(0, 50),
      photoUrl: String(profile.data()?.photoUrl || "").slice(0, 2048),
      roles: {
        marketplaceOwner: claims.marketplaceOwner === true,
        admin: claims.admin === true,
        moderator: claims.moderator === true,
        marketplaceReviewer: claims.marketplaceReviewer === true,
      },
    };
  },
);

exports.setMarketplaceStaffRole = onCall(
  {region: REGION, timeoutSeconds: 15, memory: "256MiB"},
  async (request) => {
    requireOwner(request);
    const uid = cleanString(request.data?.uid, "User", 10, 128);
    const role = cleanString(request.data?.role, "Role", 5, 30);
    const enabled = request.data?.enabled;
    if (!["admin", "moderator", "marketplaceReviewer"].includes(role) ||
        typeof enabled !== "boolean") {
      throw new HttpsError("invalid-argument", "Invalid staff role change.");
    }
    const user = await auth.getUser(uid);
    const claims = {...(user.customClaims || {})};
    claims[role] = enabled;
    await auth.setCustomUserClaims(uid, claims);
    await addAudit({
      actorUid: request.auth.uid,
      action: enabled ? "staff_role_added" : "staff_role_removed",
      targetUid: uid,
      details: {role},
    });
    return {uid, role, enabled};
  },
);

exports.transferMarketplaceOwnership = onCall(
  {region: REGION, timeoutSeconds: 30, memory: "256MiB"},
  async (request) => {
    requireOwner(request);
    const currentOwnerUid = request.auth.uid;
    const newOwnerUid = cleanString(
      request.data?.newOwnerUid,
      "New owner",
      10,
      128,
    );
    if (newOwnerUid === currentOwnerUid) {
      throw new HttpsError(
        "invalid-argument",
        "This account is already the Marketplace owner.",
      );
    }
    const [currentOwner, newOwner] = await Promise.all([
      auth.getUser(currentOwnerUid),
      auth.getUser(newOwnerUid),
    ]);
    const newClaims = {...(newOwner.customClaims || {})};
    newClaims.marketplaceOwner = true;
    newClaims.admin = true;
    newClaims.marketplaceReviewer = true;
    await auth.setCustomUserClaims(newOwnerUid, newClaims);

    const oldClaims = {...(currentOwner.customClaims || {})};
    oldClaims.marketplaceOwner = false;
    await auth.setCustomUserClaims(currentOwnerUid, oldClaims);

    await db.collection("marketplaceSystem").doc("ownership").set({
      ownerUid: newOwnerUid,
      previousOwnerUid: currentOwnerUid,
      transferredAt: Timestamp.now(),
    });
    await addAudit({
      actorUid: currentOwnerUid,
      action: "ownership_transferred",
      targetUid: newOwnerUid,
    });
    return {ownerUid: newOwnerUid};
  },
);

exports.reviewMarketplaceReport = onCall(
  {region: REGION, timeoutSeconds: 30, memory: "256MiB"},
  async (request) => {
    requireReviewer(request);
    const reviewerUid = request.auth.uid;
    const reportId = cleanString(
      request.data?.reportId,
      "Report ID",
      3,
      260,
    );
    const decision = cleanString(
      request.data?.decision,
      "Decision",
      6,
      20,
    );
    if (!["reviewing", "resolved", "dismissed"].includes(decision)) {
      throw new HttpsError("invalid-argument", "Invalid report decision.");
    }
    const resolutionNote = optionalString(
      request.data?.resolutionNote,
      1000,
    );
    if (["resolved", "dismissed"].includes(decision) &&
        resolutionNote.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "A clear resolution note is required.",
      );
    }

    const reference = db.collection("marketplaceReports").doc(reportId);
    let reportData;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Marketplace report not found.");
      }
      reportData = snapshot.data();
      const current = reportData.status;
      const allowed = (current === "submitted" &&
          ["reviewing", "resolved", "dismissed"].includes(decision)) ||
        (current === "reviewing" &&
          ["resolved", "dismissed"].includes(decision));
      if (!allowed) {
        throw new HttpsError(
          "failed-precondition",
          `Cannot change ${current || "unknown"} to ${decision}.`,
        );
      }
      const now = Timestamp.now();
      transaction.update(reference, {
        status: decision,
        updatedAt: now,
        reviewedAt: now,
        reviewedBy: reviewerUid,
        resolutionNote,
      });
    });

    await addAudit({
      actorUid: reviewerUid,
      action: `report_${decision}`,
      targetUid: reportData.sellerId,
      details: {reason: resolutionNote},
    });
    if (["resolved", "dismissed"].includes(decision)) {
      await addNotification(
        reportData.reporterId,
        `marketplaceReport${decision[0].toUpperCase()}${decision.slice(1)}`,
        decision === "resolved" ?
          "Your Marketplace report was reviewed and resolved." :
          "Your Marketplace report was reviewed and dismissed.",
        {
          marketplacePath: "/marketplace/listing",
          marketplaceListingId: reportData.listingId,
        },
      );
    }
    return {status: decision};
  },
);

async function updateSellerStats(sellerId) {
  if (!sellerId) {
    return;
  }
  const [countSnapshot, profile] = await Promise.all([
    db.collection(LISTINGS)
      .where("sellerId", "==", sellerId)
      .where("status", "==", "available")
      .where("publicVisible", "==", true)
      .count()
      .get(),
    db.collection("users").doc(sellerId).get(),
  ]);
  await db.collection("marketplaceSellerStats").doc(sellerId).set({
    sellerId,
    sellerName: String(profile.data()?.fullName || "").slice(0, 100),
    sellerPhotoUrl: String(profile.data()?.photoUrl || "").slice(0, 2048),
    availableListingCount: countSnapshot.data().count,
    active: countSnapshot.data().count > 0,
    updatedAt: Timestamp.now(),
  });
}

async function updateCategoryStats(category) {
  if (!category || !ALLOWED_CATEGORIES.has(category)) {
    return;
  }
  const countSnapshot = await db.collection(LISTINGS)
    .where("category", "==", category)
    .where("status", "==", "available")
    .where("publicVisible", "==", true)
    .count()
    .get();
  await db.collection("marketplaceCategoryStats").doc(category).set({
    category,
    availableListingCount: countSnapshot.data().count,
    updatedAt: Timestamp.now(),
  });
}

exports.syncMarketplaceDiscoveryStats = onDocumentWritten(
  {
    document: `${LISTINGS}/{listingId}`,
    region: REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const sellerIds = new Set([before.sellerId, after.sellerId].filter(Boolean));
    const categories = new Set([before.category, after.category].filter(Boolean));
    await Promise.all([
      ...Array.from(sellerIds).map(updateSellerStats),
      ...Array.from(categories).map(updateCategoryStats),
    ]);
  },
);


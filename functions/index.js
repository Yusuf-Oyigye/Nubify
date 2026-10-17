const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  initializeApp,
} = require("firebase-admin/app");

const {
  getFirestore,
  Timestamp,
  FieldValue,
} = require("firebase-admin/firestore");
const crypto = require("crypto");
const dns = require("dns").promises;
const ipaddr = require("ipaddr.js");
const cheerio = require("cheerio");

initializeApp();

const db = getFirestore();

const REGION = "europe-west1";

const MAX_URL_LENGTH = 2048;
const MAX_REDIRECTS = 5;
const MAX_BODY_BYTES = 1024 * 1024;
const FETCH_TIMEOUT_MS = 7000;

const CACHE_HOURS = 24;
const FAILURE_CACHE_HOURS = 1;

//===================================================
// NORMALIZE URL
//===================================================

function normalizeUrl(raw) {
  if (typeof raw !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "A URL is required.",
    );
  }

  const clean = raw.trim();

  if (
    clean.length === 0 ||
    clean.length > MAX_URL_LENGTH
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid URL.",
    );
  }

  let url;

  try {
    url = new URL(clean);
  } catch (_) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid URL.",
    );
  }

  if (
    url.protocol !== "http:" &&
    url.protocol !== "https:"
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Only HTTP and HTTPS links are supported.",
    );
  }

  url.hash = "";

  return url.toString();
}

//===================================================
// CACHE ID
//===================================================

function cacheId(url) {
  return crypto
    .createHash("sha256")
    .update(url)
    .digest("hex");
}

//===================================================
// PRIVATE NETWORK PROTECTION
//===================================================

function isPublicIp(address) {
  try {
    let parsed = ipaddr.parse(address);

    if (
      parsed.kind() === "ipv6" &&
      parsed.isIPv4MappedAddress()
    ) {
      parsed =
        parsed.toIPv4Address();
    }

    return parsed.range() === "unicast";
  } catch (_) {
    return false;
  }
}

//===================================================
// VALIDATE HOST
//===================================================

async function validatePublicUrl(rawUrl) {
  const url = new URL(rawUrl);

  const host =
    url.hostname.toLowerCase();

  if (
    host === "localhost" ||
    host.endsWith(".localhost") ||
    host.endsWith(".local")
  ) {
    throw new Error(
      "Local addresses are not allowed.",
    );
  }

  const addresses =
    await dns.lookup(
      host,
      {
        all: true,
        verbatim: true,
      },
    );

  if (!addresses.length) {
    throw new Error(
      "Unable to resolve host.",
    );
  }

  for (const record of addresses) {
    if (!isPublicIp(record.address)) {
      throw new Error(
        "Private network addresses are not allowed.",
      );
    }
  }
}

//===================================================
// READ LIMITED RESPONSE BODY
//===================================================

async function readLimitedBody(response) {
  if (!response.body) {
    return Buffer.alloc(0);
  }

  const chunks = [];
  let total = 0;

  for await (
    const chunk
    of response.body
  ) {
    const buffer =
      Buffer.from(chunk);

    total +=
      buffer.length;

    if (total > MAX_BODY_BYTES) {
      throw new Error(
        "Response is too large.",
      );
    }

    chunks.push(
      buffer,
    );
  }

  return Buffer.concat(
    chunks,
  );
}

//===================================================
// FETCH WITH REDIRECT VALIDATION
//===================================================

async function safeFetch(
  initialUrl,
) {
  let current =
    initialUrl;

  for (
    let redirect = 0;
    redirect <= MAX_REDIRECTS;
    redirect++
  ) {
    await validatePublicUrl(
      current,
    );

    const controller =
      new AbortController();

    const timeout =
      setTimeout(
        () =>
          controller.abort(),
        FETCH_TIMEOUT_MS,
      );

    let response;

    try {
      response =
        await fetch(
          current,
          {
            redirect: "manual",

            signal:
              controller.signal,

            headers: {
              "User-Agent":
                "Mozilla/5.0 (compatible; NubifyLinkPreview/1.0)",

              "Accept":
                "text/html,application/xhtml+xml,application/pdf,image/*;q=0.9,*/*;q=0.8",

              "Accept-Language":
                "en-US,en;q=0.8",
            },
          },
        );
    } finally {
      clearTimeout(
        timeout,
      );
    }

    if (
      response.status >= 300 &&
      response.status < 400
    ) {
      const location =
        response.headers.get(
          "location",
        );

      if (!location) {
        throw new Error(
          "Invalid redirect.",
        );
      }

      current =
        new URL(
          location,
          current,
        ).toString();

      continue;
    }

    if (!response.ok) {
      throw new Error(
        `HTTP ${response.status}`,
      );
    }

    const contentLength =
      Number(
        response.headers.get(
          "content-length",
        ) ||
        0,
      );

    if (
      contentLength >
      MAX_BODY_BYTES
    ) {
      throw new Error(
        "Response is too large.",
      );
    }

    const body =
      await readLimitedBody(
        response,
      );

    return {
      response,
      body,
      finalUrl:
        current,
    };
  }

  throw new Error(
    "Too many redirects.",
  );
}

//===================================================
// CLEAN TEXT
//===================================================

function cleanText(value) {
  return String(
    value || "",
  )
    .replace(
      /\s+/g,
      " ",
    )
    .trim()
    .slice(
      0,
      1000,
    );
}

//===================================================
// ABSOLUTE URL
//===================================================

function absoluteUrl(
  value,
  base,
) {
  if (!value) {
    return "";
  }

  try {
    return new URL(
      value,
      base,
    ).toString();
  } catch (_) {
    return "";
  }
}

//===================================================
// PROVIDER
//===================================================

function providerName(hostname) {
  const host =
    hostname
      .toLowerCase()
      .replace(
        /^www\./,
        "",
      );

  if (
    host.includes("youtube.com") ||
    host === "youtu.be"
  ) {
    return "YouTube";
  }

  if (host.includes("instagram.com")) {
    return "Instagram";
  }

  if (host.includes("tiktok.com")) {
    return "TikTok";
  }

  if (
    host === "x.com" ||
    host.includes("twitter.com")
  ) {
    return "X";
  }

  if (host.includes("whatsapp.com")) {
    return "WhatsApp";
  }

  if (host.includes("facebook.com")) {
    return "Facebook";
  }

  return host;
}

//===================================================
// YOUTUBE OEMBED
//===================================================

function isYoutube(url) {
  const host =
    new URL(url)
      .hostname
      .toLowerCase();

  return (
    host.includes("youtube.com") ||
    host === "youtu.be"
  );
}

async function youtubePreview(url) {
  const endpoint =
    "https://www.youtube.com/oembed" +
    `?url=${encodeURIComponent(url)}` +
    "&format=json";

  const controller =
    new AbortController();

  const timeout =
    setTimeout(
      () =>
        controller.abort(),
      FETCH_TIMEOUT_MS,
    );

  try {
    const response =
      await fetch(
        endpoint,
        {
          signal:
            controller.signal,
        },
      );

    if (!response.ok) {
      return null;
    }

    const data =
      await response.json();

    return {
      title:
        cleanText(
          data.title,
        ),

      description:
        data.author_name
          ? `Video by ${cleanText(data.author_name)}`
          : "",

      imageUrl:
        String(
          data.thumbnail_url ||
          "",
        ),

      faviconUrl:
        "https://www.youtube.com/favicon.ico",

      siteName:
        "YouTube",

      provider:
        "YouTube",

      creator:
        cleanText(
          data.author_name,
        ),

      contentType:
        "video",

      price:
        "",

      statusText:
        "",

      actionLabel:
        "Watch video",
    };
  } catch (_) {
    return null;
  } finally {
    clearTimeout(
      timeout,
    );
  }
}

//===================================================
// JSON-LD IMAGE
//===================================================

function jsonLdImage($) {
  const scripts =
    $('script[type="application/ld+json"]');

  for (
    let index = 0;
    index < scripts.length;
    index++
  ) {
    const raw =
      $(scripts[index])
        .text()
        .trim();

    if (!raw) {
      continue;
    }

    try {
      const json =
        JSON.parse(
          raw,
        );

      const items =
        Array.isArray(json)
          ? json
          : [json];

      for (const item of items) {
        if (!item) {
          continue;
        }

        const image =
          item.image;

        if (typeof image === "string") {
          return image;
        }

        if (
          Array.isArray(image) &&
          image.length
        ) {
          if (
            typeof image[0] ===
            "string"
          ) {
            return image[0];
          }

          if (
            image[0] &&
            typeof image[0].url ===
            "string"
          ) {
            return image[0].url;
          }
        }

        if (
          image &&
          typeof image.url ===
          "string"
        ) {
          return image.url;
        }
      }
    } catch (_) {}
  }

  return "";
}

//===================================================
// HTML PREVIEW
//===================================================

function htmlPreview(
  html,
  finalUrl,
) {
  const $ =
    cheerio.load(
      html,
    );

  const getMeta =
      (...names) => {
        for (const name of names) {
          const value =
            $(
              `meta[property="${name}"]`,
            )
              .attr(
                "content",
              ) ||
            $(
              `meta[name="${name}"]`,
            )
              .attr(
                "content",
              );

          if (
            value &&
            value.trim()
          ) {
            return value.trim();
          }
        }

        return "";
      };

  const title =
    cleanText(
      getMeta(
        "og:title",
        "twitter:title",
      ) ||
      $("title")
        .first()
        .text(),
    );

  const description =
    cleanText(
      getMeta(
        "og:description",
        "twitter:description",
        "description",
      ),
    );

  const siteName =
    cleanText(
      getMeta(
        "og:site_name",
      ),
    );

  const creator =
    cleanText(
      getMeta(
        "author",
        "article:author",
        "twitter:creator",
      ),
    );

  const ogImage =
    getMeta(
      "og:image:secure_url",
      "og:image",
      "twitter:image",
      "twitter:image:src",
    );

  const structuredImage =
    jsonLdImage(
      $,
    );

  const imageUrl =
    absoluteUrl(
      ogImage ||
      structuredImage,
      finalUrl,
    );

  const iconLink =
    $(
      'link[rel="apple-touch-icon"]',
    )
      .first()
      .attr(
        "href",
      ) ||
    $(
      'link[rel~="icon"]',
    )
      .first()
      .attr(
        "href",
      ) ||
    "";

  const faviconUrl =
    absoluteUrl(
      iconLink,
      finalUrl,
    );

  const canonical =
    absoluteUrl(
      $(
        'link[rel="canonical"]',
      )
        .first()
        .attr(
          "href",
        ),
      finalUrl,
    );

  const ogType =
    getMeta(
      "og:type",
    )
      .toLowerCase();

  let contentType =
    "website";

  if (
    ogType.includes(
      "video",
    )
  ) {
    contentType =
      "video";
  } else if (
    ogType.includes(
      "article",
    )
  ) {
    contentType =
      "article";
  } else if (
    ogType.includes(
      "product",
    )
  ) {
    contentType =
      "product";
  }

  const priceAmount =
    getMeta(
      "product:price:amount",
      "og:price:amount",
    );

  const currency =
    getMeta(
      "product:price:currency",
      "og:price:currency",
    );

  const price =
    priceAmount
      ? `${priceAmount}${currency ? ` ${currency}` : ""}`
      : "";

  const url =
    new URL(
      finalUrl,
    );

  const provider =
    providerName(
      url.hostname,
    );

  return {
    title:
      title ||
      provider,

    description,

    siteName:
      siteName ||
      provider,

    provider,

    creator,

    imageUrl,

    faviconUrl:
      faviconUrl ||
      `${url.origin}/favicon.ico`,

    canonicalUrl:
      canonical ||
      finalUrl,

    contentType,

    price,

    statusText:
      "",

    actionLabel:
      contentType === "video"
        ? "Watch"
        : contentType === "product"
        ? "View product"
        : contentType === "article"
        ? "Read article"
        : "Open link",
  };
}

//===================================================
// GENERIC PREVIEW
//===================================================

async function resolvePreview(url) {
  if (isYoutube(url)) {
    const youtube =
      await youtubePreview(
        url,
      );

    if (youtube) {
      return {
        ...youtube,

        canonicalUrl:
          url,

        resolvedUrl:
          url,
      };
    }
  }

  const {
    response,
    body,
    finalUrl,
  } =
    await safeFetch(
      url,
    );

  const contentType =
    String(
      response.headers.get(
        "content-type",
      ) ||
      "",
    )
      .toLowerCase();

  const parsedUrl =
    new URL(
      finalUrl,
    );

  const provider =
    providerName(
      parsedUrl.hostname,
    );

  //===================================================
  // IMAGE LINK
  //===================================================

  if (
    contentType.startsWith(
      "image/",
    )
  ) {
    return {
      title:
        parsedUrl.pathname
          .split("/")
          .pop() ||
        provider,

      description:
        "",

      siteName:
        provider,

      provider,

      creator:
        "",

      imageUrl:
        finalUrl,

      faviconUrl:
        `${parsedUrl.origin}/favicon.ico`,

      canonicalUrl:
        finalUrl,

      resolvedUrl:
        finalUrl,

      contentType:
        "image",

      price:
        "",

      statusText:
        "",

      actionLabel:
        "Open image",
    };
  }

  //===================================================
  // PDF
  //===================================================

  if (
    contentType.includes(
      "application/pdf",
    ) ||
    parsedUrl.pathname
      .toLowerCase()
      .endsWith(
        ".pdf",
      )
  ) {
    return {
      title:
        decodeURIComponent(
          parsedUrl.pathname
            .split("/")
            .pop() ||
          "PDF document",
        ),

      description:
        "PDF document",

      siteName:
        provider,

      provider,

      creator:
        "",

      imageUrl:
        "",

      faviconUrl:
        `${parsedUrl.origin}/favicon.ico`,

      canonicalUrl:
        finalUrl,

      resolvedUrl:
        finalUrl,

      contentType:
        "document",

      price:
        "",

      statusText:
        "PDF",

      actionLabel:
        "Open document",
    };
  }

  if (
    !contentType.includes(
      "text/html",
    ) &&
    !contentType.includes(
      "application/xhtml",
    )
  ) {
    return {
      title:
        provider,

      description:
        "Open this link",

      siteName:
        provider,

      provider,

      creator:
        "",

      imageUrl:
        "",

      faviconUrl:
        `${parsedUrl.origin}/favicon.ico`,

      canonicalUrl:
        finalUrl,

      resolvedUrl:
        finalUrl,

      contentType:
        "website",

      price:
        "",

      statusText:
        "",

      actionLabel:
        "Open link",
    };
  }

  const html =
    body.toString(
      "utf8",
    );

  return {
    ...htmlPreview(
      html,
      finalUrl,
    ),

    resolvedUrl:
      finalUrl,
  };
}

//===================================================
// SERIALIZE FOR FLUTTER
//===================================================

function clientData(data) {
  return {
    ...data,

    cachedAt:
      data.cachedAt
        instanceof Timestamp
        ? data.cachedAt
          .toMillis()
        : data.cachedAt,

    expiresAt:
      data.expiresAt
        instanceof Timestamp
        ? data.expiresAt
          .toMillis()
        : data.expiresAt,
  };
}

//===================================================
// CLOUD FUNCTION
//===================================================

exports.getLinkPreview =
onCall(
  {
    region:
      REGION,

    timeoutSeconds:
      15,

    memory:
      "256MiB",

    maxInstances:
      50,
  },

  async (
    request,
  ) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in.",
      );
    }

    const normalized =
      normalizeUrl(
        request.data
          ? request.data.url
          : null,
      );
   const forceRefresh =
     request.data &&
     request.data.forceRefresh ===
       true;

    const id =
      cacheId(
        normalized,
      );

    const ref =
      db
        .collection(
          "linkPreviews",
        )
        .doc(
          id,
        );

//===================================================
    // CACHE
    //===================================================

    if (!forceRefresh) {
      const cached =
        await ref.get();

      if (
        cached.exists
      ) {
        const data =
          cached.data();

        if (
          data &&
          data.expiresAt
          instanceof Timestamp &&
          data.expiresAt
            .toMillis() >
          Date.now()
        ) {
          return clientData(
            data,
          );
        }
      }
    }

    let metadata;
    let failure = false;

    try {
      metadata =
        await resolvePreview(
          normalized,
        );
    } catch (error) {
      failure =
        true;

      const parsed =
        new URL(
          normalized,
        );

      const provider =
        providerName(
          parsed.hostname,
        );

      metadata = {
        title:
          provider,

        description:
          "Preview information is currently unavailable.",

        siteName:
          provider,

        provider,

        creator:
          "",

        imageUrl:
          "",

        faviconUrl:
          `${parsed.origin}/favicon.ico`,

        canonicalUrl:
          normalized,

        resolvedUrl:
          normalized,

        contentType:
          "website",

        price:
          "",

        statusText:
          "",

        actionLabel:
          "Open link",
      };
    }

    const now =
      Timestamp.now();

    const ttl =
      failure
        ? FAILURE_CACHE_HOURS
        : CACHE_HOURS;

    const expiresAt =
      Timestamp.fromMillis(
        Date.now() +
        ttl *
        60 *
        60 *
        1000,
      );

    const domain =
      new URL(
        metadata.resolvedUrl ||
        normalized,
      )
        .hostname
        .replace(
          /^www\./,
          "",
        );

    const stored = {
      url:
        normalized,

      resolvedUrl:
        metadata.resolvedUrl ||
        normalized,

      canonicalUrl:
        metadata.canonicalUrl ||
        metadata.resolvedUrl ||
        normalized,

      title:
        metadata.title ||
        domain,

      description:
        metadata.description ||
        "",

      siteName:
        metadata.siteName ||
        domain,

      domain,

      imageUrl:
        metadata.imageUrl ||
        "",

      faviconUrl:
        metadata.faviconUrl ||
        "",

      contentType:
        metadata.contentType ||
        "website",

      provider:
        metadata.provider ||
        domain,

      creator:
        metadata.creator ||
        "",

      price:
        metadata.price ||
        "",

      statusText:
        metadata.statusText ||
        "",

      internalType:
        "",

      internalId:
        "",

      isInternal:
        false,

      isAvailable:
        true,

      actionLabel:
        metadata.actionLabel ||
        "Open link",

      cachedAt:
        now,

      expiresAt,
    };

    await ref.set(
      stored,
      {
        merge:
          true,
      },
    );

    return clientData(
      stored,
    );
  },
);

//===================================================
 // VALIDATE GROUP INVITATION TOKEN
 //===================================================

function validateGroupInviteToken(value) {
  if (
    typeof value !== "string" ||
    !/^[A-Za-z0-9]{32}$/.test(value.trim())
  ) {
    throw new HttpsError(
      "invalid-argument",
      "This group invitation link is invalid.",
    );
  }

  return value.trim();
}

//===================================================
// PREVIEW GROUP INVITATION
//===================================================

exports.getGroupInvitePreview = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
  },

  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in to view a group invitation.",
      );
    }

    const token = validateGroupInviteToken(
      request.data?.token,
    );

    const matches = await db
      .collection("chatGroups")
      .where("inviteToken", "==", token)
      .limit(1)
      .get();

    if (matches.empty) {
      throw new HttpsError(
        "not-found",
        "This invitation is invalid or has been reset.",
      );
    }

    const group = matches.docs[0].data();

    const memberIds = Array.isArray(group.memberIds)
      ? group.memberIds
      : [];

    return {
      name: String(
        group.name || "Nubify group",
      ).slice(0, 100),

      description: String(
        group.description || "",
      ).slice(0, 500),

      photoUrl: String(
        group.photoUrl || "",
      ).slice(0, 2048),

      memberCount: memberIds.length,

      adminApprovalRequired:
        group.permissions?.adminApprovalRequired === true,
    };
  },
);

//===================================================
// JOIN GROUP USING INVITATION
//===================================================

exports.joinGroupByInvite = onCall(
  {
    region: REGION,
    timeoutSeconds: 20,
    memory: "256MiB",
  },

  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Sign in before joining a group.",
      );
    }

    const token = validateGroupInviteToken(
      request.data?.token,
    );

    const matches = await db
      .collection("chatGroups")
      .where("inviteToken", "==", token)
      .limit(1)
      .get();

    if (matches.empty) {
      throw new HttpsError(
        "not-found",
        "This invitation is invalid or has been reset.",
      );
    }

    const groupRef = matches.docs[0].ref;

    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(groupRef);

      if (
        !snapshot.exists ||
        snapshot.data()?.inviteToken !== token
      ) {
        throw new HttpsError(
          "not-found",
          "This invitation is no longer valid.",
        );
      }

      const group = snapshot.data();

      const members = Array.isArray(group.memberIds)
        ? group.memberIds
        : [];

      //===================================================
      // USER IS ALREADY A MEMBER
      //===================================================

      if (members.includes(uid)) {
        return {
          status: "joined",
          groupId: groupRef.id,
        };
      }

      //===================================================
      // GROUP REQUIRES ADMIN APPROVAL
      //===================================================

      if (
        group.permissions?.adminApprovalRequired === true
      ) {
        const joinRef = groupRef
          .collection("joinRequests")
          .doc(uid);

        const requestSnapshot =
          await transaction.get(joinRef);

        if (
          !requestSnapshot.exists ||
          requestSnapshot.data()?.status !== "pending"
        ) {
          const now = Timestamp.now();

          transaction.set(joinRef, {
            uid,
            status: "pending",
            createdAt: now,
            updatedAt: now,
          });
        }

        return {
          status: "pending",
        };
      }

      //===================================================
      // JOIN GROUP DIRECTLY
      //===================================================

      const now = Timestamp.now();

      const existingJoinedAt =
        group.memberJoinedAt &&
        typeof group.memberJoinedAt === "object" &&
        !Array.isArray(group.memberJoinedAt)
          ? group.memberJoinedAt
          : {};

      transaction.update(groupRef, {
        memberIds: FieldValue.arrayUnion(uid),

        members: FieldValue.arrayUnion(uid),

        memberJoinedAt: {
          ...existingJoinedAt,
          [uid]: now,
        },

        updatedAt: now,
      });

      return {
        status: "joined",
        groupId: groupRef.id,
      };
    });
  },
);

//===================================================
// NUB MARKETPLACE BACKEND
//===================================================

Object.assign(
  exports,
  require("./marketplace"),
);

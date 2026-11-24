"use strict";

//===================================================
// NUBIFY PHONE NOTIFICATION WORDS
//
// What the pop-ups say, in the six app languages.
// Used by push.js; tested by test/push_words.test.js.
//===================================================

const LANGUAGES = ["en", "ar", "fr", "ha", "yo", "hi"];

//===================================================
// WORDS
//
// {name} = who did it, {text} = what they wrote.
// A pair is [he, she]: Arabic and Hausa verbs change
// with the person's gender.
//===================================================

const ACTIONS = {
  like: {
    en: "{name} liked your post",
    ar: ["{name} أُعجب بمنشورك", "{name} أُعجبت بمنشورك"],
    fr: "{name} a aimé votre publication",
    ha: ["{name} ya so rubutunku", "{name} ta so rubutunku"],
    yo: "{name} fẹ́ràn ìfìwéránṣẹ́ rẹ",
    hi: "{name} ने आपकी पोस्ट पसंद की",
  },
  comment: {
    en: "{name} commented on your post",
    ar: ["{name} علّق على منشورك", "{name} علّقت على منشورك"],
    fr: "{name} a commenté votre publication",
    ha: [
      "{name} ya yi sharhi a kan rubutunku",
      "{name} ta yi sharhi a kan rubutunku",
    ],
    yo: "{name} sọ̀rọ̀ lórí ìfìwéránṣẹ́ rẹ",
    hi: "{name} ने आपकी पोस्ट पर टिप्पणी की",
  },
  reply: {
    en: "{name} replied to your comment",
    ar: ["{name} ردّ على تعليقك", "{name} ردّت على تعليقك"],
    fr: "{name} a répondu à votre commentaire",
    ha: ["{name} ya amsa sharhinku", "{name} ta amsa sharhinku"],
    yo: "{name} fèsì sí ọ̀rọ̀ rẹ",
    hi: "{name} ने आपकी टिप्पणी का जवाब दिया",
  },
  repost: {
    en: "{name} reposted your post",
    ar: ["{name} أعاد نشر منشورك", "{name} أعادت نشر منشورك"],
    fr: "{name} a republié votre publication",
    ha: [
      "{name} ya sake wallafa rubutunku",
      "{name} ta sake wallafa rubutunku",
    ],
    yo: "{name} tún ìfìwéránṣẹ́ rẹ fi ránṣẹ́",
    hi: "{name} ने आपकी पोस्ट रीपोस्ट की",
  },
  quoteRepost: {
    en: "{name} quoted your post",
    ar: ["{name} اقتبس منشورك", "{name} اقتبست منشورك"],
    fr: "{name} a cité votre publication",
    ha: [
      "{name} ya sake wallafa rubutunku da tsokaci",
      "{name} ta sake wallafa rubutunku da tsokaci",
    ],
    yo: "{name} fi ọ̀rọ̀ tún ìfìwéránṣẹ́ rẹ fi ránṣẹ́",
    hi: "{name} ने आपकी पोस्ट को कोट किया",
  },
  tag: {
    en: "{name} tagged you in a post",
    ar: ["{name} أشار إليك في منشور", "{name} أشارت إليك في منشور"],
    fr: "{name} vous a identifié(e) dans une publication",
    ha: [
      "{name} ya ambace ku a wani rubutu",
      "{name} ta ambace ku a wani rubutu",
    ],
    yo: "{name} dárúkọ rẹ nínú ìfìwéránṣẹ́ kan",
    hi: "{name} ने आपको एक पोस्ट में टैग किया",
  },
  follow: {
    en: "{name} started following you",
    ar: ["{name} بدأ متابعتك", "{name} بدأت متابعتك"],
    fr: "{name} a commencé à vous suivre",
    ha: ["{name} ya fara bin ku", "{name} ta fara bin ku"],
    yo: "{name} bẹ̀rẹ̀ sí í tẹ̀lé ọ",
    hi: "{name} ने आपको फ़ॉलो करना शुरू किया",
  },
  storyTag: {
    en: "{name} tagged you in a story",
    ar: ["{name} أشار إليك في قصة", "{name} أشارت إليك في قصة"],
    fr: "{name} vous a identifié(e) dans une story",
    ha: [
      "{name} ya ambace ku a wani labari",
      "{name} ta ambace ku a wani labari",
    ],
    yo: "{name} dárúkọ rẹ nínú ìtàn kan",
    hi: "{name} ने आपको एक स्टोरी में टैग किया",
  },
  storyLike: {
    en: "{name} liked your story",
    ar: ["{name} أُعجب بقصتك", "{name} أُعجبت بقصتك"],
    fr: "{name} a aimé votre story",
    ha: ["{name} ya so labarinku", "{name} ta so labarinku"],
    yo: "{name} fẹ́ràn ìtàn rẹ",
    hi: "{name} ने आपकी स्टोरी पसंद की",
  },
  storyReply: {
    en: "{name} replied to your story",
    ar: ["{name} ردّ على قصتك", "{name} ردّت على قصتك"],
    fr: "{name} a répondu à votre story",
    ha: ["{name} ya amsa labarinku", "{name} ta amsa labarinku"],
    yo: "{name} fèsì sí ìtàn rẹ",
    hi: "{name} ने आपकी स्टोरी का जवाब दिया",
  },
  storyReshare: {
    en: "{name} shared your story",
    ar: ["{name} شارك قصتك", "{name} شاركت قصتك"],
    fr: "{name} a partagé votre story",
    ha: ["{name} ya raba labarinku", "{name} ta raba labarinku"],
    yo: "{name} pín ìtàn rẹ",
    hi: "{name} ने आपकी स्टोरी शेयर की",
  },
};

// Chat messages that are not plain text.
const MESSAGES = {
  image: {
    en: "📷 Photo",
    ar: "📷 صورة",
    fr: "📷 Photo",
    ha: "📷 Hoto",
    yo: "📷 Àwòrán",
    hi: "📷 फ़ोटो",
  },
  video: {
    en: "🎥 Video",
    ar: "🎥 فيديو",
    fr: "🎥 Vidéo",
    ha: "🎥 Bidiyo",
    yo: "🎥 Fídíò",
    hi: "🎥 वीडियो",
  },
  voice: {
    en: "🎤 Voice message",
    ar: "🎤 رسالة صوتية",
    fr: "🎤 Message vocal",
    ha: "🎤 Saƙon murya",
    yo: "🎤 Ìfiránṣẹ́ ohùn",
    hi: "🎤 वॉइस मैसेज",
  },
  document: {
    en: "📄 Document",
    ar: "📄 مستند",
    fr: "📄 Document",
    ha: "📄 Takarda",
    yo: "📄 Ìwé",
    hi: "📄 दस्तावेज़",
  },
  sticker: {
    en: "Sticker",
    ar: "ملصق",
    fr: "Autocollant",
    ha: "Sitika",
    yo: "Sítíkà",
    hi: "स्टिकर",
  },
  post: {
    en: "Shared a post",
    ar: ["شارك منشورًا", "شاركت منشورًا"],
    fr: "A partagé une publication",
    ha: ["Ya raba wani rubutu", "Ta raba wani rubutu"],
    yo: "Pín ìfìwéránṣẹ́ kan",
    hi: "एक पोस्ट शेयर की",
  },
  storyShare: {
    en: "Shared a story",
    ar: ["شارك قصة", "شاركت قصة"],
    fr: "A partagé une story",
    ha: ["Ya raba wani labari", "Ta raba wani labari"],
    yo: "Pín ìtàn kan",
    hi: "एक स्टोरी शेयर की",
  },
  product: {
    en: "Shared a product",
    ar: ["شارك منتجًا", "شاركت منتجًا"],
    fr: "A partagé un produit",
    ha: ["Ya raba wani kaya", "Ta raba wani kaya"],
    yo: "Pín ọjà kan",
    hi: "एक प्रोडक्ट शेयर किया",
  },
  storyReply: {
    en: "Replied to your story: {text}",
    ar: ["ردّ على قصتك: {text}", "ردّت على قصتك: {text}"],
    fr: "A répondu à votre story : {text}",
    ha: ["Ya amsa labarinku: {text}", "Ta amsa labarinku: {text}"],
    yo: "Fèsì sí ìtàn rẹ: {text}",
    hi: "आपकी स्टोरी का जवाब: {text}",
  },
  other: {
    en: "New message",
    ar: "رسالة جديدة",
    fr: "Nouveau message",
    ha: "Sabon saƙo",
    yo: "Ìfiránṣẹ́ tuntun",
    hi: "नया संदेश",
  },
};

/** The words for [language], filled in. */
function words(entry, language, {name = "", text = "", female = false} = {}) {
  let line = entry[language] || entry.en;
  if (Array.isArray(line)) line = line[female ? 1 : 0];
  return line.replace("{name}", () => name).replace("{text}", () => text);
}

/** Text short enough for a notification. */
function clip(value, max = 160) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

//===================================================
// CHAT MESSAGE TEXT
//===================================================

function messageText(message, language, sender) {
  const type = String(message.type || message.messageType || "text");
  const text = clip(message.text);

  if (type === "text") {
    return text || words(MESSAGES.other, language);
  }
  if (type === "document" && message.fileName) {
    return `📄 ${clip(message.fileName, 80)}`;
  }

  return words(MESSAGES[type] || MESSAGES.other, language, {
    text,
    female: sender.female,
  });
}

module.exports = {LANGUAGES, ACTIONS, MESSAGES, words, clip, messageText};

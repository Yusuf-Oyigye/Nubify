"use strict";

// Run from the functions folder: node --test test/push_words.test.js

const test = require("node:test");
const assert = require("node:assert");

const {
  LANGUAGES,
  ACTIONS,
  MESSAGES,
  words,
  clip,
  messageText,
} = require("../push_words");

const ali = {name: "Ali", female: false};
const amina = {name: "Amina", female: true};

test("every notification and message has all six languages", () => {
  for (const table of [ACTIONS, MESSAGES]) {
    for (const [key, entry] of Object.entries(table)) {
      for (const language of LANGUAGES) {
        assert.ok(entry[language], `${key} has no ${language}`);
      }
    }
  }
});

test("the person's name is in every notification", () => {
  for (const [key, entry] of Object.entries(ACTIONS)) {
    for (const language of LANGUAGES) {
      const line = words(entry, language, ali);
      assert.ok(line.includes("Ali"), `${key} ${language}: ${line}`);
      assert.ok(!line.includes("{"), `${key} ${language}: ${line}`);
    }
  }
});

test("each language reads right", () => {
  assert.strictEqual(words(ACTIONS.like, "en", ali), "Ali liked your post");
  assert.strictEqual(
      words(ACTIONS.follow, "fr", ali),
      "Ali a commencé à vous suivre",
  );
  assert.strictEqual(
      words(ACTIONS.like, "hi", ali),
      "Ali ने आपकी पोस्ट पसंद की",
  );
});

test("Arabic and Hausa follow the person's gender", () => {
  assert.strictEqual(words(ACTIONS.like, "ar", ali), "Ali أُعجب بمنشورك");
  assert.strictEqual(words(ACTIONS.like, "ar", amina), "Amina أُعجبت بمنشورك");
  assert.strictEqual(words(ACTIONS.follow, "ha", ali), "Ali ya fara bin ku");
  assert.strictEqual(words(ACTIONS.follow, "ha", amina), "Amina ta fara bin ku");
});

test("unknown language falls back to English", () => {
  assert.strictEqual(words(ACTIONS.like, "de", ali), "Ali liked your post");
});

test("names with $ signs stay as written", () => {
  assert.strictEqual(
      words(ACTIONS.like, "en", {name: "$& Bola"}),
      "$& Bola liked your post",
  );
});

test("chat messages", () => {
  assert.strictEqual(messageText({type: "text", text: "Hi"}, "ar", ali), "Hi");
  assert.strictEqual(messageText({type: "image"}, "ar", ali), "📷 صورة");
  assert.strictEqual(messageText({type: "voice"}, "fr", ali), "🎤 Message vocal");
  assert.strictEqual(
      messageText({type: "document", fileName: "notes.pdf"}, "en", ali),
      "📄 notes.pdf",
  );
  assert.strictEqual(
      messageText({type: "storyReply", text: "Nice!"}, "en", ali),
      "Replied to your story: Nice!",
  );
  assert.strictEqual(
      messageText({type: "post"}, "ar", amina),
      "شاركت منشورًا",
  );
  assert.strictEqual(messageText({type: "callLog"}, "yo", ali), "Ìfiránṣẹ́ tuntun");
});

test("long text is shortened", () => {
  const long = "word ".repeat(100);
  const short = clip(long);
  assert.ok(short.length <= 160);
  assert.ok(short.endsWith("…"));
});

// Adds rows of [english, ar, fr, ha, yo, hi] to an existing
// lib/l10n/translations/<feature>.dart without rewriting it.
// Phrases already in a language block are skipped (Dart maps
// cannot repeat a key). Use: require("./append_translations").append(file, rows)
"use strict";
const fs = require("fs");

const langs = ["ar", "fr", "ha", "yo", "hi"];
const q = (t) =>
  "'" +
  t
    .replace(/\\/g, "\\\\")
    .replace(/'/g, "\\'")
    .replace(/\$/g, "\\$")
    .replace(/\n/g, "\\n") +
  "'";

// Index of the "}" that closes the "{" at [open], skipping strings.
function closing(s, open) {
  let depth = 0;
  for (let i = open; i < s.length; i++) {
    const ch = s[i];
    if (ch === "'" || ch === '"') {
      i++;
      while (i < s.length && s[i] !== ch) i += s[i] === "\\" ? 2 : 1;
      continue;
    }
    if (ch === "{") depth++;
    if (ch === "}" && --depth === 0) return i;
  }
  throw new Error("unbalanced braces");
}

function append(file, rows) {
  const raw = fs.readFileSync(file, "utf8");
  const crlf = raw.includes("\r\n");
  let s = raw.replace(/\r\n/g, "\n");
  let added = 0;
  langs.forEach((lang, i) => {
    const head = s.indexOf(`'${lang}': <String, String>{`);
    if (head < 0) throw new Error(`${file}: no '${lang}' block`);
    const open = s.indexOf("{", head);
    const close = closing(s, open);
    const block = s.slice(open, close);
    const indent = (block.match(/\n(\s+)'/) || [null, "        "])[1];
    // Insert before the line that holds the closing brace.
    const at = s.lastIndexOf("\n", close);
    let lines = "";
    for (const r of rows) {
      if (r[i + 1] === null) continue;
      if (block.includes(`\n${indent}${q(r[0])}:`)) continue;
      lines += `\n${indent}${q(r[0])}: ${q(r[i + 1])},`;
      added++;
    }
    s = s.slice(0, at) + lines + s.slice(at);
  });
  fs.writeFileSync(file, crlf ? s.replace(/\n/g, "\r\n") : s);
  console.log(`${file}: ${added} translations added`);
}

module.exports = { append };

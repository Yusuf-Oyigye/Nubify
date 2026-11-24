// Lists tr() keys used in the given files that have no
// Arabic translation yet in lib/l10n/translations/*.dart.
// Reads context.tr(...) and NubifyText.tr(...): text split
// over several lines ('a ' 'b') counts as one key, and
// both sides of `x ? 'a' : 'b'` are listed.
// Extra patterns: _MenuItem('x', _sectionDividerHeading('x'),
// _unavailable('x').
"use strict";
const fs = require("fs");
const path = require("path");

const files = process.argv.slice(2);
const keys = new Set();

// Dart string literal at i ('..' or ".."); returns [value, end].
function literal(s, i) {
  const q = s[i];
  let out = "";
  let j = i + 1;
  while (j < s.length && s[j] !== q) {
    if (s[j] === "\\") {
      const next = s[j + 1];
      out += next === "n" ? "\n" : next;
      j += 2;
    } else {
      out += s[j++];
    }
  }
  return [out, j + 1];
}

// Keys in the first argument of the tr( call that starts at i.
function firstArgument(s, i) {
  const found = [];
  let depth = 0;
  let current = null;
  while (i < s.length) {
    const ch = s[i];
    if (ch === "'" || ch === '"') {
      const [value, end] = literal(s, i);
      current = (current ?? "") + value;
      i = end;
      continue;
    }
    if (/\s/.test(ch)) {
      i++;
      continue;
    }
    if (current !== null) {
      found.push(current);
      current = null;
    }
    if ("([{".includes(ch)) depth++;
    if (")]}".includes(ch)) {
      if (depth === 0) break;
      depth--;
    }
    if (ch === "," && depth === 0) break;
    i++;
  }
  if (current !== null) found.push(current);
  return found;
}

const simple = [
  /_MenuItem\(\s*'((?:[^'\\]|\\.)*)'/g,
  /_sectionDividerHeading\(\s*'((?:[^'\\]|\\.)*)'/g,
  /_unavailable\(\s*'((?:[^'\\]|\\.)*)'/g,
];

for (const f of files) {
  const s = fs.readFileSync(f, "utf8").replace(/\r\n/g, "\n");
  for (const m of s.matchAll(/(?:context|NubifyText)\.tr\(/g)) {
    for (const key of firstArgument(s, m.index + m[0].length)) keys.add(key);
  }
  for (const re of simple) for (const m of s.matchAll(re)) keys.add(m[1]);
}

const known = new Set();
const dir = "lib/l10n/translations";
for (const f of fs.readdirSync(dir)) {
  const s = fs.readFileSync(path.join(dir, f), "utf8");
  const ar = s.indexOf("'ar':");
  const fr = s.indexOf("'fr':");
  const block = s.slice(ar, fr > ar ? fr : undefined);
  for (const m of block.matchAll(/^\s*'((?:[^'\\]|\\.)*)':/gm)) {
    known.add(m[1].replace(/\\n/g, "\n").replace(/\\(.)/g, "$1"));
  }
  for (const m of block.matchAll(/^\s*"((?:[^"\\]|\\.)*)":/gm)) {
    known.add(m[1].replace(/\\n/g, "\n").replace(/\\(.)/g, "$1"));
  }
}
const missing = [...keys].filter((k) => !known.has(k) && /[A-Za-z]/.test(k));
console.log(JSON.stringify(missing, null, 1));
console.error(`${keys.size} keys, ${missing.length} missing`);

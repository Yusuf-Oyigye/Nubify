// Lists tr() keys used in the given files that have no
// Arabic translation yet in lib/l10n/translations/*.dart.
// Extra patterns: _MenuItem('x', _sectionDividerHeading('x'),
// _unavailable('x').
"use strict";
const fs = require("fs");
const path = require("path");

const files = process.argv.slice(2);
const keys = new Set();
const patterns = [
  /context\.tr\(\s*'((?:[^'\\]|\\.)*)'/g,
  /context\.tr\(\s*"((?:[^"\\]|\\.)*)"/g,
  /_MenuItem\(\s*'((?:[^'\\]|\\.)*)'/g,
  /_sectionDividerHeading\(\s*'((?:[^'\\]|\\.)*)'/g,
  /_unavailable\(\s*'((?:[^'\\]|\\.)*)'/g,
];
for (const f of files) {
  const s = fs.readFileSync(f, "utf8");
  for (const re of patterns) for (const m of s.matchAll(re)) keys.add(m[1]);
}

const known = new Set();
const dir = "lib/l10n/translations";
for (const f of fs.readdirSync(dir)) {
  const s = fs.readFileSync(path.join(dir, f), "utf8");
  const ar = s.indexOf("'ar':");
  const fr = s.indexOf("'fr':");
  const block = s.slice(ar, fr > ar ? fr : undefined);
  for (const m of block.matchAll(/^\s*'((?:[^'\\]|\\.)*)':/gm)) known.add(m[1]);
  for (const m of block.matchAll(/^\s*"((?:[^"\\]|\\.)*)":/gm)) known.add(m[1]);
}
const missing = [...keys].filter((k) => !known.has(k));
console.log(JSON.stringify(missing, null, 1));
console.error(`${keys.size} keys, ${missing.length} missing`);

// Wraps plain English UI strings in context.tr('...').
// Usage: node wrap_tr.js <lib-relative dart files...>
// Only touches Text('...') and a few named arguments whose
// value is a single plain literal (no $, has letters).
"use strict";
const fs = require("fs");
const path = require("path");

const root = process.cwd();
const files = process.argv.slice(2);
const named = ["label", "tooltip", "hintText", "labelText", "helperText", "title", "subtitle", "semanticLabel"];

function ok(str) {
  return /[A-Za-z]{2}/.test(str) && !str.includes("$") && !/^https?:/.test(str) &&
    !/^[a-z_]+$/.test(str) && !str.includes("\\n\\n\\n");
}

let total = 0;
for (const rel of files) {
  const file = path.join(root, rel);
  const raw = fs.readFileSync(file, "utf8");
  const crlf = raw.includes("\r\n");
  let s = raw.replace(/\r\n/g, "\n");
  let count = 0;

  // const Text('x' ...)  /  Text('x' ...)  (single-quoted, may span lines)
  s = s.replace(/(const\s+)?Text\(\s*'((?:[^'\\\n]|\\.)*)'/g, (m, c, str) => {
    if (!ok(str)) return m;
    count++;
    return `Text(context.tr('${str}')`;
  });
  s = s.replace(/(const\s+)?Text\(\s*"((?:[^"\\\n]|\\.)*)"/g, (m, c, str) => {
    if (!ok(str)) return m;
    count++;
    return `Text(context.tr("${str}")`;
  });
  for (const n of named) {
    const re = new RegExp(`\\b${n}:(\\s*)'((?:[^'\\\\\\n]|\\\\.)*)'(\\s*[,)])`, "g");
    s = s.replace(re, (m, sp, str, tail) => {
      if (!ok(str)) return m;
      count++;
      return `${n}:${sp}context.tr('${str}')${tail}`;
    });
  }

  if (count > 0 && !s.includes("l10n/nubify_text.dart")) {
    const importPath = path
      .relative(path.dirname(file), path.join(root, "lib/l10n/nubify_text.dart"))
      .split(path.sep)
      .join("/");
    const imports = [...s.matchAll(/^import '[^']+';\n/gm)];
    const last = imports[imports.length - 1];
    const at = last.index + last[0].length;
    s = s.slice(0, at) + `import '${importPath}';\n` + s.slice(at);
  }

  fs.writeFileSync(file, crlf ? s.replace(/\n/g, "\r\n") : s);
  console.log(`${rel}: ${count}`);
  total += count;
}
console.log(`total wrapped: ${total}`);

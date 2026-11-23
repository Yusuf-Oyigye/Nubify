// Runs dart analyze on the given files and removes the
// nearest "const " before each invalid-constant error,
// repeating until clean. Prints any other errors.
"use strict";
const fs = require("fs");
const { execSync } = require("child_process");

const files = process.argv.slice(2);
const constCodes = /invalid_constant|const_with_non_constant_argument|non_constant_list_element|const_initialized_with_non_constant_value|non_constant_map_element|const_constructor_param_type_mismatch|const_eval/;

for (let round = 0; round < 40; round++) {
  let out = "";
  try {
    out = execSync(`dart analyze --format=machine ${files.join(" ")}`, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  } catch (e) {
    out = (e.stdout || "") + (e.stderr || "");
  }
  const errors = out.split(/\r?\n/).filter((l) => l.startsWith("ERROR|"));
  const constErrors = errors.filter((l) => constCodes.test(l.split("|")[2].toLowerCase()));
  if (constErrors.length === 0) {
    errors.forEach((l) => console.log("REMAINING " + l));
    console.log(`done after ${round} rounds, ${errors.length} other errors`);
    process.exit(0);
  }
  // One fix per file per round (positions shift after edits).
  const seen = new Set();
  for (const l of constErrors) {
    const parts = l.split("|");
    const file = parts[3];
    if (seen.has(file)) continue;
    seen.add(file);
    const line = Number(parts[4]);
    const col = Number(parts[5]);
    const raw = fs.readFileSync(file, "utf8");
    const crlf = raw.includes("\r\n");
    const text = raw.replace(/\r\n/g, "\n");
    const lines = text.split("\n");
    let offset = 0;
    for (let i = 0; i < line - 1; i++) offset += lines[i].length + 1;
    offset += col - 1;
    const before = text.slice(0, offset);
    const at = before.lastIndexOf("const ");
    if (at === -1) { console.log("NO CONST for " + l); process.exit(1); }
    const fixed = text.slice(0, at) + text.slice(at + 6);
    fs.writeFileSync(file, crlf ? fixed.replace(/\n/g, "\r\n") : fixed);
  }
}
console.log("gave up after 40 rounds");

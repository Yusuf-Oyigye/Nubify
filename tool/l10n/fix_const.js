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
  // Every const error in a file in one round: find the
  // nearest "const " before each error on the unchanged
  // text, then remove those from the end backwards so
  // earlier positions stay right. (A const shared by
  // several errors is removed once.)
  const byFile = new Map();
  for (const l of constErrors) {
    const parts = l.split("|");
    const list = byFile.get(parts[3]) || [];
    list.push([Number(parts[4]), Number(parts[5])]);
    byFile.set(parts[3], list);
  }
  for (const [file, places] of byFile) {
    const raw = fs.readFileSync(file, "utf8");
    const crlf = raw.includes("\r\n");
    let text = raw.replace(/\r\n/g, "\n");
    const starts = [0];
    for (let i = 0; i < text.length; i++) if (text[i] === "\n") starts.push(i + 1);
    const targets = new Set();
    for (const [line, col] of places) {
      const at = text.lastIndexOf("const ", starts[line - 1] + col - 1);
      // A const more than 40 lines up is not the cause (for
      // example a constructor declaration): fix it by hand.
      const constLine = text.slice(0, at).split("\n").length;
      if (at === -1 || line - constLine > 40) {
        console.log("FIX BY HAND " + file + " at " + line + ":" + col);
        process.exit(1);
      }
      targets.add(at);
    }
    for (const at of [...targets].sort((a, b) => b - a)) {
      text = text.slice(0, at) + text.slice(at + 6);
    }
    fs.writeFileSync(file, crlf ? text.replace(/\n/g, "\r\n") : text);
  }
}
console.log("gave up after 40 rounds");

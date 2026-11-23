// Helper for writing lib/l10n/translations/<feature>.dart from rows of
// [english, ar, fr, ha, yo, hi]. Use: require("./write_translations").write(...)
// Writes translations into lib/l10n/translations/<file>.dart.
// Each entry: [english, ar, fr, ha, yo, hi].
"use strict";
const fs = require("fs");

function write(file, name, comment, rows) {
  const langs = ["ar", "fr", "ha", "yo", "hi"];
  const q = (t) => "'" + t.replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'";
  let out = `// ${comment}\n// See lib/l10n/nubify_text.dart.\n\nconst Map<String, Map<String, String>> ${name} =\n    <String, Map<String, String>>{\n`;
  langs.forEach((lang, i) => {
    out += `      '${lang}': <String, String>{\n`;
    for (const r of rows) {
      if (r[i + 1] === null) continue;
      out += `        ${q(r[0])}: ${q(r[i + 1])},\n`;
    }
    out += `      },\n`;
  });
  out += `    };\n`;
  fs.writeFileSync(file, out);
  console.log(`${file}: ${rows.length} phrases`);
}

module.exports = { write };


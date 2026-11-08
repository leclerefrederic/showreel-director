// Copies the skill folder into app/resources/skill for packaging (never committed).
const fs = require("fs"), path = require("path");
const src = path.join(__dirname, "..", "..", "showreel-director");
const dst = path.join(__dirname, "..", "resources", "skill");
fs.rmSync(dst, { recursive: true, force: true });
fs.cpSync(src, dst, { recursive: true, filter: p => !/__pycache__|\.DS_Store/.test(p) });
console.log("skill copied to", dst);

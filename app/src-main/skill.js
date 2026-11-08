// Locates the skill and builds the system prompt from SKILL.md.
const fs = require("fs"), path = require("path");

function skillRoot() {
  const cands = [
    process.env.SHOWREEL_SKILL_DIR,
    process.resourcesPath && path.join(process.resourcesPath, "skill"),
    path.join(__dirname, "..", "..", "showreel-director"),
  ].filter(Boolean);
  for (const c of cands) if (fs.existsSync(path.join(c, "SKILL.md"))) return c;
  throw new Error("showreel-director skill folder not found");
}

const ADDENDUM = (root, project, lang) => fs.readFileSync(path.join(__dirname, "..", "shared", "addendum.md"), "utf8")
  .replace(/{{root}}/g, root).replace(/{{project}}/g, project)
  .replace(/{{lang}}/g, lang || "the language of the user's first message"); // template shared with the Swift app

function systemPrompt(project, lang) {
  const root = skillRoot();
  const skill = fs.readFileSync(path.join(root, "SKILL.md"), "utf8").replace(/^---[\s\S]*?---\n/, "");
  return { root, text: skill + "\n" + ADDENDUM(root, project, lang) };
}
module.exports = { skillRoot, systemPrompt };

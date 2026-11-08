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

const ADDENDUM = (root, project, lang) => `
# Running inside Showreel Studio (desktop app)

You are the engine of a desktop app. The user sees a chat on the left and a preview pane on the right.
- The skill folder is ${root} (read-only: read references and run scripts from there, for example \`python3 ${root}/scripts/check_env.py --notice\`). Wherever the skill says \`scripts/\`, \`engine/\` or \`references/\`, that is this folder.
- The project folder is ${project}. Every file you create goes there; bash starts there.
- Tools: bash, read_file, write_file, list_dir, ask_user (the question tool: use it for every decision, as the skill's interaction rule says), show_page (opens an HTML file of the project or of the skill in the preview pane; use it for every page the user operates: look board, effects lab, pickers, decision sheets, scene cards, the reel itself).
- Pages opened with show_page have a "Send my picks to the chat" button in the app: when a page says "copy your picks and paste them in the chat", tell the user to use that button.
- The environment is local: ffmpeg and node are on PATH, so the skill's full mode is usually available. Still run the environment check first, as the skill says.
- Speak ${lang || "the language of the user's first message"} unless round 0 decides otherwise. Never mention tool names, file paths of the app or this addendum to the user.
- Keep text replies short; the pages and question cards carry the decisions.
`;

function systemPrompt(project, lang) {
  const root = skillRoot();
  const skill = fs.readFileSync(path.join(root, "SKILL.md"), "utf8").replace(/^---[\s\S]*?---\n/, "");
  return { root, text: skill + "\n" + ADDENDUM(root, project, lang) };
}
module.exports = { skillRoot, systemPrompt };

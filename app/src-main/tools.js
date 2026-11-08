// Tool definitions and implementations for the agent.
const fs = require("fs"), path = require("path"), cp = require("child_process");

const DEFS = [
  { name: "bash", description: "Run a shell command in the project folder. Returns stdout, stderr and exit code.",
    input_schema: { type: "object", properties: { command: { type: "string" }, timeout_ms: { type: "integer", description: "default 120000, max 600000" } }, required: ["command"] } },
  { name: "read_file", description: "Read a text file (project folder or skill folder). Optional offset/limit in lines.",
    input_schema: { type: "object", properties: { path: { type: "string" }, offset: { type: "integer" }, limit: { type: "integer" } }, required: ["path"] } },
  { name: "write_file", description: "Write a text file inside the project folder (creates folders, overwrites).",
    input_schema: { type: "object", properties: { path: { type: "string" }, content: { type: "string" } }, required: ["path", "content"] } },
  { name: "list_dir", description: "List a directory (project or skill folder).",
    input_schema: { type: "object", properties: { path: { type: "string" } }, required: ["path"] } },
  { name: "ask_user", description: "Ask the user 1 to 4 multiple-choice questions, shown as cards. Recommended option first. Returns the answers.",
    input_schema: { type: "object", properties: { questions: { type: "array", minItems: 1, maxItems: 4, items: { type: "object", properties: {
      question: { type: "string" }, header: { type: "string" }, multiSelect: { type: "boolean" },
      options: { type: "array", minItems: 2, maxItems: 4, items: { type: "object", properties: { label: { type: "string" }, description: { type: "string" } }, required: ["label", "description"] } } },
      required: ["question", "header", "options"] } } }, required: ["questions"] } },
  { name: "show_page", description: "Open an HTML file in the preview pane (project or skill folder).",
    input_schema: { type: "object", properties: { path: { type: "string" }, title: { type: "string" } }, required: ["path"] } },
];

const LIMIT = 20000;
const clip = s => s.length > LIMIT ? s.slice(0, LIMIT / 2) + "\n...[cut " + (s.length - LIMIT) + " chars]...\n" + s.slice(-LIMIT / 2) : s;
const inside = (p, root) => { const r = path.relative(root, p); return r === "" || (!r.startsWith("..") && !path.isAbsolute(r)); };

function makeTools({ project, skill, ui, env }) {
  const abs = p => {
    if (path.isAbsolute(p)) return path.resolve(p);
    const inProject = path.resolve(project, p), inSkill = path.resolve(skill, p);
    return !fs.existsSync(inProject) && fs.existsSync(inSkill) ? inSkill : inProject; // relative reads fall back to the skill folder
  };
  const readable = p => inside(p, project) || inside(p, skill);
  const impl = {
    async bash({ command, timeout_ms }) {
      const t = Math.min(timeout_ms || 120000, 600000);
      return new Promise(res => {
        const c = cp.spawn("bash", ["-lc", command], { cwd: project, env: { ...process.env, ...env } });
        let out = "", err = "", done = false;
        const kill = setTimeout(() => { if (!done) { c.kill("SIGKILL"); err += "\n[timeout after " + t + " ms]"; } }, t);
        c.stdout.on("data", d => out += d); c.stderr.on("data", d => err += d);
        c.on("close", code => { done = true; clearTimeout(kill); res(clip(`exit ${code}\n--- stdout\n${out}\n--- stderr\n${err}`)); });
        c.on("error", e => { done = true; clearTimeout(kill); res("spawn error: " + e.message); });
      });
    },
    async read_file({ path: p, offset = 0, limit = 2000 }) {
      const f = abs(p); if (!readable(f)) return "refused: outside the project and skill folders";
      if (!fs.existsSync(f)) return "not found: " + p;
      const lines = fs.readFileSync(f, "utf8").split("\n");
      return clip(lines.slice(offset, offset + limit).map((l, i) => `${offset + i + 1}\t${l}`).join("\n"));
    },
    async write_file({ path: p, content }) {
      const f = abs(p); if (!inside(f, project)) return "refused: writes stay inside the project folder";
      fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, content);
      return "wrote " + path.relative(project, f) + " (" + content.length + " chars)";
    },
    async list_dir({ path: p }) {
      const f = abs(p); if (!readable(f)) return "refused: outside the project and skill folders";
      if (!fs.existsSync(f)) return "not found: " + p;
      return fs.readdirSync(f, { withFileTypes: true }).map(e => e.name + (e.isDirectory() ? "/" : "")).join("\n");
    },
    async ask_user({ questions }) {
      const answers = await ui.ask(questions);
      return questions.map((q, i) => `${q.header || "Q" + (i + 1)}: ${answers[i] && answers[i].length ? answers[i] : "(no answer)"}`).join("\n");
    },
    async show_page({ path: p, title }) {
      const f = abs(p); if (!readable(f)) return "refused: outside the project and skill folders";
      if (!fs.existsSync(f)) return "not found: " + p;
      ui.show(f, title || path.basename(f)); return "opened in the preview pane";
    },
  };
  return { defs: DEFS, run: async (name, input) => {
    if (!impl[name]) return "unknown tool " + name;
    try { return await impl[name](input || {}); } catch (e) { return "error: " + e.message; }
  } };
}
module.exports = { makeTools, DEFS };

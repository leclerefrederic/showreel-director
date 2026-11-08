// Runs the agent loop with a scripted fake client: no network, no Electron.
const assert = require("assert"), fs = require("fs"), os = require("os"), path = require("path");
const { Agent } = require("../src-main/agent");
const project = fs.mkdtempSync(path.join(os.tmpdir(), "studio-"));
const events = [];
const ui = { text: t => events.push(["text", t]), endText: () => {}, tool: (n) => events.push(["tool", n]),
  ask: async qs => { events.push(["ask", qs[0].question]); return [qs[0].options[0].label]; },
  show: (f, t) => events.push(["show", path.basename(f)]) };
const script = [
  [{ type: "text", text: "Hello" }, { type: "tool_use", id: "a", name: "bash", input: { command: "echo hi > a.txt && cat a.txt" } },
   { type: "tool_use", id: "b", name: "ask_user", input: { questions: [{ question: "Language?", header: "Lang", options: [{ label: "English", description: "x" }, { label: "French", description: "y" }] }] } },
   { type: "tool_use", id: "c", name: "write_file", input: { path: "qa/p.html", content: "<p>x</p>" } },
   { type: "tool_use", id: "d", name: "show_page", input: { path: "qa/p.html" } },
   { type: "tool_use", id: "e", name: "write_file", input: { path: "../escape.txt", content: "no" } },
   { type: "tool_use", id: "f", name: "read_file", input: { path: "SKILL.md", limit: 3 } }], 
  [{ type: "text", text: "Done" }],
];
let i = 0; const seen = [];
const client = { messages: { stream: req => { seen.push(req); const content = script[i]; const stop = i++ === 0 ? "tool_use" : "end_turn";
  return { on(ev, fn) { if (ev === "text") content.filter(b => b.type === "text").forEach(b => fn(b.text)); }, finalMessage: async () => ({ content, stop_reason: stop }) }; } } };
(async () => {
  const a = new Agent({ client, project, ui });
  await a.send("start");
  const last = a.messages[a.messages.length - 2].content; // tool results
  const res = Object.fromEntries(last.map(r => [r.tool_use_id, r.content]));
  assert(/exit 0[\s\S]*hi/.test(res.a), "bash ran in project");
  assert(res.b.includes("Lang: English"), "ask_user answer");
  assert(fs.existsSync(path.join(project, "qa/p.html")), "write_file");
  assert(res.d.includes("opened"), "show_page");
  assert(res.e.startsWith("refused"), "write outside refused");
  assert(res.f.includes("name:") || res.f.includes("---"), "skill readable: " + res.f.slice(0, 80));
  assert(seen[0].system[0].text.includes("Running inside Showreel Studio") && seen[0].system[0].text.includes("Showreel director"), "system prompt");
  assert(seen[0].tools.length === 6);
  assert(events.some(e => e[0] === "show" && e[1] === "p.html"));
  console.log("agent test ok");
})().catch(e => { console.error(e); process.exit(1); });

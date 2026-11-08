// Browser mode: same agent and UI, served on 127.0.0.1 (no Electron, no binary download).
// Usage: node src-main/server.js [project-folder]   (API key: ANTHROPIC_API_KEY or entered in the page, kept in memory only)
const http = require("http"), fs = require("fs"), path = require("path"), crypto = require("crypto"), cp = require("child_process");
const { Agent } = require("./agent");
const { skillRoot } = require("./skill");

const UI = path.join(__dirname, "..", "src-ui"), TOKEN = crypto.randomBytes(16).toString("hex");
const state = { key: process.env.ANTHROPIC_API_KEY || "", model: process.env.SHOWREEL_MODEL || "claude-sonnet-5-5",
  project: process.argv[2] ? path.resolve(process.argv[2]) : "", agent: null, pending: null, clients: new Set() };
let Anthropic; try { Anthropic = require("@anthropic-ai/sdk"); } catch { Anthropic = null; }

const emit = (ev, ...args) => { const d = "data: " + JSON.stringify({ ev, args }) + "\n\n"; state.clients.forEach(r => r.write(d)); };
const fileUrl = f => "/file?k=" + TOKEN + "&p=" + encodeURIComponent(f);
const ui = {
  text: t => emit("text", t), endText: () => emit("end"), tool: (n, i) => emit("tool", n, i),
  ask: qs => new Promise(res => { state.pending = res; emit("ask", qs); }),
  show: (f, title) => emit("show", fileUrl(f), title),
};
const inside = (p, root) => { const r = path.relative(root, p); return !r.startsWith("..") && !path.isAbsolute(r); };
const MIME = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".woff2": "font/woff2", ".mp3": "audio/mpeg", ".wav": "audio/wav", ".mp4": "video/mp4" };

const api = {
  cfg: () => ({ hasKey: !!state.key, model: state.model, project: state.project }),
  setKey: k => { state.key = String(k); state.agent = null; return true; },
  setModel: m => { state.model = String(m); state.agent = null; return true; },
  pickProject: p => { const d = path.resolve(String(p || "")); if (!fs.existsSync(d) || !fs.statSync(d).isDirectory()) return ""; state.project = d; state.agent = null; return d; },
  async send(text) {
    if (!state.key) return "Set your API key first.";
    if (!state.project) return "Choose a project folder first.";
    if (!Anthropic) return "Run npm install first (the SDK is missing).";
    try {
      if (!state.agent) state.agent = new Agent({ client: new Anthropic({ apiKey: state.key }), model: state.model, project: state.project, ui });
      await state.agent.send(text); return "";
    } catch (e) { return "Error: " + e.message; }
  },
  stop: () => { if (state.agent) state.agent.abort(); if (state.pending) { state.pending([]); state.pending = null; } },
  answer: a => { if (state.pending) { state.pending(a); state.pending = null; } },
  reset: () => { state.agent = null; },
  reveal: f => { const p = new URL(f, "http://x").searchParams.get("p"); if (p) cp.spawn("open", ["-R", p]); },
};

function body(req) { return new Promise(r => { let b = ""; req.on("data", d => b += d); req.on("end", () => { try { r(JSON.parse(b || "{}")); } catch { r({}); } }); }); }

const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, "http://127.0.0.1");
  const guard = () => u.searchParams.get("k") === TOKEN || req.headers["x-token"] === TOKEN;
  try {
    if (u.pathname === "/" || u.pathname === "/index.html") {
      const html = fs.readFileSync(path.join(UI, "index.html"), "utf8").replace("<head>", `<head><script>window.STUDIO_TOKEN="${TOKEN}"</script>`);
      res.writeHead(200, { "content-type": "text/html" }); return res.end(html);
    }
    if (["/renderer.js", "/bridge-web.js"].includes(u.pathname)) { res.writeHead(200, { "content-type": "text/javascript" }); return res.end(fs.readFileSync(path.join(UI, u.pathname))); }
    if (!guard()) { res.writeHead(403); return res.end("forbidden"); }
    if (u.pathname === "/events") { res.writeHead(200, { "content-type": "text/event-stream", "cache-control": "no-cache" }); res.write(": ok\n\n"); state.clients.add(res); req.on("close", () => state.clients.delete(res)); return; }
    if (u.pathname === "/file") {
      const f = path.resolve(u.searchParams.get("p") || "");
      if (!(state.project && inside(f, state.project)) && !inside(f, skillRoot())) { res.writeHead(403); return res.end("outside project"); }
      if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end("not found"); }
      res.writeHead(200, { "content-type": MIME[path.extname(f).toLowerCase()] || "application/octet-stream" }); return fs.createReadStream(f).pipe(res);
    }
    const m = u.pathname.match(/^\/api\/(\w+)$/);
    if (req.method === "POST" && m && api[m[1]]) {
      const { arg } = await body(req); const out = await api[m[1]](arg);
      res.writeHead(200, { "content-type": "application/json" }); return res.end(JSON.stringify(out === undefined ? null : out));
    }
    res.writeHead(404); res.end("not found");
  } catch (e) { res.writeHead(500); res.end(String(e.message)); }
});
module.exports = { server, api, state, TOKEN };
if (require.main === module) {
  server.listen(0, "127.0.0.1", () => {
    const url = "http://127.0.0.1:" + server.address().port + "/";
    console.log("Showreel Studio: " + url + "  (Ctrl+C to stop)");
    if (!process.env.NO_OPEN) cp.spawn("open", [url]);
  });
}

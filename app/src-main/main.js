const { app, BrowserWindow, ipcMain, dialog, safeStorage, clipboard, shell } = require("electron");
const fs = require("fs"), path = require("path");
const Anthropic = require("@anthropic-ai/sdk");
const { Agent } = require("./agent");

let win, agent = null, pending = null;
const cfgFile = () => path.join(app.getPath("userData"), "config.json");
const readCfg = () => { try { return JSON.parse(fs.readFileSync(cfgFile(), "utf8")); } catch { return {}; } };
const writeCfg = c => fs.writeFileSync(cfgFile(), JSON.stringify(c));
function getKey() {
  const c = readCfg(); if (!c.key) return process.env.ANTHROPIC_API_KEY || "";
  try { return safeStorage.decryptString(Buffer.from(c.key, "base64")); } catch { return ""; }
}
const send = (ch, ...a) => win && !win.isDestroyed() && win.webContents.send(ch, ...a);

const ui = {
  text: t => send("agent:text", t), endText: () => send("agent:end"),
  tool: (n, i) => send("agent:tool", n, i),
  ask: qs => new Promise(res => { pending = res; send("agent:ask", qs); }),
  show: (f, title) => send("agent:show", "file://" + f, title),
};

function createWindow() {
  win = new BrowserWindow({ width: 1400, height: 900, title: "Showreel Studio",
    webPreferences: { preload: path.join(__dirname, "preload.js"), contextIsolation: true } });
  win.loadFile(path.join(__dirname, "..", "src-ui", "index.html"));
}
app.whenReady().then(createWindow);
app.on("window-all-closed", () => app.quit());

ipcMain.handle("cfg:get", () => ({ hasKey: !!getKey(), model: readCfg().model || "claude-sonnet-5-5", project: readCfg().project || "" }));
ipcMain.handle("cfg:setKey", (_, k) => { const c = readCfg(); c.key = safeStorage.encryptString(k).toString("base64"); writeCfg(c); return true; });
ipcMain.handle("cfg:setModel", (_, m) => { const c = readCfg(); c.model = m; writeCfg(c); return true; });
ipcMain.handle("project:pick", async () => {
  const r = await dialog.showOpenDialog(win, { properties: ["openDirectory", "createDirectory"] });
  if (r.canceled) return ""; const c = readCfg(); c.project = r.filePaths[0]; writeCfg(c); agent = null; return c.project;
});
ipcMain.handle("agent:send", async (_, text) => {
  const c = readCfg(), key = getKey();
  if (!key) return "Set your API key first.";
  if (!c.project) return "Choose a project folder first.";
  try {
    if (!agent) agent = new Agent({ client: new Anthropic({ apiKey: key }), model: c.model || "claude-sonnet-5-5", project: c.project, ui });
    await agent.send(text); return "";
  } catch (e) { return "Error: " + e.message; }
});
ipcMain.handle("agent:stop", () => { if (agent) agent.abort(); if (pending) { pending([]); pending = null; } });
ipcMain.handle("agent:answer", (_, a) => { if (pending) { pending(a); pending = null; } });
ipcMain.handle("agent:reset", () => { agent = null; });
ipcMain.handle("clipboard:read", () => clipboard.readText());
ipcMain.handle("open:external", (_, f) => shell.showItemInFolder(f.replace("file://", "")));

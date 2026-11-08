const { contextBridge, ipcRenderer } = require("electron");
const on = (ch, fn) => ipcRenderer.on(ch, (_, ...a) => fn(...a));
contextBridge.exposeInMainWorld("studio", {
  cfg: () => ipcRenderer.invoke("cfg:get"), setKey: k => ipcRenderer.invoke("cfg:setKey", k), setModel: m => ipcRenderer.invoke("cfg:setModel", m),
  pickProject: () => ipcRenderer.invoke("project:pick"),
  send: t => ipcRenderer.invoke("agent:send", t), stop: () => ipcRenderer.invoke("agent:stop"), reset: () => ipcRenderer.invoke("agent:reset"),
  answer: a => ipcRenderer.invoke("agent:answer", a), readClipboard: () => ipcRenderer.invoke("clipboard:read"),
  reveal: f => ipcRenderer.invoke("open:external", f),
  onText: f => on("agent:text", f), onEnd: f => on("agent:end", f), onTool: f => on("agent:tool", f),
  onAsk: f => on("agent:ask", f), onShow: f => on("agent:show", f),
});

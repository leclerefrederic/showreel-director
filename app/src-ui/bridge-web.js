// Browser mode: defines window.studio over HTTP when the Electron preload is absent.
if (!window.studio) {
  const T = window.STUDIO_TOKEN, post = (n, arg) => fetch("/api/" + n, { method: "POST", headers: { "x-token": T, "content-type": "application/json" }, body: JSON.stringify({ arg }) }).then(r => r.json());
  const es = new EventSource("/events?k=" + T), L = {};
  es.onmessage = m => { const { ev, args } = JSON.parse(m.data); (L[ev] || []).forEach(f => f(...args)); };
  const on = ev => f => (L[ev] = L[ev] || []).push(f);
  window.studio = {
    cfg: () => post("cfg"), setKey: k => post("setKey", k), setModel: m => post("setModel", m),
    pickProject: async () => { const p = prompt("Absolute path of the project folder (it must exist)"); return p ? post("pickProject", p) : ""; },
    send: t => post("send", t), stop: () => post("stop"), reset: () => post("reset"), answer: a => post("answer", a),
    readClipboard: () => navigator.clipboard.readText().catch(() => ""), reveal: f => post("reveal", f),
    onText: on("text"), onEnd: on("end"), onTool: on("tool"), onAsk: on("ask"), onShow: on("show"),
  };
}

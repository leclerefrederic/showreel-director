const $ = id => document.getElementById(id), log = $("log");
let cur = null, frame = null, curFile = "";
const add = (cls, t) => { const d = document.createElement("div"); d.className = "m " + cls; d.textContent = t; log.appendChild(d); log.scrollTop = 1e9; return d; };
studio.onText(t => { if (!cur) cur = add("", ""); cur.textContent += t; log.scrollTop = 1e9; });
studio.onEnd(() => { cur = null; });
studio.onTool((n, i) => add("t", "· " + n + (n === "bash" ? ": " + String(i.command).slice(0, 90) : i.path ? ": " + i.path : "")));
studio.onShow((f, title) => {
  curFile = f; $("pt").textContent = title; if ($("empty")) $("empty").remove();
  if (!frame) { frame = document.createElement("iframe"); frame.setAttribute("allow", "clipboard-write"); frame.setAttribute("sandbox", "allow-scripts allow-same-origin allow-forms allow-popups"); $("pv").appendChild(frame); }
  frame.src = f + (f.includes("?") ? "&" : "?") + "t=" + Date.now();
});
studio.onAsk(qs => {
  const card = document.createElement("div"); card.className = "card"; const sel = qs.map(() => new Set());
  qs.forEach((q, qi) => { const h = document.createElement("h4"); h.textContent = q.question; card.appendChild(h);
    q.options.forEach(o => { const b = document.createElement("button"); b.className = "opt"; b.innerHTML = "<b></b><small></small>"; b.firstChild.textContent = o.label; b.lastChild.textContent = o.description;
      b.onclick = () => { if (q.multiSelect) { sel[qi].has(o.label) ? sel[qi].delete(o.label) : sel[qi].add(o.label); b.classList.toggle("on"); } else { sel[qi] = new Set([o.label]); [...b.parentNode.querySelectorAll(".opt")].forEach(x => x.classList.toggle("on", x === b)); } };
      card.appendChild(b); }); });
  const ok = document.createElement("button"); ok.textContent = "Confirm"; ok.onclick = () => { studio.answer(sel.map(s => [...s].join(", "))); ok.disabled = true; card.style.opacity = .6; };
  card.appendChild(ok); log.appendChild(card); log.scrollTop = 1e9;
});
async function send() { const t = $("txt").value.trim(); if (!t) return; $("txt").value = ""; add("u", t); const e = await studio.send(t); if (e) add("t", e); }
$("go").onclick = send; $("txt").onkeydown = e => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) send(); };
$("stop").onclick = () => studio.stop(); $("new").onclick = async () => { await studio.reset(); log.innerHTML = ""; };
$("proj").onclick = async () => { const p = await studio.pickProject(); if (p) $("pn").textContent = p; };
$("key").onclick = async () => { const k = prompt("Anthropic API key (stored encrypted in the macOS keychain)"); if (k) { await studio.setKey(k.trim()); add("t", "API key saved."); } };
$("pick").onclick = async () => { const t = await studio.readClipboard(); if (t) { $("txt").value += (($("txt").value ? "\n" : "") + t); $("txt").focus(); } };
$("rev").onclick = () => curFile && studio.reveal(curFile);
studio.cfg().then(c => { $("pn").textContent = c.project || "no project folder"; if (!c.hasKey) add("t", "Set your API key (top bar) and choose a project folder to start."); });

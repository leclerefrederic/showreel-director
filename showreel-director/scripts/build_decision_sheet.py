#!/usr/bin/env python3
"""Build a one-file HTML decision sheet from a JSON spec: the user picks an option per item instead of reading a text
block and answering "OK?". Used for the brief review, the style sheet, structure options, cut-downs and the release gate.

Usage: python3 build_decision_sheet.py SPEC.json --out qa/decision-brief.html
         [--bg #111 --fg #f4f4f0 --accent #e6ff00 --accent2 #888 --font path/to/font.ttf --family "Name"] [--ui ui.json] [--lang fr]

Spec (JSON):
{ "title": "Brief review", "intro": "One line of context.",
  "items": [ { "id": "feeling", "title": "Intended feeling", "body": "Short text (a few lines at most).",
               "swatches": ["#0a7d78", "#ffffff"],            optional colour chips
               "sample": {"text": "Know where your money goes", "css": "font:700 28px system-ui"},   optional type specimen
               "multi": false,                                  true = several options can be ticked
               "options": [ {"label": "Keep", "recommended": true},
                            {"label": "Change", "needs_note": true},        needs_note: the note field must be filled
                            {"label": "Waive and accept the risk", "needs_note": true} ] } ] }
Page language: all page texts come from a UI table (English by default). Pass --ui FILE.json with the same keys translated into the
conversation language (keys: accept, copy, rec, several, noteReq, noteOpt, status, open, copied, header, missing) and --lang CODE for the page's lang attribute.
Guardrails built in: nothing is pre-selected (the recommended option is only highlighted); "Accept all recommended" is a
separate explicit button; "Copy decisions" refuses (and outlines the open cards) until every item is decided and every needs_note note is filled;
the copied text is a draft that the skill still confirms in the conversation. Text is never interpreted as HTML.
No look is assumed: pass the brand colours.
"""
import argparse, html, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _common as C

HEX = C.HEX

def check(spec):
    errs = []
    if not isinstance(spec, dict) or not isinstance(spec.get("items"), list) or not spec["items"]:
        return ["spec needs a non-empty \"items\" list"]
    seen = set()
    for n, it in enumerate(spec["items"], 1):
        iid = it.get("id")
        if not iid or not isinstance(iid, str): errs.append(f"item {n}: missing id"); continue
        if iid in seen: errs.append(f"item {n}: duplicate id {iid}")
        seen.add(iid)
        if not it.get("title"): errs.append(f"{iid}: missing title")
        opts = it.get("options")
        if not isinstance(opts, list) or len(opts) < 2: errs.append(f"{iid}: needs at least 2 options")
        elif len(opts) > (8 if it.get("multi") else 4): errs.append(f"{iid}: at most {8 if it.get('multi') else 4} options (4 for a single choice, 8 for a multi-select checklist)")
        else:
            if sum(1 for o in opts if o.get("recommended")) > 1 and not it.get("multi"): errs.append(f"{iid}: more than one recommended option")
            for o in opts:
                if not o.get("label"): errs.append(f"{iid}: an option has no label")
        for c in it.get("swatches", []):
            if not HEX.match(str(c)): errs.append(f"{iid}: bad colour {c!r}")
        if len(it.get("body", "")) > 600: errs.append(f"{iid}: body over 600 characters; move long content to a file and keep the card short")
    if len(spec["items"]) > 30: errs.append("more than 30 items; split the sheet")
    return errs

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("spec"); ap.add_argument("--out", default="qa/decision-sheet.html")
    C.add_brand_args(ap, "#111111", "#f4f4f0", "#e6ff00", "#8a8a84", "Reel Font")
    a = ap.parse_args()
    spec = json.load(open(a.spec, encoding="utf-8")); errs = check(spec)
    if errs: sys.exit("spec problems:\n  " + "\n  ".join(errs))
    C.require_colors(a.bg, a.fg, a.accent, a.accent2)
    face = C.font_face(a.family, *C.font_blob(a.font)[:2]) if a.font else ""
    page = C.fill(PAGE, [("__UI__", C.js_json(C.load_ui(UI, a.ui))), ("__LANG__", html.escape(a.lang)), ("__DATA__", C.js_json(spec)),
                         ("__TITLE__", html.escape(spec.get("title", "Decisions"))), ("__BG__", a.bg), ("__FG__", a.fg), ("__ACC__", a.accent), ("__ACC2__", a.accent2),
                         ("__FACE__", face), ("__FAMILY__", a.family.replace('"', ""))])
    C.write_text(a.out, page)
    print(f"wrote {a.out}: {len(spec['items'])} items")

UI = {"accept": "Accept all recommended", "copy": "Copy decisions", "rec": "(recommended)", "several": "Several can be ticked.", "noteReq": "Required: say what, or why",
      "noteOpt": "Optional note", "status": "{n} of {total} decided", "open": "Open items are outlined when you try to copy.", "copied": "Copied. Paste it in the chat.",
      "header": "{title} - decisions (draft, please confirm in chat):", "missing": "Decide every item first (a required note counts)."}

PAGE = r"""<!DOCTYPE html><html lang="__LANG__"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__TITLE__</title>
<style>__FACE__
:root{--bg:__BG__;--fg:__FG__;--acc:__ACC__;--mute:__ACC2__}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.45 "__FAMILY__",system-ui,sans-serif}
header{position:sticky;top:0;z-index:2;background:var(--bg);border-bottom:1px solid #ffffff22;padding:12px 20px;display:flex;gap:14px;align-items:center;flex-wrap:wrap}
h1{font-size:18px;margin:0}#st{color:var(--mute);font-size:13px;flex:1}
button{font:inherit;border:1px solid #ffffff44;background:transparent;color:var(--fg);border-radius:6px;padding:7px 12px;cursor:pointer}
button.on{background:var(--acc);color:var(--bg);border-color:var(--acc)}button.rec{border-style:dashed;border-color:var(--acc)}
button.p{background:var(--acc);color:var(--bg);border-color:var(--acc);font-weight:700}
#intro{padding:12px 20px 0;color:var(--mute)}
main{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:16px;padding:20px}
.card{border:1px solid #ffffff33;border-radius:10px;padding:14px;display:flex;flex-direction:column;gap:8px}.card.done{border-color:var(--acc)}.card.miss{border-color:#ff6b6b}
.t{font-weight:700;font-size:17px}.b{color:var(--fg);opacity:.9;white-space:pre-wrap}.hint{font-size:12px;color:var(--mute)}
.sw{display:flex;gap:6px;flex-wrap:wrap}.chip{width:44px;height:44px;border-radius:8px;border:1px solid #ffffff44;display:flex;align-items:flex-end;justify-content:center;font-size:9px}
.row{display:flex;gap:6px;flex-wrap:wrap}textarea{width:100%;min-height:54px;background:#ffffff0d;color:var(--fg);border:1px solid #ffffff33;border-radius:6px;padding:8px;font:inherit}
#out{position:fixed;bottom:12px;right:12px;background:var(--bg);border:1px solid var(--acc);border-radius:8px;padding:8px 12px;display:none}
</style></head><body><header><h1>__TITLE__</h1><span id="st"></span><button id="rec"></button><button class="p" id="copy"></button></header>
<div id="intro"></div><main id="m"></main><div id="out"></div>
<script>
const D=__DATA__,U=__UI__,pick={},note={};const m=document.getElementById('m');
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
document.getElementById('intro').textContent=D.intro||'';document.getElementById('rec').textContent=U.accept;document.getElementById('copy').textContent=U.copy;
const sel=id=>pick[id]||[];
function lab(h){let x=String(h).replace('#','');if(x.length===3)x=x.split('').map(c=>c+c).join('');const r=parseInt(x.slice(0,2),16),g=parseInt(x.slice(2,4),16),b=parseInt(x.slice(4,6),16);return (0.299*r+0.587*g+0.114*b)>150?'#111':'#fff'}
const needNote=it=>sel(it.id).some(i=>it.options[i].needs_note);
const decided=it=>sel(it.id).length>0;
const complete=it=>decided(it)&&(!needNote(it)||(note[it.id]||'').trim().length>0);
function draw(){m.innerHTML='';D.items.forEach(it=>{const c=document.createElement('div');c.className='card '+(complete(it)?'done':'');c.dataset.id=it.id;
let h='<div class="t">'+esc(it.title)+'</div>';if(it.body)h+='<div class="b">'+esc(it.body)+'</div>';
if(it.swatches&&it.swatches.length)h+='<div class="sw">'+it.swatches.map(x=>'<div class="chip" style="background:'+esc(x)+';color:'+lab(x)+'">'+esc(x)+'</div>').join('')+'</div>';
if(it.sample&&it.sample.text)h+='<div style="'+esc(it.sample.css||'')+'">'+esc(it.sample.text)+'</div>';
h+='<div class="row">'+it.options.map((o,i)=>'<button data-i="'+i+'" class="'+(sel(it.id).includes(i)?'on':(o.recommended?'rec':''))+'">'+esc(o.label)+(o.recommended?' '+U.rec:'')+'</button>').join('')+'</div>';
if(it.multi)h+='<div class="hint">'+esc(U.several)+'</div>';
if(needNote(it)||it.note)h+='<textarea data-n="'+esc(it.id)+'" placeholder="'+esc(needNote(it)?U.noteReq:U.noteOpt)+'">'+esc(note[it.id]||'')+'</textarea>';
c.innerHTML=h;m.appendChild(c)});
document.querySelectorAll('button[data-i]').forEach(b=>b.onclick=()=>{const id=b.closest('.card').dataset.id,it=D.items.find(x=>x.id===id),i=+b.dataset.i,cur=sel(id);
 if(it.multi)pick[id]=cur.includes(i)?cur.filter(x=>x!==i):cur.concat(i);else pick[id]=cur[0]===i?[]:[i];const ta=document.querySelector('textarea[data-n="'+id+'"]');draw();});
document.querySelectorAll('textarea').forEach(t=>t.oninput=()=>{note[t.dataset.n]=t.value;status()});
status()}
function status(){const n=D.items.filter(complete).length;document.getElementById('st').textContent=U.status.replace('{n}',n).replace('{total}',D.items.length)+(n<D.items.length?' - '+U.open:'')}
document.getElementById('rec').onclick=()=>{D.items.forEach(it=>{if(!decided(it)){const r=it.options.map((o,i)=>o.recommended?i:-1).filter(i=>i>=0);if(r.length&&!r.some(i=>it.options[i].needs_note))pick[it.id]=it.multi?r:[r[0]]}});draw()};
document.getElementById('copy').onclick=()=>{const o=document.getElementById('out'),miss=D.items.filter(x=>!complete(x));if(miss.length){document.querySelectorAll('.card').forEach(c=>{if(miss.some(x=>x.id===c.dataset.id))c.classList.add('miss')});o.textContent=U.missing;o.style.display='block';setTimeout(()=>o.style.display='none',3000);return}
const t=U.header.replace('{title}',D.title)+'\n'+D.items.map(it=>it.id+' ('+it.title+'): '+sel(it.id).map(i=>it.options[i].label).join(' + ')+((note[it.id]||'').trim()?' - '+note[it.id].trim().replace(/\n/g,' '):'')).join('\n');
(navigator.clipboard?navigator.clipboard.writeText(t):Promise.reject()).catch(()=>{const a=document.createElement('textarea');a.value=t;document.body.appendChild(a);a.select();try{document.execCommand('copy')}catch(e){}a.remove()});
o.textContent=U.copied;o.style.display='block';setTimeout(()=>o.style.display='none',2500)};
draw();
</script></body></html>
"""

if __name__ == "__main__":
    main()

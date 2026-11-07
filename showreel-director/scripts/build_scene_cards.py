#!/usr/bin/env python3
"""Turn storyboard.md into a visual sheet of scene cards for the scene-by-scene review.

Usage: python3 build_scene_cards.py STORYBOARD.md --out qa/cards-scenes.html [--title "Reel name"]
         [--bg #111 --fg #f4f4f0 --accent #e6ff00 --accent2 #888 --font path/to/font.ttf --family "Name"]
Reads the first Markdown table of the storyboard (one row per scene). Columns are matched by name: an ID column
("#", "ID", "Scene"), a time column ("Time"), a text column ("text"), "image"/"motion", "feeling"/"tension",
"gag"/"handoff"; any other column is shown as a labelled line. The page is one self-contained HTML file with, per
scene, OK / MODIFY / DITCH buttons (MODIFY opens a note field), "OK for all remaining", running totals (kept,
ditched, time left when times are numeric) and a "Copy decisions" button that puts the result on the clipboard
so the user can paste it in the chat. The decisions are only a draft: the skill still confirms every MODIFY and
DITCH in the conversation (see references/scene-review.md). No palette or look is assumed: pass the brand colours.
"""
import argparse, base64, html, json, os, re, sys

def split_row(line):
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    return cells

def parse_table(text):
    lines = text.splitlines(); i = 0
    while i < len(lines) - 1:
        if lines[i].lstrip().startswith("|") and re.match(r"^\s*\|?\s*:?-{2,}", lines[i + 1].replace("|", "", 1) if lines[i + 1].lstrip().startswith("|") else ""):
            head = split_row(lines[i]); rows = []; j = i + 2
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                r = split_row(lines[j]); r += [""] * (len(head) - len(r)); rows.append(dict(zip(head, r[:len(head)]))); j += 1
            return head, rows
        i += 1
    return [], []

def clean(s):
    return re.sub(r"\*\*(.+?)\*\*", r"\1", s).replace("<br>", " / ")

def find(head, *keys):
    for h in head:
        if any(k in h.lower() for k in keys): return h
    return None

def seconds(s):
    m = re.search(r"(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)", s or "")
    return (float(m.group(2)) - float(m.group(1))) if m else None

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("storyboard"); ap.add_argument("--out", default="qa/cards-scenes.html"); ap.add_argument("--title", default="Storyboard")
    ap.add_argument("--bg", default="#111111"); ap.add_argument("--fg", default="#f4f4f0"); ap.add_argument("--accent", default="#e6ff00"); ap.add_argument("--accent2", default="#8a8a84")
    ap.add_argument("--font"); ap.add_argument("--family", default="Reel Font")
    a = ap.parse_args()
    head, rows = parse_table(open(a.storyboard, encoding="utf-8").read())
    if not rows: sys.exit("no Markdown table found in " + a.storyboard)
    cid = find(head, "id", "#", "scene") or head[0]; ctime = find(head, "time"); ctext = find(head, "text"); cimg = find(head, "image", "motion")
    cfeel = find(head, "feeling", "tension"); cgag = find(head, "gag", "handoff", "jeu")
    used = {cid, ctime, ctext, cimg, cfeel, cgag}; extra = [h for h in head if h not in used]
    scenes = []
    for k, r in enumerate(rows):
        sid = clean(r.get(cid, "")).strip() or str(k + 1)
        sid = sid if re.match(r"^S\d+", sid) else "S%02d" % (int(sid) if sid.isdigit() else k + 1)
        scenes.append({"id": sid, "time": clean(r.get(ctime, "")) if ctime else "", "dur": seconds(r.get(ctime, "")) if ctime else None,
                       "text": clean(r.get(ctext, "")) if ctext else "", "image": clean(r.get(cimg, "")) if cimg else "",
                       "feel": clean(r.get(cfeel, "")) if cfeel else "", "gag": clean(r.get(cgag, "")) if cgag else "",
                       "extra": [(h, clean(r.get(h, ""))) for h in extra if r.get(h, "").strip()]})
    face = ""
    if a.font:
        mime = "font/woff2" if a.font.lower().endswith(".woff2") else "font/woff" if a.font.lower().endswith(".woff") else "font/ttf"
        face = '@font-face{font-family:"%s";src:url(data:%s;base64,%s)}' % (a.family, mime, base64.b64encode(open(a.font, "rb").read()).decode())
    total = sum(s["dur"] or 0 for s in scenes)
    page = PAGE.replace("__DATA__", json.dumps({"scenes": scenes, "total": round(total, 1), "title": a.title}, ensure_ascii=False).replace("</", "<\\/")) \
               .replace("__TITLE__", html.escape(a.title)).replace("__BG__", a.bg).replace("__FG__", a.fg).replace("__ACC__", a.accent).replace("__ACC2__", a.accent2) \
               .replace("__FACE__", face).replace("__FAMILY__", a.family.replace('"', ''))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "w", encoding="utf-8").write(page)
    print(f"wrote {a.out}: {len(scenes)} scene cards, {total:.1f} s of timed scenes")

PAGE = r"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__TITLE__ - scene cards</title>
<style>__FACE__
:root{--bg:__BG__;--fg:__FG__;--acc:__ACC__;--mute:__ACC2__}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.45 "__FAMILY__",system-ui,sans-serif}
header{position:sticky;top:0;z-index:2;background:var(--bg);border-bottom:1px solid #ffffff22;padding:12px 20px;display:flex;gap:16px;align-items:center;flex-wrap:wrap}
h1{font-size:18px;margin:0}#tot{color:var(--mute);font-size:13px;flex:1}
button{font:inherit;border:1px solid #ffffff44;background:transparent;color:var(--fg);border-radius:6px;padding:7px 12px;cursor:pointer}
button.on{background:var(--acc);color:var(--bg);border-color:var(--acc)}button.p{background:var(--acc);color:var(--bg);border-color:var(--acc);font-weight:700}
main{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:16px;padding:20px}
.card{border:1px solid #ffffff33;border-radius:10px;padding:14px;display:flex;flex-direction:column;gap:8px}
.card.OK{border-color:var(--acc)}.card.DITCH{opacity:.45}.card.MODIFY{border-color:#ffb020}
.top{display:flex;justify-content:space-between;align-items:baseline}.id{font-weight:800;font-size:22px;color:var(--acc)}.tm{color:var(--mute);font-size:13px}
.txt{font-size:19px;font-weight:700}.l{font-size:12px;color:var(--mute);text-transform:uppercase;letter-spacing:.05em}
.row{display:flex;gap:6px;margin-top:4px;flex-wrap:wrap}textarea{width:100%;min-height:54px;background:#ffffff0d;color:var(--fg);border:1px solid #ffffff33;border-radius:6px;padding:8px;font:inherit}
#tl{display:flex;gap:2px;padding:10px 20px 0;height:34px}#tl div{background:#ffffff22;border-radius:4px;min-width:6px;cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:10px;overflow:hidden;color:var(--fg)}
#tl div.OK{background:var(--acc);color:var(--bg)}#tl div.MODIFY{background:#ffb020;color:#111}#tl div.DITCH{background:#ffffff11;text-decoration:line-through}
.warn{font-size:12px;color:#ffb020}#out{position:fixed;bottom:12px;right:12px;background:var(--bg);border:1px solid var(--acc);border-radius:8px;padding:8px 12px;display:none}
</style></head><body><header><h1>__TITLE__</h1><span id="tot"></span><button id="allok">OK for all remaining</button><button class="p" id="copy">Copy decisions</button></header>
<div id="tl"></div><main id="m"></main><div id="out">Copied. Paste it in the chat.</div>
<script>
const D=__DATA__,st={},note={};const m=document.getElementById('m');
const esc=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
function draw(){m.innerHTML='';D.scenes.forEach(s=>{const c=document.createElement('div');c.className='card '+(st[s.id]||'');
let h='<div class="top"><span class="id">'+esc(s.id)+'</span><span class="tm">'+esc(s.time)+'</span></div>';
if(s.text)h+='<div class="txt">'+esc(s.text)+'</div>';
const rd=s.dur&&s.text?s.text.length/s.dur:0;if(rd>17)h+='<div class="warn">Reading: '+rd.toFixed(0)+' characters per second on screen (comfortable is about 15 to 17). Shorten the text or give the scene more time.</div>';
const L=(k,v)=>v?'<div><span class="l">'+k+'</span><br>'+esc(v)+'</div>':'';
h+=L('Image and motion',s.image)+L('Feeling and tension',s.feel)+L('Gag / handoff',s.gag)+s.extra.map(e=>L(e[0],e[1])).join('');
h+='<div class="row">'+['OK','MODIFY','DITCH'].map(k=>'<button data-s="'+s.id+'" data-k="'+k+'" class="'+(st[s.id]===k?'on':'')+'">'+k+'</button>').join('')+'</div>';
if(st[s.id]==='MODIFY')h+='<textarea data-n="'+s.id+'" placeholder="What should change?">'+esc(note[s.id]||'')+'</textarea>';
c.innerHTML=h;m.appendChild(c)});
c=document.querySelectorAll('button[data-k]');c.forEach(b=>b.onclick=()=>{st[b.dataset.s]=st[b.dataset.s]===b.dataset.k?'':b.dataset.k;draw()});
document.querySelectorAll('textarea').forEach(t=>t.oninput=()=>{note[t.dataset.n]=t.value});
const tl=document.getElementById('tl');tl.innerHTML='';const tot=D.scenes.reduce((a,s)=>a+(s.dur||1),0);D.scenes.forEach((s,i)=>{const d=document.createElement('div');d.className=st[s.id]||'';d.style.flex=String((s.dur||1)/tot*1000);d.textContent=s.id;d.title=s.id+(s.time?' '+s.time:'');d.onclick=()=>document.querySelectorAll('.card')[i].scrollIntoView({behavior:'smooth',block:'center'});tl.appendChild(d)});
const n=k=>D.scenes.filter(s=>st[s.id]===k).length,left=D.total-D.scenes.filter(s=>st[s.id]==='DITCH').reduce((a,s)=>a+(s.dur||0),0);
document.getElementById('tot').textContent=D.scenes.length+' scenes: '+n('OK')+' OK, '+n('MODIFY')+' to modify, '+n('DITCH')+' ditched, '+(D.scenes.length-n('OK')-n('MODIFY')-n('DITCH'))+' undecided'+(D.total?' - '+left.toFixed(1)+' s of '+D.total+' s left':'')}
document.getElementById('allok').onclick=()=>{D.scenes.forEach(s=>{if(!st[s.id])st[s.id]='OK'});draw()};
document.getElementById('copy').onclick=()=>{const bad=D.scenes.filter(s=>st[s.id]==='MODIFY'&&!(note[s.id]||'').trim());if(bad.length){const o=document.getElementById('out');o.textContent='Say what to change for: '+bad.map(s=>s.id).join(', ');o.style.display='block';setTimeout(()=>{o.style.display='none';o.textContent='Copied. Paste it in the chat.'},3500);return}
const t='Scene decisions (draft, please confirm in chat):\n'+D.scenes.map(s=>s.id+': '+(st[s.id]||'undecided')+(st[s.id]==='MODIFY'&&note[s.id]?' - '+note[s.id].replace(/\n/g,' '):'')).join('\n');
(navigator.clipboard?navigator.clipboard.writeText(t):Promise.reject()).catch(()=>{const a=document.createElement('textarea');a.value=t;document.body.appendChild(a);a.select();try{document.execCommand('copy')}catch(e){}a.remove()});
const o=document.getElementById('out');o.style.display='block';setTimeout(()=>o.style.display='none',2500)};
draw();
</script></body></html>
"""

if __name__ == "__main__":
    main()

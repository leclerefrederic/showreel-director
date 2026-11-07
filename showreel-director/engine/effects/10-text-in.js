/* ---------- TEXT IN ---------- */
const C1='Text in';
fx(C1,'Fade','Opacity rises, nothing else moves.','low',1.2,(g,p,c)=>{bg(g,c);T(g,S1(c),W/2,H/2,SZ,c.P.fg,{a:e.io3(p)})});
fx(C1,'Rise','Slides up a few pixels while fading in.','low',1.2,(g,p,c)=>{bg(g,c);const k=e.out3(p);T(g,S1(c),W/2,H/2+(1-k)*26,SZ,c.P.fg,{a:k})});
fx(C1,'Fly in','Slides in from the side with easing.','mid',1.1,(g,p,c)=>{bg(g,c);const k=e.expo(p);T(g,S1(c),W/2-(1-k)*W*.7,H/2,SZ,c.P.fg)});
fx(C1,'Drop','Falls from above with a small settle.','mid',1.3,(g,p,c)=>{bg(g,c);const k=e.bounce(p);T(g,S1(c),W/2,H/2-(1-k)*H*.8,SZ,c.P.fg,{a:clamp(p*6)})});
fx(C1,'Pop','Scales up from nothing with a slight overshoot.','mid',1,(g,p,c)=>{bg(g,c);const k=Math.max(0,e.back(p));T(g,S1(c),W/2,H/2,SZ,c.P.fg,{s:k,a:clamp(p*4)})});
fx(C1,'Zoom','Starts oversized and settles to size.','high',1,(g,p,c)=>{bg(g,c);const k=e.expo(p);T(g,S1(c),W/2,H/2,SZ,c.P.fg,{s:lerp(2.6,1,k),a:clamp(p*3)})});
fx(C1,'Slam','Lands oversized with a short shake.','high',1.1,(g,p,c)=>{bg(g,c);const k=e.expo(clamp(p/.35));const sh=p>.3?Math.sin(p*90)*8*Math.exp(-(p-.3)*9):0;T(g,S1(c),W/2+sh,H/2,SZ,c.P.accent,{s:lerp(3.4,1,k),a:clamp(p*8)})});
fx(C1,'Typewriter','Letters appear one by one with a caret.','mid',1.8,(g,p,c)=>{bg(g,c);const s=S1(c),n=Math.floor(s.length*clamp(p/.85));g.save();setFont(g,SZ);const wf=g.measureText(s).width,ws=g.measureText(s.slice(0,n)).width;g.restore();T(g,s.slice(0,n),W/2-wf/2,H/2,SZ,c.P.fg,{al:'left'});if(Math.floor(p*14)%2===0){g.fillStyle=c.P.accent;g.fillRect(W/2-wf/2+ws+4,H/2-SZ*.45,4,SZ*.9)}});
fx(C1,'Letter stagger','Each letter rises a beat after the previous one.','mid',1.5,(g,p,c)=>{bg(g,c);letters(g,S1(c),W/2,H/2,SZ,c.P.fg,(i,n)=>{const k=e.out3(clamp((p*1.5-i*.05)/.5));return{dy:(1-k)*30,a:k}})});
fx(C1,'Word stagger','Words arrive one after another.','mid',1.6,(g,p,c)=>{bg(g,c);const ws=S1(c).split(' ');ws.forEach((w,i)=>{const k=e.out3(clamp((p*1.6-i*.4)/.5));T(g,w,W/2,H/2+(i-(ws.length-1)/2)*SZ*1.1+(1-k)*20,SZ,i%2?c.P.accent:c.P.fg,{a:k})})});
fx(C1,'Mask wipe','A moving edge reveals the text.','low',1.3,(g,p,c)=>{bg(g,c);g.save();g.beginPath();g.rect(0,0,W*e.io3(p),H);g.clip();T(g,S1(c),W/2,H/2,SZ,c.P.fg);g.restore()});
fx(C1,'Scramble decode','Random glyphs resolve into the text.','mid',1.6,(g,p,c)=>{bg(g,c);const s=S1(c),G='#%&@$*+=?';const o=[...s].map((ch,i)=>ch===' '||p*1.3>i/s.length+.2?ch:G[Math.floor(hs(i,Math.floor(p*30))*G.length)]).join('');T(g,o,W/2,H/2,SZ,c.P.fg)});
fx(C1,'Blur in','From blurred to sharp.','low',1.3,(g,p,c)=>{bg(g,c);g.save();try{g.filter=`blur(${(1-e.out3(p))*14}px)`}catch(x){}T(g,S1(c),W/2,H/2,SZ,c.P.fg,{a:.2+.8*e.out3(p)});g.restore()});
fx(C1,'Elastic','Springs past its place and back.','mid',1.4,(g,p,c)=>{bg(g,c);T(g,S1(c),W/2,H/2,SZ,c.P.fg,{s:Math.max(0,e.elastic(p)),a:clamp(p*5)})});

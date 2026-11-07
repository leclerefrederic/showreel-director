/* ---------- TEXT OUT ---------- */
const C2='Text out';
fx(C2,'Fade out','Opacity falls away.','low',1.2,(g,p,c)=>{bg(g,c);T(g,S1(c),W/2,H/2,SZ,c.P.fg,{a:1-e.io3(clamp((p-.2)/.8))})});
fx(C2,'Wind exit','Letters are blown away left to right.','mid',1.5,(g,p,c)=>{bg(g,c);letters(g,S1(c),W/2,H/2,SZ,c.P.fg,(i,n)=>{const k=clamp((p*1.4-.2-i*.03)/.5);return{dx:e.in3(k)*W*.6,dy:-e.in3(k)*30,a:1-k,rot:k*1.2}})});
fx(C2,'Drop out','Falls off the bottom of the frame.','mid',1.2,(g,p,c)=>{bg(g,c);const k=e.in3(clamp((p-.25)/.75));T(g,S1(c),W/2,H/2+k*H,SZ,c.P.fg,{rot:k*.3})});
fx(C2,'Slide out','Leaves the way it came in.','mid',1.1,(g,p,c)=>{bg(g,c);const k=e.in3(clamp((p-.25)/.75));T(g,S1(c),W/2-k*W*.8,H/2,SZ,c.P.fg)});
fx(C2,'Shrink to corner','Becomes a small persistent title.','low',1.3,(g,p,c)=>{bg(g,c);const k=e.io3(clamp((p-.2)/.8));T(g,S1(c),lerp(W/2,28,k),lerp(H/2,28,k),lerp(SZ,18,k),c.P.fg,{al:k>.5?'left':'center'})});
fx(C2,'Strike and replace','Crossed out, then the new word lands.','mid',1.8,(g,p,c)=>{bg(g,c);const w=c.w1;g.save();setFont(g,SZ);const wd=g.measureText(w).width;g.restore();T(g,w,W/2,H/2-26,SZ,c.P.fg,{a:p<.6?1:.35});g.fillStyle=c.P.accent;g.fillRect(W/2-wd/2,H/2-26,wd*clamp(p/.3),5);const k=e.back(clamp((p-.55)/.4));T(g,c.w2,W/2,H/2+30,SZ,c.P.accent,{s:Math.max(0,k),a:clamp((p-.55)*6)})});
fx(C2,'Shatter','Breaks into pieces that fly apart.','high',1.3,(g,p,c)=>{bg(g,c);const k=e.in3(clamp((p-.25)/.75));letters(g,S1(c),W/2,H/2,SZ,c.P.fg,(i,n)=>({dx:(hs(i,1)-.5)*500*k,dy:(hs(i,2)-.3)*400*k,rot:(hs(i,3)-.5)*8*k,a:1-k}))});

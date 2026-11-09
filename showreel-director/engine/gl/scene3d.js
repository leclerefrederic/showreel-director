/* SR3D: the optional 3D layer of the engine (window.SR3D). Loaded after core.js and kit.js, only when main.js or a scene names SR3D; the Three.js bundle
   (engine/gl/three-bundle.js, window.T3) travels in its own script. It carries NO look: colours, sizes, wording and motion always come from the scene.

   A 3D scene is a normal scene file. It builds its stage ONCE (the body of the scene file runs once at load), then each frame it sets everything from time and draws:

     const st = SR3D.stage({ w: 1600, h: 900, focal: 2544, bg: '#000000', bloom: { strength: .3, radius: .4, threshold: .9 }, grade: { tone: 1.2, vignette: .6, grain: .04 } });
     const dust = SR3D.particles(st, { count: 6000, seed: 7, colors: ['#ffffff', '#ffd9a0'] });
     const orb  = SR3D.orb(st, { colors: ['#ff9d2e', '#fff1c4'] });
     return function render(g, lt, c) {
       st.fit(c); st.look(0, 0, 1);                        // stage size from the format, camera position and zoom
       dust.set(lt, { amt: SR.clamp(lt / 4) }, c);         // pure functions of lt: seek, pause and loop stay exact
       orb.set(lt, { x: 0, y: 0, z: 0, radius: 120, k: 1 }, c);
       st.draw(g, lt, { veil: 1 - SR.clamp(lt / .6) });    // renders in WebGL, then blits onto the 2D stage; draw 2D text and shapes after it
     };

   Everything is a pure function of its arguments (time in, pixels out). Without WebGL (a Node harness, an old browser, a lost context) st.ok is false: every call is a
   no-op, nothing throws, and SR3D.skipped counts the frames that were not drawn so a host can say so (the harness prints it). GLSL is linted even then (SR3D.lint).
   Reduced motion: pass the scene context (c) to set(): particles stop orbiting and twinkling, and a scene decides for flashes and veils.

   SR3D.stage(o)        -> {ok, canvas, THREE, scene, camera, renderer, composer, w, h, fit(c), resize(w, h), look(x, y, zoom), render(t, o), blit(g, x, y, w, h), draw(g, t, o), dispose()}
                           o: {w, h, focal (stage px of one world unit at distance 1), near, far, bg, scale (pixel scale, default 1), samples (MSAA, default 4, 0 on WebGL1),
                               bloom: {strength, radius, threshold} | null, grade: {tone, vignette, grain} | false}
                           render/draw options o: {flash (0..1, additive), veil (0..1, to black), bars (fraction of the height, top and bottom), grainTime}
   SR3D.particles(st, o)-> {points, data, set(t, s, c)}   a Points field whose state is computed in the vertex shader from time and uniforms (no stored state)
                           o: {count, seed, camZ, spread:[sx, sy], cy, z:[near, far], size:[min, max], big:{share, size:[min, max], alpha:[min, max]}, alpha:[min, max], warmShare,
                               colors:[a, b], px, ref, radius}
                           s: {amt (1 at rest, below 1 the field is pulled toward the target, above 1 it is thrown out), orbit (rad/s), twinkle (0..1), alpha, size, target:[x, y]}
   SR3D.orb(st, o)      -> {mesh, set(t, s)}      emissive sphere with moving noise; o: {colors:[a, b], limb (0..1), scale, segments}; s: {x, y, z, radius, k, spin, seed}
   SR3D.glow(st, o)     -> {mesh, set(t, s)}      camera-facing soft disc or ring; o: {mode:'disc'|'ring', color}; s: {x, y, z, size, k}
   SR3D.material(st, o) -> a Three.ShaderMaterial (additive by default) from {vertex, fragment, uniforms, additive, depthTest, depthWrite}; linted, throws on a GLSL rule break
   SR3D.glsl            -> {noise, billboardVS, ...}  chunks to include in your own shaders (hash, vn, fbm, h3, vn3, fbm3)
   SR3D.lint(src)       -> list of problems in a GLSL source: a // comment (it swallows the rest of the line when the source is flattened to one line, a failure that compiles without error),
                           an unclosed block comment, unbalanced braces or parentheses
   SR3D.rng(seed), SR3D.particleData(o), SR3D.fov(h, focal) are exposed for tests. */
(function (G) {
  'use strict';
  const SR = G.SR, clamp = SR.clamp;
  const S = { skipped: 0, avail: null };

  const rng = seed => { let a = seed | 0; return () => { a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; };
  const fov = (h, focal) => 2 * Math.atan((h / 2) / focal) * 180 / Math.PI;

  // ---- GLSL: shared chunks and the lint ----
  const NOISE = [
    'float hash(float n){return fract(sin(n*127.1)*43758.5453);}',
    'float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}',
    'float vn(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);}',
    'float fbm(vec2 p){float a=.5,s=0.;for(int i=0;i<4;i++){s+=a*vn(p);p*=2.03;a*=.5;}return s;}',
    'float h3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}',
    'float vn3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);',
    'return mix(mix(mix(h3(i),h3(i+vec3(1,0,0)),f.x),mix(h3(i+vec3(0,1,0)),h3(i+vec3(1,1,0)),f.x),f.y),',
    'mix(mix(h3(i+vec3(0,0,1)),h3(i+vec3(1,0,1)),f.x),mix(h3(i+vec3(0,1,1)),h3(i+vec3(1,1,1)),f.x),f.y),f.z);}',
    'float fbm3(vec3 p){float a=.5,s=0.;for(int i=0;i<4;i++){s+=a*vn3(p);p*=2.03;a*=.5;}return s;}'
  ].join('\n');
  const BILLBOARD_VS = 'varying vec2 vUv;uniform vec2 uSize;void main(){vUv=uv;vec4 mv=modelViewMatrix*vec4(0.,0.,0.,1.);mv.xy+=position.xy*uSize;gl_Position=projectionMatrix*mv;}';
  const GLOW_FS = 'precision highp float;varying vec2 vUv;uniform vec3 uC;uniform float uK,uMode;\n' +
    'void main(){vec2 p=(vUv-.5)*2.;float r=length(p);float v;if(uMode<.5)v=exp(-r*r*4.5);else v=exp(-pow((r-.72)*5.5,2.))*.55+exp(-r*r*3.)*.18;v*=smoothstep(1.,.85,r);gl_FragColor=vec4(uC*v*uK,1.);}';
  const ORB_VS = 'varying vec3 vO;varying vec3 vN;varying vec3 vV;void main(){vO=position;vec4 mv=modelViewMatrix*vec4(position,1.);vN=normalize(normalMatrix*normal);vV=normalize(-mv.xyz);gl_Position=projectionMatrix*mv;}';
  const ORB_FS = 'precision highp float;varying vec3 vO;varying vec3 vN;varying vec3 vV;uniform vec3 uC1,uC2;uniform float uT,uK,uSeed,uSpin,uLimb,uScale;\n' + NOISE + '\n' +
    'void main(){float mu=clamp(dot(normalize(vN),normalize(vV)),0.,1.);float ca=cos(uSpin),sa=sin(uSpin);vec3 p=vec3(ca*vO.x+sa*vO.z,vO.y,-sa*vO.x+ca*vO.z);\n' +
    'float gr=fbm3(p*uScale+uSeed*9.+vec3(0.,0.,uT*.05))*.6+fbm3(p*uScale*2.4)*.4;float limb=mix(1.,pow(mu,.6),uLimb);float a=pow(smoothstep(0.,.95,mu),1.8);\n' +
    'gl_FragColor=vec4(mix(uC2,uC1,gr)*limb*uK*a,1.);}';
  const PTS_VS = 'attribute vec3 aux;attribute float warm;uniform float uT,uAmt,uOrbit,uPx,uAlpha,uTwinkle,uRadius,uRef,uSize;uniform vec2 uTarget;varying float vA;varying float vW;\n' +
    'void main(){vec3 pp=position;float oa=uT*uOrbit*(.55+.45*sin(aux.y*2.3));float co=cos(oa),so=sin(oa);pp.xy=vec2(co*pp.x-so*pp.y,so*pp.x+co*pp.y);\n' +
    'vec2 rel=pp.xy-uTarget;float r0=length(rel);vec2 dr=r0>.001?rel/r0:vec2(1.,0.);float pull=1.-clamp(uAmt,0.,1.);float an=pull*1.5*(.6+.4*sin(aux.y*3.));\n' +
    'dr=vec2(dr.x*cos(an)-dr.y*sin(an),dr.x*sin(an)+dr.y*cos(an));pp.xy=uTarget+dr*mix(uRadius+aux.y*14.,r0,uAmt);\n' +
    'vec4 mv=modelViewMatrix*vec4(pp,1.);float dist=-mv.z;float tw=1.-uTwinkle+uTwinkle*(.5+.5*sin(uT*1.5+aux.y));\n' +
    'vA=clamp(aux.z*tw*uAlpha*clamp(pow(uRef/dist,.25),.7,1.5)*(1.+1.6*pull),0.,1.);vW=warm;\n' +
    'gl_PointSize=aux.x*uSize*uPx*clamp(pow(uRef*.78/dist,.3),.6,1.7)*(1.+1.2*pull+.5*min(max(uAmt-1.,0.),3.));gl_Position=projectionMatrix*mv;}';
  const PTS_FS = 'precision highp float;varying float vA;varying float vW;uniform vec3 uC1,uC2;void main(){float r=length(gl_PointCoord-.5)*2.;float v=smoothstep(1.,.2,r);gl_FragColor=vec4(mix(uC1,uC2,vW)*v*vA,1.);}';
  const GRADE_VS = 'varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position.xy,0.,1.);}';
  const GRADE_FS = 'precision highp float;uniform sampler2D tDiffuse;uniform float uT,uVeil,uFlash,uBar,uTone,uVig,uGrain;uniform vec2 uRes;varying vec2 vUv;\n' +
    'float h(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}\n' +
    'void main(){vec3 c=texture2D(tDiffuse,vUv).rgb;if(uTone>0.)c=1.-exp(-c*uTone);c+=vec3(1.,.98,.92)*uFlash;vec2 q=vUv-.5;c*=1.-smoothstep(.28,.95,length(q*vec2(1.5,1.1)))*uVig;\n' +
    'c+=(h(vUv*uRes+floor(uT*24.)*3.7)-.5)*uGrain;if(vUv.y<uBar||vUv.y>1.-uBar)c=vec3(0.);c=mix(c,vec3(0.),uVeil);gl_FragColor=vec4(clamp(c,0.,1.),1.);}';

  function lint(src) {
    const out = [], s = String(src || '');
    if (/\/\/[^\n]*/.test(s)) out.push('a // comment (use /* */ or none: once the source is flattened to one line it swallows the rest of the line without a compile error)');
    const noBlocks = s.replace(/\/\*[\s\S]*?\*\//g, '');
    if (/\/\*/.test(noBlocks)) out.push('an unclosed /* comment');
    const count = (re) => (noBlocks.match(re) || []).length;
    if (count(/\{/g) !== count(/\}/g)) out.push('unbalanced braces');
    if (count(/\(/g) !== count(/\)/g)) out.push('unbalanced parentheses');
    return out;
  }

  // ---- Seeded particle data, on the CPU, pure: the same options give the same arrays ----
  function particleData(o) {
    o = o || {}; const n = o.count == null ? 4000 : o.count, R = rng(o.seed == null ? 1 : o.seed), TAU = Math.PI * 2;
    const camZ = o.camZ == null ? 20000 : o.camZ, sp = o.spread || [.36, .5], cy = o.cy || 0, zr = o.z || [-9000, 2000];
    const sz = o.size || [1.1, 3.0], al = o.alpha || [.2, .65], big = o.big || {}, bs = big.share == null ? .06 : big.share, bsz = big.size || [2.6, 4.4], bal = big.alpha || [.6, .9];
    const position = new Float32Array(n * 3), aux = new Float32Array(n * 3), warm = new Float32Array(n), ws = o.warmShare == null ? .3 : o.warmShare;
    for (let i = 0; i < n; i++) {
      const isBig = R() < bs, z = zr[0] + R() * (zr[1] - zr[0]), d = camZ - z;
      position[i * 3] = (R() * 2 - 1) * d * sp[0]; position[i * 3 + 1] = cy + (R() * 2 - 1) * d * sp[1]; position[i * 3 + 2] = z;
      aux[i * 3] = isBig ? bsz[0] + R() * (bsz[1] - bsz[0]) : sz[0] + R() * (sz[1] - sz[0]);
      aux[i * 3 + 1] = R() * TAU;
      aux[i * 3 + 2] = isBig ? bal[0] + R() * (bal[1] - bal[0]) : al[0] + R() * (al[1] - al[0]);
      warm[i] = R() < ws ? 1 : 0;
    }
    return { count: n, position, aux, warm };
  }

  // ---- WebGL availability (cached): the bundle is there and a context can be created ----
  function available() {
    if (S.avail !== null) return S.avail;
    let ok = false;
    try {
      if (G.T3 && G.T3.THREE && typeof G.document !== 'undefined') {
        const c = G.document.createElement('canvas'), gl = c.getContext('webgl2') || c.getContext('webgl');
        ok = !!gl; if (gl) { const e = gl.getExtension('WEBGL_lose_context'); if (e) e.loseContext(); }
      }
    } catch (e) { ok = false; }
    S.avail = ok; return ok;
  }

  const noop = () => {};
  function inertStage(st) {
    return Object.assign(st, {
      ok: false, canvas: null, THREE: null, renderer: null, composer: null,
      scene: { add: noop, remove: noop }, camera: { position: { x: 0, y: 0, z: 0, set: noop }, lookAt: noop, updateProjectionMatrix: noop },
      fit: noop, resize: noop, look: noop, dispose: noop,
      render() { S.skipped++; return null; }, blit() { S.skipped++; return false; }, draw() { S.skipped++; return false; }
    });
  }

  function stage(o) {
    o = o || {};
    const st = { w: o.w || 1600, h: o.h || 900, focal: o.focal || 2544, scale: o.scale || 1, lost: false };
    if (!available()) return inertStage(st);
    const { THREE, EffectComposer, RenderPass, UnrealBloomPass, ShaderPass } = G.T3;
    const cv = G.document.createElement('canvas');
    const renderer = new THREE.WebGLRenderer({ canvas: cv, antialias: false, alpha: false, powerPreference: 'high-performance', preserveDrawingBuffer: true });
    renderer.setPixelRatio(1);
    renderer.setClearColor(new THREE.Color(o.bg || '#000000'), 1);
    const scene = new THREE.Scene(), camera = new THREE.PerspectiveCamera(fov(st.h, st.focal), st.w / st.h, o.near || 200, o.far || 90000);
    const pw = () => Math.max(2, Math.round(st.w * st.scale)), ph = () => Math.max(2, Math.round(st.h * st.scale));
    const samples = renderer.capabilities.isWebGL2 ? (o.samples == null ? 4 : o.samples) : 0;
    const rt = new THREE.WebGLRenderTarget(pw(), ph(), { type: THREE.HalfFloatType, samples });
    const composer = new EffectComposer(renderer, rt);
    composer.addPass(new RenderPass(scene, camera));
    if (o.bloom) composer.addPass(new UnrealBloomPass(new THREE.Vector2(pw(), ph()), o.bloom.strength == null ? .3 : o.bloom.strength, o.bloom.radius == null ? .4 : o.bloom.radius, o.bloom.threshold == null ? .9 : o.bloom.threshold));
    let grade = null;
    if (o.grade !== false) {
      const gr = o.grade || {};
      grade = new ShaderPass({ uniforms: { tDiffuse: { value: null }, uT: { value: 0 }, uVeil: { value: 0 }, uFlash: { value: 0 }, uBar: { value: 0 }, uTone: { value: gr.tone == null ? 0 : gr.tone }, uVig: { value: gr.vignette == null ? 0 : gr.vignette }, uGrain: { value: gr.grain == null ? 0 : gr.grain }, uRes: { value: new THREE.Vector2(pw(), ph()) } }, vertexShader: GRADE_VS, fragmentShader: GRADE_FS });
      composer.addPass(grade);
    }
    const apply = () => { renderer.setSize(pw(), ph(), false); composer.setSize(pw(), ph()); camera.fov = fov(st.h, st.focal); camera.aspect = st.w / st.h; camera.updateProjectionMatrix(); if (grade) grade.uniforms.uRes.value.set(pw(), ph()); };
    apply();
    cv.addEventListener('webglcontextlost', e => { e.preventDefault(); st.lost = true; });
    cv.addEventListener('webglcontextrestored', () => { st.lost = false; });
    return Object.assign(st, {
      ok: true, canvas: cv, THREE, renderer, composer, scene, camera,
      resize(w, h) { if (w === st.w && h === st.h) return; st.w = w; st.h = h; apply(); },
      fit(c) { if (c && c.SW && c.SH) st.resize(c.SW, c.SH); },
      look(x, y, zoom) { camera.position.set(x || 0, y || 0, st.focal / (zoom || 1)); camera.lookAt(x || 0, y || 0, 0); },
      render(t, ro) {
        if (st.lost) { S.skipped++; return null; }
        ro = ro || {};
        if (grade) { const u = grade.uniforms; u.uT.value = ro.grainTime == null ? t : ro.grainTime; u.uVeil.value = clamp(ro.veil || 0); u.uFlash.value = clamp(ro.flash || 0); u.uBar.value = ro.bars || 0; }
        composer.render(); return cv;
      },
      blit(g, x, y, w, h) { if (st.lost) { S.skipped++; return false; } g.drawImage(cv, x || 0, y || 0, w || st.w, h || st.h); return true; },
      draw(g, t, ro) { return st.render(t, ro) ? st.blit(g) : false; },
      dispose() { try { composer.dispose && composer.dispose(); rt.dispose(); renderer.dispose(); } catch (e) {} }
    });
  }

  function material(st, o) {
    const bad = lint(o.vertex).concat(lint(o.fragment));
    if (bad.length) throw new Error('SR3D shader: ' + bad.join('; '));
    if (!st.ok) return null;
    const T = st.THREE;
    return new T.ShaderMaterial({ vertexShader: o.vertex, fragmentShader: o.fragment, uniforms: o.uniforms || {}, transparent: o.transparent !== false, depthTest: o.depthTest !== false, depthWrite: !!o.depthWrite, blending: o.additive === false ? T.NormalBlending : T.AdditiveBlending });
  }

  function particles(st, o) {
    o = o || {}; const data = particleData(o), cols = o.colors || ['#ffffff', '#ffe2b0'];
    lint(PTS_VS); const bad = lint(PTS_VS).concat(lint(PTS_FS)); if (bad.length) throw new Error('SR3D shader: ' + bad.join('; '));
    if (!st.ok) return { points: null, data, set: noop };
    const T = st.THREE, geo = new T.BufferGeometry();
    geo.setAttribute('position', new T.BufferAttribute(data.position, 3)); geo.setAttribute('aux', new T.BufferAttribute(data.aux, 3)); geo.setAttribute('warm', new T.BufferAttribute(data.warm, 1));
    const U = { uT: { value: 0 }, uAmt: { value: 1 }, uOrbit: { value: 0 }, uPx: { value: (o.px || 1) * st.scale }, uAlpha: { value: 1 }, uTwinkle: { value: 0 }, uRadius: { value: o.radius || 240 }, uRef: { value: o.ref || 9000 }, uSize: { value: 1 }, uTarget: { value: new T.Vector2(0, 0) }, uC1: { value: new T.Color(cols[0]) }, uC2: { value: new T.Color(cols[1] || cols[0]) } };
    const pts = new T.Points(geo, new T.ShaderMaterial({ vertexShader: PTS_VS, fragmentShader: PTS_FS, uniforms: U, transparent: true, depthTest: true, depthWrite: false, blending: T.AdditiveBlending }));
    pts.frustumCulled = false; st.scene.add(pts);
    return {
      points: pts, data,
      set(t, s, c) {
        s = s || {}; const red = !!(c && c.reduced);
        U.uT.value = t; U.uAmt.value = s.amt == null ? 1 : s.amt; U.uOrbit.value = red ? 0 : (s.orbit == null ? 0 : s.orbit); U.uTwinkle.value = red ? 0 : (s.twinkle == null ? 0 : clamp(s.twinkle));
        U.uAlpha.value = s.alpha == null ? 1 : s.alpha; U.uSize.value = s.size == null ? 1 : s.size; if (s.target) U.uTarget.value.set(s.target[0], s.target[1]);
        pts.visible = (s.alpha == null ? 1 : s.alpha) > 0.001;
      }
    };
  }

  function orb(st, o) {
    o = o || {}; const cols = o.colors || ['#ffffff', '#888888'];
    const bad = lint(ORB_VS).concat(lint(ORB_FS)); if (bad.length) throw new Error('SR3D shader: ' + bad.join('; '));
    if (!st.ok) return { mesh: null, set: noop };
    const T = st.THREE, seg = o.segments || 64;
    const U = { uT: { value: 0 }, uK: { value: 1 }, uSeed: { value: 0 }, uSpin: { value: 0 }, uLimb: { value: o.limb == null ? 0 : o.limb }, uScale: { value: o.scale || 4.5 }, uC1: { value: new T.Color(cols[0]) }, uC2: { value: new T.Color(cols[1] || cols[0]) } };
    const mesh = new T.Mesh(new T.SphereGeometry(1, seg, Math.round(seg * .66)), new T.ShaderMaterial({ vertexShader: ORB_VS, fragmentShader: ORB_FS, uniforms: U, transparent: true, depthWrite: false, blending: T.AdditiveBlending }));
    mesh.renderOrder = o.order == null ? 1 : o.order; st.scene.add(mesh);
    return { mesh, set(t, s) { s = s || {}; const r = s.radius == null ? 100 : s.radius; mesh.position.set(s.x || 0, s.y || 0, s.z || 0); mesh.scale.set(r, r, r); U.uT.value = t; U.uK.value = s.k == null ? 1 : s.k; U.uSpin.value = s.spin || 0; U.uSeed.value = s.seed || 0; mesh.visible = U.uK.value > 0.001; } };
  }

  function glow(st, o) {
    o = o || {};
    const bad = lint(BILLBOARD_VS).concat(lint(GLOW_FS)); if (bad.length) throw new Error('SR3D shader: ' + bad.join('; '));
    if (!st.ok) return { mesh: null, set: noop };
    const T = st.THREE, U = { uSize: { value: new T.Vector2(1, 1) }, uC: { value: new T.Color(o.color || '#ffffff') }, uK: { value: 1 }, uMode: { value: o.mode === 'ring' ? 1 : 0 } };
    const mesh = new T.Mesh(new T.PlaneGeometry(1, 1), new T.ShaderMaterial({ vertexShader: BILLBOARD_VS, fragmentShader: GLOW_FS, uniforms: U, transparent: true, depthWrite: false, blending: T.AdditiveBlending }));
    mesh.frustumCulled = false; mesh.renderOrder = o.order == null ? 10 : o.order; st.scene.add(mesh);
    return { mesh, set(t, s) { s = s || {}; mesh.position.set(s.x || 0, s.y || 0, s.z || 0); const z = s.size == null ? 100 : s.size; U.uSize.value.set(z, z); U.uK.value = s.k == null ? 1 : s.k; mesh.visible = U.uK.value > 0.001; } };
  }

  G.SR3D = {
    version: 1, rng, fov, lint, particleData, available, stage, material, particles, orb, glow,
    glsl: { noise: NOISE, billboardVS: BILLBOARD_VS, glowFS: GLOW_FS, orbVS: ORB_VS, orbFS: ORB_FS, pointsVS: PTS_VS, pointsFS: PTS_FS, gradeVS: GRADE_VS, gradeFS: GRADE_FS },
    get skipped() { return S.skipped; }
  };
})(window);

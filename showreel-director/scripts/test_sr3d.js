#!/usr/bin/env node
/* Self-test of the 3D layer (engine/gl): the parts that need no WebGL, so it runs in Node without a GPU or a browser.
   Usage: node test_sr3d.js [--quiet]
   Checks: the Three.js bundle loads and keeps its licence block, the GLSL lint (and that every built-in shader passes it), seeded particle data (same seed same arrays,
   different seed different arrays, ranges, no NaN), the camera maths, the inert stage (no WebGL: nothing throws, skipped frames are counted), and the graph of Three
   objects that particles(), orb() and glow() build (uniforms are pure functions of time and state; reduced motion stops the orbit and the twinkle).
   What it cannot check: pixels. Look at the 3D in a browser (the built page of evals/gl-spike/v1). */
const fs = require('fs'), path = require('path'), vm = require('vm');
const quiet = process.argv.includes('--quiet');
const GL = path.join(__dirname, '..', 'engine', 'gl');
let fails = 0;
const ok = (c, m) => { if (c) { if (!quiet) console.log('  ok   ' + m); } else { fails++; console.log('  FAIL ' + m); } };
const near = (a, b, e) => Math.abs(a - b) <= (e || 1e-9);

const sb = { console, Math, Uint8Array, Float32Array, Array, JSON };
sb.window = sb; sb.globalThis = sb; vm.createContext(sb);
sb.SR = { clamp: (x, a = 0, b = 1) => Math.min(b, Math.max(a, x)) };
const bundleSrc = fs.readFileSync(path.join(GL, 'three-bundle.js'), 'utf8');
vm.runInContext(bundleSrc, sb);
ok(sb.T3 && ['THREE', 'EffectComposer', 'RenderPass', 'UnrealBloomPass', 'ShaderPass'].every(k => sb.T3[k]), 'the bundle defines window.T3 with THREE, EffectComposer, RenderPass, UnrealBloomPass and ShaderPass');
ok(/SPDX-License-Identifier: MIT/.test(bundleSrc) && /Three\.js Authors/.test(bundleSrc), 'the bundle keeps the MIT licence block of Three.js');
vm.runInContext(fs.readFileSync(path.join(GL, 'scene3d.js'), 'utf8'), sb);
const S3 = sb.SR3D;
ok(S3 && S3.version === 1, 'scene3d.js defines window.SR3D');

// lint
ok(S3.lint('void main(){gl_FragColor=vec4(1.);}').length === 0, 'lint accepts a clean shader');
ok(S3.lint('void main(){ // comment\n gl_FragColor=vec4(1.);}').some(m => /\/\/ comment/.test(m)), 'lint refuses a // comment (it swallows a line once flattened)');
ok(S3.lint('void main(){ /* ok */ gl_FragColor=vec4(1.);}').length === 0, 'lint accepts a /* */ comment');
ok(S3.lint('void main(){ /* open gl_FragColor=vec4(1.);}').length > 0, 'lint refuses an unclosed block comment');
ok(S3.lint('void main(){gl_FragColor=vec4(1.);').length > 0, 'lint refuses unbalanced braces');
ok(S3.lint('void main(){gl_FragColor=vec4(1.;}').length > 0, 'lint refuses unbalanced parentheses');
const names = Object.keys(S3.glsl), bad = names.filter(k => S3.lint(S3.glsl[k]).length);
ok(!bad.length, 'every built-in GLSL chunk passes the lint (' + names.length + ' chunks' + (bad.length ? ', failing: ' + bad.join(', ') : '') + ')');

// seeded particles
const A = S3.particleData({ count: 500, seed: 7 }), B = S3.particleData({ count: 500, seed: 7 }), C = S3.particleData({ count: 500, seed: 8 });
const same = (x, y) => x.length === y.length && x.every((v, i) => v === y[i]);
ok(same(A.position, B.position) && same(A.aux, B.aux) && same(A.warm, B.warm), 'particle data: the same seed gives the same arrays');
ok(!same(A.position, C.position), 'particle data: another seed gives other positions');
ok(A.position.length === 1500 && A.aux.length === 1500 && A.warm.length === 500, 'particle data: array sizes follow the count');
ok([...A.position, ...A.aux, ...A.warm].every(Number.isFinite), 'particle data: no NaN or infinity');
let amin = 9, amax = -9, smin = 99, smax = -1; for (let i = 0; i < 500; i++) { const al = A.aux[i * 3 + 2], sz = A.aux[i * 3]; amin = Math.min(amin, al); amax = Math.max(amax, al); smin = Math.min(smin, sz); smax = Math.max(smax, sz); }
ok(amin >= .2 && amax <= .9 && smin >= 1.1 && smax <= 4.4, 'particle data: alpha and size stay in their ranges');
const D = S3.particleData({ count: 300, seed: 3, z: [-100, 100], camZ: 1000, spread: [.5, .25], cy: 40 });
ok(Array.from({ length: 300 }, (_, i) => D.position[i * 3 + 2]).every(z => z >= -100 && z <= 100) && Array.from({ length: 300 }, (_, i) => Math.abs(D.position[i * 3] / (1000 - D.position[i * 3 + 2]))).every(r => r <= .5 + 1e-6), 'particle data: depth range and perspective spread follow the options');

// camera maths: a world unit at distance 1 covers `focal` stage pixels
ok(near(S3.fov(900, 2544), 2 * Math.atan(450 / 2544) * 180 / Math.PI, 1e-9), 'camera: fov from the stage height and the focal length');

// inert stage: no WebGL here (no document)
ok(S3.available() === false, 'no WebGL in Node: available() is false');
const st0 = S3.stage({ w: 800, h: 450 });
ok(st0.ok === false && st0.canvas === null, 'the stage is inert without WebGL');
const before = S3.skipped; let threw = false, drawn = true;
try { st0.fit({ SW: 800, SH: 450 }); st0.look(0, 0, 1); drawn = st0.draw({ drawImage() { throw new Error('should not draw'); } }, 1, { veil: .5 }); S3.particles(st0, {}).set(1, {}, {}); S3.orb(st0, {}).set(1, {}); S3.glow(st0, {}).set(1, {}); } catch (e) { threw = true; }
ok(!threw && drawn === false, 'an inert stage never throws and never draws');
ok(S3.skipped > before, 'skipped frames are counted (the harness reports them)');
let lintThrew = false; try { S3.material(st0, { vertex: 'void main(){ // x\n}', fragment: 'void main(){}' }); } catch (e) { lintThrew = /SR3D shader/.test(e.message); }
ok(lintThrew, 'a GLSL rule break throws even without WebGL, so the harness catches it');

// graph of Three objects on a stage without renderer
const T = sb.T3.THREE, fake = { ok: true, THREE: T, scale: 1, scene: new T.Scene() };
const P = S3.particles(fake, { count: 200, seed: 5 });
ok(P.points && P.points.isPoints && P.points.geometry.getAttribute('position').count === 200 && fake.scene.children.includes(P.points), 'particles(): a Points object with the seeded attributes joins the scene');
const U = P.points.material.uniforms, val = () => JSON.stringify([U.uT.value, U.uAmt.value, U.uOrbit.value, U.uTwinkle.value, U.uAlpha.value, U.uTarget.value.x, U.uTarget.value.y]);
P.set(2.5, { amt: .4, orbit: .1, twinkle: .8, alpha: .9, target: [10, 20] }, { reduced: false }); const v1 = val();
P.set(9, { amt: 1 }, {}); P.set(2.5, { amt: .4, orbit: .1, twinkle: .8, alpha: .9, target: [10, 20] }, { reduced: false });
ok(val() === v1 && U.uOrbit.value === .1 && U.uTwinkle.value === .8, 'particles(): the state is a pure function of time and options (no stored state)');
P.set(2.5, { amt: .4, orbit: .1, twinkle: .8 }, { reduced: true });
ok(U.uOrbit.value === 0 && U.uTwinkle.value === 0, 'particles(): reduced motion stops the orbit and the twinkle');
P.set(1, { alpha: 0 }, {}); ok(P.points.visible === false, 'particles(): a zero alpha hides the field');
const O = S3.orb(fake, { colors: ['#ff0000', '#00ff00'], limb: .3 }); O.set(1, { x: 5, y: 6, z: 7, radius: 50, k: 1, spin: 2, seed: 4 });
ok(O.mesh.isMesh && near(O.mesh.scale.x, 50) && near(O.mesh.position.y, 6) && near(O.mesh.material.uniforms.uLimb.value, .3), 'orb(): a sphere placed and scaled from its state');
const G = S3.glow(fake, { mode: 'ring', color: '#ffffff' }); G.set(1, { size: 300, k: 0 });
ok(G.mesh.isMesh && G.mesh.material.uniforms.uMode.value === 1 && G.mesh.visible === false, 'glow(): a ring billboard, hidden at zero intensity');
let mat = null; try { mat = S3.material(fake, { vertex: S3.glsl.billboardVS, fragment: S3.glsl.glowFS, uniforms: { uSize: { value: new T.Vector2(1, 1) }, uC: { value: new T.Color('#fff') }, uK: { value: 1 }, uMode: { value: 0 } } }); } catch (e) {}
ok(mat && mat.isShaderMaterial && mat.blending === T.AdditiveBlending, 'material(): a linted additive ShaderMaterial');

console.log(fails ? fails + ' check(s) failed' : 'sr3d self-test: all passed');
process.exit(fails ? 1 : 0);

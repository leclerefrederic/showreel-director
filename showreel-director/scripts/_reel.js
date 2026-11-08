/* Shared by harness.js and export_mp4.js (not a command): loads a built reel page into a sandbox, registers its embedded fonts and
   provides the image stub. The reel's scripts (data, core, main) run in a vm context with no DOM; the host decides how images load. */
const fs = require('fs'), vm = require('vm');

const makeOpt = args => (name, def) => { const i = args.indexOf(name); return i > -1 ? args[i + 1] : def; };

// imgLoader(dataUri) -> drawable or null; it becomes SR_IMG_LOADER, which SR.img(key) calls (see engine/core.js).
// canvasFactory(w, h) -> an off-screen canvas; it becomes SR_CANVAS_FACTORY, which the film layer (engine/film.js) uses to draw two scenes at once during a transition.
function loadReel(file, imgLoader, canvasFactory) {
  const html = fs.readFileSync(file, 'utf8');
  const sandbox = { console, atob: s => Buffer.from(s, 'base64').toString('binary'), Math, Uint8Array, Array, JSON };
  sandbox.window = sandbox; sandbox.globalThis = sandbox;
  if (imgLoader) sandbox.SR_IMG_LOADER = imgLoader;
  if (canvasFactory) sandbox.SR_CANVAS_FACTORY = canvasFactory;
  vm.createContext(sandbox);
  for (const id of ['sr-data', 'sr-core', 'sr-main']) {
    const m = new RegExp(`<script id="${id}">([\\s\\S]*?)</script>`).exec(html);
    if (!m) { console.error('missing script ' + id + ' (is this a built player page, not a contact sheet?)'); process.exit(2); }
    vm.runInContext(m[1], sandbox);
  }
  return { html, sandbox, S: sandbox.SHOWREEL, SR: sandbox.SR, DUR: sandbox.SR.data.dur };
}

// Registers every font embedded as a data URL in an @font-face rule; returns how many were registered.
function registerFonts(html, GlobalFonts) {
  let n = 0;
  for (const m of html.matchAll(/@font-face\{font-family:"([^"]+)";[^}]*?base64,([A-Za-z0-9+/=]+)\)/g)) {
    try { if (GlobalFonts.register(Buffer.from(m[2], 'base64'), m[1])) n++; } catch (e) { console.warn('font not registered: ' + m[1] + ' (' + e.message + ')'); }
  }
  return n;
}

// Image stub with the real pixel size (PNG header) or 100x100, so code that draws embedded images is exercised without decoding.
function stubImage(uri) {
  const b = Buffer.from(uri.split(',')[1] || '', 'base64'); let w = 100, h = 100;
  if (b.length > 24 && b.toString('latin1', 1, 4) === 'PNG') { w = b.readUInt32BE(16); h = b.readUInt32BE(20); }
  return { width: w, height: h, naturalWidth: w, naturalHeight: h, complete: true };
}

module.exports = { makeOpt, loadReel, registerFonts, stubImage };

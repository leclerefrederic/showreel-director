/* Tiny GIF89a encoder for the effects lab (no dependencies). Fixed 256-colour palette: 216 web-safe colours + 40 greys,
   nearest-colour mapping, no dithering (flat motion-design frames survive well; photographic content would not).
   GifLab.quantize(rgbaArray) -> Uint8Array of palette indices; GifLab.encode(indexFrames, w, h, delayCs) -> Uint8Array (.gif bytes, loops forever). */
(function (G) {
  'use strict';
  const PAL = [];
  for (let r = 0; r < 6; r++) for (let g = 0; g < 6; g++) for (let b = 0; b < 6; b++) PAL.push([r * 51, g * 51, b * 51]);
  for (let i = 0; i < 40; i++) { const v = Math.round(i * 255 / 39); PAL.push([v, v, v]); }

  function quantize(rgba) {
    const n = rgba.length / 4, out = new Uint8Array(n);
    for (let i = 0; i < n; i++) {
      const r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
      const wr = Math.round(r / 51), wg = Math.round(g / 51), wb = Math.round(b / 51);
      const e1 = (r - wr * 51) ** 2 + (g - wg * 51) ** 2 + (b - wb * 51) ** 2;
      let idx = wr * 36 + wg * 6 + wb;
      if (e1 > 60) { // maybe a grey is closer
        const a = Math.round((r + g + b) / 3), gi = Math.round(a * 39 / 255), gv = PAL[216 + gi][0];
        if ((r - gv) ** 2 + (g - gv) ** 2 + (b - gv) ** 2 < e1) idx = 216 + gi;
      }
      out[i] = idx;
    }
    return out;
  }

  function lzw(idx, min) {
    const clear = 1 << min, eoi = clear + 1, bytes = []; let dict = new Map(), next = eoi + 1, size = min + 1, cur = 0, nb = 0;
    const emit = c => { cur |= c << nb; nb += size; while (nb >= 8) { bytes.push(cur & 255); cur >>>= 8; nb -= 8; } };
    emit(clear); let prefix = idx[0];
    for (let i = 1; i < idx.length; i++) {
      const k = prefix * 256 + idx[i], hit = dict.get(k);
      if (hit !== undefined) { prefix = hit; continue; }
      emit(prefix); dict.set(k, next);
      if (next === (1 << size) && size < 12) size++;
      next++;
      if (next >= 4095) { emit(clear); dict = new Map(); next = eoi + 1; size = min + 1; }
      prefix = idx[i];
    }
    emit(prefix); emit(eoi); if (nb > 0) bytes.push(cur & 255);
    return bytes;
  }

  function encode(frames, w, h, delay) {
    const o = []; const w16 = v => o.push(v & 255, (v >> 8) & 255);
    'GIF89a'.split('').forEach(c => o.push(c.charCodeAt(0))); w16(w); w16(h); o.push(0xF7, 0, 0);
    PAL.forEach(c => o.push(c[0], c[1], c[2]));
    o.push(0x21, 0xFF, 11); 'NETSCAPE2.0'.split('').forEach(c => o.push(c.charCodeAt(0))); o.push(3, 1, 0, 0, 0);
    frames.forEach(fr => {
      o.push(0x21, 0xF9, 4, 0); w16(delay); o.push(0, 0);
      o.push(0x2C); w16(0); w16(0); w16(w); w16(h); o.push(0);
      o.push(8); const data = lzw(fr, 8);
      for (let i = 0; i < data.length; i += 255) { const part = data.slice(i, i + 255); o.push(part.length); for (let j = 0; j < part.length; j++) o.push(part[j]); }
      o.push(0);
    });
    o.push(0x3B);
    return Uint8Array.from(o);
  }

  G.GifLab = { quantize, encode };
})(typeof window !== 'undefined' ? window : globalThis);

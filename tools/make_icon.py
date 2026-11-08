#!/usr/bin/env python3
"""Draws the app icon master (1024x1024 PNG) with PIL and numpy: an original design, a film reel with a play
triangle on a violet-to-pink gradient, inside the macOS icon grid (824 pt squircle, soft shadow).
The PNG master and the finished AppIcon.icns (every macOS size, 16 to 1024 px) are both committed; make-app.sh
just copies the .icns into the app. Usage: python3 tools/make_icon.py"""
import io, math, os, struct
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "app-swift", "Icon", "AppIcon.png")
S = 2                 # supersampling
N = 1024 * S
C = N / 2


def squircle_mask(size, half, n=5.0):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    nx, ny = (x - C) / half, (y - C) / half
    d = np.abs(nx) ** n + np.abs(ny) ** n
    return np.clip((1.0 - d) * half * 0.9, 0, 1)  # soft 1 px edge


def gradient(size):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    t = np.clip((x + y) / (2 * size), 0, 1)[..., None]
    stops = [(0.0, (58, 43, 214)), (0.55, (139, 61, 240)), (1.0, (240, 80, 142))]
    out = np.zeros((size, size, 3), np.float32)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = ((t >= t0) & (t <= t1)).astype(np.float32)
        k = (t - t0) / (t1 - t0)
        out += m * (np.array(c0, np.float32) * (1 - k) + np.array(c1, np.float32) * k)
    return out


def rounded_triangle(draw, pts, r, fill):
    cx = sum(p[0] for p in pts) / 3; cy = sum(p[1] for p in pts) / 3
    inset = []
    for px, py in pts:                       # shrink toward the centre, then round by r
        d = math.hypot(px - cx, py - cy); k = (d - r * 2) / d
        inset.append((cx + (px - cx) * k, cy + (py - cy) * k))
    draw.polygon(inset, fill=fill)
    for i in range(3):
        a, b = inset[i], inset[(i + 1) % 3]
        draw.line([a, b], fill=fill, width=int(r * 2))
        draw.ellipse([a[0] - r, a[1] - r, a[0] + r, a[1] + r], fill=fill)


half = 412 * S                               # macOS grid: an 824 pt shape in a 1024 pt canvas
mask = squircle_mask(N, half)
grad = gradient(N)

# soft highlight from the top left
y, x = np.mgrid[0:N, 0:N].astype(np.float32)
hl = np.clip(1 - np.hypot(x - 0.30 * N, y - 0.18 * N) / (0.75 * N), 0, 1) ** 2 * 0.22
grad = grad + hl[..., None] * (255 - grad)

# the reel: white disc with six holes, a hub, and a play triangle
reel = Image.new("L", (N, N), 0)
d = ImageDraw.Draw(reel)
R = 285 * S
d.ellipse([C - R, C - R, C + R, C + R], fill=255)
for k in range(6):                           # six cut-outs
    a = math.radians(30 + 60 * k)
    hx, hy, hr = C + math.cos(a) * 168 * S, C + math.sin(a) * 168 * S, 66 * S
    d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=0)
hub = 96 * S
d.ellipse([C - hub, C - hub, C + hub, C + hub], fill=0)   # centre opening
tri = Image.new("L", (N, N), 0)
td = ImageDraw.Draw(tri)
s = 70 * S
rounded_triangle(td, [(C - s * 0.62 + 10 * S, C - s), (C - s * 0.62 + 10 * S, C + s), (C + s * 1.05 + 10 * S, C)], 12 * S, 255)

reel_a = np.asarray(reel, np.float32)[..., None] / 255
tri_a = np.asarray(tri, np.float32)[..., None] / 255
white = np.full((N, N, 3), 255, np.float32)
shade = np.asarray(reel.filter(ImageFilter.GaussianBlur(14 * S)), np.float32)[..., None] / 255
img = grad * (1 - 0.30 * np.roll(shade, 10 * S, axis=0) * (1 - reel_a))   # soft shadow of the reel on the background
img = img * (1 - reel_a * 0.97) + white * reel_a * 0.97
img = img * (1 - tri_a) + white * tri_a

# squircle with its drop shadow
rgb = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
alpha = Image.fromarray((mask * 255).astype(np.uint8), "L")
canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
shadow.putalpha(alpha.filter(ImageFilter.GaussianBlur(18 * S)).point(lambda v: int(v * 0.35)))
canvas.alpha_composite(Image.new("RGBA", (N, N), (0, 0, 0, 0)))
sh = Image.new("RGBA", (N, N), (0, 0, 0, 255)); sh.putalpha(shadow.getchannel("A"))
canvas.alpha_composite(sh, (0, 12 * S))
icon = rgb.convert("RGBA"); icon.putalpha(alpha)
canvas.alpha_composite(icon)
canvas.resize((1024, 1024), Image.LANCZOS).save(OUT, optimize=True)
print("wrote", OUT)

# AppIcon.icns: PNG-compressed entries, as macOS expects (type, pixel size)
ICNS = os.path.join(os.path.dirname(OUT), "AppIcon.icns")
master = Image.open(OUT).convert("RGBA")
TYPES = [(b"icp4", 16), (b"icp5", 32), (b"icp6", 64), (b"ic07", 128), (b"ic08", 256), (b"ic09", 512), (b"ic10", 1024),
         (b"ic11", 32), (b"ic12", 64), (b"ic13", 256), (b"ic14", 512)]
body = b""
for code, px in TYPES:
    buf = io.BytesIO()
    (master if px == 1024 else master.resize((px, px), Image.LANCZOS)).save(buf, "PNG", optimize=True)
    body += code + struct.pack(">I", len(buf.getvalue()) + 8) + buf.getvalue()
open(ICNS, "wb").write(b"icns" + struct.pack(">I", len(body) + 8) + body)
print("wrote", ICNS, "(%d KB)" % (os.path.getsize(ICNS) // 1024))

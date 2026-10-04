#!/usr/bin/env python3
"""Generates the bundled notification tones (WAV, converted to CAF by afconvert) and the app icon."""
import math, os, struct, subprocess, wave, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 44100

def tone(notes, path):
    """notes: list of (start_s, freq, dur_s, amp) — bell-like decaying partials."""
    total = max(s + d for s, _, d, _ in notes) + 0.1
    buf = [0.0] * int(total * SR)
    for start, f, dur, amp in notes:
        s0 = int(start * SR)
        for i in range(int(dur * SR)):
            t = i / SR
            env = math.exp(-t * 4.0 / dur) * min(1.0, t * 200)
            v = (math.sin(2*math.pi*f*t) + 0.4*math.sin(2*math.pi*2.01*f*t) + 0.15*math.sin(2*math.pi*3.02*f*t))
            buf[s0 + i] += amp * env * v / 1.55
    peak = max(abs(x) for x in buf) or 1
    wav = path + ".wav"
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(x / peak * 0.85 * 32767)) for x in buf))
    subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", wav, path + ".caf"], check=True)
    os.remove(wav)

snd = os.path.join(ROOT, "App/Resources/Sounds")
os.makedirs(snd, exist_ok=True)
tone([(0, 880, 1.2, 1), (0.25, 1108.7, 1.2, 1), (0.5, 1318.5, 1.6, 1)], f"{snd}/Chime")
tone([(0, 523.25, 2.5, 1), (1.2, 523.25, 2.5, 0.8)], f"{snd}/Bell")
tone([(0, 659.25, 1.5, 0.6), (0.4, 587.33, 1.8, 0.6)], f"{snd}/Soft")
tone([(i * 0.18, 1760, 0.12, 1) for i in range(3)] + [(0.8 + i * 0.18, 1760, 0.12, 1) for i in range(3)], f"{snd}/Beeps")

# ---- icon: teal gradient, gold crescent and star (1024x1024, opaque) ----
N = 1024
def png(path, px):
    raw = b"".join(b"\x00" + bytes(row) for row in px)
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

def star_inside(x, y, cx, cy, r_out, r_in, pts=5):
    ang = math.atan2(y - cy, x - cx) + math.pi / 2
    d = math.hypot(x - cx, y - cy)
    seg = (ang % (2*math.pi / pts)) / (2*math.pi / pts)
    frac = abs(seg - 0.5) * 2  # 1 at tips, 0 between
    return d < r_in + (r_out - r_in) * frac ** 1.6

gold = (240, 200, 110)
rows = []
for y in range(N):
    row = []
    for x in range(N):
        t = y / N
        c = (int(10 + 20*t), int(70 + 30*(1-t)), int(90 + 40*(1-t)))
        # crescent: big circle minus offset circle, antialiased via 2x2 supersampling
        cov = 0
        for sx in (0.25, 0.75):
            for sy in (0.25, 0.75):
                px, py = x + sx, y + sy
                in_a = (px - 470)**2 + (py - 520)**2 < 300**2
                in_b = (px - 580)**2 + (py - 450)**2 < 255**2
                in_s = star_inside(px, py, 700, 360, 95, 40)
                cov += 1 if ((in_a and not in_b) or in_s) else 0
        a = cov / 4
        row += [int(c[i] * (1 - a) + gold[i] * a) for i in range(3)]
    rows.append(row)
icon_dir = os.path.join(ROOT, "App/Assets.xcassets/AppIcon.appiconset")
png(f"{icon_dir}/icon-1024.png", rows)
with open(f"{icon_dir}/Contents.json", "w") as f:
    f.write('{"images":[{"filename":"icon-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}],'
            '"info":{"author":"xcode","version":1}}')
with open(os.path.join(ROOT, "App/Assets.xcassets/Contents.json"), "w") as f:
    f.write('{"info":{"author":"xcode","version":1}}')
print("assets ok")

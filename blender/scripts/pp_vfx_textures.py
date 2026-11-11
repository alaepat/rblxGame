"""Original particle textures for Controllers/Effects (VFX pass).

Run with Blender's bundled Python (needs only numpy + zlib):
  "C:/Program Files/Blender Foundation/Blender 3.4/3.4/python/bin/python.exe" blender/scripts/pp_vfx_textures.py
Writes blender/export/vfx_smoke.png: a soft, lumpy white smoke puff on
transparent background (tint it with ParticleEmitter.Color). Uploaded as a
group asset (Chrome Hearts Global); id in src/shared/Config/VfxIds.luau.
Roblox's built-in rbxasset://textures/particles/smoke_main.dds renders almost
invisible, which is why this exists.
"""
import os
import struct
import zlib

import numpy as np

SIZE = 256
OUT = os.path.join(os.path.dirname(__file__), "..", "export", "vfx_smoke.png")


def write_png(path, rgba):
    h, w, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def value_noise(size, cells, rng):
    """Smooth value noise in [0,1] (bicubic-ish upsample of a random grid)."""
    grid = rng.random((cells + 3, cells + 3))
    t = np.linspace(0, cells, size, endpoint=False)
    i = t.astype(int)
    f = t - i
    s = f * f * (3 - 2 * f)  # smoothstep
    y0, x0 = np.meshgrid(i, i, indexing="ij")
    sy, sx = np.meshgrid(s, s, indexing="ij")
    a = grid[y0, x0]
    b = grid[y0, x0 + 1]
    c = grid[y0 + 1, x0]
    d = grid[y0 + 1, x0 + 1]
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


def main():
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    c = (SIZE - 1) / 2
    r = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c  # 0 centre .. 1 edge

    # fractal noise for lumpy, cloudy edges
    n = sum(value_noise(SIZE, cells, rng) * w for cells, w in ((4, 0.5), (8, 0.3), (16, 0.2)))
    edge = 0.72 + 0.28 * n  # radius where the puff fades out, wobbles with noise
    falloff = np.clip(1 - r / edge, 0, 1)
    alpha = falloff ** 1.6 * (0.75 + 0.25 * n)
    alpha = np.clip(alpha * 1.15, 0, 1)

    # slight shading: brighter top-left, greyer bottom-right, so puffs read as volume
    shade = 0.82 + 0.18 * np.clip(1 - ((xx + yy) / (2 * SIZE)), 0, 1) + 0.08 * (n - 0.5)
    shade = np.clip(shade, 0, 1)

    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = (shade * 255).astype(np.uint8)
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    write_png(os.path.abspath(OUT), rgba)
    print("wrote", os.path.abspath(OUT))


if __name__ == "__main__":
    main()

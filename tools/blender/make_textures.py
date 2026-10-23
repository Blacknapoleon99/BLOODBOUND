"""Procedural tileable PBR sets for materials Poly Haven has no scan for (DEC-057): bone,
cloth (coarse woven, stained) and wax. Original, generated with numpy (bundled with Blender).

  blender.exe -b --python tools/blender/make_textures.py -- <repo_root>

Writes assets/textures/gothic/<set>_{diff,nor,arm}.jpg (512 px, tileable). ARM = AO, rough,
metal like the Poly Haven sets; normals are OpenGL convention.
"""
import os, sys
import numpy as np
import bpy

N = 512
rng = np.random.default_rng(57)


def noise(scale, octaves=4, persistence=0.5):
    """Tileable fractal noise in [0, 1] (white noise low-passed in Fourier space)."""
    out = np.zeros((N, N))
    amp = 1.0
    total = 0.0
    fy = np.fft.fftfreq(N)[:, None]
    fx = np.fft.fftfreq(N)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    for o in range(octaves):
        cutoff = scale * (2 ** o) / N
        w = np.exp(-(f / max(cutoff, 1e-6)) ** 2)
        n = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((N, N))) * w))
        n = (n - n.mean()) / (n.std() + 1e-9)
        out += n * amp
        total += amp
        amp *= persistence
    out /= total
    return np.clip(out * 0.25 + 0.5, 0.0, 1.0)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)  # OpenGL (+Y up)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save(name, rgb):
    img = bpy.data.images.new(name, N, N, alpha=True)
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((N, N, 1))], -1)
    img.pixels.foreach_set(rgba[::-1].astype(np.float32).ravel())
    img.filepath_raw = os.path.join(OUT, name + ".jpg")
    img.file_format = 'JPEG'
    bpy.context.scene.render.image_settings.quality = 92
    img.save()
    print("wrote", img.filepath_raw)


def bone():
    base = noise(6, 5)
    pores = noise(90, 2)
    pores = (pores < 0.32).astype(float) * 0.6 + noise(140, 1) * 0.15
    streak = noise(3, 3)
    stain = np.clip((noise(4, 4) - 0.45) * 2.5, 0, 1)
    h = base * 0.5 + streak * 0.3 - pores * 0.25
    col = np.stack([0.86 + 0.08 * base, 0.79 + 0.07 * base, 0.64 + 0.05 * base], -1)
    col *= (1.0 - 0.28 * pores[..., None])
    col = col * (1 - stain[..., None] * 0.45) + stain[..., None] * 0.45 * np.array([0.42, 0.3, 0.18])
    save("bone_diff", col)
    save("bone_nor", normal_from_height(h, 6.0))
    rough = 0.55 + 0.25 * pores + 0.15 * stain
    save("bone_arm", np.stack([1.0 - pores * 0.35, rough, np.zeros_like(h)], -1))


def cloth():
    y, x = np.mgrid[0:N, 0:N] / N
    threads = 128
    wx = np.sin(x * np.pi * 2 * threads) * 0.5 + 0.5
    wy = np.sin(y * np.pi * 2 * threads) * 0.5 + 0.5
    checker = ((np.floor(x * threads) + np.floor(y * threads)) % 2)
    weave = np.where(checker > 0, wx * 0.7 + 0.3 * wy, wy * 0.7 + 0.3 * wx)
    slub = noise(40, 2)
    grime = noise(5, 5)
    holes = np.clip((noise(10, 3) - 0.78) * 6.0, 0, 1)
    h = weave * 0.6 + slub * 0.3 - holes * 0.5
    lum = 0.55 + 0.35 * weave * (0.7 + 0.3 * slub)
    lum *= 0.65 + 0.35 * grime
    lum *= 1.0 - holes * 0.7
    # Neutral warm-grey so the material tint sets the colour (red banners, dark robes).
    col = np.stack([lum * 0.95, lum * 0.9, lum * 0.86], -1)
    stain = np.clip((noise(6, 4) - 0.55) * 3.0, 0, 1)[..., None]
    col = col * (1 - stain * 0.5)
    save("cloth_diff", col)
    save("cloth_nor", normal_from_height(h, 4.0))
    save("cloth_arm", np.stack([0.75 + 0.25 * weave, 0.85 + 0.1 * slub, np.zeros_like(h)], -1))


def wax():
    base = noise(5, 4)
    drip = noise(2, 3)
    h = base * 0.6 + drip * 0.4
    col = np.stack([0.9 + 0.06 * base, 0.82 + 0.06 * base, 0.62 + 0.05 * base], -1) * (0.85 + 0.15 * drip[..., None])
    save("wax_diff", col)
    save("wax_nor", normal_from_height(h, 3.0))
    save("wax_arm", np.stack([np.ones_like(h), 0.35 + 0.2 * base, np.zeros_like(h)], -1))


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.join(args[0] if args else os.getcwd(), "assets", "textures", "gothic")
bone()
cloth()
wax()

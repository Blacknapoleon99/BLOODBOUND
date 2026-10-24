"""Procedural tileable PBR sets for the full-3D creatures (DEC-064): wet flayed muscle, pale
corpse skin and torn black lace. Original, generated with numpy (bundled with Blender / bpy).

  blender.exe -b --python tools/blender/make_creature_textures.py -- <repo_root>
  python tools/blender/make_creature_textures.py -- <repo_root>      (pip install bpy)

Writes assets/models/enemies/creatures/tex/<set>_{diff,nor,arm}.(jpg|png) (512 px, tileable).
ARM = AO, rough, metal like the Poly Haven sets; normals are OpenGL convention. The lace
diffuse is a PNG whose alpha is the hole mask (alpha-scissored in Godot).
"""
import os, sys
import numpy as np
import bpy

N = 512
rng = np.random.default_rng(64)


def noise(scale, octaves=4, persistence=0.5, stretch=(1.0, 1.0)):
    """Tileable fractal noise in [0, 1]; `stretch` (sx, sy) > 1 elongates features along x/y."""
    out = np.zeros((N, N))
    amp = 1.0
    total = 0.0
    fy = np.fft.fftfreq(N)[:, None] * stretch[1]
    fx = np.fft.fftfreq(N)[None, :] * stretch[0]
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
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save(name, rgb, alpha=None):
    img = bpy.data.images.new(name, N, N, alpha=True)
    a = np.ones((N, N, 1)) if alpha is None else np.clip(alpha, 0, 1)[..., None]
    rgba = np.concatenate([np.clip(rgb, 0, 1), a], -1)
    img.pixels.foreach_set(rgba[::-1].astype(np.float32).ravel())
    ext = "png" if alpha is not None else "jpg"
    img.filepath_raw = os.path.join(OUT, name + "." + ext)
    img.file_format = 'PNG' if alpha is not None else 'JPEG'
    bpy.context.scene.render.image_settings.quality = 92
    img.save()
    print("wrote", img.filepath_raw)


def veins(scale, width):
    """Thin branching lines (|noise - 0.5| small): veins, cracks."""
    v = noise(scale, 3)
    return np.clip(1.0 - np.abs(v - 0.5) / width, 0, 1) ** 2


def muscle():
    # Fibre bundles run along y: noise stretched hard across x.
    fib = noise(70, 3, 0.6, (12.0, 1.0))
    bundles = noise(14, 2, 0.5, (8.0, 1.0))
    groove = np.clip((0.5 - np.abs(fib - 0.5)) * 2.0, 0, 1)
    fascia = np.clip((noise(16, 3, 0.5, (9.0, 1.0)) - 0.7) * 5.0, 0, 1)  # pale connective sheets
    vein = veins(3, 0.018)
    clot = np.clip((noise(4, 4) - 0.6) * 4.0, 0, 1)
    h = fib * 0.55 + bundles * 0.35 + fascia * 0.25 - vein * 0.15
    red = np.array([0.52, 0.06, 0.06])
    dark = np.array([0.2, 0.01, 0.025])
    fat = np.array([0.78, 0.62, 0.48])
    t = np.clip(0.1 + 1.1 * fib * (0.5 + 0.6 * bundles) - 0.25 * groove, 0, 1)[..., None]
    col = dark * (1 - t) + red * t
    col = col * (1 - fascia[..., None] * 0.6) + fat * fascia[..., None] * 0.6
    col = col * (1 - vein[..., None] * 0.55) + np.array([0.12, 0.02, 0.08]) * vein[..., None] * 0.55
    col = col * (1 - clot[..., None] * 0.6) + np.array([0.12, 0.0, 0.01]) * clot[..., None] * 0.6
    save("muscle_diff", col)
    save("muscle_nor", normal_from_height(h, 7.0))
    rough = 0.18 + 0.2 * (1 - fib) + 0.25 * fascia - 0.1 * clot
    save("muscle_arm", np.stack([1.0 - groove * 0.35, rough, np.zeros_like(h)], -1))


def skin():
    base = noise(5, 5)
    mottle = noise(3, 4)
    pores = (noise(120, 1) < 0.3).astype(float) * 0.5
    vein = veins(4, 0.02)
    bruise = np.clip((noise(3, 3) - 0.55) * 3.0, 0, 1)
    wrinkle = noise(30, 2, 0.5, (1.0, 5.0))
    h = base * 0.4 + wrinkle * 0.4 - pores * 0.15 - vein * 0.05
    lum = 0.78 + 0.16 * base - pores * 0.08
    col = np.stack([lum, lum * 0.97, lum * 0.9], -1)
    col = col * (0.85 + 0.15 * mottle[..., None])
    col = col * (1 - bruise[..., None] * 0.45) + np.array([0.35, 0.22, 0.38]) * bruise[..., None] * 0.45
    col = col * (1 - vein[..., None] * 0.5) + np.array([0.25, 0.3, 0.45]) * vein[..., None] * 0.5
    save("skin_diff", col)
    save("skin_nor", normal_from_height(h, 4.0))
    save("skin_arm", np.stack([1.0 - pores * 0.4, 0.55 + 0.2 * base, np.zeros_like(h)], -1))


def lace():
    y, x = np.mgrid[0:N, 0:N] / N
    cells = 16
    cx = (x * cells) % 1.0 - 0.5
    cy = (y * cells) % 1.0 - 0.5
    r = np.sqrt(cx * cx + cy * cy)
    ang = np.arctan2(cy, cx)
    petal = 0.3 + 0.08 * np.cos(ang * 6)
    hole = (r < petal * 0.75).astype(float)
    ring = ((r > petal * 0.75) & (r < petal)).astype(float)
    tears = np.clip((noise(6, 3) - 0.7) * 6.0, 0, 1)
    threads = (np.abs(np.sin((x + y) * np.pi * cells * 2)) < 0.12).astype(float)
    alpha = np.clip((1.0 - hole) * 0.95 + threads * hole * 0.9, 0, 1) * (1.0 - tears)
    alpha = np.clip(alpha + ring * 0.2, 0, 1)
    grime = noise(5, 3)
    lum = 0.22 + 0.15 * ring + 0.1 * grime
    col = np.stack([lum, lum * 0.95, lum * 1.02], -1)
    save("lace_diff", col, alpha)


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.join(args[0] if args else os.getcwd(), "assets", "models", "enemies", "creatures", "tex")
os.makedirs(OUT, exist_ok=True)
muscle()
skin()
lace()

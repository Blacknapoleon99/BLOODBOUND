"""Generate Kimodo text-to-motion samples for every clip in a manifest.

Run with the Kimodo venv (see tools/kimodo/README.md; adapted from the Blockheads pipeline):

    TEXT_ENCODERS_DIR=D:/Tools/kimodo/text_encoders D:/Tools/kimodo/.venv/Scripts/python.exe -I \\
        tools/kimodo/kimodo_generate.py --manifest tools/kimodo/clips.json [--only slash_1] [--samples 4]

Only the Kimodo-SOMA-RP model is allowed (NVIDIA Open Model License, commercial use OK); never the
SMPLX model (non-commercial).

For each clip it writes <manifest dir>/raw/<raw_dir or name>/<raw_dir or name>_XX.npz (Kimodo NPZ, somaskel77, 30 fps).
Pick the best sample by setting "npz" in the manifest; retarget_kimodo.py reads that path.
"""

import argparse
import json
import os

import numpy as np
import torch

from kimodo import load_model
from kimodo.exports.motion_io import save_kimodo_npz
from kimodo.tools import seed_everything

MODEL = 'Kimodo-SOMA-RP-v1.2'  # NVIDIA Open Model License (commercial use OK)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--manifest', required=True)
    ap.add_argument('--only')
    ap.add_argument('--samples', type=int)
    ap.add_argument('--steps', type=int, default=100)
    a = ap.parse_args()

    mdir = os.path.dirname(os.path.abspath(a.manifest))
    specs = json.load(open(a.manifest))
    if a.only:
        keep = set(a.only.split(','))
        specs = [s for s in specs if s['name'] in keep]

    device = 'cuda:0' if torch.cuda.is_available() else 'cpu'
    model = load_model(MODEL, device=device, default_family='Kimodo')
    for s in specs:
        n = a.samples or s.get('samples', 4)
        frames = int(round(s['duration'] * model.fps))
        seed_everything(s.get('seed', 42))
        print(f"{s['name']}: '{s['prompt']}' {frames} frames x{n}")
        out = model([s['prompt']], [frames], constraint_lst=[], num_denoising_steps=a.steps, num_samples=n,
                    multi_prompt=True, post_processing=True, return_numpy=True,
                    **({'cfg_type': 'regular', 'cfg_weight': s['cfg']} if 'cfg' in s else {}))
        stem = s.get('raw_dir', s['name'])
        odir = os.path.join(mdir, 'raw', stem)
        os.makedirs(odir, exist_ok=True)
        for i in range(n):
            single = {k: (v[i] if hasattr(v, 'shape') and v.ndim > 0 and v.shape[0] == n else v) for k, v in out.items()}
            save_kimodo_npz(os.path.join(odir, f"{stem}_{i:02d}.npz"), single)
        hip = out['posed_joints'][:, :, 0]
        travel = np.linalg.norm(hip[:, -1, [0, 2]] - hip[:, 0, [0, 2]], axis=-1)
        print('   hip travel per sample (m):', np.round(travel, 2))


if __name__ == '__main__':
    main()

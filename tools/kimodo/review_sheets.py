"""Renders one Godot contact sheet per clip of the Kimodo manifest (rows = samples 00..03).

    python tools/kimodo/review_sheets.py <out dir> <library.res> [clip,clip,...] [--final]

--final renders the picked clips (no _NN suffix), 4 per sheet. Calls tools/kimodo/anim_sheet.gd.
"""
import json
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def sheet(out_png, clips, lib, frames=8, yaw=-50, sword=True):
    cmd = ['godot', '--path', REPO, '-s', 'res://tools/kimodo/anim_sheet.gd', '--', out_png, ','.join(clips),
           str(frames), lib, str(yaw)] + (['sword'] if sword else [])
    r = subprocess.run(cmd, capture_output=True, text=True)
    lines = [ln for ln in (r.stdout + r.stderr).splitlines() if 'wrote' in ln or 'ERROR' in ln or 'SCRIPT' in ln]
    print('\n'.join(lines[:4]))


def main():
    out, lib = sys.argv[1], sys.argv[2]
    rest = [a for a in sys.argv[3:] if not a.startswith('--')]
    final = '--final' in sys.argv
    specs = json.load(open(os.path.join(REPO, 'tools', 'kimodo', 'clips.json')))
    names = rest[0].split(',') if rest else [s['name'] for s in specs]
    os.makedirs(out, exist_ok=True)
    if final:
        for i in range(0, len(names), 4):
            sheet(os.path.join(out, f'final_{i // 4:02d}.png'), names[i:i + 4], lib)
        return
    for n in names:
        sheet(os.path.join(out, f'{n}.png'), [f'{n}_{k:02d}' for k in range(4)], lib)


if __name__ == '__main__':
    main()

"""Retarget Kimodo NPZ motions onto the hero's Mixamo skeleton, written for BLOODBOUND (DEC-059).

Numpy only (run with the Kimodo venv's python, isolated):

    D:/Tools/kimodo/.venv/Scripts/python.exe -I tools/kimodo/kimodo_to_hero.py \
        --glb assets/models/player/bone_revenant.glb --manifest tools/kimodo/clips.json \
        --out <dir>/hero_clips.json [--review] [--only slash_1,slash_2]

The output JSON is turned into a Godot AnimationLibrary by tools/kimodo/build_hero_library.gd.
The hero GLB is only read: its own 13 Tripo clips stay untouched.

Method (written from scratch; standard world-rotation transfer):
  * Kimodo NPZ: global joint rotations relative to the SOMA T-pose (identity joint frames), y-up,
    +z forward, 30 fps, 77 joints; the same axes as glTF.
  * Per mapped bone: target world rotation = source world rotation x swing x target world rest,
    where the swing turns the target's rest bone direction (joint -> child) onto the source's
    T-pose direction. That absorbs T-pose vs A-pose rests and different proportions.
  * Unmapped bones (cloth, sheath, finger tips) keep their rest pose relative to their parent and
    get no tracks (the cloth sim drives the cloth).
  * Fingers: both hands take the grip of a reference frame of one of the hero's own clips
    (default: the sword fist from "slash"), so the sword stays held.
  * Root: the clip is turned so the mean hip heading faces +z (the model's front); horizontal hip
    travel loses its linear drift and is centred (in place: the motor moves the body); hip height
    is scaled by the leg-length ratio; a grounding pass puts the lowest toe over the clip at the
    rest toe height. "lock_z" clips (airborne) keep the hips at rest height instead.
  * Loops cross-fade their tail into frame 0; "cycle" clips are cut to whole gait cycles.
"""

import argparse
import json
import math
import os
import struct

import numpy as np

FPS = 30

# --- SOMA 77 joint layout (Kimodo somaskel77) -----------------------------------------------------


def soma77():
    names = ['Hips', 'Spine1', 'Spine2', 'Chest', 'Neck1', 'Neck2', 'Head', 'HeadEnd', 'Jaw', 'LeftEye', 'RightEye']
    for side in ('Left', 'Right'):
        names += [f'{side}Shoulder', f'{side}Arm', f'{side}ForeArm', f'{side}Hand']
        names += [f'{side}HandThumb{i}' for i in (1, 2, 3)] + [f'{side}HandThumbEnd']
        for f in ('Index', 'Middle', 'Ring', 'Pinky'):
            names += [f'{side}Hand{f}{i}' for i in (1, 2, 3, 4)] + [f'{side}Hand{f}End']
    for side in ('Left', 'Right'):
        names += [f'{side}Leg', f'{side}Shin', f'{side}Foot', f'{side}ToeBase', f'{side}ToeEnd']
    parent = {'Spine1': 'Hips', 'Spine2': 'Spine1', 'Chest': 'Spine2', 'Neck1': 'Chest', 'Neck2': 'Neck1',
              'Head': 'Neck2', 'HeadEnd': 'Head', 'Jaw': 'Head', 'LeftEye': 'Head', 'RightEye': 'Head'}
    for s in ('Left', 'Right'):
        parent.update({f'{s}Shoulder': 'Chest', f'{s}Arm': f'{s}Shoulder', f'{s}ForeArm': f'{s}Arm',
                       f'{s}Hand': f'{s}ForeArm', f'{s}Leg': 'Hips', f'{s}Shin': f'{s}Leg', f'{s}Foot': f'{s}Shin',
                       f'{s}ToeBase': f'{s}Foot', f'{s}ToeEnd': f'{s}ToeBase'})
        for f, chain in (('Thumb', ['1', '2', '3', 'End']),) + tuple((f, ['1', '2', '3', '4', 'End']) for f in ('Index', 'Middle', 'Ring', 'Pinky')):
            prev = f'{s}Hand'
            for c in chain:
                parent[f'{s}Hand{f}{c}'] = prev
                prev = f'{s}Hand{f}{c}'
    return names, parent


SOMA, SOMA_PARENT = soma77()

# Hero bone (without "mixamorig:") -> (source joint, hero aim child, source aim child or None).
BODY_MAP = {
    'Hips': ('Hips', None, None),
    'Spine': ('Spine1', 'Spine1', 'Spine2'),
    'Spine1': ('Spine2', 'Spine2', 'Chest'),
    'Spine2': ('Chest', 'Neck', 'Neck1'),
    'Neck': ('Neck1', 'Head', 'Head'),
    'Head': ('Head', None, None),
}
for _s in ('Left', 'Right'):
    BODY_MAP.update({
        f'{_s}Shoulder': (f'{_s}Shoulder', f'{_s}Arm', f'{_s}Arm'),
        f'{_s}Arm': (f'{_s}Arm', f'{_s}ForeArm', f'{_s}ForeArm'),
        f'{_s}ForeArm': (f'{_s}ForeArm', f'{_s}Hand', f'{_s}Hand'),
        f'{_s}Hand': (f'{_s}Hand', f'{_s}HandMiddle1', f'{_s}HandMiddle2'),
        f'{_s}UpLeg': (f'{_s}Leg', f'{_s}Leg', f'{_s}Shin'),
        f'{_s}Leg': (f'{_s}Shin', f'{_s}Foot', f'{_s}Foot'),
        f'{_s}Foot': (f'{_s}Foot', f'{_s}ToeBase', f'{_s}ToeBase'),
        f'{_s}ToeBase': (f'{_s}ToeBase', f'{_s}Toe_End', f'{_s}ToeEnd'),
    })
FINGERS = [f'{s}Hand{f}{i}' for s in ('Left', 'Right') for f in ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky') for i in (1, 2, 3)]
PFX = 'mixamorig:'

# --- small math -----------------------------------------------------------------------------------


def quat_to_mat(q):  # glTF order x, y, z, w
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_to_quat(m):  # -> x, y, z, w
    t = np.trace(m)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        return np.array([(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s])
    i = int(np.argmax([m[0, 0], m[1, 1], m[2, 2]]))
    if i == 0:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        return np.array([0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s])
    if i == 1:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        return np.array([(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s])
    s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
    return np.array([(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s])


def orthonormal(m):
    u, _, vt = np.linalg.svd(m)
    return u @ vt


def swing(a, b):
    """Minimal rotation matrix taking direction a onto direction b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.9999:  # opposite: turn 180 degrees about any perpendicular axis
        p = np.cross(a, [1, 0, 0] if abs(a[0]) < 0.9 else [0, 1, 0])
        p /= np.linalg.norm(p)
        return 2 * np.outer(p, p) - np.eye(3)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def slerp(qa, qb, w):
    d = float(np.dot(qa, qb))
    if d < 0:
        qb, d = -qb, -d
    if d > 0.9995:
        q = qa + w * (qb - qa)
        return q / np.linalg.norm(q)
    th = math.acos(d)
    return (math.sin((1 - w) * th) * qa + math.sin(w * th) * qb) / math.sin(th)

# --- GLB reading ------------------------------------------------------------------------------------


def read_glb(path):
    data = open(path, 'rb').read()
    off, js, binb = 12, None, b''
    while off < len(data):
        clen, ctype = struct.unpack_from('<II', data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode('utf-8'))
        elif ctype == 0x004E4942:
            binb = chunk
        off += 8 + clen
    return js, binb


def accessor(js, binb, i):
    acc = js['accessors'][i]
    bv = js['bufferViews'][acc['bufferView']]
    comps = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[acc['type']]
    start = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    assert acc['componentType'] == 5126
    return np.frombuffer(binb[start:start + acc['count'] * comps * 4], dtype='<f4').reshape(acc['count'], comps)


class Hero:
    def __init__(self, path):
        js, binb = read_glb(path)
        self.js, self.binb = js, binb
        nodes = js['nodes']
        self.nodes = nodes
        self.index = {n['name']: i for i, n in enumerate(nodes)}
        self.parent = {c: i for i, n in enumerate(nodes) for c in n.get('children', [])}
        joints = js['skins'][0]['joints']
        self.joints = [nodes[i]['name'] for i in joints]
        self.local_r, self.local_t = {}, {}
        for n in nodes:
            self.local_r[n['name']] = quat_to_mat(n.get('rotation', [0, 0, 0, 1]))
            self.local_t[n['name']] = np.array(n.get('translation', [0, 0, 0]), dtype=np.float64)
        self.world_r, self.world_t = {}, {}
        for name in self.joints:
            self._world(name)
        # parent-first order
        self.order = sorted(self.joints, key=self.depth)

    def pname(self, name):
        i = self.index[name]
        return self.nodes[self.parent[i]]['name'] if i in self.parent else None

    def depth(self, name):
        d, p = 0, self.pname(name)
        while p is not None:
            d, p = d + 1, self.pname(p)
        return d

    def _world(self, name):
        if name in self.world_r:
            return self.world_r[name], self.world_t[name]
        p = self.pname(name)
        if p is None:
            r, t = np.eye(3), np.zeros(3)
        else:
            r, t = self._world(p)
        wr = r @ self.local_r[name]
        wt = t + r @ self.local_t[name]
        self.world_r[name], self.world_t[name] = wr, wt
        return wr, wt

    def clip_rotation(self, clip, node, at):
        """Local rotation (3x3) of `node` in the hero's own clip at fraction `at` (nearest key)."""
        for a in self.js['animations']:
            if a['name'] != clip:
                continue
            for c in a['channels']:
                if c['target']['path'] == 'rotation' and self.nodes[c['target']['node']]['name'] == node:
                    s = a['samplers'][c['sampler']]
                    tm = accessor(self.js, self.binb, s['input'])[:, 0]
                    vals = accessor(self.js, self.binb, s['output'])
                    k = int(np.argmin(np.abs(tm - tm[-1] * at)))
                    return quat_to_mat(vals[k])
        return None

# --- retarget -----------------------------------------------------------------------------------------


def load_npz(path):
    d = np.load(path)
    P = d['posed_joints'].astype(np.float64)
    R = d['global_rot_mats'].astype(np.float64)
    assert P.shape[1] == 77, f'{path}: expected somaskel77'
    idx = {n: i for i, n in enumerate(SOMA)}
    rest_abs = {'Hips': np.zeros(3)}
    for n in SOMA[1:]:
        p = SOMA_PARENT[n]
        rest_abs[n] = rest_abs[p] + R[0, idx[p]].T @ (P[0, idx[n]] - P[0, idx[p]])
    contacts = d['foot_contacts'] if 'foot_contacts' in d.files else None
    return dict(R=R, P=P, idx=idx, rest=rest_abs, contacts=contacts)


def cut_cycle(spec, contacts, T):
    heel = contacts[:, 0].astype(bool).copy()
    for t in range(1, len(heel) - 3):  # fill 1-3 frame flickers
        if heel[t - 1] and not heel[t] and heel[t + 1:t + 4].any():
            heel[t] = True
    onsets = [t for t in range(1, len(heel)) if heel[t] and not heel[t - 1] and t >= spec.get('cycle_skip', 15)]
    n = spec.get('cycles', 1)
    if len(onsets) < n + 1:
        raise ValueError(f"{spec['name']}: not enough heel strikes {onsets}")
    k = (len(onsets) - n - 1) // 2
    return onsets[k], onsets[k + n] + 1


def retarget(hero, clip, spec, fingers):
    R, P, idx, srest = clip['R'], clip['P'], clip['idx'], clip['rest']
    t0, t1 = spec.get('trim_start', 0), R.shape[0] - spec.get('trim_end', 0)
    if spec.get('cycle'):
        t0, t1 = cut_cycle(spec, clip['contacts'], R.shape[0])
    R, P = R[t0:t1].copy(), P[t0:t1].copy()
    T = R.shape[0]
    hip = idx['Hips']
    # Face +z: mean hip forward (+z in the SOMA T-pose frame).
    # Once clips that turn the body over (flips, rolls) use the stance of their first frames.
    hf = spec.get('heading_frames', 0)
    fwd = (R[:hf, hip] if hf else R[:, hip]) @ np.array([0, 0, 1.0])
    yaw = math.atan2(fwd[:, 0].mean(), fwd[:, 2].mean()) + math.radians(spec.get('yaw_offset_deg', 0))
    turn = rot_y(-yaw)
    R = np.einsum('ab,tjbc->tjac', turn, R)
    P = P @ turn.T

    def hb(n):
        return PFX + n

    # Swing corrections.
    A = {}
    for tb, (sj, tc, sc) in BODY_MAP.items():
        if hb(tb) not in hero.world_r:
            continue
        if tc and sc and hb(tc) in hero.world_t:
            A[tb] = swing(hero.world_t[hb(tc)] - hero.world_t[hb(tb)], srest[sc] - srest[sj])
        else:
            A[tb] = np.eye(3)

    leg_s = np.linalg.norm(srest['LeftShin'] - srest['LeftLeg']) + np.linalg.norm(srest['LeftFoot'] - srest['LeftShin'])
    leg_t = (np.linalg.norm(hero.world_t[hb('LeftLeg')] - hero.world_t[hb('LeftUpLeg')])
             + np.linalg.norm(hero.world_t[hb('LeftFoot')] - hero.world_t[hb('LeftLeg')]))
    scale = leg_t / leg_s
    src_hip_h = srest['Hips'][1] - srest['LeftToeBase'][1]
    toes = [idx['LeftToeBase'], idx['RightToeBase']]
    floor = np.percentile(P[:, toes, 1].min(axis=1), 5)
    hp = P[:, hip].copy()
    xz = hp[:, [0, 2]]
    xz = xz - (xz[-1] - xz[0]) * np.linspace(0, 1, T)[:, None]
    xz = xz - xz.mean(axis=0)
    if spec.get('lock_xy'):
        xz[:] = 0
    travel = np.linalg.norm(hp[-1, [0, 2]] - hp[0, [0, 2]]) * scale / max(1e-6, (T - 1) / FPS)
    dy = hp[:, 1] - (floor + src_hip_h)
    if spec.get('lock_z'):
        dy[:] = 0.0
    hips_world = hero.world_t[hb('Hips')] + np.column_stack([xz[:, 0], dy, xz[:, 1]]) * scale

    # World rotations of every hero joint, parent first.
    W = {}
    for name in hero.order:
        short = name[len(PFX):] if name.startswith(PFX) else None
        p = hero.pname(name)
        if short in A:
            W[name] = np.einsum('tab,bc,cd->tad', R[:, idx[BODY_MAP[short][0]]], A[short], hero.world_r[name])
        elif short in fingers and p in W:
            W[name] = np.einsum('tab,bc->tac', W[p], fingers[short])
        elif p in W:
            W[name] = np.einsum('tab,bc->tac', W[p], hero.local_r[name])
        else:
            W[name] = np.repeat(hero.world_r[name][None], T, axis=0)

    def fk(names):
        pos = {}
        for name in hero.order:
            p = hero.pname(name)
            if name == hb('Hips'):
                pos[name] = hips_world.copy()
            elif p in pos:
                pos[name] = pos[p] + np.einsum('tab,b->ta', W[p], hero.local_t[name])
        return {n: pos[n] for n in names}

    if not spec.get('lock_z') and not spec.get('no_ground'):
        toe_names = [hb('LeftToeBase'), hb('RightToeBase')]
        tp = fk(toe_names)
        rest_y = min(hero.world_t[n][1] for n in toe_names)
        low = min(tp[n][:, 1].min() for n in toe_names)
        hips_world[:, 1] += rest_y - low

    # Local tracks.
    tracks = {}
    for name in hero.order:
        short = name[len(PFX):] if name.startswith(PFX) else None
        if short is None or not (short in A or short in fingers):
            continue  # cloth, sheath, finger tips: no tracks (rest / cloth sim)
        p = hero.pname(name)
        Wp = W[p] if p in W else np.repeat(hero.world_r[p][None], T, axis=0) if p else np.repeat(np.eye(3)[None], T, axis=0)
        L = np.einsum('tba,tbc->tac', Wp, W[name])
        q = np.array([mat_to_quat(orthonormal(L[t])) for t in range(T)])
        for t in range(1, T):
            if np.dot(q[t], q[t - 1]) < 0:
                q[t] = -q[t]
        tracks[name] = {'rot': q}
    hp_name = hb('Hips')
    pr, pt = hero._world(hero.pname(hp_name))
    tracks[hp_name]['pos'] = (hips_world - pt) @ pr  # into the parent's space (rows: pr^T v)

    if spec.get('loop'):
        n = min(spec.get('blend_frames', 12), T // 3)
        for k in range(n):
            w = (k + 1) / n
            w = w * w * (3 - 2 * w)
            t = T - n + k
            for tr in tracks.values():
                tr['rot'][t] = slerp(tr['rot'][t], tr['rot'][0], w)
                if 'pos' in tr:
                    tr['pos'][t] = tr['pos'][t] * (1 - w) + tr['pos'][0] * w
        for tr in tracks.values():
            tr['rot'][-1] = tr['rot'][0]
            if 'pos' in tr:
                tr['pos'][-1] = tr['pos'][0]

    # Sword-hand timing: speed of the right hand's tip (the sword grip) over the clip.
    hand = fk([hb('RightHandMiddle1')])[hb('RightHandMiddle1')]
    v = np.linalg.norm(np.diff(hand, axis=0), axis=1) * FPS
    v = np.convolve(v, np.ones(3) / 3, mode='same')
    peak = int(np.argmax(v))
    above = np.nonzero(v > 0.25 * v[peak])[0]
    meta = {'frames': T, 'length': (T - 1) / FPS, 'strike': (peak + 1) / FPS,
            'motion_start': float(above[0]) / FPS if len(above) else 0.0,
            'motion_end': float(above[-1] + 1) / FPS if len(above) else (T - 1) / FPS,
            'hand_peak_speed': float(v[peak]), 'treadmill_speed': float(travel), 'source_frames': [int(t0), int(t1)]}
    return tracks, meta, T


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--glb', required=True)
    ap.add_argument('--manifest', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--only')
    ap.add_argument('--review', action='store_true', help='every raw sample as <name>_<NN>')
    ap.add_argument('--fingers', default='slash@0.45', help='hero clip@fraction whose finger pose is kept')
    a = ap.parse_args()
    mdir = os.path.dirname(os.path.abspath(a.manifest))
    specs = json.load(open(a.manifest))
    if a.only:
        keep = set(a.only.split(','))
        specs = [s for s in specs if s['name'] in keep]
    if a.review:
        expanded = []
        for s in specs:
            stem = s.get('raw_dir', s['name'])
            for f in sorted(os.listdir(os.path.join(mdir, 'raw', stem))):
                if f.endswith('.npz'):
                    expanded.append({**s, 'name': f"{s['name']}_{f[:-4].rsplit('_', 1)[1]}", 'npz': f'raw/{stem}/{f}'})
        specs = expanded
    hero = Hero(a.glb)
    clip_name, at = a.fingers.split('@')
    fingers = {}
    for f in FINGERS:
        m = hero.clip_rotation(clip_name, PFX + f, float(at))
        fingers[f] = m if m is not None else hero.local_r[PFX + f]
    out = {'fps': FPS, 'clips': []}
    for s in specs:
        if 'npz' not in s:
            print(f"skip {s['name']}: no npz picked")
            continue
        tracks, meta, T = retarget(hero, load_npz(os.path.join(mdir, s['npz'])), s, fingers)
        print(f"{s['name']}: {T} frames ({meta['length']:.2f}s) strike {meta['strike']:.2f}s "
              f"motion {meta['motion_start']:.2f}-{meta['motion_end']:.2f}s travel {meta['treadmill_speed']:.2f} m/s")
        out['clips'].append({'name': s['name'], 'loop': bool(s.get('loop')), 'meta': meta,
                             'tracks': {n: {k: np.round(v, 6).tolist() for k, v in tr.items()} for n, tr in tracks.items()}})
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    json.dump(out, open(a.out, 'w'))
    print('wrote', a.out, len(out['clips']), 'clips')


if __name__ == '__main__':
    main()

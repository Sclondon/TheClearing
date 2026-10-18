"""Builds the brachiosaurus (creatures/brachiosaurus) and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/brachiosaurus/tools/build_brachiosaurus.py
    blender --background --python creatures/brachiosaurus/tools/build_brachiosaurus.py -- <preview folder>   # with pictures and a .blend

Writes creatures/brachiosaurus/models/brachiosaurus.glb and a demade
brachiosaurus_lo.glb. Nothing else is written (an editable .blend goes to the
preview folder, when there is one; this folder has a .gdignore so that Godot
does not try to import anything here).

It is Brachiosaurus altithorax as it is drawn now, at its real size (metres):
about 21 m from snout to tail tip, the shoulders 6.6 m up and the hips well
below them (the forelimbs longer than the hind, so that the back slopes down to
the tail), the neck held high, the head 13 m up. Columnar legs like an
elephant's: the forefeet a tall horseshoe of bones with one claw on the thumb;
the hind feet broad pads with three claws on the inner toes. A short, deep tail
for a sauropod, held clear of the ground. A small head on the long neck: a
broad, blunt muzzle with spoon-like teeth along its edges, the eye high at the
back, and the arch of the nasal crest rising in front of the eyes, the nostrils
low on the snout in front of it.

Its hide is wrinkled, of small pebbly scales (the skin shader draws them from
the first texture coordinates: metres along it and round it), dull grey, darker
over the back and paler underneath, mottled.

The bones (the rig, creatures/brachiosaurus/brachiosaurus_rig.gd, poses them):
`body` with `chest` and `pelvis` under it; `neck`, `neck_1`, `neck_2`,
`neck_3`, `head` and `jaw` from the chest; the tail, `tail` to `tail_5` (and
`tail_end`), from the pelvis; and each leg, from `body`, three bones and a foot:

    fore: `upper` (shoulder to elbow), `lower` (forearm), `hock` (wrist to the foot), `hoof`
    hind: `upper` (thigh, hip to knee), `lower` (shank), `hock` (ankle to the foot), `hoof`

Two materials, so that it is two draws: `skin` (its vertex colours: red how
open the surface is, dark in creases; green its darker mottling; blue how pale,
underneath) and `parts` (eyes, claws, teeth, the mouth, the nostrils: colour in
the vertex colours, alpha how wet).

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
GAME = os.path.dirname(os.path.dirname(COMPONENT))
sys.path.insert(0, os.path.join(GAME, "tools"))
import build_character as kit  # noqa: E402  (the character controller's shape-building tools)

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
SUFFIXES = ("_fl", "_fr", "_rl", "_rr")
OUT = os.path.join(COMPONENT, "models")


def V(x, y, z):
    return Vector((x, y, z))


# --- How it is built ---

BODY = V(0.0, 5.0, 0.3)
CHEST = V(0.0, 5.4, 2.3)
PELVIS = V(0.0, 4.6, -2.3)
# The neck: its base deep in the shoulders, rising steeply, and the head on it.
NECK_JOINTS = [V(0.0, 6.0, 3.4), V(0.0, 7.95, 4.85), V(0.0, 9.85, 6.05), V(0.0, 11.55, 7.0), V(0.0, 12.85, 7.6)]
NECK, NECK_1, NECK_2, NECK_3, HEAD = NECK_JOINTS
NECK_BONES = ["neck", "neck_1", "neck_2", "neck_3", "head"]

# (along the body, centre height, half width, half height): deepest at the
# belly, the back high over the shoulders and sloping down to the hips
TRUNK = [(-3.6, 4.60, 0.80, 0.80), (-3.0, 4.62, 1.02, 1.04), (-2.2, 4.66, 1.20, 1.22), (-1.2, 4.72, 1.38, 1.42),
         (0.0, 4.86, 1.50, 1.56), (1.2, 5.08, 1.50, 1.56), (2.2, 5.30, 1.38, 1.44), (3.0, 5.52, 1.16, 1.24),
         (3.7, 5.86, 0.86, 0.98)]

# Shoulder, elbow, wrist, foot; hip, knee, ankle, foot (the left legs: the right are their mirror)
FORE = [V(0.95, 5.25, 2.65), V(1.02, 3.30, 2.42), V(1.0, 1.12, 2.58), V(1.0, 0.36, 2.62)]
HIND = [V(0.92, 4.45, -2.30), V(1.0, 2.62, -2.02), V(1.0, 0.84, -2.36), V(1.0, 0.30, -2.22)]
# (how far down the leg, counted in joints; half width; half depth; forward offset)
FORE_SHAPE = [(0.05, 0.50, 0.66, 0.02), (0.45, 0.47, 0.56, 0.04), (0.9, 0.41, 0.46, 0.02),
              (1.0, 0.40, 0.44, 0.0), (1.5, 0.35, 0.38, 0.01), (1.9, 0.32, 0.34, 0.0), (2.1, 0.325, 0.345, 0.0),
              (2.5, 0.35, 0.37, 0.01), (2.85, 0.39, 0.41, 0.02), (3.2, 0.41, 0.43, 0.02), (3.45, 0.41, 0.43, 0.02)]
HIND_SHAPE = [(0.05, 0.62, 0.86, -0.02), (0.4, 0.58, 0.76, 0.02), (0.85, 0.47, 0.55, 0.04),
              (1.0, 0.45, 0.51, 0.04), (1.5, 0.39, 0.44, 0.0), (1.9, 0.37, 0.40, 0.0), (2.1, 0.38, 0.41, 0.01),
              (2.5, 0.43, 0.47, 0.03), (2.85, 0.49, 0.54, 0.05), (3.2, 0.53, 0.58, 0.06), (3.45, 0.53, 0.58, 0.06)]

# The tail: its joints (tail, tail_1 .. tail_5, its end), held up clear of
# the ground and drooping, and how thick it is at each (half width, half height).
TAIL = [V(0.0, 4.62, -3.4), V(0.0, 4.42, -4.75), V(0.0, 4.05, -6.05), V(0.0, 3.55, -7.3),
        V(0.0, 3.00, -8.5), V(0.0, 2.45, -9.65), V(0.0, 1.95, -10.75)]
TAIL_SHAPE = [(0.86, 0.92), (0.64, 0.70), (0.47, 0.52), (0.34, 0.38), (0.24, 0.27), (0.15, 0.17), (0.07, 0.08)]
TAIL_BONES = ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5"]

# The neck: (along from its base to the head, half width, half height: deeper
# than wide, the cervical ribs under it), and how far its middle hangs below the line.
NECK_SHAPE = [(-0.12, 0.90, 1.02, 0.0), (0.0, 0.84, 0.98, 0.05), (0.12, 0.66, 0.80, 0.10), (0.3, 0.52, 0.64, 0.08),
              (0.55, 0.42, 0.52, 0.05), (0.8, 0.34, 0.42, 0.03), (0.95, 0.30, 0.36, 0.01), (1.04, 0.28, 0.33, 0.0)]

# The skull, from HEAD: held level and a little down at the end of the neck.
SNOUT_WAY = V(0.0, -0.30, 0.95).normalized()
SNOUT_UP = V(0.0, SNOUT_WAY.z, -SNOUT_WAY.y)
# (along it, half width, half height, how far up its middle is)
SKULL = [(-0.05, 0.22, 0.25, 0.03), (0.08, 0.26, 0.30, 0.05), (0.20, 0.255, 0.30, 0.04), (0.34, 0.235, 0.25, 0.0),
         (0.48, 0.225, 0.21, -0.04), (0.62, 0.225, 0.18, -0.07), (0.73, 0.215, 0.155, -0.085), (0.80, 0.185, 0.13, -0.09)]
# The lower jaw: from its hinge low at the back of the skull.
JAW = HEAD + SNOUT_WAY * 0.02 - SNOUT_UP * 0.18
JAW_WAY = (SNOUT_WAY * 0.97 - SNOUT_UP * 0.06).normalized()
JAW_UP = V(0.0, JAW_WAY.z, -JAW_WAY.y)
# (along it, half width, half height, how far below the line its middle is)
JAW_SHAPE = [(-0.04, 0.19, 0.10, 0.0), (0.15, 0.19, 0.09, 0.0), (0.32, 0.185, 0.075, 0.0),
             (0.48, 0.18, 0.07, -0.005), (0.62, 0.175, 0.065, -0.005), (0.74, 0.16, 0.055, 0.0)]
EYE = (0.11, 0.12, 0.062)  # (along, up from the middle, radius)
# The nasal crest: an arch of bone in skin rising over the snout in front of the eyes.
CREST = [(0.12, 0.26, 0.17), (0.20, 0.36, 0.20), (0.29, 0.40, 0.20), (0.38, 0.36, 0.18), (0.47, 0.27, 0.15), (0.56, 0.16, 0.10)]


def legs():
    made = {}
    for suffix in SUFFIXES:
        side = 1.0 if suffix[2] == "l" else -1.0
        made[suffix] = [V(j.x * side, j.y, j.z) for j in (FORE if suffix[1] == "f" else HIND)]
    return made


LEGS = legs()


def skull_ring(t):
    rings = SKULL
    if t <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if t <= b[0]:
            u = (t - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * u for k in (1, 2, 3))
    return rings[-1][1:]


def skull_at(t):
    return HEAD + SNOUT_WAY * t + SNOUT_UP * skull_ring(t)[2]


def ring_at(rings, z):
    if z <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return rings[-1][1:]


def smooth_rings(rings, step):
    """More rings, every `step` along, on smooth curves through those given (Catmull-Rom)."""
    made = []
    for i in range(len(rings) - 1):
        r0, r1, r2 = rings[max(i - 1, 0)], rings[i], rings[i + 1]
        r3 = rings[min(i + 2, len(rings) - 1)]
        count = max(int(math.ceil((r2[0] - r1[0]) / step)), 1)
        for k in range(count):
            t = k / count
            t2, t3 = t * t, t * t * t
            made.append(tuple(0.5 * (2 * r1[c] + (-r0[c] + r2[c]) * t + (2 * r0[c] - 5 * r1[c] + 4 * r2[c] - r3[c]) * t2
                                     + (-r0[c] + 3 * r1[c] - 3 * r2[c] + r3[c]) * t3) for c in range(len(r1))))
    made.append(rings[-1])
    return made


def neck_point(t):
    """A point `t` of the way along the neck's joints (0 its base, 1 the head)."""
    t = min(max(t, 0.0), 1.0) * (len(NECK_JOINTS) - 1)
    i = min(int(t), len(NECK_JOINTS) - 2)
    return NECK_JOINTS[i].lerp(NECK_JOINTS[i + 1], t - i)


def neck_ring(t):
    rings = NECK_SHAPE
    if t <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if t <= b[0]:
            u = (t - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * u for k in (1, 2, 3))
    return rings[-1][1:]


# The line down the middle of it, tail tip to snout, for its texture
# coordinates and its shading: (point, about how thick it is there).
def spine_line():
    line = []
    for j, (w, h) in list(zip(TAIL, TAIL_SHAPE))[::-1]:
        line.append((j, (w + h) * 0.5))
    for z, y, w, h in TRUNK:
        if z > TAIL[0].z and z < NECK.z:
            line.append((V(0.0, y, z), (w + h) * 0.5))
    for k in range(11):
        t = k / 10.0
        w, h, _ = neck_ring(t)
        line.append((neck_point(t) - V(0.0, neck_ring(t)[2], 0.0), (w + h) * 0.5))
    for t in (0.2, 0.45, 0.7, 0.93):
        rx, ry, _ = skull_ring(t)
        line.append((skull_at(t), (rx + ry) * 0.5))
    return line


SPINE = spine_line()


def on_spine(p):
    """The nearest point on the line down its middle: (how far along it, m; the
    point; the way along there; how thick it is there)."""
    best = None
    walked = 0.0
    for (a, ra), (b, rb) in zip(SPINE, SPINE[1:]):
        ab = b - a
        t = min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)
        at = a + ab * t
        d = (p - at).length
        if best is None or d < best[0]:
            best = (d, walked + ab.length * t, at, ab.normalized(), ra + (rb - ra) * t)
        walked += ab.length
    return best[1:]


def chain_param(p, joints):
    best = (1e9, 0.0)
    for i in range(len(joints) - 1):
        a, b = joints[i], joints[i + 1]
        ab = b - a
        t = min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)
        d = (p - (a + ab * t)).length
        if d < best[0]:
            best = (d, i + t)
    return best


def leg_share(p):
    """Which leg a point is nearest, and how much of it hangs from that leg rather than the trunk."""
    fore = p.z > 0.2
    suffix = ("_f" if fore else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = LEGS[suffix]
    top = joints[0]
    off = chain_param(V(top.x, p.y, p.z), joints)[0]
    side = abs(p.x - top.x)
    inner = abs(p.x)
    if fore:
        return suffix, blend(top.y - 0.2, top.y - 1.1, p.y) * blend(0.95, 0.65, math.hypot(side, off / 1.5)) * blend(top.x - 0.55, top.x - 0.3, inner)
    return suffix, blend(top.y - 0.3, top.y - 1.4, p.y) * blend(1.15, 0.8, math.hypot(side, off / 1.5)) * blend(top.x - 0.6, top.x - 0.35, inner)


def leg_axis(joints, y):
    for a, b in zip(joints, joints[1:]):
        if y >= b.y:
            return a.z + (b.z - a.z) * min(max((a.y - y) / (a.y - b.y), 0.0), 1.0)
    return joints[-1].z


def around_of(p, at, way):
    """The angle round the line down its middle at `at` (going `way`) that `p` is at."""
    side = way.cross(Y).normalized() if abs(way.y) < 0.95 else X
    if side.dot(X) < 0.0:
        side = -side
    up = side.cross(way).normalized()
    if up.y < 0.0:
        up = -up
    d = p - at
    return math.atan2(d.dot(side), d.dot(up))


def lay_skin(bm):
    """The texture coordinates the skin shader draws its scales from: (along
    it, round it), in metres: along the middle of it from the tail tip to the
    snout, and down each leg."""
    uv = bm.loops.layers.uv.verify()

    def unwrap(angle, near):
        return near + (angle - near + math.pi) % math.tau - math.pi

    for face in bm.faces:
        near = kit.from_blender(face.calc_center_median())
        suffix, near_leg_share = leg_share(near)
        # (each face on the leg or the trunk, not between: a fold, not a smear)
        on_leg = near_leg_share > 0.5
        joints = LEGS[suffix]
        hip = joints[0]
        out = 1.0 if hip.x > 0.0 else -1.0
        _, n_at, n_way, _ = on_spine(near)
        near_round = around_of(near, n_at, n_way)
        near_leg = math.atan2(near.z - leg_axis(joints, near.y), (near.x - hip.x) * out)
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            leg = leg_share(p)[1]
            along, at, way, radius = on_spine(p)
            trunk = (along, unwrap(around_of(p, at, way), near_round) * radius)
            limb_uv = (hip.y - p.y - hip.z, unwrap(math.atan2(p.z - leg_axis(joints, p.y), (p.x - hip.x) * out), near_leg) * 0.45)
            loop[uv].uv = limb_uv if on_leg else trunk


def skinned(b, fuse):
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, 0.0)  # nothing goes through the ground
    mesh = kit.fused(b, None if kit.LOW else fuse)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    lay_skin(bm)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def limb(b, joints, stations, segments=12):
    directions = [(q - p).normalized() for p, q in zip(joints, joints[1:])]
    last = len(directions) - 1
    rings = []
    for s, rx, rd, shift in stations:
        i = min(max(int(math.floor(s)), 0), last)
        t = s - i
        point = joints[i] + (joints[i + 1] - joints[i]) * t
        if t < 0.5:
            ahead = directions[max(i - 1, 0)].lerp(directions[i], min(0.5 + t, 1.0))
        else:
            ahead = directions[i].lerp(directions[min(i + 1, last)], min(t - 0.5, 1.0))
        across = ahead.normalized().cross(X).normalized()
        rings.append((point + across * shift, X * rx, across * rd))
    # (the sole: flat on the ground)
    b.tube(dome(rings[0], -directions[0], 0.2)[::-1] + rings + dome(rings[-1], directions[-1], 0.05, 2), segments)


def body():
    """The trunk, the tail, the neck and the legs, fused into one hide."""
    def shapes(b):
        low = kit.LOW
        b.tube([kit.lengthwise(*ring) for ring in smooth_rings(TRUNK, 0.3)], 28)
        # The tail, on from the hips to its tip
        tail = [(j, X * w, Y * h) for j, (w, h) in zip(TAIL, TAIL_SHAPE)]
        b.tube([(TAIL[0] + V(0.0, 0.0, 0.8), X * 0.95, Y * 1.0)] + tail + dome(tail[-1], (TAIL[-1] - TAIL[-2]).normalized(), 0.1, 2), 18)
        # The neck, up and forward from the shoulders to the head
        neck = []
        steps = [k / 16.0 for k in range(-2, 17)] + [1.04]
        for t in steps:
            rx, ry, sag = neck_ring(t)
            at = neck_point(t) if t >= 0.0 else NECK + (NECK - NECK_1).normalized() * (-t * 6.0)
            way = (neck_point(min(t + 0.05, 1.0)) - neck_point(max(t - 0.05, 0.0))).normalized()
            up = way.cross(X).normalized() * -1.0
            if up.y < 0.0:
                up = -up
            neck.append((at - up * sag, X * rx, up * ry))
        b.tube(neck + dome(neck[-1], (NECK_JOINTS[-1] - NECK_JOINTS[-2]).normalized(), 0.2, 3), 18)
        for side in (1.0, -1.0):
            # The great muscles over the shoulders and the thighs; the base of the tail
            b.ellipsoid(V(side * 0.88, 4.95, 2.55), V(0.48, 0.95, 0.78), Matrix.Rotation(0.15, 3, "X"), 20, 10)
            b.ellipsoid(V(side * 0.86, 4.15, -2.25), V(0.52, 1.05, 0.95), Matrix.Rotation(-0.12, 3, "X"), 20, 10)
            b.ellipsoid(V(side * 0.55, 4.45, -3.6), V(0.45, 0.62, 0.9), Matrix.Rotation(-0.1, 3, "X"), 16, 8)
            # (the deep ribcage and belly of a plant-eater)
            b.ellipsoid(V(side * 0.45, 4.55, 0.4), V(1.0, 1.15, 2.1), None, 24, 12)
        # (the deep chest in front of the shoulders, up into the base of the neck)
        b.ellipsoid(V(0.0, 5.75, 3.25), V(0.95, 1.25, 1.05), Matrix.Rotation(0.5, 3, "X"), 24, 12)
        for suffix, joints in LEGS.items():
            limb(b, joints, FORE_SHAPE if suffix[1] == "f" else HIND_SHAPE, 16 if not low else 12)
        return skinned(b, (0.07, 4, 34000))
    return shapes


def head():
    """The small head: a broad, blunt muzzle, the crest arching over it in front of the eyes."""
    def shapes(b):
        rings = [(skull_at(t), X * rx, SNOUT_UP * ry) for t, rx, ry, _ in SKULL]
        b.tube(dome(rings[0], -SNOUT_WAY, 0.08, 3)[::-1] + rings + dome(rings[-1], SNOUT_WAY, 0.07, 3), 18)
        # The arch of the crest over the snout
        crest = []
        for t, up, half in CREST:
            crest.append((HEAD + SNOUT_WAY * t + SNOUT_UP * up, X * half, SNOUT_UP * half * 0.8))
        b.tube(dome(crest[0], -SNOUT_WAY, 0.04, 2)[::-1] + crest + dome(crest[-1], SNOUT_WAY, 0.04, 2), 12)
        for side in (1.0, -1.0):
            # (the ridge over each eye, the cheek over the teeth)
            b.ellipsoid(HEAD + SNOUT_WAY * 0.06 + SNOUT_UP * 0.17 + X * side * 0.17, V(0.08, 0.05, 0.11), None, 10, 5)
            b.ellipsoid(HEAD + SNOUT_WAY * 0.40 - SNOUT_UP * 0.10 + X * side * 0.15, V(0.07, 0.08, 0.24), Matrix.Rotation(0.3, 3, "X"), 10, 5)
        return skinned(b, (0.02, 3, 6000))
    return shapes


def jaw():
    def shapes(b):
        rings = [(JAW + JAW_WAY * t - JAW_UP * drop, X * rx, JAW_UP * ry) for t, rx, ry, drop in JAW_SHAPE]
        b.tube(dome(rings[0], -JAW_WAY, 0.05, 2)[::-1] + rings + dome(rings[-1], JAW_WAY, 0.05, 3), 14)
        return skinned(b, (0.02, 2, 2400))
    return shapes


def teeth(jaw_side):
    """Spoon-like teeth along the front of the upper jaw (0) or the lower (1), showing at the lips."""
    def shapes(b):
        count = 9 if not kit.LOW else 5
        if True:
            for side in (1.0, -1.0):
                for k in range(count):
                    u = k / (count - 1)
                    # (round the broad front of the muzzle and back along each side)
                    angle = u * 1.25
                    if jaw_side == 0:
                        t = 0.80 - (1.0 - math.cos(angle)) * 0.5
                        rx, ry, up = skull_ring(t)
                        at = HEAD + SNOUT_WAY * t + SNOUT_UP * (up - ry * 0.92) + X * side * rx * 0.9 * math.sin(angle + 0.25)
                        down = -SNOUT_UP
                    else:
                        t = 0.73 - (1.0 - math.cos(angle)) * 0.5
                        at = JAW + JAW_WAY * t + JAW_UP * 0.055 + X * side * 0.14 * math.sin(angle + 0.25)
                        down = JAW_UP
                    b.ellipsoid(at + down * 0.012, V(0.014, 0.026, 0.011), Matrix.Rotation(-0.3 if jaw_side == 0 else 0.3, 3, "X"), 6, 3)
    return shapes


def mouth():
    """The dark inside of its mouth, seen when the jaw drops."""
    def shapes(b):
        b.ellipsoid(JAW + JAW_WAY * 0.4 + JAW_UP * 0.05, V(0.13, 0.04, 0.3), None, 10, 5)
    return shapes


def nostrils():
    def shapes(b):
        for side in (1.0, -1.0):
            at = skull_at(0.70) + SNOUT_UP * 0.05 + X * side * 0.17
            b.ellipsoid(at, V(0.035, 0.022, 0.05), Matrix.Rotation(-side * 0.4, 3, "Y"), 8, 4)
    return shapes


def eyes():
    def shapes(b):
        t, up, radius = EYE
        for side in (1.0, -1.0):
            rx = skull_ring(t)[0]
            at = HEAD + SNOUT_WAY * t + SNOUT_UP * up + X * side * (rx * 0.9)
            b.ellipsoid(at, V(radius * 0.7, radius * 0.8, radius), Matrix.Rotation(-side * 0.5, 3, "Y"), 8, 5)
    return shapes


def claws():
    """The thumb claw on the inside of each forefoot, and three claws on the inner
    toes of each hind foot, curved down and out."""
    def shapes(b):
        for suffix, joints in LEGS.items():
            foot = joints[3]
            fore = suffix[1] == "f"
            side = 1.0 if suffix[2] == "l" else -1.0
            if fore:
                # (on the inside of the horseshoe, pointing in and forward)
                root = foot + V(-side * 0.30, -0.13, 0.26)
                b.strand([root, root + V(-side * 0.07, -0.05, 0.14), root + V(-side * 0.1, -0.17, 0.22)], [0.07, 0.045, 0.01], 8)
                # (the blunt ends of the bones of the horseshoe, round the front of the sole)
                for k, a in enumerate((-0.9, -0.3, 0.3, 0.9)):
                    at = foot + V(math.sin(a) * 0.37, -0.27, math.cos(a) * 0.37 + 0.03)
                    b.ellipsoid(at, V(0.08, 0.06, 0.06), Matrix.Rotation(a, 3, "Y"), 8, 4)
            else:
                for k, a in enumerate((-0.25, 0.25, 0.75)):
                    angle = -side * a
                    root = foot + V(math.sin(angle) * 0.5, -0.14, math.cos(angle) * 0.5 + 0.08)
                    way = V(math.sin(angle - side * 0.35), -0.35, math.cos(angle - side * 0.35)).normalized()
                    size = 0.085 - 0.015 * k
                    b.strand([root, root + way * 0.12, root + way * 0.2 + V(0.0, -0.07, 0.0)], [size, size * 0.6, 0.012], 8)
    return shapes


def coat_weights(p):
    """Which bones the hide at `p` hangs from (not the legs: see `weights`)."""
    names = ["pelvis"] + TAIL_BONES
    off, along = chain_param(p, TAIL)
    if p.z < TAIL[0].z + 0.4:
        past = [1.0, blend(-0.4, 0.4, along)] + [blend(k - 0.4, k + 0.4, along) for k in range(1, len(TAIL_BONES))] + [0.0]
        return {name: past[i] - past[i + 1] for i, name in enumerate(names) if past[i] - past[i + 1] > 0.0}
    if p.z > NECK.z - 0.9 and p.y > 5.0:
        off, along = chain_param(p, NECK_JOINTS)
        # (how far along it, in joints: 0 its base, 4 the head)
        names = ["chest"] + NECK_BONES
        past = [1.0, blend(-0.35, 0.35, along)] + [blend(k - 0.35, k + 0.35, along) for k in range(1, len(NECK_BONES) - 1)]
        past += [blend(3.75, 3.98, along), 0.0]
        return {name: past[i] - past[i + 1] for i, name in enumerate(names) if past[i] - past[i + 1] > 0.0}
    front = blend(-1.2, 2.0, p.z)
    return {"chest": front, "pelvis": 1.0 - front}


def weights():
    def weigh(part, p):
        if part in ("jaw", "mouth", "teeth_low"):
            return {"jaw": 1.0}
        if part in ("head", "eyes", "nostrils", "teeth"):
            return {"head": 1.0}
        if part == "claws":
            suffix = ("_f" if p.z > 0.2 else "_r") + ("l" if p.x >= 0.0 else "r")
            return {"hoof" + suffix: 1.0}
        trunk = coat_weights(p)
        suffix, leg = leg_share(p)
        if leg <= 0.0:
            return trunk
        joints = LEGS[suffix]
        along = chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.25 / spans[0], 1.0 + 0.25 / spans[1], along)
        hock = blend(2.0 - 0.18 / spans[1], 2.0 + 0.18 / spans[2], along)
        hoof = blend(joints[3].y + 0.25, joints[3].y + 0.05, p.y)
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + suffix] = leg * (1.0 - low)
        made["lower" + suffix] = leg * low * (1.0 - hock)
        made["hock" + suffix] = leg * low * hock * (1.0 - hoof)
        made["hoof" + suffix] = leg * low * hock * hoof
        return made
    return weigh


def bones():
    listed = [("body", BODY, None), ("chest", CHEST, "body"), ("pelvis", PELVIS, "body")]
    chain = ["chest"] + NECK_BONES
    for i, joint in enumerate(NECK_JOINTS):
        listed.append((chain[i + 1], joint, chain[i]))
    listed.append(("jaw", JAW, "head"))
    chain = ["pelvis"] + TAIL_BONES + ["tail_end"]
    for i, joint in enumerate(TAIL):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in LEGS.items():
        for bone, joint in zip(("upper", "lower", "hock", "hoof"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


MATERIALS = [("skin", (0.27, 0.27, 0.255)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "nostrils": (0.05, 0.045, 0.04, 0.4), "mouth": (0.22, 0.10, 0.09, 0.5), "eyes": (0.26, 0.20, 0.10, 1.0),
    "claws": (0.16, 0.15, 0.13, 0.12), "teeth": (0.62, 0.58, 0.50, 0.3), "teeth_low": (0.62, 0.58, 0.50, 0.3),
}


def parts():
    # (name, material index, shapes): the body, head and jaw fuse themselves
    return [
        ("body", 0, body()), ("head", 0, head()), ("jaw", 0, jaw()),
        ("teeth", 1, teeth(0)), ("teeth_low", 1, teeth(1)), ("mouth", 1, mouth()), ("nostrils", 1, nostrils()),
        ("eyes", 1, eyes()), ("claws", 1, claws()),
    ]


# --- Shading baked in ---

def paint(whole, part_of):
    """Vertex colours. On the hide: red, how open the surface is (low in
    creases); green, its darker mottling; blue, how pale (underneath). On the
    other parts, their colours (see PART_COLOURS)."""
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    hide = [part in ("body", "head", "jaw") for part in part_of]
    across_uv = {}
    open_ = [1.0] * len(whole.verts)
    for vert in whole.verts:
        if not hide[vert.index] or not vert.link_edges:
            continue
        rise = 0.0
        for edge in vert.link_edges:
            other = edge.other_vert(vert)
            step = other.co - vert.co
            if step.length > 1e-6:
                rise += step.dot(vert.normal) / step.length
        open_[vert.index] = rise / len(vert.link_edges)
    for _ in range(4):
        spread = list(open_)
        for vert in whole.verts:
            if hide[vert.index] and vert.link_edges:
                around = [open_[e.other_vert(vert).index] for e in vert.link_edges]
                spread[vert.index] = 0.5 * open_[vert.index] + 0.5 * sum(around) / len(around)
        open_ = spread
    measured = sorted(open_[i] for i in range(len(open_)) if hide[i])
    middle = measured[len(measured) // 2] if measured else 0.0

    def noise3(p, scale):
        return 0.5 + 0.25 * (math.sin(p.x * scale * 1.7 + p.z * scale * 0.9) + math.sin(p.y * scale * 2.3 - p.z * scale * 1.3 + 1.7))

    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part in PART_COLOURS:
            r, g, bl, wet = PART_COLOURS[part]
            vert[layer] = (r, g, bl, wet)
            if part == "eyes":
                side = 1.0 if p.x >= 0.0 else -1.0
                t, up, radius = EYE
                centre = HEAD + SNOUT_WAY * t + SNOUT_UP * up + X * side * (skull_ring(t)[0] * 0.9)
                local = Matrix.Rotation(side * 1.2, 3, "Y").inverted() @ (p - centre)
                if local.z > 0.0:
                    across_uv[vert.index] = (0.5 + local.x / (radius * 0.8) * 0.4, 0.5 + local.y / (radius * 0.8) * 0.4)
                else:
                    across_uv[vert.index] = (0.95, 0.95)
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 4.0, 0.0), 1.0)
        _, at, way, radius = on_spine(p)
        side = way.cross(Y).normalized() if abs(way.y) < 0.95 else X
        up = side.cross(way).normalized()
        if up.y < 0.0:
            up = -up
        rise = (p - at).dot(up) / max(radius, 0.05)
        # Paler underneath (the belly, under the neck and tail, the insides of the legs)
        under = blend(0.1, -0.85, rise)
        suffix, leg = leg_share(p)
        legs_in = 0.0
        if leg > 0.0:
            hip = LEGS[suffix][0]
            legs_in = blend(0.0, -0.3, (p.x - hip.x) * (1.0 if hip.x > 0.0 else -1.0)) * 0.6 * leg
        pale = max(under * (1.0 - leg * 0.6), legs_in) * 0.85
        # Darker over the back, mottled in big soft blotches
        mottle = blend(0.45, 0.8, noise3(p, 0.9) * 0.6 + noise3(p * 1.7 + V(3.0, 1.0, 2.0), 0.9) * 0.4)
        upper = blend(-0.2, 0.9, rise)
        dark = min(max(mottle * upper * 0.9 + blend(0.7, 1.0, rise) * 0.35, 0.0), 1.0) * (1.0 - leg * 0.6)
        vert[layer] = (shade, dark, pale, 1.0)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))


def export(preview):
    low = kit.LOW
    name = "brachiosaurus" + ("_lo" if low else "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = kit.make_armature(bones())
    whole = bmesh.new()
    whole.loops.layers.uv.verify()
    part_of = []
    for part, material, shapes in parts():
        builder = kit.Builder()
        ready = shapes(builder)
        mesh = ready if ready is not None else kit.fused(builder, None)
        first_face = len(whole.faces)
        whole.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        whole.faces.ensure_lookup_table()
        for face in whole.faces[first_face:]:
            face.material_index = material
            face.smooth = not low
        part_of += [part] * (len(whole.verts) - len(part_of))
    paint(whole, part_of)

    mesh = bpy.data.meshes.new(name)
    body_object = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body_object)
    for label, srgb in MATERIALS:
        made = bpy.data.materials.new(label)
        made.use_nodes = True
        colour = tuple(kit.linear(c) for c in srgb) + (1.0,)
        bsdf = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Roughness"].default_value = 1.0
        made.diffuse_color = colour
        mesh.materials.append(made)
    groups = {bone.name: body_object.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
    deform = whole.verts.layers.deform.verify()
    weigh = weights()
    whole.verts.ensure_lookup_table()
    for vert, part in zip(whole.verts, part_of):
        for bone, weight in weigh(part, kit.from_blender(vert.co)).items():
            if weight > 0.001:
                vert[deform][groups[bone]] = weight
    whole.to_mesh(mesh)
    whole.free()
    for attribute in [a for a in mesh.color_attributes if a.name != "Color"]:
        mesh.color_attributes.remove(attribute)
    painted = mesh.color_attributes["Color"]
    mesh.color_attributes.active_color = painted
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    body_object.parent = armature
    body_object.modifiers.new("Armature", "ARMATURE").object = armature
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_yup=True,
        export_animations=False, export_skins=True, export_vertex_color="ACTIVE",
    )
    print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), kit.triangle_count(mesh)))
    if preview:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(preview, name + ".blend"))
        if not low:
            render(preview, name)


def render(folder, name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1200, 800
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (view, direction to the camera in Blender space, what it looks at, how much it frames, colours)
    views = [("side", (1, 0, 0), (0.0, 1.5, 6.5), 24.0, "MATERIAL"), ("quarter", (0.7, -0.7, 0.25), (0.0, 1.5, 6.5), 24.0, "MATERIAL"),
             ("front", (0.02, -1, 0.08), (0.0, -3.0, 6.5), 15.0, "MATERIAL"), ("back", (-0.5, 1, 0.3), (0.0, 1.0, 6.0), 20.0, "MATERIAL"),
             ("head", (0.8, -0.45, 0.15), (0.0, -8.0, 12.6), 2.2, "MATERIAL"), ("top", (0.15, 0.1, 1), (0.0, 1.0, 5.0), 24.0, "MATERIAL"),
             ("feet", (0.6, -0.7, 0.2), (0.0, -0.5, 0.8), 7.0, "MATERIAL"), ("shade", (0.8, -0.5, 0.2), (0.0, 1.5, 6.5), 24.0, "VERTEX")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 60.0
        camera.data.ortho_scale = frame
        camera.data.clip_end = 200.0
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        export(preview)

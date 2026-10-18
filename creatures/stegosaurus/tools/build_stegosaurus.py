"""Builds the stegosaurus (creatures/stegosaurus) and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/stegosaurus/tools/build_stegosaurus.py
    blender --background --python creatures/stegosaurus/tools/build_stegosaurus.py -- <preview folder>   # with pictures and a .blend

Writes creatures/stegosaurus/models/stegosaurus.glb and a demade
stegosaurus_lo.glb. Nothing else is written (an editable .blend goes to the
preview folder, when there is one; this folder has a .gdignore so that Godot
does not try to import anything here).

It is Stegosaurus stenops, as the bones have it, at its real size (metres):
8.6 m from beak to tail tip, its back 2.85 m up over the hips and its biggest
plates near 3.75 m. Short forelimbs and long, straight hind limbs, so that its
back arches high over the hips and falls to the shoulders; a short neck carried
low and a tiny, long, low head (a toothless horny beak, cheeks over its rows of
small teeth, the eye high at the back). Two alternating rows of tall plates
stand up along its back, small on the neck, biggest over the hips and the base
of the tail, smaller again down it; the end of the tail carries the
thagomizer, two pairs of long spikes held out sideways and up. A pavement of
little bony studs (ossicles) armours its throat. Elephant feet: the forefeet
a column with five short toes in a half circle in front, blunt hoof-like nails
on them; the hind feet three short, broad toes with hoof-like claws.

Its hide is small pebbly scales (the skin shader draws them from the first
texture coordinates, laid after fusing: metres along it and round it), dull
grey-brown, paler underneath, with darker bands across its back. The plates
and spikes are bone in horn, grooved from the root to the edge.

The bones (the rig, creatures/stegosaurus/stegosaurus_rig.gd, poses them):
`body` with `chest` and `pelvis` under it; `neck`, `neck_1`, `head` and `jaw`
from the chest; the tail, `tail` to `tail_5` (and `tail_end`), from the pelvis;
and each leg, from `body`, three bones and a foot:

    fore: `upper` (shoulder to elbow), `lower` (forearm), `hock` (wrist to the foot), `hoof`
    hind: `upper` (thigh, hip to knee), `lower` (shank), `hock` (ankle to the foot), `hoof`

The plates ride the spine bones they stand on, whole (so they never bend);
the spikes ride the end of the tail.

Three materials, so that it is a few draws: `skin` (its vertex colours: red how
open the surface is, dark in creases; green its darker bands; blue how pale,
underneath), `plates` (the plates and spikes: their colour in the vertex
colours, alpha how far along from the root), `parts` (eyes, beak, nails, the
ossicles, the mouth: colour in the vertex colours, alpha how wet).

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

BODY = V(0.0, 1.85, 0.8)
CHEST = V(0.0, 1.70, 1.5)
PELVIS = V(0.0, 2.05, 0.0)
NECK = V(0.0, 1.50, 2.32)
NECK_1 = V(0.0, 1.46, 2.84)
HEAD = V(0.0, 1.27, 3.30)
# (the hinge of the lower jaw, low at the back of the skull)
JAW = HEAD + V(0.0, -0.125, 0.05)

# (along the body, centre height, half width, half height): deepest over the
# belly, the back arching up to its highest over the hips and falling to the
# low shoulders and the neck
TRUNK = [(-1.20, 2.285, 0.36, 0.335), (-0.90, 2.225, 0.45, 0.475), (-0.40, 2.135, 0.60, 0.685),
         (0.00, 2.000, 0.70, 0.850), (0.50, 1.850, 0.76, 0.930), (1.00, 1.725, 0.75, 0.875),
         (1.50, 1.610, 0.66, 0.730), (2.00, 1.520, 0.52, 0.520), (2.40, 1.490, 0.40, 0.330)]

# Shoulder, elbow, wrist, foot; hip, knee, ankle, foot (the left legs: the right are their mirror)
FORE = [V(0.50, 1.36, 1.70), V(0.60, 0.86, 1.55), V(0.57, 0.37, 1.68), V(0.57, 0.11, 1.72)]
HIND = [V(0.52, 2.00, 0.00), V(0.58, 1.06, 0.17), V(0.56, 0.42, -0.03), V(0.56, 0.11, 0.02)]
# (how far down the leg, counted in joints; half width; half depth; forward offset)
FORE_SHAPE = [(-0.3, 0.27, 0.34, 0.0), (0.0, 0.28, 0.35, 0.0), (0.5, 0.235, 0.28, 0.0), (0.95, 0.19, 0.215, -0.01),
              (1.0, 0.188, 0.21, 0.0), (1.5, 0.168, 0.18, 0.01), (1.95, 0.152, 0.16, 0.0), (2.1, 0.158, 0.166, 0.0),
              (2.6, 0.182, 0.186, 0.008), (3.0, 0.196, 0.198, 0.012), (3.38, 0.198, 0.200, 0.012)]
HIND_SHAPE = [(-0.3, 0.34, 0.48, 0.0), (0.0, 0.36, 0.52, -0.02), (0.4, 0.31, 0.41, 0.0), (0.85, 0.245, 0.29, 0.02),
              (1.0, 0.235, 0.27, 0.02), (1.5, 0.21, 0.235, -0.01), (1.9, 0.19, 0.205, 0.0), (2.1, 0.198, 0.212, 0.01),
              (2.6, 0.232, 0.245, 0.02), (3.0, 0.25, 0.262, 0.025), (3.38, 0.25, 0.262, 0.025)]

# The tail: its joints (tail, tail_1 .. tail_5, its end), carried clear of the
# ground, and how thick it is at each (half width, half height: deep, with the
# chevrons under it).
TAIL = [V(0.0, 2.30, -0.70), V(0.0, 2.24, -1.40), V(0.0, 2.11, -2.10), V(0.0, 1.95, -2.80),
        V(0.0, 1.78, -3.45), V(0.0, 1.63, -4.05), V(0.0, 1.52, -4.62)]
TAIL_SHAPE = [(0.40, 0.48), (0.31, 0.37), (0.235, 0.28), (0.17, 0.205), (0.12, 0.145), (0.085, 0.10), (0.045, 0.055)]
TAIL_BONES = ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5"]

# The neck: (along from NECK to HEAD, half width, half height), and how far its
# middle hangs below the line (the throat sags).
NECK_SHAPE = [(-0.15, 0.44, 0.42, 0.0), (0.0, 0.40, 0.42, 0.0), (0.3, 0.32, 0.37, 0.03), (0.6, 0.25, 0.29, 0.04),
              (0.85, 0.20, 0.22, 0.025), (1.05, 0.165, 0.175, 0.0)]

# The skull, from HEAD: long, low and narrow, tapering to the beak; its top
# runs straight forward and a little down.
SNOUT_TOP = V(0.0, 0.085, -0.04)
SNOUT_WAY = V(0.0, -0.20, 0.98).normalized()
SNOUT_UP = V(0.0, SNOUT_WAY.z, -SNOUT_WAY.y)
# (along the top of the skull, half width, half height)
SKULL = [(0.0, 0.135, 0.135), (0.08, 0.145, 0.138), (0.17, 0.132, 0.122), (0.27, 0.108, 0.100),
         (0.36, 0.088, 0.084), (0.44, 0.070, 0.068), (0.50, 0.058, 0.056)]
JAW_WAY = V(0.0, -0.09, 0.996).normalized()
JAW_UP = V(0.0, JAW_WAY.z, -JAW_WAY.y)
# (along the jaw from JAW, half width, half height, how far its middle is below the line from the hinge)
JAW_SHAPE = [(-0.02, 0.100, 0.052, 0.0), (0.09, 0.094, 0.048, 0.004), (0.18, 0.078, 0.040, 0.006),
             (0.26, 0.062, 0.032, 0.006), (0.31, 0.052, 0.027, 0.004), (0.345, 0.044, 0.022, 0.003)]
EYE = (V(0.122, -0.030, 0.105), 0.024)

# The plates: (along the body, how tall, which row: 1 its left, -1 its right).
# Seventeen, alternating, small on the neck, biggest over the hips and the
# base of the tail, then smaller down it to the spikes.
PLATES = [(2.92, 0.17, 1), (2.62, 0.24, -1), (2.30, 0.32, 1), (2.00, 0.42, -1), (1.68, 0.52, 1), (1.34, 0.60, -1),
          (1.00, 0.67, 1), (0.64, 0.75, -1), (0.28, 0.82, 1), (-0.08, 0.87, -1), (-0.44, 0.88, 1), (-0.82, 0.84, -1),
          (-1.22, 0.75, 1), (-1.64, 0.62, -1), (-2.08, 0.48, 1), (-2.52, 0.34, -1), (-2.94, 0.22, 1)]

# The thagomizer: (along the tail, how long, outward, up, back): the front
# pair held more out and up, the back pair swept further back.
SPIKES = [(-3.62, 0.72, 0.76, 0.60, -0.26), (-4.12, 0.82, 0.62, 0.36, -0.72)]


def legs():
    made = {}
    for suffix in SUFFIXES:
        side = 1.0 if suffix[2] == "l" else -1.0
        made[suffix] = [V(j.x * side, j.y, j.z) for j in (FORE if suffix[1] == "f" else HIND)]
    return made


LEGS = legs()


def ring_at(rings, z):
    """(centre height, half width, half height) at `z` along a list of rings ordered by z."""
    if z <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return rings[-1][1:]


def smooth_rings(rings, step):
    """More rings, every `step` along, on smooth curves through those given (Catmull-Rom), so that the hide has no kinks."""
    made = []
    for i in range(len(rings) - 1):
        r0, r1, r2 = rings[max(i - 1, 0)], rings[i], rings[i + 1]
        r3 = rings[min(i + 2, len(rings) - 1)]
        count = max(int(math.ceil((r2[0] - r1[0]) / step)), 1)
        for k in range(count):
            t = k / count
            t2, t3 = t * t, t * t * t
            made.append(tuple(0.5 * (2 * r1[c] + (-r0[c] + r2[c]) * t + (2 * r0[c] - 5 * r1[c] + 4 * r2[c] - r3[c]) * t2
                                     + (-r0[c] + 3 * r1[c] - 3 * r2[c] + r3[c]) * t3) for c in range(4)))
    made.append(rings[-1])
    return made


def tail_at(z):
    """The tail's (centre height, half width, half height) at `z` (behind the hips)."""
    rings = [(j.z, j.y, w, h) for j, (w, h) in zip(TAIL, TAIL_SHAPE)][::-1]
    return ring_at(rings, z)


def top_at(z):
    """How high its back is at `z`: over the trunk, the tail or the neck."""
    best = -1.0
    if z >= TRUNK[0][0] - 0.1 and z <= TRUNK[-1][0]:
        y, _, ry = ring_at(TRUNK, z)
        best = y + ry
    if z <= TAIL[0].z + 0.3:
        y, _, ry = tail_at(z)
        best = max(best, y + ry)
    if z >= NECK.z - 0.2:
        reach = (z - NECK.z) / (HEAD.z - NECK.z)
        y, _, ry, sag = neck_ring(reach)
        best = max(best, neck_point(reach).y - sag + ry)
    return best


def neck_point(t):
    """A point `t` of the way along the neck's line (NECK, NECK_1, HEAD)."""
    if t < 0.5:
        return NECK.lerp(NECK_1, t * 2.0)
    return NECK_1.lerp(HEAD, (t - 0.5) * 2.0)


def neck_ring(t):
    rings = NECK_SHAPE
    if t <= rings[0][0]:
        return (0.0,) + rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if t <= b[0]:
            u = (t - a[0]) / (b[0] - a[0])
            return (0.0,) + tuple(a[k] + (b[k] - a[k]) * u for k in (1, 2, 3))
    return (0.0,) + rings[-1][1:]


def skull_ring(t):
    rings = SKULL
    if t <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if t <= b[0]:
            u = (t - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * u for k in (1, 2))
    return rings[-1][1:]


def skull_at(t):
    """The middle of the skull `t` along its top: it hangs from the line of its top."""
    return HEAD + SNOUT_TOP + SNOUT_WAY * t - SNOUT_UP * skull_ring(t)[1]


def axis_at(z):
    """The middle of it (height) at `z`, from the tip of the tail to the beak, and about how thick it is there."""
    if z < TRUNK[0][0] + 0.3:
        y, rx, ry = tail_at(z)
        return y, (rx + ry) * 0.5
    if z <= NECK.z:
        y, rx, ry = ring_at(TRUNK, z)
        return y, (rx + ry) * 0.5
    if z <= HEAD.z:
        t = (z - NECK.z) / (HEAD.z - NECK.z)
        _, rx, ry, sag = neck_ring(t)
        return neck_point(t).y - sag, (rx + ry) * 0.5
    t = (z - HEAD.z) / SNOUT_WAY.z
    rx, ry = skull_ring(t)
    return skull_at(t).y, (rx + ry) * 0.5


def chain_param(p, joints):
    """The nearest point to `p` on a line of joints: (how far off it, how far along it counted in joints)."""
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
    fore = p.z > 0.85
    suffix = ("_f" if fore else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = LEGS[suffix]
    top = joints[0]
    off = chain_param(V(top.x, p.y, p.z), joints)[0]
    side = abs(p.x - top.x)
    inner = abs(p.x)
    if fore:
        return suffix, blend(top.y - 0.05, top.y - 0.42, p.y) * blend(0.40, 0.26, math.hypot(side, off / 1.5)) * blend(top.x - 0.22, top.x - 0.12, inner)
    return suffix, blend(top.y - 0.12, top.y - 0.70, p.y) * blend(0.55, 0.38, math.hypot(side, off / 1.5)) * blend(top.x - 0.30, top.x - 0.18, inner)


def leg_axis(joints, y):
    """Where the leg's line is (z) at height `y`."""
    for a, b in zip(joints, joints[1:]):
        if y >= b.y:
            return a.z + (b.z - a.z) * min(max((a.y - y) / (a.y - b.y), 0.0), 1.0)
    return joints[-1].z


def lay_skin(bm):
    """The texture coordinates the skin shader draws its scales from: (along
    it, round it), in metres: along the body from the beak to the tail, and
    down each leg."""
    uv = bm.loops.layers.uv.verify()

    def around(x, y, near_x, near_y, radius):
        near = math.atan2(near_x, near_y)
        return (near + (math.atan2(x, y) - near + math.pi) % math.tau - math.pi) * radius

    for face in bm.faces:
        near = kit.from_blender(face.calc_center_median())
        suffix, _ = leg_share(near)
        joints = LEGS[suffix]
        hip = joints[0]
        out = 1.0 if hip.x > 0.0 else -1.0
        near_axis, _ = axis_at(near.z)
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            leg = leg_share(p)[1]
            middle, radius = axis_at(p.z)
            trunk = (-p.z, around(p.x, p.y - middle, near.x, near.y - near_axis, radius))
            limb_uv = (hip.y - p.y - hip.z, around(p.z - leg_axis(joints, p.y), (p.x - hip.x) * out,
                                                  near.z - leg_axis(joints, near.y), (near.x - hip.x) * out, 0.2))
            loop[uv].uv = (trunk[0] + (limb_uv[0] - trunk[0]) * leg, trunk[1] + (limb_uv[1] - trunk[1]) * leg)


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
    b.tube(dome(rings[0], -directions[0], 0.1)[::-1] + rings + dome(rings[-1], directions[-1], 0.03, 2), segments)


def body():
    """The trunk, the tail, the neck and the legs, fused into one hide."""
    def shapes(b):
        low = kit.LOW
        rings = [kit.lengthwise(*ring) for ring in smooth_rings(TRUNK, 0.15)]
        b.tube(rings, 24)
        # The tail, on from the hips to its tip
        tail = [(j, X * w, Y * h) for j, (w, h) in zip(TAIL, TAIL_SHAPE)]
        b.tube([(TAIL[0] + V(0.0, -0.05, 0.5), X * 0.5, Y * 0.62)] + tail + dome(tail[-1], -Z, 0.06, 2), 16)
        # The neck, down and forward from the shoulders to the head
        neck = []
        for t, rx, ry, sag in NECK_SHAPE:
            at = neck_point(t) if t >= 0.0 else NECK + (NECK - NECK_1) * (-t * 2.0)
            way = (neck_point(min(t + 0.05, 1.0)) - neck_point(max(t - 0.05, 0.0))).normalized()
            up = way.cross(X).normalized() * -1.0
            if up.y < 0.0:
                up = -up
            neck.append((at - up * sag, X * rx, up * ry))
        b.tube(neck, 16)
        # The big muscles over each haunch and shoulder; the hip bones and the
        # spine ridge under the plates
        for side in (1.0, -1.0):
            b.ellipsoid(V(side * 0.56, 1.64, -0.06), V(0.26, 0.58, 0.60), Matrix.Rotation(-0.20, 3, "X"), 24, 12)
            b.ellipsoid(V(side * 0.50, 1.28, 1.66), V(0.23, 0.38, 0.32), Matrix.Rotation(0.25, 3, "X"), 20, 10)
            # (the flank swelling out over the belly, the great gut of a plant eater)
            b.ellipsoid(V(side * 0.30, 1.40, 0.75), V(0.50, 0.50, 0.95), None, 24, 12)
        for suffix, joints in LEGS.items():
            limb(b, joints, FORE_SHAPE if suffix[1] == "f" else HIND_SHAPE, 14 if not low else 12)
        return skinned(b, (0.034, 4, 30000))
    return shapes


def head():
    """The tiny skull: long, low and narrow, the cheeks over its teeth, a ridge over each eye."""
    def shapes(b):
        h = HEAD
        rings = [(skull_at(t), X * rx, SNOUT_UP * ry) for t, rx, ry in SKULL]
        b.tube(dome(rings[0], -SNOUT_WAY, 0.06, 3)[::-1] + rings + dome(rings[-1], SNOUT_WAY, 0.035, 3), 16)
        for side in (1.0, -1.0):
            # (the cheek: a fleshy pouch along the mouth, over the rows of little teeth)
            b.ellipsoid(h + V(side * 0.082, -0.050, 0.200), V(0.040, 0.042, 0.140), Matrix.Rotation(-0.20, 3, "X"), 10, 5)
            # (the ridge over the eye, and the jowl behind it)
            b.ellipsoid(h + V(side * 0.108, 0.002, 0.100), V(0.036, 0.018, 0.058), None, 8, 4)
            b.ellipsoid(h + V(side * 0.088, -0.020, 0.030), V(0.050, 0.065, 0.075), None, 10, 5)
        return skinned(b, (0.008, 3, 5200))
    return shapes


def jaw():
    def shapes(b):
        rings = [(JAW + JAW_WAY * t - JAW_UP * drop, X * rx, JAW_UP * ry) for t, rx, ry, drop in JAW_SHAPE]
        b.tube(dome(rings[0], -JAW_WAY, 0.03, 2)[::-1] + rings + dome(rings[-1], JAW_WAY, 0.022, 3), 12)
        return skinned(b, (0.008, 2, 1800))
    return shapes


def beak():
    """The horny beak sheathing the end of the snout: dark, hooked a little down over the lower."""
    def shapes(b):
        rings = []
        for t, grow in ((0.40, 1.03), (0.445, 1.07), (0.49, 1.08)):
            rx, ry = skull_ring(t)
            rings.append((skull_at(t) - SNOUT_UP * 0.006, X * rx * grow, SNOUT_UP * ry * grow))
        b.tube(rings + dome(rings[-1], (SNOUT_WAY - SNOUT_UP * 0.35).normalized(), 0.05, 3), 12)
    return shapes


def lower_beak():
    def shapes(b):
        rings = []
        for t, rx, ry, drop in JAW_SHAPE[-3:]:
            rings.append((JAW + JAW_WAY * t - JAW_UP * drop, X * rx * 1.06, JAW_UP * ry * 1.08))
        b.tube(rings[1:] + dome(rings[-1], JAW_WAY, 0.03, 3), 10)
    return shapes


def nostrils():
    def shapes(b):
        face = skull_at(0.43) + SNOUT_UP * 0.040
        for side in (1.0, -1.0):
            b.ellipsoid(face + X * side * 0.030 + SNOUT_WAY * 0.02, V(0.012, 0.010, 0.022), None, 6, 3)
    return shapes


def mouth():
    """The dark inside of its mouth, seen when the jaw drops."""
    def shapes(b):
        b.ellipsoid(JAW + JAW_WAY * 0.22 + V(0.0, 0.03, 0.0), V(0.055, 0.025, 0.20), Matrix.Rotation(-0.26, 3, "X"), 10, 5)
    return shapes


def eyes():
    def shapes(b):
        at, radius = EYE
        for side in (1.0, -1.0):
            b.ellipsoid(HEAD + V(side * at.x, at.y, at.z), V(radius * 0.7, radius * 0.75, radius), Matrix.Rotation(-side * 0.35, 3, "Y"), 8, 5)
    return shapes


def ossicles():
    """The little bony studs in the skin of its throat: armour, a pavement of them under the neck."""
    def shapes(b):
        count = 34 if not kit.LOW else 12
        for k in range(count):
            # (spread along the throat, from under the jaw to the base of the neck, and round its underside)
            u = (k + 0.5) / count
            t = 0.35 + 0.62 * u
            spin = (k * 2.39996) % math.tau
            across = math.sin(spin) * 0.7
            centre = neck_point(t)
            _, rx, ry, sag = neck_ring(t)
            around = math.pi * (1.0 + across * 0.45)
            at = centre + V(math.sin(around) * rx * 0.98, -sag + math.cos(around) * ry * 0.98, 0.0)
            size = 0.019 + 0.010 * math.sin(k * 7.1) ** 2
            normal = V(math.sin(around) * ry, math.cos(around) * rx, 0.0).normalized()
            tilt = Vector((0.0, -1.0, 0.0)).rotation_difference(-normal).to_matrix()
            b.ellipsoid(at, V(size, size * 0.45, size * 1.15), tilt, 7 if not kit.LOW else 5, 3)
    return shapes


def plate_frame(z, row):
    """Where a plate roots on the back, and its frame: (root, along it, up it, out of its face)."""
    if z > NECK.z:
        t = (z - NECK.z) / (HEAD.z - NECK.z)
        ahead = (neck_point(min(t + 0.05, 1.0)) - neck_point(max(t - 0.05, 0.0))).normalized()
    elif z < TAIL[0].z:
        _, along = chain_param(V(0.0, tail_at(z)[0], z), TAIL)
        i = min(int(along), len(TAIL) - 2)
        ahead = (TAIL[i] - TAIL[i + 1]).normalized()
    else:
        ahead = V(0.0, (top_at(z + 0.05) - top_at(z - 0.05)) / 0.1, 1.0).normalized()
    # (the two rows each a little off the middle, leaning out a little)
    up = (ahead.cross(X).normalized() * -1.0)
    if up.y < 0.0:
        up = -up
    lean = Matrix.Rotation(-row * 0.13, 3, ahead)
    up = lean @ up
    out = ahead.cross(up).normalized() * (-1.0 if row > 0 else 1.0)
    root = V(row * 0.065, top_at(z) - 0.07, z)
    return root, ahead, up, out


def plate_outline(t):
    """How wide a plate is (half, along the body) and how far forward its middle is, `t` of the way up it."""
    # A broad, rounded diamond leaning back a little: its root narrower, widest
    # two-fifths of the way up, its edges bulging out and rounding to a blunt tip.
    if t < 0.38:
        half = 0.26 + 0.20 * math.sin(math.pi * 0.5 * t / 0.38)
    else:
        u = (t - 0.38) / 0.62
        half = 0.46 * (1.0 - u) ** 0.8 * (1.0 + 0.35 * math.sin(math.pi * u) * (1.0 - u))
    shift = -0.12 * t ** 1.6
    return max(half, 0.006), shift


def plates():
    def shapes(b):
        low = kit.LOW
        stations = (0.0, 0.08, 0.2, 0.32, 0.44, 0.56, 0.68, 0.80, 0.90, 0.97, 1.0) if not low else (0.0, 0.2, 0.44, 0.7, 0.9, 1.0)
        for z, height, row in PLATES:
            root, ahead, up, out = plate_frame(z, row)
            rings = []
            for t in stations:
                half, shift = plate_outline(t)
                half *= height * (1.25 if height < 0.3 else 1.0)
                # (thick and rounded at its root, thinning to a sharp rim and tip)
                thick = (0.035 * (1.0 - t) ** 1.5 + 0.006) * (0.6 + height * 0.5)
                at = root + up * (t * height) + ahead * (shift * height)
                rings.append((at, ahead * half, out * thick))
            b.tube(rings, 12 if not low else 6)
    return shapes


def spikes():
    def shapes(b):
        low = kit.LOW
        for z, length, ox, oy, oz in SPIKES:
            y, rx, ry = tail_at(z)
            for side in (1.0, -1.0):
                way = V(side * ox, oy, oz).normalized()
                root = V(side * rx * 0.45, y + ry * 0.35, z)
                # (each curves a little up towards its point)
                points = [root.lerp(root + way * length, t) + V(0.0, 0.05 * length * t * t, 0.0) for t in (0.0, 0.25, 0.5, 0.75, 0.92, 1.0)]
                radii = [0.075, 0.062, 0.046, 0.028, 0.012, 0.002]
                rings = []
                for i, point in enumerate(points):
                    ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
                    u = ahead.cross(Z if abs(ahead.z) < 0.9 else X).normalized()
                    rings.append((point, u * radii[i], ahead.cross(u) * radii[i]))
                b.tube(dome(rings[0], -way, 0.05, 2)[::-1] + rings, 10 if not low else 5)
    return shapes


def nails():
    """Hoof-like nails: five short ones in a half circle round the front of each
    forefoot; three broad ones on the toes of each hind foot."""
    def shapes(b):
        for suffix, joints in LEGS.items():
            foot = joints[3]
            fore = suffix[1] == "f"
            radius = 0.158 if fore else 0.215
            toes = (-1.1, -0.55, 0.0, 0.55, 1.1) if fore else (-0.62, 0.0, 0.62)
            side = 1.0 if suffix[2] == "l" else -1.0
            for k, a in enumerate(toes):
                # (the inner toe is on the inside of the foot: its nail is the biggest)
                big = 1.0 + 0.25 * blend(0.0, 1.2, -a * side) if fore else 1.0
                at = foot + V(math.sin(a) * radius * 0.92, -0.072, math.cos(a) * radius * 0.92 + (0.05 if fore else 0.06))
                size = V(0.040, 0.040, 0.034) * big if fore else V(0.062, 0.050, 0.060)
                tilt = Matrix.Rotation(a, 3, "Y") @ Matrix.Rotation(0.5, 3, "X")
                b.ellipsoid(at, size, tilt, 8, 4)
    return shapes


def coat_weights(p):
    """Which bones the hide at `p` hangs from (not the legs: see `weights`)."""
    names = ["pelvis"] + TAIL_BONES
    off, along = chain_param(p, TAIL)
    if p.z < TAIL[0].z + 0.25:
        past = [1.0, blend(-0.35, 0.4, along)] + [blend(k - 0.35, k + 0.35, along) for k in range(1, len(TAIL_BONES))] + [0.0]
        return {name: past[i] - past[i + 1] for i, name in enumerate(names) if past[i] - past[i + 1] > 0.0}
    base, top = NECK, HEAD
    reach = (p - base).dot((top - base).normalized()) / (top - base).length
    if reach > -0.3 and p.z > base.z - 0.3 and p.y > 0.75:
        neck = blend(-0.25, 0.25, reach)
        upper = blend(0.35, 0.65, reach)
        head = blend(0.88, 1.02, reach)
        return {"chest": 1.0 - neck, "neck": neck * (1.0 - upper), "neck_1": neck * upper * (1.0 - head), "head": neck * upper * head}
    front = blend(0.1, 1.4, p.z)
    return {"chest": front, "pelvis": 1.0 - front}


def weights():
    def weigh(part, p):
        if part in ("jaw", "lower_beak", "mouth"):
            return {"jaw": 1.0}
        if part in ("head", "beak", "eyes", "nostrils"):
            return {"head": 1.0}
        if part == "ossicles":
            return coat_weights(p)
        if part == "nails":
            suffix = ("_f" if p.z > 0.85 else "_r") + ("l" if p.x >= 0.0 else "r")
            return {"hoof" + suffix: 1.0}
        if part in ("plates", "spikes"):
            # (rigid: `p` is its root, so that each rides the bones under it whole)
            return coat_weights(p)
        trunk = coat_weights(p)
        suffix, leg = leg_share(p)
        if leg <= 0.0:
            return trunk
        joints = LEGS[suffix]
        along = chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.12 / spans[0], 1.0 + 0.12 / spans[1], along)
        hock = blend(2.0 - 0.09 / spans[1], 2.0 + 0.09 / spans[2], along)
        hoof = blend(joints[3].y + 0.10, joints[3].y + 0.02, p.y)
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + suffix] = leg * (1.0 - low)
        made["lower" + suffix] = leg * low * (1.0 - hock)
        made["hock" + suffix] = leg * low * hock * (1.0 - hoof)
        made["hoof" + suffix] = leg * low * hock * hoof
        return made
    return weigh


def bones():
    listed = [
        ("body", BODY, None), ("chest", CHEST, "body"), ("pelvis", PELVIS, "body"),
        ("neck", NECK, "chest"), ("neck_1", NECK_1, "neck"), ("head", HEAD, "neck_1"), ("jaw", JAW, "head"),
    ]
    chain = ["pelvis"] + TAIL_BONES + ["tail_end"]
    for i, joint in enumerate(TAIL):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in LEGS.items():
        for bone, joint in zip(("upper", "lower", "hock", "hoof"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


MATERIALS = [("skin", (0.25, 0.243, 0.22)), ("plates", (1.0, 1.0, 1.0)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "beak": (0.11, 0.10, 0.09, 0.35), "lower_beak": (0.11, 0.10, 0.09, 0.35), "nostrils": (0.04, 0.035, 0.03, 0.4),
    "mouth": (0.20, 0.09, 0.08, 0.5), "eyes": (0.30, 0.20, 0.08, 1.0), "nails": (0.19, 0.17, 0.15, 0.12),
    "ossicles": (0.36, 0.34, 0.30, 0.0),
}


def parts():
    # (name, material index, shapes): the body, head and jaw fuse themselves
    return [
        ("body", 0, body()), ("head", 0, head()), ("jaw", 0, jaw()),
        ("plates", 1, plates()), ("spikes", 1, spikes()),
        ("beak", 2, beak()), ("lower_beak", 2, lower_beak()), ("nostrils", 2, nostrils()), ("mouth", 2, mouth()),
        ("eyes", 2, eyes()), ("ossicles", 2, ossicles()), ("nails", 2, nails()),
    ]


# --- Shading baked in ---

def paint(whole, part_of, piece_of):
    """Vertex colours. On the hide: red, how open the surface is (low in
    creases); green, its darker bands; blue, how pale (underneath). On the
    plates and spikes: their colour, alpha how far from the root to the edge.
    On the other parts, their colours (see PART_COLOURS)."""
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
        if part in ("plates", "spikes"):
            root, tip_length, k = piece_of[vert.index]
            reach = min((p - root).length / max(tip_length, 0.01), 1.0)
            tone = 0.9 + 0.2 * ((math.sin(k * 12.9898) * 43758.5453) % 1.0)
            if part == "plates":
                # (dark at the root, where it is set in the skin; a little warmer and paler to the rim)
                r, g, bl = 0.25 * tone, 0.232 * tone, 0.21 * tone
            else:
                r, g, bl = 0.38 * tone, 0.355 * tone, 0.31 * tone
            vert[layer] = (r, g, bl, reach)
            continue
        if part in PART_COLOURS:
            r, g, bl, wet = PART_COLOURS[part]
            if part == "ossicles":
                shade = 0.85 + 0.3 * noise3(p, 40.0)
                r, g, bl = r * shade, g * shade, bl * shade
            vert[layer] = (r, g, bl, wet)
            if part == "eyes":
                side = 1.0 if p.x >= 0.0 else -1.0
                at, radius = EYE
                centre = HEAD + V(side * at.x, at.y, at.z)
                local = Matrix.Rotation(side * 1.2, 3, "Y").inverted() @ (p - centre)
                if local.z > 0.0:
                    across_uv[vert.index] = (0.5 + local.x / (radius * 0.75) * 0.4, 0.5 + local.y / (radius * 0.75) * 0.4)
                else:
                    across_uv[vert.index] = (0.95, 0.95)
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 4.0, 0.0), 1.0)
        centre, radius = axis_at(p.z)
        # Paler underneath (the belly, the underside of the tail and neck, the throat, the insides of the legs)
        under = blend(centre + radius * 0.1, centre - radius * 0.85, p.y)
        legs_in = 0.0
        suffix, leg = leg_share(p)
        if leg > 0.0:
            hip = LEGS[suffix][0]
            legs_in = blend(0.0, -0.12, (p.x - hip.x) * (1.0 if hip.x > 0.0 else -1.0)) * 0.6 * leg
        pale = max(under * (1.0 - leg * 0.6), legs_in) * 0.9
        # Darker bands across its back and down its flanks (from the spine), broken up
        bands = 0.5 + 0.5 * math.sin(p.z * 4.2 + 0.8 * math.sin(p.y * 3.0) + noise3(p, 2.0) * 2.0)
        upper = blend(centre - radius * 0.2, centre + radius * 0.8, p.y)
        dark = min(max(bands * upper * 1.2 + blend(centre + radius * 0.7, centre + radius * 1.0, p.y) * 0.4, 0.0), 1.0) * (1.0 - leg * 0.7)
        vert[layer] = (shade, dark, pale, 1.0)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))


def export(preview):
    low = kit.LOW
    name = "stegosaurus" + ("_lo" if low else "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = kit.make_armature(bones())
    whole = bmesh.new()
    whole.loops.layers.uv.verify()
    part_of = []
    # (for each plate and spike vertex: its root, its length, and which it is)
    piece_of = {}
    for part, material, shapes in parts():
        builder = kit.Builder()
        ready = shapes(builder)
        if part in ("plates", "spikes"):
            # Tell each piece apart: it was built as one closed tube after another.
            pieces = []
            if part == "plates":
                for z, height, row in PLATES:
                    root, _, up, _ = plate_frame(z, row)
                    pieces.append((root, height))
            else:
                for z, length, _ox, _oy, _oz in SPIKES:
                    y, rx, ry = tail_at(z)
                    for side in (1.0, -1.0):
                        pieces.append((V(side * rx * 0.45, y + ry * 0.35, z), length))
            per = len(builder.bm.verts) // len(pieces)
            builder.bm.verts.ensure_lookup_table()
            tags = []
            for i, vert in enumerate(builder.bm.verts):
                k = min(i // per, len(pieces) - 1)
                tags.append((pieces[k][0], pieces[k][1], k))
        mesh = ready if ready is not None else kit.fused(builder, None)
        first = len(whole.verts)
        first_face = len(whole.faces)
        whole.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        whole.faces.ensure_lookup_table()
        for face in whole.faces[first_face:]:
            face.material_index = material
            face.smooth = not low
        part_of += [part] * (len(whole.verts) - len(part_of))
        if part in ("plates", "spikes"):
            for i in range(len(whole.verts) - first):
                piece_of[first + i] = tags[i]
    paint(whole, part_of, piece_of)

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
        p = piece_of[vert.index][0] if part in ("plates", "spikes") else kit.from_blender(vert.co)
        for bone, weight in weigh(part, p).items():
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
    views = [("side", (1, 0, 0), (0.0, 0.3, 1.8), 9.6, "MATERIAL"), ("quarter", (0.7, -0.7, 0.25), (0.0, 0.3, 1.8), 9.6, "MATERIAL"),
             ("front", (0.02, -1, 0.08), (0.0, -2.0, 1.8), 4.6, "MATERIAL"), ("back", (-0.5, 1, 0.3), (0.0, 1.0, 1.8), 7.5, "MATERIAL"),
             ("head", (0.75, -0.6, 0.2), (0.0, -3.55, 1.2), 1.0, "MATERIAL"), ("top", (0.15, 0.1, 1), (0.0, 0.3, 1.5), 9.6, "MATERIAL"),
             ("shade", (0.8, -0.5, 0.2), (0.0, 0.3, 1.8), 9.6, "VERTEX")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 20.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    preview = kit.PREVIEW_DIR or None
    for low in (False, True):
        kit.LOW = low
        export(preview)

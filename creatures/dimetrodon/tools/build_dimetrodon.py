"""Builds the dimetrodon (creatures/dimetrodon) and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/dimetrodon/tools/build_dimetrodon.py
    blender --background --python creatures/dimetrodon/tools/build_dimetrodon.py -- <preview folder>   # with pictures and a .blend

Writes creatures/dimetrodon/models/dimetrodon.glb and a demade dimetrodon_lo.glb.

It is Dimetrodon grandis, at its real size (metres): 3.4 m from snout to tail
tip, a synapsid (nearer to us than to any lizard or dinosaur), low-slung on
sprawling legs: the upper arm and thigh held out sideways, the forearm and
shin down to broad five-toed clawed feet planted out to the sides, the belly
a hand's breadth off the ground. Down its back the sail: tall neural spines,
the tallest about a metre over the back in the middle of it, with skin
stretched between them, its top a long arch. A big, deep, narrow skull with
the eye high and far back; teeth of two kinds (its name: "two measures of
teeth"): great stabbing canines at the front of the upper jaw and smaller
cutting teeth behind. A long tail tapering to the ground.

Its hide is fine pebbly scales (drawn by the skin shader from the first
texture coordinates), dusky grey-brown, paler underneath; the sail darker with
paler bands up it.

The bones (the rig, creatures/dimetrodon/dimetrodon_rig.gd, poses them):
`body` with `chest` and `pelvis` under it; `neck`, `head` and `jaw` from the
chest; the tail, `tail` to `tail_5` (and `tail_end`), from the pelvis; each
leg, from `body`: `upper` (the upper arm or thigh, out sideways), `lower`
(forearm or shin, down), `hock` (the foot, flat on the ground), `hoof` (the
tips of its toes).

Two materials: `skin` (vertex colours: red how open, green darker bands, blue
how pale) and `parts` (eyes, teeth, claws, the mouth: colour, alpha how wet).

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
import build_character as kit  # noqa: E402

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
SUFFIXES = ("_fl", "_fr", "_rl", "_rr")
OUT = os.path.join(COMPONENT, "models")


def V(x, y, z):
    return Vector((x, y, z))


BODY = V(0.0, 0.42, 0.0)
CHEST = V(0.0, 0.43, 0.42)
PELVIS = V(0.0, 0.42, -0.48)
NECK = V(0.0, 0.47, 0.70)
HEAD = V(0.0, 0.50, 0.86)

# (along, centre height, half width, half height)
TRUNK = [(-0.78, 0.40, 0.11, 0.11), (-0.62, 0.41, 0.17, 0.16), (-0.44, 0.42, 0.215, 0.185), (-0.15, 0.425, 0.255, 0.205),
         (0.15, 0.43, 0.255, 0.205), (0.40, 0.44, 0.225, 0.195), (0.60, 0.46, 0.165, 0.165), (0.76, 0.48, 0.125, 0.135)]

# Shoulder, elbow, wrist, toe tips; hip, knee, ankle, toe tips (left; the right their mirror)
FORE = [V(0.15, 0.40, 0.47), V(0.39, 0.37, 0.43), V(0.44, 0.065, 0.51), V(0.50, 0.012, 0.67)]
HIND = [V(0.14, 0.40, -0.47), V(0.41, 0.38, -0.39), V(0.47, 0.07, -0.50), V(0.57, 0.012, -0.33)]
# (along in joints, radius) for the upper and lower leg
FORE_SHAPE = [(0.0, 0.1), (0.5, 0.082), (0.95, 0.068), (1.05, 0.066), (1.5, 0.054), (1.95, 0.046)]
HIND_SHAPE = [(0.0, 0.115), (0.5, 0.095), (0.95, 0.075), (1.05, 0.072), (1.5, 0.058), (1.95, 0.048)]

TAIL = [V(0.0, 0.41, -0.74), V(0.0, 0.38, -1.02), V(0.0, 0.33, -1.31), V(0.0, 0.27, -1.6),
        V(0.0, 0.21, -1.88), V(0.0, 0.16, -2.14), V(0.0, 0.12, -2.38)]
TAIL_SHAPE = [(0.115, 0.12), (0.09, 0.1), (0.07, 0.08), (0.055, 0.062), (0.04, 0.046), (0.026, 0.03), (0.01, 0.012)]
TAIL_BONES = ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5"]

SNOUT_WAY = V(0.0, -0.06, 1.0).normalized()
SNOUT_UP = V(0.0, SNOUT_WAY.z, -SNOUT_WAY.y)
# (along, half width, half height, how far up its middle): deep and narrow
SKULL = [(-0.04, 0.10, 0.10, 0.03), (0.05, 0.11, 0.125, 0.02), (0.15, 0.095, 0.13, 0.0), (0.26, 0.075, 0.118, -0.01),
         (0.35, 0.062, 0.105, -0.02), (0.43, 0.052, 0.09, -0.028), (0.48, 0.04, 0.07, -0.032)]
JAW = HEAD + SNOUT_WAY * -0.03 - SNOUT_UP * 0.085
JAW_WAY = SNOUT_WAY
JAW_UP = SNOUT_UP
JAW_SHAPE = [(-0.03, 0.085, 0.045, 0.0), (0.12, 0.08, 0.042, 0.0), (0.26, 0.062, 0.035, 0.0), (0.38, 0.048, 0.03, 0.0), (0.47, 0.034, 0.026, -0.004)]
EYE = (0.11, 0.06, 0.024)

# The sail: spines from over the shoulders to over the hips, its top an arch.
SAIL_FROM, SAIL_TO, SAIL_HIGH = 0.64, -0.56, 0.95


def sail_height(z):
    u = (z - (SAIL_FROM + SAIL_TO) * 0.5 - 0.04) / ((SAIL_FROM - SAIL_TO) * 0.5 + 0.03)
    return max(SAIL_HIGH * math.sqrt(max(1.0 - u * u, 0.0)) ** 1.15, 0.05)


def legs():
    made = {}
    for suffix in SUFFIXES:
        side = 1.0 if suffix[2] == "l" else -1.0
        made[suffix] = [V(j.x * side, j.y, j.z) for j in (FORE if suffix[1] == "f" else HIND)]
    return made


LEGS = legs()


def ring_at(rings, z):
    if z <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in range(1, len(a)))
    return rings[-1][1:]


def smooth_rings(rings, step):
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


def skull_ring(t):
    return ring_at(SKULL, t)


def skull_at(t):
    return HEAD + SNOUT_WAY * t + SNOUT_UP * skull_ring(t)[2]


def top_at(z):
    y, _, ry = ring_at(TRUNK, z)
    return y + ry


def spine_line():
    line = []
    for j, (w, h) in list(zip(TAIL, TAIL_SHAPE))[::-1]:
        line.append((j, (w + h) * 0.5))
    for z, y, w, h in TRUNK:
        if TAIL[0].z < z < NECK.z:
            line.append((V(0.0, y, z), (w + h) * 0.5))
    line.append((NECK, 0.13))
    for t in (0.0, 0.15, 0.3, 0.45):
        rx, ry, _ = skull_ring(t)
        line.append((skull_at(t), (rx + ry) * 0.5))
    return line


SPINE = spine_line()


def on_spine(p):
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
    suffix = ("_f" if p.z > 0.0 else "_r") + ("l" if p.x >= 0.0 else "r")
    off, along = chain_param(p, LEGS[suffix])
    return suffix, blend(0.14, 0.09, off) * blend(0.12, 0.45, along) * blend(0.1, 0.2, abs(p.x))


def frame_for(ahead):
    side = ahead.cross(Y)
    if side.length < 0.3:
        side = ahead.cross(X)
    side.normalize()
    return side, ahead.cross(side).normalized()


def around_of(p, at, way):
    side = way.cross(Y).normalized() if abs(way.y) < 0.95 else X
    if side.dot(X) < 0.0:
        side = -side
    up = side.cross(way).normalized()
    if up.y < 0.0:
        up = -up
    d = p - at
    return math.atan2(d.dot(side), d.dot(up))


def lay_skin(bm):
    uv = bm.loops.layers.uv.verify()

    def unwrap(angle, near):
        return near + (angle - near + math.pi) % math.tau - math.pi

    for face in bm.faces:
        near = kit.from_blender(face.calc_center_median())
        suffix, share = leg_share(near)
        on_leg = share > 0.5
        _, n_at, n_way, _ = on_spine(near)
        near_round = around_of(near, n_at, n_way)
        joints = LEGS[suffix]
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            if on_leg:
                off, along = chain_param(p, joints)
                loop[uv].uv = (along * 0.3, math.atan2(p.y - 0.2, p.z - joints[1].z) * 0.06)
            else:
                along, at, way, radius = on_spine(p)
                loop[uv].uv = (along, unwrap(around_of(p, at, way), near_round) * radius)


def skinned(b, fuse):
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, 0.0)
    mesh = kit.fused(b, None if kit.LOW else fuse)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    lay_skin(bm)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def limb(b, joints, stations, segments=10):
    rings = []
    for s, r in stations:
        i = min(int(s), len(joints) - 2)
        t = s - i
        point = joints[i].lerp(joints[i + 1], t)
        ahead = (joints[i + 1] - joints[i]).normalized()
        if t < 0.15 and i > 0:
            ahead = ahead.lerp((joints[i] - joints[i - 1]).normalized(), 0.5).normalized()
        side, up = frame_for(ahead)
        rings.append((point, side * r, up * r))
    first = (joints[0] - joints[1]).normalized()
    b.tube(dome(rings[0], first, 0.04)[::-1] + rings, segments)


def foot(b, joints, fore):
    """The broad foot flat on the ground, its five spread toes, from the wrist or ankle to the toe tips."""
    wrist, tip = joints[2], joints[3]
    way = V(tip.x - wrist.x, 0.0, tip.z - wrist.z).normalized()
    side = way.cross(Y).normalized()
    # (the sole and the palm: a flat pad)
    palm = wrist.lerp(tip, 0.35) + V(0.0, -0.025, 0.0)
    b.ellipsoid(palm, V(0.055, 0.03, 0.075), Matrix.Rotation(math.atan2(way.x, way.z), 3, "Y"), 10, 5)
    b.strand([wrist + V(0, 0.02, 0), palm + V(0, 0.01, 0)], [0.05, 0.05], 8)
    for k in range(5):
        spread = (k - 2) * 0.32
        toe = (way * math.cos(spread) + side * math.sin(spread)).normalized()
        length = (0.07, 0.09, 0.11, 0.12, 0.1)[k] * (1.0 if fore else 1.15)
        root = palm + toe * 0.04
        b.strand([root, root + toe * length * 0.6 + V(0, -0.005, 0), root + toe * length + V(0, -0.015, 0)], [0.016, 0.013, 0.01], 6)


def claws_shapes():
    def shapes(b):
        for suffix, joints in LEGS.items():
            wrist, tip = joints[2], joints[3]
            fore = suffix[1] == "f"
            way = V(tip.x - wrist.x, 0.0, tip.z - wrist.z).normalized()
            side = way.cross(Y).normalized()
            palm = wrist.lerp(tip, 0.35) + V(0.0, -0.025, 0.0)
            for k in range(5):
                spread = (k - 2) * 0.32
                toe = (way * math.cos(spread) + side * math.sin(spread)).normalized()
                length = (0.07, 0.09, 0.11, 0.12, 0.1)[k] * (1.0 if fore else 1.15)
                end = palm + toe * (0.04 + length) + V(0, -0.015, 0)
                b.strand([end - toe * 0.01, end + toe * 0.022 + V(0, -0.008, 0), end + toe * 0.035 + V(0, -0.02, 0)], [0.009, 0.006, 0.0015], 5)
    return shapes


def body():
    def shapes(b):
        low = kit.LOW
        b.tube([kit.lengthwise(*ring) for ring in smooth_rings(TRUNK, 0.06)], 20)
        tail = [(j, X * w, Y * h) for j, (w, h) in zip(TAIL, TAIL_SHAPE)]
        b.tube([(TAIL[0] + V(0.0, 0.0, 0.12), X * 0.13, Y * 0.13)] + tail + dome(tail[-1], (TAIL[-1] - TAIL[-2]).normalized(), 0.02, 2), 12)
        # The short thick neck into the head
        way = (HEAD - NECK).normalized()
        b.tube([(NECK - way * 0.12, X * 0.14, Y * 0.15), (NECK, X * 0.13, Y * 0.14), (NECK.lerp(HEAD, 0.6), X * 0.11, Y * 0.13), (HEAD, X * 0.10, Y * 0.12)], 14)
        for side in (1.0, -1.0):
            # (the shoulder and the haunch over each leg)
            b.ellipsoid(V(side * 0.16, 0.42, 0.45), V(0.09, 0.1, 0.1), None, 12, 6)
            b.ellipsoid(V(side * 0.15, 0.41, -0.47), V(0.1, 0.11, 0.12), None, 12, 6)
        for suffix, joints in LEGS.items():
            fore = suffix[1] == "f"
            limb(b, joints, FORE_SHAPE if fore else HIND_SHAPE, 10 if not low else 6)
            foot(b, joints, fore)
        return skinned(b, (0.012, 3, 22000))
    return shapes


def head():
    def shapes(b):
        rings = [(skull_at(t), X * rx, SNOUT_UP * ry) for t, rx, ry, _ in SKULL]
        b.tube(dome(rings[0], -SNOUT_WAY, 0.04, 3)[::-1] + rings + dome(rings[-1], SNOUT_WAY, 0.035, 3), 16)
        for side in (1.0, -1.0):
            # (the brow over the eye, high and far back; the bulge of the jaw muscle behind it)
            b.ellipsoid(HEAD + SNOUT_WAY * 0.1 + SNOUT_UP * 0.085 + X * side * 0.075, V(0.035, 0.022, 0.05), None, 8, 4)
            b.ellipsoid(HEAD + SNOUT_WAY * 0.01 - SNOUT_UP * 0.02 + X * side * 0.08, V(0.04, 0.07, 0.07), None, 8, 4)
            # (the step in the upper jaw over the great canines)
            b.ellipsoid(HEAD + SNOUT_WAY * 0.36 - SNOUT_UP * 0.06 + X * side * 0.045, V(0.025, 0.04, 0.05), None, 8, 4)
        return skinned(b, (0.006, 2, 5000))
    return shapes


def jaw():
    def shapes(b):
        rings = [(JAW + JAW_WAY * t - JAW_UP * drop, X * rx, JAW_UP * ry) for t, rx, ry, drop in JAW_SHAPE]
        b.tube(dome(rings[0], -JAW_WAY, 0.03, 2)[::-1] + rings + dome(rings[-1], JAW_WAY, 0.025, 3), 12)
        return skinned(b, (0.006, 2, 1800))
    return shapes


def teeth(lower):
    """The two kinds of teeth: great stabbing canines at the front, small cutting teeth behind."""
    def shapes(b):
        for side in (1.0, -1.0):
            if not lower:
                # (upper: two long canines on each side, a few incisors at the front, a row of small teeth back)
                plan = [(0.355, 0.075, 0.012), (0.385, 0.06, 0.011), (0.44, 0.03, 0.007), (0.465, 0.026, 0.006)]
                plan += [(0.12 + 0.03 * k, 0.018, 0.006) for k in range(7)]
            else:
                plan = [(0.40, 0.04, 0.009), (0.445, 0.022, 0.006)] + [(0.1 + 0.035 * k, 0.015, 0.0055) for k in range(7)]
            for t, length, radius in plan:
                if lower:
                    rx = ring_at(JAW_SHAPE, t)[0]
                    root = JAW + JAW_WAY * t + JAW_UP * 0.03 + X * side * rx * 0.75
                    way = JAW_UP
                else:
                    rx, ry, up = skull_ring(t)
                    root = HEAD + SNOUT_WAY * t + SNOUT_UP * (up - ry * 0.8) + X * side * rx * 0.72
                    way = -SNOUT_UP
                # (curved back a little, as a dagger)
                b.strand([root, root + way * length * 0.55 - SNOUT_WAY * length * 0.06, root + way * length - SNOUT_WAY * length * 0.18],
                         [radius, radius * 0.7, radius * 0.15], 6)
    return shapes


def mouth():
    def shapes(b):
        b.ellipsoid(JAW + JAW_WAY * 0.24 + JAW_UP * 0.04, V(0.06, 0.02, 0.2), None, 10, 5)
    return shapes


def eyes():
    def shapes(b):
        t, up, radius = EYE
        for side in (1.0, -1.0):
            at = HEAD + SNOUT_WAY * t + SNOUT_UP * up + X * side * (skull_ring(t)[0] * 0.86)
            b.ellipsoid(at, V(radius * 0.7, radius * 0.8, radius), Matrix.Rotation(-side * 0.4, 3, "Y"), 8, 5)
    return shapes


def sail():
    """The skin stretched between the spines: a thin sheet, its top the arch of the spines."""
    def shapes(b):
        rings = []
        steps = 40 if not kit.LOW else 12
        for k in range(steps + 1):
            z = SAIL_FROM + (SAIL_TO - SAIL_FROM) * k / steps
            base = top_at(z) - 0.04
            h = sail_height(z) * 0.97
            rings.append((V(0.0, base + h * 0.5, z), X * 0.007, Y * h * 0.5))
        b.tube(rings, 8 if not kit.LOW else 4)
    return shapes


def spines():
    """The neural spines holding up the sail, standing a little out of its skin on both faces and at the top."""
    def shapes(b):
        count = 21 if not kit.LOW else 9
        for k in range(count):
            z = SAIL_FROM - 0.03 + (SAIL_TO - SAIL_FROM + 0.06) * k / (count - 1)
            base = top_at(z) - 0.05
            h = sail_height(z) + 0.012
            # (each leaning back a little, more towards the hips)
            lean = 0.04 + 0.05 * k / count
            points = [V(0.0, base, z), V(0.0, base + h * 0.5, z - lean * 0.4), V(0.0, base + h, z - lean)]
            b.strand(points, [0.016, 0.011, 0.008], 6)
    return shapes


def coat_weights(p):
    names = ["pelvis"] + TAIL_BONES
    off, along = chain_param(p, TAIL)
    if p.z < TAIL[0].z + 0.08:
        past = [1.0, blend(-0.4, 0.4, along)] + [blend(k - 0.4, k + 0.4, along) for k in range(1, len(TAIL_BONES))] + [0.0]
        return {name: past[i] - past[i + 1] for i, name in enumerate(names) if past[i] - past[i + 1] > 0.0}
    if p.z > NECK.z - 0.06:
        head = blend(NECK.z + 0.04, HEAD.z - 0.02, p.z)
        neck = blend(NECK.z - 0.06, NECK.z + 0.06, p.z)
        return {k: v for k, v in {"chest": 1.0 - neck, "neck": neck * (1.0 - head), "head": neck * head}.items() if v > 0.0}
    front = blend(-0.4, 0.45, p.z)
    return {"chest": front, "pelvis": 1.0 - front}


def weights():
    def weigh(part, p):
        if part in ("jaw", "mouth", "teeth_low"):
            return {"jaw": 1.0}
        if part in ("head", "eyes", "teeth"):
            return {"head": 1.0}
        if part == "claws":
            suffix = ("_f" if p.z > 0.0 else "_r") + ("l" if p.x >= 0.0 else "r")
            return {"hock" + suffix: 1.0}
        if part in ("sail", "spines"):
            return coat_weights(V(0.0, 0.4, p.z))
        trunk = coat_weights(p)
        suffix, leg = leg_share(p)
        if leg <= 0.0:
            return trunk
        joints = LEGS[suffix]
        along = chain_param(p, joints)[1]
        low = blend(0.85, 1.15, along)
        hock = blend(1.85, 2.05, along)
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + suffix] = leg * (1.0 - low)
        made["lower" + suffix] = leg * low * (1.0 - hock)
        made["hock" + suffix] = leg * low * hock
        return made
    return weigh


def bones():
    listed = [("body", BODY, None), ("chest", CHEST, "body"), ("pelvis", PELVIS, "body"),
              ("neck", NECK, "chest"), ("head", HEAD, "neck"), ("jaw", JAW, "head")]
    chain = ["pelvis"] + TAIL_BONES + ["tail_end"]
    for i, joint in enumerate(TAIL):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in LEGS.items():
        for bone, joint in zip(("upper", "lower", "hock", "hoof"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


MATERIALS = [("skin", (0.29, 0.27, 0.245)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "mouth": (0.23, 0.13, 0.12, 0.6), "eyes": (0.42, 0.30, 0.10, 1.0), "claws": (0.12, 0.11, 0.10, 0.15),
    "teeth": (0.70, 0.66, 0.56, 0.35), "teeth_low": (0.70, 0.66, 0.56, 0.35), "spines": (0.21, 0.19, 0.17, 0.05),
}


def parts():
    return [
        ("body", 0, body()), ("head", 0, head()), ("jaw", 0, jaw()), ("sail", 0, sail()),
        ("spines", 1, spines()), ("teeth", 1, teeth(False)), ("teeth_low", 1, teeth(True)),
        ("mouth", 1, mouth()), ("eyes", 1, eyes()), ("claws", 1, claws_shapes()),
    ]


def paint(whole, part_of):
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
            step = edge.other_vert(vert).co - vert.co
            if step.length > 1e-6:
                rise += step.dot(vert.normal) / step.length
        open_[vert.index] = rise / len(vert.link_edges)
    for _ in range(3):
        spread = list(open_)
        for vert in whole.verts:
            if hide[vert.index] and vert.link_edges:
                around = [open_[e.other_vert(vert).index] for e in vert.link_edges]
                spread[vert.index] = 0.5 * open_[vert.index] + 0.5 * sum(around) / len(around)
        open_ = spread
    measured = sorted(open_[i] for i in range(len(open_)) if hide[i])
    middle = measured[len(measured) // 2] if measured else 0.0
    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part in PART_COLOURS:
            r, g, bl, wet = PART_COLOURS[part]
            vert[layer] = (r, g, bl, wet)
            if part == "eyes":
                side = 1.0 if p.x >= 0.0 else -1.0
                t, up, radius = EYE
                centre = HEAD + SNOUT_WAY * t + SNOUT_UP * up + X * side * (skull_ring(t)[0] * 0.86)
                local = Matrix.Rotation(side * 1.3, 3, "Y").inverted() @ (p - centre)
                across_uv[vert.index] = (0.5 + local.x / (radius * 0.8) * 0.4, 0.5 + local.y / (radius * 0.8) * 0.4) if local.z > 0.0 else (0.95, 0.95)
            continue
        if part == "sail":
            # (darker than the body, with paler bands up it between the spines, darker to its top)
            band = 0.5 + 0.5 * math.sin(p.z * 31.0)
            up = blend(top_at(p.z), top_at(p.z) + sail_height(p.z), p.y)
            vert[layer] = (0.85, min(0.55 + 0.35 * up, 1.0) * (0.55 + 0.45 * band), 0.12 * (1.0 - band), 1.0)
            continue
        shade = min(max(1.0 - (open_[vert.index] - middle) * 4.0, 0.0), 1.0)
        _, at, way, radius = on_spine(p)
        side = way.cross(Y).normalized() if abs(way.y) < 0.95 else X
        up = side.cross(way).normalized()
        if up.y < 0.0:
            up = -up
        rise = (p - at).dot(up) / max(radius, 0.02)
        suffix, leg = leg_share(p)
        pale = blend(0.0, -0.8, rise) * (1.0 - leg * 0.5) * 0.9 + (blend(0.06, 0.0, p.y) * 0.4 if leg > 0.3 else 0.0)
        # (darker bands across the back and down the flanks and tail)
        bands = 0.5 + 0.5 * math.sin(-p.z * 9.0 + math.sin(p.x * 7.0) * 0.6)
        dark = min(max(blend(-0.3, 0.8, rise) * (0.35 + 0.65 * bands), 0.0), 1.0) * (1.0 - leg * 0.6)
        vert[layer] = (shade, dark, min(pale, 1.0), 1.0)
    second = whole.loops.layers.uv.new("UVMap2")
    uv = whole.loops.layers.uv.active
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))
            if part_of[loop.vert.index] == "sail":
                p = kit.from_blender(loop.vert.co)
                loop[uv].uv = (-p.z, p.y)


def export(preview):
    low = kit.LOW
    name = "dimetrodon" + ("_lo" if low else "")
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
    mesh.color_attributes.active_color = mesh.color_attributes["Color"]
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
    views = [("side", (1, 0, 0), (0.0, 0.5, 0.6), 4.0, "MATERIAL"), ("quarter", (0.7, -0.7, 0.3), (0.0, 0.3, 0.6), 4.0, "MATERIAL"),
             ("front", (0.02, -1, 0.1), (0.0, -0.5, 0.5), 2.0, "MATERIAL"), ("head", (0.8, -0.45, 0.15), (0.0, -1.05, 0.5), 0.8, "MATERIAL"),
             ("top", (0.05, 0.05, 1), (0.0, 0.5, 0.4), 4.0, "MATERIAL"), ("shade", (0.8, -0.5, 0.25), (0.0, 0.5, 0.6), 4.0, "VERTEX")]
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

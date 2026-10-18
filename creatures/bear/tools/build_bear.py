"""Builds the screaming bear (creatures/bear) and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/bear/tools/build_bear.py
    blender --background --python creatures/bear/tools/build_bear.py -- <preview folder>   # with pictures and a .blend

Writes creatures/bear/models/bear.glb and a demade bear_lo.glb. Nothing else
is written (an editable .blend goes to the preview folder, when there is one;
this folder has a .gdignore so that Godot does not try to import anything here).

It is a bear that something has got into and changed (in the spirit of the
mutated bear of the film Annihilation, but its own thing): a huge animal
starved to the bone, and wrong. The model stands a metre at the shoulder; the
game draws it more than twice that. The legs are far too long for it, so that
it stands high and gaunt over its own shadow, the elbows and knees bony knobs;
the trunk is pinched in to nothing behind a deep, narrow ribcage, the ribs
standing out under the skin, the hip bones and the knobs of the spine poking
up, a bony hump over the shoulders. The neck is long and thin and carries the
head low, out in front. The head is a bear's, but half of it is skull: on its
right the skin has gone from the muzzle, the cheek and round the eye, and the
bone shows, ivory and cracked, the eye in that side clouded white; it has no
lips at all, so its teeth (yellowed, long in the canines) show along both jaws,
in dark wet gums, all the time. Long curved claws.

Its coat is patchy: dark grey-brown fur, ragged and hanging, sloughing away
in places to show pale, blotched, veined skin (the coat's vertex colours,
green), and on its right flank the skin has gone too and some ribs show
through bare. Loose flaps of skin hang under its belly. Strings of bloody
slaver hang from its jaw.

The bones are the boar's (creatures/boar), with paws for hooves, so the same
kind of rig drives it (creatures/bear/bear_rig.gd). Each leg is three bones
and a paw:

    fore: `upper` (shoulder to elbow), `lower` (forearm), `hock` (wrist to the ball of the paw), `paw`
    hind: `upper` (thigh, hip to knee), `lower` (shin), `hock` (heel to the ball of the foot), `paw`

Its lower jaw is the bone `jaw`; strings of slaver hang from it on bones of
their own (`drool_l`, `drool_r`), which the rig swings.

The coat's vertex colours: red is how open the surface is (dark in creases);
green how bare (the fur sloughed off: pale skin); blue how far it is paler,
grizzled hair; alpha how far it is NOT bone (0: the bare skull).

Everything is in Godot space (metres, Y up, facing +Z, +X its left).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

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

BODY = V(0.0, 0.88, 0.0)
CHEST = V(0.0, 0.90, 0.24)
PELVIS = V(0.0, 0.86, -0.36)
NECK = V(0.0, 0.93, 0.44)
HEAD = V(0.0, 0.79, 0.80)
NECK_1 = NECK.lerp(HEAD, 0.5) + V(0.0, 0.02, 0.0)
# (the hinge of the lower jaw, under the back of the cheek)
JAW = HEAD + V(0.0, -0.072, 0.045)

# (along the body, centre height, half width, half height): a deep, narrow
# ribcage, the belly pinched up to nothing behind it, the bony hips
TRUNK = [(-0.60, 0.865, 0.055, 0.065), (-0.56, 0.865, 0.120, 0.135), (-0.48, 0.868, 0.150, 0.160),
         (-0.38, 0.878, 0.140, 0.145), (-0.26, 0.910, 0.108, 0.105), (-0.14, 0.905, 0.120, 0.150),
         (-0.02, 0.890, 0.150, 0.205), (0.10, 0.875, 0.172, 0.250), (0.22, 0.875, 0.180, 0.262),
         (0.32, 0.885, 0.170, 0.240), (0.41, 0.900, 0.145, 0.195), (0.48, 0.915, 0.105, 0.135)]

# Shoulder, elbow, wrist, the ball of the paw; hip, knee, heel, the ball of the
# foot (the left legs: the right are their mirror). Far too long for it.
FORE = [V(0.128, 0.880, 0.330), V(0.150, 0.565, 0.235), V(0.140, 0.135, 0.330), V(0.140, 0.040, 0.430)]
HIND = [V(0.112, 0.875, -0.440), V(0.135, 0.545, -0.290), V(0.128, 0.150, -0.500), V(0.126, 0.040, -0.335)]
# (how far down the leg, counted in joints; half width; half depth; forward offset):
# wasted, the bones of the joints standing out
FORE_SHAPE = [(-0.1, 0.060, 0.100, 0.0), (0.0, 0.074, 0.112, 0.0), (0.45, 0.058, 0.080, 0.0), (0.92, 0.050, 0.060, -0.010),
              (1.0, 0.056, 0.062, -0.012), (1.15, 0.046, 0.054, 0.0), (1.6, 0.048, 0.050, 0.004), (1.95, 0.054, 0.056, 0.0),
              (2.15, 0.062, 0.056, 0.0), (2.6, 0.070, 0.050, 0.0), (3.0, 0.068, 0.044, 0.0)]
HIND_SHAPE = [(-0.1, 0.070, 0.120, 0.0), (0.0, 0.088, 0.150, 0.0), (0.45, 0.068, 0.110, 0.0), (0.9, 0.050, 0.064, 0.010),
              (1.0, 0.054, 0.060, 0.012), (1.2, 0.044, 0.056, -0.004), (1.7, 0.036, 0.046, 0.0), (1.97, 0.042, 0.050, -0.008),
              (2.2, 0.050, 0.044, 0.0), (2.6, 0.055, 0.040, 0.0), (3.0, 0.054, 0.036, 0.0)]

# The head, from HEAD: a bear's broad skull, the muzzle long and straight.
MUZZLE_WAY = V(0.0, -0.15, 0.99).normalized()
MUZZLE_UP = V(0.0, MUZZLE_WAY.z, -MUZZLE_WAY.y)
MUZZLE_ROOT = V(0.0, 0.005, 0.095)
# (along it, half width, half height)
MUZZLE = [(0.0, 0.102, 0.092), (0.06, 0.094, 0.080), (0.11, 0.084, 0.069), (0.15, 0.074, 0.060), (0.17, 0.069, 0.055)]
ML = MUZZLE[-1][0]
JAW_WAY = V(0.0, -0.21, 0.977).normalized()
JAW_UP = V(0.0, JAW_WAY.z, -JAW_WAY.y)
# (along the jaw from JAW, half width, half height, how far its middle is below the line from the hinge)
JAW_SHAPE = [(-0.02, 0.084, 0.052, 0.0), (0.06, 0.076, 0.040, 0.004), (0.12, 0.064, 0.032, 0.006),
             (0.16, 0.055, 0.026, 0.006), (0.19, 0.048, 0.022, 0.004)]
JL = JAW_SHAPE[-1][0]
# (the left eye is its own, small and dark; the right, in the bare skull, is clouded)
EYE = (V(0.072, 0.045, 0.110), 0.0145)
EAR = [V(0.092, 0.110, -0.030), V(0.112, 0.152, -0.042), V(0.120, 0.180, -0.052)]
TAIL = [V(0.0, 0.900, -0.590), V(0.0, 0.860, -0.640), V(0.0, 0.800, -0.655)]
TAIL_SHAPE = [0.030, 0.028, 0.020, 0.012]
DROOL = (V(0.040, -0.100, 0.170), 0.12)


def legs():
    made = {}
    for suffix in SUFFIXES:
        side = 1.0 if suffix[2] == "l" else -1.0
        made[suffix] = [V(j.x * side, j.y, j.z) for j in (FORE if suffix[1] == "f" else HIND)]
    return made


LEGS = legs()


def trunk_at(z):
    """The trunk's (centre height, half width, half height) at `z` along it."""
    rings = TRUNK
    if z <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return rings[-1][1:]


# The bony hump over its shoulders.
HUMP = (V(0.0, 1.06, 0.25), V(0.130, 0.120, 0.210))


def top_at(z):
    y, _, ry = trunk_at(z)
    top = y + ry
    c, r = HUMP
    u = (z - c.z) / r.z
    if abs(u) < 1.0:
        top = max(top, c.y + r.y * math.sqrt(1.0 - u * u))
    return top


def on_flank(side, z, rise, out=0.0):
    """A point on the side of the trunk at `z`, `rise` of the way from its middle to its top (negative: down)."""
    y, rx, ry = trunk_at(z)
    rise = max(min(rise, 0.98), -0.98)
    return V(side * (rx * math.sqrt(1.0 - rise * rise) + out), y + ry * rise, z)


def muzzle_ring(t):
    rings = MUZZLE
    if t <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if t <= b[0]:
            u = (t - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * u for k in (1, 2))
    return rings[-1][1:]


def muzzle_at(t):
    """The middle of the muzzle `t` along it."""
    return HEAD + MUZZLE_ROOT + MUZZLE_WAY * t


def tooth_line(t, side):
    """Where the upper teeth come out of the muzzle, `t` along it, on one side."""
    rx, ry = muzzle_ring(t)
    return muzzle_at(t) + X * side * rx * 0.70 - MUZZLE_UP * ry * 0.80


def jaw_line(t, side):
    rx = jaw_ring(t)[0]
    return JAW + JAW_WAY * t + X * side * rx * 0.70 + JAW_UP * (jaw_ring(t)[1] * 0.75 - jaw_ring(t)[2])


def jaw_ring(t):
    rings = JAW_SHAPE
    if t <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if t <= b[0]:
            u = (t - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * u for k in (1, 2, 3))
    return rings[-1][1:]


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
    suffix = ("_f" if p.z > -0.08 else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = LEGS[suffix]
    top = joints[0]
    off = chain_param(V(top.x, p.y, p.z), joints)[0]
    return suffix, blend(top.y - 0.06, top.y - 0.24, p.y) * blend(0.16, 0.09, math.hypot(p.x - top.x, off / 1.6))


def leg_axis(joints, y):
    for a, b in zip(joints, joints[1:]):
        if y >= b.y:
            return a.z + (b.z - a.z) * min(max((a.y - y) / (a.y - b.y), 0.0), 1.0)
    return joints[-1].z


def lay_fur(bm, ears=False):
    """The texture coordinates the coat shader reads: (along the lie of the
    hair, across it), in metres. The hair lies back from the nose to the tail,
    and down each leg (as the boar's)."""
    uv = bm.loops.layers.uv.verify()

    def around(x, y, near_x, near_y, radius):
        near = math.atan2(near_x, near_y)
        return (near + (math.atan2(x, y) - near + math.pi) % math.tau - math.pi) * radius

    def axis(z):
        return BODY.y + (HEAD.y - BODY.y) * blend(NECK.z, HEAD.z, z)

    for face in bm.faces:
        near = kit.from_blender(face.calc_center_median())
        suffix, _ = leg_share(near)
        joints = LEGS[suffix]
        hip = joints[0]
        out = 1.0 if hip.x > 0.0 else -1.0
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            if ears:
                loop[uv].uv = ((p - HEAD).length - 2.0, p.z)
                continue
            leg = leg_share(p)[1]
            trunk = (-p.z, around(p.x, p.y - axis(p.z), near.x, near.y - axis(near.z), 0.2))
            limb_uv = (hip.y - p.y - hip.z, around(p.z - leg_axis(joints, p.y), (p.x - hip.x) * out,
                                                  near.z - leg_axis(joints, near.y), (near.x - hip.x) * out, 0.05))
            loop[uv].uv = (trunk[0] + (limb_uv[0] - trunk[0]) * leg, trunk[1] + (limb_uv[1] - trunk[1]) * leg)


def furred(b, fuse):
    for vert in b.bm.verts:
        vert.co.z = max(vert.co.z, 0.0)  # nothing goes through the ground
    mesh = kit.fused(b, None if kit.LOW else fuse)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    lay_fur(bm)
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
            ahead = directions[i].lerp(directions[min(i + 1, last)], t - 0.5)
        across = ahead.normalized().cross(X).normalized()
        rings.append((point + across * shift, X * rx, across * rd))
    b.tube(dome(rings[0], -directions[0], 0.05)[::-1] + rings + dome(rings[-1], directions[-1], 0.03), segments)


def rib_points(side, k, count=8):
    """The line of one rib round the ribcage, from the spine down to the breastbone."""
    z0 = -0.04 + 0.055 * k
    points = []
    for rise in (0.92, 0.6, 0.25, -0.15, -0.5, -0.8):
        # (ribs slope back as they go down)
        z = z0 - (0.92 - rise) * 0.05
        points.append(on_flank(side, z, rise, 0.004))
    return points


def coat():
    def shapes(b):
        low = kit.LOW
        rings = [kit.lengthwise(*ring) for ring in TRUNK]
        b.tube(dome(rings[0], -Z, 0.05)[::-1] + rings + dome(rings[-1], Z, 0.05), 20)
        # The bony hump over the shoulders, and the shoulder blades either side of it
        c, r = HUMP
        b.ellipsoid(c, r, None, 14, 8)
        for side in (1.0, -1.0):
            blade = FORE[0].lerp(FORE[1], -0.15)
            b.ellipsoid(V(side * (blade.x + 0.012), blade.y + 0.0, blade.z + 0.0), V(0.030, 0.130, 0.080), Matrix.Rotation(0.35, 3, "X"))
            # the haunch, wasted, and the point of the hip standing up out of it
            thigh = HIND[0].lerp(HIND[1], 0.3)
            b.ellipsoid(V(side * (thigh.x + 0.008), thigh.y - 0.01, thigh.z - 0.02), V(0.055, 0.150, 0.115), Matrix.Rotation(-0.40, 3, "X"))
            b.ellipsoid(V(side * 0.105, 0.985, -0.36), V(0.034, 0.030, 0.060), Matrix.Rotation(0.3, 3, "X"))
            b.ellipsoid(V(side * 0.075, 0.945, -0.55), V(0.030, 0.028, 0.040))
            if not low:
                # The ribs standing out under the skin
                for k in range(8):
                    pts = rib_points(side, k)
                    b.strand(pts, [0.008, 0.011, 0.012, 0.012, 0.010, 0.008], 6)
        # The knobs of the spine down its back
        if not low:
            for k in range(13):
                z = 0.42 - k * 0.075
                b.ellipsoid(V(0.0, top_at(z) - 0.004, z), V(0.020, 0.020, 0.026), None, 8, 4)
        # The point of the chest, low between the forelegs
        b.ellipsoid(V(0.0, 0.72, 0.38), V(0.090, 0.090, 0.085))
        for suffix, joints in LEGS.items():
            limb(b, joints, FORE_SHAPE if suffix[1] == "f" else HIND_SHAPE, 12)
            # The paw: a broad pad of toes at the end of each leg
            ball = joints[3]
            fore = suffix[1] == "f"
            heel = joints[2]
            b.ellipsoid(ball.lerp(heel, 0.25), V(0.074 if fore else 0.062, 0.038, 0.085 if fore else 0.12), None, 10, 5)
            # the bony knob of each elbow and knee
            b.ellipsoid(joints[1] + V(0.0, 0.0, -0.035 if fore else 0.03), V(0.040, 0.040, 0.040), None, 8, 4)

        # The neck: long and thin, the cords of it showing, carrying the head low
        base, top = NECK, HEAD + V(0.0, 0.0, -0.04)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top, t) - across * sag, X * r, across * (r * 1.15)) for t, r, sag in
                ((-0.35, 0.130, 0.0), (0.0, 0.118, 0.01), (0.35, 0.092, 0.02), (0.7, 0.088, 0.02), (1.05, 0.100, 0.0))], 16)
        if not low:
            for side in (1.0, -1.0):
                b.strand([base + V(side * 0.07, -0.06, 0.0), base.lerp(top, 0.5) + V(side * 0.068, -0.075, 0.0), top + V(side * 0.06, -0.06, 0.0)], [0.016, 0.014, 0.014], 6)

        # The head: a broad skull with a heavy brow, and the long muzzle
        h = HEAD
        b.ellipsoid(h + V(0.0, 0.035, -0.010), V(0.140, 0.116, 0.140), None, 14, 8)
        b.ellipsoid(h + V(0.0, 0.078, 0.072), V(0.104, 0.044, 0.070))  # the brow
        for side in (1.0, -1.0):
            b.ellipsoid(h + V(side * 0.100, -0.015, 0.045), V(0.055, 0.060, 0.085), Matrix.Rotation(0.2, 3, "X"))  # the cheek
        rings = [(muzzle_at(t), X * rx, MUZZLE_UP * ry) for t, rx, ry in MUZZLE]
        b.tube([(h + V(0.0, 0.01, -0.01), X * 0.10, Y * 0.10)] + rings + dome(rings[-1], MUZZLE_WAY, 0.03, 2), 14)
        return furred(b, (0.0055, 4, 44000))
    return shapes


def jaw():
    def shapes(b):
        rings = [(JAW + JAW_WAY * t - JAW_UP * drop, X * rx, JAW_UP * ry) for t, rx, ry, drop in JAW_SHAPE]
        b.tube(dome(rings[0], -JAW_WAY, 0.03, 2)[::-1] + rings + dome(rings[-1], JAW_WAY, 0.022, 3), 12)
        return furred(b, (0.0045, 2, 2600))
    return shapes


def nose():
    def shapes(b):
        tip = muzzle_at(MUZZLE[-1][0]) + MUZZLE_WAY * 0.030 + MUZZLE_UP * 0.012
        b.ellipsoid(tip, V(0.046, 0.030, 0.022), Matrix.Rotation(-0.2, 3, "X"), 10, 5)
    return shapes


def nostrils():
    def shapes(b):
        tip = muzzle_at(MUZZLE[-1][0]) + MUZZLE_WAY * 0.045 + MUZZLE_UP * 0.012
        for side in (1.0, -1.0):
            b.ellipsoid(tip + X * side * 0.016, V(0.010, 0.008, 0.006), None, 6, 3)
        # (on its bare side, the hole in the skull where the nose was)
        b.ellipsoid(muzzle_at(0.12) - X * 0.042 + MUZZLE_UP * 0.024, V(0.010, 0.016, 0.030), Matrix.Rotation(0.2, 3, "Z"), 6, 3)
    return shapes


def gums():
    """Dark wet gums the full length of both jaws: it has no lips."""
    def shapes(b):
        for side in (1.0, -1.0):
            b.strand([tooth_line(t, side) - X * side * 0.004 + MUZZLE_UP * 0.006 for t in (0.03, 0.07, 0.11, 0.14, ML - 0.005)], [0.008, 0.009, 0.009, 0.008, 0.007], 6)
    return shapes


def lower_gums():
    def shapes(b):
        for side in (1.0, -1.0):
            b.strand([jaw_line(t, side) - X * side * 0.004 - JAW_UP * 0.004 for t in (0.02, 0.07, 0.12, 0.16, JL - 0.005)], [0.008, 0.009, 0.009, 0.008, 0.007], 6)
    return shapes


def teeth_on(b, line, up, count, canine_at, length, canine_length, end):
    for k in range(count):
        t = 0.03 + (end - 0.03) * k / (count - 1)
        root = line(t)
        canine = abs(t - canine_at) < 0.012
        long = canine_length if canine else length * (0.75 + 0.4 * ((k * 7) % 5) / 4.0)
        lean = MUZZLE_WAY * (0.25 if canine else 0.05)
        kit.spike(b, root + up * 0.004, root - up * long + lean * long, 0.0085 if canine else 0.0062, 6 if canine else 5)


def upper_teeth():
    def shapes(b):
        for side in (1.0, -1.0):
            teeth_on(b, lambda t: tooth_line(t, side), MUZZLE_UP, 6 if not kit.LOW else 4, ML - 0.02, 0.020, 0.060, ML - 0.02)
            # (the front teeth, across the tip)
        for k in (-1.5, -0.5, 0.5, 1.5):
            root = tooth_line(ML - 0.002, 1.0).lerp(tooth_line(ML - 0.002, -1.0), 0.5 + k * 0.17) + MUZZLE_WAY * 0.010
            kit.spike(b, root, root - MUZZLE_UP * 0.022 + MUZZLE_WAY * 0.004, 0.0055, 5)
    return shapes


def lower_teeth():
    def shapes(b):
        for side in (1.0, -1.0):
            teeth_on(b, lambda t: jaw_line(t, side), -JAW_UP, 5 if not kit.LOW else 3, JL - 0.03, 0.018, 0.052, JL - 0.03)
        for k in (-1.0, 0.0, 1.0):
            root = jaw_line(JL - 0.01, 1.0).lerp(jaw_line(JL - 0.01, -1.0), 0.5 + k * 0.2) + JAW_WAY * 0.008
            kit.spike(b, root, root + JAW_UP * 0.020 + JAW_WAY * 0.006, 0.005, 5)
    return shapes


def mouth():
    """The dark inside of its mouth, seen between the teeth."""
    def shapes(b):
        b.ellipsoid(JAW + JAW_WAY * 0.14 + V(0.0, 0.035, 0.0), V(0.050, 0.030, 0.15), Matrix.Rotation(-0.30, 3, "X"), 10, 5)
    return shapes


def tongue():
    def shapes(b):
        b.ellipsoid(JAW + JAW_WAY * 0.15 + V(0.0, 0.020, 0.0), V(0.036, 0.013, 0.12), Matrix.Rotation(-0.30, 3, "X"), 10, 5)
    return shapes


def skull_bones():
    """The bare bone of its right side: the ridge of the cheekbone and the rim of the eye socket."""
    def shapes(b):
        h = HEAD
        e, r = EYE
        socket = h + V(-e.x, e.y, e.z)
        # the rim of the socket, a ring of bone
        ring = []
        for k in range(9):
            a = k / 8.0 * math.tau
            ring.append(socket + V(-0.006 + math.cos(a) * 0.004, math.sin(a) * r * 1.7, math.cos(a) * r * 1.9) + V(-0.010, 0.0, 0.0))
        b.strand(ring, [0.0038] * len(ring), 5)
        # the cheekbone sweeping back from under the socket
        b.strand([socket + V(-0.012, -0.030, 0.010), h + V(-0.100, -0.030, -0.010), h + V(-0.104, -0.020, -0.060)], [0.010, 0.012, 0.009], 6)
    return shapes


def sockets():
    def shapes(b):
        e, r = EYE
        b.ellipsoid(HEAD + V(-e.x + 0.007, e.y, e.z - 0.002), V(r * 1.1, r * 1.6, r * 1.7), Matrix.Rotation(0.5, 3, "Y"), 8, 5)
    return shapes


def eyes():
    def shapes(b):
        at, radius = EYE
        for side in (1.0, -1.0):
            grow = 1.0 if side > 0.0 else 1.2
            b.ellipsoid(HEAD + V(side * (at.x + (0.003 if side < 0.0 else 0.0)), at.y, at.z), V(radius * 0.8 * grow, radius * 0.7 * grow, radius * grow), Matrix.Rotation(-side * 0.55, 3, "Y"), 8, 5)
    return shapes


def ear_curve(t, side):
    root, mid, end = EAR
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return HEAD + V(at.x * side, at.y, at.z)


EAR_RINGS = ((0.0, 0.050, 0.018), (0.25, 0.064, 0.014), (0.6, 0.062, 0.012), (0.85, 0.046, 0.009), (1.0, 0.014, 0.006))


def ears():
    def shapes(b):
        for side in (1.0, -1.0):
            wide = V(side * 0.85, 0.0, -0.5).normalized()
            face = V(side * 0.5, 0.0, 0.85).normalized()
            rings = []
            for t, half, thick in EAR_RINGS:
                if side < 0.0 and t > 0.4:
                    # (its right ear is half gone, ragged)
                    half *= 0.45
                rings.append((ear_curve(t if side > 0.0 else t * 0.7, side), wide * half, face * thick))
            b.tube(dome(rings[0], -Y, 0.010, 2)[::-1] + rings, 10)
        lay_fur(b.bm, True)
    return shapes


def claws():
    """Long, curved, dark claws: five on each paw, longest on the fore."""
    def shapes(b):
        for suffix, joints in LEGS.items():
            ball = joints[3]
            fore = suffix[1] == "f"
            ahead = V(0.0, 0.0, 1.0)
            side = 1.0 if suffix[2] == "l" else -1.0
            for k in range(5):
                spread = (k - 2) / 2.0
                root = ball + V(spread * (0.044 if fore else 0.038) * side, 0.010, (0.055 if fore else 0.075) - abs(spread) * 0.014)
                length = (0.085 if fore else 0.045) * (1.0 - abs(spread) * 0.15)
                pts = [root, root + ahead * length * 0.55 + V(spread * 0.006, -0.004, 0.0), root + ahead * length + V(spread * 0.01, -0.032, 0.0)]
                b.strand(pts, [0.010, 0.0075, 0.0025], 5)
    return shapes


def exposed_ribs():
    """On its right flank, where skin and all have gone, some ribs bare."""
    def shapes(b):
        for k in (2, 3, 4, 5):
            pts = [onto_coat(p, 0.004) for p in rib_points(-1.0, k)[1:5]]
            b.strand(pts, [0.009, 0.010, 0.010, 0.008], 6)
    return shapes


def flaps():
    """Loose flaps of skin hanging from its belly and flank."""
    def shapes(b):
        for z, side, length in ((0.06, 1.0, 0.11), (-0.10, -1.0, 0.15), (0.20, -1.0, 0.08)):
            top = on_flank(side, z, -0.85)
            pts = [top, top + V(side * 0.01, -length * 0.5, -0.01), top + V(side * 0.004, -length, -0.02)]
            b.tube([(p, X * (0.026 - 0.008 * i), Z * 0.004) for i, p in enumerate(pts)], 6)
    return shapes


def drool():
    def shapes(b):
        at, length = DROOL
        for side in (1.0, -1.0):
            top = HEAD + V(at.x * side, at.y, at.z)
            b.strand([top, top + V(side * 0.004, -length * 0.5, 0.004), top + V(side * 0.002, -length, 0.0)], [0.0035, 0.0025, 0.005], 6)
    return shapes


def tail_shapes():
    def shapes(b):
        b.strand(TAIL, TAIL_SHAPE[:3], 8)
    return shapes


def bare_at(p):
    """How bare its skin is at `p`, 0 (fur) to 1 (the fur sloughed off)."""
    def noise3(q, scale):
        return 0.5 + 0.25 * (math.sin(q.x * scale * 1.7 + q.z * scale * 0.9 + 0.3) + math.sin(q.y * scale * 2.3 - q.z * scale * 1.3 + 1.7))
    n = noise3(p, 16.0) * 0.6 + noise3(p, 41.0) * 0.4
    y, rx, ry = trunk_at(p.z)
    patches = 0.0
    # its right flank, over the ribs
    patches = max(patches, blend(-0.04, -0.10, p.x) * blend(-0.12, -0.02, p.z) * blend(0.42, 0.32, p.z) * blend(y + ry * 0.75, y + ry * 0.5, p.y))
    # a patch on the left haunch, and down the spine
    patches = max(patches, blend(0.15, 0.07, (p - V(0.13, 0.82, -0.40)).length))
    patches = max(patches, blend(0.03, 0.0, abs(p.x)) * blend(-0.05, -0.30, p.z) * blend(y + ry * 0.8, y + ry, p.y) * 0.9)
    # the right side of its neck, its left shoulder, and its legs here and there
    q = p - NECK.lerp(HEAD, 0.4)
    patches = max(patches, blend(0.10, 0.04, (q - V(-0.09, -0.02, 0.0)).length))
    patches = max(patches, blend(0.10, 0.05, (p - V(0.16, 0.78, 0.28)).length))
    patches = max(patches, blend(0.06, 0.02, abs(p.y - 0.32 - 0.1 * math.sin(p.z * 9.0))) * blend(0.45, 0.6, n) * blend(0.6, 0.2, p.y))
    random = blend(0.76, 0.84, n)
    return min(max(patches * blend(0.15, 0.4, n + 0.15), random), 1.0)


def bone_at(p):
    """How far the skin has gone from the bone at `p`, on its head: its right
    cheek and round the right eye, and the end of the muzzle."""
    q = p - HEAD
    if q.z < -0.06:
        return 0.0
    rag = 0.012 * math.sin(q.y * 140.0 + q.z * 60.0) + 0.01 * math.sin(q.z * 210.0)
    side = blend(-0.012 + rag, -0.04 + rag, q.x) * blend(-0.03, 0.03, q.z) * blend(0.085 + rag, 0.05, q.y)
    tip = blend(0.21 + rag, 0.245 + rag, q.z) * blend(0.0, -0.02, q.x - 0.03)
    return min(max(side, tip), 1.0)


def scar_lines():
    return []


# The coat as built, to lay things on: a tree of its faces (set by `export`).
COAT = None


def onto_coat(p, lift=0.0):
    if COAT is None:
        return p
    found, normal, _, _ = COAT.find_nearest(kit.to_blender(p))
    if found is None:
        return p
    return kit.from_blender(found + normal * lift)


def weights():
    tail_names = ["pelvis", "tail", "tail_1"]

    def weigh(part, p):
        if part in ("jaw", "tongue", "lower_teeth", "lower_gums"):
            return {"jaw": 1.0}
        if part in ("upper_teeth", "gums", "eyes", "nose", "nostrils", "mouth", "skull_bones", "sockets"):
            return {"head": 1.0}
        if part == "drool":
            side = "_l" if p.x >= 0.0 else "_r"
            at, length = DROOL
            top = HEAD.y + at.y
            hung = blend(top - 0.01, top - length * 0.8, p.y)
            return {"jaw": 1.0 - hung, "drool" + side: hung}
        if part == "ears":
            suffix = "_l" if p.x >= 0.0 else "_r"
            side = 1.0 if p.x >= 0.0 else -1.0
            root, mid, end = (HEAD + V(j.x * side, j.y, j.z) for j in EAR)
            along = (p - root).dot((end - root).normalized())
            joint = (mid - root).dot((end - root).normalized())
            hung = blend(0.0, 0.03, along)
            tip = blend(joint - 0.02, joint + 0.02, along)
            return {"head": 1.0 - hung, "ear" + suffix: hung * (1.0 - tip), "ear_tip" + suffix: hung * tip}
        if part == "tail":
            _, along = chain_param(p, TAIL)
            past = [1.0, blend(0.0, 0.5, along), blend(0.7, 1.4, along), 0.0]
            return {name: past[i] - past[i + 1] for i, name in enumerate(tail_names)}
        if part == "claws":
            suffix = ("_f" if p.z > -0.08 else "_r") + ("l" if p.x >= 0.0 else "r")
            return {"paw" + suffix: 1.0}
        front = blend(-0.25, 0.12, p.z)
        trunk = {"chest": front, "pelvis": 1.0 - front}
        if part in ("exposed_ribs", "flaps"):
            return trunk
        base, top = NECK, HEAD
        reach = (p - base).dot((top - base).normalized()) / (top - base).length
        if reach > -0.2 and p.z > base.z - 0.06 and p.y > 0.62:
            neck = blend(-0.1, 0.35, reach)
            upper = blend(0.35, 0.75, reach)
            head = blend(0.72, 1.0, reach)
            return {"chest": 1.0 - neck, "neck": neck * (1.0 - upper), "neck_1": neck * upper * (1.0 - head), "head": neck * upper * head}
        suffix, leg = leg_share(p)
        joints = LEGS[suffix]
        along = chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.06 / spans[0], 1.0 + 0.06 / spans[1], along)
        hock = blend(2.0 - 0.045 / spans[1], 2.0 + 0.04 / spans[2], along)
        fore = suffix[1] == "f"
        # (the paw: what is in front of the ball of the foot, and low)
        paw = blend(joints[3].y + 0.05, joints[3].y + 0.015, p.y) * blend(joints[3].z - (0.02 if fore else 0.06), joints[3].z + 0.02, p.z)
        made = {bone: weight * (1.0 - leg) for bone, weight in trunk.items()}
        made["upper" + suffix] = leg * (1.0 - low)
        made["lower" + suffix] = leg * low * (1.0 - hock)
        made["hock" + suffix] = leg * low * hock * (1.0 - paw)
        made["paw" + suffix] = leg * low * hock * paw
        return made
    return weigh


def bones():
    listed = [
        ("body", BODY, None), ("chest", CHEST, "body"), ("pelvis", PELVIS, "body"),
        ("neck", NECK, "chest"), ("neck_1", NECK_1, "neck"), ("head", HEAD, "neck_1"), ("jaw", JAW, "head"),
    ]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root, mid, end = (HEAD + V(j.x * side, j.y, j.z) for j in EAR)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
        at, length = DROOL
        top = HEAD + V(at.x * side, at.y, at.z)
        listed.append(("drool" + suffix, top + V(0.0, -0.01, 0.0), "jaw"))
        listed.append(("drool_end" + suffix, top + V(0.0, -length, 0.0), "drool" + suffix))
    chain = ["pelvis", "tail", "tail_1", "tail_end"]
    for i, joint in enumerate(TAIL):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in LEGS.items():
        for bone, joint in zip(("upper", "lower", "hock", "paw"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


## Two materials, so that it is few draws: the coat (with its fur, its bare
## skin and its bare skull), and everything else (`parts`), whose colours are
## in its vertex colours: (sRGB colour, and in alpha how wet it is: 1 shines like an eye).
MATERIALS = [("coat", (0.15, 0.135, 0.12)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "mouth": (0.10, 0.04, 0.04, 0.6), "tongue": (0.30, 0.17, 0.18, 0.7),
    "upper_teeth": (0.64, 0.58, 0.44, 0.35), "lower_teeth": (0.64, 0.58, 0.44, 0.35),
    "gums": (0.24, 0.11, 0.11, 0.85), "lower_gums": (0.24, 0.11, 0.11, 0.85),
    "eyes": (0.10, 0.07, 0.05, 1.0), "nose": (0.10, 0.09, 0.09, 0.8), "nostrils": (0.02, 0.015, 0.015, 0.4),
    "claws": (0.07, 0.065, 0.06, 0.25), "drool": (0.42, 0.30, 0.28, 0.95),
    "skull_bones": (0.70, 0.66, 0.56, 0.15), "sockets": (0.025, 0.02, 0.02, 0.3),
    "exposed_ribs": (0.66, 0.62, 0.52, 0.2), "flaps": (0.50, 0.46, 0.44, 0.3),
}


def parts():
    # (name, material index, shapes): the coat and the jaw fuse themselves
    return [
        ("coat", 0, coat()), ("jaw", 0, jaw()), ("ears", 0, ears()), ("tail", 0, tail_shapes()),
        ("nose", 1, nose()), ("nostrils", 1, nostrils()), ("mouth", 1, mouth()), ("tongue", 1, tongue()),
        ("gums", 1, gums()), ("lower_gums", 1, lower_gums()), ("upper_teeth", 1, upper_teeth()), ("lower_teeth", 1, lower_teeth()),
        ("skull_bones", 1, skull_bones()), ("sockets", 1, sockets()), ("eyes", 1, eyes()), ("claws", 1, claws()),
        ("exposed_ribs", 1, exposed_ribs()), ("flaps", 1, flaps()), ("drool", 1, drool()),
    ]


# --- Shading baked into the coat ---

def paint(whole, part_of):
    """Vertex colours. On the coat: red, how open the surface is (low in
    grooves and creases); green, how bare; blue, how pale the hair; alpha, how
    far it is not bone. On the other parts, their colours (see PART_COLOURS)."""
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred = [part in ("coat", "jaw", "ears", "tail") for part in part_of]
    across_uv = {}
    open_ = [1.0] * len(whole.verts)
    for vert in whole.verts:
        if not furred[vert.index] or not vert.link_edges:
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
            if furred[vert.index] and vert.link_edges:
                around = [open_[e.other_vert(vert).index] for e in vert.link_edges]
                spread[vert.index] = 0.5 * open_[vert.index] + 0.5 * sum(around) / len(around)
        open_ = spread
    measured = sorted(open_[i] for i in range(len(open_)) if furred[i])
    middle = measured[len(measured) // 2] if measured else 0.0

    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part in PART_COLOURS:
            r, g, bl, wet = PART_COLOURS[part]
            if part in ("upper_teeth", "lower_teeth"):
                # (stained dark at the gum, yellowed)
                q = p - HEAD
                tone = 0.75 + 0.25 * math.sin(q.z * 300.0 + q.y * 120.0) ** 2
                r, g, bl = r * tone, g * tone * 0.97, bl * tone * 0.88
            elif part == "eyes" and p.x < 0.0:
                # (its right eye, in the bare skull, clouded over)
                r, g, bl = 0.72, 0.74, 0.74
            elif part == "claws":
                tip = blend(0.03, 0.0, p.y)
                r, g, bl = r + 0.25 * tip, g + 0.22 * tip, bl + 0.18 * tip
            vert[layer] = (r, g, bl, wet)
            if part == "eyes":
                side = 1.0 if p.x >= 0.0 else -1.0
                at, radius = EYE
                centre = HEAD + V(side * at.x, at.y, at.z)
                local = Matrix.Rotation(side * 0.9, 3, "Y").inverted() @ (p - centre)
                if local.z > 0.0:
                    across_uv[vert.index] = (0.5 + local.x / (radius * 0.8) * 0.4, 0.5 + local.y / (radius * 0.7) * 0.4)
                else:
                    across_uv[vert.index] = (0.95, 0.95)
            continue
        shade = 1.0
        pale = 0.0
        bare = 0.0
        bone = 0.0
        if furred[vert.index]:
            shade = min(max(1.0 - (open_[vert.index] - middle) * 4.5, 0.0), 1.0)
            y, rx, ry = trunk_at(p.z)
            q = p - HEAD
            on_head = q.z > -0.08 and p.y > 0.6
            muzzle = blend(0.10, 0.22, q.z) * 0.5 if on_head else 0.0
            belly = blend(y - ry * 0.3, y - ry * 0.9, p.y) * 0.4
            pale = max(muzzle, belly)
            bare = bare_at(p)
            if on_head:
                bone = bone_at(p)
                # (raw skin round the edge of the bone)
                bare = max(bare, blend(0.0, 0.5, bone_at(p + V(-0.02, 0.0, 0.0))) * (1.0 - bone))
            if part == "jaw":
                # (the bare jaw bone on its right and at its tip)
                bone = max(bone, blend(-0.012, -0.035, p.x) * blend(0.03, 0.08, (p - JAW).dot(JAW_WAY)) * 0.9, blend(JL - 0.03, JL, (p - JAW).dot(JAW_WAY)))
        vert[layer] = (shade, bare, pale, 1.0 - bone)
    second = whole.loops.layers.uv.new("UVMap2")
    for face in whole.faces:
        for loop in face.loops:
            loop[second].uv = across_uv.get(loop.vert.index, (0.95, 0.95))


def _bm_of(mesh):
    made = bmesh.new()
    made.from_mesh(mesh)
    return made


def export(preview):
    low = kit.LOW
    name = "bear" + ("_lo" if low else "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = kit.make_armature(bones())
    whole = bmesh.new()
    whole.loops.layers.uv.verify()
    part_of = []
    for part, material, shapes in parts():
        builder = kit.Builder()
        ready = shapes(builder)
        if ready is None and part in ("tail", "ears"):
            ready = furred(builder, None) if part == "tail" else None
        mesh = ready if ready is not None else kit.fused(builder, None)
        if part == "coat":
            global COAT
            COAT = BVHTree.FromBMesh(_bm_of(mesh))
        first = len(whole.faces)
        whole.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        whole.faces.ensure_lookup_table()
        for face in whole.faces[first:]:
            face.material_index = material
            face.smooth = not low
        part_of += [part] * (len(whole.verts) - len(part_of))
    paint(whole, part_of)

    mesh = bpy.data.meshes.new(name)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    for label, srgb in MATERIALS:
        made = bpy.data.materials.new(label)
        made.use_nodes = True
        colour = tuple(kit.linear(c) for c in srgb) + (1.0,)
        bsdf = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Roughness"].default_value = 1.0
        made.diffuse_color = colour
        mesh.materials.append(made)
    groups = {bone.name: body.vertex_groups.new(name=bone.name).index for bone in armature.data.bones}
    deform = whole.verts.layers.deform.verify()
    weigh = weights()
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
    body.parent = armature
    body.modifiers.new("Armature", "ARMATURE").object = armature
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
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (view, direction to the camera in Blender space, what it looks at, how much it frames, colours)
    views = [("side", (1, 0, 0), (0.0, -0.1, 0.6), 2.0, "MATERIAL"), ("quarter", (0.7, -0.7, 0.2), (0.0, -0.1, 0.6), 2.0, "MATERIAL"),
             ("front", (0.05, -1, 0.1), (0.0, -0.6, 0.6), 1.4, "MATERIAL"), ("face", (0.6, -0.75, 0.15), (0.0, -0.9, 0.8), 0.6, "VERTEX"),
             ("face_other", (-0.6, -0.75, 0.15), (0.0, -0.9, 0.8), 0.6, "VERTEX"), ("other_side", (-1, 0, 0), (0.0, -0.1, 0.6), 2.0, "VERTEX")]
    for view, direction, target, frame, colours in views:
        scene.display.shading.color_type = colours
        offset = Vector(direction).normalized() * 5.0
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

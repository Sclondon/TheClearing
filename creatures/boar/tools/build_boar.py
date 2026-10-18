"""Builds the giant boar (creatures/boar) and exports it for Godot.

Run from the game's root (it needs the character controller's tools/build_character.py):
    blender --background --python creatures/boar/tools/build_boar.py
    blender --background --python creatures/boar/tools/build_boar.py -- <preview folder>   # with pictures and a .blend

Writes creatures/boar/models/boar.glb and a demade boar_lo.glb. Nothing else
is written (an editable .blend goes to the preview folder, when there is one;
this folder has a .gdignore so that Godot does not try to import anything here).

It is a wild boar of the old stories, after the boar gods of Princess
Mononoke: the shape of a real one, made huge (the model stands a metre at the
shoulder, as a big boar does; the game draws it nearly three times that). A
great wedge of a beast, all its weight forward: the back falls away from a
hump of muscle over the shoulders to a narrow rump; short, thick-boned legs on
cloven hooves with the dewclaws behind them; a short, deep neck lost in the
shoulders and the jowls; a long wedge of a head running down to a flat, wet
disc of a nose. Small eyes set deep under a heavy brow, high on the head and
far back. Small, stiff, hairy ears. Two pairs of tusks: the lower, long and
curving up and back out of the mouth, the upper flaring up against them;
chipped and scored, the right lower one broken off short. A thin tail with a
tassel.

Its coat is coarse black-brown bristle, grizzled at the tips, with a crest of
long, stiff hair from between its ears down over the hump (material `crest`)
that the shader stands up when its hackles rise. Mud is caked on its legs and
belly and snout (the coat's vertex colours, green). It is old and has been
hunted: scars across its face and flanks (UV2, as the dogs'), and the broken
shafts of arrows still in its shoulder and side.

The bones are the dogs' (creatures/dog), with hooves for paws, so the same
kind of rig drives it (creatures/boar/boar_rig.gd). Each leg is three bones
and a hoof:

    fore: `upper` (shoulder to elbow), `lower` (forearm), `hock` (cannon and pastern), `hoof`
    hind: `upper` (thigh, hip to stifle), `lower` (shank), `hock` (hock to hoof), `hoof`

Its lower jaw is the bone `jaw`; strings of slobber hang from the corners of
its mouth on bones of their own (`drool_l`, `drool_r`), which the rig swings.

The coat's vertex colours: red is how open the surface is (dark in creases,
round the eyes, under the jowls), green how caked with mud, blue how far it is
the paler grizzled hair (the snout, the cheeks, the underside).

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

BODY = V(0.0, 0.66, 0.0)
CHEST = V(0.0, 0.70, 0.22)
PELVIS = V(0.0, 0.66, -0.38)
NECK = V(0.0, 0.74, 0.40)
HEAD = V(0.0, 0.76, 0.62)
NECK_1 = NECK.lerp(HEAD, 0.5)
# (the hinge of the lower jaw, under the back of the cheek)
JAW = HEAD + V(0.0, -0.125, 0.07)

# (along the body, centre height, half width, half height): a deep chest under
# the hump, the back falling away behind it to a narrow, low rump
TRUNK = [(-0.64, 0.652, 0.060, 0.070), (-0.60, 0.650, 0.128, 0.150), (-0.52, 0.645, 0.176, 0.196),
         (-0.40, 0.640, 0.204, 0.218), (-0.26, 0.648, 0.222, 0.234), (-0.10, 0.665, 0.236, 0.258),
         (0.04, 0.688, 0.250, 0.288), (0.18, 0.700, 0.262, 0.305), (0.30, 0.690, 0.258, 0.305),
         (0.40, 0.676, 0.238, 0.282), (0.48, 0.674, 0.196, 0.232), (0.54, 0.682, 0.138, 0.164)]

# Shoulder, elbow, knee (carpus), hoof; hip, stifle, hock, hoof (the left legs: the right are their mirror)
FORE = [V(0.160, 0.640, 0.300), V(0.162, 0.430, 0.255), V(0.155, 0.215, 0.300), V(0.152, 0.052, 0.330)]
HIND = [V(0.135, 0.660, -0.430), V(0.150, 0.440, -0.315), V(0.140, 0.262, -0.505), V(0.138, 0.052, -0.470)]
# (how far down the leg, counted in joints; half width; half depth; forward offset)
FORE_SHAPE = [(-0.3, 0.084, 0.140, 0.0), (0.0, 0.090, 0.140, 0.0), (0.5, 0.080, 0.116, 0.0), (0.95, 0.066, 0.084, -0.006),
              (1.2, 0.057, 0.070, 0.0), (1.6, 0.048, 0.057, 0.0), (1.95, 0.050, 0.058, 0.004), (2.15, 0.043, 0.049, 0.0),
              (2.6, 0.037, 0.042, 0.0), (3.0, 0.040, 0.044, 0.004)]
HIND_SHAPE = [(-0.25, 0.092, 0.170, 0.0), (0.0, 0.104, 0.184, 0.0), (0.45, 0.098, 0.162, 0.0), (0.85, 0.074, 0.110, 0.006),
              (1.0, 0.064, 0.090, 0.006), (1.4, 0.052, 0.070, -0.006), (1.85, 0.042, 0.056, 0.0), (2.0, 0.045, 0.060, -0.006),
              (2.3, 0.037, 0.044, 0.0), (2.7, 0.036, 0.040, 0.0), (3.0, 0.040, 0.044, 0.004)]

# The head, from HEAD. The snout is a long wedge: its top runs straight from
# the crown, forward and down, to the disc of its nose; it is deep at the
# cheeks and narrows to the disc.
SNOUT_TOP = V(0.0, 0.140, 0.120)
SNOUT_WAY = V(0.0, -0.53, 0.848).normalized()
SNOUT_UP = V(0.0, SNOUT_WAY.z, -SNOUT_WAY.y)
# (along the top of the snout, half width, half height)
SNOUT = [(0.0, 0.128, 0.160), (0.08, 0.118, 0.146), (0.16, 0.104, 0.126), (0.24, 0.090, 0.106),
         (0.32, 0.077, 0.088), (0.39, 0.068, 0.074), (0.44, 0.064, 0.066)]
DISC = (0.445, 0.066, 0.063, 0.026)  # where along the snout it is, half width, half height, depth
JAW_WAY = V(0.0, -0.29, 0.957).normalized()
JAW_UP = V(0.0, JAW_WAY.z, -JAW_WAY.y)
# (along the jaw from JAW, half width, half height, how far its middle is below the line from the hinge)
JAW_SHAPE = [(-0.03, 0.100, 0.082, 0.0), (0.08, 0.090, 0.066, 0.004), (0.16, 0.076, 0.052, 0.008),
             (0.23, 0.062, 0.040, 0.008), (0.29, 0.052, 0.032, 0.006), (0.32, 0.046, 0.027, 0.004)]
EYE = (V(0.100, 0.058, 0.195), 0.0165)
# Each ear: where it roots, the joint part way along it, and its end (small, stiff, upright, a little out)
EAR = [V(0.085, 0.122, 0.000), V(0.132, 0.180, -0.022), V(0.172, 0.226, -0.046)]
TAIL_ROOT = V(0.0, 0.795, -0.625)
TAIL = [V(0.0, 0.795, -0.625), V(0.0, 0.742, -0.672), V(0.0, 0.650, -0.690), V(0.0, 0.552, -0.688), V(0.0, 0.468, -0.678)]
TAIL_SHAPE = [0.030, 0.022, 0.016, 0.013, 0.011, 0.008]
DROOL = (V(0.072, -0.190, 0.270), 0.14)


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


# The hump of muscle over its shoulders, which the back line rises to.
HUMP = (V(0.0, 0.905, 0.17), V(0.175, 0.135, 0.28))


def top_at(z):
    """How high its back is at `z` (the trunk or the hump over it)."""
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


def snout_ring(t):
    """The snout's (half width, half height) `t` along it."""
    rings = SNOUT
    if t <= rings[0][0]:
        return rings[0][1:]
    for a, b in zip(rings, rings[1:]):
        if t <= b[0]:
            u = (t - a[0]) / (b[0] - a[0])
            return tuple(a[k] + (b[k] - a[k]) * u for k in (1, 2))
    return rings[-1][1:]


def snout_at(t):
    """The middle of the snout `t` along its top, in the model: it hangs from the line of its top."""
    return HEAD + SNOUT_TOP + SNOUT_WAY * t - SNOUT_UP * snout_ring(t)[1]


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
    suffix = ("_f" if p.z > -0.08 else "_r") + ("l" if p.x >= 0.0 else "r")
    joints = LEGS[suffix]
    top = joints[0]
    off = chain_param(V(top.x, p.y, p.z), joints)[0]
    return suffix, blend(top.y - 0.04, top.y - 0.20, p.y) * blend(0.17, 0.10, math.hypot(p.x - top.x, off / 1.6))


def leg_axis(joints, y):
    for a, b in zip(joints, joints[1:]):
        if y >= b.y:
            return a.z + (b.z - a.z) * min(max((a.y - y) / (a.y - b.y), 0.0), 1.0)
    return joints[-1].z


def lay_fur(bm, ears=False):
    """The texture coordinates the coat shader reads: (along the lie of the
    hair, across it), in metres. The hair lies back from the nose to the tail,
    and down each leg and ear (as the dogs')."""
    uv = bm.loops.layers.uv.verify()

    def around(x, y, near_x, near_y, radius):
        near = math.atan2(near_x, near_y)
        return (near + (math.atan2(x, y) - near + math.pi) % math.tau - math.pi) * radius

    def axis(z):
        return BODY.y + 0.02 + (HEAD.y - BODY.y) * blend(NECK.z - 0.02, HEAD.z, z)

    for face in bm.faces:
        near = kit.from_blender(face.calc_center_median())
        suffix, _ = leg_share(near)
        joints = LEGS[suffix]
        hip = joints[0]
        out = 1.0 if hip.x > 0.0 else -1.0
        for loop in face.loops:
            p = kit.from_blender(loop.vert.co)
            if ears:
                root = EAR[0]
                loop[uv].uv = ((p - (HEAD + V(root.x * (1.0 if p.x >= 0.0 else -1.0), root.y, root.z))).length - 2.0, p.z)
                continue
            leg = leg_share(p)[1]
            trunk = (-p.z, around(p.x, p.y - axis(p.z), near.x, near.y - axis(near.z), 0.22))
            limb_uv = (hip.y - p.y - hip.z, around(p.z - leg_axis(joints, p.y), (p.x - hip.x) * out,
                                                  near.z - leg_axis(joints, near.y), (near.x - hip.x) * out, 0.06))
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
    b.tube(dome(rings[0], -directions[0], 0.06)[::-1] + rings, segments)


def coat():
    def shapes(b):
        low = kit.LOW
        rings = [kit.lengthwise(*ring) for ring in TRUNK]
        b.tube(dome(rings[0], -Z, 0.06)[::-1] + rings + dome(rings[-1], Z, 0.06), 20)
        # The hump over the shoulders, and the ridge of the spine falling away behind it
        c, r = HUMP
        b.ellipsoid(c, r, None, 16, 9)
        b.ellipsoid(V(0.0, top_at(-0.22) - 0.07, -0.22), V(0.13, 0.08, 0.36), Matrix.Rotation(-0.12, 3, "X"))
        # The point of the chest (brisket), low between the forelegs
        b.ellipsoid(V(0.0, 0.47, 0.40), V(0.150, 0.110, 0.130))
        for side in (1.0, -1.0):
            # The great muscles over each shoulder and forearm, and each haunch
            arm = FORE[0].lerp(FORE[1], 0.25)
            b.ellipsoid(V(side * (arm.x + 0.012), arm.y + 0.06, arm.z - 0.01), V(0.075, 0.215, 0.155), Matrix.Rotation(0.30, 3, "X"))
            b.ellipsoid(V(side * 0.135, 0.80, 0.24), V(0.090, 0.140, 0.180), Matrix.Rotation(-0.25, 3, "X"))
            thigh = HIND[0].lerp(HIND[1], 0.3)
            b.ellipsoid(V(side * (thigh.x + 0.01), thigh.y + 0.03, thigh.z - 0.03), V(0.092, 0.205, 0.170), Matrix.Rotation(-0.40, 3, "X"))
        for suffix, joints in LEGS.items():
            limb(b, joints, FORE_SHAPE if suffix[1] == "f" else HIND_SHAPE, 14)

        # The neck: short and deep, lost in the shoulders, with the jowls under it
        base, top = NECK, HEAD + V(0.0, -0.03, 0.0)
        along = (top - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(top, t) - across * sag, X * r, across * (r * 1.22)) for t, r, sag in
                ((-0.4, 0.23, 0.0), (0.0, 0.225, 0.02), (0.4, 0.21, 0.04), (0.8, 0.19, 0.04), (1.1, 0.165, 0.02))], 18)
        b.ellipsoid(HEAD + V(0.0, -0.16, -0.10), V(0.170, 0.140, 0.200))

        # The head: a deep skull, a heavy brow over each eye and big cheeks under it,
        # and the long wedge of the snout
        h = HEAD
        b.ellipsoid(h + V(0.0, 0.030, 0.040), V(0.140, 0.148, 0.170), None, 16, 9)
        b.ellipsoid(h + V(0.0, 0.105, 0.110), V(0.094, 0.056, 0.120))  # the brow, between the eyes
        for side in (1.0, -1.0):
            b.ellipsoid(h + V(side * 0.078, 0.090, 0.160), V(0.050, 0.026, 0.085), Matrix.Rotation(0.30, 3, "X"))  # the ridge over the eye
            b.ellipsoid(h + V(side * 0.094, -0.070, 0.120), V(0.064, 0.105, 0.145), Matrix.Rotation(0.35, 3, "X"))  # cheek
            b.ellipsoid(h + V(side * 0.088, -0.130, -0.010), V(0.082, 0.100, 0.125))  # jowl
            if not low:
                # The lip pushed up and out over each upper tusk
                b.ellipsoid(h + V(side * 0.064, -0.150, 0.345), V(0.030, 0.030, 0.052), Matrix.Rotation(0.4, 3, "X"))
        # The snout: each ring hangs from the straight line of its top.
        rings = [(snout_at(t), X * rx, SNOUT_UP * ry) for t, rx, ry in SNOUT]
        b.tube([(h + V(0.0, 0.0, 0.0), X * 0.13, Y * 0.15)] + rings, 16)
        return furred(b, (0.0062, 4, 32000))
    return shapes


def jaw():
    def shapes(b):
        rings = [(JAW + JAW_WAY * t - JAW_UP * drop, X * rx, JAW_UP * ry) for t, rx, ry, drop in JAW_SHAPE]
        b.tube(dome(rings[0], -JAW_WAY, 0.03, 2)[::-1] + rings + dome(rings[-1], JAW_WAY, 0.026, 3), 12)
        # (the chin)
        b.ellipsoid(JAW + JAW_WAY * 0.27 - JAW_UP * 0.03, V(0.044, 0.026, 0.046))
        return furred(b, (0.005, 2, 1800))
    return shapes


def disc():
    """The flat, wet disc of its nose, at the end of the snout."""
    def shapes(b):
        t, rx, ry, depth = DISC
        centre = snout_at(t)
        up = SNOUT_UP
        rings = [(centre + SNOUT_WAY * (depth * k), X * (rx * s), up * (ry * s)) for k, s in ((-1.0, 0.96), (-0.3, 1.0), (0.4, 1.0), (0.85, 0.94))]
        b.tube(rings + dome(rings[-1], SNOUT_WAY, depth * 0.35, 2), 16)
    return shapes


def nostrils():
    def shapes(b):
        t, rx, ry, depth = DISC
        face = snout_at(t) + SNOUT_WAY * depth * 1.05
        up = SNOUT_UP
        for side in (1.0, -1.0):
            b.ellipsoid(face + X * side * rx * 0.36 + up * (ry * 0.08), V(rx * 0.17, ry * 0.30, 0.012), None, 8, 5)
    return shapes


def mouth():
    """The dark inside of its mouth, seen when the jaw drops."""
    def shapes(b):
        b.ellipsoid(JAW + JAW_WAY * 0.15 + V(0.0, 0.04, 0.0), V(0.060, 0.030, 0.17), Matrix.Rotation(-0.42, 3, "X"), 10, 5)
    return shapes


def tongue():
    def shapes(b):
        b.ellipsoid(JAW + JAW_WAY * 0.16 + V(0.0, 0.025, 0.0), V(0.045, 0.016, 0.14), Matrix.Rotation(-0.42, 3, "X"), 10, 5)
    return shapes


def sweep(b, points, radii, segments=10, blunt=False):
    """A horn-like sweep along a line of points, tapering (a tusk); with `blunt`, its end broken off flat."""
    rings = []
    for i, point in enumerate(points):
        ahead = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        ahead.normalize()
        u = ahead.cross(Z if abs(ahead.z) < 0.9 else X).normalized()
        # (a tusk is a little flattened, triangular in section in life: an oval here)
        rings.append((point, u * radii[i] * 1.15, ahead.cross(u) * radii[i] * 0.85))
    first = (points[0] - points[1]).normalized()
    last = (points[-1] - points[-2]).normalized()
    end = [] if blunt else dome(rings[-1], last, radii[-1] * 1.5, 2)
    b.tube(dome(rings[0], first, radii[0], 1)[::-1] + rings + end, segments)


def curve(points, count):
    """`count` points along a smooth curve through `points` (Catmull-Rom)."""
    made = []
    spans = len(points) - 1
    for k in range(count):
        s = k / (count - 1) * spans
        i = min(int(s), spans - 1)
        t = s - i
        p0 = points[max(i - 1, 0)]
        p1, p2 = points[i], points[i + 1]
        p3 = points[min(i + 2, spans)]
        t2, t3 = t * t, t * t * t
        made.append(((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3) * 0.5)
    return made


# The tusks, from HEAD: the lower pair rise out of the jaw and sweep up and back
# outside the snout; the upper pair flare up against them. (left side; the right is mirrored)
LOWER_TUSK = [V(0.040, -0.200, 0.330), V(0.075, -0.190, 0.350), V(0.110, -0.150, 0.356), V(0.138, -0.095, 0.345),
              V(0.152, -0.040, 0.318), V(0.156, 0.005, 0.285), V(0.150, 0.035, 0.255)]
LOWER_RADII = (0.021, 0.023, 0.021, 0.018, 0.014, 0.009, 0.003)
UPPER_TUSK = [V(0.048, -0.150, 0.350), V(0.082, -0.150, 0.365), V(0.112, -0.130, 0.368), V(0.134, -0.100, 0.352),
              V(0.145, -0.070, 0.330)]
UPPER_RADII = (0.016, 0.016, 0.013, 0.009, 0.004)
# (how much of the right lower tusk is left: it broke off in something long ago)
BROKEN = 0.58


def tusk_points(points, radii, side, keep=1.0, count=14):
    fine = curve([HEAD + V(p.x * side, p.y, p.z) for p in points], count)
    rad = curve([V(r, 0.0, 0.0) for r in radii], count)
    n = max(int(round(count * keep)), 3)
    return fine[:n], [r.x for r in rad[:n]]


def lower_tusks():
    def shapes(b):
        for side in (1.0, -1.0):
            keep = BROKEN if side < 0.0 else 1.0
            points, radii = tusk_points(LOWER_TUSK, LOWER_RADII, side, keep)
            sweep(b, points, radii, 12, blunt=keep < 1.0)
            if keep < 1.0:
                # (the break: a jagged, splintered end)
                end = points[-1]
                ahead = (points[-1] - points[-2]).normalized()
                for k, (dx, dy) in enumerate(((0.008, 0.004), (-0.006, 0.007), (0.002, -0.008))):
                    kit.spike(b, end - ahead * 0.006 + V(dx * side, dy, 0.0), end + ahead * (0.012 + 0.006 * k) + V(dx * side, dy, 0.0) * 1.2, 0.0065, 5)
    return shapes


def upper_tusks():
    def shapes(b):
        for side in (1.0, -1.0):
            points, radii = tusk_points(UPPER_TUSK, UPPER_RADII, side, 1.0, 10)
            sweep(b, points, radii, 10)
    return shapes


def teeth():
    def shapes(b):
        # A few blunt cheek teeth and front teeth, seen only with the mouth open
        for side in (1.0, -1.0):
            for k in range(4):
                at = JAW + JAW_WAY * (0.05 + 0.06 * k) + V(side * (0.040 - 0.004 * k), 0.035, 0.0)
                b.ellipsoid(at, V(0.010, 0.012, 0.014), None, 6, 3)
        for k in (-1.0, 0.0, 1.0):
            at = JAW + JAW_WAY * 0.33 + V(k * 0.012, 0.020, 0.0)
            kit.spike(b, at, at + V(0.0, 0.010, 0.020), 0.006, 5)
    return shapes


def eyes():
    def shapes(b):
        at, radius = EYE
        for side in (1.0, -1.0):
            b.ellipsoid(HEAD + V(side * at.x, at.y, at.z), V(radius * 0.8, radius * 0.66, radius), Matrix.Rotation(-side * 0.55, 3, "Y"), 8, 5)
    return shapes


def ear_curve(t, side):
    root, mid, end = EAR
    bend = mid * 2.0 - (root + end) * 0.5
    at = root.lerp(bend, t).lerp(bend.lerp(end, t), t)
    return HEAD + V(at.x * side, at.y, at.z)


EAR_RINGS = ((0.0, 0.046, 0.022), (0.15, 0.056, 0.016), (0.40, 0.050, 0.012), (0.65, 0.034, 0.010),
             (0.85, 0.016, 0.008), (0.96, 0.007, 0.006), (1.0, 0.003, 0.004))


def ears():
    def shapes(b):
        for side in (1.0, -1.0):
            wide = V(side * 0.90, 0.0, -0.42).normalized()
            face = V(side * 0.42, 0.0, 0.90).normalized()
            rings = []
            for t, half, thick in EAR_RINGS:
                if side < 0.0 and t > 0.5 and t < 0.75:
                    # (a notch torn out of its right ear)
                    half *= 0.55
                rings.append((ear_curve(t, side), wide * half, face * thick))
            b.tube(dome(rings[0], -Y, 0.012, 2)[::-1] + rings, 10)
            # A tuft of stiff hair off the tip
            tip = ear_curve(1.0, side)
            for k in range(3 if not kit.LOW else 1):
                kit.spike(b, ear_curve(0.82, side) + wide * (k - 1) * 0.006, tip + V(side * 0.010 * (k - 1), 0.030, -0.020), 0.006, 5)
        lay_fur(b.bm, True)
    return shapes


def ear_linings():
    def shapes(b):
        for side in (1.0, -1.0):
            wide = V(side * 0.90, 0.0, -0.42).normalized()
            face = V(side * 0.42, 0.0, 0.90).normalized()
            rings = [(ear_curve(t, side) + face * 0.008, wide * half, face * 0.005) for t, half in ((0.12, 0.020), (0.35, 0.030), (0.60, 0.022), (0.82, 0.010))]
            b.tube(rings, 8)
    return shapes


def crest():
    """The crest: long, coarse, stiff hair from between its ears down over the
    hump and along its back, lying back. The shader stands it up (each tuft's
    texture coordinate runs from 0 at its root to 1 at its tip)."""
    def shapes(b):
        low = kit.LOW
        rows = (-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0) if not low else (-1.0, 0.0, 1.0)
        # Over the head and down the back of the neck to the hump
        steps = 46 if not low else 14
        start, end = 0.66, -0.36
        for i in range(steps):
            z = start + (end - start) * i / (steps - 1)
            if z > NECK.z + 0.06:
                # (over the skull and the back of the neck: the top of the head there)
                y = HEAD.y + 0.16 - (z - HEAD.z) * 0.45 if z > HEAD.z - 0.08 else top_at(z) - 0.01
                y = max(y, top_at(z) - 0.01)
                width = 0.020
            else:
                y = top_at(z) - 0.012
                width = 0.024
            # (longest over the withers, short on the head, shorter again along the back)
            reach = 0.05 + 0.14 * blend(0.62, 0.30, z) * blend(-0.36, 0.05, z)
            for k in rows:
                jitter = math.sin(i * 7.31 + k * 3.7)
                fall = abs(k) / 3.0
                root = V(k * width + jitter * 0.004, y - fall * fall * 0.040, z + jitter * 0.006)
                length = reach * (1.0 - fall * 0.35) * (1.0 + jitter * 0.18)
                lie = V(k * 0.10 + jitter * 0.08, 0.32 - fall * 0.2, -1.0).normalized()
                kit.spike(b, root, root + lie * length, 0.010 * (1.0 - fall * 0.3), 5)
    return shapes


def tail_tassel():
    def shapes(b):
        end = TAIL[-1]
        for k in range(7 if not kit.LOW else 3):
            a = k * 2.4
            root = TAIL[-2].lerp(end, 0.4) + V(math.cos(a) * 0.006, 0.0, math.sin(a) * 0.006)
            kit.spike(b, root, end + V(math.cos(a) * 0.022, -0.075 - 0.01 * (k % 3), math.sin(a) * 0.018), 0.007, 5)
    return shapes


def hooves():
    """Cloven hooves: two toes each, dark horn, with the dewclaws behind them."""
    def shapes(b):
        for suffix, joints in LEGS.items():
            hoof = joints[3]
            for toe in (1.0, -1.0):
                at = hoof + V(toe * 0.019, -0.026, 0.026)
                b.ellipsoid(at, V(0.018, 0.026, 0.042), Matrix.Rotation(0.35, 3, "X"), 10, 5)
                b.ellipsoid(hoof + V(toe * 0.030, 0.030, -0.030), V(0.010, 0.017, 0.014), Matrix.Rotation(-0.5, 3, "X"), 8, 4)
    return shapes


def arrows():
    """Broken arrow shafts still in it from old hunts, the fletching rotted to tatters."""
    def shapes(b):
        for z, rise, side, length, lean in ((0.24, 0.35, 1.0, 0.20, 0.5), (0.12, 0.10, 1.0, 0.12, -0.3), (-0.18, 0.40, -1.0, 0.26, 0.2)):
            root = on_flank(side, z, rise, -0.03)
            out = V(side * 0.85, 0.45 + lean * 0.2, -0.35 + lean * 0.3).normalized()
            tip = root + out * length
            b.strand([root, root.lerp(tip, 0.5), tip], [0.0065, 0.0060, 0.0055], 6)
            if length > 0.15 and not kit.LOW:
                for k in range(3):
                    a = k * math.tau / 3.0
                    across = out.cross(Y).normalized()
                    fin = Matrix.Rotation(a, 3, out) @ across
                    kit.spike(b, tip - out * 0.05, tip - out * 0.005 + fin * 0.020, 0.006, 4)
    return shapes


def drool():
    def shapes(b):
        at, length = DROOL
        for side in (1.0, -1.0):
            top = HEAD + V(at.x * side, at.y, at.z)
            b.strand([top, top + V(side * 0.004, -length * 0.5, 0.004), top + V(side * 0.002, -length, 0.0)], [0.0045, 0.0030, 0.0055], 6)
    return shapes


def scar_lines():
    """Old wounds, healed bare: lines on the coat, each a list of points on it
    (painted into the second texture coordinates, as the dogs')."""
    h = HEAD
    lines = [
        # Down across its face from the brow over the left eye to the snout
        [h + V(0.090, 0.115, 0.150), h + V(0.105, 0.040, 0.230), h + V(0.090, -0.040, 0.320), h + V(0.075, -0.090, 0.390)],
        # Across the bridge of the snout
        [h + V(-0.070, 0.000, 0.300), h + V(0.000, 0.035, 0.300), h + V(0.060, 0.005, 0.315)],
        # Three gashes down its right shoulder, from another boar's tusks
        [on_flank(-1.0, 0.30, 0.70), on_flank(-1.0, 0.26, 0.20), on_flank(-1.0, 0.22, -0.30)],
        [on_flank(-1.0, 0.20, 0.75), on_flank(-1.0, 0.16, 0.25), on_flank(-1.0, 0.12, -0.25)],
        # One long one along its left flank
        [on_flank(1.0, 0.06, 0.20), on_flank(1.0, -0.10, 0.05), on_flank(1.0, -0.26, 0.15), on_flank(1.0, -0.40, 0.35)],
        # Puckered round each arrow
        [on_flank(1.0, 0.27, 0.40), on_flank(1.0, 0.21, 0.30)],
        [on_flank(-1.0, -0.15, 0.45), on_flank(-1.0, -0.21, 0.35)],
    ]
    made = []
    for points in lines:
        fine = []
        for a, c in zip(points, points[1:]):
            for k in range(6):
                fine.append(onto_coat(a.lerp(c, k / 6.0)))
        fine.append(onto_coat(points[-1]))
        made.append(fine)
    return made


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
    tail_names = ["pelvis", "tail", "tail_1", "tail_2", "tail_3"]

    def weigh(part, p):
        if part in ("jaw", "tongue", "teeth", "lower_tusks"):
            return {"jaw": 1.0}
        if part in ("upper_tusks", "eyes", "disc", "nostrils", "mouth"):
            return {"head": 1.0}
        if part == "drool":
            side = "_l" if p.x >= 0.0 else "_r"
            at, length = DROOL
            top = HEAD.y + at.y
            hung = blend(top - 0.01, top - length * 0.8, p.y)
            return {"jaw": 1.0 - hung, "drool" + side: hung}
        if part in ("ears", "linings"):
            suffix = "_l" if p.x >= 0.0 else "_r"
            side = 1.0 if p.x >= 0.0 else -1.0
            root, mid, end = (HEAD + V(j.x * side, j.y, j.z) for j in EAR)
            along = (p - root).dot((end - root).normalized())
            joint = (mid - root).dot((end - root).normalized())
            hung = blend(0.0, 0.04, along)
            tip = blend(joint - 0.03, joint + 0.03, along)
            return {"head": 1.0 - hung, "ear" + suffix: hung * (1.0 - tip), "ear_tip" + suffix: hung * tip}
        off, along = chain_param(p, TAIL)
        if part == "tail" or (part == "coat" and p.z < TAIL[0].z + 0.01 and off < 0.06 and p.y < TAIL[0].y + 0.04):
            past = [1.0, blend(0.0, 0.6, along)] + [blend(k - 0.3, k + 0.3, along) for k in (1, 2, 3)] + [0.0]
            return {name: past[i] - past[i + 1] for i, name in enumerate(tail_names)}
        if part == "tassel":
            return {"tail_3": 1.0}
        front = blend(-0.25, 0.12, p.z)
        trunk = {"chest": front, "pelvis": 1.0 - front}
        base, top = NECK, HEAD
        reach = (p - base).dot((top - base).normalized()) / (top - base).length
        if reach > -0.2 and p.z > base.z - 0.08 and p.y > 0.45:
            neck = blend(-0.1, 0.4, reach)
            upper = blend(0.35, 0.75, reach)
            head = blend(0.70, 1.05, reach)
            return {"chest": 1.0 - neck, "neck": neck * (1.0 - upper), "neck_1": neck * upper * (1.0 - head), "head": neck * upper * head}
        suffix, leg = leg_share(p)
        joints = LEGS[suffix]
        along = chain_param(V(joints[0].x, p.y, p.z), joints)[1]
        spans = [(b - a).length for a, b in zip(joints, joints[1:])]
        low = blend(1.0 - 0.06 / spans[0], 1.0 + 0.06 / spans[1], along)
        hock = blend(2.0 - 0.045 / spans[1], 2.0 + 0.045 / spans[2], along)
        hoof = blend(joints[3].y + 0.06, joints[3].y + 0.015, p.y)
        if part == "hooves":
            return {"hoof" + suffix: 1.0}
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
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        root, mid, end = (HEAD + V(j.x * side, j.y, j.z) for j in EAR)
        listed.append(("ear" + suffix, root, "head"))
        listed.append(("ear_tip" + suffix, mid, "ear" + suffix))
        listed.append(("ear_end" + suffix, end, "ear_tip" + suffix))
        at, length = DROOL
        top = HEAD + V(at.x * side, at.y, at.z)
        listed.append(("drool" + suffix, top + V(0.0, -0.01, 0.0), "jaw"))
        listed.append(("drool_end" + suffix, top + V(0.0, -length, 0.0), "drool" + suffix))
    chain = ["pelvis", "tail", "tail_1", "tail_2", "tail_3", "tail_end"]
    for i, joint in enumerate(TAIL):
        listed.append((chain[i + 1], joint, chain[i]))
    for suffix, joints in LEGS.items():
        for bone, joint in zip(("upper", "lower", "hock", "hoof"), joints):
            listed.append((bone + suffix, joint, "body"))
    return listed


## Three materials, so that it is few draws: the coat (with its fur), the crest,
## and everything else (`parts`), whose colours are in its vertex colours:
## (sRGB colour, and in alpha how wet it is: 1 shines like an eye).
MATERIALS = [("coat", (0.115, 0.095, 0.080)), ("crest", (0.085, 0.072, 0.062)), ("parts", (1.0, 1.0, 1.0))]
PART_COLOURS = {
    "mouth": (0.22, 0.07, 0.07, 0.5), "tongue": (0.40, 0.17, 0.18, 0.6), "teeth": (0.62, 0.56, 0.42, 0.3),
    "lower_tusks": (0.58, 0.53, 0.42, 0.35), "upper_tusks": (0.58, 0.53, 0.42, 0.35),
    "eyes": (0.55, 0.20, 0.06, 1.0), "linings": (0.20, 0.14, 0.13, 0.0),
    "disc": (0.20, 0.15, 0.14, 0.85), "nostrils": (0.03, 0.02, 0.02, 0.6),
    "hooves": (0.085, 0.075, 0.065, 0.15), "arrows": (0.26, 0.20, 0.13, 0.0), "drool": (0.52, 0.52, 0.48, 0.95),
    "tassel": (0.07, 0.06, 0.05, 0.0),
}


def parts():
    # (name, material index, shapes): the coat and the jaw fuse themselves
    return [
        ("coat", 0, coat()), ("jaw", 0, jaw()), ("ears", 0, ears()),
        ("crest", 1, crest()),
        ("disc", 2, disc()), ("nostrils", 2, nostrils()), ("mouth", 2, mouth()), ("tongue", 2, tongue()),
        ("teeth", 2, teeth()), ("lower_tusks", 2, lower_tusks()), ("upper_tusks", 2, upper_tusks()),
        ("eyes", 2, eyes()), ("linings", 2, ear_linings()), ("hooves", 2, hooves()), ("arrows", 2, arrows()),
        ("drool", 2, drool()), ("tassel", 2, tail_tassel()),
    ]


def tail_shapes():
    def shapes(b):
        b.strand([TAIL_ROOT + V(0.0, -0.01, 0.06)] + TAIL, TAIL_SHAPE, 10)
    return shapes


# --- Shading baked into the coat ---

def paint(whole, part_of):
    """Vertex colours. On the coat: red, how open the surface is (low in
    grooves and creases); green, how caked with mud; blue, how far it is the
    paler grizzled hair. On the other parts, their colours (see PART_COLOURS);
    on a tusk, darker scored lines and a stained root."""
    layer = whole.verts.layers.float_color.new("Color")
    whole.verts.ensure_lookup_table()
    whole.verts.index_update()
    whole.normal_update()
    furred = [part in ("coat", "jaw", "ears", "tail") for part in part_of]
    scars = scar_lines()
    crest_first = part_of.index("crest")
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

    def noise3(p, scale):
        return 0.5 + 0.25 * (math.sin(p.x * scale * 1.7 + p.z * scale * 0.9) + math.sin(p.y * scale * 2.3 - p.z * scale * 1.3 + 1.7))

    for vert in whole.verts:
        p = kit.from_blender(vert.co)
        part = part_of[vert.index]
        if part == "crest":
            spike = (vert.index - crest_first) // (18 if kit.LOW else 22)
            vert[layer] = (1.0, 1.0, 1.0, (math.sin(spike * 12.9898) * 43758.5453) % 1.0)
            continue
        if part in PART_COLOURS:
            r, g, bl, wet = PART_COLOURS[part]
            if part in ("lower_tusks", "upper_tusks"):
                q = p - HEAD
                # (stained dark at the root, yellower along it, scored across, pale at the tip)
                root = blend(-0.15, -0.22, q.y) if part == "lower_tusks" else blend(-0.13, -0.17, q.y)
                score = 0.75 + 0.25 * math.sin(q.y * 260.0 + q.z * 90.0) ** 8
                grime = 1.0 - 0.55 * root
                tone = grime * (1.0 - 0.3 * (1.0 - score))
                r, g, bl = r * tone, g * tone * 0.97, bl * tone * 0.9
            elif part == "hooves":
                # (mud on the horn)
                mud = blend(0.02, 0.06, p.y)
                r, g, bl = r + 0.08 * (1 - mud), g + 0.06 * (1 - mud), bl + 0.04 * (1 - mud)
            vert[layer] = (r, g, bl, wet)
            if part == "eyes":
                side = 1.0 if p.x >= 0.0 else -1.0
                at, radius = EYE
                centre = HEAD + V(side * at.x, at.y, at.z)
                local = Matrix.Rotation(side * 0.9, 3, "Y").inverted() @ (p - centre)
                if local.z > 0.0:
                    across_uv[vert.index] = (0.5 + local.x / (radius * 0.8) * 0.4, 0.5 + local.y / (radius * 0.66) * 0.4)
                else:
                    across_uv[vert.index] = (0.95, 0.95)
            continue
        shade = 1.0
        pale = 0.0
        mud = 0.0
        if furred[vert.index]:
            near = 1e9
            for line in scars:
                for a, c in zip(line, line[1:]):
                    ac = c - a
                    t = min(max((p - a).dot(ac) / max(ac.length_squared, 1e-9), 0.0), 1.0)
                    gap = (a + ac * t - p).length
                    if gap < near:
                        near = gap
                        way = ac.normalized()
                        off = (p - a) - way * (p - a).dot(way)
                        side = way.cross(kit.from_blender(vert.normal)).dot(off)
                        across = off.length if side >= 0.0 else -off.length
                        # (a boar's scars are wider than a dog's: two centimetres a tenth)
                        across_uv[vert.index] = (0.5 + max(min(across * 5.0, 0.45), -0.45), 0.5 + min(gap * 5.0, 0.45))
            shade = min(max(1.0 - (open_[vert.index] - middle) * 4.5, 0.0), 1.0)
            y, rx, ry = trunk_at(p.z)
            q = p - HEAD
            # Grizzled: the snout and cheeks, round the eyes and the underside of the jowls
            on_head = q.z > -0.05 and p.y > 0.4
            snout = blend(0.14, 0.32, q.z) * 0.6 if on_head else 0.0
            cheek = blend(0.10, 0.04, abs(abs(q.x) - 0.10)) * blend(-0.18, -0.05, q.y) * blend(0.0, 0.08, q.z) * 0.8 if on_head else 0.0
            belly = blend(y - ry * 0.3, y - ry * 0.9, p.y) * 0.45
            pale = max(snout, cheek, belly)
            # Mud: caked thick up its legs and under its belly, splashed up its flanks
            # and chest, on the end of its snout from rooting; it dries paler at the top edge.
            splash = noise3(p, 18.0) * 0.5 + noise3(p, 47.0) * 0.5
            legs = blend(0.42 + 0.08 * splash, 0.22, p.y)
            under = blend(y - ry * 0.45, y - ry * 0.95, p.y) * (0.55 + 0.45 * splash)
            nose = blend(0.30, 0.46, q.z) * 0.85 if on_head else 0.0
            mud = min(max(legs, under, nose) * (0.75 + 0.35 * splash), 1.0)
        vert[layer] = (shade, mud, pale, 1.0)
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
    name = "boar" + ("_lo" if low else "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = kit.make_armature(bones())
    whole = bmesh.new()
    whole.loops.layers.uv.verify()
    part_of = []
    listed = parts()
    # (the tail is its own furred tube, on the coat's material)
    listed.insert(3, ("tail", 0, tail_shapes()))
    for part, material, shapes in listed:
        builder = kit.Builder()
        ready = shapes(builder)
        if ready is None and part == "tail":
            ready = furred(builder, None)
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
    views = [("side", (1, 0, 0), (0.0, -0.25, 0.55), 2.3, "MATERIAL"), ("quarter", (0.7, -0.7, 0.2), (0.0, -0.25, 0.55), 2.3, "MATERIAL"),
             ("front", (0.05, -1, 0.1), (0.0, -0.6, 0.6), 1.3, "MATERIAL"), ("face", (0.6, -0.75, 0.15), (0.0, -0.95, 0.65), 0.75, "MATERIAL"),
             ("face_other", (-0.6, -0.75, 0.15), (0.0, -0.95, 0.65), 0.75, "MATERIAL"), ("top", (0.2, 0.1, 1), (0.0, 0.0, 0.55), 2.1, "MATERIAL"),
             ("shade", (0.8, -0.5, 0.2), (0.0, -0.25, 0.55), 2.3, "VERTEX")]
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

"""Builds the giant octopus (creatures/octopus) and exports it for Godot.

Run from the game's root:
    blender --background --python creatures/octopus/tools/build_octopus.py
    blender --background --python creatures/octopus/tools/build_octopus.py -- <preview folder>   # with pictures and a .blend

Writes creatures/octopus/models/octopus.glb: one skeleton and two meshes on it, `octopus` (the full model, near) and
`octopus_lo` (the demade one, for far off and for phones). Nothing else is written here (the pictures and an editable
.blend go to the preview folder, when there is one; this folder has a .gdignore so that Godot leaves it alone).

A giant octopus, after the common and the giant Pacific octopus, at its full size in metres: the mantle (the sac
of the body, behind and above the eyes) about 2.5 m long, the arms 8.4 m from the mouth.

- THE BODY (bones `body`, `head`, `mantle`): one lofted surface along a curved spine, from the arm crown round
  the mouth (on the underside, the beak dark in it), up through the head with its two eyes on raised turrets, a
  slight waist at the mantle's collar, and the mantle sac swelling back and up behind and tapering to a round end.
  Lumpy skin and a few folds. The siphon (`siphon`), a fleshy funnel, comes out of the collar on its right under
  the eye.
- THE EYES: on turrets at the sides of the head, looking out and a little up; on each eyeball the first UV says
  where on the eye a point is, for the shader's iris and its horizontal slit pupil.
- THE ARMS: eight, two by two (`arm_k_j`: k 0 to 7 round from the front right, j 0 to 19 from the crown), each a
  tapering tube flattened a little on its oral side, with two rows of suckers along that side (one row near the
  crown), smaller towards the tip, and none on the last tenth. At rest they lie straight out on the ground like
  the spokes of a wheel, the suckers down, so that the game can lay each along any curve (every bone is set in code:
  creatures/octopus/octopus_rig.gd).
- THE WEB: skin between each two arms, out to about a fifth of their length at the arms and less between them
  (a scalloped edge), weighted between the two arms' bones so that it stretches when they spread and folds when
  they curl. Two-sided.

One material (`skin`). What a point is comes from its UVs and colour, for the shader (creatures/octopus/octopus_look.gd):
UV.x is the part (0 skin, 1 sucker, 2 eye, 3 the dark of the mouth and siphon, 4 web), UV.y its height at rest, UV2
its x and z at rest (so the shader's mottling and papillae stay put on it as it moves); on an eye UV2 is where on
the eye it is (across and up) and UV.y how far it faces out. Vertex colour: red how open it is to the sky (baked:
dark in the creases), green how far on the oral side (pale underneath; on a sucker, its rim), blue how far along an
arm (0 at the crown, 1 the tip).

Everything here is in Godot space (metres, Y up, facing +Z, +X its left) until it is written out.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
COMPONENT = os.path.dirname(HERE)
OUT = os.path.join(COMPONENT, "models")
PREVIEW = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

LOW = False  # True while building the demade model

UP = Vector((0.0, 1.0, 0.0))

# The rest pose (the game reads it back from the skeleton).
ARMS = 8
ARM_BONES = 20
ARM_LENGTH = 8.4
CROWN_R = 0.42
CROWN_Y = 0.34
ARM_BASE_R = 0.3
ARM_TIP_R = 0.022
WEB_AT_ARM = 1.55
WEB_BETWEEN = 0.85
BODY_BONE = Vector((0.0, CROWN_Y, 0.0))
HEAD_BONE = Vector((0.0, 0.92, 0.12))
MANTLE_BONE = Vector((0.0, 1.1, -0.08))
SIPHON_BASE = Vector((-0.5, 0.74, -0.12))
SIPHON_END = Vector((-0.86, 0.6, 0.22))
EYES = [(Vector((0.7, 1.06, 0.26)), Vector((0.86, 0.36, 0.38))), (Vector((-0.7, 1.06, 0.26)), Vector((-0.86, 0.36, 0.38)))]
EYE_R = 0.21

SEG = ARM_LENGTH / ARM_BONES


def V(x, y, z):
    return Vector((x, y, z))


def to_b(p):
    return Vector((p.x, -p.z, p.y))


def res(full, low):
    return low if LOW else full


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def perpendicular(d):
    other = UP if abs(d.dot(UP)) < 0.9 else Vector((1.0, 0.0, 0.0))
    return d.cross(other).normalized()


def lumps(p, scale=1.0):
    """A cheap smooth noise in rest space (sum of sines), about -1..1."""
    x, y, z = p.x * scale, p.y * scale, p.z * scale
    return (math.sin(x * 3.1 + y * 1.7) * math.sin(z * 2.9 - x * 1.3) + 0.6 * math.sin(y * 5.3 + z * 4.1 + 1.0) * math.sin(x * 4.7 - 0.6)) / 1.6


class Build:
    """Vertices (each with its bone weights, a colour, a part and an eye UV) and faces."""

    def __init__(self):
        self.verts = []
        self.weights = []
        self.cols = []
        self.parts = []
        self.eye_uv = []
        self.faces = []

    def vert(self, p, bone, col, part=0, eye=None):
        self.verts.append(Vector(p))
        self.weights.append(bone if isinstance(bone, dict) else {bone: 1.0})
        self.cols.append(col)
        self.parts.append(part)
        self.eye_uv.append(eye)
        return len(self.verts) - 1

    def face(self, idx):
        self.faces.append(list(idx))

    def normal(self, f):
        n = Vector()
        for k in range(len(f)):
            a = self.verts[f[k]]
            b = self.verts[f[(k + 1) % len(f)]]
            n += Vector((a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x))
        return n

    def orient(self, first, outward):
        votes = 0
        for f in self.faces[first:]:
            c = sum((self.verts[i] for i in f), Vector()) / len(f)
            votes += 1 if self.normal(f).dot(outward(c)) >= 0.0 else -1
        if votes < 0:
            for k in range(first, len(self.faces)):
                self.faces[k].reverse()

    def grid(self, rows, bone, col, part=0, wrap=True, outward=None, cap_end=None, cap_start=None):
        """A surface through `rows` of points (each row as long), wrapping round each row if `wrap`.
        `bone`, `col` may be functions of (row, column, point)."""
        first = len(self.faces)
        count = len(rows[0])
        index = []
        for r, row in enumerate(rows):
            line = []
            for c, p in enumerate(row):
                line.append(self.vert(p, bone(r, c, p) if callable(bone) else bone, col(r, c, p) if callable(col) else col, part))
            index.append(line)
        span = count if wrap else count - 1
        for r in range(len(rows) - 1):
            for c in range(span):
                c1 = (c + 1) % count
                self.face([index[r][c], index[r][c1], index[r + 1][c1], index[r + 1][c]])
        for cap, r in ((cap_end, len(rows) - 1), (cap_start, 0)):
            if cap is None:
                continue
            centre = self.vert(cap, bone(r, 0, cap) if callable(bone) else bone, col(r, 0, cap) if callable(col) else col, part)
            for c in range(span):
                self.face([index[r][c], index[r][(c + 1) % count], centre])
        if outward is not None:
            self.orient(first, outward)
        return index


# --- The rest pose ---

def arm_angle(k):
    """Arm k's angle round from straight ahead (+Z), towards +X: the front pair either side of the middle."""
    return math.radians(22.5 + 45.0 * k)


def arm_dir(k):
    a = arm_angle(k)
    return Vector((math.sin(a), 0.0, math.cos(a)))


def arm_point(k, j):
    """Arm k's bone j's rest point (j = ARM_BONES is the tip)."""
    return BODY_BONE + arm_dir(k) * (CROWN_R + SEG * j)


def arm_radius(t):
    return lerp(ARM_BASE_R, ARM_TIP_R, t ** 0.75) * (1.0 + 0.12 * math.exp(-(t / 0.06) ** 2))


def arm_weights(k, p):
    """Weights at a distance `p` along arm k, in bones from its crown: blended linearly between the middles of
    neighbouring bones (and into the body at the crown), so that it bends smoothly anywhere."""
    s = p - 0.5
    if s < 0.0:
        f = max(s + 0.5, 0.0) / 0.5
        return {"body": 1.0 - f, "arm_%d_0" % k: f} if f < 1.0 else {"arm_%d_0" % k: 1.0}
    j = int(math.floor(s))
    f = s - j
    if j >= ARM_BONES - 1:
        return {"arm_%d_%d" % (k, ARM_BONES - 1): 1.0}
    return {"arm_%d_%d" % (k, j): 1.0 - f, "arm_%d_%d" % (k, j + 1): f}


def mix_weights(a, b, f):
    out = {}
    for name, w in a.items():
        out[name] = out.get(name, 0.0) + w * (1.0 - f)
    for name, w in b.items():
        out[name] = out.get(name, 0.0) + w * f
    return {n: w for n, w in out.items() if w > 0.001}


# --- The body ---

SPINE = [  # (point, radius across, radius up-and-down / front-back)
    (V(0.0, 0.22, 0.08), 0.32, 0.3),
    (V(0.0, 0.34, 0.1), 0.62, 0.58),
    (V(0.0, 0.6, 0.16), 0.74, 0.64),
    (V(0.0, 0.92, 0.14), 0.7, 0.6),
    (V(0.0, 1.12, -0.02), 0.64, 0.56),
    (V(0.0, 1.32, -0.36), 0.86, 0.76),
    (V(0.0, 1.5, -0.86), 0.98, 0.86),
    (V(0.0, 1.62, -1.4), 0.9, 0.8),
    (V(0.0, 1.66, -1.85), 0.64, 0.58),
    (V(0.0, 1.62, -2.18), 0.32, 0.3),
    (V(0.0, 1.58, -2.32), 0.06, 0.06),
]


def catmull(points, t):
    n = len(points) - 1
    x = min(max(t, 0.0), 1.0) * n
    i = min(int(x), n - 1)
    f = x - i
    p0 = points[max(i - 1, 0)]
    p1 = points[i]
    p2 = points[i + 1]
    p3 = points[min(i + 2, n)]
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)


def catmull_f(values, t):
    n = len(values) - 1
    x = min(max(t, 0.0), 1.0) * n
    i = min(int(x), n - 1)
    f = x - i
    p0 = values[max(i - 1, 0)]
    p1 = values[i]
    p2 = values[i + 1]
    p3 = values[min(i + 2, n)]
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)


def body_weights(t):
    """The crown (`body`), the head, the mantle, along the spine (0 the mouth, 1 the mantle's end)."""
    head = smooth(0.12, 0.24, t)
    mantle = smooth(0.34, 0.46, t)
    w = {"body": 1.0 - head, "head": head * (1.0 - mantle), "mantle": mantle}
    return {n: v for n, v in w.items() if v > 0.001}


def body(b):
    pts = [p for p, rx, ry in SPINE]
    rxs = [rx for p, rx, ry in SPINE]
    rys = [ry for p, rx, ry in SPINE]
    rings = res(46, 16)
    sides = res(40, 14)
    rows = []
    centres = []
    params = []
    for i in range(rings + 1):
        t = i / rings
        c = catmull(pts, t)
        d = (catmull(pts, min(t + 0.01, 1.0)) - catmull(pts, max(t - 0.01, 0.0))).normalized()
        side = V(1.0, 0.0, 0.0)
        up = d.cross(side).normalized()
        rx = catmull_f(rxs, t)
        ry = catmull_f(rys, t)
        row = []
        for j in range(sides):
            a = math.tau * j / sides
            p = c + side * math.cos(a) * rx + up * math.sin(a) * ry
            if not LOW:
                # lumpy skin, and on the mantle a few long folds and wrinkles
                bump = 0.035 * lumps(p, 2.3) + 0.018 * lumps(p, 6.1)
                if t > 0.4:
                    bump += 0.025 * math.sin(a * 5.0 + t * 9.0) * smooth(0.4, 0.55, t) * (1.0 - smooth(0.85, 1.0, t))
                # the waist at the collar, where the mantle opens
                bump -= 0.05 * math.exp(-((t - 0.36) / 0.035) ** 2)
                p = p + (p - c).normalized() * bump * max(rx, 0.2)
            row.append(p)
        rows.append(row)
        centres.append(c)
        params.append(t)

    def weigh(r, c, p):
        return body_weights(params[r])

    def colour(r, c, p):
        under = smooth(0.25, -0.15, (p - centres[r]).normalized().y) * (1.0 - smooth(0.05, 0.25, params[r]))
        return (1.0, under, 0.0)
    b.grid(rows, weigh, colour, 0, True, lambda q: q - nearest(centres, q), cap_end=pts[-1], cap_start=V(0.0, 0.2, 0.08))
    # The beak, dark in the mouth on the underside.
    mouth = V(0.0, 0.2, 0.08)
    beak = []
    for j in range(8):
        a = math.tau * j / 8
        beak.append(mouth + V(math.cos(a) * 0.14, -0.005, math.sin(a) * 0.14))
    centre = b.vert(mouth + V(0.0, -0.09, 0.0), "body", (0.2, 1.0, 0.0), 3)
    ring = [b.vert(p, "body", (0.4, 1.0, 0.0), 3) for p in beak]
    for j in range(8):
        b.face([ring[(j + 1) % 8], ring[j], centre])


def nearest(centres, q):
    return min(centres, key=lambda c: (c - q).length_squared)


def eye(b, at, look):
    """An eye on a turret at the side of the head: the raised skin round it, and the eyeball (its UV2 where on it)."""
    look = look.normalized()
    right = UP.cross(look).normalized()
    up = look.cross(right).normalized()
    centre = at - look * 0.07
    # The turret: a mound of skin swelling out of the head, its lids closing on the eyeball (a slit of an
    # opening, wider across than up and down), the upper lid a little heavier, a ridge of skin over it.
    rows = []
    sides = res(24, 12)
    for k, (forward, r, lid) in enumerate([(-0.3, 0.42, 0.0), (-0.16, 0.37, 0.0), (-0.05, 0.3, 0.02), (0.02, 0.245, 0.035)]):
        row = []
        for j in range(sides):
            a = math.tau * j / sides
            ca, sa = math.cos(a), math.sin(a)
            # (narrower up and down at the lids, and the upper lid hangs a little lower)
            rr = r * (1.0 if k < 3 else lerp(1.0, 0.82, abs(sa)))
            drop = -lid * max(sa, 0.0)
            row.append(centre + look * (forward + 0.07) + right * ca * rr + up * (sa * rr + drop))
        rows.append(row)
    # the lids' edge, tucked onto the eyeball's surface
    edge = []
    for j in range(sides):
        a = math.tau * j / sides
        ca, sa = math.cos(a), math.sin(a)
        d = (look * 0.62 + (right * ca + up * sa * 0.7) * 0.78).normalized()
        edge.append(centre + d * EYE_R * 1.02)
    rows.append(edge)
    b.grid(rows, "head", lambda r, c, p: (0.9 if r < len(rows) - 1 else 0.55, 0.0, 0.0), 0, True, lambda q: q - (centre - look * 0.3))
    # The eyeball.
    n_lat = res(10, 5)
    n_lon = res(18, 9)
    first = len(b.faces)
    index = []
    for i in range(n_lat + 1):
        lat = -math.pi * 0.5 + math.pi * i / n_lat
        line = []
        for j in range(n_lon):
            lon = math.tau * j / n_lon
            d = look * math.cos(lat) * math.cos(lon) + right * math.cos(lat) * math.sin(lon) + up * math.sin(lat)
            p = centre + d * EYE_R
            q = p - centre
            line.append(b.vert(p, "head", (1.0, 0.0, 0.0), 2, (q.dot(right) / EYE_R, q.dot(up) / EYE_R, q.dot(look) / EYE_R)))
        index.append(line)
    for i in range(n_lat):
        for j in range(n_lon):
            j1 = (j + 1) % n_lon
            b.face([index[i][j], index[i][j1], index[i + 1][j1], index[i + 1][j]])
    b.orient(first, lambda q: q - centre)


def siphon(b):
    """The siphon: a fleshy funnel out of the collar on its right, under the eye, open at its end."""
    d = (SIPHON_END - SIPHON_BASE).normalized()
    n = perpendicular(d)
    bn = d.cross(n).normalized()
    stations = [(0.0, 0.2), (0.3, 0.15), (0.65, 0.12), (0.9, 0.12), (1.0, 0.13)]
    sides = res(14, 7)
    rows = []
    length = (SIPHON_END - SIPHON_BASE).length
    for s, r in stations:
        c = SIPHON_BASE + d * length * s
        rows.append([c + (n * math.cos(math.tau * j / sides) + bn * math.sin(math.tau * j / sides)) * r for j in range(sides)])
    b.grid(rows, lambda r, c, p: {"siphon": 0.3 + 0.7 * stations[r][0], "head": 0.7 - 0.7 * stations[r][0]}, (0.8, 0.3, 0.0), 0, True,
           lambda q: q - (SIPHON_BASE + d * (q - SIPHON_BASE).dot(d)))
    # its open end, dark inside
    inner = [SIPHON_END - d * 0.02 + (n * math.cos(math.tau * j / sides) + bn * math.sin(math.tau * j / sides)) * 0.08 for j in range(sides)]
    rim = rows[-1]
    first = len(b.faces)
    a_idx = [b.vert(p, "siphon", (0.5, 0.3, 0.0), 0) for p in rim]
    i_idx = [b.vert(p, "siphon", (0.2, 0.0, 0.0), 3) for p in inner]
    bottom = b.vert(SIPHON_END - d * 0.15, "siphon", (0.0, 0.0, 0.0), 3)
    for j in range(sides):
        j1 = (j + 1) % sides
        b.face([a_idx[j], a_idx[j1], i_idx[j1], i_idx[j]])
        b.face([i_idx[j], i_idx[j1], bottom])
    b.orient(first, lambda q: d)


# --- The arms ---

def arm_frame(k):
    t = arm_dir(k)
    down = V(0.0, -1.0, 0.0)
    side = t.cross(down).normalized()
    return t, down, side


def arm_section(k, along, r, a, sucker_side=True):
    """A point on arm k's surface `along` metres out, at angle `a` round it (0 the oral side, straight down)."""
    t, down, side = arm_frame(k)
    c = arm_point(k, 0) + t * along
    ca = math.cos(a)
    sa = math.sin(a)
    # flatter on its oral side, rounder above
    up_down = ca * r * (0.72 if ca > 0.0 else 0.92)
    return c + down * up_down + side * sa * r * 1.05


def arm(b, k, rng):
    rings = res(ARM_BONES * 5, ARM_BONES * 2)
    sides = res(14, 6)
    rows = []
    params = []
    for i in range(rings + 1):
        f = i / rings
        along = ARM_LENGTH * f
        r = arm_radius(f)
        row = []
        for j in range(sides):
            a = math.tau * j / sides
            p = arm_section(k, along, r, a)
            if not LOW and f < 0.92:
                p = p + (p - (arm_point(k, 0) + arm_dir(k) * along)).normalized() * r * 0.06 * lumps(p, 5.0)
            row.append(p)
        rows.append(row)
        params.append(f)
    tip = arm_point(k, ARM_BONES) + arm_dir(k) * ARM_TIP_R

    def weigh(r, c, p):
        return arm_weights(k, params[min(r, len(params) - 1)] * ARM_BONES)

    def colour(r, c, p):
        a = math.tau * c / sides
        under = smooth(0.1, 0.75, math.cos(a))
        return (1.0, under, params[min(r, len(params) - 1)])
    t = arm_dir(k)
    b.grid(rows, weigh, colour, 0, True, lambda q: q - (arm_point(k, 0) + t * (q - arm_point(k, 0)).dot(t)), cap_end=tip)
    if not LOW:
        suckers(b, k, rng)


def suckers(b, k, rng):
    """Two rows of suckers along the oral side (one near the crown), smaller towards the tip, none on the last tenth."""
    t, down, side = arm_frame(k)
    along = 0.12
    row = 0
    sides = 6
    while along < ARM_LENGTH * 0.9:
        f = along / ARM_LENGTH
        r = arm_radius(f)
        rs = max(r * 0.34, 0.012)
        single = along < 0.55
        lateral = 0.0 if single else (0.42 if row % 2 == 0 else -0.42) * r
        base = arm_point(k, 0) + t * along + down * r * 0.66 + side * lateral
        normal = (down + side * (lateral / max(r, 0.01)) * 0.5).normalized()
        u = t
        w = normal.cross(u).normalized()
        h = rs * 0.55
        rings = [(0.0 - rs * 0.25, rs * 1.08, 0.0), (h, rs, 1.0), (h * 1.02, rs * 0.66, 1.0), (h * 0.45, rs * 0.42, 0.45)]
        weights = arm_weights(k, along / SEG)
        index = []
        first = len(b.faces)
        for height, radius, rim in rings:
            line = []
            for j in range(sides):
                a = math.tau * j / sides
                p = base + normal * height + (u * math.cos(a) + w * math.sin(a)) * radius
                line.append(b.vert(p, weights, (1.0, rim, f), 1))
            index.append(line)
        for i in range(len(rings) - 1):
            for j in range(sides):
                j1 = (j + 1) % sides
                b.face([index[i][j], index[i][j1], index[i + 1][j1], index[i + 1][j]])
        bottom = b.vert(base + normal * h * 0.35, weights, (0.6, 0.3, f), 1)
        for j in range(sides):
            b.face([index[-1][j], index[-1][(j + 1) % sides], bottom])
        b.orient(first, lambda q, base=base, normal=normal: normal * 0.3 + (q - base) * 0.0 + normal)
        step = rs * 2.3 if single else rs * 1.35
        along += max(step, 0.03)
        row += 1


def web(b, k):
    """The web between arm k and arm k+1: out along each arm to WEB_AT_ARM, less between them (a scalloped edge).
    Weighted between the two arms' bones. Two sheets, back to back, the oral one pale."""
    k2 = (k + 1) % ARMS
    cols = res(14, 6)
    rows_n = res(10, 4)
    for face_side in (1.0, -1.0):
        rows = []
        weights = []
        for i in range(rows_n + 1):
            v = i / rows_n
            row = []
            wrow = []
            for c in range(cols + 1):
                u = c / cols
                edge = lerp(WEB_AT_ARM, WEB_BETWEEN, math.sin(u * math.pi) ** 0.8)
                along = lerp(0.0, edge, v)
                r1 = arm_radius(along / ARM_LENGTH)
                p1 = arm_point(k, 0) + arm_dir(k) * along
                p2 = arm_point(k2, 0) + arm_dir(k2) * along
                # (from the arm's flank, not its middle)
                side1 = (p2 - p1).normalized() if (p2 - p1).length > 0.001 else perpendicular(arm_dir(k))
                a1 = p1 + side1 * r1 * 0.9
                a2 = p2 - side1 * r1 * 0.9
                p = a1.lerp(a2, u)
                # the web sags down a little between the arms, and thickens towards the crown
                p.y += -0.05 * math.sin(u * math.pi) * v - 0.02 + face_side * (0.035 + 0.05 * (1.0 - v))
                row.append(p)
                wrow.append(mix_weights(arm_weights(k, along / SEG), arm_weights(k2, along / SEG), u))
            rows.append(row)
            weights.append(wrow)
        index = b.grid(rows, lambda r, c, p: weights[r][c], lambda r, c, p: (0.85 - 0.25 * (1.0 - r / rows_n), 1.0 if face_side < 0 else 0.0, 0.05 * r / rows_n), 4, False)
        first = len(b.faces) - rows_n * cols
        b.orient(first, lambda q, s=face_side: V(0.0, s, 0.0))


def bones():
    out = [("body", BODY_BONE, None), ("head", HEAD_BONE, "body"), ("mantle", MANTLE_BONE, "head"), ("siphon", SIPHON_BASE, "head")]
    for k in range(ARMS):
        for j in range(ARM_BONES):
            out.append(("arm_%d_%d" % (k, j), arm_point(k, j), "body"))
    return out


def make_armature(listed):
    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for name, at, parent in listed:
        bone = data.edit_bones.new(name)
        bone.head = to_b(at)
        bone.tail = to_b(at + UP * 0.3)
        bone.roll = 0.0
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def build(rng):
    b = Build()
    body(b)
    for at, look in EYES:
        eye(b, at, look)
    siphon(b)
    for k in range(ARMS):
        arm(b, k, rng)
        web(b, k)
    return b


def make_mesh(b, name):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_b(p) for p in b.verts], [], b.faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    uv2 = mesh.uv_layers.new(name="UVMap2")
    for poly in mesh.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            p = b.verts[vi]
            part = b.parts[vi]
            if part == 2:
                e = b.eye_uv[vi]
                uv.data[li].uv = (2.0, e[2])
                uv2.data[li].uv = (e[0], e[1])
            else:
                uv.data[li].uv = (float(part), p.y)
                uv2.data[li].uv = (p.x, p.z)
    return mesh


def bake_colours(mesh, b):
    """Vertex colours: red how open each point is (rays out over its hemisphere), green and blue as made."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    count = res(12, 6)
    golden = math.pi * (3.0 - math.sqrt(5.0))
    dirs = []
    for k in range(count):
        z = 1.0 - (k + 0.5) / count
        r = math.sqrt(max(1.0 - z * z, 0.0))
        dirs.append(Vector((math.cos(golden * k) * r, math.sin(golden * k) * r, z)))
    reach = 0.9
    opens = []
    for v in bm.verts:
        n = v.normal
        if n.length < 0.5:
            opens.append(1.0)
            continue
        t = n.orthogonal().normalized()
        bt = n.cross(t)
        hits = 0.0
        for d in dirs:
            w = t * d.x + bt * d.y + n * d.z
            loc, nor, idx, dist = tree.ray_cast(v.co + n * 0.01, w, reach)
            if loc is not None:
                hits += 1.0 - dist / reach * 0.7
        opens.append(max(0.0, 1.0 - hits / count))
    bm.free()
    attribute = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    for i, (open_, under, along) in enumerate(b.cols):
        o = min(opens[i], open_) if b.parts[i] != 2 else 1.0
        attribute.data[i].color = (min(max(o, 0.0), 1.0), min(max(under, 0.0), 1.0), min(max(along, 0.0), 1.0), 1.0)
    mesh.color_attributes.active_color = attribute
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")


def export(preview):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = make_armature(bones())
    made = []
    global LOW
    for low in (False, True):
        LOW = low
        rng = random.Random(11)
        b = build(rng)
        name = "octopus_lo" if low else "octopus"
        mesh = make_mesh(b, name)
        bake_colours(mesh, b)
        body_obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(body_obj)
        material = bpy.data.materials.get("skin") or bpy.data.materials.new("skin")
        material.use_nodes = True
        bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (0.35, 0.3, 0.27, 1.0)
        material.diffuse_color = (0.35, 0.3, 0.27, 1.0)
        mesh.materials.append(material)
        groups = {bone.name: body_obj.vertex_groups.new(name=bone.name) for bone in armature.data.bones}
        for i, weights in enumerate(b.weights):
            total = sum(weights.values())
            for bone, w in weights.items():
                groups[bone].add([i], w / total, "REPLACE")
        body_obj.parent = armature
        body_obj.modifiers.new("Armature", "ARMATURE").object = armature
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), tris))
        made.append(body_obj)
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, "octopus.glb"), export_format="GLB", export_yup=True,
        export_animations=False, export_skins=True, export_vertex_color="ACTIVE", export_texcoords=True,
    )
    if preview:
        os.makedirs(preview, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(preview, "octopus.blend"))
        render(preview, made)


def render(folder, made):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    camera.data.clip_end = 1000.0
    scene.collection.objects.link(camera)
    scene.camera = camera
    views = [("top", (0.0, -0.01, 1.0), (0, 0, 0.5), 19.0), ("quarter", (0.7, -0.7, 0.4), (0, 0, 0.8), 7.0),
             ("side", (1, 0, 0.05), (0, 0, 1.0), 5.0), ("front", (0, -1, 0.15), (0, 0, 1.0), 4.0),
             ("under", (0.2, -0.3, -1.0), (0, 0, 0.3), 6.0), ("arm", (0.3, -0.6, -0.6), tuple(to_b(arm_point(0, 3))), 2.5),
             ("eye", (0.95, -0.3, 0.2), tuple(to_b(EYES[0][0])), 1.2)]
    for low in (False, True):
        for obj in made:
            obj.hide_render = (obj.name == "octopus") == low
        for view, direction, target, frame in views:
            if low and view not in ("quarter", "top"):
                continue
            for colours in (("MATERIAL", "VERTEX") if not low else ("MATERIAL",)):
                if colours == "VERTEX" and view not in ("quarter", "under"):
                    continue
                scene.display.shading.color_type = colours
                offset = Vector(direction).normalized() * 60.0
                camera.data.ortho_scale = frame
                camera.location = Vector(target) + offset
                camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
                scene.render.filepath = os.path.join(folder, "%s%s_%s.png" % ("lo_" if low else "", view, colours.lower()))
                bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    export(PREVIEW)

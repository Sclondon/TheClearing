"""Builds the tripod (creatures/tripod) and exports it for Godot.

Run from the game's root:
    blender --background --python creatures/tripod/tools/build_tripod.py
    blender --background --python creatures/tripod/tools/build_tripod.py -- <preview folder>   # with pictures and a .blend

Writes creatures/tripod/models/tripod.glb: one skeleton and two meshes on it, `tripod` (the full model) and
`tripod_lo` (the demade one, for far off and for phones). Nothing else is written (the pictures and an editable
.blend go to the preview folder, when there is one; this folder has a .gdignore so that Godot leaves it alone).

It is a Martian fighting-machine, after The War of the Worlds: Wells' "brazen hood" on three long whippy legs,
by way of the 2005 film's tripods. Made at its full size, in metres: the hood is about 22 m across and 28 m from
brow to tail, its top 63 m up, its hips 50 m up, its feet 24 m out from under it.

- THE HOOD (bone `head`): a great cowl of weathered bronze plate, low and broad, with a ridge down its spine.
  Its rim sweeps down at the front into a drooping brow, and in the dark under it, set back in a concave face
  plate, is its eye: one great lens (bone `eye`, which turns in its bezel) and two small ones beside it. Its
  underside is a ribbed dish of darker machinery. Slatted vents at the back.
- THE BODY (bone `body`): a drum under the hood that the hood turns on, with the three hip sockets under it and
  a bulb and a spike hanging below.
- THE LEGS: three, one behind and two before (at 60, 180 and 300 degrees round from straight ahead). Each is
  long and flexible, a whippy cable of segmented metal 73 m long: ribbed vertebrae with a heavy collar at each
  of its twelve joints (`leg_i_j`, j 0 to 11 from the hip), a cable along its underside, a shroud over the hip,
  and a foot (`foot_i`) of three claws. At rest each is laid along the arch the game's rig lays it on (from the
  hip up and out, then down to come in on the foot from straight above), bowed to its length.
- THE HEAT RAY: on a jointed arm under the right of the brow (`arm_upper`, `arm_fore`), a finned emitter like a
  camera with a horn (`emitter`), its lens deep in the horn.
- THE TENTACLES: four cables (`tent_k_j`, k 0 to 3, j 0 to 3 from the root) and a grasper (k 4) with three
  claws at its end, hanging from the dish. They hang straight down at rest, so that the game can stretch one
  along its length (a scale along the bone's Y).
- RED WEED (material `weed`): strands hanging from the rim and the legs' high arches, and lying over the hood.

Materials: `metal` (everything solid), `glow` (the lenses: vertex colour red the eye, green the emitter's lens)
and `weed`. The metal's vertex colours: red is its tone (0 dark steel, 1 bronze), green how open it is to the
sky (baked occlusion: dark in the creases and under the hood), blue edge wear (bright where it is worn). Its
first UVs are in metres along and round each part, for the shader's plate seams and rivets.

Every bone stands up (+Y) at rest, with no turn, so the rest pose of every bone is the identity turned; the game
poses them all in code (creatures/tripod/tripod_rig.gd). Everything here is in Godot space (metres, Y up,
facing +Z, +X its left) until it is written out.
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
HEAD_PIVOT = Vector((0.0, 56.0, 0.0))
BODY = Vector((0.0, 52.0, 0.0))
HIP_R = 5.0
HIP_Y = 50.5
LEG_ANGLES = (60.0, 180.0, 300.0)
FOOT_R = 24.0
LEG_LENGTH = 73.0
LEG_BONES = 12
FOOT_TOP = 1.6
SHOULDER = Vector((-5.0, 52.6, 6.0))
UPPER_ARM = 7.0
FOREARM = 6.0
EMITTER = 3.8
TENTACLES = [  # root (x, z) under the dish, segment length
    ((6.4, 0.6), 4.6), ((-6.6, -0.6), 4.6), ((3.2, -6.2), 4.4), ((-2.8, -6.8), 4.5), ((3.6, 5.2), 4.0),
]
GRASPER = 4

# Tones (vertex red): bronze plate, darker steel, the underside's machinery, cables.
BRONZE = 0.9
PLATE = 0.75
STEEL = 0.35
MACHINE = 0.18
CABLE = 0.08

MATERIALS = [("metal", (0.42, 0.36, 0.28)), ("glow", (0.95, 0.97, 1.0)), ("weed", (0.45, 0.07, 0.05))]


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


def flat(v):
    return Vector((v.x, 0.0, v.z))


def perpendicular(d):
    other = UP if abs(d.dot(UP)) < 0.9 else Vector((1.0, 0.0, 0.0))
    return d.cross(other).normalized()


class Build:
    """Vertices (each with its bone weights and a colour) and faces (each with its corners' UVs and a material)."""

    def __init__(self):
        self.verts = []
        self.weights = []
        self.cols = []
        self.faces = []
        self.uvs = []
        self.mats = []

    def vert(self, p, bone, col):
        self.verts.append(Vector(p))
        self.weights.append(bone if isinstance(bone, dict) else {bone: 1.0})
        self.cols.append(col)
        return len(self.verts) - 1

    def face(self, idx, uv, mat=0):
        self.faces.append(list(idx))
        self.uvs.append(list(uv))
        self.mats.append(mat)

    def orient(self, first, outward):
        """Turns every face from `first` on so that they face `outward(point)` (judged by the majority)."""
        votes = 0
        for f in self.faces[first:]:
            n = self.normal(f)
            c = sum((self.verts[i] for i in f), Vector()) / len(f)
            votes += 1 if n.dot(outward(c)) >= 0.0 else -1
        if votes < 0:
            for k in range(first, len(self.faces)):
                self.faces[k].reverse()
                self.uvs[k].reverse()

    def normal(self, f):
        n = Vector()
        for k in range(len(f)):
            a = self.verts[f[k]]
            b = self.verts[f[(k + 1) % len(f)]]
            n += Vector((a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x))
        return n

    def sheet(self, rows, bone, col, mat=0, wrap=True, outward=None, uv_scale=1.0, cap_end=None, cap_start=None):
        """A surface through `rows` of points (each row the same length), wrapping round each row if `wrap`.
        `bone` and `col` may be functions of (row, column, point). UVs are metres round the rows and along them.
        `cap_end` / `cap_start`: a point to close the last / first row to with a fan."""
        first = len(self.faces)
        count = len(rows[0])
        index = []
        for r, row in enumerate(rows):
            line = []
            for c, p in enumerate(row):
                b = bone(r, c, p) if callable(bone) else bone
                k = col(r, c, p) if callable(col) else col
                line.append(self.vert(p, b, k))
            index.append(line)
        # UVs: u round the row (metres, by the first row's spacing scaled to each row), v along the rows
        u_of = []
        for row in rows:
            u = [0.0]
            span = count if wrap else count - 1
            for c in range(span):
                u.append(u[-1] + (row[(c + 1) % count] - row[c]).length)
            u_of.append(u)
        v_of = [[0.0] * count]
        for r in range(1, len(rows)):
            v_of.append([v_of[-1][c] + (rows[r][c] - rows[r - 1][c]).length for c in range(count)])
        span = count if wrap else count - 1
        for r in range(len(rows) - 1):
            for c in range(span):
                c1 = (c + 1) % count
                quad = [index[r][c], index[r][c1], index[r + 1][c1], index[r + 1][c]]
                uv = [(u_of[r][c] * uv_scale, v_of[r][c] * uv_scale), (u_of[r][c + 1] * uv_scale, v_of[r][c1] * uv_scale),
                      (u_of[r + 1][c + 1] * uv_scale, v_of[r + 1][c1] * uv_scale), (u_of[r + 1][c] * uv_scale, v_of[r + 1][c] * uv_scale)]
                self.face(quad, uv, mat)
        for cap, r in ((cap_end, len(rows) - 1), (cap_start, 0)):
            if cap is None:
                continue
            b = bone(r, 0, cap) if callable(bone) else bone
            k = col(r, 0, cap) if callable(col) else col
            centre = self.vert(cap, b, k)
            for c in range(span):
                c1 = (c + 1) % count
                self.face([index[r][c], index[r][c1], centre], [(u_of[r][c], v_of[r][c]), (u_of[r][c + 1], v_of[r][c1]), (u_of[r][c], v_of[r][c] + 0.5)], mat)
        if outward is not None:
            self.orient(first, outward)
        return index


def frames_along(points, side=None):
    """Parallel-transport frames along a polyline: (tangent, normal, binormal) at each point."""
    tangents = []
    for i in range(len(points)):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, len(points) - 1)]
        tangents.append((b - a).normalized())
    n = side if side is not None else perpendicular(tangents[0])
    n = (n - tangents[0] * n.dot(tangents[0])).normalized()
    out = []
    for i, t in enumerate(tangents):
        if i > 0:
            n = (n - t * n.dot(t))
            n = n.normalized() if n.length > 1e-6 else perpendicular(t)
        out.append((t, n, t.cross(n).normalized()))
    return out


def tube(b, points, radii, sides, bone, col, mat=0, side=None, caps=(True, True), shape=None, twist=0.0):
    """A tube along `points` with a radius at each; `shape(angle)` scales the radius round it (a polygon)."""
    frames = frames_along(points, side)
    rows = []
    for i, p in enumerate(points):
        t, n, bn = frames[i]
        row = []
        for k in range(sides):
            a = math.tau * k / sides + twist
            r = radii[i] * (shape(a) if shape else 1.0)
            row.append(p + (n * math.cos(a) + bn * math.sin(a)) * r)
        rows.append(row)
    centre = list(points)
    end = points[-1] + frames[-1][0] * radii[-1] * 0.15 if caps[1] else None
    start = points[0] - frames[0][0] * radii[0] * 0.15 if caps[0] else None

    def outward(c):
        best = min(range(len(centre)), key=lambda i: (centre[i] - c).length_squared)
        d = c - centre[best]
        return d if d.length > 1e-4 else frames[best][0]
    return b.sheet(rows, bone, col, mat, True, outward, cap_end=end, cap_start=start)


def octagon(chamfer=0.86):
    """A polygon-ish section: flats with chamfered corners (for armour)."""
    def shape(a):
        k = (a % (math.tau / 8.0)) / (math.tau / 8.0)
        return lerp(1.0, chamfer, 1.0 - abs(k * 2.0 - 1.0))
    return shape


def ellipsoid(b, centre, radii, bone, col, mat=0, rings=10, segs=16, axes=None):
    """An ellipsoid (radii along `axes`, default the world's)."""
    ax = axes or (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    rows = []
    for r in range(1, rings):
        th = math.pi * r / rings
        row = []
        for s in range(segs):
            ph = math.tau * s / segs
            row.append(centre + ax[0] * (math.sin(th) * math.cos(ph) * radii.x) + ax[1] * (math.cos(th) * radii.y) + ax[2] * (math.sin(th) * math.sin(ph) * radii.z))
        rows.append(row)
    top = centre + ax[1] * radii.y
    bottom = centre - ax[1] * radii.y
    return b.sheet(rows, bone, col, mat, True, lambda c: c - centre, cap_start=top, cap_end=bottom)


def drum(b, centre, axis, radius, half, bone, col, sides=20, hub=0.0):
    """A short cylinder across `axis` (a joint drum), with a hub on each face."""
    pts = [centre - axis * half, centre - axis * (half - 0.15), centre + axis * (half - 0.15), centre + axis * half]
    radii = [radius * 0.9, radius, radius, radius * 0.9]
    tube(b, pts, radii, sides, bone, col)
    if hub > 0.0:
        for s in (-1.0, 1.0):
            p0 = centre + axis * s * half
            tube(b, [p0, p0 + axis * s * 0.35], [hub, hub * 0.8], max(8, sides // 2), bone, col)


# --- The rest pose ---

def leg_out(i):
    a = math.radians(LEG_ANGLES[i])
    return Vector((math.sin(a), 0.0, math.cos(a)))


def two_bone(root, target, upper, lower, pole):
    to = target - root
    length = to.length
    d = to / max(length, 1e-4)
    length = min(max(length, abs(upper - lower) + 0.01), upper + lower - 0.001)
    a = (upper * upper - lower * lower + length * length) / (2.0 * length)
    h = math.sqrt(max(upper * upper - a * a, 0.0))
    bend = pole - d * pole.dot(d)
    bend.normalize()
    return root + d * a + bend * h, root + d * length


def bezier(p0, p1, p2, p3, t):
    u = 1.0 - t
    return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


def leg_curve(hip, ankle, out, length, count):
    """The leg as a smooth arch from the hip (leaving up and out) down to the ankle (coming in from straight
    above), arched just enough that it is `length` long: `count` + 1 points evenly along it. (The game's rig
    makes the same curve, with sway and ripples on it.)"""
    def points_for(a, n=48):
        p1 = hip + (out * 0.55 + UP * 0.85).normalized() * a
        p2 = ankle + UP * (a * 1.1)
        return [bezier(hip, p1, p2, ankle, k / n) for k in range(n + 1)]

    def arc(points):
        return sum((points[k + 1] - points[k]).length for k in range(len(points) - 1))
    low, high = 0.1, 80.0
    for _ in range(30):
        mid = (low + high) * 0.5
        if arc(points_for(mid)) < length:
            low = mid
        else:
            high = mid
    dense = points_for((low + high) * 0.5, 200)
    run = [0.0]
    for k in range(len(dense) - 1):
        run.append(run[-1] + (dense[k + 1] - dense[k]).length)
    total = run[-1]
    out_points = []
    k = 0
    for j in range(count + 1):
        want = total * j / count
        while k < len(run) - 2 and run[k + 1] < want:
            k += 1
        f = (want - run[k]) / max(run[k + 1] - run[k], 1e-6)
        out_points.append(dense[k].lerp(dense[k + 1], min(max(f, 0.0), 1.0)))
    return out_points


def leg_rest(i):
    """[hip, the leg's points (LEG_BONES + 1, hip to ankle), ankle, foot]."""
    out = leg_out(i)
    hip = out * HIP_R + UP * HIP_Y
    foot = out * FOOT_R
    ankle = foot + UP * FOOT_TOP
    return hip, leg_curve(hip, ankle, out, LEG_LENGTH, LEG_BONES), ankle, foot


def arm_rest():
    elbow = SHOULDER + V(-0.25, -0.8, 0.55).normalized() * UPPER_ARM
    wrist = elbow + V(0.0, -0.25, 1.0).normalized() * FOREARM
    tip = wrist + V(0.0, -0.3, 1.0).normalized() * EMITTER
    return SHOULDER, elbow, wrist, tip


def eye_rest():
    return HEAD_PIVOT + V(0.0, -2.7, face_z(0.0, face_v(-2.7)) + 0.45)


# --- The hood ---

def plan_r(phi):
    s, c = math.sin(phi), math.cos(phi)
    length = 16.0 if c > 0.0 else 14.5
    n = lerp(2.6, 1.7, max(c, 0.0) ** 2)
    return (abs(s / 12.4) ** n + abs(c / length) ** n) ** (-1.0 / n)


def rim_y(phi):
    """How low the hood's rim comes (from its pivot): arched up over the face at the front, down at the cheeks."""
    c = math.cos(phi)
    return -4.0 + 3.3 * max(c, 0.0) ** 2.2 + 1.0 * max(-c, 0.0) ** 2


def hood_point(phi, t):
    s, c = math.sin(phi), math.cos(phi)
    k = max(math.cos(t * math.pi / 2.0), 0.0) ** 0.72
    r = plan_r(phi) * k
    base = rim_y(phi)
    top = 5.6
    y = base + (top - base) * math.sin(t * math.pi / 2.0) ** 1.25
    x = r * s
    z = r * c
    y += 0.8 * math.exp(-(x / 1.5) ** 2) * smooth(0.12, 0.7, t) * smooth(-15.0, -4.0, z)
    # (it rises to the back like a cowl: the crown is behind the middle, the brow low over the face)
    y += 1.6 * smooth(0.2, 0.9, t) * (smooth(14.0, -4.0, z) - 0.6)
    front = max(c, 0.0) ** 4
    # (the brow juts out over the face)
    z += 2.6 * front * math.sin(min(t * 1.6, 1.0) * math.pi)
    y -= 0.6 * front * smooth(0.0, 0.25, t) * (1.0 - smooth(0.25, 0.6, t))
    # (a step in the plate a third of the way up: the hood is two great courses of plate)
    y += 0.25 * smooth(0.32, 0.36, t)
    return Vector((x, y, z)) + HEAD_PIVOT


def hood_normal(phi, t):
    e = 1e-3
    a = hood_point(phi + e, t) - hood_point(phi - e, t)
    b = hood_point(phi, min(t + e, 1.0)) - hood_point(phi, max(t - e, 0.0))
    n = b.cross(a).normalized()
    p = hood_point(phi, t)
    if n.dot(p - (HEAD_PIVOT + V(0, -2, 0))) < 0.0:
        n = -n
    return n


def dish_edge(phi):
    c = math.cos(phi)
    return lerp(plan_r(phi) * 0.86, 7.4, smooth(0.25, 0.75, c))


def dish_point(phi, q):
    """The underside: q 0 at its edge, 1 at the middle."""
    r = dish_edge(phi) * (1.0 - q)
    y = -1.3 - 2.2 * (1.0 - (1.0 - q) ** 2)
    y -= 0.22 * max(math.cos(14.0 * phi), 0.0) ** 6 * 4.0 * q * (1.0 - q)
    return Vector((r * math.sin(phi), y, r * math.cos(phi))) + HEAD_PIVOT


def dish_y_at(x, z):
    phi = math.atan2(x, z)
    r = math.hypot(x, z)
    q = 1.0 - min(r / dish_edge(phi), 1.0)
    return dish_point(phi, q).y


def hood(b):
    around = res(112, 36)
    up = res(30, 9)
    ts = [(r / up) ** 1.15 for r in range(up)]  # rim to just short of the top
    rows_out = []
    rows_in = []
    for t in ts:
        row_o = []
        row_i = []
        for k in range(around):
            phi = math.tau * k / around
            p = hood_point(phi, t)
            row_o.append(p)
            row_i.append(p - hood_normal(phi, t) * 0.5)
        rows_out.append(row_o)
        rows_in.append(row_i)

    global HOOD_TREE
    flat_verts = [p for row in rows_out for p in row]
    polys = []
    for r in range(len(rows_out) - 1):
        for k in range(around):
            k1 = (k + 1) % around
            polys.append((r * around + k, r * around + k1, (r + 1) * around + k1, (r + 1) * around + k))
    HOOD_TREE = BVHTree.FromPolygons(flat_verts, polys)

    def tone(r, c, p):
        return (BRONZE if p.y > HEAD_PIVOT.y + 1.5 else PLATE, 1.0, 0.0)
    top = hood_point(0.0, 1.0)
    b.sheet(rows_out, "head", tone, 0, True, lambda c: c - (HEAD_PIVOT + V(0, -3, 0)), cap_end=top)
    b.sheet(rows_in, "head", (MACHINE, 0.4, 0.0), 0, True, lambda c: (HEAD_PIVOT + V(0, -3, 0)) - c, cap_end=top - UP * 0.5)
    # the rim: a rolled lip between the two
    lip = []
    for k in range(around):
        phi = math.tau * k / around
        p = hood_point(phi, 0.0)
        n = hood_normal(phi, 0.0)
        lip.append([p, p - UP * 0.3 + n * 0.12, p - UP * 0.35 - n * 0.3, rows_in[0][k]])
    rows = [[lip[k][j] for k in range(around)] for j in range(4)]
    b.sheet(rows, "head", (PLATE, 0.9, 1.0), 0, True, lambda c: c - (HEAD_PIVOT + V(0, -3, 0)) - UP * 4.0)


HOOD_TREE = None


def hood_surface(x, z):
    """Where the top of the hood is over (x, z), and which way it faces there, or None."""
    loc, nor, idx, dist = HOOD_TREE.ray_cast(Vector((x, HEAD_PIVOT.y + 30.0, z)), Vector((0.0, -1.0, 0.0)), 60.0)
    if loc is None:
        return None
    return loc, (nor if nor.y > 0.0 else -nor)


def hood_ribs(b):
    """Low ribs along the hood either side of its spine: its great plates' seams."""
    lines = [[(s * 4.8 + 0.4 * s * math.sin(z * 0.1), z) for z in [-16.0 + 0.7 * k for k in range(50)]] for s in (-1.0, 1.0)]
    for line in lines:
        pts = []
        for x, z in line:
            hit = hood_surface(x, z)
            if hit is None:
                continue
            p, n = hit
            pts.append(p + n * 0.02)
        # (a run of points on it, trimmed back from its edge)
        pts = pts[1:-1]
        if len(pts) > 3:
            if LOW:
                pts = pts[::3] + [pts[-1]]
            tube(b, pts, [0.2] * len(pts), res(6, 4), "head", (BRONZE, 1.0, 0.5), shape=octagon(0.75))


def dish(b):
    around = res(112, 36)
    rings = res(12, 4)
    rows = []
    for r in range(rings):
        q = r / rings
        rows.append([dish_point(math.tau * k / around, q) for k in range(around)])
    b.sheet(rows, "head", (MACHINE, 0.6, 0.0), 0, True, lambda c: -UP, cap_end=dish_point(0.0, 1.0))
    # (a skirt from the edge up into the hood, so that no gap shows)
    rows = [[dish_point(math.tau * k / around, 0.0) + UP * (j * 1.6) for k in range(around)] for j in range(2)]
    b.sheet(rows, "head", (MACHINE, 0.3, 0.0), 0, True, lambda c: flat(c - HEAD_PIVOT))


FACE_W = 8.6


def face_w(v):
    """How far out to the side the face plate goes, at `v` down it."""
    return lerp(6.4, FACE_W, smooth(0.0, 0.6, v))


def face_v(y):
    return (-0.5 - y) / 4.6


def face_z(x, v):
    """How far forward the face plate is (from the pivot) at `x` across it and `v` down it (0 top, 1 bottom)."""
    u = x / FACE_W
    return 7.0 + 3.2 * u * u + 0.8 * v - 0.3 * math.sin(v * math.pi)


def face(b):
    """The concave plate deep under the brow that the eye is set in, and a chin under it."""
    across = res(26, 8)
    down = res(10, 4)
    rows = []
    for j in range(down + 1):
        v = j / down
        y = -0.5 - 4.6 * v
        w = face_w(v)
        rows.append([HEAD_PIVOT + V(u * w, y, face_z(u * w, v)) for u in [i / across * 2.0 - 1.0 for i in range(across + 1)]])
    b.sheet(rows, "head", (STEEL, 0.5, 0.0), 0, False, lambda c: V(0, -0.3, 1))
    # (and up behind the brow, so that nothing shows over it)
    rows = [[p for p in rows[0]], [HEAD_PIVOT + (p - HEAD_PIVOT) * V(0.8, 1.0, 1.0) + V(0.0, 2.2, -2.2) for p in rows[0]]]
    b.sheet(rows, "head", (MACHINE, 0.2, 0.0), 0, False, lambda c: V(0, -0.3, 1))
    chin = []
    for j in range(res(6, 2) + 1):
        v = j / res(6, 2)
        row = []
        for i in range(across + 1):
            u = i / across * 2.0 - 1.0
            x = u * face_w(1.0) * (1.0 - 0.35 * v)
            row.append(HEAD_PIVOT + V(x, -5.1 + 1.0 * v, face_z(u * face_w(1.0), 1.0) - 4.5 * v))
        chin.append(row)
    b.sheet(chin, "head", (MACHINE, 0.5, 0.0), 0, False, lambda c: -UP)
    # Ribs down the face plate, either side of the eye
    if not LOW:
        for s in (-1.0, 1.0):
            for k in range(5):
                x = s * (2.9 + k * 0.85)
                pts = []
                for j in range(7):
                    v = 0.05 + j / 6.0 * 0.85
                    pts.append(HEAD_PIVOT + V(x, -0.5 - 4.6 * v, face_z(x, v) + 0.12))
                tube(b, pts, [0.15] * len(pts), 6, "head", (STEEL, 0.6, 0.8))


def eye(b):
    centre = eye_rest()
    axis = V(0.0, -0.45, 1.0).normalized()
    side = Vector((1.0, 0.0, 0.0))
    bn = axis.cross(side).normalized()
    # The bezel (on the hood): a thick ring round the socket
    segs = res(36, 14)
    ring = []
    for j, (rr, dz) in enumerate([(1.55, -0.6), (2.25, -0.35), (2.35, 0.05), (2.0, 0.3), (1.75, 0.15)]):
        ring.append([centre + axis * dz + (side * math.cos(math.tau * k / segs) + bn * math.sin(math.tau * k / segs)) * rr for k in range(segs)])
    b.sheet(ring, "head", (STEEL, 0.7, 0.9), 0, True, lambda c: (c - centre) + axis * 0.8)
    # The lens and its housing turn (bone `eye`): a dark iris ring and the glowing lens
    rows = []
    for j in range(res(9, 4)):
        th = (j + 1) / res(9, 4) * math.pi * 0.5
        rr = 1.5 * math.sin(th)
        dz = 0.15 + 0.75 * math.cos(th)
        rows.insert(0, [centre + axis * dz + (side * math.cos(math.tau * k / segs) + bn * math.sin(math.tau * k / segs)) * rr for k in range(segs)])
    b.sheet(rows, "eye", (1.0, 0.0, 0.0), 1, True, lambda c: c - centre + axis * 0.5, cap_start=centre + axis * 0.9)
    tube(b, [centre - axis * 0.9, centre + axis * 0.2], [1.62, 1.62], segs, "eye", (MACHINE, 0.2, 0.3), caps=(True, False))
    # Two small lenses beside it, dim
    for s in (-1.0, 1.0):
        c2 = HEAD_PIVOT + V(s * 3.7, -1.7, face_z(3.7, face_v(-1.7)) + 0.25)
        tube(b, [c2 - axis * 0.3, c2 + axis * 0.25], [0.7, 0.62], res(16, 8), "head", (STEEL, 0.6, 0.9), caps=(False, False))
        ellipsoid(b, c2 + axis * 0.15, V(0.5, 0.5, 0.5), "head", (0.35, 0.0, 0.0), 1, res(6, 3), res(12, 6))


def vents(b):
    """Slatted vents in the hood's back, either side of the spine."""
    if LOW:
        return
    for s in (-1.0, 1.0):
        for k in range(7):
            phi = math.pi + s * (0.35 + k * 0.075)
            pts = [hood_point(phi, t) + hood_normal(phi, t) * 0.18 for t in (0.36, 0.42, 0.48, 0.54, 0.6)]
            tube(b, pts, [0.16] * 5, 4, "head", (STEEL, 0.5, 1.0), shape=octagon(0.7))


def drum_body(b):
    sides = res(40, 14)
    profile = [(53.9, 4.6), (53.6, 5.2), (52.0, 5.4), (51.6, 5.7), (51.2, 5.4), (49.7, 5.0), (49.2, 4.2), (48.0, 3.0), (46.8, 1.6), (46.2, 0.9)]
    pts = [V(0.0, y, 0.0) for y, r in profile]
    tube(b, pts, [r for y, r in profile], sides, "body", (STEEL, 0.6, 0.0), side=Vector((1, 0, 0)))
    tube(b, [V(0, 46.3, 0), V(0, 44.5, 0), V(0, 42.6, 0)], [0.45, 0.3, 0.06], res(10, 5), "body", (STEEL, 1.0, 0.6), caps=(False, False))
    # Ribs round the drum
    if not LOW:
        for k in range(16):
            a = math.tau * k / 16
            o = Vector((math.sin(a), 0.0, math.cos(a)))
            tube(b, [o * 5.45 + UP * 53.3, o * 5.75 + UP * 52.0, o * 5.45 + UP * 50.0], [0.14, 0.16, 0.14], 4, "body", (STEEL, 0.6, 1.0), shape=octagon(0.7))
    for i in range(3):
        hip, points, ankle, foot = leg_rest(i)
        ellipsoid(b, hip, V(2.4, 2.4, 2.4), "body", (STEEL, 0.6, 0.3), 0, res(12, 6), res(20, 8))


def leg(b, i):
    """A long, flexible leg of segmented metal: a ribbed cable of vertebrae, a collar at each of its many joints,
    a cable along its underside, ending in a foot of three claws."""
    hip, points, ankle, foot = leg_rest(i)
    out = leg_out(i)
    side = UP.cross(out).normalized()
    fb = "foot_%d" % i
    seg = LEG_LENGTH / LEG_BONES
    steps = res(16, 4)
    dense = []
    params = []
    for j in range(LEG_BONES):
        for k in range(steps):
            f = k / steps
            dense.append(points[j].lerp(points[j + 1], f))
            params.append(j + f)
    dense.append(points[-1])
    params.append(float(LEG_BONES))
    # (smooth the polyline a little so the tube bends roundly)
    for _ in range(3):
        dense = [dense[0]] + [(dense[k - 1] + dense[k] * 2.0 + dense[k + 1]) * 0.25 for k in range(1, len(dense) - 1)] + [dense[-1]]
    radii = []
    for p in params:
        v = p / LEG_BONES
        r = lerp(1.45, 0.62, v ** 0.8)
        f = p - math.floor(p)
        if not LOW:
            # vertebrae: a ring every fifth of a segment, and a heavy collar at each joint
            ring = max(math.cos(f * math.tau * 5.0), 0.0) ** 6
            collar = math.exp(-((min(f, 1.0 - f)) / 0.035) ** 2)
            r *= 1.0 + 0.09 * ring + 0.22 * collar
        else:
            r *= 1.0 + 0.15 * math.exp(-((min(f, 1.0 - f)) / 0.06) ** 2)
        radii.append(r)

    def weigh_at(p):
        j = min(int(p), LEG_BONES - 1)
        f = p - j
        name = "leg_%d_%d" % (i, j)
        if f < 0.2 and j > 0:
            w = 0.5 + f / 0.4
            return {name: w, "leg_%d_%d" % (i, j - 1): 1.0 - w}
        if f > 0.8 and j < LEG_BONES - 1:
            w = 0.5 + (1.0 - f) / 0.4
            return {name: w, "leg_%d_%d" % (i, j + 1): 1.0 - w}
        return {name: 1.0}

    def weigh(r, c, p):
        return weigh_at(params[min(r, len(params) - 1)])
    tube(b, dense, radii, res(14, 7), weigh, (STEEL, 1.0, 0.0), side=side, caps=(False, False))
    if not LOW:
        # A cable along its underside, held off it by the collars
        frames = frames_along(dense, side)
        cable = []
        for k, p in enumerate(dense):
            t, n, bn = frames[k]
            under = -(UP - t * UP.dot(t)).normalized() if abs(t.dot(UP)) < 0.99 else n
            cable.append(p + under * (radii[k] + 0.25))
        cable_radii = [0.16] * len(cable)
        tube(b, cable, cable_radii, 5, weigh, (CABLE, 0.8, 0.2), side=side)
    # The hip's shroud
    d0 = (points[1] - points[0]).normalized()
    tube(b, [hip - d0 * 0.8, hip + d0 * 2.0], [2.5, 1.8], res(16, 8), "leg_%d_0" % i, (PLATE, 0.9, 0.6), side=side, caps=(False, False))
    # The foot: a domed pad and three claws
    sides = res(16, 8)
    rows = []
    for k, (y, r) in enumerate([(1.9, 0.6), (1.5, 1.5), (1.0, 2.1), (0.4, 2.3), (0.05, 2.0)]):
        rows.append([foot + V(math.sin(math.tau * j / sides) * r, y, math.cos(math.tau * j / sides) * r) for j in range(sides)])
    b.sheet(rows, fb, (STEEL, 0.8, 0.4), 0, True, lambda c: c - (foot + UP * 0.4), cap_start=foot + UP * 2.0, cap_end=foot + UP * 0.02)
    for k in range(3):
        a = math.radians(LEG_ANGLES[i]) + math.tau * k / 3.0
        o = Vector((math.sin(a), 0.0, math.cos(a)))
        pts = [foot + o * 1.4 + UP * 1.0, foot + o * 2.6 + UP * 1.2, foot + o * 3.6 + UP * 0.85, foot + o * 4.3 + UP * 0.3, foot + o * 4.6 + UP * 0.02]
        tube(b, pts, [0.55, 0.5, 0.4, 0.25, 0.08], res(10, 5), fb, (STEEL, 0.9, 0.8), side=UP, shape=octagon(0.7) if not LOW else None)


def arm(b):
    s, e, w, t = arm_rest()
    side = Vector((-1.0, 0.0, 0.0))
    # The shoulder housing on the hood, and the ball the arm turns in
    ellipsoid(b, s + UP * 0.4, V(1.6, 1.2, 1.6), "head", (STEEL, 0.6, 0.4), 0, res(10, 5), res(16, 8))
    ellipsoid(b, s, V(1.05, 1.05, 1.05), "arm_upper", (STEEL, 0.7, 0.7), 0, res(8, 4), res(14, 7))
    d = (e - s).normalized()
    stations = [0.0, 0.1, 0.45, 0.48, 0.5, 0.9, 1.0]
    radii = [0.6, 0.72, 0.62, 0.78, 0.6, 0.5, 0.48]
    tube(b, [s + d * UPPER_ARM * k for k in stations], radii, res(12, 6), "arm_upper", (PLATE, 1.0, 0.0), side=side, shape=octagon(0.8))
    drum(b, e, side, 0.85, 0.7, "arm_fore", (STEEL, 0.8, 0.6), sides=res(16, 8), hub=0.45)
    d = (w - e).normalized()
    tube(b, [e + d * FOREARM * k for k in (0.0, 0.5, 0.52, 0.54, 1.0)], [0.55, 0.48, 0.6, 0.47, 0.42], res(12, 6), "arm_fore", (PLATE, 1.0, 0.0), side=side, shape=octagon(0.8))
    ellipsoid(b, w, V(0.7, 0.7, 0.7), "emitter", (STEEL, 0.8, 0.6), 0, res(8, 4), res(14, 7))
    # The emitter: a housing, a flared horn, the lens deep in it, fins round its back
    d = (t - w).normalized()
    stations = [(0.0, 0.7), (0.05, 0.92), (0.55, 0.95), (0.6, 1.05), (0.68, 0.95), (0.8, 1.15), (1.0, 1.45)]
    pts = [w + d * EMITTER * k for k, r in stations]
    tube(b, pts, [r for k, r in stations], res(20, 8), "emitter", (PLATE, 0.9, 0.3), side=side, caps=(True, False))
    rim = [w + d * EMITTER * k for k in (1.0, 1.0, 0.82)]
    tube(b, rim, [1.45, 1.3, 0.9], res(20, 8), "emitter", (MACHINE, 0.3, 0.9), side=side, caps=(False, False))
    lens_at = w + d * EMITTER * 0.8
    ellipsoid(b, lens_at, V(0.75, 0.25, 0.75), "emitter", (0.0, 1.0, 0.0), 1, res(6, 3), res(14, 7),
              axes=(side, d, side.cross(d).normalized()))
    if not LOW:
        bn = side.cross(d).normalized()
        for k in range(8):
            a = math.tau * k / 8 + 0.2
            o = side * math.cos(a) + bn * math.sin(a)
            tube(b, [w + d * 0.4 + o * 0.9, w + d * 1.9 + o * 0.92], [0.18, 0.18], 4, "emitter", (STEEL, 0.6, 1.0), shape=lambda x: 1.0 + 1.8 * abs(math.cos(x)), twist=a)


def tentacle_root(k):
    (x, z), seg = TENTACLES[k]
    return Vector((x, dish_y_at(x, z) + 0.2, z)), seg


def tentacles(b):
    for k in range(len(TENTACLES)):
        root, seg = tentacle_root(k)
        n = res(48, 12)
        pts = [root - UP * (4 * seg * j / n) for j in range(n + 1)]
        radii = []
        for j in range(n + 1):
            v = j / n
            r = lerp(0.48 if k != GRASPER else 0.56, 0.17, v)
            if not LOW:
                r *= 1.0 + 0.16 * max(math.sin(j * math.pi * 0.5), 0.0)
            radii.append(r)

        def weigh(r, c, p, root=root, seg=seg, k=k):
            along = (root.y - p.y) / seg
            j = min(int(along), 3)
            f = along - j
            weights = {"tent_%d_%d" % (k, j): 1.0}
            # (blended over the joints, so that the cable bends smoothly)
            if f < 0.15 and j > 0:
                w = 0.5 + f / 0.3
                weights = {"tent_%d_%d" % (k, j): w, "tent_%d_%d" % (k, j - 1): 1.0 - w}
            elif f > 0.85 and j < 3:
                w = 0.5 + (1.0 - f) / 0.3
                weights = {"tent_%d_%d" % (k, j): w, "tent_%d_%d" % (k, j + 1): 1.0 - w}
            return weights
        tube(b, pts, radii, res(10, 5), weigh, (CABLE, 1.0, 0.3), side=Vector((1, 0, 0)), caps=(False, True))
        # its root collar
        tube(b, [root + UP * 0.4, root - UP * 0.5], [0.9, 0.7], res(12, 6), "head", (STEEL, 0.6, 0.7))
        if k == GRASPER:
            end = root - UP * (4 * seg)
            last = "tent_%d_3" % k
            ellipsoid(b, end, V(0.45, 0.35, 0.45), last, (STEEL, 0.8, 0.6), 0, res(6, 3), res(10, 6))
            for c in range(3):
                a = math.tau * c / 3.0
                o = Vector((math.sin(a), 0.0, math.cos(a)))
                pts = [end + o * 0.3, end + o * 0.9 - UP * 0.5, end + o * 1.1 - UP * 1.4, end + o * 0.7 - UP * 2.3, end + o * 0.2 - UP * 2.7]
                tube(b, pts, [0.2, 0.18, 0.15, 0.1, 0.03], res(6, 4), last, (STEEL, 0.9, 0.9))


# --- The red weed ---

def weed(b, rng):
    if LOW:
        count = 4
    else:
        count = 1
    strand_sides = res(4, 3)

    def strand(points, bone, thick=0.1):
        radii = [thick * lerp(1.0, 0.35, j / (len(points) - 1)) for j in range(len(points))]
        tube(b, points, radii, strand_sides, bone, (0.5 + rng.random() * 0.5, 1.0, 0.0), 2, caps=(False, True))

    def hang(start, length, bone, drift):
        pts = [start]
        steps = res(7, 3)
        for j in range(1, steps + 1):
            v = j / steps
            pts.append(start + drift * (math.sin(v * 2.0) * 0.6) - UP * length * v + Vector((rng.uniform(-0.15, 0.15), 0.0, rng.uniform(-0.15, 0.15))))
        strand(pts, bone, rng.uniform(0.07, 0.13))

    # Over the hood and hanging from the rim (sides and back)
    sites = [math.radians(a) for a in (55, 80, 100, 128, 150, 172, 196, 214, 236, 262, 285, 305)]
    for n, phi0 in enumerate(sites):
        if n % count:
            continue
        for s in range(res(7, 2)):
            phi = phi0 + rng.uniform(-0.09, 0.09)
            t0 = rng.uniform(0.25, 0.55)
            pts = []
            steps = res(6, 2)
            for j in range(steps + 1):
                t = t0 * (1.0 - j / steps)
                pts.append(hood_point(phi + 0.02 * math.sin(j), t) + hood_normal(phi, t) * 0.14)
            rim = hood_point(phi, 0.0) + hood_normal(phi, 0.0) * 0.3
            length = rng.uniform(2.0, 8.0)
            for j in range(1, res(6, 3) + 1):
                v = j / res(6, 3)
                pts.append(rim - UP * (length * v) + hood_normal(phi, 0.0) * (0.4 * math.sin(v * 2.5)) + Vector((rng.uniform(-0.12, 0.12), 0.0, rng.uniform(-0.12, 0.12))))
            strand(pts, "head", rng.uniform(0.08, 0.14))
    # Draped over the high arch of each leg and hanging from it, and off the drum
    for i in range(3):
        hip, points, ankle, foot = leg_rest(i)
        out = leg_out(i)
        side = UP.cross(out).normalized()
        for s in range(res(12, 4)):
            j = rng.randint(2, 5)
            f = rng.random()
            start = points[j].lerp(points[j + 1], f) + UP * 1.2 + side * rng.uniform(-0.9, 0.9)
            hang(start, rng.uniform(2.5, 10.0), "leg_%d_%d" % (i, j), out * rng.uniform(0.2, 0.9))
    for s in range(res(8, 3)):
        a = rng.uniform(0.0, math.tau)
        o = Vector((math.sin(a), 0.0, math.cos(a)))
        hang(o * 5.6 + UP * 51.4, rng.uniform(2.0, 7.0), "body", o * 0.6)


# --- Bones, weights, colours ---

def bones():
    out = [("body", BODY, None), ("head", HEAD_PIVOT, "body"), ("eye", eye_rest(), "head")]
    s, e, w, t = arm_rest()
    out += [("arm_upper", s, "head"), ("arm_fore", e, "head"), ("emitter", w, "head")]
    for i in range(3):
        hip, points, ankle, foot = leg_rest(i)
        out += [("leg_%d_%d" % (i, j), points[j], "body") for j in range(LEG_BONES)]
        out.append(("foot_%d" % i, foot, "body"))
    for k in range(len(TENTACLES)):
        root, seg = tentacle_root(k)
        for j in range(4):
            out.append(("tent_%d_%d" % (k, j), root - UP * seg * j, "head"))
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
        bone.tail = to_b(at + UP * 0.5)
        bone.roll = 0.0
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def build(rng):
    b = Build()
    hood(b)
    hood_ribs(b)
    dish(b)
    face(b)
    eye(b)
    vents(b)
    drum_body(b)
    for i in range(3):
        leg(b, i)
    arm(b)
    tentacles(b)
    weed(b, rng)
    return b


def make_mesh(b, name):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_b(p) for p in b.verts], [], b.faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    k = 0
    for poly, corners in zip(mesh.polygons, b.uvs):
        for li, c in zip(poly.loop_indices, corners):
            uv.data[li].uv = c
    for poly, m in zip(mesh.polygons, b.mats):
        poly.material_index = m
        poly.use_smooth = True
    return mesh


def bake_colours(mesh, b, rng):
    """Vertex colours: the tone, how open each point is to the sky (rays out over its hemisphere), and edge wear."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    count = res(14, 8)
    dirs = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for k in range(count):
        z = 1.0 - (k + 0.5) / count
        r = math.sqrt(max(1.0 - z * z, 0.0))
        dirs.append(Vector((math.cos(golden * k) * r, math.sin(golden * k) * r, z)))
    reach = 9.0
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
            loc, nor, idx, dist = tree.ray_cast(v.co + n * 0.05, w, reach)
            if loc is not None:
                hits += 1.0 - dist / reach * 0.6
        # (and the sky is above: what faces down is darker anyway)
        sky = 0.65 + 0.35 * max(n.z, -0.6) / 1.0
        opens.append(max(0.0, 1.0 - hits / count) * sky)
    wear = []
    for v in bm.verts:
        sharp = 0.0
        for e in v.link_edges:
            if len(e.link_faces) == 2:
                a = e.calc_face_angle_signed(0.0)
                if a > 0.35:
                    sharp = max(sharp, min((a - 0.35) / 0.6, 1.0))
        wear.append(sharp)
    bm.free()
    attribute = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    weed_verts = set()
    for f, m in zip(b.faces, b.mats):
        if m == 2:
            weed_verts.update(f)
    for i, (tone, grime, edge) in enumerate(b.cols):
        # (green as made is how much of the open sky a part lets show: the inside of the hood little)
        o = opens[i] * grime
        noise = 0.06 * (rng.random() - 0.5) if i not in weed_verts else 0.0
        attribute.data[i].color = (min(max(tone + noise, 0.0), 1.0), min(max(o, 0.0), 1.0), min(max(edge + wear[i], 0.0), 1.0), 1.0)
    mesh.color_attributes.active_color = attribute
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")


def glow_colours(mesh, b):
    """On the glow material the colour says which light it is (red the eye, green the emitter): keep it as made."""
    attribute = mesh.color_attributes["Color"]
    for poly in mesh.polygons:
        if poly.material_index == 1:
            for vi in poly.vertices:
                tone, grime, edge = b.cols[vi]
                attribute.data[vi].color = (tone, grime, edge, 1.0)


def export(preview):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    armature = make_armature(bones())
    made = []
    global LOW
    for low in (False, True):
        LOW = low
        rng = random.Random(7)
        b = build(rng)
        name = "tripod_lo" if low else "tripod"
        mesh = make_mesh(b, name)
        bake_colours(mesh, b, rng)
        glow_colours(mesh, b)
        mesh.set_sharp_from_angle(angle=math.radians(48.0))
        body = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(body)
        for label, srgb in MATERIALS:
            material = bpy.data.materials.get(label) or bpy.data.materials.new(label)
            material.use_nodes = True
            bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Base Color"].default_value = srgb + (1.0,)
            material.diffuse_color = srgb + (1.0,)
            mesh.materials.append(material)
        groups = {bone.name: body.vertex_groups.new(name=bone.name) for bone in armature.data.bones}
        for i, weights in enumerate(b.weights):
            for bone, w in weights.items():
                groups[bone].add([i], w, "REPLACE")
        body.parent = armature
        body.modifiers.new("Armature", "ARMATURE").object = armature
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), tris))
        made.append(body)
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, "tripod.glb"), export_format="GLB", export_yup=True,
        export_animations=False, export_skins=True, export_vertex_color="ACTIVE",
    )
    if preview:
        os.makedirs(preview, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(preview, "tripod.blend"))
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
    views = [("side", (1, 0, 0), (0, 0, 32), 70.0), ("front", (0, -1, 0.1), (0, 0, 32), 70.0),
             ("quarter", (0.7, -0.7, 0.25), (0, 0, 32), 70.0), ("hood", (0.6, -0.8, 0.35), (0, -2, 54), 34.0),
             ("hood_front", (0.05, -1, -0.15), (0, -6, 52), 26.0), ("under", (0.3, -0.5, -0.8), (0, 0, 50), 40.0),
             ("leg", (0.9, -0.3, 0.2), tuple(to_b(leg_rest(0)[1][4])), 18.0), ("foot", (0.8, -0.6, 0.3), tuple(to_b(leg_rest(0)[3] + UP * 2)), 12.0),
             ("emitter", (-0.8, -0.6, 0.0), tuple(to_b(arm_rest()[2])), 14.0), ("top", (0.1, -0.1, 1), (0, 0, 50), 70.0)]
    for low in (False, True):
        for obj in made:
            obj.hide_render = (obj.name == "tripod") == low
        for view, direction, target, frame in views:
            if low and view not in ("quarter", "hood"):
                continue
            for colours in (("MATERIAL", "VERTEX") if not low else ("MATERIAL",)):
                if colours == "VERTEX" and view not in ("quarter", "hood", "under"):
                    continue
                scene.display.shading.color_type = colours
                offset = Vector(direction).normalized() * 300.0
                camera.data.ortho_scale = frame
                camera.location = Vector(target) + offset
                camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
                scene.render.filepath = os.path.join(folder, "%s%s_%s%s.png" % ("lo_" if low else "", view, colours.lower(), ""))
                bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    export(PREVIEW)

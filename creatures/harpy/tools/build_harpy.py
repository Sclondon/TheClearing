"""Builds the harpy and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/harpy/tools/build_harpy.py [-- <preview folder>]

Writes creatures/harpy/models/harpy.glb: two meshes on one skeleton, "harpy"
and "harpy_lo" (fewer feathers and strands of hair, a coarser skin), for Harpy
to choose between by distance. Given a folder, renders previews into it.

What it is: the harpy of the old stories, starved. A gaunt, wasted woman's head
and trunk: collarbones and ribs standing out under ashen skin, a sunken belly,
a scrawny corded neck; a long skull with hollow temples and cheeks, deep eye
sockets with small milky eyes in them, and a lipless mouth far too wide, cut
from under one cheekbone to the other, its jaw hinged to drop open on crowded
teeth. Lank wet hair hangs from the crown in clumps over most of the face and
down to the chest. Where her arms should be are great ragged wings, built as a
bird's are: the arm (humerus, forearm, the hand and its one long finger), ten
primaries on the hand and finger (the outer five emarginated, so the spread
wing ends in fingers), twelve secondaries and tertials on the forearm, humeral
feathers behind the upper arm, greater, median and lesser coverts in rows over
them, under-wing coverts, an alula, scapulars over the shoulder; and at the
wrist, where a bird has its alula, what is left of a hand: three bony fingers
with hooked black claws. From the lower ribs down she is a bird: a feathered
belly and rump, a ragged tail of twelve feathers, feathered thighs and shins
(long "trousers" hanging over the ankle), and bare scaly raptor legs, each foot
three toes forward and one back with long hooked talons. The feathers are
grey-black, filthy, worn pale at the edges, notched and broken, some missing
(she is moulting: a gap and a half-grown pin feather in one wing, a broken one
in the other, bare patches on the body).

How it is made. Godot's axes (Y up, facing +Z, +X her left) throughout, turned
to Blender's only as it is put in a mesh.
- The skin (trunk, neck, arms to the fingertips, thighs and shins; and the head)
  is a signed distance field: ellipsoids and capsules joined with smooth unions
  (the ribs and collarbones as thin capsules, so they stand out under the
  skin) and smooth cuts (the eye sockets, temples, cheeks, the sunken belly).
  It is sampled on a grid and polygonised (surface nets), decimated, and every
  vertex put back on the surface; the normals are the field's gradient, and how
  deep in a hollow each point is (a few steps of the field out along the
  normal) is baked into the alpha of its colour. The head is its own finer
  field, overlapping the neck; the mouth is cut out of it as a slit, and its
  lips weighted to the head above and the jaw below, with a mouth behind it.
- Feathers are cards: a quill, then two vanes either side of a raised rachis,
  cambered, swept, narrowing at the tip, notched; tinted per feather. Hair is
  flattened clumps hung from the scalp, falling under gravity and pushed out of
  the skin as they fall. The tarsi and toes are lofted tubes, the talons and
  claws curved horn.
- One skeleton, its bones parented as a bird's are (hips, spine, chest, neck,
  head, jaw; hair; per side clavicle, humerus, forearm, hand, finger, the wrist
  claws, each primary its own bone p1..p10 and the secondaries in four, sec1..
  sec4; thigh, shin, tarsus and the toes; the tail and the two halves of its
  fan), so that Harpy (creatures/harpy/harpy.gd) can fold and spread the wing a
  feather at a time. It is built in the rest pose: standing, wings straight out.
- What each vertex is, for HarpyLook's shader: UV2.x a kind (0 skin, 1 feather,
  2 hair, 3 scales, 4 horn, 5 eye, 6 mouth, 7 teeth), UV2.y a random number per
  piece; UV where on its piece (a feather: along it and across it, -1 leading
  edge to 1 trailing; scales: along and round); colour, and how open it is
  (alpha: 1 open, 0 in a hollow).
"""

import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

SKIN, FEATHER, HAIR, SCALES, HORN, EYE, MOUTH, TEETH, PLUMAGE = range(9)


def V(*p):
    if len(p) == 1:
        p = p[0]
    return np.array(p, dtype=np.float64)


def to_b(p):
    return Vector((p[0], -p[2], p[1]))


def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a + (b - a) * t


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def rot_axis(axis, a):
    axis = norm(axis)
    x, y, z = axis
    c, s = math.cos(a), math.sin(a)
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


# ---------------------------------------------------------------------------
# The skeleton (rest: standing, wings straight out). Left side (+X); the right
# is the mirror. Each bone: head, tail, parent.

SHOULDER = V(0.17, 1.425, -0.02)
ELBOW = V(0.58, 1.425, -0.045)
WRIST = V(1.03, 1.425, -0.02)
KNUCKLE = V(1.30, 1.425, -0.012)
FINGERTIP = V(1.47, 1.425, -0.004)
CLAVICLE = V(0.03, 1.428, 0.035)
HIP = V(0.11, 0.93, -0.03)
KNEE = V(0.14, 0.72, 0.09)
ANKLE = V(0.14, 0.36, -0.06)
FOOT = V(0.14, 0.065, 0.02)
JAW_HINGE = V(0.0, 1.588, 0.0)
CHIN = V(0.0, 1.535, 0.095)

# Toes: [base, joint, tip] (left foot). 1 the hallux, back; 2 inner, 3 middle, 4 outer.
TOES = {
    1: [FOOT + V(0.0, -0.02, -0.02), FOOT + V(0.0, -0.035, -0.085), FOOT + V(0.0, -0.04, -0.14)],
    2: [FOOT + V(-0.012, -0.025, 0.015), FOOT + V(-0.035, -0.04, 0.07), FOOT + V(-0.055, -0.045, 0.12)],
    3: [FOOT + V(0.004, -0.025, 0.02), FOOT + V(0.01, -0.04, 0.095), FOOT + V(0.016, -0.045, 0.175)],
    4: [FOOT + V(0.018, -0.025, 0.012), FOOT + V(0.05, -0.04, 0.06), FOOT + V(0.075, -0.045, 0.105)],
}
# Talon lengths (along the curve), per toe.
TALONS = {1: 0.085, 2: 0.07, 3: 0.06, 4: 0.05}


def primaries():
    """The ten primaries, P1 (inner) to P10 (outer): root, angle back from +X, length, bone parent."""
    # (x of the root along the hand and finger, angle back from straight out, length)
    table = [(1.045, 80, 0.455), (1.08, 73, 0.47), (1.12, 65, 0.49), (1.165, 56, 0.53), (1.215, 46, 0.58),
             (1.27, 36, 0.64), (1.32, 27, 0.68), (1.37, 19, 0.70), (1.415, 12, 0.67), (1.455, 6, 0.61)]
    out = []
    for i, (x, angle, length) in enumerate(table):
        z = arm_z(x) - 0.012
        parent = "finger" if x > KNUCKLE[0] else "hand"
        out.append((V(x, 1.418, z), math.radians(angle), length, parent))
    return out


def secondaries():
    """S1 (by the wrist) to S12 (the tertials, by the elbow): root, angle back from +X, length, group."""
    out = []
    for i in range(12):
        u = i / 11.0
        x = mix(1.0, 0.615, u)
        angle = math.radians(mix(84, 99, u))
        length = mix(0.445, 0.41, u) + (0.02 if i >= 10 else 0.0)
        out.append((V(x, 1.416, arm_z(x) - 0.016), angle, length, i // 3 + 1))
    return out


def arm_z(x):
    """Where the arm's bones run (z) at a distance out (x), on the left wing."""
    pts = [SHOULDER, ELBOW, WRIST, KNUCKLE, FINGERTIP]
    for a, b in zip(pts, pts[1:]):
        if x <= b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            return a[2] + (b[2] - a[2]) * max(0.0, min(1.0, t))
    return FINGERTIP[2]


def arm_radius(x):
    pts = [(SHOULDER[0], 0.048), (ELBOW[0], 0.03), (WRIST[0], 0.022), (KNUCKLE[0], 0.016), (FINGERTIP[0], 0.007)]
    for (xa, ra), (xb, rb) in zip(pts, pts[1:]):
        if x <= xb:
            t = max(0.0, min(1.0, (x - xa) / (xb - xa)))
            return ra + (rb - ra) * t
    return 0.007


def bones():
    B = {}

    def add(name, head, tail, parent):
        B[name] = (V(head), V(tail), parent)

    add("hips", (0, 0.95, -0.03), (0, 1.08, -0.02), None)
    add("spine", (0, 1.08, -0.02), (0, 1.27, -0.01), "hips")
    add("chest", (0, 1.27, -0.01), (0, 1.46, 0.0), "spine")
    add("neck", (0, 1.46, 0.0), (0, 1.565, 0.012), "chest")
    add("head", (0, 1.565, 0.012), (0, 1.72, 0.02), "neck")
    add("jaw", JAW_HINGE, CHIN, "head")
    add("hair_f1", (0, 1.70, 0.10), (0, 1.50, 0.14), "head")
    add("hair_f2", (0, 1.50, 0.14), (0, 1.28, 0.14), "hair_f1")
    add("hair_b1", (0, 1.71, -0.07), (0, 1.48, -0.115), "head")
    add("hair_b2", (0, 1.48, -0.115), (0, 1.24, -0.12), "hair_b1")
    add("tail", (0, 0.915, -0.15), (0, 0.885, -0.3), "hips")
    for side, s in (("l", 1.0), ("r", -1.0)):
        M = np.array([s, 1.0, 1.0])

        def addm(name, head, tail, parent):
            add(name + "_" + side, V(head) * M, V(tail) * M, parent + "_" + side if parent not in ("chest", "hips", "head", "tail") else parent)

        addm("hair", (0.075, 1.665, 0.005), (0.10, 1.40, 0.02), "head")
        addm("clavicle", CLAVICLE, SHOULDER, "chest")
        addm("humerus", SHOULDER, ELBOW, "clavicle")
        addm("forearm", ELBOW, WRIST, "humerus")
        addm("hand", WRIST, KNUCKLE, "forearm")
        addm("finger", KNUCKLE, FINGERTIP, "hand")
        addm("claws", WRIST + V(0.01, 0.0, 0.03), WRIST + V(0.08, 0.0, 0.07), "hand")
        for i, (root, angle, length, parent) in enumerate(primaries()):
            d = V(math.cos(angle), 0.0, -math.sin(angle))
            addm("p%d" % (i + 1), root, root + d * length * 0.5, parent)
        groups = {}
        for root, angle, length, g in secondaries():
            groups.setdefault(g, []).append((root, angle, length))
        for g, feathers in groups.items():
            root, angle, length = feathers[len(feathers) // 2]
            d = V(math.cos(angle), 0.0, -math.sin(angle))
            addm("sec%d" % g, root, root + d * length * 0.5, "forearm")
        addm("thigh", HIP, KNEE, "hips")
        addm("shin", KNEE, ANKLE, "thigh")
        addm("tarsus", ANKLE, FOOT, "shin")
        for t, (base, joint, tip) in TOES.items():
            addm("toe%da" % t, base, joint, "tarsus")
            addm("toe%db" % t, joint, tip, "toe%da" % t)
        add("tail_" + side, V(0.0, 0.885, -0.29), V(0.12 * s, 0.87, -0.62), "tail")
    return B


BONES = bones()
BONE_NAMES = list(BONES.keys())


# ---------------------------------------------------------------------------
# Signed distance fields (numpy, Godot axes)

def sd_ellipsoid(P, c, r, R=None):
    q = P - c
    if R is not None:
        q = q @ R  # (R's columns are the ellipsoid's axes)
    k0 = np.linalg.norm(q / r, axis=1)
    k1 = np.linalg.norm(q / (r * r), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_capsule(P, a, b, ra, rb):
    pa = P - a
    ba = b - a
    h = np.clip((pa @ ba) / max(ba @ ba, 1e-12), 0.0, 1.0)
    return np.linalg.norm(pa - np.outer(h, ba), axis=1) - (ra + (rb - ra) * h)


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


class Field:
    """A shape as a list of parts, each joined on (smoothly, by k) or cut away."""

    def __init__(self):
        self.parts = []

    def ellipsoid(self, c, r, k=0.0, cut=False, R=None):
        c, r = V(c), V(r)
        reach = max(r) * 1.05 + k + 0.02
        self.parts.append(("e", (c, r, R), k, cut, (c - reach, c + reach)))

    def capsule(self, a, b, ra, rb=None, k=0.0, cut=False):
        a, b = V(a), V(b)
        rb = ra if rb is None else rb
        reach = max(ra, rb) + k + 0.02
        self.parts.append(("c", (a, b, ra, rb), k, cut, (np.minimum(a, b) - reach, np.maximum(a, b) + reach)))

    def ball(self, c, r, k=0.0, cut=False):
        self.capsule(c, c, r, r, k, cut)

    def plane_above(self, y):
        """Everything above `y` is cut off (flat)."""
        self.parts.append(("above", (y,), 0.0, False, None))

    def plane_below(self, y):
        self.parts.append(("below", (y,), 0.0, False, None))

    def __call__(self, P):
        d = None
        for kind, prm, k, cut, box in self.parts:
            if kind == "above":
                d = np.maximum(d, P[:, 1] - prm[0])
                continue
            if kind == "below":
                d = np.maximum(d, prm[0] - P[:, 1])
                continue
            inside = np.all((P >= box[0]) & (P <= box[1]), axis=1)
            v = np.full(len(P), 1.0)
            if inside.any():
                Q = P[inside]
                v[inside] = sd_ellipsoid(Q, *prm) if kind == "e" else sd_capsule(Q, *prm)
            if d is None:
                d = v
            elif cut:
                d = smax(d, -v, k)
            else:
                d = smin(d, v, k)
        return d

    def gradient(self, P, eps=0.0008):
        g = np.zeros_like(P)
        for i in range(3):
            o = np.zeros(3)
            o[i] = eps
            g[:, i] = (self(P + o) - self(P - o)) / (2 * eps)
        return g

    def project(self, P, steps=4):
        for _ in range(steps):
            d = self(P)
            g = self.gradient(P)
            P = P - (d / np.maximum((g * g).sum(1), 1e-9))[:, None] * g
        return P

    def surface_point(self, start, direction, far=0.5, step=0.0015):
        """Where a ray from `start` (outside) along `direction` first meets the surface."""
        direction = norm(V(direction))
        ts = np.arange(0.0, far, step)
        P = V(start)[None, :] + ts[:, None] * direction[None, :]
        d = self(P)
        hit = np.nonzero(d < 0)[0]
        if len(hit) == 0:
            return None
        i = hit[0]
        if i == 0:
            return P[0]
        t = ts[i - 1] + step * d[i - 1] / (d[i - 1] - d[i])
        return V(start) + direction * t

    def occlusion(self, P, N, step, count=5):
        """How open each point is, 1 open, 0 deep in a hollow."""
        shut = np.zeros(len(P))
        for k in range(1, count + 1):
            dist = k * step
            shut += (dist - np.minimum(self(P + N * dist), dist)) / dist * (0.5 ** k)
        return np.clip(1.0 - shut * 1.4, 0.0, 1.0)


def surface_nets(field, lo, hi, h):
    """Polygonises `field` over the box lo..hi with cells `h` across: (vertices, triangles)."""
    lo = V(lo)
    hi = V(hi)
    n = (np.ceil((hi - lo) / h)).astype(int) + 1
    F = np.empty(tuple(n), dtype=np.float32)
    ys = lo[1] + np.arange(n[1]) * h
    zs = lo[2] + np.arange(n[2]) * h
    YY, ZZ = np.meshgrid(ys, zs, indexing="ij")
    for i0 in range(0, n[0], 8):
        i1 = min(n[0], i0 + 8)
        xs = lo[0] + np.arange(i0, i1) * h
        P = np.stack(np.broadcast_arrays(xs[:, None, None], YY[None], ZZ[None]), axis=-1).reshape(-1, 3)
        F[i0:i1] = field(P).reshape(i1 - i0, n[1], n[2])
    cells = n - 1
    total = int(np.prod(cells))
    sums = np.zeros((total, 3))
    counts = np.zeros(total)

    def index(c):
        return (c[:, 0] * cells[1] + c[:, 1]) * cells[2] + c[:, 2]

    quads = []
    for axis in range(3):
        s0 = [slice(None)] * 3
        s1 = [slice(None)] * 3
        s0[axis] = slice(0, -1)
        s1[axis] = slice(1, None)
        f0 = F[tuple(s0)]
        f1 = F[tuple(s1)]
        cross = (f0 < 0) != (f1 < 0)
        idx = np.argwhere(cross)
        a = f0[cross].astype(np.float64)
        b = f1[cross].astype(np.float64)
        t = a / (a - b)
        pts = lo + h * idx.astype(np.float64)
        pts[:, axis] += h * t
        o1, o2 = [ax for ax in range(3) if ax != axis]
        for d1 in (0, -1):
            for d2 in (0, -1):
                c = idx.copy()
                c[:, o1] += d1
                c[:, o2] += d2
                ok = np.all((c >= 0) & (c < cells), axis=1)
                ci = index(c[ok])
                np.add.at(sums, ci, pts[ok])
                np.add.at(counts, ci, 1)
        ok = (idx[:, o1] >= 1) & (idx[:, o2] >= 1) & (idx[:, o1] < cells[o1]) & (idx[:, o2] < cells[o2]) & (idx[:, axis] < cells[axis])
        e = idx[ok]
        low_inside = a[ok] < 0

        def cell(d1, d2):
            c = e.copy()
            c[:, o1] += d1
            c[:, o2] += d2
            return index(c)

        q = np.stack([cell(-1, -1), cell(0, -1), cell(0, 0), cell(-1, 0)], axis=1)
        flip = (~low_inside) ^ (axis == 1)
        q[flip] = q[flip][:, ::-1]
        quads.append(q)
    quads = np.concatenate(quads)
    used = np.nonzero(counts > 0)[0]
    remap = np.full(total, -1)
    remap[used] = np.arange(len(used))
    verts = sums[used] / counts[used][:, None]
    quads = remap[quads]
    quads = quads[np.all(quads >= 0, axis=1)]
    tris = np.concatenate([quads[:, [0, 1, 2]], quads[:, [0, 2, 3]]])
    return verts, tris


def blender_mesh(verts, tris, name="part"):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_b(p) for p in verts], [], [tuple(int(i) for i in t) for t in tris])
    mesh.update()
    return mesh


def decimated(verts, tris, ratio):
    """The mesh decimated to `ratio` of its faces, as (vertices, triangles), Godot axes."""
    mesh = blender_mesh(verts, tris)
    obj = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(obj)
    if ratio < 0.999:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
    tri = obj.modifiers.new("Triangulate", "TRIANGULATE")
    depsgraph = bpy.context.evaluated_depsgraph_get()
    out = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(mesh)
    co = np.empty(len(out.vertices) * 3)
    out.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    verts = np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)
    tris = np.array([tuple(p.vertices) for p in out.polygons if len(p.vertices) == 3], dtype=int)
    bpy.data.meshes.remove(out)
    return verts, tris


def vertex_normals(P, T):
    """Smooth normals of a mesh from its faces."""
    N = np.zeros_like(P)
    if len(T) == 0:
        return N
    a, b, c = P[T[:, 0]], P[T[:, 1]], P[T[:, 2]]
    f = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(N, T[:, k], f)
    return N / np.maximum(np.linalg.norm(N, axis=1), 1e-12)[:, None]


# ---------------------------------------------------------------------------
# The model, as it is put together

class Model:
    def __init__(self):
        self.P, self.N, self.C, self.UV0, self.UV1, self.W, self.T = [], [], [], [], [], [], []
        self.count = 0

    def add(self, P, T, N, C, UV0, UV1, W, mirror=False):
        P = np.array(P, dtype=np.float64).reshape(-1, 3)
        N = np.array(N, dtype=np.float64).reshape(-1, 3)
        T = np.array(T, dtype=int).reshape(-1, 3)
        if mirror:
            P = P * V(-1, 1, 1)
            N = N * V(-1, 1, 1)
            T = T[:, ::-1]
            W = [{_mirror_name(k): w for k, w in wd.items()} for wd in W]
        self.P.append(P)
        self.N.append(N)
        self.C.append(np.array(C, dtype=np.float64).reshape(-1, 4))
        self.UV0.append(np.array(UV0, dtype=np.float64).reshape(-1, 2))
        self.UV1.append(np.array(UV1, dtype=np.float64).reshape(-1, 2))
        self.W.extend(W)
        self.T.append(T + self.count)
        self.count += len(P)

    def triangles(self):
        return sum(len(t) for t in self.T)


def _mirror_name(name):
    if name.endswith("_l"):
        return name[:-2] + "_r"
    if name.endswith("_r"):
        return name[:-2] + "_l"
    return name


# ---------------------------------------------------------------------------
# Weights

def segment_distance(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
    return np.linalg.norm(P - (a + np.outer(t, ab)), axis=1)


def nearest_weights(P, among, power=4.0, keep=3):
    """Per point, weights for the bones of `among` by how near each bone's segment is."""
    D = np.stack([segment_distance(P, BONES[b][0], BONES[b][1]) for b in among], axis=1)
    W = 1.0 / (D ** power + 1e-12)
    order = np.argsort(-W, axis=1)[:, :keep]
    out = []
    for i in range(len(P)):
        ws = {among[j]: W[i, j] for j in order[i]}
        best = max(ws.values())
        ws = {k: w for k, w in ws.items() if w > best * 0.03}
        total = sum(ws.values())
        out.append({k: w / total for k, w in ws.items()})
    return out


def skin_weights(P):
    """Weights for the body's skin: each region to the bones that may move it."""
    out = []
    body = ["hips", "spine", "chest", "neck", "head"]
    for side in ("l", "r"):
        body += ["clavicle_" + side, "humerus_" + side, "thigh_" + side]
    arm = lambda s: ["chest", "clavicle_" + s, "humerus_" + s, "forearm_" + s, "hand_" + s, "finger_" + s]
    leg = lambda s: ["hips", "thigh_" + s, "shin_" + s, "tarsus_" + s]
    groups = {}
    keys = []
    for p in P:
        x, y, z = p
        s = "l" if x > 0 else "r"
        if abs(x) > 0.2 and y > 1.3:
            key = "arm_" + s
        elif y < 0.86 or (abs(x) > 0.08 and y < 0.95 and z > -0.1):
            key = "leg_" + s
        else:
            key = "body"
        keys.append(key)
    keys = np.array(keys)
    W = [None] * len(P)
    for key in set(keys):
        sel = np.nonzero(keys == key)[0]
        if key == "body":
            among = body
        elif key.startswith("arm"):
            among = arm(key[-1])
        else:
            among = leg(key[-1])
        ws = nearest_weights(P[sel], among)
        for i, w in zip(sel, ws):
            W[i] = w
    # (the chest is not pulled by the arm, nor the belly by the thighs, any more than a little)
    for i, p in enumerate(P):
        x, y, z = p
        w = W[i]
        for side in ("l", "r"):
            hb = "humerus_" + side
            if hb in w and abs(x) < 0.16:
                f = smooth(0.08, 0.16, abs(x))
                w["chest"] = w.get("chest", 0.0) + w[hb] * (1 - f)
                w[hb] *= f
            cb = "clavicle_" + side
            if cb in w and (abs(x) < 0.05 or y < 1.32):
                f = smooth(0.02, 0.06, abs(x)) * smooth(1.28, 1.34, y)
                w["chest"] = w.get("chest", 0.0) + w[cb] * (1 - f)
                w[cb] *= f
        total = sum(w.values())
        W[i] = {k: v / total for k, v in w.items() if v / total > 0.01}
    return W


# ---------------------------------------------------------------------------
# The skin

def body_field():
    f = Field()
    # The ribcage, narrow and starved, a little tipped forward.
    f.ellipsoid((0, 1.275, -0.008), (0.126, 0.165, 0.098), R=rot_x(-0.08))
    # The shoulder girdle, and the caps of the shoulders.
    f.capsule((-0.15, 1.418, -0.022), (0.15, 1.418, -0.022), 0.042, k=0.05)
    for s in (1, -1):
        f.ellipsoid((s * 0.17, 1.415, -0.022), (0.048, 0.048, 0.054), k=0.03)
    # Wasted chest: barely any flesh over the ribs.
    f.ellipsoid((0, 1.36, 0.02), (0.118, 0.065, 0.07), k=0.04)
    # The waist, pinched; the belly under the ribs sucked in.
    f.ellipsoid((0, 1.11, -0.018), (0.094, 0.12, 0.074), k=0.06)
    f.ellipsoid((0, 1.095, 0.105), (0.085, 0.065, 0.05), k=0.035, cut=True)
    # The bird's body below: the belly and the rump, the root of the tail.
    f.ellipsoid((0, 0.955, -0.05), (0.112, 0.115, 0.15), k=0.08)
    f.ellipsoid((0, 0.925, -0.17), (0.078, 0.065, 0.08), k=0.05)
    # Scapulae standing out on the back.
    for s in (1, -1):
        f.ellipsoid((s * 0.082, 1.34, -0.083), (0.052, 0.068, 0.018), k=0.022, R=rot_z(s * 0.3))
    # The neck: thin, corded, the tendons standing out to the notch of the breastbone.
    # (a hair thinner than the head's own neck, which overlaps it, so the two never fight)
    f.capsule((0, 1.40, -0.006), (0, 1.585, 0.01), 0.0365, 0.0305, k=0.05)
    for s in (1, -1):
        f.capsule((s * 0.04, 1.585, -0.006), (s * 0.012, 1.432, 0.066), 0.0092, 0.0078, k=0.01)
        f.capsule((s * 0.025, 1.52, -0.028), (s * 0.15, 1.432, -0.036), 0.02, 0.026, k=0.04)
    # Legs (thighs and shins, under their feathers).
    for s in (1, -1):
        m = V(s, 1, 1)
        f.capsule(HIP * m, KNEE * m, 0.055, 0.046, k=0.05)
        f.capsule(KNEE * m, ANKLE * m, 0.048, 0.028, k=0.03)
        f.ball(ANKLE * m, 0.03, k=0.012)
    # The arms, to the fingertips, and the thin skin of the leading edge.
    for s in (1, -1):
        m = V(s, 1, 1)
        f.capsule(SHOULDER * m, ELBOW * m, 0.046, 0.03, k=0.04)
        f.ball(ELBOW * m, 0.032, k=0.012)
        f.capsule(ELBOW * m, WRIST * m, 0.029, 0.021, k=0.012)
        f.ball(WRIST * m, 0.025, k=0.01)
        f.capsule(WRIST * m, KNUCKLE * m, 0.02, 0.015, k=0.008)
        f.capsule(KNUCKLE * m, FINGERTIP * m, 0.015, 0.006, k=0.006)
        f.ellipsoid(V(0.6 * s, 1.426, 0.012), (0.4, 0.011, 0.045), k=0.022, R=rot_y(s * 0.03))
    # Collarbones, the breastbone, the ribs: thin capsules on the surface, so they stand out.
    for s in (1, -1):
        f.capsule((s * 0.016, 1.432, 0.066), (s * 0.15, 1.448, -0.004), 0.0115, 0.0105, k=0.012)
        f.ball((s * 0.155, 1.448, -0.008), 0.016, k=0.01)
    f.capsule((0, 1.41, 0.08), (0, 1.22, 0.09), 0.009, 0.007, k=0.014)
    base = Field()
    base.parts = list(f.parts)
    for i in range(7):
        for s in (1, -1):
            y0 = 1.385 - i * 0.036
            reach = 2.55 - (0.3 if i >= 5 else 0.0) - i * 0.03
            pts = []
            for k in range(9):
                phi = mix(0.6, reach - 0.15, k / 8.0)
                y = y0 - 0.055 * (phi - 0.35) / 2.2
                scale = math.sqrt(max(0.0, 1.0 - ((y - 1.275) / 0.168) ** 2))
                rx, rz = 0.126 * scale + 0.0005, 0.098 * scale + 0.0005
                pts.append(V(s * rx * math.sin(phi), y, -0.008 - rz * math.cos(phi)))
            for a, b in zip(pts, pts[1:]):
                f.capsule(a, b, 0.005, 0.005, k=0.012)
    # The knobs of the spine down the back.
    for y in np.linspace(1.47, 1.04, 14):
        hit = base.surface_point((0, y, -0.4), (0, 0, 1))
        if hit is not None:
            f.ball(hit + V(0, 0, 0.004), 0.011, k=0.008)
    f.plane_above(1.56)
    return f


def head_field():
    f = Field()
    # The skull: long, narrow, the forehead high.
    f.ellipsoid((0, 1.668, -0.008), (0.07, 0.09, 0.093))
    f.ellipsoid((0, 1.672, 0.035), (0.062, 0.072, 0.062), k=0.03)
    # The face below: long and narrow, the maxilla, a gaunt jaw tapering to a small chin.
    f.ellipsoid((0, 1.606, 0.05), (0.047, 0.055, 0.05), k=0.03)
    f.ellipsoid((0, 1.562, 0.048), (0.04, 0.026, 0.046), k=0.028)
    f.ball((0, 1.537, 0.084), 0.011, k=0.02)
    for s in (1, -1):
        f.ball((s * 0.045, 1.566, 0.0), 0.014, k=0.022)
        f.capsule((s * 0.05, 1.598, -0.01), (s * 0.045, 1.566, 0.004), 0.011, k=0.018)
        # Cheekbones, standing out over the hollow cheeks.
        f.ellipsoid((s * 0.047, 1.627, 0.07), (0.017, 0.009, 0.018), k=0.016, R=rot_y(s * 0.5))
        f.capsule((s * 0.05, 1.627, 0.06), (s * 0.064, 1.624, 0.012), 0.0055, k=0.016)
        # Ears, small and flat to the head (the hair hides them).
        f.ellipsoid((s * 0.068, 1.632, -0.008), (0.007, 0.021, 0.015), k=0.008)
        # The brow over each eye, slight.
        f.ellipsoid((s * 0.028, 1.666, 0.088), (0.022, 0.0065, 0.012), k=0.016)
    # A thin, hooked nose.
    f.capsule((0, 1.66, 0.095), (0, 1.607, 0.119), 0.0058, 0.0078, k=0.012)
    f.ball((0, 1.606, 0.113), 0.0075, k=0.006)
    for s in (1, -1):
        f.ball((s * 0.0095, 1.604, 0.107), 0.0052, k=0.006)
    # The neck and its cords, as the body has them.
    f.capsule((0, 1.40, -0.006), (0, 1.585, 0.01), 0.038, 0.032, k=0.05)
    for s in (1, -1):
        f.capsule((s * 0.04, 1.585, -0.006), (s * 0.012, 1.432, 0.066), 0.0105, 0.009, k=0.01)
    # Cut away: the sockets, a shallow hollow round a deep almond of an eye; the temples; the cheeks under their bones.
    for s in (1, -1):
        f.ellipsoid((s * 0.029, 1.646, 0.098), (0.02, 0.014, 0.018), k=0.012, cut=True)
        f.ellipsoid((s * 0.029, 1.645, 0.088), (0.0145, 0.0072, 0.016), k=0.003, cut=True, R=rot_z(s * 0.12))
        f.ellipsoid((s * 0.066, 1.662, 0.034), (0.015, 0.024, 0.03), k=0.02, cut=True)
        f.ellipsoid((s * 0.043, 1.592, 0.078), (0.017, 0.02, 0.016), k=0.016, cut=True)
    # The groove of the mouth, from under one cheekbone to the other.
    pts = [mouth_point(u) for u in np.linspace(-1, 1, 13)]
    for a, b in zip(pts, pts[1:]):
        f.capsule(a, b, 0.0026, 0.0026, k=0.003, cut=True)
    f.plane_below(1.47)
    return f


MOUTH_HALF = 0.064


def mouth_y(x):
    u = x / MOUTH_HALF
    return 1.5775 - 0.003 * u * u


def mouth_point(u):
    """A point on the line of the mouth, u -1 (her right corner) to 1."""
    x = u * MOUTH_HALF
    # (round the face: further back at the corners)
    z = 0.091 - 0.05 * u * u - 0.008 * u ** 4
    return V(x, mouth_y(x), z)


def skin_colour(P, N, open_, head=False):
    """Ashen, sickly grey-green skin, filthy in the hollows and down low."""
    base = V(0.3, 0.3, 0.265)
    dirt = V(0.12, 0.11, 0.085)
    bruise = V(0.2, 0.18, 0.2)
    C = np.zeros((len(P), 4))
    rng = np.random.default_rng(5)
    blot = rng.uniform(0, 1, len(P))
    for i, p in enumerate(P):
        c = base * (0.9 + 0.2 * _noise3(p * 18.0))
        c = mix(c, dirt, (1 - open_[i]) * 0.75)
        # (grime down the trunk, and round the hands and wrists)
        c = mix(c, dirt, smooth(1.2, 0.95, p[1]) * 0.5)
        if not head:
            # (under the feathers, and over the wing's arm, dark down)
            under = max(feathered(p), smooth(0.24, 0.32, abs(p[0])) if p[1] > 1.3 else 0.0)
            c = mix(c, V(0.055, 0.052, 0.048), under)
        if head and (p[1] > 1.705 or (p[1] > 1.63 and p[2] < 0.02)):
            # (the scalp, under the hair: as dark as it)
            c = V(0.03, 0.029, 0.027)
        elif head:
            # (bruised round the eyes)
            for s in (1, -1):
                d = np.linalg.norm((p - V(s * 0.029, 1.643, 0.09)) / V(1, 1.2, 1))
                c = mix(c, bruise, smooth(0.03, 0.012, d) * 0.7)
        C[i, :3] = c
        C[i, 3] = open_[i]
    return C


def _noise3(p):
    return 0.5 + 0.25 * math.sin(p[0] * 1.7 + math.sin(p[1] * 2.3)) * math.cos(p[1] * 1.3 + p[2] * 2.1) + 0.25 * math.sin(p[2] * 3.1 + p[0] * 0.7)


def build_skin(model, low):
    print("skin: body field")
    f = body_field()
    h = 0.011 if low else 0.0075
    P, T = surface_nets(f, (-1.5, 0.32, -0.25), (1.5, 1.6, 0.2), h)
    print("  raw", len(P), len(T))
    P = f.project(P, 3)
    P, T = decimated(P, T, (3500 if low else 9000) / len(T))
    P = f.project(P, 3)
    N = norm_rows(f.gradient(P))
    open_ = f.occlusion(P, N, 0.012)
    print("  body", len(P), len(T))
    C = skin_colour(P, N, open_)
    W = skin_weights(P)
    # Where the skin is under feathers it is drawn as small shingled coverts (PLUMAGE,
    # by the shader): UV then runs across the rows (x) and along the way they lie (y,
    # in metres). Round the wing's arm the rows run along it, the feathers lying back
    # over the top and under it; on the body, round it, lying down it.
    UV0 = np.zeros((len(P), 2))
    UV1 = np.tile(V(SKIN, 0.3), (len(P), 1))
    for i, p in enumerate(P):
        x, y, z = p
        on_arm = abs(x) > 0.24 and y > 1.3
        under = max(feathered(p), smooth(0.24, 0.32, abs(x)) if y > 1.3 else 0.0)
        if on_arm:
            around = math.atan2(y - 1.425, z - arm_z(abs(x)) - 0.01)
            UV0[i] = (abs(x), (math.pi * 0.5 - abs(around)) * arm_radius(abs(x)) * 1.6)
        else:
            UV0[i] = (math.atan2(x, z + 0.03) * 0.11, -y)
        if under > 0.5:
            UV1[i] = (PLUMAGE, 0.3)
    model.add(P, T, N, C, UV0, UV1, W)
    model.body = f
    model.body_points = P
    model.body_normals = N
    model.body_weights = W

    print("skin: head field")
    hf = head_field()
    hh = 0.0042 if low else 0.003
    P, T = surface_nets(hf, (-0.11, 1.46, -0.12), (0.11, 1.78, 0.155), hh)
    P = hf.project(P, 3)
    P, T = decimated(P, T, (2200 if low else 6500) / len(T))
    P = hf.project(P, 3)
    P, T = cut_mouth(P, T)
    N = norm_rows(hf.gradient(P))
    open_ = hf.occlusion(P, N, 0.004)
    C = skin_colour(P, N, open_, head=True)
    W = head_weights(P)
    UV0 = np.stack([P[:, 0] * 8, P[:, 1] * 8], axis=1)
    UV1 = np.tile(V(SKIN, 0.7), (len(P), 1))
    model.add(P, T, N, C, UV0, UV1, W)
    model.head = hf
    print("  head", len(P), len(T))
    mouth_parts(model, low)


def norm_rows(G):
    return G / np.maximum(np.linalg.norm(G, axis=1), 1e-12)[:, None]


def lip_gap(x):
    u = min(1.0, abs(x) / MOUTH_HALF)
    return 0.0024 * (1.0 - u ** 3) + 0.0006


def cut_mouth(P, T):
    """Cuts the slit of the mouth out of the face (the faces whose middles are in it)."""
    mids = P[T].mean(axis=1)
    keep = []
    for i, m in enumerate(mids):
        x, y, z = m
        if abs(x) < MOUTH_HALF and z > 0.02 and abs(y - mouth_y(x)) < lip_gap(x):
            continue
        keep.append(i)
    T = T[keep]
    used = np.unique(T)
    remap = np.full(len(P), -1)
    remap[used] = np.arange(len(used))
    return P[used], remap[T]


def jaw_share(p):
    """How much of a point of the head the jaw carries."""
    x, y, z = p
    line = mouth_y(min(abs(x), MOUTH_HALF))
    # Beyond the corners, the line runs back and up to the hinge under the ear.
    corner = V(MOUTH_HALF, mouth_y(MOUTH_HALF), 0.035)
    hinge = V(0.058, 1.592, -0.004)
    if abs(x) > MOUTH_HALF * 0.85 or z < 0.035:
        t = np.clip((corner[2] - z) / (corner[2] - hinge[2]), 0.0, 1.0)
        line = corner[1] + (hinge[1] - corner[1]) * t
    below = smooth(0.003, -0.004, y - line)
    # (the throat under the jaw is shared with the neck)
    throat = smooth(1.555, 1.515, y) * smooth(0.03, -0.02, z)
    behind = smooth(-0.005, 0.02, z)
    return below * behind * (1.0 - 0.6 * throat)


def head_weights(P):
    W = []
    for p in P:
        j = jaw_share(p)
        neck = smooth(1.545, 1.49, p[1]) * (1.0 - smooth(0.0, 0.06, p[2]) * 0.5)
        w = {"jaw": j * (1 - neck), "head": (1 - j) * (1 - neck), "neck": neck}
        if neck > 0.5:
            w["chest"] = w.pop("neck") * smooth(1.5, 1.47, p[1])
            w["neck"] = neck - w["chest"]
        total = sum(w.values())
        W.append({k: v / total for k, v in w.items() if v / total > 0.01})
    return W


def ellipsoid_mesh(c, r, R=np.eye(3), seg=12, rings=8):
    P, T = [], []
    for i in range(rings + 1):
        th = math.pi * i / rings
        for k in range(seg):
            ph = math.tau * k / seg
            P.append(c + R @ (V(math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)) * r))
    for i in range(rings):
        for k in range(seg):
            a = i * seg + k
            b = i * seg + (k + 1) % seg
            c_ = (i + 1) * seg + (k + 1) % seg
            d = (i + 1) * seg + k
            T.append((a, d, c_))
            T.append((a, c_, b))
    P = np.array(P)
    T = np.array(T)
    return P, T


def mouth_parts(model, low):
    """Behind the slit: the mouth (dark, opening with the jaw), two rows of crowded teeth, a tongue; the eyes."""
    # The mouth: a dark pouch inside, its upper half carried by the head and its lower by the jaw.
    P, T = ellipsoid_mesh(V(0, 1.574, 0.036), V(0.05, 0.019, 0.042), seg=20, rings=10)
    T = T[:, ::-1]
    N = -vertex_normals(P, T[:, ::-1])
    C = np.tile(V(0.07, 0.02, 0.025, 0.3), (len(P), 1))
    W = []
    for p in P:
        j = smooth(1.578, 1.568, p[1])
        W.append({"jaw": j, "head": 1 - j} if 0 < j < 1 else ({"jaw": 1.0} if j >= 1 else {"head": 1.0}))
    model.add(P, T, N, C, np.zeros((len(P), 2)), np.tile(V(MOUTH, 0.5), (len(P), 1)), W)
    # Tongue.
    P, T = ellipsoid_mesh(V(0, 1.564, 0.035), V(0.026, 0.006, 0.036), seg=12, rings=6)
    model.add(P, T, vertex_normals(P, T), np.tile(V(0.16, 0.06, 0.06, 0.5), (len(P), 1)), np.zeros((len(P), 2)),
              np.tile(V(MOUTH, 0.8), (len(P), 1)), [{"jaw": 1.0}] * len(P))
    # Teeth: thin, long and crowded, a row along each lip, set in from it.
    count = 18 if low else 30
    for row, (bone, down) in enumerate((("head", -1.0), ("jaw", 1.0))):
        for k in range(count):
            u = mix(-0.88, 0.88, (k + 0.5) / count)
            base = mouth_point(u) + V(0, -down * 0.0045, -0.006)
            out = norm(V(u * 0.6, 0.0, 1.0))
            length = (0.009 + 0.004 * math.sin(k * 2.7) ** 2) * (1.0 - 0.45 * abs(u))
            tip = base + V(0, down * length, 0) + out * 0.0015
            Pc, Tc = cone(base, tip, 0.0019 * (1.0 - 0.4 * abs(u)), 4)
            model.add(Pc, Tc, vertex_normals(Pc, Tc), np.tile(V(0.42, 0.38, 0.28, 1.0), (len(Pc), 1)), np.zeros((len(Pc), 2)),
                      np.tile(V(TEETH, k / count), (len(Pc), 1)), [{bone: 1.0}] * len(Pc))
    # The eyes: small, milky, deep in their sockets; a pupil like a pinhole.
    for s in (1, -1):
        c = V(s * 0.029, 1.645, 0.067)
        P, T = ellipsoid_mesh(c, V(0.0095, 0.0095, 0.0095), seg=12, rings=8)
        C = []
        for p in P:
            front = (p - c)[2] / 0.0095
            pupil = smooth(0.93, 0.97, front)
            C.append(np.concatenate([mix(V(0.36, 0.35, 0.31), V(0.05, 0.05, 0.045), pupil), [1.0]]))
        model.add(P, T, vertex_normals(P, T), C, np.zeros((len(P), 2)), np.tile(V(EYE, 0.5), (len(P), 1)), [{"head": 1.0}] * len(P))


def cone(base, tip, radius, sides=6):
    axis = norm(tip - base)
    a = norm(np.cross(axis, V(0, 1, 0)) if abs(axis[1]) < 0.9 else np.cross(axis, V(1, 0, 0)))
    b = np.cross(axis, a)
    P = [base + (a * math.cos(t) + b * math.sin(t)) * radius for t in [math.tau * k / sides for k in range(sides)]]
    P.append(tip)
    P = np.array(P)
    T = [(k, (k + 1) % sides, sides) for k in range(sides)]
    return P, np.array(T)


# ---------------------------------------------------------------------------
# Tubes (legs, toes, talons, claws, hair)

def tube(centres, radii, sides, flat=None, ups=None, close_end=True, close_start=False):
    """A tube through `centres` with (rx, ry) radii at each (ry across `ups`); returns P, T, and per vertex (along, round)."""
    n = len(centres)
    P, UV = [], []
    lengths = [0.0]
    for i in range(1, n):
        lengths.append(lengths[-1] + np.linalg.norm(centres[i] - centres[i - 1]))
    total = max(lengths[-1], 1e-9)
    prev_up = None
    for i in range(n):
        if i == 0:
            t = centres[1] - centres[0]
        elif i == n - 1:
            t = centres[-1] - centres[-2]
        else:
            t = centres[i + 1] - centres[i - 1]
        t = norm(t)
        up = ups[i] if ups is not None else (prev_up if prev_up is not None else (V(0, 1, 0) if abs(t[1]) < 0.9 else V(0, 0, 1)))
        up = norm(up - t * (up @ t))
        prev_up = up
        side = np.cross(t, up)
        rx, ry = radii[i] if hasattr(radii[i], "__len__") else (radii[i], radii[i])
        for k in range(sides):
            a = math.tau * k / sides
            P.append(centres[i] + side * math.cos(a) * rx + up * math.sin(a) * ry)
            UV.append((lengths[i] / total, k / sides))
    T = []
    for i in range(n - 1):
        for k in range(sides):
            a = i * sides + k
            b = i * sides + (k + 1) % sides
            c = (i + 1) * sides + (k + 1) % sides
            d = (i + 1) * sides + k
            T.append((a, b, c))
            T.append((a, c, d))
    if close_end:
        P.append(centres[-1] + norm(centres[-1] - centres[-2]) * 0.0005)
        UV.append((1.0, 0.0))
        e = len(P) - 1
        for k in range(sides):
            T.append(((n - 1) * sides + k, (n - 1) * sides + (k + 1) % sides, e))
    if close_start:
        P.append(centres[0] - norm(centres[1] - centres[0]) * 0.0005)
        UV.append((0.0, 0.0))
        e = len(P) - 1
        for k in range(sides):
            T.append(((k + 1) % sides, k, e))
    return np.array(P), np.array(T), np.array(UV)


def bezier(points, count):
    """Points along a Catmull-Rom curve through `points`."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    segs = len(points) - 1
    for i in range(count):
        u = i / (count - 1) * segs
        j = min(int(u), segs - 1)
        t = u - j
        p0, p1, p2, p3 = pts[j], pts[j + 1], pts[j + 2], pts[j + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    return out


def horn(model, root, forward, down, length, radius, curl, weights, sides=6, rings=8, colour=V(0.02, 0.018, 0.016)):
    """A hooked talon or claw: from `root` along `forward`, curling round towards `down` by `curl` radians."""
    forward = norm(forward)
    down = norm(down - forward * (down @ forward))
    R = length / max(curl, 1e-3)
    centres, radii = [], []
    for i in range(rings):
        u = i / (rings - 1)
        a = curl * u
        centres.append(root + forward * math.sin(a) * R + down * (1 - math.cos(a)) * R)
        r = radius * (1 - u) ** 0.8 + 0.0004
        radii.append((r * 0.85, r))
    ups = [-down] * rings
    P, T, UV = tube(centres, radii, sides, ups=ups)
    C = np.tile(np.concatenate([colour, [1.0]]), (len(P), 1))
    model.add(P, T, vertex_normals(P, T), C, UV, np.tile(V(HORN, 0.5), (len(P), 1)), [weights] * len(P))


def build_legs(model, low):
    sides = 8 if low else 12
    for side in ("l", "r"):
        mirror = side == "r"
        # The tarsus: thick, scaly, a knob at the joint above it.
        centres = bezier([ANKLE + V(0, 0.01, 0), ANKLE + V(0, -0.08, 0.012), FOOT + V(0, 0.1, -0.005), FOOT + V(0, 0.005, 0.0)], 10 if low else 16)
        radii = []
        for i, c in enumerate(centres):
            u = i / (len(centres) - 1)
            r = mix(0.029, 0.021, u) + 0.006 * math.exp(-((u - 0.02) / 0.06) ** 2) + 0.004 * math.exp(-((u - 0.97) / 0.05) ** 2)
            radii.append((r, r * 1.08))
        P, T, UV = tube(centres, radii, sides, ups=[V(0, 0, 1)] * len(centres))
        W = []
        for p in P:
            u = np.clip((ANKLE[1] - p[1]) / (ANKLE[1] - FOOT[1]), 0, 1)
            knee = smooth(0.08, 0.0, u)
            foot = smooth(0.88, 1.0, u)
            w = {"tarsus_l": 1.0 - knee * 0.5}
            if knee > 0:
                w["shin_l"] = knee * 0.5
            total = sum(w.values())
            W.append({k: v / total for k, v in w.items()})
        C = leg_colour(P)
        model.add(P, T, vertex_normals(P, T), C, UV * V(4.0, 1.0), np.tile(V(SCALES, 0.2), (len(P), 1)), W, mirror)
        # The toes, each two joints, with pads under them.
        for t, (base, joint, tip) in TOES.items():
            pts = bezier([base + V(0, 0.01, 0), joint, tip], 8 if low else 12)
            radii = []
            for i, c in enumerate(pts):
                u = i / (len(pts) - 1)
                r = mix(0.016, 0.0095, u) * (1.0 + 0.18 * math.sin(u * math.pi * 2) ** 2)
                radii.append((r, r * 0.9))
            P, T, UV = tube(pts, radii, 8 if low else 10, close_start=True)
            W = []
            seg_a = (base, joint)
            for p in P:
                da = segment_distance(p[None], base, joint)[0]
                db = segment_distance(p[None], joint, tip)[0]
                wa = 1 / (da ** 4 + 1e-12)
                wb = 1 / (db ** 4 + 1e-12)
                W.append({"toe%da_l" % t: wa / (wa + wb), "toe%db_l" % t: wb / (wa + wb)})
            model.add(P, T, vertex_normals(P, T), leg_colour(P), UV * V(2.0, 1.0), np.tile(V(SCALES, 0.6), (len(P), 1)), W, mirror)
            # The talon, long and hooked.
            forward = norm(tip - joint)
            root = tip - forward * 0.004 + V(0, 0.002, 0)
            ws = {"toe%db_l" % t: 1.0}
            if mirror:
                pass
            horn_part = Model()
            horn(horn_part, root, forward, V(0, -1, 0), TALONS[t], 0.0085 if t == 1 else 0.0072, 2.0, ws, 6 if low else 8, 8 if low else 10)
            _merge(model, horn_part, mirror)


def _merge(model, part, mirror):
    for i in range(len(part.P)):
        n = len(part.P[i])
        model.add(part.P[i], part.T[i] - (sum(len(p) for p in part.P[:i])), part.N[i], part.C[i], part.UV0[i], part.UV1[i],
                  part.W[sum(len(p) for p in part.P[:i]): sum(len(p) for p in part.P[:i]) + n], mirror)


def leg_colour(P):
    C = np.zeros((len(P), 4))
    for i, p in enumerate(P):
        c = mix(V(0.17, 0.16, 0.11), V(0.23, 0.21, 0.14), _noise3(p * 40.0))
        c = mix(c, V(0.08, 0.07, 0.05), smooth(0.12, 0.0, p[1]) * 0.55)
        C[i] = np.concatenate([c, [1.0]])
    return C


# ---------------------------------------------------------------------------
# Feathers

class Plume:
    """How one feather is made."""

    def __init__(self, length, lead, trail, rings=8, across=2, quill=0.08, camber=0.06, sweep=0.0, lift=0.0, tip="round",
                 emarg=None, notches=0, tone=None, kind=FEATHER, curl=0.0, fray=0.0):
        self.length, self.lead, self.trail = length, lead, trail
        self.rings, self.across, self.quill = rings, across, quill
        self.camber, self.sweep, self.lift, self.tip = camber, sweep, lift, tip
        self.emarg, self.notches, self.tone, self.kind, self.curl, self.fray = emarg, notches, tone, kind, curl, fray


FEATHER_DARK = V(0.06, 0.057, 0.053)
FEATHER_GREY = V(0.13, 0.125, 0.118)
FEATHER_EDGE = V(0.2, 0.19, 0.175)
FEATHER_FILTH = V(0.1, 0.08, 0.055)


def feather(model, rng, root, along, up, plume, weights, mirror=False, under=False):
    """One feather card from `root`, pointing `along`, its top facing `up`; `weights` its bones."""
    along = norm(V(along))
    up = norm(V(up) - along * (V(up) @ along))
    side = np.cross(up, along)  # (on the left wing: the trailing side)
    if plume.lift:
        along2 = norm(along * math.cos(plume.lift) + up * math.sin(plume.lift))
        up = norm(np.cross(along2, side))
        along = along2
    L = plume.length
    rings = plume.rings
    # Notches: (where, how wide, how deep, which side)
    notches = [(rng.uniform(0.3, 0.92), rng.uniform(0.015, 0.05), rng.uniform(0.35, 0.9), rng.choice((-1, 1))) for _ in range(plume.notches)]
    ss = sorted(set([0.0, plume.quill * 0.5, plume.quill] + [mix(plume.quill, 1.0, (i / (rings - 1)) ** 0.9) for i in range(rings)]))
    ts = np.linspace(-1, 1, 2 * plume.across + 1)
    tone = plume.tone if plume.tone is not None else feather_tone(rng)
    worn = rng.uniform(0.0, 1.0)
    filth_at = rng.uniform(0.1, 0.7)
    seed = rng.uniform(0, 1)
    P, C, UV, NN = [], [], [], []
    for s in ss:
        c = root + along * L * s - up * plume.camber * L * s * s + side * plume.sweep * L * s * s
        width = smooth(plume.quill * 0.6, plume.quill + 0.12, s)
        if plume.tip == "round":
            tipw = math.sqrt(max(0.0, 1.0 - ((max(s, 0.72) - 0.72) / 0.28) ** 2))
        else:
            tipw = max(0.0, min(1.0, (1.0 - s) / 0.35))
        width *= tipw * (1.0 - 0.18 * s)
        lead = plume.lead * width + 0.0012
        trail = plume.trail * width + 0.0012
        if plume.emarg is not None:
            e = plume.emarg
            lead *= mix(1.0, 0.32, smooth(e, e + 0.08, s))
            trail *= mix(1.0, 0.5, smooth(e + 0.05, e + 0.14, s))
        for (sn, ds, depth, which) in notches:
            cut = 1.0 - depth * math.exp(-((s - sn) / ds) ** 2)
            if which < 0:
                lead *= cut
            else:
                trail *= cut
        for t in ts:
            w = trail if t > 0 else lead
            lift = (0.16 * (1 - abs(t)) - 0.1 * t * t) * (plume.lead + plume.trail) * 0.5 * width
            curl = plume.curl * t * t * w
            p = c + side * t * w + up * (lift - curl)
            # (the tip frays out past the vane at the rachis)
            if s >= 0.999 and abs(t) < 0.01:
                p = p + along * L * 0.02
            P.append(p)
            n = norm(up + side * (0.25 * t + 0.6 * plume.curl * t))
            NN.append(n)
            col = tone
            col = mix(col, FEATHER_EDGE, smooth(0.55, 1.0, abs(t)) * (0.25 + 0.45 * worn))
            col = mix(col, FEATHER_EDGE * 1.1, smooth(0.75, 1.0, s) * worn * 0.6)
            col = mix(col, FEATHER_FILTH, math.exp(-((s - filth_at) / 0.15) ** 2) * 0.5 * (1 - abs(t) * 0.5))
            col = mix(col, V(0.2, 0.19, 0.17), (1 - smooth(0.0, 0.2, abs(t))) * 0.35)
            if s < plume.quill:
                col = V(0.22, 0.21, 0.2)
            C.append(np.concatenate([col, [1.0]]))
            UV.append((s, t))
    n_across = len(ts)
    T = []
    for i in range(len(ss) - 1):
        for k in range(n_across - 1):
            a = i * n_across + k
            b = a + 1
            c = a + n_across + 1
            d = a + n_across
            T.append((a, d, c))
            T.append((a, c, b))
    T = np.array(T)
    # (wound so that the front faces `up`)
    P = np.array(P)
    fn = np.cross(P[T[0, 1]] - P[T[0, 0]], P[T[0, 2]] - P[T[0, 0]])
    if fn @ up < 0:
        T = T[:, ::-1]
    UV1 = np.tile(V(plume.kind, seed), (len(P), 1))
    model.add(P, T, NN, C, UV, UV1, [weights] * len(P), mirror)


def feather_tone(rng):
    k = rng.uniform(0, 1)
    tone = mix(FEATHER_DARK, FEATHER_GREY, k ** 1.5)
    # (some browner, some greyer)
    return tone * V(1.0 + rng.uniform(-0.04, 0.08), 1.0, 1.0 - rng.uniform(0.0, 0.08))


def build_wings(model, low):
    for side in ("l", "r"):
        rng = random.Random(41 if side == "l" else 77)
        mirror = side == "r"
        L = lambda name: name + "_l"
        rings_big = 9 if low else 15
        rings_mid = 5 if low else 7
        rings_small = 3 if low else 4
        across_big = 1 if low else 2
        # Primaries.
        for i, (root, angle, length, parent) in enumerate(primaries()):
            n = i + 1
            d = V(math.cos(angle), 0.0, -math.sin(angle))
            rank = 10 - i  # (P10 lowest, the inner ones over them)
            r = root + V(0, 0.0013 * rank, 0)
            plume = Plume(length, 0.026 if n >= 6 else 0.03, 0.05 if n >= 6 else 0.056, rings=rings_big, across=across_big, quill=0.07,
                          camber=0.05, sweep=0.04 + 0.01 * (n >= 7), emarg=(0.48 if n >= 7 else 0.6) if n >= 6 else None,
                          notches=rng.choice((0, 1, 1, 2, 3)), curl=0.06)
            if side == "l" and n == 4:
                # (moulting: a half-grown pin feather where P4 was)
                plume = Plume(length * 0.42, 0.012, 0.024, rings=rings_mid, across=1, quill=0.3, camber=0.02, tip="point")
            if side == "r" and n == 8:
                # (broken off)
                plume.length *= 0.8
                plume.tip = "point"
                plume.notches = 3
            feather(model, rng, r, d, V(0, 1, 0), plume, {L("p%d" % n): 1.0}, mirror)
            # Its covert, over its root.
            if rng.random() > 0.12:
                cov = Plume(0.15 + 0.01 * rng.random(), 0.02, 0.032, rings=rings_mid, across=1, quill=0.06, camber=0.08, notches=rng.choice((0, 1)))
                feather(model, rng, r + V(0, 0.022, 0.012), d, V(0, 1, 0), cov, {L("p%d" % n): 0.5, L(parent): 0.5}, mirror)
            # And under it.
            if rng.random() > 0.15:
                cov = Plume(0.12, 0.018, 0.026, rings=rings_small, across=1, quill=0.05, camber=0.08, tone=mix(feather_tone(rng), FEATHER_EDGE, 0.5))
                feather(model, rng, r + V(0, -0.02, 0.01), d, V(0, -1, 0), cov, {L("p%d" % n): 0.5, L(parent): 0.5}, mirror, under=True)
        # Secondaries and tertials.
        secs = secondaries()
        for i, (root, angle, length, g) in enumerate(secs):
            n = i + 1
            if side == "r" and n == 6:
                continue  # (moulted)
            d = V(math.cos(angle), 0.0, -math.sin(angle))
            rank = 11 + i
            r = root + V(0, 0.0013 * rank, 0)
            k = i % 3
            weights = {L("sec%d" % g): 1.0}
            if k == 0 and g > 1:
                weights = {L("sec%d" % g): 0.7, L("sec%d" % (g - 1)): 0.3}
            elif k == 2 and g < 4:
                weights = {L("sec%d" % g): 0.7, L("sec%d" % (g + 1)): 0.3}
            plume = Plume(length * rng.uniform(0.96, 1.02), 0.028, 0.048 if g < 4 else 0.055, rings=rings_big, across=across_big, quill=0.07,
                          camber=0.05, sweep=-0.02, notches=rng.choice((0, 1, 1, 2)), curl=0.05)
            feather(model, rng, r, d, V(0, 1, 0), plume, weights, mirror)
            # Greater covert over it, and an under-wing covert under it.
            if rng.random() > 0.1:
                cov = Plume(0.165 + 0.02 * rng.random(), 0.022, 0.034, rings=rings_mid, across=1, quill=0.06, camber=0.09, notches=rng.choice((0, 0, 1)))
                feather(model, rng, r + V(0, 0.03, 0.016), d, V(0, 1, 0), cov, dict({L("forearm"): 0.5}, **{k2: v * 0.5 for k2, v in weights.items()}), mirror)
            if rng.random() > 0.1:
                cov = Plume(0.15, 0.022, 0.03, rings=rings_small, across=1, quill=0.05, camber=0.08, tone=mix(feather_tone(rng), FEATHER_EDGE, 0.55))
                feather(model, rng, r + V(0, -0.024, 0.014), d, V(0, -1, 0), cov, {L("forearm"): 1.0}, mirror, under=True)
        # Humeral feathers behind the upper arm, down to the body.
        for i in range(6 if low else 8):
            u = i / (5 if low else 7)
            x = mix(0.555, 0.2, u)
            angle = math.radians(mix(100, 112, u))
            d = V(math.cos(angle), 0.0, -math.sin(angle))
            r = V(x, 1.43 + 0.0013 * (24 + i), arm_z(x) - 0.02)
            share = smooth(0.18, 0.32, x)
            plume = Plume(mix(0.36, 0.2, u), 0.03, 0.05, rings=rings_mid + 2, across=across_big, quill=0.06, camber=0.05, notches=rng.choice((0, 1, 2)))
            feather(model, rng, r, d, V(0, 1, 0), plume, {L("humerus"): share, "chest": 1 - share} if share < 1 else {L("humerus"): 1.0}, mirror)
        # Median and lesser coverts: rows of small feathers over the arm and the hand, shingled back.
        rows = [(0.03, 0.105, 0.6), (0.045, 0.075, 0.75), (0.058, 0.055, 0.9)] if not low else [(0.035, 0.1, 0.65), (0.055, 0.065, 0.9)]
        for row, (forward, size, over) in enumerate(rows):
            x = 0.25
            while x < 1.34:
                step = size * (0.42 if not low else 0.6)
                if rng.random() < 0.08:
                    x += step
                    continue  # (gaps where they have fallen)
                top = model.body.surface_point(V(x, 1.6, arm_z(x) + forward * over - 0.01), (0, -1, 0))
                if top is None:
                    x += step
                    continue
                angle = math.radians(rng.uniform(80, 98))
                d = V(math.cos(angle), 0.0, -math.sin(angle))
                plume = Plume(size * rng.uniform(0.85, 1.15) * (0.75 if x > 1.03 else 1.0), 0.03 * size / 0.1, 0.04 * size / 0.1, rings=rings_small, across=1,
                              quill=0.0, camber=0.15, lift=0.2, notches=0 if rng.random() < 0.7 else 1)
                bone = L("humerus") if x < ELBOW[0] else (L("forearm") if x < WRIST[0] else L("hand"))
                feather(model, rng, top - V(0, 0.002, 0), d, V(0, 1, 0), plume, _arm_weights(x, side), mirror)
                x += step
        # Marginal coverts, small and close, wrapped over the leading edge and under it.
        x = 0.24
        while x < 1.36:
            step = 0.022 if not low else 0.034
            edge = model.body.surface_point(V(x, 1.425 + rng.uniform(-0.004, 0.004), 0.25), (0, 0, -1))
            if edge is not None and rng.random() > 0.05:
                for k, (lift, up) in enumerate(((0.55, 1.0), (-0.45, -1.0))):
                    if low and k == 1:
                        continue
                    d = norm(V(rng.uniform(-0.1, 0.25), lift, -1.0))
                    u = norm(V(0, up, 0.5 * up * 0 + 0.55))
                    u = norm(V(0, 1.0, 0.6)) if up > 0 else norm(V(0, -1.0, 0.6))
                    size = rng.uniform(0.04, 0.06) * (0.8 if x > 1.03 else 1.0)
                    plume = Plume(size, 0.013, 0.015, rings=3, across=1, quill=0.0, camber=0.2, tip="round")
                    feather(model, rng, edge + V(0, 0.004 * up, -0.003), d, u, plume, _arm_weights(x, side), mirror)
            x += step
        # Under the arm: two rows of pale coverts.
        for row in range(2):
            x = 0.24
            size = 0.12 if row == 0 else 0.08
            while x < 1.25:
                bottom = model.body.surface_point(V(x, 1.25, arm_z(x) - 0.005 + row * 0.025), (0, 1, 0))
                if bottom is not None and rng.random() > 0.08:
                    angle = math.radians(rng.uniform(85, 100))
                    d = V(math.cos(angle), 0.0, -math.sin(angle))
                    plume = Plume(size * rng.uniform(0.9, 1.15), 0.035 * size / 0.1, 0.045 * size / 0.1, rings=rings_small, across=1, quill=0.06,
                                  camber=0.1, lift=0.15, tone=mix(feather_tone(rng), FEATHER_EDGE, 0.6))
                    feather(model, rng, bottom + V(0, 0.002, 0), d, V(0, -1, 0), plume, _arm_weights(x, side), mirror, under=True)
                x += size * (0.5 if not low else 0.7)
        # The alula, at the wrist, along the leading edge.
        for k in range(3):
            r = WRIST + V(0.012 + 0.012 * k, 0.03 + 0.003 * k, 0.018 - 0.004 * k)
            d = norm(V(1.0, 0.0, 0.12 - 0.05 * k))
            plume = Plume(0.11 + 0.025 * k, 0.012, 0.026, rings=rings_mid, across=1, quill=0.08, camber=0.04, notches=1 if k == 1 else 0)
            feather(model, rng, r, d, V(0, 1, 0), plume, {L("hand"): 1.0}, mirror)
        # Scapulars, over the shoulder, back along the body.
        for k in range(5 if low else 8):
            u = k / (4 if low else 7)
            x = mix(0.07, 0.24, u)
            top = model.body.surface_point(V(x, 1.6, -0.05 - 0.02 * u), (0, -1, 0))
            if top is None:
                continue
            angle = math.radians(mix(96, 112, u) + rng.uniform(-5, 5))
            d = norm(V(math.cos(angle), -0.12, -math.sin(angle)))
            plume = Plume(mix(0.2, 0.27, u) * rng.uniform(0.9, 1.1), 0.032, 0.045, rings=rings_mid, across=1, quill=0.06, camber=0.1, lift=0.15,
                          notches=rng.choice((0, 1, 2)))
            share = smooth(0.08, 0.2, x)
            feather(model, rng, top - V(0, 0.004, 0), d, V(0, 1, 0), plume, {L("humerus"): share * 0.6, L("clavicle"): share * 0.4 + (1 - share) * 0.3, "chest": (1 - share) * 0.7}, mirror)
        # What is left of a hand at the wrist: three bony fingers with hooked claws.
        claws = Model()
        base = WRIST + V(0.008, 0.004, 0.026)
        for k in range(3):
            spread = (k - 1) * 0.35
            d = norm(V(0.75, -0.25 - 0.1 * k, 0.6) @ rot_y(spread).T)
            knuckle = base + V(0.0, -0.004 * k, -0.006 * k)
            mid = knuckle + d * (0.045 - 0.006 * k)
            d2 = norm(d + V(0, -0.5, 0))
            end = mid + d2 * (0.035 - 0.004 * k)
            pts = bezier([knuckle, mid, end], 7 if low else 10)
            radii = [mix(0.0075, 0.0045, i / (len(pts) - 1)) * (1 + 0.25 * math.exp(-((i / (len(pts) - 1) - 0.5) / 0.08) ** 2)) for i in range(len(pts))]
            P, T, UV = tube(pts, radii, 6 if low else 8, close_start=True)
            C = np.tile(V(0.2, 0.19, 0.16, 0.8), (len(P), 1))
            claws.add(P, T, vertex_normals(P, T), C, UV, np.tile(V(SKIN, 0.9), (len(P), 1)), [{L("claws"): 1.0}] * len(P))
            horn(claws, end - d2 * 0.002, d2, V(0, -1, 0.2), 0.04 - 0.004 * k, 0.0055, 2.1, {L("claws"): 1.0}, 6, 7 if low else 9)
        _merge(model, claws, mirror)


def _arm_weights(x, side):
    """Weights along the arm at a distance out, blended at the joints."""
    names = ["humerus_l", "forearm_l", "hand_l", "finger_l"]
    joints = [SHOULDER[0], ELBOW[0], WRIST[0], KNUCKLE[0], FINGERTIP[0]]
    w = {}
    for i, n in enumerate(names):
        a, b = joints[i], joints[i + 1]
        if x < a - 0.04 or x > b + 0.04:
            continue
        inside = smooth(a - 0.04, a + 0.04, x) * (1.0 - smooth(b - 0.04, b + 0.04, x))
        if i == 0:
            inside = 1.0 - smooth(b - 0.04, b + 0.04, x)
        if i == len(names) - 1:
            inside = smooth(a - 0.04, a + 0.04, x)
        if inside > 0.001:
            w[n] = inside
    if x < 0.3:
        w["chest"] = 1.0 - smooth(0.2, 0.3, x)
    total = sum(w.values()) or 1.0
    return {k: v / total for k, v in w.items()}


def build_tail(model, low):
    rng = random.Random(9)
    count = 12
    for i in range(count):
        u = (i + 0.5) / count * 2 - 1  # -1 her right .. 1 her left
        angle = u * math.radians(26)
        d = V(math.sin(angle), -0.12, -math.cos(angle))
        rank = 6 - abs(i - 5.5)
        root = V(u * 0.045, 0.902 + 0.0018 * rank, -0.2)
        length = mix(0.5, 0.44, abs(u)) * rng.uniform(0.85, 1.0)
        plume = Plume(length, 0.03, 0.03, rings=11 if not low else 7, across=2 if not low else 1, quill=0.06, camber=0.04,
                      notches=rng.choice((0, 1, 2, 3)), curl=0.04)
        wl = smooth(-0.6, 0.6, u)
        feather(model, rng, root, d, V(0, 1, 0.12), plume, {"tail_l": wl, "tail_r": 1 - wl} if 0.0 < wl < 1.0 else ({"tail_l": 1.0} if wl >= 1 else {"tail_r": 1.0}))
    # Coverts over and under it.
    for i in range(10 if not low else 6):
        u = (i + 0.5) / (10 if not low else 6) * 2 - 1
        angle = u * math.radians(30)
        for under in (False, True):
            if rng.random() < 0.15:
                continue
            d = V(math.sin(angle), -0.08, -math.cos(angle))
            root = V(u * 0.05, 0.93 if not under else 0.875, -0.17)
            plume = Plume(rng.uniform(0.17, 0.24), 0.03, 0.03, rings=5, across=1, quill=0.06, camber=0.08,
                          tone=mix(feather_tone(rng), FEATHER_EDGE, 0.5 if under else 0.0))
            feather(model, rng, root, d, V(0, -1 if under else 1, 0), plume, {"tail": 1.0}, under=under)


def feathered(p):
    """How thick the body's feathers are at a point of the skin (0 bare skin), and how long."""
    x, y, z = p
    # The line where feathers begin on the trunk: under the ribs in front, higher behind.
    front = smooth(-0.02, 0.08, z)
    line = mix(1.215, 1.15, front) + 0.03 * math.sin(x * 40.0) + 0.02 * math.sin(x * 17 + z * 23)
    trunk = smooth(line + 0.015, line - 0.02, y)
    # The mantle: a shaggy ruff over the shoulders and the upper back, up the back of the neck.
    behind = smooth(0.0, -0.05, z)
    ruff = smooth(1.3, 1.36, y) * smooth(1.55, 1.48, y) * behind * smooth(0.03, 0.09, abs(x) + (1.5 - y) * 0.2)
    shoulder = smooth(1.37, 1.41, y) * smooth(1.5, 1.45, y) * smooth(0.11, 0.17, abs(x)) * smooth(0.27, 0.2, abs(x))
    cover = max(trunk, ruff, shoulder)
    if abs(x) > 0.23 and y > 1.3:
        cover = 0.0  # (the arm: its own coverts)
    if y < 0.37:
        cover = 0.0  # (the bare tarsus)
    return cover


def build_body_feathers(model, low):
    rng = random.Random(23)
    P = model.body_points
    N = model.body_normals
    W = model.body_weights
    order = list(range(len(P)))
    rng.shuffle(order)
    spacing = 0.04 if low else 0.022
    grid = {}
    placed = 0

    def key(p):
        return (int(p[0] // spacing), int(p[1] // spacing), int(p[2] // spacing))

    for i in order:
        p = P[i]
        cover = feathered(p)
        if cover < 0.5:
            continue
        # (bare patches, where she is moulting)
        if _noise3(p * 9.0 + V(3, 1, 2)) < 0.27 and 0.5 < p[1] < 1.3:
            continue
        k = key(p)
        near = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for q in grid.get((k[0] + dx, k[1] + dy, k[2] + dz), []):
                        if np.linalg.norm(q - p) < spacing:
                            near = True
                            break
        if near:
            continue
        grid.setdefault(k, []).append(p)
        n = N[i]
        x, y, z = p
        leg = y < 0.93 and abs(x) > 0.06 and z > -0.12
        # Which way it lies: down the body (and back, on the trunk), along the surface.
        down = V(0, -1, 0) if leg else norm(V(0.0, -1.0, -0.35 if z < 0 else -0.1))
        if y > 1.28:
            down = norm(V(math.copysign(0.3, x), -1.0, -0.7))
        flat = down - n * (down @ n)
        d = norm(flat) if np.linalg.norm(flat) > 0.1 else norm(np.cross(n, V(1, 0, 0)))
        d = norm(d @ rot_axis(n, rng.uniform(-0.3, 0.3)).T)
        if leg:
            # (long ragged trousers, longest at the shin, hanging over the ankle)
            length = mix(0.08, 0.17, smooth(0.85, 0.42, y)) * rng.uniform(0.75, 1.2)
        elif y > 1.28:
            length = rng.uniform(0.1, 0.19)
        else:
            length = rng.uniform(0.065, 0.11) * (1.3 if z < -0.1 else 1.0)
        width = 0.095 * length + 0.004
        plume = Plume(length, width, width, rings=3 if low else 4, across=1, quill=0.0, camber=0.14, lift=0.2,
                      notches=0 if rng.random() < 0.55 else 1, tip="point" if rng.random() < 0.6 else "round", curl=0.15)
        weights = W[i]
        plume.tone = feather_tone(rng) * 0.8
        feather(model, rng, p - n * 0.004, d, n, plume, weights)
        # (bend its normals out from the body, so the plumage shades as one mass)
        model.N[-1] = norm_rows(model.N[-1] * 0.4 + n[None, :] * 0.6)
        placed += 1
        # Now and then a pin feather pushing through.
        if rng.random() < 0.04:
            Pc, Tc = cone(p - n * 0.002, p + n * 0.006 + d * 0.025, 0.0028, 4)
            model.add(Pc, Tc, vertex_normals(Pc, Tc), np.tile(V(0.18, 0.18, 0.2, 1.0), (len(Pc), 1)), np.zeros((len(Pc), 2)),
                      np.tile(V(FEATHER, 0.5), (len(Pc), 1)), [weights] * len(Pc))
    print("body feathers", placed)


# ---------------------------------------------------------------------------
# Hair

def hair_field():
    """A rough body for the hair to fall over: the head as it is, and a plain trunk."""
    f = head_field()
    f.parts = [part for part in f.parts if part[0] != "below"]
    f.ellipsoid((0, 1.275, -0.008), (0.135, 0.17, 0.108), k=0.04, R=rot_x(-0.08))
    f.capsule((-0.17, 1.425, -0.022), (0.17, 1.425, -0.022), 0.05, k=0.05)
    f.ellipsoid((0, 1.36, 0.02), (0.125, 0.07, 0.078), k=0.04)
    for s in (1, -1):
        f.capsule((s * 0.025, 1.52, -0.028), (s * 0.15, 1.432, -0.036), 0.024, 0.03, k=0.04)
        f.capsule((s * 0.17, 1.425, -0.02), (s * 0.5, 1.425, -0.04), 0.05, 0.035, k=0.03)
    return f


def ribbon(pts, widths, outs):
    """A flat strip through `pts`, `widths` wide, facing `outs`, with a raised middle: P, T, UV."""
    P, UV = [], []
    n = len(pts)
    total = sum(np.linalg.norm(pts[i + 1] - pts[i]) for i in range(n - 1)) or 1.0
    run = 0.0
    for i in range(n):
        t = norm(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        out = norm(outs[i] - t * (outs[i] @ t))
        side = norm(np.cross(t, out))
        if i > 0:
            run += np.linalg.norm(pts[i] - pts[i - 1])
        w = widths[i]
        for k, a in enumerate((-1.0, 0.0, 1.0)):
            P.append(pts[i] + side * a * w + out * (0.3 * w if a == 0 else 0.0))
            UV.append((run / total, a))
    T = []
    for i in range(n - 1):
        for k in range(2):
            a = i * 3 + k
            T.append((a, a + 3, a + 4))
            T.append((a, a + 4, a + 1))
    return np.array(P), np.array(T), np.array(UV)


def build_hair(model, low):
    rng = random.Random(3)
    head = model.head
    both = hair_field()
    centre = V(0, 1.66, 0.0)
    strands = []
    # Roots over the scalp, the hairline high on the forehead.
    count = 70 if low else 170
    tries = 0
    while len(strands) < count and tries < count * 6:
        tries += 1
        a = rng.uniform(-math.pi, math.pi)  # 0: straight forward
        lift = rng.uniform(0.1, 1.45)
        out = norm(V(math.sin(a) * math.cos(lift), math.sin(lift), math.cos(a) * math.cos(lift)))
        root = head.surface_point(centre + out * 0.2, -out)
        if root is None or root[1] < 1.61:
            continue
        if abs(a) < 1.0 and root[1] < 1.7:
            continue
        strands.append((root, a))
    step = 0.04 if low else 0.024
    for root, a in strands:
        front = math.cos(a)
        length = rng.uniform(0.34, 0.6) if front > 0.3 else rng.uniform(0.3, 0.52)
        width = rng.uniform(0.0028, 0.0075) * (1.8 if low else 1.0)
        n = int(length / step)
        pts = [root]
        d = norm(V(math.sin(a), 0.2, math.cos(a)))
        clear = rng.uniform(0.004, 0.013) + (0.004 if front > 0.5 else 0.0)
        sway = rng.uniform(-0.12, 0.12)
        for i in range(n):
            d = norm(d * 0.6 + V(sway * 0.3, -1.0, 0.0) * 0.4)
            p = pts[-1] + d * step
            # Pushed out of the skin as it falls.
            for _ in range(2):
                dist = both(p[None])[0]
                if dist < clear:
                    g = norm(np.array([(both((p + o)[None])[0] - both((p - o)[None])[0]) for o in np.eye(3) * 0.0008]))
                    p = p + g * (clear - dist)
            pts.append(p)
            d = norm(p - pts[-2])
        pts = np.array(pts)
        if len(pts) < 4:
            continue
        # Wet clumps: wide at the root, drawn together to a point.
        widths = [width * (1.0 - (i / (len(pts) - 1)) ** 1.4) + 0.0008 for i in range(len(pts))]
        outs = []
        for p in pts:
            o = p - V(0, 1.6, 0.0)
            o[1] *= 0.2
            outs.append(norm(o))
        P, T, UV = ribbon(list(pts), widths, outs)
        if front > 0.55:
            among = ["hair_f1", "hair_f2"]
        elif front < -0.4:
            among = ["hair_b1", "hair_b2"]
        else:
            among = ["hair_l" if math.sin(a) > 0 else "hair_r"]
        W = []
        along = UV[:, 0] * length
        for i, p in enumerate(P):
            s = along[i]
            h = smooth(0.1, 0.03, s)
            ws = nearest_weights(p[None], among)[0] if h < 1 else {}
            w = {k: v * (1 - h) for k, v in ws.items()}
            w["head"] = w.get("head", 0.0) + h
            W.append({k: v for k, v in w.items() if v > 0.005})
        tone = V(0.028, 0.027, 0.026) * rng.uniform(0.7, 1.4)
        C = np.tile(np.concatenate([tone, [1.0]]), (len(P), 1))
        N = np.array([outs[i // 3] for i in range(len(P))])
        model.add(P, T, N, C, UV, np.tile(V(HAIR, rng.random()), (len(P), 1)), W)
    print("hair strands", len(strands))


# ---------------------------------------------------------------------------
# Putting it out

def make_model(low):
    model = Model()
    stages = [("skin", build_skin), ("legs", build_legs), ("wings", build_wings), ("tail", build_tail),
              ("body feathers", build_body_feathers), ("hair", build_hair)]
    model.ranges = {}
    for name, step in stages:
        before = model.triangles()
        first = len(model.T)
        step(model, low)
        model.ranges[name] = (first, len(model.T))
        print("  %s: %d triangles" % (name, model.triangles() - before))
    return model


def make_armature():
    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in BONE_NAMES:
        head, tail, parent = BONES[bone]
        eb = data.edit_bones.new(bone)
        eb.head = to_b(head)
        eb.tail = to_b(tail)
    for bone in BONE_NAMES:
        parent = BONES[bone][2]
        if parent:
            data.edit_bones[bone].parent = data.edit_bones[parent]
            data.edit_bones[bone].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def make_mesh(model, name, armature, material, skip=()):
    """The model as a skinned mesh object on `armature` (leaving out the parts named in `skip`)."""
    keep = []
    for part, (a, b) in model.ranges.items():
        if part not in skip:
            keep.extend(range(a, b))
    keep = sorted(keep)
    T = np.concatenate([model.T[i] for i in keep])
    P = np.concatenate(model.P)
    N = norm_rows(np.concatenate(model.N))
    C = np.concatenate(model.C)
    UV0 = np.concatenate(model.UV0)
    UV1 = np.concatenate(model.UV1)
    used = np.unique(T)
    remap = np.full(len(P), -1)
    remap[used] = np.arange(len(used))
    T = remap[T]
    P, N, C, UV0, UV1 = P[used], N[used], C[used], UV0[used], UV1[used]
    Wd = [model.W[i] for i in used]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_b(p) for p in P], [], [tuple(int(i) for i in t) for t in T])
    mesh.update()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    col.data.foreach_set("color", C.astype(np.float32).ravel())
    loops = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loops)
    for layer, uv in (("UVMap", UV0), ("UV2", UV1)):
        lay = mesh.uv_layers.new(name=layer)
        flipped = np.stack([uv[:, 0], 1.0 - uv[:, 1]], axis=1)
        lay.data.foreach_set("uv", flipped[loops].astype(np.float32).ravel())
    mesh.uv_layers.active = mesh.uv_layers["UVMap"]
    mesh.color_attributes.active_color = mesh.color_attributes["Col"]
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
    mesh.normals_split_custom_set_from_vertices([to_b(n) for n in N])
    mesh.materials.append(material)
    body = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(body)
    groups = {b: body.vertex_groups.new(name=b) for b in BONE_NAMES}
    for i, w in enumerate(Wd):
        for bone, value in w.items():
            groups[bone].add([i], float(value), "REPLACE")
    body.parent = armature
    body.modifiers.new("Armature", "ARMATURE").object = armature
    print("%s: %d vertices, %d triangles" % (name, len(P), len(T)))
    return body


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    print("full model")
    hi = make_model(False)
    print("low model")
    lo = make_model(True)
    armature = make_armature()
    material = bpy.data.materials.new("harpy")
    body = make_mesh(hi, "harpy", armature, material)
    make_mesh(lo, "harpy_lo", armature, material)
    os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
    path = os.path.join(FOLDER, "models", "harpy.glb")
    options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=True,
                   export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    print("BUILT", path)
    if PREVIEW_DIR:
        for obj in bpy.data.objects:
            if obj.type == "MESH":
                obj.hide_render = obj is not body
        previews("harpy")
        bald = make_mesh(hi, "bald", armature, material, skip=("hair",))
        body.hide_render = True
        previews("bald", faces_only=True)
        bald.hide_render = True
        lo_obj = bpy.data.objects["harpy_lo"]
        lo_obj.hide_render = False
        previews("lo", wholes_only=True)


def previews(name, faces_only=False, wholes_only=False):
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = False
    scene.display.shading.show_backface_culling = False
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.4, 0.42, 0.45)
    camera = scene.camera
    if camera is None:
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        scene.collection.objects.link(camera)
        scene.camera = camera
    camera.data.lens = 60
    views = [("whole_front", V(0, 0.15, 1), V(0, 1.1, 0), 5.0), ("whole_top", V(0, 1, 0.02), V(0, 1.1, -0.2), 4.6),
             ("whole_back", V(-0.4, 0.4, -1), V(0, 1.1, -0.1), 5.0),
             ("body_quarter", V(0.8, 0.2, 0.9), V(0, 1.05, 0), 2.6), ("body_side", V(1, 0.05, 0), V(0, 1.0, 0), 2.6),
             ("face_front", V(0, 0.05, 1), V(0, 1.6, 0.05), 0.6), ("face_quarter", V(0.7, 0.1, 0.8), V(0, 1.6, 0.05), 0.6),
             ("face_under", V(0.2, -0.5, 1), V(0, 1.6, 0.05), 0.6), ("wing_under", V(0.1, -1, 0.15), V(0.9, 1.4, -0.2), 2.2),
             ("feet", V(0.6, 0.35, 1), V(0.14, 0.08, 0.05), 0.7), ("wrist", V(0.3, 0.6, 1), V(1.06, 1.43, 0.02), 0.5),
             ("chest", V(0.15, 0.1, 1), V(0, 1.32, 0.05), 0.9)]
    for view, direction, target, far in views:
        if faces_only and not (view.startswith("face") or view == "chest"):
            continue
        if wholes_only and not view.startswith("whole") and view != "body_quarter":
            continue
        offset = to_b(norm(direction)) * far
        t = to_b(target)
        camera.location = t + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()

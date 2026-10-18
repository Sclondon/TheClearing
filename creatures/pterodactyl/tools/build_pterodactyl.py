"""Builds the pterodactyl (a great pteranodont pterosaur) and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/pterodactyl/tools/build_pterodactyl.py [-- <preview folder>]

Writes creatures/pterodactyl/models/pterodactyl.glb: two meshes on one
skeleton, "pterodactyl" and "pterodactyl_lo" (a coarser body, head and wings),
for Pterodactyl to choose between by distance. Given a folder, renders
previews into it.

What it is: a Pteranodon-like pterosaur about 6.8 m across the wings, built as
the fossils say they were. A short deep body with a keeled breastbone and the
great flight muscles over it, a long neck, and a head longer than the body: a
long, straight, toothless beak, laterally flattened and pointed, and a blade of
a crest sweeping back from the skull over the neck; a small eye in front of the
crest, over the hinge of the jaw. The wing is a hand: the upper arm (short and
stout, with the deltopectoral crest), the forearm, a long fourth metacarpal,
and then the hugely long fourth finger in four phalanges, the last bending a
little back, out to the wingtip. At the end of the metacarpal, where the wing
finger begins, three small clawed fingers; at the wrist the pteroid, a thin
bone pointing in towards the neck that holds up the propatagium, the skin in
front of the arm. The main wing membrane (the brachiopatagium) is stretched
from the wingtip back to the ankle, along the arm and the side of the body and
down the leg. Hind legs sprawled out to the side in flight, four toes with
claws. A stub of a tail. Furred all over its body, neck and the back of its
head, and over the upper arm, with short pycnofibres (the shader draws them).

How it is made. Godot's axes (Y up, facing +Z, +X its left) throughout,
turned to Blender's only as it is put in a mesh. Built in the rest pose, the
glide: wings straight out, legs sprawled back, neck held out in front.
- The body (trunk, neck, upper arms and thighs) and the head (skull, beak,
  crest; the lower jaw its own) are signed distance fields, ellipsoids and
  capsules joined smoothly, sampled on a grid, polygonised (surface nets),
  decimated and put back on the surface; normals from the field, how deep in a
  hollow each point is baked into the alpha of its colour.
- The forearm, the hand and the wing finger, the pteroid, the little fingers,
  the shins, feet and toes, and the claws are lofted tubes.
- The membranes are sheets: the brachiopatagium a Coons patch between the arm
  and finger (its leading edge), the free trailing edge from the wingtip to the
  ankle, and the line of the body and leg it grows from; the propatagium
  between the arm and the line from the neck to the pteroid's tip. Each vertex
  of a sheet is carried by the bones along the leading edge where it is (more
  near the arm), and by the body and leg near the root and trailing edge.
- One skeleton (hips, spine, chest, two neck bones, head, jaw, tail; per side
  shoulder, humerus, forearm, hand (the metacarpal), pteroid, digits (the three
  little fingers), wing1..wing4 (the wing finger's phalanges), thigh, shin,
  foot, toes), so that Pterodactyl (creatures/pterodactyl/pterodactyl.gd) can
  fold the wing a joint at a time.
- What each vertex is, for PterodactylLook's shader: UV2.x a kind (0 fur, 1
  membrane, 2 beak, 3 crest, 4 eye, 5 mouth, 6 claw, 7 bare skin), UV2.y a
  random number per piece; UV where on its piece (fur: along the body and
  round; membrane: out along the wing and back across it); colour, and the
  alpha how open (fur, skin) or how thin (membrane: 1 at the free edge).
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

FUR, MEMBRANE, BEAK, CREST, EYE, MOUTH, CLAW, SKIN = range(8)


def V(*p):
    if len(p) == 1:
        p = p[0]
    return np.array(p, dtype=np.float64)


def to_b(p):
    return Vector((p[0], -p[2], p[1]))


def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def norm_rows(G):
    return G / np.maximum(np.linalg.norm(G, axis=1), 1e-12)[:, None]


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a + (b - a) * t


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


# ---------------------------------------------------------------------------
# The skeleton (rest: the glide, wings straight out). Left side (+X); the right
# is the mirror. Metres: it is drawn at scale 1.

SHOULDER = V(0.11, 0.05, 0.14)
ELBOW = V(0.39, 0.05, 0.13)
WRIST = V(0.89, 0.045, 0.12)
KNUCKLE = V(1.60, 0.045, 0.10)
# The wing finger: the ends of its four phalanges, the last the wingtip.
PHALANX = [V(2.33, 0.045, 0.06), V(2.86, 0.04, 0.0), V(3.20, 0.035, -0.065), V(3.40, 0.03, -0.13)]
TIP = PHALANX[-1]
PTEROID_TIP = V(0.72, 0.05, 0.27)
HIP = V(0.065, -0.02, -0.20)
KNEE = V(0.24, -0.06, -0.43)
ANKLE = V(0.42, -0.065, -0.80)
FOOT = V(0.46, -0.07, -0.92)
TOE_TIP = V(0.48, -0.075, -1.0)
NECK_BASE = V(0.0, 0.05, 0.2)
NECK_MID = V(0.0, 0.09, 0.45)
ATLAS = V(0.0, 0.12, 0.74)
JAW_HINGE = V(0.0, 0.08, 0.82)
BEAK_TIP = V(0.0, 0.045, 1.72)
EYE_AT = V(0.047, 0.137, 0.86)


def bones():
    B = {}

    def add(name, head, tail, parent):
        B[name] = (V(head), V(tail), parent)

    add("hips", (0, -0.01, -0.17), (0, 0.0, -0.05), None)
    add("spine", (0, 0.0, -0.05), (0, 0.03, 0.08), "hips")
    add("chest", (0, 0.03, 0.08), NECK_BASE, "spine")
    add("neck1", NECK_BASE, NECK_MID, "chest")
    add("neck2", NECK_MID, ATLAS - V(0, 0, 0.02), "neck1")
    add("head", ATLAS, (0, 0.11, 1.0), "neck2")
    add("jaw", JAW_HINGE, BEAK_TIP, "head")
    add("tail", (0, 0.0, -0.27), (0, -0.01, -0.40), "hips")
    for side, s in (("l", 1.0), ("r", -1.0)):
        M = np.array([s, 1.0, 1.0])

        def addm(name, head, tail, parent):
            add(name + "_" + side, V(head) * M, V(tail) * M, parent if parent in ("chest", "hips") else parent + "_" + side)

        addm("shoulder", (0.03, 0.05, 0.15), SHOULDER, "chest")
        addm("humerus", SHOULDER, ELBOW, "shoulder")
        addm("forearm", ELBOW, WRIST, "humerus")
        addm("hand", WRIST, KNUCKLE, "forearm")
        addm("pteroid", WRIST, PTEROID_TIP, "forearm")
        addm("digits", KNUCKLE, KNUCKLE + V(0.0, 0.0, 0.12), "hand")
        addm("wing1", KNUCKLE, PHALANX[0], "hand")
        addm("wing2", PHALANX[0], PHALANX[1], "wing1")
        addm("wing3", PHALANX[1], PHALANX[2], "wing2")
        addm("wing4", PHALANX[2], PHALANX[3], "wing3")
        addm("thigh", HIP, KNEE, "hips")
        addm("shin", KNEE, ANKLE, "thigh")
        addm("foot", ANKLE, FOOT, "shin")
        addm("toes", FOOT, TOE_TIP, "foot")
    return B


BONES = bones()
BONE_NAMES = list(BONES.keys())


# ---------------------------------------------------------------------------
# Signed distance fields (numpy, Godot axes)

def sd_ellipsoid(P, c, r, R=None):
    q = P - c
    if R is not None:
        q = q @ R
    k0 = np.linalg.norm(q / r, axis=1)
    k1 = np.linalg.norm(q / (r * r), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_capsule(P, a, b, ra, rb):
    pa = P - a
    ba = b - a
    h = np.clip((pa @ ba) / max(ba @ ba, 1e-12), 0.0, 1.0)
    return np.linalg.norm(pa - np.outer(h, ba), axis=1) - (ra + (rb - ra) * h)


def sd_squashed(P, a, b, ra, rb, scale):
    """A capsule squashed by `scale` (per axis, about `a`): a flattened beak or blade."""
    Q = a + (P - a) / scale
    A, Bp = a, a + (b - a) / scale
    return sd_capsule(Q, A, Bp, ra, rb) * min(scale)


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

    def squashed(self, a, b, ra, rb, scale, k=0.0, cut=False):
        a, b, scale = V(a), V(b), V(scale)
        reach = max(ra, rb) * max(scale) + k + 0.02
        self.parts.append(("s", (a, b, ra, rb, scale), k, cut, (np.minimum(a, b) - reach, np.maximum(a, b) + reach)))

    def ball(self, c, r, k=0.0, cut=False):
        self.capsule(c, c, r, r, k, cut)

    def __call__(self, P):
        d = None
        for kind, prm, k, cut, box in self.parts:
            inside = np.all((P >= box[0]) & (P <= box[1]), axis=1)
            v = np.full(len(P), 1.0)
            if inside.any():
                Q = P[inside]
                if kind == "e":
                    v[inside] = sd_ellipsoid(Q, *prm)
                elif kind == "c":
                    v[inside] = sd_capsule(Q, *prm)
                else:
                    v[inside] = sd_squashed(Q, *prm)
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
    obj.modifiers.new("Triangulate", "TRIANGULATE")
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
    N = np.zeros_like(P)
    if len(T) == 0:
        return N
    a, b, c = P[T[:, 0]], P[T[:, 1]], P[T[:, 2]]
    f = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(N, T[:, k], f)
    return N / np.maximum(np.linalg.norm(N, axis=1), 1e-12)[:, None]


def _noise3(p):
    return 0.5 + 0.25 * math.sin(p[0] * 1.7 + math.sin(p[1] * 2.3)) * math.cos(p[1] * 1.3 + p[2] * 2.1) + 0.25 * math.sin(p[2] * 3.1 + p[0] * 0.7)


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
    P = np.atleast_2d(P)
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


def blend(a, b, t):
    """Weights `a` and `b` mixed, `t` of `b`."""
    out = {}
    for k, w in a.items():
        out[k] = out.get(k, 0.0) + w * (1 - t)
    for k, w in b.items():
        out[k] = out.get(k, 0.0) + w * t
    total = sum(out.values())
    return {k: w / total for k, w in out.items() if w / total > 0.01}


BODY_BONES = ["hips", "spine", "chest", "neck1", "neck2", "head", "tail"]


def body_weights(P):
    out = []
    left = ["shoulder_l", "humerus_l", "thigh_l"]
    right = ["shoulder_r", "humerus_r", "thigh_r"]
    for p in P:
        x, y, z = p
        among = BODY_BONES + (left if x >= 0 else right)
        w = nearest_weights(p[None, :], among)[0]
        # (the trunk is not pulled about by the upper arm or thigh, only their roots)
        s = "_l" if x >= 0 else "_r"
        for b, inner in (("humerus" + s, 0.13), ("thigh" + s, 0.05), ("shoulder" + s, 0.06)):
            if b in w:
                f = smooth(inner - 0.03, inner + 0.04, abs(x))
                w["chest" if b != "thigh" + s else "hips"] = w.get("chest" if b != "thigh" + s else "hips", 0.0) + w[b] * (1 - f)
                w[b] *= f
        total = sum(w.values())
        out.append({k: v / total for k, v in w.items() if v / total > 0.01})
    return out


# ---------------------------------------------------------------------------
# The body and the head

def body_field():
    f = Field()
    # The trunk: short and deep, the keel of the breastbone under the chest.
    f.ellipsoid((0, 0.0, -0.02), (0.1, 0.095, 0.22))
    f.ellipsoid((0, -0.07, 0.07), (0.055, 0.1, 0.12), k=0.06)
    # The flight muscles over the breast, and the shoulders.
    for s in (1, -1):
        f.ellipsoid((s * 0.06, -0.03, 0.08), (0.065, 0.085, 0.11), k=0.05, R=rot_z(s * 0.25))
        f.ellipsoid((s * 0.085, 0.045, 0.13), (0.06, 0.055, 0.075), k=0.04)
    # The hips and the stub of a tail.
    f.ellipsoid((0, -0.005, -0.19), (0.072, 0.065, 0.1), k=0.05)
    f.capsule((0, 0.0, -0.26), (0, -0.01, -0.40), 0.026, 0.007, k=0.03)
    # The neck: long, thick at the base, held out in front.
    f.capsule(NECK_BASE + V(0, -0.01, -0.05), NECK_MID, 0.07, 0.05, k=0.06)
    f.capsule(NECK_MID, ATLAS + V(0, -0.005, 0.0), 0.05, 0.043, k=0.03)
    for s in (1, -1):
        m = V(s, 1, 1)
        # The upper arm, short and stout, the deltopectoral crest on its front.
        f.capsule(SHOULDER * m, ELBOW * m, 0.05, 0.034, k=0.05)
        f.ellipsoid(V(0.19 * s, 0.03, 0.158), (0.06, 0.03, 0.03), k=0.03)
        f.ball(ELBOW * m, 0.036, k=0.015)
        # The thigh, short.
        f.capsule(HIP * m, KNEE * m, 0.045, 0.03, k=0.045)
        f.ball(KNEE * m, 0.03, k=0.012)
    return f


def head_field():
    f = Field()
    # The skull: the braincase behind the eyes.
    f.ellipsoid((0, 0.13, 0.79), (0.05, 0.065, 0.08))
    # The upper beak: long, straight, deep at its root and flattened from side to
    # side, tapering to a point; its top runs on in one line into the crest.
    f.squashed((0, 0.12, 0.86), BEAK_TIP + V(0, 0.003, 0), 0.066, 0.003, (0.7, 1.0, 1.0), k=0.03)
    # The crest: one long blade sweeping back from the skull over the neck.
    f.squashed((0, 0.15, 0.82), (0, 0.35, 0.3), 0.062, 0.009, (0.22, 1.0, 1.0), k=0.04)
    # The back of the skull down to the neck, and the cheeks round the jaw's hinge.
    f.capsule((0, 0.11, 0.78), ATLAS + V(0, 0.0, -0.06), 0.05, 0.046, k=0.03)
    for s in (1, -1):
        f.ellipsoid((s * 0.035, 0.09, 0.83), (0.025, 0.03, 0.05), k=0.025)
        # The socket the eye sits in.
        f.ball(EYE_AT * V(s, 1, 1) + V(-0.004 * s, 0, 0), 0.018, k=0.008, cut=True)
        # A shallow brow over it.
        f.ellipsoid((s * 0.038, 0.158, 0.865), (0.018, 0.008, 0.03), k=0.015)
    return f


def jaw_field():
    f = Field()
    # The lower jaw, a long flat-sided spear under the beak, a little inside it.
    f.squashed(JAW_HINGE + V(0, -0.01, 0.0), BEAK_TIP + V(0, -0.004, -0.02), 0.042, 0.003, (0.76, 1.0, 1.0), k=0.02)
    for s in (1, -1):
        f.ball((s * 0.03, 0.075, 0.82), 0.02, k=0.02)
    return f


def fur_colour(P, open_):
    """Dark grey-brown pycnofibres, a little paler underneath and down the neck's front."""
    C = np.zeros((len(P), 4))
    for i, p in enumerate(P):
        c = V(0.11, 0.1, 0.09) * (0.88 + 0.24 * _noise3(p * 14.0))
        under = smooth(0.02, -0.08, p[1] - p[2] * 0.08)
        c = mix(c, V(0.15, 0.142, 0.13), under * 0.55)
        c = c * mix(0.55, 1.0, open_[i])
        C[i, :3] = c
        C[i, 3] = open_[i]
    return C


def build_body(model, low):
    print("body field")
    f = body_field()
    h = 0.016 if low else 0.009
    P, T = surface_nets(f, (-0.48, -0.22, -0.46), (0.48, 0.18, 0.8), h)
    P = f.project(P, 3)
    P, T = decimated(P, T, (1800 if low else 6000) / len(T))
    P = f.project(P, 3)
    N = norm_rows(f.gradient(P))
    open_ = f.occlusion(P, N, 0.015)
    C = fur_colour(P, open_)
    W = body_weights(P)
    # (fur: UV along the body (z) and round it; the forearm side of the elbow is skin)
    UV0 = np.stack([P[:, 2], np.arctan2(P[:, 1], P[:, 0])], axis=1)
    kind = np.where(np.abs(P[:, 0]) > 0.36, SKIN, FUR)
    UV1 = np.stack([kind, np.full(len(P), 0.3)], axis=1)
    model.add(P, T, N, C, UV0, UV1, W)
    print("  body", len(P), len(T))


def head_colour(P, N, open_, part):
    C = np.zeros((len(P), 4))
    kinds = np.zeros(len(P))
    for i, p in enumerate(P):
        x, y, z = p
        if part == "jaw":
            c = mix(V(0.2, 0.19, 0.17), V(0.33, 0.31, 0.28), smooth(0.9, 1.5, z))
            k = BEAK
            # (the inside of the mouth: the top of the jaw)
            if N[i][1] > 0.55 and z > 0.9:
                k = MOUTH
                c = V(0.14, 0.1, 0.1)
        else:
            # (on the crest: near its blade's line, over the skull or behind it)
            a, b = V(0.15, 0.82), V(0.35, 0.3)
            t = min(max(((V(y, z) - a) @ (b - a)) / ((b - a) @ (b - a)), 0.0), 1.0)
            d = np.linalg.norm(V(y, z) - (a + (b - a) * t))
            on_crest = d < (0.062 - 0.053 * t) * 1.08 and (z < 0.74 or y > 0.19) and z < 0.86
            if z > 0.9:
                # The beak: horn, pale grey, darker at its base, a darker line along its edge.
                c = mix(V(0.17, 0.16, 0.145), V(0.34, 0.32, 0.29), smooth(0.95, 1.55, z))
                if N[i][1] < -0.55 and z > 0.95:
                    c = V(0.12, 0.09, 0.09)
                    k = MOUTH
                else:
                    k = BEAK
            elif on_crest:
                # The crest: dark, a little paler towards its tip.
                c = mix(V(0.06, 0.055, 0.05), V(0.13, 0.12, 0.11), smooth(0.7, 0.3, z))
                k = CREST
            else:
                c = V(0.11, 0.1, 0.09) * (0.88 + 0.24 * _noise3(p * 14.0))
                k = FUR if z < 0.84 or y > 0.15 else SKIN
        c = c * mix(0.6, 1.0, open_[i])
        C[i, :3] = c
        C[i, 3] = open_[i]
        kinds[i] = k
    return C, kinds


def build_head(model, low):
    print("head field")
    for part, field, box in (("head", head_field(), ((-0.11, -0.02, 0.22), (0.11, 0.4, 1.76))),
                             ("jaw", jaw_field(), ((-0.07, -0.01, 0.76), (0.07, 0.12, 1.76)))):
        h = 0.009 if low else 0.0052
        P, T = surface_nets(field, box[0], box[1], h)
        P = field.project(P, 3)
        target = (900 if low else 3200) if part == "head" else (300 if low else 1000)
        P, T = decimated(P, T, target / len(T))
        P = field.project(P, 3)
        N = norm_rows(field.gradient(P))
        open_ = field.occlusion(P, N, 0.008)
        C, kinds = head_colour(P, N, open_, part)
        if part == "jaw":
            W = [{"jaw": 1.0} for _ in P]
        else:
            W = []
            for p in P:
                # (the back of the skull runs into the neck)
                t = float(smooth(0.74, 0.66, p[2])) if p[1] < 0.17 else 0.0
                W.append(blend({"head": 1.0}, {"neck2": 1.0}, t))
        UV0 = np.stack([P[:, 2], P[:, 1]], axis=1)
        UV1 = np.stack([kinds, np.full(len(P), 0.6 if part == "jaw" else 0.5)], axis=1)
        model.add(P, T, N, C, UV0, UV1, W)
        print("  %s" % part, len(P), len(T))
    # The eyes: small and dark.
    for s in (1, -1):
        P, T = ellipsoid_mesh(EYE_AT * V(s, 1, 1), V(0.015, 0.015, 0.017), seg=8 if low else 12, rings=6 if low else 8)
        N = norm_rows(P - EYE_AT * V(s, 1, 1))
        C = np.tile([0.02, 0.018, 0.016, 1.0], (len(P), 1))
        model.add(P, T, N, C, np.zeros((len(P), 2)), np.tile([EYE, 0.1], (len(P), 1)), [{"head": 1.0} for _ in P])


def ellipsoid_mesh(c, r, seg=12, rings=8):
    P = []
    for i in range(rings + 1):
        th = math.pi * i / rings
        for j in range(seg):
            ph = math.tau * j / seg
            P.append(c + r * V(math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)))
    T = []
    for i in range(rings):
        for j in range(seg):
            a = i * seg + j
            b = i * seg + (j + 1) % seg
            T.append((a, b + seg, b))
            T.append((a, a + seg, b + seg))
    return np.array(P), np.array(T)


# ---------------------------------------------------------------------------
# Tubes: the arm and finger bones, the legs, the little fingers, the claws

def tube(centres, radii, sides, ups=None, close_end=True, close_start=False):
    """A tube through `centres` with (rx, ry) radii at each (ry across `ups`): P, T, N, and per vertex (along, round)."""
    centres = [V(c) for c in centres]
    n = len(centres)
    P, N, UV = [], [], []
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
            N.append(norm(side * math.cos(a) * ry + up * math.sin(a) * rx))
            UV.append((lengths[i] / total, k / sides))
    T = []
    for i in range(n - 1):
        for k in range(sides):
            a = i * sides + k
            b = i * sides + (k + 1) % sides
            c = (i + 1) * sides + (k + 1) % sides
            d = (i + 1) * sides + k
            T.append((a, c, b))
            T.append((a, d, c))
    if close_end:
        tdir = norm(centres[-1] - centres[-2])
        P.append(centres[-1] + tdir * 0.0005)
        N.append(tdir)
        UV.append((1.0, 0.0))
        e = len(P) - 1
        for k in range(sides):
            T.append(((n - 1) * sides + k, e, (n - 1) * sides + (k + 1) % sides))
    if close_start:
        tdir = norm(centres[1] - centres[0])
        P.append(centres[0] - tdir * 0.0005)
        N.append(-tdir)
        UV.append((0.0, 0.0))
        e = len(P) - 1
        for k in range(sides):
            T.append(((k + 1) % sides, e, k))
    return np.array(P), np.array(T), np.array(N), np.array(UV)


def chain_weights(P, among):
    return nearest_weights(P, among, power=6.0, keep=2)


def add_tube(model, centres, radii, sides, kind, colour, among, ups=None, close_start=False, close_end=True, seed=0.5):
    P, T, N, UV = tube(centres, radii, sides, ups=ups, close_start=close_start, close_end=close_end)
    W = chain_weights(P, among)
    C = np.tile(np.append(colour, 1.0), (len(P), 1))
    model.add(P, T, N, C, UV, np.tile([kind, seed], (len(P), 1)), W)
    model.add(P, T, N, C, UV, np.tile([kind, seed], (len(P), 1)), W, mirror=True)


def claw(model, root, forward, down, length, radius, among, low):
    """A small curved claw from `root`, along `forward`, curling down."""
    rings = 4 if low else 6
    pts = []
    rad = []
    for i in range(rings):
        t = i / (rings - 1)
        a = t * 1.1
        pts.append(root + (forward * math.sin(a) / 1.1 + down * (1 - math.cos(a)) / 1.1 * 0.9) * length)
        rad.append((radius * (1 - t * 0.92), radius * 1.3 * (1 - t * 0.92)))
    add_tube(model, pts, rad, 5, CLAW, V(0.03, 0.028, 0.026), among, ups=[down * -1.0] * rings)


def build_limbs(model, low):
    sides = 6 if low else 9
    bone_colour = V(0.1, 0.092, 0.085)
    # The forearm (radius and ulna, side by side: flattened), the wrist, the metacarpal.
    fore = [ELBOW + V(0.01, 0, 0), mix(ELBOW, WRIST, 0.33), mix(ELBOW, WRIST, 0.66), WRIST]
    add_tube(model, fore, [(0.036, 0.028), (0.03, 0.022), (0.026, 0.019), (0.027, 0.021)], sides, FUR, V(0.085, 0.078, 0.07),
             ["humerus_l", "forearm_l", "hand_l"], close_start=True)
    hand = [WRIST, mix(WRIST, KNUCKLE, 0.15), mix(WRIST, KNUCKLE, 0.5), mix(WRIST, KNUCKLE, 0.9), KNUCKLE + V(0.015, 0, 0)]
    add_tube(model, hand, [(0.026, 0.021), (0.02, 0.016), (0.016, 0.013), (0.019, 0.016), (0.022, 0.018)], sides, SKIN, bone_colour,
             ["forearm_l", "hand_l", "wing1_l"], close_start=True)
    # The wing finger: four phalanges, each thick at its root, out to the fine tip.
    roots = [KNUCKLE] + PHALANX[:-1]
    thick = [0.017, 0.0115, 0.008, 0.0055]
    for k in range(4):
        a, b = roots[k], PHALANX[k]
        t1 = thick[k]
        t2 = thick[k + 1] if k < 3 else 0.0015
        pts = [a, mix(a, b, 0.1), mix(a, b, 0.5), mix(a, b, 0.92), b]
        rad = [(t1 * 1.15, t1), (t1 * 0.95, t1 * 0.8), (t1 * 0.8, t1 * 0.68), (t2 * 1.2, t2), (t2, t2 * 0.9)]
        names = ["hand_l"] + ["wing%d_l" % (i + 1) for i in range(4)]
        add_tube(model, pts, rad, 6 if low else 7, SKIN, bone_colour, names[max(0, k): k + 3], close_start=True)
    # The pteroid: a thin rod from the wrist in towards the neck.
    add_tube(model, [WRIST + V(-0.01, 0, 0.015), mix(WRIST, PTEROID_TIP, 0.5), PTEROID_TIP], [0.009, 0.006, 0.0035], 5, SKIN, bone_colour,
             ["pteroid_l"])
    # The three little fingers at the end of the metacarpal, each two joints and a hooked claw.
    for d in range(3):
        root = KNUCKLE + V(-0.015 + 0.012 * d, 0.012 - 0.008 * d, 0.012)
        forward = norm(V(-0.1 + 0.12 * d, -0.05, 1.0))
        down = V(0, -1, 0)
        length = 0.045 + 0.008 * d
        mid = root + forward * length
        end = mid + norm(forward + down * 0.35) * length * 0.6
        add_tube(model, [root, mid, end], [0.009, 0.0075, 0.006], 5, SKIN, bone_colour, ["digits_l"], close_start=True, close_end=False)
        claw(model, end, norm(forward + down * 0.5), down, 0.04, 0.0055, ["digits_l"], low)
    # The legs: the shin and the foot (the thigh is the body's), four toes with claws.
    leg = [KNEE, mix(KNEE, ANKLE, 0.4), mix(KNEE, ANKLE, 0.8), ANKLE, mix(ANKLE, FOOT, 0.6), FOOT]
    add_tube(model, leg, [0.03, 0.025, 0.02, 0.022, 0.018, 0.017], sides, SKIN, V(0.09, 0.083, 0.077),
             ["thigh_l", "shin_l", "foot_l"], close_start=True)
    along = norm(TOE_TIP - FOOT)
    side = norm(np.cross(V(0, 1, 0), along))
    for t in range(4):
        spread = (t - 1.5) * 0.35
        d = norm(along + side * spread)
        root = FOOT + side * (t - 1.5) * 0.012
        length = 0.055 + 0.012 * (1.5 - abs(t - 1.5))
        mid = root + d * length
        add_tube(model, [root, mid], [0.008, 0.0065], 5, SKIN, V(0.09, 0.083, 0.077), ["toes_l"], close_start=True, close_end=False)
        claw(model, mid, d, V(0, -1, 0) * 0.6 + V(0, 0, 0), 0.035, 0.005, ["toes_l"], low)


# ---------------------------------------------------------------------------
# The membranes

def polyline(points, count):
    """`count` points evenly by length along a polyline."""
    points = [V(p) for p in points]
    lengths = [0.0]
    for a, b in zip(points, points[1:]):
        lengths.append(lengths[-1] + np.linalg.norm(b - a))
    total = lengths[-1]
    out = []
    for i in range(count):
        want = total * i / (count - 1)
        for j in range(len(points) - 1):
            if want <= lengths[j + 1] or j == len(points) - 2:
                t = (want - lengths[j]) / max(lengths[j + 1] - lengths[j], 1e-9)
                out.append(mix(points[j], points[j + 1], min(max(t, 0.0), 1.0)))
                break
    return out


def smooth_curve(points, count):
    """A Catmull-Rom curve through `points`, then even by length."""
    pts = [points[0]] + list(points) + [points[-1]]
    dense = []
    segs = len(points) - 1
    for i in range(count * 4):
        u = i / (count * 4 - 1) * segs
        j = min(int(u), segs - 1)
        t = u - j
        p0, p1, p2, p3 = pts[j], pts[j + 1], pts[j + 2], pts[j + 3]
        dense.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    return polyline(dense, count)


def build_membranes(model, low):
    nu = 22 if low else 44
    nv = 5 if low else 10
    # The brachiopatagium. Leading edge: along the arm and the wing finger (just behind the bones).
    lead_pts = [SHOULDER + V(0, 0.0, -0.03), ELBOW + V(0, 0, -0.02), WRIST + V(0, 0, -0.012), KNUCKLE + V(0, 0, -0.012)] + [p + V(0, 0, -0.006) for p in PHALANX]
    L = polyline(lead_pts, nu + 1)
    # The free trailing edge, from the ankle out to the wingtip: a long gentle curve.
    T = smooth_curve([ANKLE + V(0.0, 0.0, -0.01), V(0.8, -0.04, -0.76), V(1.25, -0.015, -0.62), V(1.8, 0.005, -0.46), V(2.35, 0.02, -0.3),
                      V(2.86, 0.025, -0.19), V(3.2, 0.028, -0.14), TIP + V(0, 0, -0.004)], nu + 1)
    # The root: down the side of the body from the shoulder to the hip, and along the leg to the ankle.
    R = polyline([SHOULDER + V(0, 0.0, -0.03), V(0.1, 0.02, 0.0), V(0.085, -0.01, -0.15), HIP + V(0.01, -0.01, -0.03), mix(KNEE, HIP, 0.3), KNEE, ANKLE + V(0.0, 0.0, -0.01)], nv + 1)
    chain = ["humerus_l", "forearm_l", "hand_l", "wing1_l", "wing2_l", "wing3_l", "wing4_l"]
    root_bones = ["chest", "spine", "hips", "thigh_l", "shin_l"]
    WL = nearest_weights(np.array(L), chain)
    WR = nearest_weights(np.array(R), root_bones)
    WT0 = nearest_weights(np.array(T[:1]), ["shin_l", "foot_l"])[0]
    grid = []
    for i in range(nu + 1):
        u = i / nu
        row = []
        for j in range(nv + 1):
            v = j / nv
            # (a Coons patch: the leading edge, the trailing edge, the root and the tip)
            p = (1 - v) * L[i] + v * T[i] + (1 - u) * R[j] + u * TIP - ((1 - u) * (1 - v) * L[0] + (1 - u) * v * T[0] + u * (1 - v) * TIP + u * v * TIP)
            # (cambered: bowed up a little in the middle of the chord, most near the body)
            p = p + V(0, 0.045 * math.sin(math.pi * v) * (1 - u) ** 0.6 * math.sin(math.pi * min(1.0, u * 3 + 0.15)), 0)
            # Carried by the leading edge's bones, and near the root and down the trailing edge by the body and leg.
            reach = 0.05 + 0.42 * v ** 1.6
            share = 1.0 - float(smooth(0.0, reach, u))
            root_w = WR[j] if j < nv else WT0
            w = blend(WL[i], root_w, share)
            row.append((p, w, u, v))
        grid.append(row)
    P, W, UV, C = [], [], [], []
    for row in grid:
        for p, w, u, v in row:
            P.append(p)
            W.append(w)
            UV.append((u, v))
            thin = max(v ** 1.5, u ** 3)
            c = V(0.155, 0.14, 0.127) * (0.9 + 0.2 * _noise3(p * 6.0))
            C.append(np.append(c, thin))
    Tr = []
    for i in range(nu):
        for j in range(nv):
            a = i * (nv + 1) + j
            b = a + nv + 1
            Tr.append((a, b, b + 1))
            Tr.append((a, b + 1, a + 1))
    P = np.array(P)
    Tr = np.array(Tr)
    N = vertex_normals(P, Tr)
    # (normals up, out of the top of the wing)
    if N[:, 1].mean() < 0:
        N = -N
        Tr = Tr[:, ::-1]
    for mirror in (False, True):
        model.add(P, Tr, N, C, UV, np.tile([MEMBRANE, 0.2], (len(P), 1)), W, mirror=mirror)
    print("  brachiopatagium", len(P), len(Tr))

    # The propatagium: in front of the arm, from the neck's side out to the pteroid's tip and back to the wrist.
    nu2 = 6 if low else 12
    nv2 = 2 if low else 4
    back = polyline([SHOULDER + V(-0.01, 0.0, 0.03), ELBOW + V(0, 0, 0.022), WRIST + V(0, 0, 0.015)], nu2 + 1)
    front = smooth_curve([NECK_BASE + V(0.05, 0.02, 0.04), V(0.3, 0.05, 0.27), PTEROID_TIP, mix(PTEROID_TIP, WRIST, 0.5) + V(0, 0, 0.015), WRIST + V(0, 0, 0.015)], nu2 + 1)
    WB = nearest_weights(np.array(back), ["shoulder_l", "humerus_l", "forearm_l"])
    WF = nearest_weights(np.array(front), ["chest", "neck1", "pteroid_l"])
    P, W, UV, C = [], [], [], []
    for i in range(nu2 + 1):
        for j in range(nv2 + 1):
            v = j / nv2
            P.append(mix(back[i], front[i], v) + V(0, 0.008 * math.sin(math.pi * v), 0))
            W.append(blend(WB[i], WF[i], v))
            UV.append((i / nu2 * 0.3, -v * 0.2))
            C.append(np.append(V(0.12, 0.105, 0.095), v))
    Tr = []
    for i in range(nu2):
        for j in range(nv2):
            a = i * (nv2 + 1) + j
            b = a + nv2 + 1
            Tr.append((a, b, b + 1))
            Tr.append((a, b + 1, a + 1))
    P = np.array(P)
    Tr = np.array(Tr)
    N = vertex_normals(P, Tr)
    if N[:, 1].mean() < 0:
        N = -N
        Tr = Tr[:, ::-1]
    for mirror in (False, True):
        model.add(P, Tr, N, C, UV, np.tile([MEMBRANE, 0.25], (len(P), 1)), W, mirror=mirror)


# ---------------------------------------------------------------------------
# Putting it together

def make_model(low):
    model = Model()
    stages = [("body", build_body), ("head", build_head), ("limbs", build_limbs), ("membranes", build_membranes)]
    for name, step in stages:
        before = model.triangles()
        step(model, low)
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


def make_mesh(model, name, armature, material):
    T = np.concatenate(model.T)
    P = np.concatenate(model.P)
    N = norm_rows(np.concatenate(model.N))
    C = np.concatenate(model.C)
    UV0 = np.concatenate(model.UV0)
    UV1 = np.concatenate(model.UV1)
    Wd = model.W
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
    material = bpy.data.materials.new("pterodactyl")
    body = make_mesh(hi, "pterodactyl", armature, material)
    make_mesh(lo, "pterodactyl_lo", armature, material)
    os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
    path = os.path.join(FOLDER, "models", "pterodactyl.glb")
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
        previews("full")


def previews(name):
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_backface_culling = False
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.4, 0.42, 0.45)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 60
    views = [("top", V(0, 1, 0.02), V(0, 0, 0.2), 9.0), ("front", V(0, 0.15, 1), V(0, 0, 0), 9.0), ("under", V(0.1, -1, 0.1), V(0, 0, 0.1), 9.0),
             ("head_side", V(1, 0.1, 0.05), V(0, 0.15, 0.95), 2.6), ("head_quarter", V(0.7, 0.3, 0.7), V(0, 0.15, 0.95), 2.6),
             ("body_quarter", V(0.8, 0.5, -0.6), V(0.3, 0, -0.1), 3.0), ("hand", V(0.3, 0.6, 0.8), V(1.55, 0.04, 0.1), 0.8)]
    for view, direction, target, far in views:
        offset = to_b(norm(direction)) * far
        camera.location = to_b(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()

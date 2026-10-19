"""Builds the wyvern (a two-legged dragon, its wings its arms) and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/wyvern/tools/build_wyvern.py [-- <preview folder>]

Writes creatures/wyvern/models/wyvern.glb: two meshes on one skeleton,
"wyvern" and "wyvern_lo" (a coarser body, head and wings), for Wyvern to
choose between by distance. Given a folder, renders previews into it.

What it is: a wyvern, a dragon with two legs, about 9 m across the wings when
drawn (Wyvern draws the model at MODEL_SCALE, 1.35: it is built a little
smaller, the size of the pterodactyl it began from, so that the two share
their ways of moving). Its wings are its arms, as a bat's are: a stout upper
arm, a long forearm, a short hand, and at the knuckle three fingers: one very
long, in four joints, along the leading edge out to the wingtip (as a
pterosaur's), and two that run back through the membrane to the trailing edge
(as a bat's), the edge scalloped between them; the thumb is free, short and
thick with a great hooked claw, at the wrist. On the ground the wing is folded
up along the arm and it walks on its knuckles and thumbs. Strong hind legs
with raptor feet: a heavy thigh, a long shin, a raised metatarsus, three toes
forward and one back, all hooked claws. A deep heavy chest, a long neck, a
long tail ending in a flat barbed arrowhead. A horned reptile's head: a long
skull and snout, heavy brows over the eyes, two great horns swept back from
the back of the skull and smaller spikes at the cheeks, teeth along the jaws.
A row of spines down the neck, back and tail. Dark weathered scales, paler
plates under the belly and throat; the membrane dark and leathery.

How it is made. Godot's axes (Y up, facing +Z, +X its left) throughout,
turned to Blender's only as it is put in a mesh. Built in the rest pose, the
glide: wings straight out, legs trailing back, neck held out in front, the tail
straight behind.
- The body (trunk, neck, upper arms and thighs) and the head (skull, snout,
  brows; the lower jaw its own) are signed distance fields, ellipsoids and
  capsules joined smoothly, sampled on a grid, polygonised (surface nets),
  decimated and put back on the surface; normals from the field, how deep in a
  hollow each point is baked into the alpha of its colour.
- The tail, horns, forearm, hand and fingers, shins, feet and toes, spines,
  teeth and claws are lofted tubes; the barb at the tail's end a flat
  double-sided arrowhead.
- The membrane is one sheet each side, a Coons patch between the arm and long
  finger (its leading edge), the scalloped free trailing edge (wingtip to
  thigh) and the line of the body it grows from. Each vertex is carried by the
  bones along the leading edge where it is (more near the arm), and by the body
  near the root; the two back fingers are drawn in the sheet and carried as it is.
- One skeleton (hips, spine, chest, two neck bones, head, jaw, tail1..tail5;
  per side shoulder, humerus, forearm, hand, digits (the thumb), wing1..wing4
  (the long finger's joints), thigh, shin, foot (the metatarsus), toes), so
  that Wyvern (creatures/wyvern/wyvern.gd) can fold the wing a joint at a time
  and lash the tail.
- What each vertex is, for WyvernLook's shader: UV2.x a kind (0 scales, 1
  membrane, 2 horn, 3 belly plates, 4 eye, 5 mouth, 6 claw or tooth, 7 bare
  skin), UV2.y a random number per piece; UV where on its piece (along and
  round; membrane: out along the wing and back across it); colour, and the
  alpha how open (scales, skin) or how thin (membrane: 1 at the free edge).
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


SCALES, MEMBRANE, HORN, BELLY, EYE, MOUTH, CLAW, SKIN = range(8)




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
# is the mirror. Built at 1/1.35 of its size (Wyvern draws it at MODEL_SCALE).

SHOULDER = V(0.14, 0.07, 0.17)
ELBOW = V(0.55, 0.07, 0.13)
WRIST = V(1.20, 0.06, 0.08)
KNUCKLE = V(1.42, 0.055, 0.06)
# The long finger: the ends of its four joints, the last the wingtip.
PHALANX = [V(2.02, 0.05, 0.0), V(2.55, 0.045, -0.08), V(2.98, 0.04, -0.16), V(3.33, 0.035, -0.25)]
TIP = PHALANX[-1]
HIP = V(0.1, -0.03, -0.3)
KNEE = V(0.2, -0.1, -0.56)
ANKLE = V(0.25, -0.12, -0.88)
FOOT = V(0.27, -0.13, -1.06)
TOE_TIP = V(0.28, -0.135, -1.17)
NECK_BASE = V(0.0, 0.08, 0.26)
NECK_MID = V(0.0, 0.14, 0.62)
ATLAS = V(0.0, 0.2, 0.98)
JAW_HINGE = V(0.0, 0.17, 1.01)
SNOUT_TIP = V(0.0, 0.19, 1.40)
EYE_AT = V(0.06, 0.245, 1.12)
# The tail's joints, from the hips back; the barb past the last.
TAIL = [V(0, 0.0, -0.4), V(0, -0.01, -0.72), V(0, -0.02, -1.05), V(0, -0.03, -1.4), V(0, -0.035, -1.75), V(0, -0.04, -2.05)]
BARB_TIP = V(0, -0.042, -2.34)


def bones():
    B = {}

    def add(name, head, tail, parent):
        B[name] = (V(head), V(tail), parent)

    add("hips", (0, 0.0, -0.36), (0, 0.01, -0.15), None)
    add("spine", (0, 0.01, -0.15), (0, 0.04, 0.06), "hips")
    add("chest", (0, 0.04, 0.06), NECK_BASE, "spine")
    add("neck1", NECK_BASE, NECK_MID, "chest")
    add("neck2", NECK_MID, ATLAS - V(0, 0, 0.02), "neck1")
    add("head", ATLAS, (0, 0.2, 1.38), "neck2")
    add("jaw", JAW_HINGE, SNOUT_TIP, "head")
    parent = "hips"
    for k in range(5):
        add("tail%d" % (k + 1), TAIL[k], TAIL[k + 1], parent)
        parent = "tail%d" % (k + 1)
    for side, s in (("l", 1.0), ("r", -1.0)):
        M = np.array([s, 1.0, 1.0])

        def addm(name, head, tail, parent):
            add(name + "_" + side, V(head) * M, V(tail) * M, parent if parent in ("chest", "hips") else parent + "_" + side)

        addm("shoulder", (0.04, 0.07, 0.17), SHOULDER, "chest")
        addm("humerus", SHOULDER, ELBOW, "shoulder")
        addm("forearm", ELBOW, WRIST, "humerus")
        addm("hand", WRIST, KNUCKLE, "forearm")
        addm("digits", WRIST, WRIST + V(0.0, -0.005, 0.1), "hand")
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
TAIL_BONES = ["tail%d" % (k + 1) for k in range(5)]


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



BODY_BONES = ["hips", "spine", "chest", "neck1", "neck2", "head", "tail1"]


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
        for b, inner in (("humerus" + s, 0.17), ("thigh" + s, 0.1), ("shoulder" + s, 0.09)):
            if b in w:
                f = smooth(inner - 0.04, inner + 0.05, abs(x))
                w["chest" if b != "thigh" + s else "hips"] = w.get("chest" if b != "thigh" + s else "hips", 0.0) + w[b] * (1 - f)
                w[b] *= f
        total = sum(w.values())
        out.append({k: v / total for k, v in w.items() if v / total > 0.01})
    return out


# ---------------------------------------------------------------------------
# The body and the head

def body_field():
    f = Field()
    # The trunk: deep and heavy, the keel of the breastbone under the chest.
    f.ellipsoid((0, 0.02, -0.06), (0.175, 0.16, 0.32))
    f.ellipsoid((0, -0.07, 0.07), (0.11, 0.145, 0.17), k=0.07)
    # The flight muscles over the breast, and the shoulders.
    for s in (1, -1):
        f.ellipsoid((s * 0.08, -0.02, 0.08), (0.085, 0.105, 0.14), k=0.06, R=rot_z(s * 0.25))
        f.ellipsoid((s * 0.11, 0.065, 0.15), (0.08, 0.07, 0.09), k=0.05)
    # The hips and the root of the tail.
    f.ellipsoid((0, 0.0, -0.32), (0.135, 0.115, 0.16), k=0.06)
    f.capsule((0, 0.0, -0.36), (0, -0.005, -0.5), 0.095, 0.085, k=0.04)
    # The neck: long and strong, thick at the base.
    f.capsule(NECK_BASE + V(0, -0.01, -0.06), NECK_MID, 0.088, 0.062, k=0.07)
    f.capsule(NECK_MID, ATLAS + V(0, -0.005, 0.0), 0.062, 0.05, k=0.03)
    # (the throat: a little fuller underneath)
    f.capsule(NECK_BASE + V(0, -0.03, 0.02), NECK_MID + V(0, -0.025, 0.0), 0.07, 0.045, k=0.05)
    for s in (1, -1):
        m = V(s, 1, 1)
        # The upper arm, stout.
        f.capsule(SHOULDER * m, ELBOW * m, 0.062, 0.042, k=0.05)
        f.ellipsoid(V(0.27 * s, 0.05, 0.16), (0.08, 0.04, 0.04), k=0.04)
        f.ball(ELBOW * m, 0.044, k=0.015)
        # The thigh: heavy, a great drumstick of muscle.
        f.capsule(HIP * m, KNEE * m, 0.085, 0.05, k=0.06)
        f.ellipsoid(V(0.14 * s, -0.05, -0.41), (0.07, 0.085, 0.13), k=0.05, R=rot_y(s * 0.3))
        f.ball(KNEE * m, 0.047, k=0.015)
    return f


def head_field():
    f = Field()
    # The skull behind the eyes.
    f.ellipsoid((0, 0.23, 1.06), (0.07, 0.065, 0.095))
    # The snout: long, a little flat on top, narrowing to the nose.
    f.squashed((0, 0.225, 1.1), SNOUT_TIP + V(0, 0.003, 0), 0.062, 0.026, (0.85, 0.72, 1.0), k=0.04)
    # The back of the skull down to the neck, and the heavy jaw muscles at the cheeks.
    f.capsule((0, 0.22, 1.03), ATLAS + V(0, 0.0, -0.06), 0.055, 0.05, k=0.03)
    for s in (1, -1):
        f.ellipsoid((s * 0.055, 0.19, 1.04), (0.038, 0.048, 0.065), k=0.03)
        # The brows: heavy ridges over the eyes, running forward along the snout.
        f.ellipsoid((s * 0.05, 0.268, 1.11), (0.03, 0.014, 0.065), k=0.025, R=rot_y(s * 0.15))
        # The socket the eye sits in, under the brow.
        f.ball(EYE_AT * V(s, 1, 1) + V(-0.004 * s, 0, 0), 0.02, k=0.008, cut=True)
        # The nostrils.
        f.ball((s * 0.022, 0.215, 1.375), 0.011, k=0.006, cut=True)
    return f


def jaw_field():
    f = Field()
    # The lower jaw, under the snout and a little inside it.
    f.squashed(JAW_HINGE + V(0, -0.005, 0.03), SNOUT_TIP + V(0, -0.025, -0.025), 0.048, 0.02, (0.85, 0.55, 1.0), k=0.02)
    for s in (1, -1):
        f.ball((s * 0.045, 0.165, 1.02), 0.028, k=0.025)
    return f


def scale_colour(P, N, open_):
    """Dark weathered scales, paler plates under the belly and throat; kinds too."""
    C = np.zeros((len(P), 4))
    kinds = np.zeros(len(P))
    for i, p in enumerate(P):
        c = V(0.098, 0.095, 0.088) * (0.82 + 0.3 * _noise3(p * 11.0))
        under = float(smooth(-0.35, -0.8, N[i][1])) * (1.0 if abs(p[0]) < 0.17 else 0.0)
        c = mix(c, V(0.19, 0.18, 0.162), under)
        c = c * mix(0.5, 1.0, open_[i])
        C[i, :3] = c
        C[i, 3] = open_[i]
        kinds[i] = BELLY if under > 0.5 else SCALES
    return C, kinds


def build_body(model, low):
    print("body field")
    f = body_field()
    h = 0.02 if low else 0.011
    P, T = surface_nets(f, (-0.66, -0.3, -0.62), (0.66, 0.3, 1.05), h)
    P = f.project(P, 3)
    P, T = decimated(P, T, (1600 if low else 6500) / len(T))
    P = f.project(P, 3)
    N = norm_rows(f.gradient(P))
    open_ = f.occlusion(P, N, 0.018)
    C, kind = scale_colour(P, N, open_)
    W = body_weights(P)
    UV0 = np.stack([P[:, 2], np.arctan2(P[:, 1], P[:, 0])], axis=1)
    UV1 = np.stack([kind, np.full(len(P), 0.3)], axis=1)
    model.add(P, T, N, C, UV0, UV1, W)
    print("  body", len(P), len(T))


def build_head(model, low):
    print("head field")
    for part, field, box in (("head", head_field(), ((-0.14, 0.1, 0.86), (0.14, 0.32, 1.45))),
                             ("jaw", jaw_field(), ((-0.1, 0.1, 0.95), (0.1, 0.22, 1.42)))):
        h = 0.009 if low else 0.005
        P, T = surface_nets(field, box[0], box[1], h)
        P = field.project(P, 3)
        target = (800 if low else 3000) if part == "head" else (250 if low else 900)
        P, T = decimated(P, T, target / len(T))
        P = field.project(P, 3)
        N = norm_rows(field.gradient(P))
        open_ = field.occlusion(P, N, 0.009)
        C, kinds = scale_colour(P, N, open_)
        if part == "jaw":
            # (the inside of the mouth: the top of the jaw)
            for i in range(len(P)):
                if N[i][1] > 0.6 and P[i][2] > 1.06:
                    kinds[i] = MOUTH
                    C[i, :3] = V(0.12, 0.085, 0.085)
            W = [{"jaw": 1.0} for _ in P]
        else:
            W = []
            for i, p in enumerate(P):
                if N[i][1] < -0.6 and p[2] > 1.08:
                    kinds[i] = MOUTH
                    C[i, :3] = V(0.12, 0.085, 0.085)
                # (the back of the skull runs into the neck)
                t = float(smooth(1.0, 0.92, p[2]))
                W.append(blend({"head": 1.0}, {"neck2": 1.0}, t))
        UV0 = np.stack([P[:, 2] * 2.0, np.arctan2(P[:, 1] - 0.2, P[:, 0]) * 0.5], axis=1)
        UV1 = np.stack([kinds, np.full(len(P), 0.6 if part == "jaw" else 0.5)], axis=1)
        model.add(P, T, N, C, UV0, UV1, W)
        print("  %s" % part, len(P), len(T))
    # The eyes: small, deep under the brows, a dull gleam.
    for s in (1, -1):
        P, T = ellipsoid_mesh(EYE_AT * V(s, 1, 1), V(0.016, 0.014, 0.019), seg=8 if low else 12, rings=6 if low else 8)
        N = norm_rows(P - EYE_AT * V(s, 1, 1))
        C = np.tile([0.05, 0.045, 0.035, 1.0], (len(P), 1))
        model.add(P, T, N, C, np.zeros((len(P), 2)), np.tile([EYE, 0.1], (len(P), 1)), [{"head": 1.0} for _ in P])
    # The horns: two great ones swept back from the back of the skull, curving out
    # and down at their tips; smaller spikes at the cheeks and behind the jaw.
    rings = 6 if low else 10
    horn = smooth_curve([V(0.045, 0.27, 1.04), V(0.07, 0.315, 0.97), V(0.095, 0.335, 0.89), V(0.115, 0.33, 0.81), V(0.125, 0.305, 0.75)], rings)
    radii = [0.026 * (1 - k / (rings - 1)) ** 0.8 + 0.002 for k in range(rings)]
    add_tube(model, horn, radii, 6 if low else 8, HORN, V(0.3, 0.285, 0.255), ["head"], close_start=True)
    for root, end, r in ((V(0.075, 0.2, 1.0), V(0.12, 0.2, 0.92), 0.014), (V(0.065, 0.24, 1.0), V(0.1, 0.27, 0.93), 0.012),
                         (V(0.06, 0.15, 0.99), V(0.09, 0.12, 0.93), 0.011)):
        add_tube(model, [root, mix(root, end, 0.55) + V(0, 0.005, 0), end], [r, r * 0.55, 0.0015], 5, HORN, V(0.26, 0.245, 0.22), ["head" if root[1] > 0.17 else "jaw"], close_start=True)
    # Teeth along the jaws, pale, a few showing past the lips.
    for k in range(6):
        z = 1.15 + k * 0.042
        at = V(0.045 - k * 0.004, 0.19 - k * 0.002, z)
        tooth(model, at, V(0, -1, 0.15), 0.022 - k * 0.002, ["head"])
    for k in range(5):
        z = 1.16 + k * 0.045
        at = V(0.038 - k * 0.003, 0.178, z)
        tooth(model, at, V(0, 1, 0.1), 0.016, ["jaw"])


def tooth(model, root, direction, length, among):
    d = norm(direction)
    add_tube(model, [root, root + d * length * 0.6, root + d * length], [0.0055, 0.0035, 0.0008], 4, CLAW, V(0.4, 0.38, 0.34), among, close_start=True)


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




def add_tube(model, centres, radii, sides, kind, colour, among, ups=None, close_start=False, close_end=True, seed=0.5, mirror=True, weights=None):
    """A tube on both sides (or, `mirror` false, one on the middle line)."""
    P, T, N, UV = tube(centres, radii, sides, ups=ups, close_start=close_start, close_end=close_end)
    W = weights(P) if weights else chain_weights(P, among)
    C = np.tile(np.append(colour, 1.0), (len(P), 1))
    model.add(P, T, N, C, UV, np.tile([kind, seed], (len(P), 1)), W)
    if mirror:
        model.add(P, T, N, C, UV, np.tile([kind, seed], (len(P), 1)), W, mirror=True)


def claw(model, root, forward, down, length, radius, among, low, mirror=True):
    """A hooked claw from `root`, along `forward`, curling down."""
    rings = 4 if low else 6
    pts = []
    rad = []
    for i in range(rings):
        t = i / (rings - 1)
        a = t * 1.3
        pts.append(root + (forward * math.sin(a) / 1.3 + down * (1 - math.cos(a)) / 1.3 * 0.9) * length)
        rad.append((radius * (1 - t * 0.92), radius * 1.35 * (1 - t * 0.92)))
    add_tube(model, pts, rad, 5, CLAW, V(0.03, 0.028, 0.026), among, ups=[down * -1.0] * rings, mirror=mirror)


def build_limbs(model, low):
    sides = 6 if low else 9
    bone_colour = V(0.085, 0.08, 0.074)
    scale_c = V(0.09, 0.087, 0.081)
    # The forearm: long and strong, a little flattened.
    fore = [ELBOW + V(0.01, 0, 0), mix(ELBOW, WRIST, 0.3), mix(ELBOW, WRIST, 0.7), WRIST]
    add_tube(model, fore, [(0.042, 0.034), (0.034, 0.026), (0.028, 0.022), (0.03, 0.025)], sides, SCALES, scale_c,
             ["humerus_l", "forearm_l", "hand_l"], close_start=True)
    # The hand: short, thick at the wrist and knuckle.
    hand = [WRIST, mix(WRIST, KNUCKLE, 0.5), KNUCKLE + V(0.015, 0, 0)]
    add_tube(model, hand, [(0.03, 0.025), (0.022, 0.019), (0.026, 0.021)], sides, SKIN, bone_colour,
             ["forearm_l", "hand_l", "wing1_l"], close_start=True)
    # The long finger: four joints, each thick at its root, out to the fine tip.
    roots = [KNUCKLE] + PHALANX[:-1]
    thick = [0.02, 0.0135, 0.0095, 0.0065]
    for k in range(4):
        a, b = roots[k], PHALANX[k]
        t1 = thick[k]
        t2 = thick[k + 1] if k < 3 else 0.0018
        pts = [a, mix(a, b, 0.1), mix(a, b, 0.5), mix(a, b, 0.92), b]
        rad = [(t1 * 1.2, t1), (t1 * 0.95, t1 * 0.8), (t1 * 0.8, t1 * 0.68), (t2 * 1.2, t2), (t2, t2 * 0.9)]
        names = ["hand_l"] + ["wing%d_l" % (i + 1) for i in range(4)]
        add_tube(model, pts, rad, 6 if low else 7, SKIN, bone_colour, names[max(0, k): k + 3], close_start=True)
        # (a knob at each joint)
        if k < 3:
            P, T = ellipsoid_mesh(b, V(t2 * 1.6, t2 * 1.4, t2 * 1.6), seg=6, rings=4)
            N = norm_rows(P - b)
            W = chain_weights(P, ["wing%d_l" % (k + 1), "wing%d_l" % (k + 2)])
            C = np.tile(np.append(bone_colour, 1.0), (len(P), 1))
            model.add(P, T, N, C, np.zeros((len(P), 2)), np.tile([SKIN, 0.4], (len(P), 1)), W)
            model.add(P, T, N, C, np.zeros((len(P), 2)), np.tile([SKIN, 0.4], (len(P), 1)), W, mirror=True)
    # A claw at the knuckle, where the fingers part.
    claw(model, KNUCKLE + V(0.005, 0.015, 0.015), norm(V(-0.2, 0.3, 1.0)), V(0, -1, 0), 0.04, 0.007, ["hand_l"], low)
    # The thumb, free at the wrist: short and thick, a great hooked claw.
    thumb_root = WRIST + V(0.0, 0.0, 0.015)
    forward = norm(V(-0.15, -0.1, 1.0))
    mid = thumb_root + forward * 0.06
    end = mid + norm(forward + V(0, -0.3, 0)) * 0.045
    add_tube(model, [thumb_root, mid, end], [0.018, 0.015, 0.012], 6, SKIN, bone_colour, ["digits_l"], close_start=True, close_end=False)
    claw(model, end, norm(forward + V(0, -0.4, 0)), V(0, -1, 0), 0.085, 0.012, ["digits_l"], low)
    # The legs: the shin (meaty at the top), the raised metatarsus; the thigh is the body's.
    shin = [KNEE, mix(KNEE, ANKLE, 0.3), mix(KNEE, ANKLE, 0.7), ANKLE]
    add_tube(model, shin, [(0.066, 0.072), (0.058, 0.064), (0.04, 0.042), (0.034, 0.034)], sides, SCALES, scale_c,
             ["thigh_l", "shin_l", "foot_l"], close_start=True)
    meta = [ANKLE, mix(ANKLE, FOOT, 0.5), FOOT]
    add_tube(model, meta, [0.036, 0.029, 0.03], sides, SCALES, scale_c, ["shin_l", "foot_l", "toes_l"], close_start=True)
    # Three toes forward, spread, each with a great hooked claw; one back (the hallux).
    along = norm(TOE_TIP - FOOT)
    side = norm(np.cross(V(0, 1, 0), along))
    for t in range(3):
        spread = (t - 1) * 0.4
        d = norm(along + side * spread)
        root = FOOT + side * (t - 1) * 0.014
        length = 0.08 if t == 1 else 0.065
        mid = root + d * length * 0.55
        end = root + d * length
        add_tube(model, [root, mid, end], [0.017, 0.014, 0.011], 6, SCALES, scale_c, ["toes_l"], close_start=True, close_end=False)
        claw(model, end, d, V(0, -1, 0), 0.06 if t == 1 else 0.05, 0.01, ["toes_l"], low)
    back = norm(-along + V(0, -0.2, 0))
    root = FOOT + V(0, 0.01, 0.025)
    add_tube(model, [root, root + back * 0.035], [0.012, 0.009], 5, SCALES, scale_c, ["foot_l"], close_start=True, close_end=False)
    claw(model, root + back * 0.035, back, V(0, -1, 0), 0.04, 0.008, ["foot_l"], low)


def tail_weights(P):
    return nearest_weights(P, ["hips"] + TAIL_BONES, power=4.0, keep=2)


def build_tail(model, low):
    """The tail, a long tapering tube from inside the hips, and the barb at its end."""
    rings = 22 if low else 44
    path = smooth_curve([V(0, 0.0, -0.32)] + TAIL, rings)
    radii = []
    for k, p in enumerate(path):
        t = (p[2] - (-0.32)) / (TAIL[-1][2] - (-0.32))
        r = mix(0.092, 0.02, t ** 0.85)
        radii.append((r, r * 1.08))
    add_tube(model, path, radii, 7 if low else 10, SCALES, V(0.095, 0.092, 0.086), None, close_start=True, close_end=False,
             mirror=False, weights=tail_weights)
    # The barb: a flat arrowhead, edged, a barb hooked back at each of its corners.
    steps = 6 if low else 10
    centres, rads = [], []
    for k in range(steps):
        s = k / (steps - 1)
        z = mix(TAIL[-1][2] + 0.02, BARB_TIP[2], s)
        w = mix(0.022, 0.105, smooth(0.0, 0.28, s)) if s < 0.28 else 0.105 * (1.0 - (s - 0.28) / 0.72) ** 0.9 + 0.002
        centres.append(V(0, mix(TAIL[-1][1], BARB_TIP[1], s), z))
        rads.append((w, max(0.022 * (1.0 - s) ** 0.7, 0.003)))
    add_tube(model, centres, rads, 6 if low else 8, HORN, V(0.075, 0.07, 0.065), ["tail5"], ups=[V(0, 1, 0)] * steps, mirror=False)
    # (the barbs: the arrowhead's back corners drawn out into hooks pointing back)
    corner = V(0.095, TAIL[-1][1], mix(TAIL[-1][2] + 0.02, BARB_TIP[2], 0.26))
    hook = corner + V(0.045, 0.0, 0.085)
    add_tube(model, [corner + V(-0.02, 0, -0.01), mix(corner, hook, 0.5), hook], [(0.02, 0.012), (0.012, 0.007), 0.001], 5, HORN,
             V(0.075, 0.07, 0.065), ["tail5"], ups=[V(0, 1, 0)] * 3, close_start=True)


def build_spines(model, low):
    """A row of spines down the neck, back and tail, smaller towards each end."""
    rows = []
    for k in range(6):
        t = (k + 0.5) / 6
        c = mix(NECK_BASE, ATLAS, t)
        r = mix(0.088, 0.05, t)
        rows.append((c + V(0, r - 0.006, 0), mix(0.055, 0.035, t), ["neck1", "neck2"]))
    for k in range(4):
        z = mix(0.18, -0.32, k / 3)
        y = 0.02 + 0.14 * math.sqrt(max(0.0, 1 - ((z + 0.06) / 0.3) ** 2)) if k < 3 else 0.095
        rows.append((V(0, y - 0.006, z), 0.07, ["chest", "spine", "hips"]))
    for k in range(9):
        t = (k + 0.5) / 9
        i = t * (len(TAIL) - 1)
        a = int(i)
        c = mix(TAIL[a], TAIL[min(a + 1, len(TAIL) - 1)], i - a)
        r = mix(0.085, 0.022, t ** 0.85)
        rows.append((c + V(0, r - 0.004, 0), mix(0.06, 0.025, t), ["hips"] + TAIL_BONES))
    for at, length, among in rows:
        tip = at + V(0, length, -length * 0.8)
        add_tube(model, [at, mix(at, tip, 0.5) + V(0, 0.004, 0.0), tip], [(length * 0.12, length * 0.3), (length * 0.07, length * 0.16), 0.001], 4,
                 HORN, V(0.07, 0.066, 0.06), among, close_start=True, mirror=False)


# ---------------------------------------------------------------------------
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
    nv = 6 if low else 12
    # Leading edge: along the arm and the long finger (just behind the bones).
    lead_pts = [SHOULDER + V(0, 0.0, -0.035), ELBOW + V(0, 0, -0.025), WRIST + V(0, 0, -0.02), KNUCKLE + V(0, 0, -0.015)] + [p + V(0, 0, -0.008) for p in PHALANX]
    L = polyline(lead_pts, nu + 1)
    # The root: down the side of the body from the shoulder to the hip and the top of the thigh.
    R = polyline([SHOULDER + V(0, 0.0, -0.035), V(0.15, 0.04, 0.0), V(0.145, 0.01, -0.18), HIP + V(0.03, 0.0, 0.0), mix(HIP, KNEE, 0.4) + V(0.03, 0, 0)], nv + 1)
    # The free trailing edge, from the thigh out to the wingtip, scalloped between the back fingers.
    T = smooth_curve([R[-1], V(0.5, -0.06, -0.68), V(0.95, -0.03, -0.8), V(1.45, 0.0, -0.76), V(1.95, 0.02, -0.64), V(2.45, 0.03, -0.5),
                      V(2.9, 0.035, -0.38), TIP + V(0, 0, -0.006)], nu + 1)
    ends = [0.36, 0.62]
    anchors = [0.0] + ends + [1.0]
    for i in range(nu + 1):
        u = i / nu
        for a, b in zip(anchors, anchors[1:]):
            if a <= u <= b:
                T[i] = mix(T[i], L[i], 0.24 * math.sin(math.pi * (u - a) / (b - a)) * (0.6 if a == 0.0 else 1.0))
                break
    chain = ["humerus_l", "forearm_l", "hand_l", "wing1_l", "wing2_l", "wing3_l", "wing4_l"]
    root_bones = ["chest", "spine", "hips", "thigh_l"]
    WL = nearest_weights(np.array(L), chain)
    WR = nearest_weights(np.array(R), root_bones)
    WT0 = nearest_weights(np.array(T[:1]), ["hips", "thigh_l"])[0]
    grid = []
    for i in range(nu + 1):
        u = i / nu
        row = []
        for j in range(nv + 1):
            v = j / nv
            # (a Coons patch: the leading edge, the trailing edge, the root and the tip)
            p = (1 - v) * L[i] + v * T[i] + (1 - u) * R[j] + u * TIP - ((1 - u) * (1 - v) * L[0] + (1 - u) * v * T[0] + u * (1 - v) * TIP + u * v * TIP)
            # (cambered: bowed up a little in the middle of the chord, most near the body)
            p = p + V(0, 0.05 * math.sin(math.pi * v) * (1 - u) ** 0.6 * math.sin(math.pi * min(1.0, u * 3 + 0.15)), 0)
            # Carried by the leading edge's bones, and near the root by the body.
            reach = 0.05 + 0.4 * v ** 1.6
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
            c = V(0.125, 0.115, 0.105) * (0.85 + 0.25 * _noise3(p * 6.0))
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
    if N[:, 1].mean() < 0:
        N = -N
        Tr = Tr[:, ::-1]
    for mirror in (False, True):
        model.add(P, Tr, N, C, UV, np.tile([MEMBRANE, 0.2], (len(P), 1)), W, mirror=mirror)
    print("  wing membrane", len(P), len(Tr))

    # The two back fingers, from the knuckle back through the membrane to the
    # trailing edge (drawn in the sheet, carried as it is).
    lengths = [0.0]
    for a, b in zip(lead_pts, lead_pts[1:]):
        lengths.append(lengths[-1] + np.linalg.norm(b - a))
    u_knuckle = lengths[3] / lengths[-1]

    def at(u, v):
        x = u * nu
        y = v * nv
        i0, j0 = min(int(x), nu - 1), min(int(y), nv - 1)
        fx, fy = x - i0, y - j0
        p = 0
        w = {}
        for di, dj, f in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
            q, wq, _, _ = grid[i0 + di][j0 + dj]
            p = p + q * f
            for k, val in wq.items():
                w[k] = w.get(k, 0.0) + val * f
        return p, w

    rings = 6 if low else 10
    for k, end in enumerate(ends):
        pts, ws, rad = [], [], []
        for r in range(rings):
            t = r / (rings - 1)
            p, w = at(mix(u_knuckle, end, t), mix(0.04, 0.985, t))
            pts.append(p)
            ws.append(w)
            rad.append(mix(0.015, 0.0035, t))
        Pt, Tt, Nt, UVt = tube(pts, rad, 5, close_start=True)
        sides = 5
        # (the rings' vertices, then the cap at the end, then the one at the start)
        Wt = [ws[n // sides] if n < rings * sides else (ws[-1] if n == rings * sides else ws[0]) for n in range(len(Pt))]
        Ct = np.tile([0.085, 0.08, 0.074, 1.0], (len(Pt), 1))
        model.add(Pt, Tt, Nt, Ct, UVt, np.tile([SKIN, 0.45], (len(Pt), 1)), Wt)
        model.add(Pt, Tt, Nt, Ct, UVt, np.tile([SKIN, 0.45], (len(Pt), 1)), Wt, mirror=True)

    # The skin in front of the arm, from the neck's side out to the wrist.
    nu2 = 6 if low else 12
    nv2 = 2 if low else 4
    back = polyline([SHOULDER + V(-0.01, 0.0, 0.04), ELBOW + V(0, 0, 0.03), WRIST + V(0, 0, 0.022)], nu2 + 1)
    front = smooth_curve([NECK_BASE + V(0.075, 0.02, 0.06), V(0.38, 0.075, 0.25), V(0.82, 0.068, 0.17), WRIST + V(0, 0, 0.028)], nu2 + 1)
    WB = nearest_weights(np.array(back), ["shoulder_l", "humerus_l", "forearm_l"])
    WF = nearest_weights(np.array(front), ["chest", "neck1", "humerus_l", "forearm_l"])
    P, W, UV, C = [], [], [], []
    for i in range(nu2 + 1):
        for j in range(nv2 + 1):
            v = j / nv2
            P.append(mix(back[i], front[i], v) + V(0, 0.008 * math.sin(math.pi * v), 0))
            W.append(blend(WB[i], WF[i], v))
            UV.append((i / nu2 * 0.3, -v * 0.2))
            C.append(np.append(V(0.11, 0.1, 0.092), v))
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
    stages = [("body", build_body), ("head", build_head), ("limbs", build_limbs), ("tail", build_tail), ("spines", build_spines),
              ("membranes", build_membranes)]
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
    material = bpy.data.materials.new("wyvern")
    body = make_mesh(hi, "wyvern", armature, material)
    make_mesh(lo, "wyvern_lo", armature, material)
    os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
    path = os.path.join(FOLDER, "models", "wyvern.glb")
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
    views = [("top", V(0, 1, 0.02), V(0, 0, -0.4), 10.0), ("side", V(1, 0.1, 0), V(0, 0, -0.45), 6.0),
             ("head_side", V(1, 0.1, 0.05), V(0, 0.22, 1.15), 1.6), ("head_quarter", V(0.7, 0.4, 0.7), V(0, 0.22, 1.12), 1.6),
             ("body_quarter", V(0.8, 0.5, -0.6), V(0.2, 0, -0.3), 3.2), ("barb", V(0.3, 1, -0.2), V(0, 0, -2.15), 0.9),
             ("foot", V(0.8, 0.2, 0.3), V(0.27, -0.13, -1.08), 0.7)]
    for view, direction, target, far in views:
        offset = to_b(norm(direction)) * far
        camera.location = to_b(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()

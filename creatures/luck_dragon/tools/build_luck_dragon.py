"""Builds the luck dragon and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/luck_dragon/tools/build_luck_dragon.py [-- <preview folder>]

Writes creatures/luck_dragon/models/luck_dragon.glb: two meshes on one
skeleton, "luck_dragon" and "luck_dragon_lo" (a coarser body, fewer locks of
fur), for LuckDragon to choose between by distance. Given a folder, renders
previews into it.

What it is: a dragon of good fortune that swims through the sky. Very long
(about 35 m from nose to tail) and slender, round in section like a great eel,
thickest a third of the way back and drawn out into a long fine tail; no wings.
Its skin is small pale scales with a pearly sheen and a row of broad plates down
the belly. Soft white fur grows along its back from the head to the tail, a mane
of long locks streams back from the crown and cheeks down the neck, and the tail
ends in a plume. Four short legs, each with three blunt toes and a tuft at the
wrist, held up under it as it swims. The head is broad and gentle, more a great
hound's than a reptile's: a high round brow, a broad short muzzle with a soft
dark nose, a closed smiling mouth, wide cheeks, big dark kind eyes under soft
brows, long hound's ears that hang and stream back, long barbels like a carp's
trailing from the lips, and a wisp from each brow.

How it is made. Godot's axes (Y up, facing +Z, +X its left) throughout, turned
to Blender's only as it is put in a mesh. It is built lying straight along -Z
from its head (the neck joint at the origin, the nose at +3.1 m).
- Every bone points straight up with no roll (so that each one's rest is the
  identity in Godot), and the spine bones (spine00..spine24, every SEG metres
  back from the head) have no parent: LuckDragon sets each where its place on
  the path its head has flown says. The head has none either; the jaw, ears and
  barbels hang from it, and each leg from the spine bone it grows from.
- The body is one lofted tube, weighted along its length between the two spine
  bones nearest; the head is built of overlapping shapes on the head bone.
- Fur is cards (tapering strips, drawn from both sides), rooted on the skin and
  laid back, each carried by the bone it grows from.
- What each vertex is, for LuckDragonLook's shader: UV2.x a kind (0 scales,
  1 fur, 2 soft skin of the face, 3 eye, 4 nose and claws, 5 mouth), UV2.y a
  random number per piece; UV where on its piece (the body: metres along it,
  and round it, 0.75 the belly); colour, and how open it is (alpha).
"""

import math
import os
import random
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

SCALES, FUR, FACE, EYE, NOSE, MOUTH = range(6)

## Spine bones: how many, and how far apart along the body (metres).
SPINES = 25
SEG = 1.3
## How far back the tail tip is.
TAIL_END = 32.4
## Where each pair of legs grows (metres back from the head).
FORE_AT = 6.2
HIND_AT = 19.6

PEARL = (0.86, 0.85, 0.83)
FUR_WHITE = (0.93, 0.92, 0.89)


def V(*p):
    if len(p) == 1:
        p = p[0]
    return np.array(p, dtype=np.float64)


def to_b(p):
    return (float(p[0]), float(-p[2]), float(p[1]))


def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
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
# The skeleton

def spine_name(i):
    return "spine%02d" % i


def bones():
    out = {}
    order = []

    def add(name, at, parent):
        out[name] = (V(at), parent)
        order.append(name)

    for i in range(SPINES):
        add(spine_name(i), (0.0, 0.0, -i * SEG), None)
    add("head", (0.0, 0.05, 0.1), None)
    add("jaw", (0.0, -0.22, 0.62), "head")
    for side, s in ((1.0, "_l"), (-1.0, "_r")):
        add("ear1" + s, (side * 0.86, 0.82, 0.5), "head")
        add("ear2" + s, (side * 1.3, 0.3, -0.7), "ear1" + s)
        add("barbel1" + s, (side * 0.56, -0.1, 2.6), "head")
        add("barbel2" + s, (side * 1.9, -0.5, 1.7), "barbel1" + s)
        for leg, z in (("fore", FORE_AT), ("hind", HIND_AT)):
            r = radius_at(z)
            spine = spine_name(int(round(z / SEG)))
            add(leg + "1" + s, (side * r * 0.72, -r * 0.55, -z), spine)
            add(leg + "2" + s, (side * (r * 0.72 + 0.26), -r * 0.55 - 0.6, -z + 0.3), leg + "1" + s)
    return out, order


# ---------------------------------------------------------------------------
# The model, as it is put together

class Model:
    def __init__(self):
        self.P, self.N, self.C, self.UV0, self.UV1, self.W, self.T = [], [], [], [], [], [], []
        self.count = 0

    def add(self, P, T, N, C, UV0, UV1, W):
        P = np.array(P, dtype=np.float64).reshape(-1, 3)
        N = np.array(N, dtype=np.float64).reshape(-1, 3)
        T = np.array(T, dtype=int).reshape(-1, 3)
        C = np.array(C, dtype=np.float64).reshape(-1, 4)
        UV0 = np.array(UV0, dtype=np.float64).reshape(-1, 2)
        UV1 = np.array(UV1, dtype=np.float64).reshape(-1, 2)
        assert len(P) == len(N) == len(C) == len(UV0) == len(UV1) == len(W)
        self.P.append(P)
        self.N.append(N)
        self.C.append(C)
        self.UV0.append(UV0)
        self.UV1.append(UV1)
        self.W.extend(W)
        self.T.append(T + self.count)
        self.count += len(P)

    def triangles(self):
        return sum(len(t) for t in self.T)


def mirrored(W):
    out = []
    for w in W:
        d = {}
        for k, v in w.items():
            if k.endswith("_l"):
                k = k[:-2] + "_r"
            elif k.endswith("_r"):
                k = k[:-2] + "_l"
            d[k] = v
        out.append(d)
    return out


# ---------------------------------------------------------------------------
# Shapes

def radius_at(s):
    """How thick the body is (its radius, metres) `s` metres back from the head."""
    profile = [(-0.8, 0.78), (0.0, 0.8), (2.0, 0.88), (5.0, 1.12), (9.0, 1.28), (14.0, 1.24), (19.0, 1.08),
               (24.0, 0.84), (28.0, 0.56), (30.5, 0.32), (31.8, 0.14), (TAIL_END, 0.04)]
    for (a, ra), (b, rb) in zip(profile, profile[1:]):
        if s <= b:
            t = (s - a) / (b - a)
            t = t * t * (3 - 2 * t)
            return lerp(ra, rb, max(0.0, min(1.0, t)))
    return profile[-1][1]


def spine_weights(s):
    """The two spine bones nearest `s` metres back, shared by how near (and the head, at the neck)."""
    f = max(0.0, min(s / SEG, SPINES - 1.0))
    i = int(math.floor(f))
    t = f - i
    w = {}
    if i >= SPINES - 1:
        w[spine_name(SPINES - 1)] = 1.0
    else:
        w[spine_name(i)] = 1.0 - t
        w[spine_name(i + 1)] = t
    head = smooth(0.5, -0.7, s)
    if head > 0.0:
        w = {k: v * (1.0 - head) for k, v in w.items()}
        w["head"] = w.get("head", 0.0) + head
    return w


def colour(rgb, open_=1.0, jitter=0.0, rng=None):
    j = (rng.uniform(-jitter, jitter) if rng else 0.0)
    return (min(1.0, rgb[0] + j), min(1.0, rgb[1] + j), min(1.0, rgb[2] + j), open_)


def build_body(model, low):
    """The body: a tube from inside the back of the head to the tail's tip."""
    step = 0.5 if low else 0.16
    sides = 10 if low else 22
    rng = random.Random(3)
    s_list = list(np.arange(-0.8, TAIL_END - 0.05, step)) + [TAIL_END]
    P, N, C, UV0, UV1, W = [], [], [], [], [], []
    for s in s_list:
        r = radius_at(s)
        for k in range(sides):
            a = math.tau * k / sides
            ca, sa = math.cos(a), math.sin(a)
            ry = r * (0.93 if sa > 0 else 0.84)
            P.append(V(ca * r, sa * ry, -s))
            N.append(norm(V(ca / r, sa / ry, 0.0)))
            # (a little darker under it and along its flanks' lower half)
            under = smooth(0.2, -0.9, sa)
            C.append(colour((PEARL[0] - 0.05 * under, PEARL[1] - 0.05 * under, PEARL[2] - 0.04 * under), 1.0 - 0.25 * under))
            UV0.append((s, k / sides))
            UV1.append((SCALES, 0.0))
            W.append(spine_weights(s))
    T = []
    rings = len(s_list)
    for i in range(rings - 1):
        for k in range(sides):
            a = i * sides + k
            b = i * sides + (k + 1) % sides
            c = (i + 1) * sides + (k + 1) % sides
            d = (i + 1) * sides + k
            T.append((a, b, c))
            T.append((a, c, d))
    # (the tail's tip closed)
    P.append(V(0.0, 0.0, -TAIL_END - 0.02))
    N.append(V(0.0, 0.0, -1.0))
    C.append(colour(PEARL))
    UV0.append((TAIL_END, 0.0))
    UV1.append((SCALES, 0.0))
    W.append(spine_weights(TAIL_END))
    e = len(P) - 1
    for k in range(sides):
        T.append(((rings - 1) * sides + k, (rings - 1) * sides + (k + 1) % sides, e))
    model.add(P, T, N, C, UV0, UV1, W)


def ellipsoid(model, c, r, R, kind, rgb, weights, low, seg=16, rings=10, open_=1.0, seed=0.0, shade_under=0.0):
    if low:
        seg, rings = max(6, seg // 2), max(4, rings // 2)
    c = V(c)
    r = V(r)
    P, N, C, UV0, UV1, W = [], [], [], [], [], []
    for i in range(rings + 1):
        th = math.pi * i / rings
        for k in range(seg):
            ph = math.tau * k / seg
            u = V(math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph))
            p = c + R @ (u * r)
            P.append(p)
            N.append(norm(R @ (u / r)))
            under = smooth(0.0, -1.0, u[1]) * shade_under
            C.append((rgb[0] * (1 - 0.15 * under), rgb[1] * (1 - 0.15 * under), rgb[2] * (1 - 0.13 * under), open_ * (1 - 0.3 * under)))
            UV0.append((k / seg, i / rings))
            UV1.append((kind, seed))
            W.append(weights(p) if callable(weights) else dict(weights))
    T = []
    for i in range(rings):
        for k in range(seg):
            a = i * seg + k
            b = i * seg + (k + 1) % seg
            c_ = (i + 1) * seg + (k + 1) % seg
            d = (i + 1) * seg + k
            T.append((a, d, c_))
            T.append((a, c_, b))
    model.add(P, T, N, C, UV0, UV1, W)


def catmull(points, count):
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


def lofted(model, centres, radii, kind, rgb, weights, sides, up_hint=V(0, 1, 0), seed=0.0, open_ends=1.0, uv_scale=1.0):
    """A tube through `centres` (each radius (rx, ry), ry along `up_hint`), closed at both ends."""
    n = len(centres)
    P, N, C, UV0, UV1, W = [], [], [], [], [], []
    along = 0.0
    for i in range(n):
        if i > 0:
            along += float(np.linalg.norm(centres[i] - centres[i - 1]))
        t = norm(centres[min(i + 1, n - 1)] - centres[max(i - 1, 0)])
        up = norm(up_hint - t * float(up_hint @ t))
        side = np.cross(t, up)
        rx, ry = radii[i]
        for k in range(sides):
            a = math.tau * k / sides
            P.append(centres[i] + side * math.cos(a) * rx + up * math.sin(a) * ry)
            N.append(norm(side * math.cos(a) / max(rx, 1e-4) + up * math.sin(a) / max(ry, 1e-4)))
            C.append((rgb[0], rgb[1], rgb[2], open_ends))
            UV0.append((along * uv_scale, k / sides))
            UV1.append((kind, seed))
            W.append(weights(centres[i], i / max(n - 1, 1)) if callable(weights) else dict(weights))
    T = []
    for i in range(n - 1):
        for k in range(sides):
            a = i * sides + k
            b = i * sides + (k + 1) % sides
            c = (i + 1) * sides + (k + 1) % sides
            d = (i + 1) * sides + k
            T.append((a, b, c))
            T.append((a, c, d))
    for end, sign in ((0, -1.0), (n - 1, 1.0)):
        t = norm(centres[min(end + 1, n - 1)] - centres[max(end - 1, 0)]) * sign
        P.append(centres[end] + t * 0.001)
        N.append(t)
        C.append((rgb[0], rgb[1], rgb[2], open_ends))
        UV0.append((0.0 if end == 0 else along * uv_scale, 0.0))
        UV1.append((kind, seed))
        W.append(weights(centres[end], end / max(n - 1, 1)) if callable(weights) else dict(weights))
        e = len(P) - 1
        for k in range(sides):
            if end == 0:
                T.append(((k + 1) % sides, k, e))
            else:
                T.append((end * sides + k, end * sides + (k + 1) % sides, e))
    model.add(P, T, N, C, UV0, UV1, W)


def card(model, root, along, side, length, width, droop, weights, rng, segs=4, outward=None, rgb=FUR_WHITE, curl=0.0):
    """A lock of fur: a strip `width` wide at its root tapering to a point,
    `length` long along `along`, sagging by `droop` (down, at its tip), its
    flat facing out of the skin (`outward`)."""
    along = norm(along)
    side = norm(side - along * float(side @ along))
    up = np.cross(side, along)
    if outward is not None and float(up @ outward) < 0:
        up = -up
    seed = rng.random()
    tone = rng.uniform(-0.04, 0.02)
    # (a lock parts into two near its end, unless it is small or the model low)
    strands = [(0.0, 1.0, 0.0)] if segs <= 2 or width < 0.2 else [(-0.25, 0.55, -0.12), (0.25, 0.55, 0.12)]
    for offset, share, spread in strands:
        P, N, C, UV0, UV1, W = [], [], [], [], [], []
        for i in range(segs + 1):
            t = i / segs
            centre = root + side * width * offset * t + along * length * t - up * droop * t * t + side * (curl + spread * length) * t * t
            # (full near the root, the parted locks narrower, rounding off at the tip)
            w = width * lerp(1.0, share, smooth(0.2, 0.6, t)) * (1.0 - 0.8 * t ** 2.2)
            for k, x in enumerate((-1.0, 1.0)):
                P.append(centre + side * w * 0.5 * x)
                # (the flat, bent a little round its middle line, so it shades as a lock, not a ribbon)
                N.append(norm(up + side * 0.35 * x))
                open_ = 0.75 + 0.25 * smooth(0.0, 0.4, t)
                C.append((rgb[0] + tone, rgb[1] + tone, rgb[2] + tone * 0.8, open_))
                UV0.append((t, x))
                UV1.append((FUR, seed))
                W.append(dict(weights))
        # (a rounded end)
        tip = root + side * width * offset + along * length * 1.05 - up * droop * 1.1 + side * (curl + spread * length)
        P.append(tip)
        N.append(up)
        C.append((rgb[0] + tone, rgb[1] + tone, rgb[2] + tone * 0.8, 1.0))
        UV0.append((1.0, 0.0))
        UV1.append((FUR, seed))
        W.append(dict(weights))
        T = []
        for i in range(segs):
            a, b, c, d = i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2
            T.append((a, b, c))
            T.append((a, c, d))
        T.append((segs * 2, segs * 2 + 1, segs * 2 + 2))
        model.add(P, T, N, C, UV0, UV1, W)


# ---------------------------------------------------------------------------
# The head (on the head bone; the jaw on the jaw)

HEAD = {"head": 1.0}
JAW = {"jaw": 1.0}


def head_weights(p):
    """The head's own shapes, and where they meet the neck, the first spine bone too."""
    s = -p[2]
    if s > -0.2:
        return spine_weights(s)
    return dict(HEAD)


def raw_ellipsoid(c, r, R=np.eye(3), seg=24, rings=14):
    """An ellipsoid's points and triangles, to be fused with others."""
    c, r = V(c), V(r)
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
    return np.array(P), np.array(T)


def fuse(shapes, voxel, budget):
    """Overlapping shapes made one smooth surface (voxel remesh, smooth, decimate): its points, triangles and normals."""
    P_all, T_all, count = [], [], 0
    for P, T in shapes:
        P_all.append(P)
        T_all.append(T + count)
        count += len(P)
    P = np.concatenate(P_all)
    T = np.concatenate(T_all)
    mesh = bpy.data.meshes.new("part")
    mesh.from_pydata([to_b(p) for p in P], [], [tuple(int(i) for i in t) for t in T])
    mesh.update()
    obj = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(obj)
    remesh = obj.modifiers.new("remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    smoothing = obj.modifiers.new("smooth", "SMOOTH")
    smoothing.factor = 0.5
    smoothing.iterations = 14
    bpy.context.view_layer.update()
    dense = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    faces = len(dense.polygons) * 2
    bpy.data.meshes.remove(dense)
    decimate = obj.modifiers.new("decimate", "DECIMATE")
    decimate.ratio = min(1.0, budget / max(faces, 1))
    obj.modifiers.new("tri", "TRIANGULATE")
    bpy.context.view_layer.update()
    out = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(mesh)
    co = np.empty(len(out.vertices) * 3)
    out.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    P = np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)
    T = np.array([tuple(p.vertices) for p in out.polygons if len(p.vertices) == 3], dtype=int)
    bpy.data.meshes.remove(out)
    N = np.zeros_like(P)
    f = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
    for k in range(3):
        np.add.at(N, T[:, k], f)
    N = N / np.maximum(np.linalg.norm(N, axis=1), 1e-12)[:, None]
    return P, T, N


def add_fused(model, P, T, N, kind, rgb, weights, seed, shade_under=0.5):
    C, UV0, UV1, W = [], [], [], []
    for p, n in zip(P, N):
        under = smooth(0.1, -0.9, n[1]) * shade_under
        C.append((rgb[0] * (1 - 0.14 * under), rgb[1] * (1 - 0.14 * under), rgb[2] * (1 - 0.12 * under), 1.0 - 0.35 * under))
        UV0.append((p[2], math.atan2(p[1], p[0]) / math.tau))
        UV1.append((kind, seed))
        W.append(weights(p) if callable(weights) else dict(weights))
    model.add(P, T, N, C, UV0, UV1, W)


def build_head(model, low):
    I = np.eye(3)
    face = (0.89, 0.88, 0.86)
    seg, rings = (12, 7) if low else (24, 14)
    shapes = [
        # The cranium, high and round, and the neck it sits on.
        raw_ellipsoid((0, 0.36, 0.45), (1.0, 0.9, 1.02), I, seg, rings),
        raw_ellipsoid((0, 0.02, -0.35), (0.84, 0.8, 0.8), I, seg, rings),
        # A broad brow over a marked stop.
        raw_ellipsoid((0, 0.72, 1.02), (0.86, 0.46, 0.58), rot_x(0.2), seg, rings),
        # The muzzle: broad and deep, short, blunt.
        raw_ellipsoid((0, 0.14, 1.95), (0.72, 0.52, 0.9), rot_x(0.06), seg, rings),
        raw_ellipsoid((0, 0.08, 2.55), (0.6, 0.45, 0.52), I, seg, rings),
    ]
    for side in (1.0, -1.0):
        shapes += [
            # Wide cheeks, and soft hanging flews (the upper lips, as a hound's).
            raw_ellipsoid((side * 0.55, -0.02, 1.05), (0.38, 0.42, 0.72), rot_z(side * 0.2), seg, rings),
            raw_ellipsoid((side * 0.38, -0.18, 2.05), (0.3, 0.3, 0.82), rot_y(side * -0.12), seg, rings),
            # The brow ridge over each eye.
            raw_ellipsoid((side * 0.5, 0.8, 1.36), (0.33, 0.17, 0.3), rot_z(side * -0.35), seg, rings),
        ]
    P, T, N = fuse(shapes, 0.09 if low else 0.035, 1100 if low else 5200)
    add_fused(model, P, T, N, FACE, face, head_weights, 0.1)
    for side in (1.0, -1.0):
        # The eye: big, dark and wet, set forward under the brow.
        ellipsoid(model, (side * 0.57, 0.53, 1.56), (0.21, 0.18, 0.21), rot_y(side * 0.42) @ rot_x(math.pi / 2), EYE, (0.05, 0.04, 0.035), HEAD, low, 16, 10, seed=0.6)
    # The nose: a soft dark pad at the end of the muzzle.
    ellipsoid(model, (0, 0.24, 3.0), (0.34, 0.22, 0.2), rot_x(-0.25), NOSE, (0.2, 0.18, 0.18), HEAD, low, 16, 8, seed=0.7)
    # The lower jaw (a rounded chin tucked under the flews), and the mouth inside, dark.
    jaw = [raw_ellipsoid((0, -0.42, 1.35), (0.56, 0.24, 0.85), I, seg, rings),
           raw_ellipsoid((0, -0.38, 2.2), (0.4, 0.2, 0.5), I, seg, rings)]
    P, T, N = fuse(jaw, 0.09 if low else 0.035, 300 if low else 1300)
    add_fused(model, P, T, N, FACE, (0.84, 0.82, 0.8), JAW, 0.8, shade_under=0.8)
    ellipsoid(model, (0, -0.26, 1.85), (0.5, 0.12, 0.95), I, MOUTH, (0.22, 0.12, 0.12), HEAD, low, 12, 6, seed=0.9)


def build_ears(model, low):
    """Long soft hound's ears, hanging back and down from the top of the head."""
    rng = random.Random(11)
    for side, s in ((1.0, "_l"), (-1.0, "_r")):
        path = [V(side * 0.86, 0.82, 0.5), V(side * 1.15, 0.72, 0.0), V(side * 1.3, 0.35, -0.55), V(side * 1.3, -0.2, -1.1), V(side * 1.2, -0.62, -1.5)]
        pts = catmull(path, 6 if low else 12)
        widths = [0.36, 0.6, 0.66, 0.6, 0.48, 0.26]
        n = len(pts)
        P, N, C, UV0, UV1, W = [], [], [], [], [], []
        for i, p in enumerate(pts):
            t = i / (n - 1)
            w = np.interp(t, np.linspace(0, 1, len(widths)), widths)
            along = norm(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
            # (the ear's flat lies against the side of the head: across it runs mostly forward and back)
            out = norm(V(side, 0.0, 0.0) - along * float(V(side, 0, 0) @ along))
            across = np.cross(out, along)
            weight = {"ear1" + s: 1.0 - smooth(0.25, 0.7, t), "ear2" + s: smooth(0.25, 0.7, t)}
            for k in range(6):
                a = math.tau * k / 6
                q = p + across * math.cos(a) * w * 0.5 + out * math.sin(a) * 0.09
                P.append(q)
                N.append(norm(across * math.cos(a) * 0.4 + out * math.sin(a)))
                C.append((0.8, 0.78, 0.74, 0.75 + 0.25 * t))
                UV0.append((t, k / 6))
                UV1.append((FUR, 0.3 + 0.1 * side))
                W.append(weight)
        T = []
        for i in range(n - 1):
            for k in range(6):
                a = i * 6 + k
                b = i * 6 + (k + 1) % 6
                c = (i + 1) * 6 + (k + 1) % 6
                d = (i + 1) * 6 + k
                T.append((a, b, c))
                T.append((a, c, d))
        model.add(P, T, N, C, UV0, UV1, W)
        # Fur on the ear: a few soft locks along its lower edge.
        for i in range(2, n - 1, 1 if not low else 3):
            t = i / (n - 1)
            along = norm(pts[i + 1] - pts[i - 1])
            w = np.interp(t, np.linspace(0, 1, len(widths)), widths)
            weight = {"ear1" + s: 1.0 - smooth(0.25, 0.7, t), "ear2" + s: smooth(0.25, 0.7, t)}
            card(model, pts[i] + V(0, -w * 0.4, 0), along * 0.6 + V(0, -0.7, 0), V(side, 0, 0), 0.45, 0.22, 0.08, weight, rng, segs=2, outward=V(side, 0, 0))


def build_barbels(model, low):
    """Long barbels trailing from the corners of the lips, and a wisp from each brow."""
    for side, s in ((1.0, "_l"), (-1.0, "_r")):
        path = [V(side * 0.56, -0.1, 2.6), V(side * 1.15, -0.22, 2.45), V(side * 1.9, -0.5, 1.7), V(side * 2.35, -0.9, 0.5), V(side * 2.5, -1.3, -0.7)]
        pts = catmull(path, 8 if low else 16)
        n = len(pts)
        radii = [(r, r) for r in np.linspace(0.065, 0.012, n)]

        def weigh(p, t, s=s):
            share = smooth(0.15, 0.55, t)
            return {"barbel1" + s: 1.0 - share, "barbel2" + s: share}

        lofted(model, pts, radii, FACE, (0.88, 0.86, 0.82), weigh, 4 if low else 6, seed=0.95)
        brow = catmull([V(side * 0.62, 0.86, 1.3), V(side * 0.95, 1.05, 0.85), V(side * 1.3, 1.08, 0.2), V(side * 1.55, 0.95, -0.4)], 5 if low else 9)
        lofted(model, brow, [(r, r) for r in np.linspace(0.045, 0.01, len(brow))], FUR, FUR_WHITE, HEAD, 4 if low else 5, seed=0.97)


def build_mane(model, low):
    """Long white locks from the crown, the back of the head and the cheeks, streaming back down the neck."""
    rng = random.Random(5)
    count = 70 if low else 210
    for i in range(count):
        # (round the back half of the head, and on down the neck)
        u = rng.random()
        around = rng.uniform(-1.0, 1.0)
        if u < 0.45:
            # the crown and back of the head
            a = around * 1.05
            root = V(0.0, 0.36, 0.45) + V(math.sin(a) * 0.97, math.cos(a) * 0.86, rng.uniform(-0.85, -0.15))
            out = norm(V(math.sin(a), math.cos(a), -0.2))
        elif u < 0.53:
            # the cheeks: a ruff
            side = 1.0 if around > 0 else -1.0
            root = V(side * 0.95, rng.uniform(-0.4, 0.15), rng.uniform(0.0, 0.5))
            out = norm(V(side, -0.2, -0.3))
        else:
            # the neck: down its top and sides
            s = rng.uniform(0.0, 5.5)
            a = around * 1.25
            r = radius_at(s)
            root = V(math.sin(a) * r * 0.98, math.cos(a) * r * 0.9, -s)
            out = norm(V(math.sin(a), math.cos(a), 0.0))
        s_root = -root[2]
        weight = spine_weights(s_root) if s_root > 0.3 else dict(HEAD)
        length = rng.uniform(1.0, 1.9) * (0.8 if u >= 0.45 and u < 0.6 else 1.0)
        back = V(0, 0, -1.0)
        along = norm(back * 1.0 + out * rng.uniform(0.08, 0.3))
        side = np.cross(out, along)
        card(model, root, along, side, length, rng.uniform(0.3, 0.5), length * rng.uniform(0.3, 0.5), weight, rng,
             segs=3 if low else 5, outward=out, curl=rng.uniform(-0.15, 0.15))


def build_back_fur(model, low):
    """The soft ridge of fur down its back, thinning towards the tail, and the plume at its end."""
    rng = random.Random(7)
    step = 0.55 if low else 0.2
    s = 5.0
    while s < 30.6:
        r = radius_at(s)
        thin = smooth(4.0, 30.0, s)
        for a in ((-0.35, 0.0, 0.35) if not low else (0.0,)):
            a += rng.uniform(-0.12, 0.12)
            root = V(math.sin(a) * r * 0.97, math.cos(a) * r * 0.9, -s - rng.uniform(0, step))
            out = norm(V(math.sin(a), math.cos(a), 0.0))
            along = norm(V(0, 0, -1.0) + out * 0.5)
            side = np.cross(out, along)
            length = lerp(1.7, 0.7, thin) * rng.uniform(0.8, 1.15)
            card(model, root, along, side, length, lerp(0.62, 0.34, thin) * (1.5 if low else 1.0), length * 0.3,
                 spine_weights(-root[2]), rng, segs=2 if low else 3, outward=out)
        s += step
    # The plume at the tail's end: long locks all round it.
    count = 18 if low else 48
    for i in range(count):
        s = rng.uniform(29.4, 32.2)
        r = radius_at(s)
        a = rng.uniform(0, math.tau)
        root = V(math.cos(a) * r * 0.9, math.sin(a) * r * 0.9, -s)
        out = norm(V(math.cos(a), math.sin(a), 0.0))
        along = norm(V(0, 0, -1.0) + out * rng.uniform(0.15, 0.4))
        side = np.cross(out, along)
        length = rng.uniform(1.2, 2.1)
        card(model, root, along, side, length, rng.uniform(0.3, 0.45), length * 0.3, spine_weights(s), rng, segs=3 if low else 5, outward=out)


def build_legs(model, low):
    """Four short legs, each with three blunt toes, small dark claws and a tuft at the wrist."""
    rng = random.Random(9)
    for side, s in ((1.0, "_l"), (-1.0, "_r")):
        for leg, z in (("fore", FORE_AT), ("hind", HIND_AT)):
            r = radius_at(z)
            spine = spine_name(int(round(z / SEG)))
            root = V(side * r * 0.72, -r * 0.55, -z)
            elbow = root + V(side * 0.26, -0.6, 0.3)
            paw = elbow + V(side * 0.04, -0.38, 0.3)
            pts = catmull([root + V(-side * 0.1, 0.25, 0), root, elbow, paw], 6 if low else 12)
            radii = []
            for i in range(len(pts)):
                t = i / (len(pts) - 1)
                rr = float(np.interp(t, [0, 0.35, 0.7, 1.0], [0.46, 0.4, 0.27, 0.22]))
                radii.append((rr, rr * 1.05))
            one, two = leg + "1" + s, leg + "2" + s

            def weigh(p, t, spine=spine, one=one, two=two):
                if t < 0.25:
                    k = smooth(0.0, 0.25, t)
                    return {spine: 1.0 - k, one: k}
                k = smooth(0.55, 0.8, t)
                return {one: 1.0 - k, two: k}

            lofted(model, pts, radii, SCALES, (0.84, 0.83, 0.81), weigh, 7 if low else 12, seed=0.2)
            # The paw and its toes.
            ellipsoid(model, paw + V(0, -0.05, 0.12), (0.27, 0.15, 0.33), np.eye(3), FACE, (0.85, 0.84, 0.82), {two: 1.0}, low, 12, 6, seed=0.3)
            for k, (dx, dz) in enumerate(((-0.15, 0.34), (0.0, 0.4), (0.15, 0.34))):
                toe = paw + V(dx, -0.1, dz)
                ellipsoid(model, toe, (0.09, 0.08, 0.14), rot_y(dx * 1.5), FACE, (0.85, 0.84, 0.82), {two: 1.0}, low, 8, 5, seed=0.31)
                ellipsoid(model, toe + V(dx * 0.3, -0.03, 0.13), (0.05, 0.04, 0.07), rot_x(0.4), NOSE, (0.22, 0.2, 0.2), {two: 1.0}, low, 6, 4, seed=0.32)
            # A tuft of fur at the wrist, swept back, and soft fur down the back of the leg.
            for k in range(4 if low else 9):
                a = rng.uniform(-1.2, 1.2)
                at = elbow + V(side * math.cos(a) * 0.26, rng.uniform(-0.2, 0.1), math.sin(a) * 0.2 - 0.12)
                out = norm(V(side * math.cos(a), 0.1, -0.6))
                card(model, at, norm(V(0, -0.35, -1.0) + out * 0.3), np.cross(out, V(0, 0, -1)), rng.uniform(0.45, 0.7), 0.24, 0.12, {two: 0.5, one: 0.5}, rng, segs=2, outward=out)


def make_model(low):
    model = Model()
    stages = [("body", build_body), ("head", build_head), ("ears", build_ears), ("barbels", build_barbels),
              ("mane", build_mane), ("back fur", build_back_fur), ("legs", build_legs)]
    model.ranges = {}
    for name, step in stages:
        before = model.triangles()
        first = len(model.T)
        step(model, low)
        model.ranges[name] = (first, len(model.T))
        print("  %s: %d triangles" % (name, model.triangles() - before))
    return model


# ---------------------------------------------------------------------------
# Into Blender, and out as glTF

def make_armature():
    spec, order = bones()
    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for name in order:
        at, parent = spec[name]
        eb = data.edit_bones.new(name)
        eb.head = to_b(at)
        # (straight up, no roll: its rest is the identity in Godot)
        eb.tail = to_b(at + V(0, 0.2, 0))
        eb.roll = 0.0
    for name in order:
        parent = spec[name][1]
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
            data.edit_bones[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature, order


def make_mesh(model, name, armature, names, material):
    T = np.concatenate(model.T)
    P = np.concatenate(model.P)
    N = np.concatenate(model.N)
    N = N / np.maximum(np.linalg.norm(N, axis=1), 1e-12)[:, None]
    C = np.concatenate(model.C)
    UV0 = np.concatenate(model.UV0)
    UV1 = np.concatenate(model.UV1)
    # (every triangle wound to face the way its vertices' normals do)
    face = np.cross(P[T[:, 1]] - P[T[:, 0]], P[T[:, 2]] - P[T[:, 0]])
    flip = np.einsum("ij,ij->i", face, N[T[:, 0]] + N[T[:, 1]] + N[T[:, 2]]) < 0.0
    T[flip] = T[flip][:, ::-1]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_b(p) for p in P], [], [tuple(int(i) for i in t) for t in T])
    mesh.update()
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    col.data.foreach_set("color", np.clip(C, 0.0, 1.0).astype(np.float32).ravel())
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
    groups = {b: body.vertex_groups.new(name=b) for b in names}
    for i, w in enumerate(model.W):
        total = sum(w.values())
        for bone, value in w.items():
            if value > 0.001:
                groups[bone].add([i], float(value / total), "REPLACE")
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
    armature, names = make_armature()
    material = bpy.data.materials.new("luck_dragon")
    body = make_mesh(hi, "luck_dragon", armature, names, material)
    lo_body = make_mesh(lo, "luck_dragon_lo", armature, names, material)
    os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
    path = os.path.join(FOLDER, "models", "luck_dragon.glb")
    options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=True,
                   export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True)
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)
    print("BUILT", path)
    if PREVIEW_DIR:
        lo_body.hide_render = True
        previews("luck_dragon")
        body.hide_render = True
        lo_body.hide_render = False
        previews("lo", wholes_only=True)


def previews(name, wholes_only=False):
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
    camera = scene.camera
    if camera is None:
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        scene.collection.objects.link(camera)
        scene.camera = camera
    camera.data.lens = 50
    camera.data.clip_end = 500
    views = [("whole_side", V(1, 0.2, 0), V(0, 0, -14.5), 48.0), ("whole_top", V(0.05, 1, 0), V(0, 0, -14.5), 48.0),
             ("front_quarter", V(0.8, 0.3, 1), V(0, 0, -2.0), 12.0),
             ("head_front", V(0, 0.1, 1), V(0, 0.2, 1.4), 6.5), ("head_quarter", V(0.8, 0.2, 0.8), V(0, 0.2, 1.2), 7.0),
             ("head_side", V(1, 0.05, 0.05), V(0, 0.1, 0.8), 7.5), ("leg", V(0.8, -0.2, 0.5), V(1.3, -1.6, -6.0), 5.0),
             ("tail", V(0.7, 0.4, -0.6), V(0, 0, -30.0), 9.0)]
    for view, direction, target, far in views:
        if wholes_only and not view.startswith("whole") and view != "head_quarter":
            continue
        offset = np.array(to_b(norm(direction) * far))
        t = np.array(to_b(target))
        from mathutils import Vector
        camera.location = Vector(t + offset)
        camera.rotation_euler = Vector(-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    build()

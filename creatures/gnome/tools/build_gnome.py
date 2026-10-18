"""Builds the gnome and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/gnome/tools/build_gnome.py [-- <preview folder>]

Writes creatures/gnome/models/gnome.glb and gnome_lo.glb (skinned, for Gnome);
given a folder, renders previews into it.

What it models round is the skeleton Gnome (creatures/gnome/gnome.gd) works out
for itself as it stands, written out by rest_joints.gd into rest_gnome.json
beside this file (its own units; Godot's axes: Y up, facing +Z, +X its left).
Everything is in those units and axes here, and turned to Blender's (Z up)
only as it is made.

- The body is the Skin modifier over a stick figure of the skeleton (a paunch,
  narrow sloping shoulders, short arms with big knobbly hands, four stubby
  fingers and a thumb; short bowed legs), smoothed with a Subdivision Surface:
  it is the coat down to the wrists and the waist, trousers below, skin at the
  hands. Over it: the coat's skirts flaring to the knee, a belt with a buckle,
  cuffs, and pointed boots turned up at the toe.
- The head: a big skull, a heavy brow with bushy grey brows over little eyes
  sunk deep (wet dark beads), a great bulbous nose, heavy cheeks, long drooping
  ears; a drooping moustache, and a long matted beard from ear to ear tapering
  to a point at the belly; a tall pointed hat, crumpled, sitting low over the
  brow, on three bones so that its tip flops.
- Colours are vertex colours. The first UV is the part (x: skin 0, coat 0.25,
  plain 0.38, hat 0.5, beard 0.75, eyes 1) and how wet it is (y); the second
  where the point was on the standing body (for the shader's wrinkles and weave).
- The skeleton is Gnome.BONES, none the child of another, each where Gnome puts
  it as it stands. Every vertex is weighted by how near it is to each bone (two
  or three at most); the head's parts go to the head, the hat's and the beard's
  to theirs.
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

SKIN = (0.2, 0.172, 0.152)
SKIN_DARK = (0.14, 0.1, 0.08)
NOSE = (0.215, 0.168, 0.15)
BEARD = (0.27, 0.26, 0.235)
BEARD_DARK = (0.22, 0.2, 0.18)
HAT = (0.15, 0.09, 0.075)
COAT = (0.11, 0.105, 0.085)
TROUSERS = (0.05, 0.04, 0.034)
BOOT = (0.025, 0.018, 0.014)
BELT = (0.13, 0.1, 0.08)
BUCKLE = (0.4, 0.38, 0.33)
EYE = (0.03, 0.025, 0.02)
SOCKET = (0.05, 0.035, 0.03)
EAR_IN = (0.21, 0.16, 0.14)

P_SKIN, P_COAT, P_PLAIN, P_HAT, P_BEARD, P_EYE = 0.0, 0.25, 0.38, 0.5, 0.75, 1.0


def V(p):
    return Vector((p[0], p[1], p[2]))


def to_b(p):
    return Vector((p.x, -p.z, p.y))


def from_b(p):
    return Vector((p.x, p.z, -p.y))


def xform(d):
    b = d["basis"]
    return Matrix((
        (b[0][0], b[1][0], b[2][0], d["origin"][0]),
        (b[0][1], b[1][1], b[2][1], d["origin"][1]),
        (b[0][2], b[1][2], b[2][2], d["origin"][2]),
        (0, 0, 0, 1)))


def basis3(b):
    return Matrix(((b[0][0], b[1][0], b[2][0]), (b[0][1], b[1][1], b[2][1]), (b[0][2], b[1][2], b[2][2])))


def smooth(a, b, x):
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def dist_segment(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def along_segment(p, a, b):
    ab = b - a
    return 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))


def hashf(x, y, z=0.0):
    v = math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453
    return v - math.floor(v)


def vnoise(x, y):
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hashf(ix, iy), hashf(ix + 1, iy)
    c, d = hashf(ix, iy + 1), hashf(ix + 1, iy + 1)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy


class Model:
    """The mesh as it is put together: one bmesh, with per-vertex data."""

    def __init__(self, bones):
        self.bm = bmesh.new()
        self.uv0 = self.bm.loops.layers.uv.new("UVMap")
        self.uv1 = self.bm.loops.layers.uv.new("UV2")
        self.col = self.bm.verts.layers.float_color.new("Col")
        self.deform = self.bm.verts.layers.deform.verify()
        self.bones = bones
        self.vert_uv = []

    def add(self, mesh, info):
        """Adds a Blender mesh (Blender's axes). info(index, godot_position, godot_normal) ->
        (colour, uv0, uv1, {bone: weight})."""
        made = []
        for v in mesh.vertices:
            nv = self.bm.verts.new(v.co)
            colour, uv0, uv1, weights = info(v.index, from_b(v.co), from_b(v.normal))
            nv[self.col] = (colour[0], colour[1], colour[2], 1.0)
            total = sum(weights.values()) or 1.0
            for bone, w in weights.items():
                if w / total > 0.001:
                    nv[self.deform][self.bones.index(bone)] = w / total
            made.append(nv)
            self.vert_uv.append((uv0, uv1))
        base = len(self.vert_uv) - len(made)
        for poly in mesh.polygons:
            try:
                face = self.bm.faces.new([made[i] for i in poly.vertices])
            except ValueError:
                continue
            face.smooth = True
            for loop, i in zip(face.loops, poly.vertices):
                uv0, uv1 = self.vert_uv[base + i]
                loop[self.uv0].uv = (uv0[0], 1.0 - uv0[1])  # (glTF turns V over)
                loop[self.uv1].uv = (uv1[0], 1.0 - uv1[1])
        return base


def mesh_from_bm(bm):
    mesh = bpy.data.meshes.new("part")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def evaluated(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    bpy.data.objects.remove(obj)
    return mesh


def subdivided(mesh, levels):
    if levels <= 0:
        return mesh
    obj = bpy.data.objects.new("part", mesh)
    bpy.context.collection.objects.link(obj)
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return evaluated(obj)


def skinned(points, edges, radii, root, levels):
    """A Skin-modifier surface over a stick figure (Godot points), smoothed."""
    bm = bmesh.new()
    verts = [bm.verts.new(to_b(p)) for p in points]
    for a, b in edges:
        bm.edges.new((verts[a], verts[b]))
    mesh = mesh_from_bm(bm)
    obj = bpy.data.objects.new("skin", mesh)
    bpy.context.collection.objects.link(obj)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    skin.use_smooth_shade = True
    for i, r in enumerate(radii):
        rx, ry = (r, r) if not isinstance(r, tuple) else r
        mesh.skin_vertices[0].data[i].radius = (rx, ry)
        mesh.skin_vertices[0].data[i].use_root = i == root
    if levels > 0:
        sub = obj.modifiers.new("Subsurf", "SUBSURF")
        sub.levels = levels
        sub.render_levels = levels
    return evaluated(obj)


def ellipsoid(centre, basis, radii, segments=16, rings=10):
    """A UV sphere (Godot space: centre, a 3x3 basis, radii)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        local = Vector((v.co.x * radii[0], v.co.z * radii[1], -v.co.y * radii[2]))
        v.co = to_b(centre + basis @ local)
    return mesh_from_bm(bm)


def tube(points, radii, sides=6, closed_end=True, closed_start=True):
    """A tube along a polyline of Godot points, a radius at each, its end closed to a point."""
    bm = bmesh.new()
    rings = []
    n = len(points)
    prev_across = None
    for i, p in enumerate(points):
        ahead = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
        across = ahead.cross(Vector((0, 1, 0))) if prev_across is None else prev_across - ahead * prev_across.dot(ahead)
        if across.length < 1e-6:
            across = ahead.cross(Vector((1, 0, 0)))
        across.normalize()
        prev_across = across
        lift = ahead.cross(across).normalized()
        r = radii[i]
        if i == n - 1 and closed_end:
            rings.append([bm.verts.new(to_b(p))])
            continue
        rings.append([bm.verts.new(to_b(p + (across * math.cos(a) + lift * math.sin(a)) * r)) for a in [math.tau * k / sides for k in range(sides)]])
    for i in range(n - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(sides):
            if len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % sides], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if closed_start and len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    return mesh_from_bm(bm)


def loft(rings_pts, closed_end=True, closed_start=False):
    """A tube through rings of Godot points (each a list, all the same length)."""
    bm = bmesh.new()
    grid = [[bm.verts.new(to_b(p)) for p in ring] for ring in rings_pts]
    n = len(grid[0])
    for i in range(len(grid) - 1):
        for k in range(n):
            bm.faces.new((grid[i][k], grid[i][(k + 1) % n], grid[i + 1][(k + 1) % n], grid[i + 1][k]))
    if closed_end:
        tip = sum((p for p in rings_pts[-1]), Vector()) / n
        prev = sum((p for p in rings_pts[-2]), Vector()) / n
        centre = bm.verts.new(to_b(tip + (tip - prev).normalized() * 0.002))
        for k in range(n):
            bm.faces.new((grid[-1][k], grid[-1][(k + 1) % n], centre))
    if closed_start:
        bm.faces.new(list(reversed(grid[0])))
    return mesh_from_bm(bm)


def sheet(grid_pts, thickness, normal_of):
    """A thin two-sided sheet: a grid of Godot points, given thickness along normal_of(point)."""
    bm = bmesh.new()
    rows, cols = len(grid_pts), len(grid_pts[0])
    front = [[bm.verts.new(to_b(p + normal_of(p) * thickness * 0.5)) for p in row] for row in grid_pts]
    back = [[bm.verts.new(to_b(p - normal_of(p) * thickness * 0.5)) for p in row] for row in grid_pts]
    for i in range(rows - 1):
        for k in range(cols - 1):
            bm.faces.new((front[i][k], front[i][k + 1], front[i + 1][k + 1], front[i + 1][k]))
            bm.faces.new((back[i][k], back[i + 1][k], back[i + 1][k + 1], back[i][k + 1]))
    edge = [(i, 0) for i in range(rows)] + [(rows - 1, k) for k in range(1, cols)] + [(i, cols - 1) for i in range(rows - 2, -1, -1)] + [(0, k) for k in range(cols - 2, 0, -1)]
    for e in range(len(edge)):
        a, b = edge[e], edge[(e + 1) % len(edge)]
        try:
            bm.faces.new((front[a[0]][a[1]], back[a[0]][a[1]], back[b[0]][b[1]], front[b[0]][b[1]]))
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    return mesh_from_bm(bm)


class Gnome:
    def __init__(self, detail):
        """detail: "hi" (gnome.glb) or "lo" (gnome_lo.glb)."""
        self.detail = detail
        self.hi = detail == "hi"
        with open(os.path.join(HERE, "rest_gnome.json")) as f:
            self.j = json.load(f)
        j = self.j
        self.bones = j["bones"]
        self.levels = 2 if self.hi else 1
        self.model = Model(self.bones)
        self.torso = basis3(j["torso"])
        self.side = V(j["torso"][0])
        self.spine = V(j["torso"][1])
        self.front = V(j["torso"][2])
        self.head = xform(j["head_xform"])
        self.H = self.head.to_3x3().normalized()
        self.rng_state = 29
        self.segments = {}
        pel, bel, che, nec = V(j["pelvis"]), V(j["belly"]), V(j["chest"]), V(j["neck"])
        self.segments["hips"] = (pel - self.spine * 0.06, pel)
        self.segments["belly"] = (pel, bel)
        self.segments["chest"] = (bel, che)
        self.segments["neck"] = (che, nec)
        self.segments["head"] = (nec, V(j["head_xform"]["origin"]))
        for i, s in enumerate(["l", "r"]):
            self.segments["arm_" + s] = (V(j["roots"][i]), V(j["mids"][i]))
            self.segments["forearm_" + s] = (V(j["mids"][i]), V(j["ends"][i]))
            wrist, knuckle = V(j["ends"][i]), V(j["knuckles"][i])
            hand_y = basis3(j["hands"][i]).col[1]
            self.segments["hand_" + s] = (wrist, knuckle)
            self.segments["fingers_" + s] = (knuckle, knuckle + hand_y * 0.05)
            self.segments["thigh_" + s] = (V(j["roots"][i + 2]), V(j["mids"][i + 2]))
            self.segments["shin_" + s] = (V(j["mids"][i + 2]), V(j["ends"][i + 2]))
            self.segments["foot_" + s] = (V(j["ends"][i + 2]), V(j["balls"][i]))
        hat = [V(p) for p in j["hat"]]
        for k in range(3):
            self.segments["hat_%d" % (k + 1)] = (hat[k], hat[k + 1])
        beard = [V(p) for p in j["beard"]]
        self.segments["beard_1"] = (beard[0], beard[1])
        self.segments["beard_2"] = (beard[1], beard[2])
        self.body_bones = [b for b in self.bones if not (b.startswith("hat") or b.startswith("beard"))]

    def rand(self):
        self.rng_state = (self.rng_state * 1103515245 + 12345) % 2147483648
        return self.rng_state / 2147483648.0

    def uniform(self, a, b):
        return a + (b - a) * self.rand()

    def h(self, x, y, z):
        return self.head @ Vector((x, y, z))

    def nearest(self, p, among=None, count=3):
        found = []
        for bone, (a, b) in self.segments.items():
            if among is not None and bone not in among:
                continue
            found.append((dist_segment(p, a, b), bone))
        found.sort()
        found = found[:count]
        weights = {}
        for d, bone in found:
            weights[bone] = 1.0 / (d ** 4 + 1e-10)
        best = max(weights.values())
        return {k: w for k, w in weights.items() if w > best * 0.02}

    @staticmethod
    def noise_uv(p):
        return (p.x * 2.0 + p.z * 1.4, p.y * 2.0 + p.z * 0.7)

    def put(self, mesh, colour, weights, uv0=(0.0, 0.0)):
        # (every part faces outwards, however its rings were wound: the shader culls back faces)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()

        def info(i, p, n):
            c = colour(p, n) if callable(colour) else colour
            w = weights(p) if callable(weights) else weights
            u = uv0(p, n) if callable(uv0) else uv0
            return c, u, self.noise_uv(p), w
        self.model.add(mesh, info)
        bpy.data.meshes.remove(mesh)

    # --- The body ---

    def body(self):
        j = self.j
        P = lambda k: V(j[k])
        points, radii, edges = [], [], []

        def add(p, r, link=None):
            points.append(p)
            radii.append(r)
            if link is not None:
                edges.append((link, len(points) - 1))
            return len(points) - 1

        pel, bel, che, nec = P("pelvis"), P("belly"), P("chest"), P("neck")
        hd = V(j["head_xform"]["origin"])
        sp, fr, sd = self.spine, self.front, self.side
        t0 = add(pel - sp * 0.04, 0.09)
        pv = add(pel, 0.108, t0)
        b1 = add(pel.lerp(bel, 0.5) + fr * 0.015, 0.128, pv)
        bl = add(bel + fr * 0.022, 0.13, b1)
        c1 = add(bel.lerp(che, 0.55) + fr * 0.01, 0.115, bl)
        ch = add(che, 0.1, c1)
        sh = add(che + sp * 0.025, 0.085, ch)
        nk = add(nec, 0.065, sh)
        add(nec.lerp(hd, 0.55), 0.07, nk)
        self.hand_tips = []
        for i in range(4):
            arm = i < 2
            sign = 1.0 if i % 2 == 0 else -1.0
            root, mid, end = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            if arm:
                a = add(root, 0.045, sh)
                a2 = add(root.lerp(mid, 0.5), 0.036, a)
                m = add(mid, 0.033, a2)
                m2 = add(mid.lerp(end, 0.5), 0.032, m)
                e = add(end, 0.026, m2)
                hand = basis3(j["hands"][i])
                hy, hx, hz = hand.col[1], hand.col[0], hand.col[2]
                palm = add(end + hy * 0.028, 0.026, e)
                knuckle = V(j["knuckles"][i])
                # Four stubby knobbly fingers, a little curled, and a thumb.
                for f, fan in enumerate([-0.36, -0.12, 0.12, 0.36]):
                    way = (hy * math.cos(fan * 0.5) + hx * math.sin(fan * 0.5) * sign).normalized()
                    at = knuckle + hx * fan * 0.05 * sign
                    last = add(at, 0.0105, palm)
                    for k, length in enumerate((0.022, 0.018, 0.014)):
                        way = (way - hz * 0.18).normalized()
                        at = at + way * length
                        last = add(at, 0.0098 - k * 0.0012 + (0.0012 if k == 0 else 0.0), last)
                tway = (hy * 0.5 + hz * 0.7 + hx * sign * 0.2).normalized()
                t1 = add(end + hy * 0.02 + hz * 0.016, 0.011, palm)
                tat = end + hy * 0.02 + hz * 0.016 + tway * 0.022
                t2 = add(tat, 0.0095, t1)
                add(tat + tway * 0.016, 0.008, t2)
            else:
                a = add(root, 0.056, pv)
                a2 = add(root.lerp(mid, 0.5), 0.045, a)
                m = add(mid, 0.036, a2)
                m2 = add(mid.lerp(end, 0.5), 0.032, m)
                add(end, 0.03, m2)
        mesh = skinned(points, edges, radii, pv, self.levels)
        self.shape_body(mesh)

        def colour(p, n):
            return self.body_colour(p, n)[0]

        def uv(p, n):
            return (self.body_colour(p, n)[1], 0.05)
        self.put(mesh, colour, lambda p: self.nearest(p, self.body_bones, 3), uv)
        self.skirts()

        self.cuffs()
        self.boots()

    def body_colour(self, p, n):
        """(colour, part) of the body at a point: skin at the hands, the coat above the
        waist and down the arms, trousers below."""
        j = self.j
        for i in range(2):
            wrist = V(j["ends"][i])
            elbow = V(j["mids"][i])
            way = (wrist - elbow).normalized()
            if (p - wrist).dot(way) > -0.008 and (p - wrist).length < 0.12:
                return mix(SKIN, SKIN_DARK, 0.3 * smooth(0.0, 1.0, -n.y)), P_SKIN
        if p.y < V(j["pelvis"]).y - 0.02:
            return TROUSERS, P_PLAIN
        return COAT, P_COAT

    def shape_body(self, mesh):
        """The paunch pushed out round and low, the shoulders sloping, the back bowed."""
        j = self.j
        bel = V(j["belly"])
        fr = self.front
        belly_at = bel + fr * 0.07 - self.spine * 0.02
        for v in mesh.vertices:
            p = from_b(v.co)
            n = from_b(v.normal).normalized()
            push = 0.0
            d = (p - belly_at).length
            push += 0.03 * math.exp(-(d / 0.09) ** 2) * max(0.0, n.dot(fr) * 0.8 + 0.3)
            # (a bowed old back: the shoulders hunched up behind)
            back = (p - (V(j["chest"]) - fr * 0.06 + self.spine * 0.02)).length
            push += 0.018 * math.exp(-(back / 0.07) ** 2) * max(0.0, -n.dot(fr))
            # (lumpy, as old cloth is)
            push += (vnoise(p.x * 40.0 + p.z * 13.0, p.y * 40.0) - 0.5) * 0.004
            v.co = to_b(p + n * push)
        mesh.update()

    def skirts(self):
        """The coat's skirts, from the waist flaring to the knee, a slit at the back, the hem ragged."""
        j = self.j
        pel = V(j["pelvis"])
        knee_y = (V(j["mids"][2]).y + V(j["mids"][3]).y) * 0.5
        top = pel.y + 0.04
        bottom = knee_y - 0.005
        ring_count, sides = (9, 28) if self.hi else (6, 16)
        rings = []
        for r in range(ring_count):
            t = r / (ring_count - 1)
            y = top + (bottom - top) * t
            ring = []
            for k in range(sides):
                a = math.tau * k / sides
                cx, cz = math.sin(a), math.cos(a)
                wide = 0.112 + 0.06 * t ** 1.2
                deep = 0.106 + 0.06 * t ** 1.2
                # (the back's slit gapes a little at the hem; the hem is ragged)
                gape = 0.012 * t * math.exp(-((a - math.pi) / 0.25) ** 2)
                rag = (vnoise(a * 5.0, 3.1) - 0.5) * 0.02 * t ** 3
                fold = 0.006 * math.sin(a * 7.0) * t
                ring.append(Vector((pel.x + cx * (wide + fold), y + rag, pel.z + 0.01 + cz * (deep + fold) - gape)))
            rings.append(ring)
        mesh = subdivided(loft(rings, closed_end=False), 1 if self.hi else 0)

        def weights(p):
            t = smooth(top, bottom, p.y)
            w = {"hips": 1.0 - t * 0.8 + 0.01}
            side = "l" if p.x > 0 else "r"
            w["thigh_" + side] = t * 0.9 + 0.01
            w["belly"] = 0.2 * (1.0 - t)
            return w

        def colour(p, n):
            return mix(COAT, (0.07, 0.07, 0.06), smooth(top - 0.04, bottom, p.y) * 0.35)
        self.put(mesh, colour, weights, (P_COAT, 0.05))

    def belt(self):
        j = self.j
        pel = V(j["pelvis"])
        y = pel.y + 0.06
        pts = []
        steps = 24 if self.hi else 14
        for k in range(steps + 1):
            a = math.tau * k / steps
            pts.append(Vector((math.sin(a) * 0.124, y, pel.z + 0.025 + math.cos(a) * 0.118)))
        self.put(tube(pts, [0.014] * len(pts), 5, closed_end=False, closed_start=False), BELT, lambda p: self.nearest(p, ["hips", "belly"], 2), (P_PLAIN, 0.1))
        buckle_at = Vector((0.0, y, pel.z + 0.025 + 0.13))
        self.put(ellipsoid(buckle_at, self.torso, Vector((0.026, 0.022, 0.008)), 10, 6), BUCKLE, {"belly": 1.0}, (P_PLAIN, 0.4))

    def cuffs(self):
        j = self.j
        for i in range(2):
            wrist, elbow = V(j["ends"][i]), V(j["mids"][i])
            way = (wrist - elbow).normalized()
            pts = [wrist - way * 0.03, wrist - way * 0.008, wrist]
            self.put(tube(pts, [0.038, 0.04, 0.036], 10, closed_end=False, closed_start=False),
                     mix(COAT, (0.07, 0.07, 0.06), 0.4), {"forearm_" + ("l" if i == 0 else "r"): 1.0}, (P_COAT, 0.05))

    def boots(self):
        """Pointed boots, the toes turned up, a cuff round the top."""
        j = self.j
        for i in range(2):
            s = "l" if i == 0 else "r"
            ankle = V(j["ends"][i + 2])
            ball = V(j["balls"][i])
            heel = Vector((ankle.x, 0.025, ankle.z - 0.025))
            ahead = Vector((0.0, 0.0, 1.0))
            toe = ball + ahead * 0.06 + Vector((0, 0.035, 0))
            pts = [heel - ahead * 0.012, heel + ahead * 0.02, ball.lerp(heel, 0.4) + Vector((0, 0.008, 0)), ball + Vector((0, 0.02, 0)),
                   ball + ahead * 0.035 + Vector((0, 0.022, 0)), toe]
            radii = [0.03, 0.036, 0.035, 0.031, 0.02, 0.0]
            mesh = tube(pts, radii, 12 if self.hi else 8)
            # (flattened underneath to stand on)
            for v in mesh.vertices:
                p = from_b(v.co)
                if p.y < 0.0:
                    p.y = 0.0
                v.co = to_b(p)
            self.put(mesh, BOOT, lambda p, s=s: {"foot_" + s: 1.0, "shin_" + s: 0.15}, (P_PLAIN, 0.15))
            shaft = [ankle - Vector((0, 0.012, 0)), ankle + Vector((0, 0.035, 0)), ankle + Vector((0, 0.06, 0.005))]
            self.put(tube(shaft, [0.034, 0.036, 0.04], 10, closed_end=False, closed_start=True), BOOT,
                     lambda p, s=s: self.nearest(p, ["shin_" + s, "foot_" + s], 2), (P_PLAIN, 0.15))

    # --- The head ---

    def head_parts(self):
        H = self.H
        HEAD = {"head": 1.0}
        sub = 1 if self.hi else 0
        to_head = self.head.inverted()

        def skin(p, n):
            local = to_head @ p
            dark = 0.25 * smooth(0.0, 0.12, local.y) + 0.2 * vnoise(local.x * 50.0, local.y * 50.0)
            return mix(SKIN, SKIN_DARK, dark)

        # The skull: big, a little long, flattened at the sides.
        self.put(subdivided(ellipsoid(self.h(0.0, 0.012, -0.012), H, Vector((0.13, 0.145, 0.138)), 22, 14), sub), skin, HEAD)
        # Heavy cheeks and jowls.
        for s in (1.0, -1.0):
            self.put(ellipsoid(self.h(0.064 * s, -0.035, 0.078), H @ Matrix.Rotation(0.3 * s, 3, "Y"), Vector((0.045, 0.04, 0.045)), 14, 9), skin, HEAD)
        # The brow: a heavy ridge over sunken eyes, one over each, knitted in the middle.
        for s in (1.0, -1.0):
            tilt = H @ Matrix.Rotation(-0.25 * s, 3, "Z") @ Matrix.Rotation(0.35 * s, 3, "Y")
            self.put(ellipsoid(self.h(0.042 * s, 0.03, 0.112), tilt, Vector((0.045, 0.019, 0.03)), 14, 8), skin, HEAD)
        # Little eyes, sunk deep under the brow: dark wet beads, a heavy lid over each, bags under.
        for s in (1.0, -1.0):
            self.put(ellipsoid(self.h(0.044 * s, 0.006, 0.112), H, Vector((0.017, 0.012, 0.01)), 12, 8), SOCKET, HEAD, (P_SKIN, 0.1))
            self.put(ellipsoid(self.h(0.044 * s, 0.006, 0.117), H, Vector((0.0095, 0.0085, 0.007)), 10, 8), EYE, HEAD, (P_EYE, 1.0))
            self.put(ellipsoid(self.h(0.044 * s, 0.015, 0.117), H @ Matrix.Rotation(-0.25 * s, 3, "Z"), Vector((0.017, 0.007, 0.011)), 12, 6), skin, HEAD)
            self.put(ellipsoid(self.h(0.046 * s, -0.008, 0.117), H, Vector((0.017, 0.007, 0.009)), 10, 6), mix(SKIN, SKIN_DARK, 0.5), HEAD)
        # Bushy grey brows: heavy tufts jutting out and drooping over the eyes, wild at the ends.
        for s in (1.0, -1.0):
            count = 4 if self.hi else 2
            for k in range(count):
                u = k / (count - 1)
                base = self.h(s * (0.018 + 0.05 * u), 0.036 + 0.006 * math.sin(u * math.pi), 0.124 - 0.028 * u * u)
                way = H @ Vector((s * (0.3 + 0.7 * u), -0.15 + 0.35 * u + self.uniform(-0.1, 0.1), 0.9 - 0.4 * u)).normalized()
                long = 0.03 + 0.012 * u + self.uniform(-0.004, 0.004)
                mid = base + way * long * 0.5 + Vector((0, 0.004, 0))
                tip = base + way * long + Vector((0, -0.014, 0))
                self.put(tube([base, mid, tip], [0.017, 0.014, 0.004], 7 if self.hi else 5), mix(BEARD, BEARD_DARK, 0.45), HEAD, (P_BEARD, 0.0))
        # The nose: a great bulb on a short bridge, its tip hanging, nostrils flared.
        self.put(tube([self.h(0.0, 0.03, 0.125), self.h(0.0, 0.0, 0.15), self.h(0.0, -0.025, 0.162)], [0.02, 0.027, 0.03], 10), NOSE, HEAD)
        self.put(subdivided(ellipsoid(self.h(0.0, -0.038, 0.17), H, Vector((0.042, 0.04, 0.04)), 16, 10), sub), NOSE, HEAD, (P_SKIN, 0.25))
        for s in (1.0, -1.0):
            self.put(ellipsoid(self.h(0.03 * s, -0.052, 0.155), H, Vector((0.02, 0.016, 0.02)), 10, 7), NOSE, HEAD)
            # (a wart on one side)
        self.put(ellipsoid(self.h(0.032, -0.022, 0.198), H, Vector((0.006, 0.006, 0.006)), 8, 6), mix(NOSE, SKIN_DARK, 0.5), HEAD)
        # Long ears, drooping, fleshy.
        rows, cols = (12, 7) if self.hi else (7, 5)
        for s in (1.0, -1.0):
            root = self.h(0.128 * s, 0.0, -0.01)
            out = H @ Vector((0.75 * s, -0.55, -0.35)).normalized()
            width = H @ Vector((0.0, 0.85, -0.5)).normalized()
            face = out.cross(width).normalized()
            if face.dot(H.col[2]) < 0:
                face = -face
            grid = []
            for r in range(rows):
                t = r / (rows - 1)
                half = 0.045 * math.sin(math.pi * min(0.15 + t * 0.95, 1.0)) * (1.0 - 0.6 * t) + 0.004
                row = []
                for c in range(cols):
                    v = (c / (cols - 1)) * 2.0 - 1.0
                    cup = -0.015 * (1.0 - v * v) * math.sin(math.pi * t)
                    droop = -0.03 * t * t
                    row.append(root + out * (0.11 * t) + width * (half * v) + face * cup + Vector((0, droop, 0)))
                grid.append(row)
            mesh = sheet(grid, 0.014, lambda p, face=face: face)
            if self.hi:
                mesh = subdivided(mesh, 1)
            self.put(mesh, lambda p, n, face=face: mix(SKIN, EAR_IN, smooth(-0.2, 0.5, n.dot(face)) * 0.6), HEAD)
        self.moustache()
        self.beard()
        self.hat()

    def moustache(self):
        """A heavy drooping moustache, in two clumps from under the nose down into the beard."""
        for s in (1.0, -1.0):
            for k in range(2 if self.hi else 1):
                o = 0.012 * k
                pts = [self.h(s * (0.012 + o), -0.07 - o * 0.5, 0.168), self.h(s * (0.048 + o), -0.088, 0.165 - o),
                       self.h(s * (0.078 + o), -0.122, 0.146 - o), self.h(s * (0.088 + o), -0.165 - o, 0.13 - o), self.h(s * (0.082 + o), -0.205 - o, 0.118)]
                self.put(tube(pts, [0.02 - o * 0.4, 0.024 - o * 0.5, 0.019, 0.01, 0.0], 8 if self.hi else 6), mix(BEARD, BEARD_DARK, 0.2 * k),
                         lambda p: {"head": 0.7, "beard_1": 0.3}, (P_BEARD, 0.0))

    def beard(self):
        """A long beard from ear to ear, matted into clumps, tapering to a point at the belly."""
        j = self.j
        H = self.H
        beard = [V(p) for p in j["beard"]]
        to_head = self.head.inverted()
        ring_count, sides = (16, 30) if self.hi else (9, 16)
        rings = []
        # (it grows from the whole jaw, ear to ear, round under the cheeks)
        top = self.h(0.0, -0.025, 0.02)
        for r in range(ring_count):
            t = r / (ring_count - 1)
            # (down the beard's two bones, from the jaw)
            if t < 0.45:
                centre = top.lerp(beard[1], t / 0.45)
            else:
                centre = beard[1].lerp(beard[2], (t - 0.45) / 0.55)
            # (full under the face, then tapering to a point)
            fullness = (0.62 + 0.38 * math.sin(0.5 * math.pi * t / 0.3)) if t < 0.3 else (1.0 - (t - 0.3) / 0.7) ** 0.8
            wide = 0.135 * fullness + 0.008
            deep = 0.115 * fullness + 0.006
            ring = []
            for k in range(sides):
                a = math.tau * k / sides
                cx, cz = math.sin(a), math.cos(a)
                clump = 1.0 + 0.1 * math.sin(a * 11.0 + t * 4.0) * smooth(0.1, 0.4, t) + 0.1 * (vnoise(a * 5.0, t * 7.0) - 0.5)
                # (the back of it lies flatter on the chest; the front bulges)
                back = 0.55 if cz < 0 else 1.0
                ring.append(centre + Vector((cx * wide * clump, 0.0, cz * deep * clump * back)))
            rings.append(ring)
        mesh = subdivided(loft(rings, closed_end=True, closed_start=True), 1 if self.hi else 0)
        # (stringy: grooves down it)
        for v in mesh.vertices:
            p = from_b(v.co)
            n = from_b(v.normal).normalized()
            groove = (vnoise(p.x * 90.0 + p.z * 40.0, p.y * 6.0) - 0.5) * 0.008
            v.co = to_b(p + n * groove)
        top_y = top.y

        def weights(p):
            t = smooth(top_y, beard[2].y, p.y)
            if t < 0.3:
                return {"head": 1.0 - t / 0.3 + 0.01, "beard_1": t / 0.3 + 0.01}
            if t < 0.7:
                return {"beard_1": 1.0 - (t - 0.3) / 0.4 + 0.01, "beard_2": (t - 0.3) / 0.4 + 0.01}
            return {"beard_2": 1.0}

        def colour(p, n):
            return mix(BEARD, BEARD_DARK, 0.08 * vnoise(p.x * 140.0 + p.z * 70.0, p.y * 3.0) + 0.35 * smooth(0.3, 0.9, -n.y))
        self.put(mesh, colour, weights, (P_BEARD, 0.0))

    def hat(self):
        """A tall pointed hat, crumpled, sitting low over the brow, its band rolled."""
        j = self.j
        H = self.H
        hat = [V(p) for p in j["hat"]]
        base = V(j["hat_base"])
        wide = j["hat_wide"]
        ring_count, sides = (18, 22) if self.hi else (9, 12)
        rings = []
        # (a polyline up the hat's bones, finely)
        path = []
        for k in range(3):
            for q in range(6):
                path.append(hat[k].lerp(hat[k + 1], q / 6.0))
        path.append(hat[3])
        total = sum((path[i + 1] - path[i]).length for i in range(len(path) - 1))

        def at_length(d):
            run = 0.0
            for i in range(len(path) - 1):
                seg = (path[i + 1] - path[i]).length
                if run + seg >= d:
                    return path[i].lerp(path[i + 1], (d - run) / max(seg, 1e-6)), (path[i + 1] - path[i]).normalized()
                run += seg
            return path[-1], (path[-1] - path[-2]).normalized()
        for r in range(ring_count):
            t = r / (ring_count - 1)
            centre, way = at_length(total * t)
            across = H.col[0] - way * H.col[0].dot(way)
            across.normalize()
            depth = way.cross(across).normalized()
            radius = wide * ((1.0 - t) ** 0.95 * (1.0 + 0.3 * smooth(0.0, 0.12, t) * (1.0 - smooth(0.12, 0.5, t)))) + 0.002
            ring = []
            for k in range(sides):
                a = math.tau * k / sides
                crumple = 1.0 + 0.07 * math.sin(a * 3.0 + t * 7.0) * math.sin(t * math.pi) + 0.05 * (vnoise(a * 3.0, t * 5.0) - 0.5)
                # (the front of the band dips over the brow)
                dip = -0.03 * max(0.0, math.cos(a)) * (1.0 - smooth(0.0, 0.15, t))
                ring.append(centre + (across * math.sin(a) + depth * math.cos(a)) * radius * crumple + way * dip)
            rings.append(ring)
        mesh = subdivided(loft(rings, closed_end=True, closed_start=True), 1 if self.hi else 0)
        lengths = [0.0]
        for k in range(3):
            lengths.append(lengths[-1] + (hat[k + 1] - hat[k]).length)

        def weights(p):
            best, bone = 1e9, "hat_1"
            for k in range(3):
                d = dist_segment(p, hat[k], hat[k + 1])
                if d < best:
                    best, bone = d, "hat_%d" % (k + 1)
            w = {bone: 1.0}
            u = along_segment(p, hat[0], hat[1])
            if bone == "hat_1" and u < 0.3:
                w = {"head": 1.0 - u / 0.3 + 0.01, "hat_1": u / 0.3 + 0.01}
            return w

        def colour(p, n):
            u = along_segment(p, hat[0], hat[3])
            return mix(HAT, (0.09, 0.06, 0.05), 0.3 * vnoise(p.x * 30.0, p.y * 30.0) + 0.25 * smooth(0.6, 1.0, u))
        self.put(mesh, colour, weights, (P_HAT, 0.0))
        # The rolled band round the bottom of it.
        ring = rings[0]
        band = [ring[k] + (ring[k] - hat[0]).normalized() * 0.002 for k in range(len(ring))] + [ring[0] + (ring[0] - hat[0]).normalized() * 0.002]
        self.put(tube(band, [0.011] * len(band), 6, closed_end=False, closed_start=False), mix(HAT, (0.07, 0.05, 0.04), 0.4), {"head": 1.0}, (P_HAT, 0.0))

    # --- Putting it out ---

    def make(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.model = Model(self.bones)
        self.body()
        self.head_parts()

    def build(self, out_name):
        self.make()
        data = bpy.data.armatures.new("Armature")
        armature = bpy.data.objects.new("Armature", data)
        bpy.context.collection.objects.link(armature)
        bpy.context.view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode="EDIT")
        for bone in self.bones:
            if bone == "head":
                at = self.head.translation
                tail = at + self.H @ Vector((0, 0, 0.05))
            else:
                at, end = self.segments[bone]
                tail = end if (end - at).length > 0.004 else at + Vector((0, 0.02, 0))
            eb = data.edit_bones.new(bone)
            eb.head = to_b(at)
            eb.tail = to_b(tail)
        bpy.ops.object.mode_set(mode="OBJECT")
        mesh = bpy.data.meshes.new(out_name)
        body = bpy.data.objects.new(out_name, mesh)
        bpy.context.collection.objects.link(body)
        for bone in self.bones:
            body.vertex_groups.new(name=bone)
        self.model.bm.to_mesh(mesh)
        self.model.bm.free()
        mesh.update()
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]
        mesh.color_attributes.active_color_index = mesh.color_attributes.find("Col")
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]
        body.parent = armature
        body.modifiers.new("Armature", "ARMATURE").object = armature
        os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
        export(os.path.join(FOLDER, "models", out_name + ".glb"), True)
        print("BUILT %s verts=%d faces=%d" % (out_name, len(mesh.vertices), len(mesh.polygons)))
        if PREVIEW_DIR and self.hi:
            self.previews(out_name)

    def previews(self, name):
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = False
        scene.display.shading.show_backface_culling = True
        scene.render.resolution_x, scene.render.resolution_y = 600, 700
        scene.world = bpy.data.worlds.new("World")
        scene.world.color = (0.35, 0.38, 0.42)
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.lens = 70
        scene.collection.objects.link(camera)
        scene.camera = camera
        head = to_b(self.h(0.0, -0.02, 0.05))
        whole = to_b(Vector((0.0, 0.66, 0.0)))
        views = [("whole_front", Vector((0.0, 0.1, 1.0)), whole, 3.3), ("whole_quarter", Vector((0.8, 0.25, 0.8)), whole, 3.3),
                 ("whole_side", Vector((1.0, 0.1, 0.0)), whole, 3.3), ("whole_back", Vector((-0.4, 0.3, -1.0)), whole, 3.3),
                 ("face_front", Vector((0.0, 0.05, 1.0)), head, 1.1), ("face_quarter", Vector((0.7, 0.15, 0.8)), head, 1.1),
                 ("face_side", Vector((1.0, 0.05, 0.05)), head, 1.2)]
        for view, direction, target, far in views:
            offset = to_b(direction.normalized()) * far
            camera.location = target + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)


def export(path, skins):
    options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=skins,
                   export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True, use_selection=False)
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)


if __name__ == "__main__":
    Gnome("hi").build("gnome")
    Gnome("lo").build("gnome_lo")

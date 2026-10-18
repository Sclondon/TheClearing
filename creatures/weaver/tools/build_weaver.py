"""Builds the weaver and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/weaver/tools/build_weaver.py [-- <preview folder>]

Writes creatures/weaver/models/weaver.glb and weaver_lo.glb (skinned, for
Weaver); given a folder, renders previews into it.

What it models round is the skeleton Weaver (creatures/weaver/weaver.gd) works
out for itself as it hangs, written out by rest_joints.gd into rest_weaver.json
beside this file (its own units, one its height toe to crown; Godot's axes: Y
up, facing +Z, +X its left), turned to Blender's (Z up) only as it is made.

- The body is the Skin modifier over a stick figure of the skeleton (a narrow
  ribbed chest, a pinched waist, a long thin neck; six long thin arms with
  knobbed elbows, long hands of four long jointed fingers and a thumb; long
  thin legs to pointed toes), smoothed with a Subdivision Surface, then shaped:
  the ribs and the knobs of the spine standing out, the belly hollow.
- The head: a smooth, faceless egg, a little long, bowed, with only the
  faintest shape of a brow and a hollow where a face would be.
- Four wings, two pairs: long and narrow fore wings with rounded tips, broader
  hind wings, each a thin sheet on two bones (root to bend, bend to tip). The
  shader veins them and tears holes and a ragged edge in them.
- Colours are vertex colours (waxen grey-white skin, darker at the fingertips
  and toes; the head paler; the wings pale). The first UV is the part (x: skin
  0, head 0.5, wing 1) and, on a wing, how near the trailing edge (y); the second
  where the point was on the body, or on a wing (along, across) its place in it.
- The skeleton is Weaver.BONES, none the child of another, each where Weaver
  puts it. Every vertex is weighted by how near it is to each bone.
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

SKIN = (0.4, 0.4, 0.385)
SKIN_DARK = (0.22, 0.22, 0.215)
HEAD = (0.5, 0.5, 0.48)
WING = (0.46, 0.46, 0.43)
WING_ROOT = (0.3, 0.3, 0.28)

P_SKIN, P_HEAD, P_WING = 0.0, 0.5, 1.0


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




class Weaver:
    def __init__(self, detail):
        self.detail = detail
        self.hi = detail == "hi"
        with open(os.path.join(HERE, "rest_weaver.json")) as f:
            self.j = json.load(f)
        j = self.j
        self.bones = j["bones"]
        self.levels = 1 if self.hi else 0
        self.model = Model(self.bones)
        self.torso = basis3(j["torso"])
        self.side = V(j["torso"][0])
        self.spine = V(j["torso"][1])
        self.front = V(j["torso"][2])
        self.head = xform(j["head_xform"])
        self.H = self.head.to_3x3().normalized()
        self.segments = {}
        pel, bel, che, nec = V(j["pelvis"]), V(j["belly"]), V(j["chest"]), V(j["neck"])
        self.segments["hips"] = (pel - self.spine * 0.06, pel)
        self.segments["belly"] = (pel, bel)
        self.segments["chest"] = (bel, che)
        self.segments["neck"] = (che, nec)
        self.segments["head"] = (nec, V(j["head_xform"]["origin"]))
        names = ["1l", "1r", "2l", "2r", "3l", "3r"]
        for i, s in enumerate(names):
            self.segments["arm_" + s] = (V(j["roots"][i]), V(j["mids"][i]))
            self.segments["forearm_" + s] = (V(j["mids"][i]), V(j["ends"][i]))
            wrist, knuckle = V(j["ends"][i]), V(j["knuckles"][i])
            hand_y = basis3(j["hands"][i]).col[1]
            self.segments["hand_" + s] = (wrist, knuckle)
            self.segments["fingers_" + s] = (knuckle, knuckle + hand_y * 0.07)
        for k, s in enumerate(["l", "r"]):
            self.segments["thigh_" + s] = (V(j["hips"][k]), V(j["knees"][k]))
            self.segments["shin_" + s] = (V(j["knees"][k]), V(j["ankles"][k]))
            self.segments["foot_" + s] = (V(j["ankles"][k]), V(j["toes"][k]))
        for w, s in enumerate(["fl", "fr", "hl", "hr"]):
            self.segments["wing_" + s] = (V(j["wing_roots"][w]), V(j["wing_mids"][w]))
            self.segments["wingtip_" + s] = (V(j["wing_mids"][w]), V(j["wing_tips"][w]))
        self.body_bones = [b for b in self.bones if not b.startswith("wing")]

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

    def put(self, mesh, colour, weights, uv0=(0.0, 0.0), uv1=None):
        # (every part faces outwards, however it was wound)
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
            u2 = uv1(p) if callable(uv1) else self.noise_uv(p)
            return c, u, u2, w
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
        sp = self.spine
        t0 = add(pel - sp * 0.03, 0.026)
        pv = add(pel, 0.034, t0)
        w1 = add(pel.lerp(bel, 0.5), (0.026, 0.022), pv)
        bl = add(bel, (0.028, 0.022), w1)
        c1 = add(bel.lerp(che, 0.5), (0.036, 0.028), bl)
        ch = add(che, (0.042, 0.03), c1)
        sh = add(che + sp * 0.04, (0.04, 0.026), ch)
        n1 = add(che.lerp(nec, 0.7), 0.016, sh)
        nk = add(nec, 0.013, n1)
        add(nec.lerp(hd, 0.45), 0.013, nk)
        self.tips = []
        for i in range(6):
            root, mid, end = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            row = i // 2
            sign = 1.0 if i % 2 == 0 else -1.0
            link = sh if row == 0 else (ch if row == 1 else bl)
            a = add(root - self.side * sign * 0.02, 0.014 - row * 0.001, link)
            a1 = add(root, 0.012, a)
            a2 = add(root.lerp(mid, 0.5), 0.0085, a1)
            m = add(mid, 0.01, a2)
            m2 = add(mid.lerp(end, 0.5), 0.0075, m)
            e = add(end, 0.0065, m2)
            hand = basis3(j["hands"][i])
            hy, hx, hz = hand.col[1], hand.col[0], hand.col[2]
            palm = add(end + hy * 0.02, 0.008, e)
            knuckle = V(j["knuckles"][i])
            # Four long jointed fingers, spread a little, and a thumb.
            for f, fan in enumerate([-0.3, -0.1, 0.1, 0.3]):
                way = (hy + hx * fan * sign * 0.6).normalized()
                at = knuckle + hx * fan * 0.03 * sign
                last = add(at, 0.0042, palm)
                for k, length in enumerate((0.03, 0.026, 0.02)):
                    way = (way - hz * 0.12).normalized()
                    at = at + way * length
                    last = add(at, 0.0036 - k * 0.0007, last)
                self.tips.append(at)
            tway = (hy * 0.4 + hz * 0.85 + hx * sign * 0.3).normalized()
            t1 = add(end + hy * 0.015 + hz * 0.008, 0.0045, palm)
            add(end + hy * 0.015 + hz * 0.008 + tway * 0.03, 0.0032, t1)
        for k in range(2):
            hip, knee, ankle, toe = V(j["hips"][k]), V(j["knees"][k]), V(j["ankles"][k]), V(j["toes"][k])
            a = add(hip, 0.02, pv)
            a2 = add(hip.lerp(knee, 0.5), 0.0145, a)
            kn = add(knee, 0.012, a2)
            s2 = add(knee.lerp(ankle, 0.5), 0.0095, kn)
            an = add(ankle, 0.0075, s2)
            ft = add(ankle.lerp(toe, 0.6), 0.006, an)
            add(toe, 0.003, ft)
        mesh = skinned(points, edges, radii, pv, self.levels)
        self.shape_body(mesh)

        def colour(p, n):
            dark = 0.0
            for t in self.tips:
                dark = max(dark, smooth(0.03, 0.0, (p - t).length))
            dark = max(dark, smooth(0.12, 0.0, p.y) * 0.8)
            return mix(SKIN, SKIN_DARK, dark)
        self.put(mesh, colour, lambda p: self.nearest(p, self.body_bones, 3), (P_SKIN, 0.0))

    def shape_body(self, mesh):
        """Ribs standing out round the chest, the spine's knobs, a hollow belly."""
        j = self.j
        bel, che, pel = V(j["belly"]), V(j["chest"]), V(j["pelvis"])
        sp, fr, sd = self.spine, self.front, self.side
        for v in mesh.vertices:
            p = from_b(v.co)
            n = from_b(v.normal).normalized()
            push = 0.0
            u = along_segment(p, bel, che + sp * 0.03)
            if 0.1 < u < 0.98 and dist_segment(p, bel, che) < 0.05:
                rib = 0.5 + 0.5 * math.cos(u * math.tau * 5.5)
                push += (rib - 0.45) * 0.0035 * (abs(n.dot(sd)) * 0.9 + max(0.0, n.dot(fr)) * 0.6)
            back = -n.dot(fr)
            if back > 0.6 and abs(p.x) < 0.012:
                u2 = along_segment(p, pel, che + sp * 0.06)
                push += max(0.0, math.cos(u2 * math.tau * 9.0)) ** 3 * 0.003
            # (the belly sucked in under the ribs)
            if dist_segment(p, pel, bel) < 0.04 and n.dot(fr) > 0.3:
                push -= 0.004 * smooth(pel.y, bel.y, p.y)
            v.co = to_b(p + n * push)
        mesh.update()

    # --- The head ---

    def head_parts(self):
        H = self.H
        r = self.j["head_size"]
        mesh = ellipsoid(self.h(0.0, 0.0, 0.0), H, Vector((r[0], r[1], r[2])), 24, 16)
        mesh = subdivided(mesh, 1 if self.hi else 0)
        to_head = self.head.inverted()
        # Shaped: narrower to the chin, the faintest brow, a shallow hollow where a face would be.
        for v in mesh.vertices:
            p = from_b(v.co)
            local = to_head @ p
            y = local.y / r[1]
            local.x *= 1.0 - 0.2 * smooth(0.1, -0.9, y)
            local.z *= 1.0 - 0.08 * smooth(0.1, -0.9, y)
            if local.z > 0:
                face = math.exp(-((local.x / (r[0] * 0.6)) ** 2)) * math.exp(-(((y + 0.05) / 0.35) ** 2))
                local.z -= 0.004 * face
                brow = math.exp(-(((y - 0.18) / 0.08) ** 2)) * math.exp(-((local.x / (r[0] * 0.8)) ** 2))
                local.z += 0.0025 * brow
            v.co = to_b(self.head @ local)
        mesh.update()
        self.put(mesh, HEAD, {"head": 1.0}, (P_HEAD, 0.0))

    # --- The wings ---

    def wings(self):
        j = self.j
        rows, cols = (16, 8) if self.hi else (9, 5)
        for w, s in enumerate(["fl", "fr", "hl", "hr"]):
            hind = w >= 2
            root, mid, tip = V(j["wing_roots"][w]), V(j["wing_mids"][w]), V(j["wing_tips"][w])
            along1 = (mid - root).normalized()
            along2 = (tip - mid).normalized()
            # (the wing lies flat across its spread: its chord goes back and down from the leading edge)
            chord = (self.torso @ Vector((0.0, -0.55, -0.85))).normalized() if not hind else (self.torso @ Vector((0.0, -0.8, -0.6))).normalized()
            chord = (chord - along1 * chord.dot(along1)).normalized()
            normal = along1.cross(chord).normalized()
            wide = 0.2 if not hind else 0.19
            grid = []
            first = (mid - root).length
            total = first + (tip - mid).length
            for r in range(rows):
                t = r / (rows - 1)
                d = t * total
                spine_pt = root + along1 * d if d <= first else mid + along2 * (d - first)
                # The outline: narrow at the root, widest two-thirds out, a rounded tip.
                width = wide * (math.sin(math.pi * min(0.08 + t * 1.0, 1.0)) ** 0.8) * (1.0 - 0.25 * t)
                if not hind:
                    width *= 0.75 + 0.25 * smooth(0.0, 0.5, t)
                row = []
                for c in range(cols):
                    q = c / (cols - 1)
                    camber = 0.006 * math.sin(math.pi * q)
                    row.append(spine_pt + chord * width * q + normal * camber)
                grid.append(row)
            mesh = sheet(grid, 0.003, lambda p, normal=normal: normal)
            if self.hi:
                mesh = subdivided(mesh, 1)

            def weights(p, root=root, along1=along1, s=s, first=first):
                d = (p - root).dot(along1)
                k = smooth(first * 0.6, first * 1.3, d)
                wt = {"wing_" + s: 1.0 - k + 0.001, "wingtip_" + s: k + 0.001}
                if d < 0.02:
                    wt["chest"] = 0.6
                return wt

            def place(p, root=root, along1=along1, chord=chord, total=total, wide=wide):
                along = max(0.0, min(1.0, (p - root).dot(along1) / total))
                across = max(0.0, min(1.0, (p - root).dot(chord) / wide))
                return (along, across)

            def colour(p, n, root=root):
                return mix(WING_ROOT, WING, smooth(0.0, 0.08, (p - root).length))

            def uv(p, n, root=root, chord=chord, wide=wide):
                return (P_WING, max(0.0, min(1.0, (p - root).dot(chord) / wide)))
            self.put(mesh, colour, weights, uv, place)
            # A vein down its leading edge (a thin rod), so that it has an edge in the mist.
            self.put(tube([root, mid, tip], [0.004, 0.003, 0.0], 5), WING_ROOT, weights, (P_SKIN, 0.0))

    # --- Putting it out ---

    def make(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.model = Model(self.bones)
        self.body()
        self.head_parts()
        self.wings()

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
                tail = at + self.H @ Vector((0, 0, 0.04))
            else:
                at, end = self.segments[bone]
                tail = end if (end - at).length > 0.003 else at + Vector((0, 0.02, 0))
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
        scene.render.resolution_x, scene.render.resolution_y = 700, 700
        scene.world = bpy.data.worlds.new("World")
        scene.world.color = (0.35, 0.38, 0.42)
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.lens = 60
        scene.collection.objects.link(camera)
        scene.camera = camera
        head = to_b(self.h(0.0, 0.0, 0.0))
        whole = to_b(Vector((0.0, 0.55, 0.0)))
        views = [("whole_front", Vector((0.0, 0.1, 1.0)), whole, 2.4), ("whole_quarter", Vector((0.8, 0.25, 0.8)), whole, 2.4),
                 ("whole_side", Vector((1.0, 0.1, 0.0)), whole, 2.4), ("whole_back", Vector((-0.4, 0.3, -1.0)), whole, 2.4),
                 ("head", Vector((0.5, 0.1, 0.8)), head, 0.5), ("hands", Vector((0.3, 0.0, 1.0)), to_b(Vector((0.0, 0.48, 0.08))), 0.9)]
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
    Weaver("hi").build("weaver")
    Weaver("lo").build("weaver_lo")

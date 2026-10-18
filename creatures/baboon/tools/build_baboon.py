"""Builds the two baboons, the mandrill that leads a troop and a plain baboon,
and exports them for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/baboon/tools/build_baboon.py [-- <preview folder>]

Writes creatures/baboon/models/mandrill.glb, mandrill_lo.glb, baboon.glb and
baboon_lo.glb, and (given a folder) renders previews into it.

What it models round is the skeleton Baboon (creatures/baboon/baboon.gd) works
out for itself as each kind stands, written out by rest_joints.gd into
rest_alpha.json and rest_baboon.json beside this file (its own units, about 0.6
to the shoulder; Godot's axes: Y up, facing +Z, +X its left). Everything is in
those units and axes here, and turned to Blender's (Z up) only as it is made.

- The body is the Skin modifier over a stick figure of the skeleton (spine,
  shoulders and hips, legs, tail, the fingers of each hand and the toes of each
  foot), smoothed with a Subdivision Surface: one organic surface.
- The head: a skull; a heavy brow over deep sockets with small ember eyes; a
  long snout lofted round a low cage and smoothed, then shaped: on the mandrill
  it narrows to a rounded bulb of a nose, with nostrils, and either side of a
  narrow raised ridge its cheeks swell out in five soft ribs with creases
  between. A hinged jaw, gums, long canines. Ears.
- Fur: many small clumps, each a tapering strand of three sides that curves
  down over the body, rooted on its surface: a shaggy cape over the neck and
  shoulders, hair down the backs of the arms, a ruff round the face, a crest on
  the crown, a beard (yellow-orange on the mandrill), a tuft on the tail. Each
  clump's normals are bent out from the body under it, so the cape takes the
  light as one soft mass and only its edge is ragged.
- Colours are vertex colours: the coat dark on the back and paler under the
  belly and inside the limbs, a pale rump (with a blue-purple patch on the
  mandrill), the mane a little paler and warmer, dark hands and feet. The
  mandrill's face is cut sharp in Godot's shader (BaboonLook) from where on the
  snout each point is, which is written into its second UV (along, round); its
  first UV says how much a point glows (the eyes: 1; the snout to be masked: 2)
  and how much it is fur. The vertex colours of the snout are the same mask, for
  the previews and anything that does not use that shader.
- The skeleton is Baboon.BONES, none the child of another, each where Baboon
  puts it as it stands. Every vertex is weighted by how near it is to each bone
  (two or three at most), the head's parts to the head, the jaw's to the jaw.
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

EMBER = (1.0, 0.3, 0.05)
BONE = (0.86, 0.82, 0.7)
GUM = (0.32, 0.05, 0.06)
CRIMSON = (0.42, 0.04, 0.06)
WET = (0.66, 0.3, 0.3)
SLATE = (0.21, 0.31, 0.46)
GROOVE = (0.07, 0.08, 0.12)
SKIN = (0.07, 0.06, 0.06)


def V(p):
    return Vector((p[0], p[1], p[2]))


def to_b(p):
    return Vector((p.x, -p.z, p.y))


def from_b(p):
    return Vector((p.x, p.z, -p.y))


def xform(d):
    b = d["basis"]
    m = Matrix((
        (b[0][0], b[1][0], b[2][0], d["origin"][0]),
        (b[0][1], b[1][1], b[2][1], d["origin"][1]),
        (b[0][2], b[1][2], b[2][2], d["origin"][2]),
        (0, 0, 0, 1)))
    return m


def smooth(a, b, x):
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def lighten(c, k):
    return mix(c, (1.0, 1.0, 1.0), k)


def dist_segment(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


class Model:
    """The mesh as it is put together: one bmesh, with per-vertex data."""

    def __init__(self, bones):
        self.bm = bmesh.new()
        self.uv0 = self.bm.loops.layers.uv.new("UVMap")
        self.uv1 = self.bm.loops.layers.uv.new("UV2")
        self.col = self.bm.verts.layers.float_color.new("Col")
        self.deform = self.bm.verts.layers.deform.verify()
        self.bones = bones
        self.normal_of = {}  # vertex index -> a normal of its own (fur)
        self.vert_uv = []  # per vertex: (uv0, uv1)

    def add(self, mesh, info, normals=None):
        """Adds a Blender mesh (in Blender's axes). info(index, godot_position, blender_normal) ->
        (colour, uv0, uv1, {bone: weight}). normals: per vertex of `mesh`, its own normal (Blender axes)."""
        mesh.calc_loop_triangles()
        made = []
        for v in mesh.vertices:
            nv = self.bm.verts.new(v.co)
            colour, uv0, uv1, weights = info(v.index, from_b(v.co), v.normal)
            nv[self.col] = (colour[0], colour[1], colour[2], 1.0)
            total = sum(weights.values()) or 1.0
            for bone, w in weights.items():
                if w / total > 0.001:
                    nv[self.deform][self.bones.index(bone)] = w / total
            made.append(nv)
            self.vert_uv.append((uv0, uv1))
            if normals is not None:
                self.normal_of[len(self.vert_uv) - 1] = normals[v.index]
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
    skin.branch_smoothing = 0.5
    skin.use_smooth_shade = True
    for i, r in enumerate(radii):
        mesh.skin_vertices[0].data[i].radius = (r, r)
        mesh.skin_vertices[0].data[i].use_root = i == root
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return evaluated(obj)


def ellipsoid(centre, basis, radii, segments=16, rings=10):
    """A UV sphere (Godot space: centre, a 3x3 basis as a Matrix, radii)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        local = Vector((v.co.x * radii[0], v.co.z * radii[1], -v.co.y * radii[2]))
        v.co = to_b(centre + basis @ local)
    return mesh_from_bm(bm)


def cone(base, tip, radius, sides=8):
    bm = bmesh.new()
    axis = tip - base
    across = axis.cross(Vector((0, 1, 0)))
    if across.length < 1e-6:
        across = axis.cross(Vector((1, 0, 0)))
    across.normalize()
    lift = axis.normalized().cross(across)
    ring = [bm.verts.new(to_b(base + (across * math.cos(a) + lift * math.sin(a)) * radius)) for a in [math.tau * k / sides for k in range(sides)]]
    point = bm.verts.new(to_b(tip))
    for k in range(sides):
        bm.faces.new((ring[k], ring[(k + 1) % sides], point))
    bm.faces.new(list(reversed(ring)))
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
        last = grid[-1]
        centre = bm.verts.new(to_b(tip + (tip - sum((p for p in rings_pts[-2]), Vector()) / n).normalized() * 0.0001))
        for k in range(n):
            bm.faces.new((last[k], last[(k + 1) % n], centre))
    if closed_start:
        bm.faces.new(list(reversed(grid[0])))
    return mesh_from_bm(bm)


class Baboon:
    def __init__(self, kind, low):
        self.kind = kind
        self.alpha = kind == "alpha"
        self.low = low
        with open(os.path.join(HERE, "rest_%s.json" % kind)) as f:
            self.j = json.load(f)
        self.bones = self.j["bones"]
        self.b = self.j["build"]
        self.hs = self.b["head"]
        self.levels = 1 if low else 2
        self.model = Model(self.bones)
        j = self.j
        self.torso = Matrix((V(j["torso"][0]), V(j["torso"][1]), V(j["torso"][2]))).transposed()
        self.up = V(j["torso"][1])
        self.side = V(j["torso"][0])
        self.fwd = V(j["torso"][2])
        self.head = xform(j["head_xform"]) @ Matrix.Diagonal((self.hs, self.hs, self.hs, 1.0))
        self.jaw = xform(j["jaw_xform"]) @ Matrix.Diagonal((self.hs, self.hs, self.hs, 1.0))
        self.rng_state = 11 if self.alpha else 12
        # Each bone as a segment (Godot points) to weigh by.
        self.segments = {}
        pairs = [("rump", "tail_root", "pelvis"), ("back", "pelvis", "mid"), ("chest", "mid", "chest"), ("neck", "chest", "neck")]
        for bone, a, b in pairs:
            self.segments[bone] = (V(j[a]), V(j[b]))
        self.segments["head"] = (V(j["neck"]), V(j["head_xform"]["origin"]))
        for i, side in enumerate(["l", "r"]):
            self.segments["arm_" + side] = (V(j["roots"][i]), V(j["mids"][i]))
            self.segments["forearm_" + side] = (V(j["mids"][i]), V(j["ends"][i]))
            end = V(j["ends"][i])
            self.segments["hand_" + side] = (end, end + (end - V(j["mids"][i])).normalized() * 0.05)
            self.segments["thigh_" + side] = (V(j["roots"][i + 2]), V(j["mids"][i + 2]))
            self.segments["shin_" + side] = (V(j["mids"][i + 2]), V(j["ends"][i + 2]))
            ankle = V(j["ends"][i + 2])
            self.segments["foot_" + side] = (ankle, ankle + Vector((0, -0.04, 0.12)))
        tail = [V(p) for p in j["tail"]]
        for k in range(5):
            self.segments["tail_%d" % (k + 1)] = (tail[k], tail[k + 1])

    def rand(self):
        # (a small fixed generator, so every build is the same)
        self.rng_state = (self.rng_state * 1103515245 + 12345) % 2147483648
        return self.rng_state / 2147483648.0

    def uniform(self, a, b):
        return a + (b - a) * self.rand()

    def h(self, x, y, z):
        return self.head @ Vector((x, y, z))

    def hb(self, v):
        return (self.head.to_3x3() @ Vector(v))

    def jw(self, x, y, z):
        return self.jaw @ Vector((x, y, z))

    def jb(self, v):
        return (self.jaw.to_3x3() @ Vector(v))

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
            weights[bone] = 1.0 / (d ** 4 + 1e-9)
        best = max(weights.values())
        return {k: w for k, w in weights.items() if w > best * 0.02}

    @staticmethod
    def noise_uv(p):
        return (p.x * 0.8 + p.z * 0.6, p.y + p.z * 0.3)

    # --- The body ---

    def coat(self, p, n):
        """The coat's colour at a point (Godot) with a normal (Godot)."""
        b = self.b
        fur, belly, rump, patch, dark = b["fur"], b["belly_fur"], b["rump"], b["rump_patch"], b["dark"]
        c = mix(fur, belly, smooth(-0.1, 0.75, -n.dot(self.up)))
        # (inside the limbs, paler)
        lateral = abs(p.x)
        if p.y < V(self.j["chest"]).y - 0.08:
            inward = -n.x * (1.0 if p.x > 0 else -1.0)
            c = mix(c, belly, smooth(0.0, 0.8, inward) * 0.7 * smooth(0.25, 0.1, p.y))
        behind = smooth(0.2, 0.9, -n.dot(self.fwd)) * smooth(0.12, 0.0, (p - V(self.j["tail_root"])).length - 0.06)
        c = mix(c, rump, behind * 0.85)
        if patch[3] > 0:
            c = mix(c, patch, behind * smooth(0.6, 0.95, -n.dot(self.fwd)) * 0.55)
        # (dark towards the hands and feet)
        low = smooth(0.2, 0.04, p.y)
        c = mix(c, dark, low * 0.6)
        return c

    def body(self):
        j, b = self.j, self.b
        P = lambda k: V(j[k])
        chest, belly, haunch = b["chest"], b["belly"], b["haunch"]
        points, radii, edges = [], [], []

        def add(p, r, link=None):
            points.append(p)
            radii.append(r)
            if link is not None:
                edges.append((link, len(points) - 1))
            return len(points) - 1

        T, Pv, M, C, N = P("tail_root"), P("pelvis"), P("mid"), P("chest"), P("neck")
        H = V(j["head_xform"]["origin"])
        up = self.up
        t0 = add(T, haunch * 0.6)
        t1 = add(T.lerp(Pv, 0.5), haunch * 0.98, t0)
        pel = add(Pv, haunch * 1.06, t1)
        w = add(Pv.lerp(M, 0.5), belly * 0.92, pel)
        mid = add(M, belly * 1.06, w)
        c1 = add(M.lerp(C, 0.55) + up * 0.01, chest * 1.0, mid)
        ch = add(C + up * chest * 0.12, chest * 1.08, c1)
        n1 = add(C.lerp(N, 0.55) + up * chest * 0.12, chest * 0.78, ch)
        nk = add(N, chest * 0.6, n1)
        add(N.lerp(H, 0.6), 0.075 * self.hs, nk)
        arm_r, leg_r = b["arm"], b["leg"]
        for i in range(4):
            front = i < 2
            root, midj, end = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            r = arm_r if front else leg_r
            base = ch if front else pel
            a = add(root, r[0] * (1.4 if front else 1.55), base)
            a2 = add(root.lerp(midj, 0.5), r[0] * (1.05 if front else 1.1), a)
            m = add(midj, r[1] * 1.08, a2)
            m2 = add(midj.lerp(end, 0.5), r[1] * 0.95, m)
            e = add(end, r[1] * 0.72, m2)
            big = (1.3 if self.alpha else 1.0)
            if front:
                down = (end - midj).normalized()
                ahead = self.fwd
                palm = add(end + down * 0.012 * big + ahead * 0.012 * big, 0.034 * big, e)
                sign = 1.0 if i == 0 else -1.0
                for f in range(4):
                    x = (f - 1.5) * 0.019 * big
                    k1 = add(end + down * 0.022 * big + ahead * 0.032 * big + self.side * x * sign, 0.011 * big, palm)
                    k2 = add(end + down * 0.04 * big + ahead * 0.045 * big + self.side * x * sign, 0.01 * big, k1)
                    add(end + down * 0.047 * big + ahead * 0.025 * big + self.side * x * sign, 0.008 * big, k2)
                th = add(end + down * 0.015 * big + ahead * 0.02 * big + self.side * 0.032 * sign * big, 0.009 * big, palm)
                add(end + down * 0.04 * big + ahead * 0.035 * big + self.side * 0.036 * sign * big, 0.007 * big, th)
            else:
                heel = add(end + Vector((0, -0.025, 0.02)) * big, 0.03 * big, e)
                sole = add(end + Vector((0, -0.03, 0.075)) * big, 0.03 * big, heel)
                for f in range(4):
                    x = (f - 1.5) * 0.016 * big
                    t1_ = add(end + Vector((x, -0.033, 0.11)) * big, 0.009 * big, sole)
                    add(end + Vector((x * 1.1, -0.042, 0.135)) * big, 0.007 * big, t1_)
        tail = [V(p) for p in j["tail"]]
        tr = 0.04 if self.alpha else 0.03
        last = t0
        for k in range(1, 6):
            last = add(tail[k], tr * (1.0 - 0.1 * k), last)
        mesh = skinned(points, edges, radii, pel, self.levels)

        def info(i, p, n):
            nn = from_b(n)
            weights = self.nearest(p, None, 3)
            return self.coat(p, nn), (0.0, 1.0), self.noise_uv(p), weights

        self.model.add(mesh, info)
        bpy.data.meshes.remove(mesh)
        # The surface, to root the fur on.
        self.surface = self.model.bm.copy()
        self.surface.transform(Matrix.Identity(4))
        self.bvh = BVHTree.FromBMesh(self.surface)

    def on_body(self, axis, out):
        """Where a ray from `axis` (inside the body) going `out` leaves it (Godot)."""
        hit = self.bvh.ray_cast(to_b(axis + out * 0.4), to_b(-out))
        if hit[0] is None:
            return None
        return from_b(hit[0])

    # --- Fur ---

    def clump(self, root, hang, length, width, out, colour, weights, sides=3, rings=4):
        """A tapering strand of fur from `root`, hanging along `hang` and lying over `out`
        (it is laid down along the surface, standing off it only a little)."""
        out = out.normalized()
        hang = hang.normalized()
        hang = (hang - out * hang.dot(out) + out * 0.18).normalized()
        across = out.cross(hang)
        if across.length < 1e-6:
            across = Vector((1, 0, 0))
        across.normalize()
        lift = hang.cross(across).normalized()
        if lift.dot(out) < 0:
            lift = -lift
        bm = bmesh.new()
        rings_v = []
        centre = root
        prev = root
        for r in range(rings):
            s = r / rings
            centre = root + hang * length * s + lift * width * 0.4 * s - Vector((0, 1, 0)) * length * 0.12 * s * s
            w = width * (1.0 - s * 0.85)
            ring = []
            for k in range(sides):
                a = math.tau * k / sides + 0.4
                ring.append(bm.verts.new(to_b(centre + across * math.cos(a) * w * 0.5 + lift * math.sin(a) * w * 0.42)))
            rings_v.append(ring)
            prev = centre
        tip_p = root + hang * length + lift * width * 0.4 - Vector((0, 1, 0)) * length * 0.12
        tip = bm.verts.new(to_b(tip_p))
        for r in range(rings - 1):
            for k in range(sides):
                bm.faces.new((rings_v[r][k], rings_v[r][(k + 1) % sides], rings_v[r + 1][(k + 1) % sides], rings_v[r + 1][k]))
        for k in range(sides):
            bm.faces.new((rings_v[-1][k], rings_v[-1][(k + 1) % sides], tip))
        bm.faces.new(list(reversed(rings_v[0])))
        mesh = mesh_from_bm(bm)
        normal = to_b((out.normalized() + hang * 0.2).normalized())
        count = len(mesh.vertices)

        def info(i, p, n):
            s = min(1.0, (p - root).length / max(length, 1e-6))
            return mix(colour, lighten(colour, 0.12), s), (0.0, 1.0), self.noise_uv(p), weights

        self.model.add(mesh, info, [normal] * count)
        bpy.data.meshes.remove(mesh)

    def mane(self):
        j, b = self.j, self.b
        chest = b["chest"]
        mane_fur, fur = b["mane_fur"], b["fur"]
        rows = 16 if self.alpha else 10
        if self.low:
            rows = rows * 2 // 3
        N, C, M = V(j["neck"]), V(j["chest"]), V(j["mid"])
        for row in range(rows):
            u = row / (rows - 1)
            axis = N.lerp(C, min(u * 2.0, 1.0)).lerp(M, max(u * 2.0 - 1.0, 0.0) * 0.85)
            count = int((34 if self.alpha else 18) + u * (18 if self.alpha else 6))
            if self.low:
                count = count * 2 // 3
            spread = (1.55 + 0.45 * u) if self.alpha else (1.2 + 0.35 * u)
            for k in range(count):
                around = -spread + 2 * spread * (k + self.uniform(0.2, 0.8)) / count
                out = (self.up * math.cos(around) + self.side * math.sin(around)).normalized()
                root = self.on_body(axis, out)
                if root is None:
                    continue
                root -= out * 0.006
                hang = (-self.fwd * 0.85 - self.up * (0.2 + 0.55 * abs(math.sin(around))) + self.side * math.sin(around) * 0.25)
                length = ((0.07 + 0.11 * u) + self.uniform(0.0, 0.05)) * b["mane"] * (1.0 + 0.4 * abs(math.sin(around))) + 0.02
                tone = mix(mane_fur, fur, self.uniform(0.0, 0.35))
                weights = {"mane": 1.0} if u > 0.25 else {"neck": 0.5, "mane": 0.5}
                self.clump(root, hang, length, self.uniform(0.04, 0.06) * (0.75 + 0.35 * b["mane"]), out, tone, weights)
        # The throat, shaggy down to the chest.
        for k in range(22 if self.alpha else 8):
            u = self.rand()
            around = self.uniform(math.pi * 0.6, math.pi * 1.4)
            axis = N.lerp(C, u * 0.7)
            out = (self.up * math.cos(around) + self.side * math.sin(around) * 0.8 + self.fwd * 0.3).normalized()
            root = self.on_body(axis, out)
            if root is None:
                continue
            self.clump(root - out * 0.005, -self.up * 0.8 - self.fwd * 0.4 + out * 0.2, self.uniform(0.08, 0.13) * b["mane"],
                       0.026, out, mix(mane_fur, b["beard"], self.uniform(0.1, 0.35) if self.alpha else 0.1), {"neck": 0.6, "chest": 0.4})
        # Over the shoulders and down the backs of the arms.
        for i in range(2):
            sign = 1.0 if i == 0 else -1.0
            root_j, elbow, wrist = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            for k in range(34 if self.alpha else 16):
                f = self.uniform(0.0, 1.6)
                axis = root_j.lerp(elbow, min(f, 1.0)).lerp(wrist, max(f - 1.0, 0.0))
                around = self.uniform(-1.3, 1.0)
                out = (self.side * sign * math.cos(around) - self.fwd * math.sin(around) * 0.9).normalized()
                root = self.on_body(axis, out)
                if root is None:
                    continue
                bone = "arm_" + ("l" if i == 0 else "r") if f < 1.0 else "forearm_" + ("l" if i == 0 else "r")
                self.clump(root - out * 0.005, (elbow - root_j).normalized() * 0.7 - self.fwd * 0.4, self.uniform(0.06, 0.11) * b["mane"] + 0.02,
                           0.024, out, mix(mane_fur, fur, self.uniform(0.2, 0.6)), {bone: 1.0})
        # A tuft at the end of the tail.
        tail = [V(p) for p in j["tail"]]
        for k in range(6):
            out = Vector((math.sin(k * 1.3), 0.3, math.cos(k * 1.3))).normalized()
            self.clump(tail[4] + out * 0.01, (tail[5] - tail[4]).normalized() + out * 0.2, 0.06 if self.alpha else 0.08, 0.022, out, fur, {"tail_5": 1.0})

    # --- The head ---

    def head_parts(self):
        b = self.b
        hs = self.hs
        fur, dark, face, mane_fur, beard = b["fur"], b["dark"], b["face"], b["mane_fur"], b["beard"]
        H = self.head.to_3x3().normalized()
        HEAD = {"head": 1.0}
        JAW = {"jaw": 1.0}

        def put(mesh, colour, weights, uv0=(0.0, 0.0), uvfn=None):
            def info(i, p, n):
                return (colour(p) if callable(colour) else colour), uv0, (uvfn(p) if uvfn else self.noise_uv(p)), weights
            self.model.add(mesh, info)
            bpy.data.meshes.remove(mesh)

        # The skull, its face dark and bare round the eyes and down to the snout.
        to_head = self.head.inverted()

        def skull_colour(p):
            local = to_head @ p
            bare = smooth(0.02, 0.045, local.z) * smooth(0.085, 0.06, local.y)
            return mix(fur, face, bare)
        put(ellipsoid(self.h(0.0, 0.03, -0.03), H, Vector((0.088, 0.08, 0.1)) * hs, 24, 14), skull_colour, HEAD, (0.0, 1.0))
        # The brow: a heavy ridge, overhanging the eyes.
        for s in (1.0, -1.0):
            tilt = H @ Matrix.Rotation(-0.3 * s, 3, "Y") @ Matrix.Rotation(0.25 * s, 3, "Z")
            put(ellipsoid(self.h(0.03 * s, 0.062, 0.05), tilt, Vector((0.032, 0.014, 0.024)) * hs, 16, 10), mix(fur, dark, 0.45), HEAD, (0.0, 0.6))
        put(ellipsoid(self.h(0.0, 0.06, 0.048), H, Vector((0.022, 0.016, 0.026)) * hs, 12, 8), mix(fur, dark, 0.6), HEAD, (0.0, 0.4))
        # Deep sockets and small ember eyes.
        for s in (1.0, -1.0):
            put(ellipsoid(self.h(0.033 * s, 0.04, 0.046), H, Vector((0.017, 0.012, 0.014)) * hs, 12, 8), (0.03, 0.02, 0.02), HEAD)
            put(ellipsoid(self.h(0.033 * s, 0.04, 0.054), H, Vector((0.0072, 0.0052, 0.006)) * hs, 10, 6), EMBER, HEAD, (1.0, 0.0))
            ear = H @ Matrix.Rotation(0.4 * s, 3, "Y")
            put(ellipsoid(self.h(0.08 * s, 0.04, -0.035), ear, Vector((0.012, 0.028, 0.024)) * hs, 10, 6), dark, HEAD, (0.0, 0.4))

        # The snout.
        length = 0.235 if self.alpha else 0.19

        def axis_at(t):
            return Vector((0.0, -0.005 - 0.04 * t, 0.03 + length * t))

        def radii_at(t):
            if self.alpha:
                if t < 0.76:
                    return Vector((0.05 + (0.03 - 0.05) * t / 0.76, 0.058 + (0.03 - 0.058) * (t / 0.76) ** 0.8))
                k = (t - 0.76) / 0.24
                return Vector((0.03 + 0.012 * math.sin(k * math.pi * 0.6), 0.03 - 0.002 * k))
            return Vector((0.05 - 0.02 * t, 0.046 - 0.016 * t))

        cage_rings, cage_sides = (12, 16)
        rings = []
        for i in range(cage_rings):
            t = i / (cage_rings - 1)
            r = radii_at(t) * hs
            round_off = math.sqrt(max(0.0, 1.0 - (max(t - 0.82, 0.0) / 0.18) ** 2))
            ring = []
            for k in range(cage_sides):
                a = math.tau * k / cage_sides
                local = axis_at(t) + Vector((math.cos(a) * r.x, math.sin(a) * r.y, 0.0)) * max(round_off, 0.25)
                ring.append(self.h(*local))
            rings.append(ring)
        mesh = subdivided(loft(rings, closed_end=True), 3 if not self.low else 2)
        # Shape it: the cheek pads in ribs, the ridge; and say where each point is (along, round).
        inv = self.head.inverted()
        mapped = {}
        for v in mesh.vertices:
            local = inv @ from_b(v.co)
            t = max(0.0, min(1.0, (local.z - 0.03) / length))
            centre = axis_at(t)
            off = local - Vector((centre.x, centre.y, local.z))
            r = radii_at(t)
            c, s = off.x / max(r.x, 1e-6), off.y / max(r.y, 1e-6)
            phi = math.atan2(s, abs(c))
            # (how far it swells out: across, and up)
            sx = sy = 1.0
            if self.alpha:
                # The cheek pads swell out sideways, soft, in ribs with creases between.
                pad = math.sin(math.pi * max(0.0, min(1.0, (phi + 0.35) / 1.3))) ** 0.6 * math.sin(math.pi * max(0.0, min(1.0, (t - 0.03) / 0.8))) ** 0.6
                rib = ((phi + 0.35) / 1.3 * 5.0) % 1.0
                bump = 0.5 - 0.5 * math.cos(math.tau * rib)
                ridge = math.exp(-((phi - math.pi * 0.5) / 0.16) ** 2) * smooth(0.0, 0.1, t) * (1.0 - smooth(0.78, 0.92, t))
                swell = pad * (0.5 + 0.2 * (bump - 0.5))
                sx += swell * 1.15
                sy += swell * 0.35 + ridge * 0.3
            else:
                sx += math.exp(-((phi - 0.3) / 0.5) ** 2) * 0.1 * math.sin(math.pi * max(0.0, min(1.0, t / 0.85)))
                sy = sx
            local = Vector((centre.x, centre.y, local.z)) + Vector((off.x * sx, off.y * sy, 0.0))
            v.co = to_b(self.head @ local)
            mapped[v.index] = (t, phi)

        def snout_info(i, p, n):
            t, phi = mapped[i]
            colour = self.face_colour(t, phi) if self.alpha else (mix(face, (0.0, 0.0, 0.0), 0.3) if t > 0.9 else face)
            return colour, ((2.0 if self.alpha else 0.0), 0.0), (t, phi), HEAD

        mesh.update()
        self.model.add(mesh, snout_info)
        bpy.data.meshes.remove(mesh)
        # Nostrils at the end of the nose.
        tip = axis_at(0.99)
        for s in (1.0, -1.0):
            put(ellipsoid(self.h(tip.x + 0.012 * s, tip.y - 0.008, tip.z - 0.002), H, Vector((0.007, 0.0045, 0.005)) * hs, 8, 6), (0.04, 0.02, 0.02), HEAD)
        # The roof of the mouth; long upper canines and the front teeth.
        put(ellipsoid(self.h(0.0, -0.036, 0.15), H, Vector((0.028, 0.01, 0.1)) * hs, 12, 6), GUM, HEAD)
        fang = b["fang"]
        can = axis_at(0.68)
        cr = radii_at(0.68)
        for s in (1.0, -1.0):
            base = Vector((can.x + cr.x * 0.6 * s, can.y - cr.y * 0.7, can.z))
            put(cone(self.h(*base), self.h(*(base + Vector((0.004 * s, -fang - 0.025, -0.012)))), 0.011 * hs), BONE, HEAD)
            for k in range(2):
                ft = axis_at(0.88) + Vector(((0.006 + k * 0.009) * s, -radii_at(0.88).y * 0.8, -k * 0.008))
                put(cone(self.h(*ft), self.h(*(ft + Vector((0, -0.02, 0)))), 0.005 * hs, 6), BONE, HEAD)
        # The jaw: lower jaw, tongue, lower canines.
        rings = []
        for i in range(7):
            t = i / 6.0
            rx, ry = (0.034 - 0.014 * t) * hs, (0.018 - 0.006 * t) * hs
            cz = length * 0.76 * t
            rings.append([self.jw(math.cos(a) * rx, -0.016 - 0.006 * t + math.sin(a) * ry, cz) for a in [math.tau * k / 12 for k in range(12)]])
        put(subdivided(loft(rings, closed_end=True), self.levels), face, JAW, (0.0, 0.05))
        J = self.jaw.to_3x3().normalized()
        put(ellipsoid(self.jw(0.0, -0.004, 0.11), J, Vector((0.026, 0.008, 0.08)) * hs, 12, 6), lighten(GUM, 0.15), JAW)
        for s in (1.0, -1.0):
            base = self.jw(0.021 * s, -0.004, length * 0.62)
            put(cone(base, base + self.jb((0.0, fang * 0.45 * hs, 0.006 * hs)), 0.008 * hs), BONE, JAW)

        # Hair: the beard, the ruff round the face, the crest.
        centre_head = self.h(0.0, 0.01, -0.03)
        for k in range(20 if self.alpha else 8):
            u = self.uniform(-1.0, 1.0)
            t = self.uniform(0.05, 0.8)
            root = self.jw(u * 0.028, -0.032, t * length * 0.8)
            out = self.jb((u * 0.6, -1.0, 0.1)).normalized()
            colour = mix(beard, (0.9, 0.75, 0.45), self.uniform(0.0, 0.4)) if self.alpha else mix(beard, mane_fur, 0.3)
            self.clump(root, self.jb((u * 0.3, -0.7, -0.5)), self.uniform(0.05, 0.1) * hs * (1.2 if self.alpha else 0.8), 0.024 * hs, out, colour, JAW)
        for s in (1.0, -1.0):
            for k in range(28 if self.alpha else 12):
                y = self.uniform(-0.05, 0.075)
                root = self.h(0.07 * s, y, self.uniform(-0.03, 0.025))
                out = (root - centre_head).normalized()
                colour = mix(mix(mane_fur, beard, 0.3 if self.alpha else 0.1), fur, self.uniform(0.0, 0.3))
                self.clump(root, self.hb((0.5 * s, -0.25 - y, -1.0)), self.uniform(0.06, 0.1) * hs * (0.7 + 0.5 * b["mane"]), 0.024 * hs, out, colour, HEAD)
        for k in range(12 if self.alpha else 6):
            x = self.uniform(-0.05, 0.05)
            root = self.h(x, 0.088 - abs(x) * 0.3, self.uniform(-0.06, 0.03))
            out = (root - centre_head).normalized()
            self.clump(root, self.hb((x * 2.0, 0.45 if self.alpha else 0.15, -1.0)), self.uniform(0.04, 0.07) * hs * b["mane"] + 0.015, 0.024 * hs, out,
                       mix(mane_fur, fur, self.uniform(0.2, 0.5)), HEAD)

    def face_colour(self, t, phi):
        """The mandrill's face, as the shader cuts it (BaboonLook face())."""
        c = SKIN
        if -0.33 < phi < 0.93 and 0.05 < t < 0.8:
            rib = ((phi + 0.35) / 1.3 * 5.0) % 1.0
            c = SLATE if 0.14 < rib < 0.86 else GROOVE
        if (abs(phi - math.pi * 0.5) < 0.2 + 0.06 * t and t > 0.02) or (t > 0.84 and phi > -0.5):
            c = CRIMSON
        if 0.91 < t < 0.955 and phi > 1.25:
            c = WET
        return c

    # --- Putting it out ---

    def build(self, out_name):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.model = Model(self.bones)
        self.body()
        self.mane()
        self.head_parts()
        self.surface.free()

        data = bpy.data.armatures.new("Armature")
        armature = bpy.data.objects.new("Armature", data)
        bpy.context.collection.objects.link(armature)
        bpy.context.view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode="EDIT")
        for bone in self.bones:
            if bone in ("head", "jaw"):
                m = self.head if bone == "head" else self.jaw
                at = m.translation
                tail = at + m.to_3x3().normalized() @ Vector((0, 0, 0.06))
            elif bone == "mane":
                at = V(self.j["mane_xform"]["origin"])
                tail = at + self.up * 0.06
            else:
                at, end = self.segments[bone]
                tail = end if (end - at).length > 0.005 else at + Vector((0, 0.03, 0))
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
        normals = [self.model.normal_of.get(i, v.normal.copy()) for i, v in enumerate(mesh.vertices)]
        mesh.normals_split_custom_set_from_vertices(normals)
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]
        mesh.color_attributes.active_color_index = mesh.color_attributes.find("Col")
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]
        body.parent = armature
        body.modifiers.new("Armature", "ARMATURE").object = armature

        os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
        path = os.path.join(FOLDER, "models", out_name + ".glb")
        options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=True,
                       export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True)
        try:
            bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
        except TypeError:
            bpy.ops.export_scene.gltf(**options, export_colors=True)
        print("BUILT %s verts=%d faces=%d" % (out_name, len(mesh.vertices), len(mesh.polygons)))
        if PREVIEW_DIR and not self.low:
            self.previews(body, out_name)

    def previews(self, body, name):
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = False
        scene.render.resolution_x, scene.render.resolution_y = 800, 800
        scene.world = bpy.data.worlds.new("World")
        scene.world.color = (0.35, 0.38, 0.42)
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.lens = 70
        scene.collection.objects.link(camera)
        scene.camera = camera
        head = to_b(self.h(0.0, 0.0, 0.12))
        whole = to_b(V(self.j["chest"]) * 0.6 + V(self.j["pelvis"]) * 0.4)
        # (view, direction to the camera (Godot), what it looks at, how far)
        views = [("whole_quarter", Vector((0.8, 0.35, 0.8)), whole, 2.2), ("whole_side", Vector((1.0, 0.1, 0.0)), whole, 2.4),
                 ("face_front", Vector((0.0, 0.1, 1.0)), head, 0.75), ("face_quarter", Vector((0.7, 0.2, 0.8)), head, 0.75),
                 ("face_side", Vector((1.0, 0.05, 0.1)), head, 0.85)]
        for view, direction, target, far in views:
            offset = to_b(direction.normalized()) * far
            camera.location = target + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for kind, name in (("alpha", "mandrill"), ("baboon", "baboon")):
        for low in (False, True):
            Baboon(kind, low).build(name + ("_lo" if low else ""))

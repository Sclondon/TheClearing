"""Builds the spider monkey and exports it for Godot, in two levels of detail.

Run from the project root (Blender 4.3):
    blender --background --python creatures/spider_monkey/tools/build_spider_monkey.py [-- <preview folder>]

Writes creatures/spider_monkey/models/spider_monkey.glb and spider_monkey_lo.glb
(skinned, for SpiderMonkey) and, given a folder, renders previews into it.

What it models round is the skeleton SpiderMonkey
(creatures/spider_monkey/spider_monkey.gd) works out for itself as it stands on
all fours, written out by rest_joints.gd into rest_spider_monkey.json beside
this file (metres at size 1; Godot's axes: Y up, facing +Z, +X its left).
Everything is in those units and axes here, and turned to Blender's (Z up) only
as it is made.

- The body is the Skin modifier over a stick figure of the skeleton (a narrow
  chest over a round pot belly, the narrow hips; long thin arms and legs; hook
  hands of four long fingers bent a little in and no thumb; long feet with four
  toes and a great toe set apart to grip; the long tapering tail), smoothed
  with a Subdivision Surface, then shaped: the belly pushed out round and low.
- The head: small and round, the braincase high; a short muzzle; big eyes set
  close and forward in shallow sockets under a little brow; the wide-set,
  sideways nostrils of a New World monkey; lips, a hinged lower jaw, small teeth
  and canines that show when it shrieks; small ears.
- The coat: many small clumps of hair, each a tapering strand that lies along
  the body (down the back and flanks, down the limbs, back along the tail),
  long and shaggy on the back, shoulders, flanks and the outsides of the limbs,
  short on the head (swept forward on the crown, as spider monkeys' is) and the
  tail. Each clump's normals are bent out from the body under it, so the coat
  takes the light as one soft mass and only its edge is ragged. The face, the
  hands and feet and the grip pad under the end of the tail are bare.
- Colours are vertex colours: the coat near black-brown, browner under the
  belly and inside the limbs; the bare face dark grey, with pale bare skin round
  the eyes and over the muzzle (its mask); the hands, feet and pad dark. The
  first UV says how wet a point is (x: eyes, nose, lips) and how much it is fur
  (y); the second where it was on the standing body.
- The skeleton is SpiderMonkey.BONES, none the child of another, each where
  SpiderMonkey puts it as it stands. Every vertex of the body is weighted by how
  near it is to each bone (two or three at most); each clump of hair goes with
  the body where it is rooted; the head's parts go to the head, the jaw's to
  the jaw.
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

COAT = (0.085, 0.072, 0.06)
COAT_TIP = (0.13, 0.11, 0.09)
BELLY = (0.105, 0.088, 0.072)
SKIN = (0.13, 0.12, 0.12)
MASK = (0.4, 0.36, 0.33)
PALM = (0.07, 0.06, 0.06)
PAD = (0.2, 0.16, 0.145)
EYE = (0.05, 0.03, 0.02)
IRIS = (0.12, 0.065, 0.03)
MOUTH = (0.06, 0.02, 0.022)
TOOTH = (0.78, 0.74, 0.62)
NAIL = (0.05, 0.045, 0.04)


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


class Model:
    """The mesh as it is put together: one bmesh, with per-vertex data."""

    def __init__(self, bones):
        self.bm = bmesh.new()
        self.uv0 = self.bm.loops.layers.uv.new("UVMap")
        self.uv1 = self.bm.loops.layers.uv.new("UV2")
        self.col = self.bm.verts.layers.float_color.new("Col")
        self.deform = self.bm.verts.layers.deform.verify()
        self.bones = bones
        self.normal_of = {}  # vertex index -> a normal of its own (hair)
        self.vert_uv = []

    def add(self, mesh, info, normals=None):
        """Adds a Blender mesh (Blender's axes). info(index, godot_position, godot_normal) ->
        (colour, uv0, uv1, {bone: weight}). normals: one of its own for every vertex (Blender axes)."""
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
    """A UV sphere (Godot space: centre, a 3x3 basis as a Matrix, radii)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        local = Vector((v.co.x * radii[0], v.co.z * radii[1], -v.co.y * radii[2]))
        v.co = to_b(centre + basis @ local)
    return mesh_from_bm(bm)


def cone(base, tip, radius, sides=6):
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


class Monkey:
    def __init__(self, low):
        self.low = low
        with open(os.path.join(HERE, "rest_spider_monkey.json")) as f:
            self.j = json.load(f)
        j = self.j
        self.bones = j["bones"]
        self.levels = 0 if low else 1
        self.side = V(j["torso"][0])
        self.spine = V(j["torso"][1])
        self.front = V(j["torso"][2])  # (out of its belly: down and a little ahead, on all fours)
        self.head = xform(j["head_xform"])
        self.jaw = xform(j["jaw_xform"])
        self.rng_state = 29
        self.hair_count = 0
        s = {}
        pel, bel, che, nec = V(j["pelvis"]), V(j["belly"]), V(j["chest"]), V(j["neck"])
        s["hips"] = (pel - self.spine * 0.06, pel)
        s["belly"] = (pel, bel)
        s["chest"] = (bel, che)
        s["neck"] = (che, nec)
        s["head"] = (nec, V(j["head_xform"]["origin"]))
        for i, side in enumerate(["l", "r"]):
            # (the shoulder and hip weighted from a little way down the limb, so the chest and haunch keep their shape)
            s["arm_" + side] = (V(j["roots"][i]).lerp(V(j["mids"][i]), 0.18), V(j["mids"][i]))
            s["forearm_" + side] = (V(j["mids"][i]), V(j["ends"][i]))
            hand_y = basis3(j["hands"][i]).col[1]
            s["hand_" + side] = (V(j["ends"][i]), V(j["knuckles"][i]))
            s["fingers_" + side] = (V(j["knuckles"][i]), V(j["knuckles"][i]) + hand_y * 0.075)
            s["thigh_" + side] = (V(j["roots"][i + 2]).lerp(V(j["mids"][i + 2]), 0.15), V(j["mids"][i + 2]))
            s["shin_" + side] = (V(j["mids"][i + 2]), V(j["ends"][i + 2]))
            foot_y = basis3(j["hands"][i + 2]).col[1]
            s["foot_" + side] = (V(j["ends"][i + 2]), V(j["knuckles"][i + 2]))
            s["toes_" + side] = (V(j["knuckles"][i + 2]), V(j["knuckles"][i + 2]) + foot_y * 0.045)
        s["jaw"] = (self.jaw.translation, self.jaw @ Vector((0, -0.01, 0.04)))
        self.tail = [V(p) for p in j["tail"]]
        for k in range(10):
            s["tail_%d" % (k + 1)] = (self.tail[k], self.tail[k + 1])
        self.segments = s
        self.body_bones = [b for b in self.bones if b not in ("jaw", "head")]

    def rand(self):
        self.rng_state = (self.rng_state * 1103515245 + 12345) % 2147483648
        return self.rng_state / 2147483648.0

    def uniform(self, a, b):
        return a + (b - a) * self.rand()

    def h(self, x, y, z):
        return self.head @ Vector((x, y, z))

    def hb(self, v):
        return self.head.to_3x3() @ Vector(v)

    def jw(self, x, y, z):
        return self.jaw @ Vector((x, y, z))

    def nearest(self, p, among=None, count=3):
        found = []
        for bone, (a, b) in self.segments.items():
            if among is not None and bone not in among:
                continue
            d = dist_segment(p, a, b)
            if bone[:-2] in ("arm", "thigh"):
                # (a limb takes nothing from short of where it leaves the body: the chest
                # and haunch keep their own shape however the limb is turned)
                ab = b - a
                t = (p - a).dot(ab) / max(ab.length_squared, 1e-12)
                if t < 0.0:
                    d += -t * ab.length * 3.0 + 0.02
            found.append((d, bone))
        found.sort()
        found = found[:count]
        weights = {}
        for d, bone in found:
            weights[bone] = 1.0 / (d ** 4 + 1e-10)
        best = max(weights.values())
        return {k: w for k, w in weights.items() if w > best * 0.03}

    @staticmethod
    def noise_uv(p):
        return (p.x * 1.6 + p.z * 1.1, p.y * 1.6 + p.z * 0.5)

    def put(self, mesh, colour, weights, uv0=(0.0, 0.0)):
        def info(i, p, n):
            c = colour(p, n) if callable(colour) else colour
            w = weights(p) if callable(weights) else weights
            return c, uv0, self.noise_uv(p), w
        self.model.add(mesh, info)
        bpy.data.meshes.remove(mesh)

    # --- The body ---

    def skin_colour(self, p, n):
        """The skin under the coat (seen only between clumps): dark, browner under the belly."""
        under = smooth(0.2, 0.9, n.dot(self.front))
        # (darker than the hair over it: where it shows between clumps it reads as the depth of the coat)
        c = mix(mix(COAT, (0.0, 0.0, 0.0), 0.55), BELLY, under * 0.25)
        # The hands and feet, and the end of the tail, bare and dark.
        for i in range(4):
            a, b = V(self.j["ends"][i]), V(self.j["knuckles"][i])
            if dist_segment(p, a, b + (b - a).normalized() * 0.08) < 0.03:
                c = mix(c, PALM, smooth(0.1, 0.6, along_segment(p, a - (b - a).normalized() * 0.015, b)) * 0.9 + 0.1)
        return c

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
        tail = self.tail
        t0 = add(tail[0] + sp * 0.01, 0.03)
        pv = add(pel, 0.056, t0)
        b1 = add(pel.lerp(bel, 0.55) + fr * 0.01, 0.072, pv)
        bl = add(bel + fr * 0.02, 0.08, b1)
        c1 = add(bel.lerp(che, 0.55) + fr * 0.006, 0.064, bl)
        ch = add(che, 0.058, c1)
        sh = add(che + sp * 0.02, 0.052, ch)
        n1 = add(che.lerp(nec, 0.6) + sp * 0.006, 0.03, sh)
        nk = add(nec, 0.027, n1)
        add(nec.lerp(hd, 0.5), 0.028, nk)
        for i in range(4):
            arm = i < 2
            sign = 1.0 if i % 2 == 0 else -1.0
            root, mid, end = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            hand = basis3(j["hands"][i])
            hy, hx, hz = hand.col[1], hand.col[0], hand.col[2]  # (along, its left, palm side)
            knuckle = V(j["knuckles"][i])
            if arm:
                a = add(root, 0.03, sh)
                a2 = add(root.lerp(mid, 0.45), 0.021, a)
                m = add(mid, 0.0175, a2)
                m2 = add(mid.lerp(end, 0.45), 0.0175, m)
                e = add(end, 0.0125, m2)
                palm = add(end.lerp(knuckle, 0.55), (0.0135, 0.009), e)
                k0 = add(knuckle, (0.0125, 0.008), palm)
                # Four long fingers, side by side, each bent a little in: a hook.
                for f in range(4):
                    x = (f - 1.5) * 0.0062
                    way = hy
                    at = knuckle + hx * x
                    last = add(at, 0.0048, k0)
                    for k, length in enumerate((0.026, 0.021, 0.017)):
                        way = (way + hz * 0.24).normalized()
                        at = at + way * length * (0.92 if f in (0, 3) else 1.0)
                        last = add(at, 0.0052 - k * 0.0006, last)
                # (no thumb: a small bump where one would be)
                add(end.lerp(knuckle, 0.35) + hx * sign * 0.011 + hz * 0.004, 0.0055, palm)
            else:
                a = add(root, 0.04, pv)
                a2 = add(root.lerp(mid, 0.45), 0.03, a)
                m = add(mid, 0.0185, a2)
                m2 = add(mid.lerp(end, 0.4), 0.0175, m)
                e = add(end, 0.013, m2)
                heel = add(end - hy * 0.012 + hz * 0.012, 0.012, e)
                sole = add(end.lerp(knuckle, 0.6) + hz * 0.004, (0.015, 0.009), heel)
                k0 = add(knuckle, (0.014, 0.008), sole)
                for f in range(4):
                    x = (f - 1.2) * 0.0065 * -sign
                    way = hy
                    at = knuckle + hx * x
                    last = add(at, 0.0048, k0)
                    for k, length in enumerate((0.02, 0.016, 0.013)):
                        way = (way + hz * 0.25).normalized()
                        at = at + way * length
                        last = add(at, 0.0043 - k * 0.0006, last)
                # The great toe, set apart and turned in, to grip.
                way = (hy * 0.55 + hx * sign * 0.8).normalized()
                at = end.lerp(knuckle, 0.35) + hx * sign * 0.011
                last = add(at, 0.006, sole)
                for k, length in enumerate((0.02, 0.016)):
                    way = (way + hy * 0.3 + hz * 0.15).normalized()
                    at = at + way * length
                    last = add(at, 0.0052 - k * 0.0008, last)
        last = t0
        for k in range(1, 11):
            last = add(tail[k], 0.021 * (1.0 - k / 11.0) ** 0.7 + 0.005, last)
        mesh = skinned(points, edges, radii, pv, self.levels)
        self.shape_body(mesh)

        def info(i, p, n):
            return self.skin_colour(p, n), (0.0, 0.7), self.noise_uv(p), self.nearest(p, self.body_bones, 3)
        self.model.add(mesh, info)
        bpy.data.meshes.remove(mesh)
        self.surface = self.model.bm.copy()
        self.bvh = BVHTree.FromBMesh(self.surface)
        self.tail_pad()

    def shape_body(self, mesh):
        """The pot belly pushed out round and low; the chest narrowed."""
        j = self.j
        bel, che = V(j["belly"]), V(j["chest"])
        belly_at = bel + self.front * 0.05 - self.spine * 0.02
        for v in mesh.vertices:
            p = from_b(v.co)
            n = from_b(v.normal).normalized()
            d = (p - belly_at).length
            push = 0.026 * math.exp(-(d / 0.075) ** 2) * max(0.0, n.dot(self.front) * 0.8 + 0.35)
            v.co = to_b(p + n * push)
        mesh.update()


    def tail_pad(self):
        """The bare grip pad under the last part of the tail: ridged skin."""
        for k in range(7, 10):
            a, b = self.tail[k], self.tail[k + 1]
            axis = (b - a).normalized()
            under = -(Vector((0, 1, 0)) - axis * axis.y).normalized()
            steps = 3 if self.low else 6
            for s in range(steps):
                u = (s + 0.5) / steps
                c = a.lerp(b, u)
                r = 0.021 * (1.0 - (k + u) / 11.0) ** 0.7 + 0.005
                across = axis.cross(under).normalized()
                basis = Matrix((across, axis, under)).transposed()
                self.put(ellipsoid(c + under * r * 0.45, basis, Vector((r * 0.75, (b - a).length / steps * 0.55, r * 0.6)), 8, 6),
                         PAD, {"tail_%d" % (k + 1): 1.0}, (0.15, 0.0))

    def on_body(self, axis, out):
        """Where a ray from `axis` (inside the body) going `out` leaves it (Godot): from
        inside, so that it finds the body there and not a limb lying against it."""
        hit = self.bvh.ray_cast(to_b(axis), to_b(out), 0.3)
        if hit[0] is None:
            return None
        return from_b(hit[0])

    # --- The coat ---

    def clump(self, root, hang, length, width, out, colour, weights, sides=3, rings=3):
        """A tapering strand of hair from `root`, lying along `hang` over the body (`out` its normal)."""
        if self.low:
            sides, rings = 3, 2
        out = out.normalized()
        hang = hang.normalized()
        hang = (hang - out * hang.dot(out) + out * 0.05).normalized()
        across = out.cross(hang)
        if across.length < 1e-6:
            across = Vector((1, 0, 0))
        across.normalize()
        lift = hang.cross(across).normalized()
        if lift.dot(out) < 0:
            lift = -lift
        bm = bmesh.new()
        rings_v = []
        for r in range(rings):
            s = r / rings
            centre = root + hang * length * s + lift * width * 0.2 * s + Vector((0, -1, 0)) * length * 0.06 * s * s
            w = width * (1.0 - s * 0.8)
            ring = []
            for k in range(sides):
                a = math.tau * k / sides + 0.4
                ring.append(bm.verts.new(to_b(centre + across * math.cos(a) * w * 0.55 + lift * math.sin(a) * w * 0.22)))
            rings_v.append(ring)
        tip_p = root + hang * length + lift * width * 0.2 + Vector((0, -1, 0)) * length * 0.06
        tip = bm.verts.new(to_b(tip_p))
        for r in range(rings - 1):
            for k in range(sides):
                bm.faces.new((rings_v[r][k], rings_v[r][(k + 1) % sides], rings_v[r + 1][(k + 1) % sides], rings_v[r + 1][k]))
        for k in range(sides):
            bm.faces.new((rings_v[-1][k], rings_v[-1][(k + 1) % sides], tip))
        bm.faces.new(list(reversed(rings_v[0])))
        mesh = mesh_from_bm(bm)
        normal = to_b((out + hang * 0.15).normalized())
        count = len(mesh.vertices)

        def info(i, p, n):
            s = min(1.0, (p - root).length / max(length, 1e-6))
            return mix(colour, mix(colour, COAT_TIP, 0.6), s), (0.0, 1.0), self.noise_uv(root), weights

        self.model.add(mesh, info, [normal] * count)
        bpy.data.meshes.remove(mesh)
        self.hair_count += 1

    def coat(self):
        j = self.j
        lo = 0.27 if self.low else 0.6
        pel, bel, che, nec = V(j["pelvis"]), V(j["belly"]), V(j["chest"]), V(j["neck"])
        sp, fr, sd = self.spine, self.front, self.side
        back = -fr
        # The torso: rows from the neck to the rump, round the back and flanks, sparse and short under the belly.
        rows = int(32 * lo) + 4
        for row in range(rows):
            u = (row + self.uniform(0.2, 0.8)) / rows
            axis = nec.lerp(che, min(u * 3.0, 1.0)).lerp(bel, smooth(0.33, 0.66, u)).lerp(pel - sp * 0.04, smooth(0.66, 1.0, u))
            count = int((36 + 10 * math.sin(math.pi * u)) * lo) + 4
            for k in range(count):
                around = -math.pi + math.tau * (k + self.uniform(0.2, 0.8)) / count
                out = (back * math.cos(around) + sd * math.sin(around)).normalized()
                belly_side = max(0.0, -math.cos(around))
                root = self.on_body(axis, out)
                if root is None:
                    continue
                root -= out * 0.005
                flank = abs(math.sin(around))
                # (down the back towards the rump; down the flanks; the belly's short and browner)
                hang = -sp * (0.9 - 0.4 * flank) + Vector((0, -1, 0)) * (0.2 + 0.9 * flank) + out * 0.1
                length = (0.045 + 0.022 * flank + 0.02 * math.sin(math.pi * u)) * (1.0 - 0.3 * belly_side) + self.uniform(0.0, 0.02)
                width = self.uniform(0.018, 0.026) * (1.25 if self.low else 1.0)
                tone = mix(COAT, BELLY, belly_side * 0.8)
                self.clump(root, hang, length, width, out, mix(tone, COAT_TIP, self.uniform(0.0, 0.25)), self.nearest(root, self.body_bones, 2))
        # The neck, shaggy behind and short under the throat, lying back over the shoulders.
        hd = V(j["head_xform"]["origin"])
        for row in range(int(8 * lo) + 3):
            u = (row + self.uniform(0.2, 0.8)) / (int(8 * lo) + 3)
            axis = che.lerp(nec.lerp(hd, 0.4), u)
            count = int(22 * lo) + 6
            for k in range(count):
                around = -math.pi + math.tau * (k + self.uniform(0.2, 0.8)) / count
                out = (back * math.cos(around) + sd * math.sin(around)).normalized()
                root = self.on_body(axis, out)
                if root is None:
                    continue
                throat = max(0.0, -math.cos(around))
                hang = -sp * 0.8 + Vector((0, -1, 0)) * 0.5
                self.clump(root - out * 0.004, hang, (0.04 - 0.02 * throat) + self.uniform(0.0, 0.015), self.uniform(0.016, 0.022) * (1.25 if self.low else 1.0),
                           out, mix(COAT, BELLY, throat * 0.5), self.nearest(root, self.body_bones, 2))
        # The limbs: down each, long on the outside, short inside, none on the hands and feet.
        for i in range(4):
            arm = i < 2
            sign = 1.0 if i % 2 == 0 else -1.0
            root_j, mid, end = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            for seg, (a, b) in enumerate(((root_j, mid), (mid, end))):
                axis_dir = (b - a).normalized()
                ref = sd * sign
                o1 = (ref - axis_dir * ref.dot(axis_dir)).normalized()
                o2 = axis_dir.cross(o1).normalized()
                along_n = int(9 * lo) + 3
                round_n = int(10 * lo) + 4
                for s in range(along_n):
                    t = (s + self.uniform(0.1, 0.9)) / along_n
                    if seg == 1 and t > 0.88:
                        continue
                    axis = a.lerp(b, t)
                    for k in range(round_n):
                        around = math.tau * (k + self.uniform(0.15, 0.85)) / round_n
                        out = (o1 * math.cos(around) + o2 * math.sin(around)).normalized()
                        root = self.on_body(axis, out)
                        if root is None:
                            continue
                        outside = 0.5 + 0.5 * math.cos(around)
                        length = (0.026 + 0.02 * outside) * (1.1 if seg == 0 else 0.8) + self.uniform(0.0, 0.01)
                        if not arm and seg == 0:
                            length += 0.012
                        hang = axis_dir * 0.85 + Vector((0, -1, 0)) * 0.3
                        self.clump(root - out * 0.004, hang, length, self.uniform(0.014, 0.02) * (1.25 if self.low else 1.0), out,
                                   mix(COAT, BELLY, (1.0 - outside) * 0.45), self.nearest(root, self.body_bones, 2))
        # The tail: short hair back along it, but under its last part (the pad).
        for k in range(10):
            a, b = self.tail[k], self.tail[k + 1]
            axis_dir = (b - a).normalized()
            up = (Vector((0, 1, 0)) - axis_dir * axis_dir.y).normalized()
            across = axis_dir.cross(up).normalized()
            n_along = int(3 * lo) + 2
            n_round = int(8 * lo) + 4
            for s in range(n_along):
                t = (s + self.uniform(0.1, 0.9)) / n_along
                axis = a.lerp(b, t)
                for q in range(n_round):
                    around = math.tau * (q + self.uniform(0.2, 0.8)) / n_round
                    out = (up * math.cos(around) + across * math.sin(around)).normalized()
                    if k >= 7 and math.cos(around) < 0.1:
                        continue
                    root = self.on_body(axis, out)
                    if root is None:
                        continue
                    length = (0.032 - 0.018 * k / 10.0) + self.uniform(0.0, 0.01)
                    self.clump(root - out * 0.003, axis_dir, length, 0.014 * (1.25 if self.low else 1.0), out, COAT, {"tail_%d" % (k + 1): 1.0})

    # --- The head ---

    def eye_at(self, s):
        return self.h(0.0165 * s, 0.006, 0.033)

    def face_colour(self, p, n):
        """The bare face: dark grey, with pale skin in a ring round each eye and over the muzzle and lips."""
        local = self.head.inverted() @ p
        pale = 0.0
        for s in (1.0, -1.0):
            d = Vector(((local.x - 0.0165 * s) / 1.1, local.y - 0.006, (local.z - 0.03) * 0.6)).length
            pale = max(pale, smooth(0.0175, 0.013, d) * smooth(0.0088, 0.0102, d))
        # (the muzzle: inside a shell a little bigger than it)
        m = Vector((local.x / 0.024, (local.y + 0.019) / 0.019, (local.z - 0.032) / 0.021)).length
        pale = max(pale, smooth(1.02, 0.8, m) * smooth(0.036, 0.044, local.z))
        return mix(SKIN, MASK, pale * 0.9)

    def head_parts(self):
        H = self.head.to_3x3().normalized()
        HEAD = {"head": 1.0}
        JAW = {"jaw": 1.0}
        seg = 10 if self.low else 20
        # The braincase, round and high; its front bare (the face).
        to_head = self.head.inverted()

        def skull_colour(p, n):
            local = to_head @ p
            bare = smooth(0.012, 0.03, local.z) * smooth(0.03, 0.016, local.y)
            return mix(COAT, self.face_colour(p, n), bare)
        self.put(ellipsoid(self.h(0.0, 0.012, -0.008), H, Vector((0.037, 0.036, 0.042)), seg, seg // 2 + 2), skull_colour, HEAD, (0.0, 0.5))
        # The face: a flat oval under the brow, and the short muzzle.
        self.put(ellipsoid(self.h(0.0, -0.002, 0.021), H, Vector((0.029, 0.028, 0.017)), seg, seg // 2), self.face_colour, HEAD)
        self.put(ellipsoid(self.h(0.0, -0.017, 0.032), H, Vector((0.021, 0.015, 0.017)), seg, seg // 2), self.face_colour, HEAD, (0.1, 0.0))
        # A low brow over the eyes, of the face's own dark skin.
        self.put(ellipsoid(self.h(0.0, 0.0185, 0.025), H, Vector((0.028, 0.0055, 0.01)), 14, 8), SKIN, HEAD)
        # The eyes: big, set close and forward, dark and wet, in shallow sockets.
        for s in (1.0, -1.0):
            self.put(ellipsoid(self.h(0.0165 * s, 0.006, 0.031), H, Vector((0.0105, 0.0095, 0.007)), 12, 8), (0.035, 0.03, 0.03), HEAD)
            self.put(ellipsoid(self.eye_at(s), H, Vector((0.0078, 0.0078, 0.0068)), 12, 8), EYE, HEAD, (1.0, 0.0))
            self.put(ellipsoid(self.eye_at(s) + self.hb((0.0, 0.0, 0.0062)), H, Vector((0.0052, 0.0052, 0.0016)), 10, 6), IRIS, HEAD, (1.0, 0.0))
            self.put(ellipsoid(self.eye_at(s) + self.hb((0.0, 0.0, 0.0078)), H, Vector((0.0028, 0.0028, 0.001)), 8, 6), (0.01, 0.01, 0.01), HEAD, (1.0, 0.0))
        # The nostrils: wide apart, opening to the sides (a New World monkey's).
        for s in (1.0, -1.0):
            self.put(ellipsoid(self.h(0.0105 * s, -0.009, 0.046), H @ Matrix.Rotation(0.9 * s, 3, "Y"), Vector((0.004, 0.0022, 0.0018)), 8, 6), (0.03, 0.025, 0.025), HEAD, (0.8, 0.0))
        # The upper lip, the mouth inside, small teeth and the upper canines.
        self.put(ellipsoid(self.h(0.0, -0.027, 0.038), H, Vector((0.018, 0.0055, 0.012)), 12, 8), mix(SKIN, MASK, 0.6), HEAD, (0.4, 0.0))
        self.put(ellipsoid(self.h(0.0, -0.03, 0.03), H, Vector((0.016, 0.007, 0.02)), 10, 6), MOUTH, HEAD, (0.7, 0.0))
        for s in (1.0, -1.0):
            base = self.h(0.0105 * s, -0.0235, 0.041)
            self.put(cone(base, base + self.hb((0.0, -0.0072, 0.001)), 0.0024), TOOTH, HEAD, (0.6, 0.0))
            for k in range(2):
                tb = self.h((0.003 + k * 0.004) * s, -0.0255, 0.046 - k * 0.002)
                self.put(cone(tb, tb + self.hb((0.0, -0.005, 0.0)), 0.0022, 5), TOOTH, HEAD, (0.6, 0.0))
        # The lower jaw and chin, its lip, its teeth.
        J = self.jaw.to_3x3().normalized()
        self.put(ellipsoid(self.jw(0.0, -0.009, 0.028), J, Vector((0.018, 0.009, 0.021)), 14, 8), self.face_colour, JAW, (0.0, 0.0))
        self.put(ellipsoid(self.jw(0.0, -0.002, 0.03), J, Vector((0.014, 0.004, 0.016)), 10, 6), MOUTH, JAW, (0.7, 0.0))
        for s in (1.0, -1.0):
            base = self.jw(0.0085 * s, -0.0065, 0.038)
            self.put(cone(base, base + self.jw(0.0, 0.0055, 0.0) - self.jaw.translation, 0.002, 5), TOOTH, JAW, (0.6, 0.0))
        # Small round ears, set low on the sides of the head, half in the hair.
        for s in (1.0, -1.0):
            ear = H @ Matrix.Rotation(0.5 * s, 3, "Y")
            self.put(ellipsoid(self.h(0.036 * s, 0.006, -0.008), ear, Vector((0.005, 0.013, 0.011)), 10, 6), SKIN, HEAD, (0.0, 0.2))
        # Hair: short over the braincase, swept forward on the crown to a fringe over the brow,
        # a ruff round the face and down the cheeks.
        centre = self.h(0.0, 0.012, -0.008)
        crown = int(70 * (0.4 if self.low else 1.0))
        for k in range(crown):
            a = self.uniform(-math.pi, math.pi)
            b = self.uniform(-0.2, 1.35)
            out = self.hb((math.sin(a) * math.cos(b), math.sin(b), math.cos(a) * math.cos(b))).normalized()
            local = (to_head @ (centre + out * 0.04))
            if local.z > 0.012 and local.y < 0.028:
                continue
            root = centre + out * 0.034
            hang = self.hb((0.0, 0.2, 1.0)) if local.y > 0.02 else (self.hb((0.0, -0.5, -0.8)) - out * 0.2)
            self.clump(root, hang, self.uniform(0.018, 0.03), 0.014 * (1.25 if self.low else 1.0), out, COAT, HEAD)
        ruff = int(26 * (0.45 if self.low else 1.0))
        for k in range(ruff):
            a = self.uniform(-1.0, 1.0)
            side = 1.0 if k % 2 == 0 else -1.0
            root = self.h(0.03 * side, -0.004 + a * 0.02, 0.012 + self.uniform(-0.01, 0.006))
            out = self.hb((side, 0.0, 0.25)).normalized()
            self.clump(root, self.hb((side * 0.6, -0.6, -0.5)), self.uniform(0.02, 0.032), 0.013 * (1.25 if self.low else 1.0), out, mix(COAT, COAT_TIP, 0.3), HEAD)

    # --- Putting it out ---

    def build(self, out_name):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.model = Model(self.bones)
        self.body()
        self.coat()
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
                tail = at + m.to_3x3().normalized() @ Vector((0, 0, 0.04))
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
                       export_materials="PLACEHOLDER", export_normals=True, export_texcoords=True, use_selection=False)
        try:
            bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
        except TypeError:
            bpy.ops.export_scene.gltf(**options, export_colors=True)
        print("BUILT %s verts=%d faces=%d hair=%d" % (out_name, len(mesh.vertices), len(mesh.polygons), self.hair_count))
        if PREVIEW_DIR and not self.low:
            self.previews(out_name)

    def previews(self, name):
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.display.shading.show_cavity = False
        scene.render.resolution_x, scene.render.resolution_y = 700, 700
        scene.world = bpy.data.worlds.new("World")
        scene.world.color = (0.55, 0.57, 0.6)
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.lens = 70
        scene.collection.objects.link(camera)
        scene.camera = camera
        head = to_b(self.h(0.0, 0.0, 0.02))
        whole = to_b(Vector((0.0, 0.3, -0.15)))
        views = [("whole_quarter", Vector((0.8, 0.35, 0.8)), whole, 3.4), ("whole_side", Vector((1.0, 0.1, 0.0)), whole, 3.4), ("whole_below", Vector((0.5, -0.8, 0.4)), whole, 2.0),
                 ("face_front", Vector((0.0, 0.05, 1.0)), head, 0.5), ("face_quarter", Vector((0.7, 0.15, 0.8)), head, 0.5),
                 ("face_side", Vector((1.0, 0.05, 0.05)), head, 0.55)]
        for view, direction, target, far in views:
            offset = to_b(direction.normalized()) * far
            camera.location = target + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    Monkey(False).build("spider_monkey")
    Monkey(True).build("spider_monkey_lo")

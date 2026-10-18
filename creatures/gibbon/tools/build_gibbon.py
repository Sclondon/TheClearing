"""Builds the gibbon, and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/gibbon/tools/build_gibbon.py

Writes creatures/gibbon/models/gibbon.glb and gibbon_lo.glb.

What it models round is the skeleton Gibbon (creatures/gibbon/gibbon.gd) works
out for itself as it stands, written out by rest_joints.gd into
rest_gibbon.json beside this file (metres at size 1, about 0.8 m standing;
Godot's axes: Y up, facing +Z, +X its left). Everything is in those units and
axes here, and turned to Blender's (Z up) only as it is made.

- The body is the Skin modifier over a stick figure of the skeleton (spine,
  shoulders and hips, the long arms, the short legs, the four long fingers and
  small low thumb of each hand, the long toes and the big toe set apart on each
  foot), smoothed with a Subdivision Surface: one organic surface.
- The head: a small round skull; a flat bare face with a heavy brow over deep
  sockets and small wet eyes, a low flat nose, a short muzzle and a lower jaw on
  its own bone, long upper canines and short lower ones. Small ears.
- Fur: many small clumps, each a tapering strand of three sides laid along the
  body and standing a little off it, shaggy: down the back and sides, down the
  upper arms to the elbow and up the forearms to it (as an ape's lies), down the
  legs, back over the crown, and a ring standing out round the face. Each
  clump's normals are bent out from the body under it, so the coat takes the
  light as one soft mass and only its edge is ragged.
- No colours: masks in the vertex colours, for GibbonLook to colour (red: how
  light the coat is, half being as it is; green: the pale ring, hands and feet;
  blue: bare skin); its first UV marks the eyes (x 1), the teeth (x 2) and fur
  (y); its second is where each point was, for the streaks.
- The skeleton is Gibbon.BONES, none the child of another, each where Gibbon
  puts it as it stands. Every vertex is weighted by how near it is to each bone
  (three at most), the head's parts to the head, the jaw's to the jaw.
"""

import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)


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


def smooth(a, b, x):
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


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
        self.normal_of = {}
        self.vert_uv = []

    def add(self, mesh, info, normals=None):
        """Adds a Blender mesh. info(index, godot_position, blender_normal) -> (mask, uv0, uv1, {bone: weight})."""
        made = []
        for v in mesh.vertices:
            nv = self.bm.verts.new(v.co)
            mask, uv0, uv1, weights = info(v.index, from_b(v.co), v.normal)
            nv[self.col] = (mask[0], mask[1], mask[2], 1.0)
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
                loop[self.uv0].uv = (uv0[0], 1.0 - uv0[1])
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
        rr = r if isinstance(r, tuple) else (r, r)
        mesh.skin_vertices[0].data[i].radius = rr
        mesh.skin_vertices[0].data[i].use_root = i == root
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return evaluated(obj)


def ellipsoid(centre, basis, radii, segments=16, rings=10):
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


SKIN = (0.5, 0.0, 1.0)
SKIN_PALE = (0.5, 0.0, 0.85)


class Gibbon:
    def __init__(self, low):
        self.low = low
        with open(os.path.join(HERE, "rest_gibbon.json")) as f:
            self.j = json.load(f)
        j = self.j
        self.bones = j["bones"]
        self.levels = 1 if low else 2
        self.fur = 0.55 if low else 1.0
        self.model = Model(self.bones)
        self.up = V(j["torso"][1])
        self.side = V(j["torso"][0])
        self.fwd = V(j["torso"][2])
        self.head = xform(j["head_xform"])
        self.jaw = xform(j["jaw_xform"])
        self.rng_state = 21
        self.segments = {}
        for bone, a, b in [("rump", "rump", "pelvis"), ("belly", "pelvis", "mid"), ("chest", "mid", "chest"), ("neck", "chest", "neck")]:
            self.segments[bone] = (V(j[a]), V(j[b]))
        self.segments["head"] = (V(j["neck"]), V(j["head_xform"]["origin"]))
        for i, s in enumerate(["l", "r"]):
            self.segments["arm_" + s] = (V(j["roots"][i]), V(j["mids"][i]))
            self.segments["forearm_" + s] = (V(j["mids"][i]), V(j["ends"][i]))
            self.segments["hand_" + s] = (V(j["ends"][i]), V(j["knuckles"][i]))
            self.segments["fingers_" + s] = (V(j["knuckles"][i]), V(j["tips"][i]))
            self.segments["thigh_" + s] = (V(j["roots"][i + 2]), V(j["mids"][i + 2]))
            self.segments["shin_" + s] = (V(j["mids"][i + 2]), V(j["ends"][i + 2]))
            self.segments["foot_" + s] = (V(j["ends"][i + 2]), V(j["knuckles"][i + 2]))
            self.segments["toes_" + s] = (V(j["knuckles"][i + 2]), V(j["tips"][i + 2]))

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
            found.append((dist_segment(p, a, b), bone))
        found.sort()
        weights = {}
        for d, bone in found[:count]:
            weights[bone] = 1.0 / (d ** 4 + 1e-10)
        best = max(weights.values())
        return {k: w for k, w in weights.items() if w > best * 0.02}

    @staticmethod
    def noise_uv(p):
        return (p.x * 0.8 + p.z * 0.6, p.y + p.z * 0.3)

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

        R, Pv, M, C, N = P("rump"), P("pelvis"), P("mid"), P("chest"), P("neck")
        H = V(j["head_xform"]["origin"])
        up, side, fwd = self.up, self.side, self.fwd
        r0 = add(R, 0.05)
        pel = add(Pv, 0.075, r0)
        w = add(Pv.lerp(M, 0.55) + fwd * 0.008, 0.066, pel)
        mid = add(M + fwd * 0.01, 0.07, w)
        c1 = add(M.lerp(C, 0.5) + fwd * 0.012, 0.08, mid)
        ch = add(C - up * 0.02, 0.078, c1)
        n1 = add(C.lerp(N, 0.6), 0.04, ch)
        nk = add(N, 0.034, n1)
        add(N.lerp(H, 0.55), 0.03, nk)
        self.hand_points = []
        for i in range(4):
            arm = i < 2
            sign = 1.0 if i % 2 == 0 else -1.0
            root, midj, end = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            knuckle, tip = V(j["knuckles"][i]), V(j["tips"][i])
            if arm:
                sh = add(C + side * sign * 0.06 - up * 0.01, 0.05, ch)
                a = add(root, 0.046, sh)
                a2 = add(root.lerp(midj, 0.45), 0.04, a)
                m = add(midj, 0.031, a2)
                m2 = add(midj.lerp(end, 0.45), 0.029, m)
                m3 = add(midj.lerp(end, 0.85), 0.02, m2)
                e = add(end, 0.018, m3)
                # The palm, long and narrow; four long fingers; a small thumb set low by the wrist.
                along = (knuckle - end).normalized()
                bend = (tip - knuckle).normalized()
                across = along.cross(self.fwd if abs(along.dot(self.fwd)) < 0.9 else self.up).normalized()
                palm = add(end.lerp(knuckle, 0.55), (0.019, 0.019), e)
                for f in range(4):
                    x = (f - 1.5) * 0.0105
                    k0 = add(knuckle + across * x, 0.0085, palm)
                    k1 = add(knuckle + across * x * 1.05 + along * 0.035 + bend * 0.012, 0.0075, k0)
                    k2 = add(knuckle + across * x * 1.05 + (tip - knuckle) * (0.95 - abs(f - 1.5) * 0.08), 0.0062, k1)
                th = add(end + along * 0.025 + across * -sign * 0.016, 0.008, palm)
                add(end + along * 0.05 + across * -sign * 0.024 + bend * 0.008, 0.0065, th)
            else:
                hp = add(root + up * 0.015, 0.055, pel)
                a2 = add(root.lerp(midj, 0.5), 0.045, hp)
                m = add(midj, 0.032, a2)
                m2 = add(midj.lerp(end, 0.5), 0.028, m)
                e = add(end, 0.021, m2)
                toes = (knuckle - end).normalized()
                inward = -side * sign
                heel = add(end - toes * 0.02 + Vector((0, -0.03, 0)), 0.02, e)
                sole = add(end.lerp(knuckle, 0.6) + Vector((0, -0.03, 0)), (0.022, 0.016), heel)
                for f in range(4):
                    x = (f - 1.2) * 0.011 * sign
                    t0 = add(knuckle + side * x + Vector((0, -0.028, 0)), 0.008, sole)
                    add(knuckle + side * x * 1.15 + (tip - knuckle) * (0.95 - f * 0.08) + Vector((0, -0.028, 0)), 0.0065, t0)
                # (the big toe, set apart and turned in, as a hand's thumb)
                b0 = add(end + toes * 0.025 + inward * 0.018 + Vector((0, -0.028, 0)), 0.01, sole)
                add(end + toes * 0.05 + inward * 0.035 + Vector((0, -0.03, 0)), 0.008, b0)
        mesh = skinned(points, edges, radii, pel, self.levels)

        def info(i, p, n):
            nn = from_b(n)
            weights = self.nearest(p, None, 3)
            # Hands and feet: pale backs (a ringed gibbon's), bare palms and soles.
            limb = max(weights, key=weights.get)
            if limb.startswith(("hand", "fingers", "foot", "toes")):
                underside = 0.0
                if limb.startswith(("foot", "toes")):
                    underside = smooth(-0.2, -0.6, nn.y)
                else:
                    underside = smooth(0.0, 0.5, nn.dot(self.fwd))
                tip_skin = 0.6 if limb.startswith(("fingers", "toes")) else 0.0
                return (0.5, 1.0, max(underside, tip_skin) * 0.85), (0.0, 0.3), self.noise_uv(p), weights
            # (a little darker under the belly and in the armpits, as fur thins there)
            shade = 0.5 - 0.06 * smooth(0.2, 0.8, nn.dot(self.fwd)) * smooth(0.4, 0.75, p.y)
            return (shade, 0.0, 0.0), (0.0, 1.0), self.noise_uv(p), weights

        self.model.add(mesh, info)
        bpy.data.meshes.remove(mesh)
        self.surface = self.model.bm.copy()
        self.bvh = BVHTree.FromBMesh(self.surface)

    def on_body(self, axis, out, reach=0.3):
        """Where a ray from `axis` (inside the body) going `out` first leaves it (Godot): its
        own surface, never a limb further out that the ray would meet from outside."""
        hit = self.bvh.ray_cast(to_b(axis), to_b(out), reach)
        if hit[0] is None:
            return None
        return from_b(hit[0])

    # --- Fur ---

    def clump(self, root, hang, length, width, out, mask, weights, stand=0.3, sides=3, rings=3):
        """A tapering strand of fur from `root`, laid along `hang` over a surface facing `out`."""
        out = out.normalized()
        hang = hang.normalized()
        hang = (hang - out * hang.dot(out) + out * stand).normalized()
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
            centre = root + hang * length * s + lift * width * 0.3 * s - Vector((0, 1, 0)) * length * 0.08 * s * s
            w = width * (1.0 - s * 0.8)
            ring = []
            for k in range(sides):
                a = math.tau * k / sides + 0.4
                ring.append(bm.verts.new(to_b(centre + across * math.cos(a) * w * 0.5 + lift * math.sin(a) * w * 0.4)))
            rings_v.append(ring)
        tip = bm.verts.new(to_b(root + hang * length + lift * width * 0.3 - Vector((0, 1, 0)) * length * 0.08))
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
            return (mask[0] + 0.07 * s, mask[1], mask[2]), (0.0, 1.0), self.noise_uv(p), weights

        self.model.add(mesh, info, [normal] * count)
        bpy.data.meshes.remove(mesh)

    def coat(self):
        """Shag over the body and limbs, each region laid its own way."""
        j = self.j
        up, side, fwd = self.up, self.side, self.fwd
        R, Pv, M, C, N = V(j["rump"]), V(j["pelvis"]), V(j["mid"]), V(j["chest"]), V(j["neck"])
        dark = (0.44, 0.0, 0.0)
        plain = (0.48, 0.0, 0.0)
        # The trunk: rings of clumps round the spine, laid down it, longer and shaggier on the back and flanks.
        rows = int(20 * self.fur)
        for row in range(rows):
            u = row / (rows - 1)
            axis = R.lerp(C + up * 0.03, u)
            count = int((34 + 8 * math.sin(math.pi * u)) * self.fur)
            for k in range(count):
                around = math.tau * (k + self.uniform(0.2, 0.8)) / count
                out = (fwd * math.cos(around) + side * math.sin(around)).normalized()
                root = self.on_body(axis, out, 0.14)
                if root is None:
                    continue
                back = smooth(0.2, -0.8, math.cos(around))
                hang = -up + out * 0.15 + side * math.sin(around) * 0.2
                length = self.uniform(0.04, 0.06) + 0.02 * back
                weights = self.nearest(root, ["rump", "belly", "chest", "neck"], 2)
                self.clump(root - out * 0.004, hang, length, self.uniform(0.018, 0.024), out, dark if back > 0.5 else plain, weights, 0.2)
        # The neck and shoulders, down and back.
        for k in range(int(60 * self.fur)):
            u = self.rand()
            axis = C.lerp(N, u)
            around = self.uniform(-math.pi, math.pi)
            out = (fwd * math.cos(around) * 0.7 + side * math.sin(around) + up * 0.3).normalized()
            root = self.on_body(axis, out, 0.1)
            if root is None:
                continue
            self.clump(root - out * 0.004, -up * 0.6 - fwd * 0.5 + out * 0.1, self.uniform(0.035, 0.05), 0.02, out, plain, {"neck": 0.5, "chest": 0.5}, 0.2)
        # The limbs: the upper arm laid down to the elbow, the forearm up to it; thighs and shins down.
        for i in range(4):
            arm = i < 2
            sign = 1.0 if i % 2 == 0 else -1.0
            s = "l" if i % 2 == 0 else "r"
            root_j, midj, end = V(j["roots"][i]), V(j["mids"][i]), V(j["ends"][i])
            for part, a, b, toward, per, long in (
                    ("arm_" if arm else "thigh_", root_j, midj, midj, 110 if arm else 70, (0.035, 0.05) if arm else (0.04, 0.055)),
                    ("forearm_" if arm else "shin_", midj, end, midj if arm else end, 90 if arm else 40, (0.028, 0.04) if arm else (0.025, 0.035))):
                bone = part + s
                axis_dir = (b - a).normalized()
                ref = side * sign if abs(axis_dir.dot(side)) < 0.8 else up
                ring_x = ref.cross(axis_dir).normalized()
                ring_y = axis_dir.cross(ring_x).normalized()
                for k in range(int(per * self.fur)):
                    t = self.uniform(0.04, 0.96)
                    axis = a.lerp(b, t)
                    around = self.uniform(0.0, math.tau)
                    out = (ring_x * math.cos(around) + ring_y * math.sin(around)).normalized()
                    root = self.on_body(axis, out, 0.08)
                    if root is None:
                        continue
                    hang = (toward - axis).normalized() if (toward - axis).length > 0.01 else (b - a).normalized()
                    if not arm and part == "shin_":
                        hang = (b - a).normalized()
                    weights = self.nearest(root, [bone, ("arm_" if arm else "thigh_") + s, ("forearm_" if arm else "shin_") + s, "chest" if arm else "rump"], 2)
                    self.clump(root - out * 0.003, hang + out * 0.1, self.uniform(*long), self.uniform(0.015, 0.02), out, plain, weights, 0.14)

    # --- The head ---

    def head_parts(self):
        H = self.head.to_3x3().normalized()
        HEAD = {"head": 1.0}
        JAW = {"jaw": 1.0}

        def put(mesh, mask, weights, uv0=(0.0, 0.0)):
            def info(i, p, n):
                return (mask(p) if callable(mask) else mask), uv0, self.noise_uv(p), weights
            self.model.add(mesh, info)
            bpy.data.meshes.remove(mesh)

        to_head = self.head.inverted()

        def skull_mask(p):
            local = to_head @ p
            # (the face bare from the brow to the chin, the rest furred)
            bare = smooth(0.012, 0.03, local.z) * smooth(0.05, 0.03, abs(local.x)) * smooth(0.042, 0.028, local.y)
            return (0.5, 0.0, bare)

        # The skull: small and round, the face flat in front of it.
        put(ellipsoid(self.h(0.0, 0.012, -0.008), H, Vector((0.058, 0.06, 0.062)), 24, 14), skull_mask, HEAD, (0.0, 0.7))
        # The face: bare skin, flat, under a brow of two arches over deep sockets.
        put(ellipsoid(self.h(0.0, -0.006, 0.032), H, Vector((0.036, 0.042, 0.024)), 20, 12), SKIN, HEAD)
        for s in (1.0, -1.0):
            arch = H @ Matrix.Rotation(-0.2 * s, 3, "Y") @ Matrix.Rotation(0.18 * s, 3, "Z")
            put(ellipsoid(self.h(0.0175 * s, 0.025, 0.05), arch, Vector((0.019, 0.0075, 0.011)), 14, 8), (0.56, 0.0, 1.0), HEAD)
        put(ellipsoid(self.h(0.0, 0.022, 0.054), H, Vector((0.01, 0.007, 0.008)), 10, 6), (0.56, 0.0, 1.0), HEAD)
        # Deep sockets and small wet eyes, close set.
        for s in (1.0, -1.0):
            put(ellipsoid(self.h(0.017 * s, 0.011, 0.049), H, Vector((0.012, 0.0095, 0.008)), 12, 8), (0.2, 0.0, 1.0), HEAD)
            put(ellipsoid(self.h(0.017 * s, 0.011, 0.0525), H, Vector((0.0068, 0.0062, 0.005)), 10, 6), (0.5, 0.0, 0.0), HEAD, (1.0, 0.0))
            # (the ear, small, mostly lost in the fur)
            put(ellipsoid(self.h(0.056 * s, 0.006, -0.004), H @ Matrix.Rotation(0.5 * s, 3, "Y"), Vector((0.007, 0.016, 0.013)), 10, 6), SKIN, HEAD)
        # The nose: a low flat bridge between the eyes, a broad flat end; the muzzle and upper lip under it.
        put(ellipsoid(self.h(0.0, 0.0, 0.058), H, Vector((0.0075, 0.012, 0.006)), 10, 8), (0.56, 0.0, 1.0), HEAD)
        put(ellipsoid(self.h(0.0, -0.011, 0.065), H, Vector((0.013, 0.0075, 0.008)), 12, 8), (0.58, 0.0, 1.0), HEAD)
        put(ellipsoid(self.h(0.0, -0.028, 0.052), H, Vector((0.026, 0.018, 0.022)), 16, 10), SKIN, HEAD)
        for s in (1.0, -1.0):
            put(ellipsoid(self.h(0.0065 * s, -0.013, 0.0715), H, Vector((0.0035, 0.0025, 0.002)), 6, 4), (0.1, 0.0, 1.0), HEAD)
        # The roof of the mouth and the long upper canines, the front teeth.
        put(ellipsoid(self.h(0.0, -0.04, 0.05), H, Vector((0.02, 0.006, 0.022)), 10, 6), (0.25, 0.0, 1.0), HEAD)
        for s in (1.0, -1.0):
            base = self.h(0.013 * s, -0.038, 0.062)
            put(cone(base, base + self.hb((0.001 * s, -0.022, -0.003)), 0.0042), (0.5, 0.0, 0.0), HEAD, (2.0, 0.0))
        for k in range(4):
            base = self.h((k - 1.5) * 0.0055, -0.04, 0.069 - abs(k - 1.5) * 0.002)
            put(cone(base, base + self.hb((0.0, -0.007, 0.0)), 0.0026, 5), (0.5, 0.0, 0.0), HEAD, (2.0, 0.0))
        # The jaw, the chin, the lower lip, the lower canines.
        J = self.jaw.to_3x3().normalized()
        put(ellipsoid(self.jw(0.0, -0.022, 0.034), J, Vector((0.026, 0.012, 0.03)), 14, 8), SKIN, JAW)
        put(ellipsoid(self.jw(0.0, -0.016, 0.03), J, Vector((0.017, 0.005, 0.02)), 10, 6), (0.25, 0.0, 1.0), JAW)
        for s in (1.0, -1.0):
            base = self.jw(0.011 * s, -0.016, 0.052)
            put(cone(base, base + J @ Vector((0.0, 0.011, -0.002)), 0.0032), (0.5, 0.0, 0.0), JAW, (2.0, 0.0))
        # Fur: the crown laid back; the ring round the face standing out from it, pale on a ringed gibbon.
        centre = self.h(0.0, 0.01, -0.01)
        for k in range(int(130 * self.fur)):
            a = self.uniform(-math.pi, math.pi)
            e = self.uniform(-0.3, 1.2)
            d = Vector((math.sin(a) * math.cos(e), math.sin(e), math.cos(a) * math.cos(e) - 0.15))
            local = Vector((d.x * 0.058, 0.012 + d.y * 0.06, -0.008 + d.z * 0.062))
            if local.z > 0.0 and abs(local.x) < 0.05 and local.y < 0.045:
                continue
            root = self.h(*local)
            out = (root - centre).normalized()
            self.clump(root - out * 0.003, self.hb((d.x * 0.3, -0.25, -1.0)), self.uniform(0.026, 0.04), 0.018, out, (0.48, 0.0, 0.0), HEAD, 0.2)
        ring = int(80 * self.fur)
        for k in range(ring):
            a = math.tau * (k + self.uniform(0.0, 0.6)) / ring
            # (round the face's edge: across the brow, down the cheeks, under the chin)
            band = 0.045 + 0.009 * (k % 2)
            local = Vector((math.cos(a) * band, -0.006 + math.sin(a) * band * 1.06, 0.02 + 0.012 * max(0.0, math.sin(a))))
            root = self.h(*local)
            outward = self.hb((math.cos(a), math.sin(a), 0.35)).normalized()
            weights = HEAD if math.sin(a) > -0.6 else {"head": 0.5, "jaw": 0.5}
            self.clump(root, outward * 0.6 + self.hb((0, -0.15, -1.0)), self.uniform(0.016, 0.026), 0.016, outward, (0.46, 1.0, 0.0), weights, 0.35)

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
                tail = at + m.to_3x3().normalized() @ Vector((0, 0, 0.05))
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


if __name__ == "__main__":
    for low in (False, True):
        Gibbon(low).build("gibbon" + ("_lo" if low else ""))

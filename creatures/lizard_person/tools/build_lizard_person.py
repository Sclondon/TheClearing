"""Builds the lizard person and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/lizard_person/tools/build_lizard_person.py [-- <preview folder>]

Writes creatures/lizard_person/models/lizard_person.glb and lizard_person_lo.glb,
and (given a folder) renders previews into it.

What it models round is the skeleton LizardPerson (creatures/lizard_person/
lizard_person.gd) works out for itself as modelled (crawling, still, its tongue
out, its eyes' membranes drawn and its dewlap fanned), written out by
rest_joints.gd into rest.json beside this file (metres; Godot's axes: Y up,
facing +Z, +X its left). Everything is in those units and axes here, and turned
to Blender's (Z up) only as it is made.

- The body is one surface: a Skin-modifier stick figure of the skeleton (spine,
  neck, limbs, tail, and the five long fingers and toes of each hand and foot,
  each with a round pad at its tip), muscles as ellipsoids over it (ribcage,
  chest, shoulder blades, belly, hips, the arms and legs), a row of keeled
  scutes down the spine and bigger plates over the shoulders, all joined by a
  voxel remesh, smoothed and decimated.
- The head: a flat skull and a long snout, the jowls, heavy scales over the
  eyes, all joined the same way and then cut: the mouth (the upper head cut off
  flat along a lizard's long gape, the jaw below it its own piece), deep
  sockets, nostrils, heat pits along the upper lip, the ear hole. Yellow eyes
  with slit pupils; a pale membrane over each (the lid bones shrink it into the
  front corner); teeth; a dark palate and mouth floor; a forked tongue; the
  dewlap, a thin fan of skin under the throat.
- Claws on every finger and toe.
- Colours are vertex colours, and the rest of what LizardPersonLook needs is in
  the UVs: UV (x, y) and UV2.x where each point is as modelled, UV2.y what it is
  (0 skin, 1 eye, 2 claw or tooth, 3 mouth, 4 membrane, 5 big scales) plus 0.8
  times how far under the belly it is.
- The skeleton is LizardPerson.BONES, none the child of another, each where
  LizardPerson puts it. Every body vertex is weighted to the three bones nearest
  it; each part of the head to its own bone.
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
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW_DIR = ARGS[0] if ARGS else None

DORSAL = (0.16, 0.165, 0.145)
SCUTE = (0.11, 0.115, 0.1)
VENTRAL = (0.37, 0.36, 0.32)
LIP = (0.3, 0.295, 0.27)
HANDS = (0.13, 0.13, 0.115)
MOUTH = (0.24, 0.17, 0.17)
TONGUE = (0.09, 0.08, 0.1)
CLAW = (0.11, 0.1, 0.085)
TOOTH = (0.72, 0.69, 0.58)
EYE = (0.48, 0.4, 0.17)
PUPIL = (0.012, 0.012, 0.012)
MEMBRANE = (0.42, 0.44, 0.42)
DEWLAP = (0.45, 0.42, 0.33)

SKIN, EYE_K, HORN, MOUTH_K, LID_K, PLATE = 0, 1, 2, 3, 4, 5


def V(p):
    return Vector((p[0], p[1], p[2]))


def to_b(p):
    return Vector((p.x, -p.z, p.y))


def from_b(p):
    return Vector((p.x, p.z, -p.y))


def basis(cols):
    return Matrix((V(cols[0]), V(cols[1]), V(cols[2]))).transposed()


def xform(d):
    m = basis(d["basis"]).to_4x4()
    m.translation = V(d["origin"])
    return m


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


def mesh_from_bm(bm):
    mesh = bpy.data.meshes.new("part")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def link(mesh, name="part"):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def evaluated(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    bpy.data.objects.remove(obj)
    return mesh


def ellipsoid(centre, axes, radii, segments=18, rings=10):
    """A UV sphere (Godot space): its centre, a 3x3 basis (columns: x, y, z axes), radii."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        local = Vector((v.co.x * radii[0], v.co.z * radii[1], -v.co.y * radii[2]))
        v.co = to_b(centre + axes @ local)
    return mesh_from_bm(bm)


def along(a, b, side_hint=Vector((1, 0, 0))):
    """A basis whose Z runs from a to b (Godot)."""
    z = (b - a).normalized()
    x = side_hint - z * side_hint.dot(z)
    if x.length < 1e-4:
        x = Vector((0, 1, 0)) - z * z.y
    x.normalize()
    y = z.cross(x).normalized()
    return Matrix((x, y, z)).transposed()


def cone(base, tip, radius, sides=7, bend=None):
    """A tapered, slightly curved horn from base to tip (Godot); `bend` pulls its middle."""
    bm = bmesh.new()
    axis = tip - base
    across = axis.cross(Vector((0, 1, 0)))
    if across.length < 1e-6:
        across = axis.cross(Vector((1, 0, 0)))
    across.normalize()
    lift = axis.normalized().cross(across)
    rings = []
    steps = 3
    for s in range(steps):
        t = s / steps
        centre = base + axis * t
        if bend is not None:
            centre = centre + bend * math.sin(math.pi * t) * 0.5
        r = radius * (1.0 - t * 0.85)
        rings.append([bm.verts.new(to_b(centre + (across * math.cos(a) + lift * math.sin(a)) * r)) for a in [math.tau * k / sides for k in range(sides)]])
    point = bm.verts.new(to_b(tip))
    for s in range(steps - 1):
        for k in range(sides):
            bm.faces.new((rings[s][k], rings[s][(k + 1) % sides], rings[s + 1][(k + 1) % sides], rings[s + 1][k]))
    for k in range(sides):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], point))
    bm.faces.new(list(reversed(rings[0])))
    return mesh_from_bm(bm)


def skinned(points, edges, radii, root, levels=1):
    """A Skin-modifier surface over a stick figure (Godot points)."""
    bm = bmesh.new()
    verts = [bm.verts.new(to_b(p)) for p in points]
    for a, b in edges:
        bm.edges.new((verts[a], verts[b]))
    mesh = mesh_from_bm(bm)
    obj = link(mesh, "skin")
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    skin.use_smooth_shade = True
    for i, r in enumerate(radii):
        mesh.skin_vertices[0].data[i].radius = (r, r)
        mesh.skin_vertices[0].data[i].use_root = i == root
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return evaluated(obj)


def joined(meshes):
    """One mesh of many (all in Blender's axes)."""
    bm = bmesh.new()
    for mesh in meshes:
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    return mesh_from_bm(bm)


def remeshed(mesh, voxel, smooth_steps=2, cutters=(), faces=0):
    """Joined into one closed surface by a voxel remesh (none if `voxel` is 0),
    smoothed, cut by each of `cutters` (meshes taken away), and decimated to
    about `faces` triangles (0: as it is)."""
    obj = link(mesh, "remesh")
    if voxel > 0.0:
        rm = obj.modifiers.new("Remesh", "REMESH")
        rm.mode = "VOXEL"
        rm.voxel_size = voxel
        rm.adaptivity = 0.0
        rm.use_smooth_shade = True
    if smooth_steps > 0:
        sm = obj.modifiers.new("Smooth", "SMOOTH")
        sm.factor = 0.5
        sm.iterations = smooth_steps
    cut_objects = []
    for k, cutter in enumerate(cutters):
        cut = link(cutter, "cutter%d" % k)
        cut.hide_render = True
        cut_objects.append(cut)
        bo = obj.modifiers.new("Cut%d" % k, "BOOLEAN")
        bo.operation = "DIFFERENCE"
        bo.solver = "EXACT"
        bo.object = cut
    out = evaluated(obj)
    for cut in cut_objects:
        m = cut.data
        bpy.data.objects.remove(cut)
        bpy.data.meshes.remove(m)
    if faces > 0:
        out.calc_loop_triangles()
        now = len(out.loop_triangles)
        if now > faces:
            obj = link(out, "decimate")
            obj.modifiers.new("Tri", "TRIANGULATE")
            dec = obj.modifiers.new("Decimate", "DECIMATE")
            dec.ratio = faces / now
            dec.use_collapse_triangulate = True
            out = evaluated(obj)
    return out


def lerp_table(table, x):
    """A value from a table of (x, value), straight between its points."""
    if x <= table[0][0]:
        return table[0][1]
    for (x0, v0), (x1, v1) in zip(table, table[1:]):
        if x <= x1:
            return v0 + (v1 - v0) * (x - x0) / (x1 - x0)
    return table[-1][1]


def loft(rings_pts, closed_end=True, closed_start=False):
    """A tube through rings of Godot points (each a list, all the same length)."""
    bm = bmesh.new()
    grid = [[bm.verts.new(to_b(p)) for p in ring] for ring in rings_pts]
    n = len(grid[0])
    for i in range(len(grid) - 1):
        for k in range(n):
            bm.faces.new((grid[i][k], grid[i][(k + 1) % n], grid[i + 1][(k + 1) % n], grid[i + 1][k]))
    if closed_end:
        centre = bm.verts.new(to_b(sum((p for p in rings_pts[-1]), Vector()) / n))
        for k in range(n):
            bm.faces.new((grid[-1][k], grid[-1][(k + 1) % n], centre))
    if closed_start:
        centre = bm.verts.new(to_b(sum((p for p in rings_pts[0]), Vector()) / n))
        for k in range(n):
            bm.faces.new((grid[0][(k + 1) % n], grid[0][k], centre))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_from_bm(bm)


def subdivided(mesh, levels):
    obj = link(mesh, "part")
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return evaluated(obj)


def box(centre, size, axes=None):
    """A box (Godot) of `size` round `centre`, turned by `axes`."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    axes = axes or Matrix.Identity(3)
    for v in bm.verts:
        local = Vector((v.co.x * size[0], v.co.z * size[1], -v.co.y * size[2]))
        v.co = to_b(centre + axes @ local)
    return mesh_from_bm(bm)


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
        (colour, kind, belly, {bone: weight})."""
        mesh.calc_loop_triangles()
        made = []
        for v in mesh.vertices:
            nv = self.bm.verts.new(v.co)
            p = from_b(v.co)
            colour, kind, belly, weights = info(v.index, p, from_b(v.normal))
            nv[self.col] = (colour[0], colour[1], colour[2], 1.0)
            total = sum(weights.values()) or 1.0
            for bone, w in weights.items():
                if w / total > 0.002:
                    nv[self.deform][self.bones.index(bone)] = w / total
            made.append(nv)
            self.vert_uv.append(((p.x, p.y), (p.z, kind + 0.8 * max(0.0, min(1.0, belly)))))
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


class Lizard:
    def __init__(self, low):
        self.low = low
        with open(os.path.join(HERE, "rest.json")) as f:
            self.j = json.load(f)
        j = self.j
        self.bones = j["bones"]
        self.model = Model(self.bones)
        self.torso = basis(j["torso"])
        self.chest_g = basis(j["chest_g"])
        self.hips_g = basis(j["hips_g"])
        self.head = xform(j["head_xform"])
        self.H = self.head.to_3x3().normalized()
        self.hs = self.head.to_3x3().col[0].length
        self.tail = [V(p) for p in j["tail"]]
        self.digits = [basis(d) for d in j["digits"]]
        # Each body bone as a segment to weigh by.
        P = lambda k: V(j[k])
        s = {}
        s["hips"] = (P("tail_root"), P("pelvis"))
        s["belly"] = (P("pelvis"), P("mid"))
        s["chest"] = (P("mid"), P("chest").lerp(P("neck_root"), 0.5))
        s["neck"] = (P("neck_root"), P("neck_end"))
        s["head"] = (P("neck_end"), self.h(0.0, -0.01, 0.12))
        for i, side in enumerate(["l", "r"]):
            for k, (upper, lower, end) in enumerate([("arm_", "forearm_", "hand_"), ("thigh_", "shin_", "foot_")]):
                n = i + 2 * k
                root, mid, e = V(j["roots"][n]), V(j["mids"][n]), V(j["ends"][n])
                s[upper + side] = (root, mid)
                s[lower + side] = (mid, e)
                s[end + side] = (e, e + self.digits[n].col[1] * 0.12)
        for k in range(len(self.tail) - 1):
            s["tail_%d" % (k + 1)] = (self.tail[k], self.tail[k + 1])
        self.segments = s
        self.body_bones = list(s.keys())

    # --- Helpers ---

    def h(self, x, y, z):
        return self.head @ Vector((x, y, z))

    def mouth_y(self, z):
        """Where the gape runs along the head (its own y, by its own z): down at the
        back, a little up at the snout."""
        return -0.034 + 0.03 * smooth(-0.02, 0.32, z) - 0.008 * math.sin(math.pi * smooth(0.0, 0.25, z))

    def _gape_cutter(self, below):
        """What the gape takes away: everything under the line of the mouth from the
        hinge on (`below`, for the upper head), or everything over it (the jaw)."""
        h = self.h
        bm = bmesh.new()
        zs = [-0.02 + 0.36 * k / 24 for k in range(25)]
        line = [bm.verts.new(to_b(h(x, self.mouth_y(z) - (0.0 if below else 0.0008), z))) for z in zs for x in (-0.12, 0.12)]
        far = [bm.verts.new(to_b(h(x, -0.3 if below else 0.3, z))) for z in zs for x in (-0.12, 0.12)]
        n = len(zs)
        for k in range(n - 1):
            a, b, c, d = 2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2
            bm.faces.new((line[a], line[b], line[c], line[d]))
            bm.faces.new((far[d], far[c], far[b], far[a]))
            bm.faces.new((line[a], line[d], far[d], far[a]))
            bm.faces.new((line[b], far[b], far[c], line[c]))
        bm.faces.new((line[0], far[0], far[1], line[1]))
        bm.faces.new((line[-2], line[-1], far[-1], far[-2]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return mesh_from_bm(bm)

    def nearest(self, p, among=None, count=3):
        found = []
        for bone, (a, b) in self.segments.items():
            if among is not None and bone not in among:
                continue
            found.append((dist_segment(p, a, b), bone))
        found.sort()
        weights = {}
        for d, bone in found[:count]:
            weights[bone] = 1.0 / (d ** 2.2 + 1e-7)
        best = max(weights.values())
        return {k: w for k, w in weights.items() if w > best * 0.06}

    # --- The body ---

    def body(self):
        j = self.j
        P = lambda k: V(j[k])
        torso = self.torso
        up, side, fwd = torso.col[1], torso.col[0], torso.col[2]
        points, radii, edges = [], [], []

        def add(p, r, link_to=None):
            points.append(p)
            radii.append(r)
            if link_to is not None:
                edges.append((link_to, len(points) - 1))
            return len(points) - 1

        TR, PV, M, C, NR, NE = P("tail_root"), P("pelvis"), P("mid"), P("chest"), P("neck_root"), P("neck_end")
        tail_r = [0.098, 0.084, 0.068, 0.052, 0.038, 0.026, 0.013]
        last = add(self.tail[-1], tail_r[-1])
        for k in range(len(self.tail) - 2, 0, -1):
            last = add(self.tail[k], tail_r[k], last)
        t0 = add(TR, tail_r[0], last)
        pel = add(PV, 0.12, t0)
        w = add(PV.lerp(M, 0.5), 0.112, pel)
        mid = add(M, 0.115, w)
        c1 = add(M.lerp(C, 0.6), 0.13, mid)
        ch = add(C, 0.135, c1)
        n0 = add(NR, 0.075, ch)
        n1 = add(NR.lerp(NE, 0.5), 0.062, n0)
        n2 = add(NE, 0.056, n1)
        add(self.h(0.0, -0.012, 0.05), 0.05, n2)
        self.hand_tips = []
        for n in range(4):
            front = n < 2
            root, midj, end = V(j["roots"][n]), V(j["mids"][n]), V(j["ends"][n])
            r = (0.058, 0.04, 0.03) if front else (0.075, 0.052, 0.034)
            a = add(root, r[0] * 1.05, ch if front else pel)
            a2 = add(root.lerp(midj, 0.5), r[0] * 0.95, a)
            m = add(midj, r[1], a2)
            m2 = add(midj.lerp(end, 0.5), r[1] * 0.95, m)
            e = add(end, r[2], m2)
            D = self.digits[n]
            dx, dy, dz = D.col[0], D.col[1], D.col[2]
            sign = 1.0 if n % 2 == 0 else -1.0
            # (which way across the hand the thumb is: towards the body)
            medial = Vector((-sign, 0.0, 0.0))
            thumb = 1.0 if dx.dot(medial) > 0 else -1.0
            palm_long = 0.05 if front else 0.075
            palm = add(end + dy * palm_long * 0.5 - dz * (0.042 if front else 0.044), 0.027 if front else 0.03, e)
            lengths = [0.065, 0.1, 0.12, 0.115, 0.085] if front else [0.07, 0.105, 0.13, 0.15, 0.1]
            spread = [-0.95, -0.42, 0.0, 0.38, 0.78] if front else [-0.8, -0.38, 0.0, 0.32, 0.72]
            for f in range(5):
                a_f = spread[f] * thumb
                ray = (dy * math.cos(a_f) + dx * math.sin(a_f)).normalized()
                start = end + dy * palm_long * 0.8 - dz * 0.046 + (ray - dy) * 0.022
                if f == 0:
                    start = end + dy * palm_long * 0.4 - dz * 0.045
                k1 = add(start + ray * lengths[f] * 0.15, 0.012, palm)
                k2 = add(start + ray * lengths[f] * 0.55 - dz * 0.004, 0.0095, k1)
                tip = start + ray * lengths[f] - dz * 0.01
                add(tip, 0.0075, k2)
                self.hand_tips.append((n, tip, ray, dz))
        mesh = skinned(points, edges, radii, pel, 2)
        parts = [mesh]
        # Muscles and bulk, sunk into the figure so that they only shape it: a broad
        # ribcage and shoulders over a lean waist, long muscles down the limbs.
        cg, hg = self.chest_g, self.hips_g
        parts.append(ellipsoid(C - cg.col[2] * 0.05 - cg.col[1] * 0.01, cg, (0.16, 0.13, 0.21)))  # ribcage
        parts.append(ellipsoid(C + cg.col[2] * 0.03 + cg.col[1] * 0.025, cg, (0.205, 0.07, 0.075)))  # shoulders
        parts.append(ellipsoid(M - up * 0.01, torso, (0.105, 0.088, 0.17)))  # waist
        parts.append(ellipsoid(PV, hg, (0.15, 0.1, 0.13)))  # hips
        parts.append(ellipsoid(NR.lerp(NE, 0.35) - up * 0.025, along(NR, NE, side), (0.056, 0.055, 0.12)))  # throat
        for n in range(4):
            front = n < 2
            root, midj, end = V(j["roots"][n]), V(j["mids"][n]), V(j["ends"][n])
            if front:
                parts.append(ellipsoid(root.lerp(midj, 0.45), along(root, midj, up), (0.049, 0.045, 0.19)))
                parts.append(ellipsoid(midj.lerp(end, 0.35), along(midj, end, up), (0.04, 0.036, 0.15)))
            else:
                parts.append(ellipsoid(root.lerp(midj, 0.42), along(root, midj, up), (0.086, 0.076, 0.27)))
                parts.append(ellipsoid(midj.lerp(end, 0.3), along(midj, end, up), (0.05, 0.046, 0.16)))
        # Toe pads.
        for n, tip, ray, dz in self.hand_tips:
            pad_axes = along(tip - ray, tip, dz.cross(ray))
            parts.append(ellipsoid(tip - dz * 0.003, pad_axes, (0.012, 0.0065, 0.014), 12, 6))
        rough = joined([m for m in parts])
        # Scutes, rooted on that surface: a keeled row down the spine, plates over the shoulders.
        bm = bmesh.new()
        bm.from_mesh(rough)
        bvh = BVHTree.FromBMesh(bm)
        bm.free()
        self.bvh_rough = bvh
        scutes = []
        self.scute_points = []
        spine = [NE, NR, C, M, PV, TR] + self.tail[1:5]
        lengths = [(spine[k + 1] - spine[k]).length for k in range(len(spine) - 1)]
        total = sum(lengths)
        count = 34 if self.low else 52
        for i in range(count):
            u = (i + 0.5) / count
            d = u * total
            k = 0
            while k < len(lengths) - 1 and d > lengths[k]:
                d -= lengths[k]
                k += 1
            a, b = spine[k], spine[k + 1]
            axis = a.lerp(b, d / lengths[k])
            hit = bvh.ray_cast(to_b(axis + Vector((0, 0.5, 0))), Vector((0, 0, -1)))
            if hit[0] is None:
                continue
            surf = from_b(hit[0])
            big = 1.0 - 0.6 * smooth(0.45, 1.0, u) + 0.35 * math.exp(-((u - 0.2) / 0.1) ** 2)
            ax = along(a, b, Vector((1, 0, 0)))
            centre = surf - Vector((0, 0.004 * big, 0))
            scutes.append(ellipsoid(centre, ax, (0.0065 * big, 0.014 * big, 0.019 * big), 10, 6))
            self.scute_points.append((centre, 0.03 * big))
        # (over the shoulders and the back of the neck, in rows each side)
        for row in range(3):
            for k in range(6 if not self.low else 4):
                u = k / 5.0
                axis = NE.lerp(NR, min(u * 2.0, 1.0)).lerp(C - fwd * 0.12, max(u * 2.0 - 1.0, 0.0) * 1.0)
                for s_ in (1.0, -1.0):
                    a_ = (0.45 + 0.32 * row + 0.06 * (k % 2)) * s_
                    out = (up * math.cos(a_) + side * math.sin(a_)).normalized()
                    hit = bvh.ray_cast(to_b(axis + out * 0.5), to_b(-out))
                    if hit[0] is None:
                        continue
                    surf = from_b(hit[0])
                    big = (1.0 - 0.25 * row) * (0.8 + 0.4 * smooth(0.0, 0.6, u))
                    centre = surf - out * 0.004
                    scutes.append(ellipsoid(centre, self._frame(fwd, out), (0.017 * big, 0.0055 * big, 0.02 * big), 10, 6))
                    self.scute_points.append((centre, 0.024 * big))
        mesh = joined([rough] + scutes)
        voxel = 0.0034
        mesh = remeshed(mesh, voxel, 6, faces=9000 if self.low else 36000)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        self.bvh_body = BVHTree.FromBMesh(bm)
        bm.free()

        def info(i, p, n):
            weights = self.nearest(p, self.body_bones, 3)
            under = smooth(0.05, 0.7, -n.y)
            c = mix(DORSAL, VENTRAL, under)
            # (the plated belly is the trunk's and the tail's; the limbs are only paler under)
            total = sum(weights.values())
            trunk = sum(w for b, w in weights.items() if b in ("hips", "belly", "chest", "neck") or b.startswith("tail")) / total
            under *= smooth(0.5, 0.9, trunk)
            # (darker towards the hands and feet)
            for k, prefix in enumerate(["hand_", "foot_"]):
                for s_ in ("l", "r"):
                    bone = prefix + s_
                    a, b = self.segments[bone]
                    if bone in weights:
                        c = mix(c, HANDS, min(1.0, weights[bone] / sum(weights.values())) * 0.65)
            kind = SKIN
            for centre, r in self.scute_points:
                if (p - centre).length < r and n.y > -0.2:
                    kind = PLATE
                    c = mix(c, SCUTE, 0.7)
                    break
            return c, kind, under, weights

        self.model.add(mesh, info)
        bpy.data.meshes.remove(mesh)
        # Claws on every finger and toe.
        for n, tip, ray, dz in self.hand_tips:
            bone = ["hand_l", "hand_r", "foot_l", "foot_r"][n]
            base = tip + ray * 0.002 + dz * 0.004
            claw = cone(base, base + ray * (0.026 if n < 2 else 0.022) - dz * 0.014, 0.0045, 6, -dz * 0.006 + ray * 0.0)
            self.model.add(claw, lambda i, p, nn, b=bone: (CLAW, HORN, 0.0, {b: 1.0}))
            bpy.data.meshes.remove(claw)

    @staticmethod
    def _frame(fwd, out):
        z = (fwd - out * fwd.dot(out)).normalized()
        x = out.cross(z).normalized()
        return Matrix((x, out, z)).transposed()

    # --- The head ---

    def head_parts(self):
        H = self.H
        h = self.h
        HEAD = {"head": 1.0}
        JAW = {"jaw": 1.0}

        def E(c, r, axes=None, seg=20, rings=12):
            return ellipsoid(h(*c), H @ (axes or Matrix.Identity(3)), Vector(r) * self.hs, seg, rings)

        rings_n = 20 if self.low else 30
        sides = 16 if self.low else 26
        zs = [-0.055 + (0.318 + 0.055) * k / (rings_n - 1) for k in range(rings_n)]
        # The upper head, lofted: wide and flat over the jowls and the eyes,
        # narrowing to a long, low snout; its sides steep, its top flat.
        widths = [(-0.055, 0.042), (-0.03, 0.056), (0.0, 0.064), (0.04, 0.062), (0.08, 0.057), (0.115, 0.053), (0.15, 0.046),
                  (0.2, 0.037), (0.25, 0.029), (0.29, 0.021), (0.318, 0.008)]
        tops = [(-0.055, 0.028), (-0.03, 0.044), (0.0, 0.051), (0.04, 0.052), (0.08, 0.05), (0.115, 0.045), (0.15, 0.035),
                (0.2, 0.024), (0.25, 0.014), (0.29, 0.006), (0.318, -0.006)]

        def upper_bottom(z):
            return self.mouth_y(z) - 0.014 if z > -0.01 else lerp_table([(-0.055, -0.06), (-0.01, -0.06)], z)

        def ring(z, width, top, bottom, flat_top=0.5, flat_bottom=0.9):
            mid = 0.5 * (top + bottom)
            points = []
            for q in range(sides):
                a = math.tau * q / sides
                c, s = math.cos(a), math.sin(a)
                x = width * math.copysign(abs(c) ** 0.75, c)
                if s >= 0:
                    y = mid + (top - mid) * abs(s) ** flat_top
                else:
                    y = mid - (mid - bottom) * abs(s) ** flat_bottom
                points.append(h(x, y, z))
            return points

        loft_rings = [ring(z, lerp_table(widths, z), lerp_table(tops, z), upper_bottom(z)) for z in zs]
        mesh = loft(loft_rings, closed_end=True, closed_start=True)
        mesh = subdivided(mesh, 1)
        inv = self.head.inverted()
        # The scales over the eyes stand out in a ridge, overhanging them.
        for v in mesh.vertices:
            local = inv @ from_b(v.co)
            ridge = math.exp(-((local.z - 0.112) / 0.034) ** 2 - ((abs(local.x) - 0.044) / 0.012) ** 2)
            ridge *= smooth(0.0, 0.03, local.y)
            local = local + Vector((math.copysign(0.004, local.x), 0.007, 0.0)) * ridge
            v.co = to_b(self.head @ local)
        mesh.update()
        cutters = [self._gape_cutter(below=True)]
        self.eyes = []
        for s in (1.0, -1.0):
            cutters.append(E((0.044 * s, 0.026, 0.113), (0.018, 0.017, 0.02), None, 16, 10))  # socket
            cutters.append(E((0.017 * s, 0.006, 0.305), (0.0045, 0.004, 0.006), None, 10, 6))  # nostril
            for k, z in enumerate((0.2, 0.228, 0.254, 0.278)):
                x = lerp_table(widths, z) * 0.97
                cutters.append(E((x * s, self.mouth_y(z) + 0.007, z), (0.0042, 0.0034, 0.0036), None, 10, 6))  # heat pit
            cutters.append(E((0.062 * s, -0.012, -0.022), (0.008, 0.014, 0.012), None, 12, 8))  # ear
            self.eyes.append(Vector((0.04 * s, 0.026, 0.113)))
        mesh = remeshed(mesh, 0.0, 1, cutters, 2600 if self.low else 9000)

        def upper_info(i, p, nn):
            local = inv @ p
            ln = (self.H.inverted() @ nn).normalized()
            under = smooth(0.1, 0.7, -ln.y)
            c = mix(DORSAL, VENTRAL, under * 0.6)
            kind = PLATE if ln.y > 0.5 else SKIN
            if abs(local.y - self.mouth_y(local.z)) < 0.006 and local.z > -0.01:
                c = LIP
                kind = SKIN
            if ln.y < -0.8 and local.y < self.mouth_y(local.z) + 0.003:
                c = MOUTH
                kind = MOUTH_K
            return c, kind, under * 0.5, HEAD

        self.model.add(mesh, upper_info)
        bpy.data.meshes.remove(mesh)

        # The jaw, its own piece below the gape, deep at the throat.
        jaw_widths = [(-0.05, 0.046), (-0.02, 0.056), (0.02, 0.059), (0.06, 0.056), (0.1, 0.051), (0.15, 0.044), (0.2, 0.035),
                      (0.25, 0.027), (0.29, 0.019), (0.31, 0.008)]
        jaw_bottoms = [(-0.05, -0.072), (-0.02, -0.08), (0.02, -0.086), (0.06, -0.084), (0.1, -0.077), (0.15, -0.066),
                       (0.2, -0.056), (0.25, -0.047), (0.29, -0.04), (0.31, -0.035)]
        jzs = [-0.05 + (0.31 + 0.05) * k / (rings_n - 1) for k in range(rings_n)]
        loft_rings = [ring(z, lerp_table(jaw_widths, z), self.mouth_y(z) + 0.012, lerp_table(jaw_bottoms, z), 0.9, 0.7) for z in jzs]
        mesh = subdivided(loft(loft_rings, closed_end=True, closed_start=True), 1)
        mesh = remeshed(mesh, 0.0, 1, [self._gape_cutter(below=False)], 1800 if self.low else 6000)

        def jaw_info(i, p, nn):
            local = inv @ p
            ln = (self.H.inverted() @ nn).normalized()
            under = smooth(-0.2, 0.6, -ln.y)
            c = mix(DORSAL, VENTRAL, under)
            kind = SKIN
            if abs(local.y - self.mouth_y(local.z)) < 0.006:
                c = LIP
            if ln.y > 0.8 and local.y > self.mouth_y(local.z) - 0.004:
                c = MOUTH
                kind = MOUTH_K
            return c, kind, under, JAW

        self.model.add(mesh, jaw_info)
        bpy.data.meshes.remove(mesh)

        def put(mesh, colour, kind, weights, belly=0.0):
            self.model.add(mesh, lambda i, p, nn: (colour(p) if callable(colour) else colour, kind, belly, weights))
            bpy.data.meshes.remove(mesh)

        # Teeth, small and many, along both lips.
        teeth = 7 if self.low else 12
        for s in (1.0, -1.0):
            for k in range(teeth):
                z = 0.05 + 0.24 * k / (teeth - 1)
                x = (lerp_table(widths, z) - 0.007) * s
                y = self.mouth_y(z)
                size = 0.006 - 0.002 * k / teeth
                put(cone(h(x, y + 0.004, z), h(x, y - size, z + 0.002), 0.0022, 5), TOOTH, HORN, HEAD)
                put(cone(h(x * 0.95, y - 0.004, z - 0.006), h(x * 0.95, y + size * 0.8, z - 0.004), 0.002, 5), TOOTH, HORN, JAW)
        # Eyes: yellow, a black slit; and each eye's membrane.
        LID_AT = [V(p) for p in self.j["lid_at"]]
        for k, c in enumerate(self.eyes):
            s = 1.0 if c.x > 0 else -1.0
            out = Vector((s * 0.96, 0.1, 0.26)).normalized()
            put(E(tuple(c), (0.0175, 0.0175, 0.0175), None, 20, 12), EYE, EYE_K, HEAD)
            slit_axes = Matrix((Vector((0, 0, 1)).cross(out).normalized() if False else out.cross(Vector((0, 1, 0))).normalized(), Vector((0, 1, 0)), out)).transposed()
            put(E(tuple(c + out * 0.0172), (0.003, 0.0128, 0.002), slit_axes, 12, 8), PUPIL, EYE_K, HEAD)
            # (the membrane: the outer half of a shell over the eye)
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=18, v_segments=10, radius=0.0188)
            kill = []
            for v in bm.verts:
                g = Vector((v.co.x, v.co.z, -v.co.y))
                if g.dot(out) < -0.002:
                    kill.append(v)
            bmesh.ops.delete(bm, geom=kill, context="VERTS")
            # (closed with a back face, so it is solid)
            edges = [e for e in bm.edges if e.is_boundary]
            if edges:
                bmesh.ops.holes_fill(bm, edges=edges, sides=0)
            for v in bm.verts:
                g = Vector((v.co.x, v.co.z, -v.co.y))
                v.co = to_b(h(*(c + g)))
            put(mesh_from_bm(bm), MEMBRANE, LID_K, {"lid_l" if s > 0 else "lid_r": 1.0})
        # The tongue, forked, out of the front of the mouth (the tongue bone draws it in).
        t0 = V(self.j["tongue_at"])
        rings = []
        length = 0.33
        bm = bmesh.new()
        segs = 10
        prev = None
        for fork in (1.0, -1.0):
            ring_list = []
            for k in range(segs + 1):
                u = k / segs
                z = t0.z + length * u
                y = t0.y + 0.006 * u
                spread = smooth(0.75, 1.0, u) * 0.014 * fork
                w = (0.0075 if u < 0.75 else 0.0075 * 0.5) * (1.0 - 0.6 * u)
                th = 0.0035 * (1.0 - 0.5 * u)
                cx = spread + (w if u < 0.75 else 0.0) * 0.5 * fork
                ring = [bm.verts.new(to_b(h(cx + math.cos(a) * w, y + math.sin(a) * th, z))) for a in [math.tau * q / 6 for q in range(6)]]
                ring_list.append(ring)
            for k in range(segs):
                for q in range(6):
                    bm.faces.new((ring_list[k][q], ring_list[k][(q + 1) % 6], ring_list[k + 1][(q + 1) % 6], ring_list[k + 1][q]))
            bm.faces.new(list(reversed(ring_list[0])))
            bm.faces.new(ring_list[-1])
        put(mesh_from_bm(bm), TONGUE, MOUTH_K, {"tongue": 1.0})
        # The dewlap: a thin fan of skin under the throat, scaled in rows (the bone folds it up).
        centre = V(self.j["dewlap_at"]) + Vector((0.0, 0.0, 0.01))
        radius = 0.125
        bm = bmesh.new()
        arcs, steps = 16, 6
        grid = {}
        for side in (1.0, -1.0):
            for a in range(arcs + 1):
                ang = math.pi * a / arcs
                for r in range(steps + 1):
                    rr = radius * r / steps
                    if r == steps:
                        rr *= 1.0 - 0.06 * (0.5 + 0.5 * math.cos(ang * 9.0))
                    thick = (0.014 * (1.0 - r / steps) + 0.0025) * side * 0.5
                    local = centre + Vector((thick, -math.sin(ang) * rr, -math.cos(ang) * rr * 0.9))
                    grid[(side, a, r)] = bm.verts.new(to_b(h(*local)))
        for a in range(arcs):
            for r in range(steps):
                q = [grid[(1.0, a, r)], grid[(1.0, a + 1, r)], grid[(1.0, a + 1, r + 1)], grid[(1.0, a, r + 1)]]
                bm.faces.new(q)
                bm.faces.new([grid[(-1.0, a, r)], grid[(-1.0, a, r + 1)], grid[(-1.0, a + 1, r + 1)], grid[(-1.0, a + 1, r)]])
            bm.faces.new([grid[(1.0, a, steps)], grid[(1.0, a + 1, steps)], grid[(-1.0, a + 1, steps)], grid[(-1.0, a, steps)]])
        for a_end in (0, arcs):
            for r in range(steps):
                f = [grid[(1.0, a_end, r)], grid[(1.0, a_end, r + 1)], grid[(-1.0, a_end, r + 1)], grid[(-1.0, a_end, r)]]
                bm.faces.new(f if a_end == arcs else list(reversed(f)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = mesh_from_bm(bm)
        inv_c = centre

        def dewlap_colour(p):
            local = inv @ p
            rel = local - inv_c
            ang = math.atan2(-rel.y, -rel.z / 0.9)
            stripe = 0.5 + 0.5 * math.cos(ang * 14.0)
            return mix(DEWLAP, SCUTE, 0.35 * smooth(0.6, 0.95, stripe) * smooth(0.01, 0.05, rel.length))

        self.model.add(mesh, lambda i, p, nn: (dewlap_colour(p), SKIN, 0.35, {"dewlap": 1.0}))
        bpy.data.meshes.remove(mesh)

    # --- Putting it out ---

    def build(self, out_name):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.model = Model(self.bones)
        self.body()
        self.head_parts()

        data = bpy.data.armatures.new("Armature")
        armature = bpy.data.objects.new("Armature", data)
        bpy.context.collection.objects.link(armature)
        bpy.context.view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode="EDIT")
        j = self.j
        fixed = {"head": j["head_xform"], "jaw": j["jaw_xform"], "dewlap": j["dewlap_xform"], "tongue": j["tongue_xform"],
                 "lid_l": j["lid_xforms"][0], "lid_r": j["lid_xforms"][1]}
        for bone in self.bones:
            if bone in fixed:
                m = xform(fixed[bone])
                at = m.translation
                tail = at + m.to_3x3().normalized() @ Vector((0, 0, 0.04))
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
            self.previews(out_name)

    def previews(self, name):
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "VERTEX"
        scene.render.resolution_x, scene.render.resolution_y = 900, 700
        scene.world = bpy.data.worlds.new("World")
        scene.world.color = (0.35, 0.38, 0.42)
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.lens = 60
        scene.collection.objects.link(camera)
        scene.camera = camera
        head = to_b(self.h(0.0, 0.0, 0.14))
        whole = to_b(V(self.j["mid"]) + Vector((0, 0, -0.2)))
        views = [("whole_quarter", Vector((0.8, 0.6, 0.8)), whole, 3.6), ("whole_top", Vector((0.05, 1.0, 0.05)), whole, 3.8),
                 ("whole_side", Vector((1.0, 0.15, 0.0)), whole, 3.6),
                 ("face_front", Vector((0.0, 0.15, 1.0)), head, 0.6), ("face_quarter", Vector((0.7, 0.3, 0.7)), head, 0.6),
                 ("face_side", Vector((1.0, 0.05, 0.05)), head, 0.6), ("hand", Vector((0.4, 1.0, 0.4)), to_b(V(self.j["ends"][0])), 0.6)]
        for view, direction, target, far in views:
            offset = to_b(direction.normalized()) * far
            camera.location = target + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for low in (False, True):
        Lizard(low).build("lizard_person" + ("_lo" if low else ""))

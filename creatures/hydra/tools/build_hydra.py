"""Builds the hydra's body and its head and exports them for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/hydra/tools/build_hydra.py [-- <preview folder>]

Writes creatures/hydra/models/hydra.glb and hydra_lo.glb, each with two loose
meshes and no skeleton: "body" (the squat bulk, its four splayed legs and its
tail) and "head" (one snake's head; Godot's Hydra draws as many of it as it has
heads, as one MultiMesh). The necks are not here: Godot makes them, one tube
each, bent along their spines in the shader. Given a folder, renders previews.

Everything here is in Godot's axes (Y up, the hydra facing +Z, +X its left),
in metres, and turned into Blender's (Z up) only as it is made.

THE BODY, after a monitor lizard crossed with a crocodile and a snapping
turtle: low and heavy, belly near the ground, about 7 m from the hump the
necks grow from to the tip of its thick tail; four short legs splayed out to
the sides (upper arm and thigh out level, forearm and shin down), broad feet
with four clawed toes; a row of blunt bony scutes down the spine and two lower
rows down the flanks; the necks grow from a broad hump of muscle at the front,
where the head of a lizard would be (they are set on it in Godot, Hydra.ROOTS).

THE HEAD, after a viper (a broad, heavy, triangular head, the jaw muscles
swelling it behind the eyes) and a python's heavy head plates: heavy brows
over lidless eyes set at the sides, nostrils at the snout's tip, the upper head
and lower jaw separate surfaces (so the jaw can open on a pale mouth), two
long fangs folded back along the roof of the mouth (they swing down as the jaw
opens), and a forked tongue lying inside it (pushed out through the notch at
the front of the snout in Godot's shader). Its origin is the back of the skull,
where the neck goes in; it is about a metre long.

WHAT A POINT IS (for Godot's shader):
- body: the first UV is (limb, how far down it, 0 at the body to 1 at the
  foot), limb 0 the body, 1 the left foreleg, 2 the right, 3 the left hind
  leg, 4 the right; the second UV is (how far down the tail, 0 to 1; how high
  a scute it is, 0 to 1). Colours are vertex colours.
- head: the first UV is (part, 1 on the lower jaw and 0 elsewhere), part 0
  scales, 1 eye, 2 mouth, 3 fang, 4 tongue; the second UV is, on an eye, where
  on the eye the point is (across and up, as seen from the way the eye looks),
  on the tongue how far along it (0 to 1). Colours are vertex colours.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Quaternion, Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDER = os.path.dirname(HERE)
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

# How far out a lone metaball ellipsoid's surface is, as a share of its size (threshold 0.6, stiffness 2).
META = 0.5725

SCALES, EYE, MOUTH, FANG, TONGUE = 0.0, 1.0, 2.0, 3.0, 4.0

# Where the legs join the body, and how they go (Godot, metres; the left side, +X; the right is mirrored).
FORE = [(0.85, 0.8, 1.15), (1.62, 0.84, 1.35), (1.86, 0.18, 1.6), (1.96, 0.07, 1.78)]
HIND = [(0.8, 0.78, -1.25), (1.68, 0.88, -1.45), (1.9, 0.18, -1.25), (2.04, 0.07, -1.0)]
TAIL = [(0.0, 0.88, -2.0), (0.0, 0.78, -2.9), (0.08, 0.6, -3.8), (0.2, 0.42, -4.6), (0.3, 0.27, -5.3), (0.32, 0.18, -5.8)]
TAIL_R = [0.62, 0.5, 0.36, 0.24, 0.13, 0.05]

# Colours: near colourless (the game is lit as Inside is). A dark grey-olive back, paler grey flanks, a dirty
# pale belly, darker blotches, near-black claws and scutes tipped paler; the mouth a dead pinkish grey.
BACK = (0.13, 0.14, 0.12)
FLANK = (0.24, 0.24, 0.21)
BELLY = (0.5, 0.48, 0.41)
CLAW = (0.04, 0.035, 0.03)
SCUTE = (0.09, 0.09, 0.08)
MOUTH_C = (0.3, 0.21, 0.2)
FANG_C = (0.78, 0.74, 0.62)
TONGUE_C = (0.12, 0.05, 0.06)
EYE_C = (0.6, 0.55, 0.35)


def B(p):
    """Godot (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def G(v):
    """Blender to Godot."""
    return Vector((v[0], v[2], -v[1]))


def V(*a):
    return Vector(a)


def smooth(a, b, x):
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def scale(c, k):
    return tuple(x * k for x in c)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def obj_mesh(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    bpy.data.objects.remove(obj, do_unlink=True)
    return mesh


def link(mesh, name="part"):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def apply_modifiers(mesh, mods):
    obj = link(mesh)
    for kind, settings in mods:
        m = obj.modifiers.new(kind, kind)
        for key, value in settings.items():
            setattr(m, key, value)
    return obj_mesh(obj)


def blobs(elements, resolution, smoothing=3):
    """One fused surface from metaball ellipsoids: (centre, half extents, (pitch, yaw, roll) degrees)."""
    data = bpy.data.metaballs.new("blob")
    data.resolution = resolution
    data.render_resolution = resolution
    data.threshold = 0.6
    holder = bpy.data.objects.new("blob", data)
    bpy.context.scene.collection.objects.link(holder)
    for centre, extents, turn in elements:
        e = data.elements.new(type="ELLIPSOID")
        e.co = B(centre)
        e.radius = 1.0
        e.stiffness = 2.0
        e.size_x = extents[0] / META
        e.size_y = extents[2] / META
        e.size_z = extents[1] / META
        pitch, yaw, roll = (math.radians(a) for a in turn)
        e.rotation = Quaternion((0, 0, 1), yaw) @ Quaternion((1, 0, 0), pitch) @ Quaternion((0, -1, 0), roll)
    bpy.context.view_layer.update()
    mesh = obj_mesh(holder)
    bpy.data.metaballs.remove(data)
    return apply_modifiers(mesh, [("SMOOTH", dict(factor=0.5, iterations=smoothing))])


def thin(mesh, faces):
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    if tris <= faces:
        return mesh
    return apply_modifiers(mesh, [("DECIMATE", dict(ratio=faces / tris))])


def skinned(points, radii, levels=2):
    """A Skin-modifier tube along a line of Godot points, smoothed."""
    bm = bmesh.new()
    verts = [bm.verts.new(B(p)) for p in points]
    for i in range(len(verts) - 1):
        bm.edges.new((verts[i], verts[i + 1]))
    mesh = bpy.data.meshes.new("skin")
    bm.to_mesh(mesh)
    bm.free()
    obj = link(mesh, "skin")
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    skin.use_smooth_shade = True
    for i, r in enumerate(radii):
        rr = r if isinstance(r, tuple) else (r, r)
        mesh.skin_vertices[0].data[i].radius = rr
        mesh.skin_vertices[0].data[i].use_root = i == 0
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return obj_mesh(obj)


def ellipsoid(centre, radii, segments=12, rings=8, turn=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        g = G(v.co)
        p = V(g.x * radii[0], g.y * radii[1], g.z * radii[2])
        if turn is not None:
            p = turn @ p
        v.co = B(V(*centre) + p)
    mesh = bpy.data.meshes.new("ellipsoid")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def cone(base, tip, radius, segments=8, bend=None):
    """A pointed horn from `base` to `tip` (Godot), optionally bowed towards `bend`, as a few rings."""
    bm = bmesh.new()
    base = V(*base)
    tip = V(*tip)
    axis = (tip - base)
    length = axis.length
    axis.normalize()
    side = axis.cross(V(0, 1, 0))
    if side.length < 0.1:
        side = axis.cross(V(1, 0, 0))
    side.normalize()
    up = side.cross(axis).normalized()
    rings = []
    steps = 5
    for i in range(steps):
        t = i / (steps - 1)
        centre = base + axis * length * t
        if bend is not None:
            centre = centre + V(*bend) * math.sin(t * math.pi * 0.85) * length * 0.18
        r = radius * (1.0 - t) ** 0.9
        ring = []
        if i == steps - 1:
            ring = [bm.verts.new(B(centre))]
        else:
            for k in range(segments):
                a = math.tau * k / segments
                ring.append(bm.verts.new(B(centre + (side * math.cos(a) + up * math.sin(a)) * r)))
        rings.append(ring)
    cap = bm.verts.new(B(base - axis * radius * 0.2))
    for k in range(segments):
        bm.faces.new((cap, rings[0][(k + 1) % segments], rings[0][k]))
    for i in range(steps - 2):
        for k in range(segments):
            a, b = rings[i][k], rings[i][(k + 1) % segments]
            c, d = rings[i + 1][(k + 1) % segments], rings[i + 1][k]
            bm.faces.new((a, b, c, d))
    last = rings[-1][0]
    for k in range(segments):
        bm.faces.new((rings[-2][k], rings[-2][(k + 1) % segments], last))
    mesh = bpy.data.meshes.new("cone")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def mirrored(p):
    return (-p[0], p[1], p[2])


class Model:
    """A mesh as it is put together: one bmesh, with per-vertex colour and two UVs."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv0 = self.bm.loops.layers.uv.new("UVMap")
        self.uv1 = self.bm.loops.layers.uv.new("UV2")
        self.col = self.bm.verts.layers.float_color.new("Col")

    def add(self, mesh, info):
        """info(godot_position, godot_normal) -> (colour, uv0, uv1)."""
        mesh.update()
        made = []
        uvs = []
        for v in mesh.vertices:
            nv = self.bm.verts.new(v.co)
            colour, uv0, uv1 = info(G(v.co), G(v.normal).normalized())
            nv[self.col] = (colour[0], colour[1], colour[2], 1.0)
            made.append(nv)
            uvs.append((uv0, uv1))
        for poly in mesh.polygons:
            try:
                face = self.bm.faces.new([made[i] for i in poly.vertices])
            except ValueError:
                continue
            face.smooth = True
            for loop, i in zip(face.loops, poly.vertices):
                uv0, uv1 = uvs[i]
                loop[self.uv0].uv = (uv0[0], 1.0 - uv0[1])  # (glTF turns V over)
                loop[self.uv1].uv = (uv1[0], 1.0 - uv1[1])
        bpy.data.meshes.remove(mesh)

    def finish(self, name):
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.update()
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]
        mesh.color_attributes.active_color_index = mesh.color_attributes.find("Col")
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
        mesh.uv_layers.active = mesh.uv_layers["UVMap"]
        return link(mesh, name)


def blotch(p, size=1.6):
    """Darker blotches over the back, 0 to 1."""
    n = noise.noise(V(p[0] * size, p[1] * size, p[2] * size) + V(3.1, 7.7, 1.3))
    return smooth(0.1, 0.35, n)


# --- The body ---

def skin_colour(p, n, tail=0.0):
    up = n.y
    c = mix(FLANK, BACK, smooth(-0.1, 0.6, up))
    c = mix(c, BELLY, smooth(-0.4, -0.8, up) * (1.0 - 0.5 * tail))
    c = mix(c, scale(c, 0.6), blotch(p) * smooth(-0.3, 0.3, up))
    # (lighter mottling, flecks)
    fleck = noise.noise(V(*p) * 6.0)
    return scale(c, 0.92 + 0.16 * fleck)


def body_elements():
    return [
        ((0.0, 0.92, 0.0), (1.22, 0.58, 1.75), (0, 0, 0)),
        ((0.0, 1.0, 1.15), (1.15, 0.64, 0.95), (0, 0, 0)),
        ((0.0, 0.88, -1.3), (1.0, 0.54, 0.9), (0, 0, 0)),
        ((0.0, 0.64, 0.1), (1.12, 0.4, 1.45), (0, 0, 0)),
        # (the hump the necks grow from, and the heavy shoulders under it)
        ((0.0, 1.34, 1.8), (1.05, 0.56, 0.72), (-12, 0, 0)),
        ((0.6, 1.1, 1.35), (0.62, 0.5, 0.6), (0, 0, 0)),
        ((-0.6, 1.1, 1.35), (0.62, 0.5, 0.6), (0, 0, 0)),
        ((0.58, 0.96, -1.25), (0.58, 0.45, 0.6), (0, 0, 0)),
        ((-0.58, 0.96, -1.25), (0.58, 0.45, 0.6), (0, 0, 0)),
        # (the root of the tail)
        ((0.0, 0.88, -2.15), (0.62, 0.44, 0.8), (6, 0, 0)),
    ]


def tail_t(p):
    """How far down the tail a point is, 0 (the hips) to 1 (its tip)."""
    return smooth(-1.8, -5.85, p[2]) if p[2] < -1.8 else 0.0


def tail_at(z):
    """The middle of the tail (x, y) and how thick it is, where it crosses `z`."""
    for i in range(len(TAIL) - 1):
        a, b = TAIL[i], TAIL[i + 1]
        if b[2] <= z <= a[2]:
            t = (a[2] - z) / (a[2] - b[2])
            return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, TAIL_R[i] + (TAIL_R[i + 1] - TAIL_R[i]) * t
    return TAIL[-1][0], TAIL[-1][1], TAIL_R[-1]


def build_body(model, low):
    torso = blobs(body_elements(), 0.16 if low else 0.085)
    torso = thin(torso, 2600 if low else 9000)

    def torso_info(p, n):
        t = tail_t(p)
        return skin_colour(p, n, t), (0.0, 0.0), (t, 0.0)

    model.add(torso, torso_info)

    tail = skinned(TAIL, TAIL_R, levels=1 if low else 2)

    def tail_info(p, n):
        t = tail_t(p)
        return skin_colour(p, n, t), (0.0, 0.0), (t, 0.0)

    model.add(tail, tail_info)

    # The legs: out level from the body, then down to the ground; broad feet, four toes each, black claws.
    for limb, chain in enumerate((FORE, FORE, HIND, HIND)):
        left = limb % 2 == 0
        radii = [0.44, 0.36, 0.27, 0.2] if limb < 2 else [0.5, 0.4, 0.28, 0.22]
        points = [p if left else mirrored(p) for p in chain]
        # (a little way into the body, so the joint is hidden)
        inner = (points[0][0] * 0.6, points[0][1] + 0.05, points[0][2])
        line = [inner] + points
        leg = skinned(line, [radii[0] * 1.15] + radii, levels=1 if low else 2)
        hip = V(*points[0])
        foot = V(*points[-1])
        reach = (foot - hip).length

        def leg_info(p, n, hip=hip, reach=reach, limb=limb):
            w = smooth(0.0, 1.0, (p - hip).length / reach) if abs(p.x) > abs(hip.x) * 0.9 else 0.0
            return skin_colour(p, n), (float(limb + 1), w), (0.0, 0.0)

        model.add(leg, leg_info)
        # Toes and claws, splayed forward and out.
        side = 1.0 if left else -1.0
        fan = [-35.0, -8.0, 18.0, 45.0] if limb < 2 else [-25.0, 0.0, 25.0, 55.0]
        for k, angle in enumerate(fan):
            a = math.radians(angle)
            way = V(math.sin(a) * side, 0.0, math.cos(a))
            start = foot + V(0.0, 0.02, 0.0)
            knuckle = start + way * 0.32 + V(0.0, 0.03, 0.0)
            end = start + way * 0.5 + V(0.0, -0.03, 0.0)
            toe = skinned([tuple(start), tuple(knuckle), tuple(end)], [0.08, 0.065, 0.045], levels=1)

            def toe_info(p, n, hip=hip, reach=reach, limb=limb):
                return skin_colour(p, n), (float(limb + 1), 1.0), (0.0, 0.0)

            model.add(toe, toe_info)
            claw = cone(tuple(end - way * 0.02), tuple(end + way * 0.2 + V(0.0, -0.06, 0.0)), 0.05, segments=6, bend=(0.0, 1.0, 0.0))

            def claw_info(p, n, limb=limb):
                return CLAW, (float(limb + 1), 1.0), (0.0, 0.0)

            model.add(claw, claw_info)

    # Scutes: a row of blunt bony knobs down the spine, from the hump to near the tail's tip, and two lower rows.
    rng = random.Random(5)
    rows = [(0.0, 1.0, 26 if not low else 14)] + [(side * 0.62, 0.55, 16 if not low else 8) for side in (1.0, -1.0)]
    for x0, size, count in rows:
        for i in range(count):
            t = i / (count - 1)
            z = 2.0 - t * (7.2 if x0 == 0.0 else 4.0)
            # (the height of the back there, from a ray down onto what is built so far is too dear: a profile)
            if z > -1.8:
                y = 1.5 + 0.1 * smooth(1.0, 2.0, z) + 0.04 * math.sin(z * 1.3) if x0 == 0.0 else 1.3 - 0.02 * abs(z)
                r = 0.2 * size
            else:
                if x0 != 0.0:
                    continue
                cx, cy, cr = tail_at(z)
                tt = tail_t((0, 0, z))
                r = 0.18 * size * (1.0 - tt * 0.75)
                y = cy + cr * 0.92
            x = x0 * (1.0 - 0.15 * abs(z) / 2.0) if x0 != 0.0 or z > -1.8 else tail_at(z)[0]
            r *= 0.85 + 0.3 * rng.random()
            knob = ellipsoid((x, y, z), (r * 0.8, r * 0.9, r * 1.4), segments=7 if low else 9, rings=5 if low else 6)

            def scute_info(p, n, y0=y, r=r, z=z):
                lift = smooth(y0 - r * 0.4, y0 + r * 0.9, p.y)
                c = mix(SCUTE, scale(FLANK, 1.1), lift * 0.6)
                return c, (0.0, 0.0), (tail_t((0, 0, z)), 0.5 + 0.5 * lift)

            model.add(knob, scute_info)


# --- The head ---

HINGE = V(0.0, -0.05, 0.14)


def head_colour(p, n):
    up = n.y
    c = mix(FLANK, BACK, smooth(-0.2, 0.5, up))
    c = mix(c, BELLY, smooth(-0.3, -0.7, up))
    # (a dark band back from the eye, as many snakes have)
    band = smooth(0.06, 0.0, abs(p.y - (0.05 - (0.5 - p.z) * 0.12))) * smooth(0.0, 0.25, abs(p.x)) * smooth(0.75, 0.45, p.z)
    c = mix(c, scale(BACK, 0.5), band * 0.8)
    return scale(c, 0.9 + 0.2 * noise.noise(V(*p) * 9.0))


def build_head(model, low):
    res = 0.045 if low else 0.024
    # (the mouth's line: everything of the upper head below it is cut away, everything of the jaw above it)
    lip = -0.045
    upper = blobs([
        # (the broad back of the skull, the jaw muscles swelling it out behind the eyes: a viper's triangle)
        ((0.0, 0.02, 0.26), (0.24, 0.12, 0.28), (0, 0, 0)),
        ((0.19, -0.0, 0.2), (0.13, 0.1, 0.2), (0, 28, 0)),
        ((-0.19, -0.0, 0.2), (0.13, 0.1, 0.2), (0, -28, 0)),
        # (the snout, flat-topped, narrowing to a blunt end)
        ((0.0, 0.01, 0.62), (0.17, 0.085, 0.3), (3, 0, 0)),
        ((0.0, 0.0, 0.86), (0.11, 0.06, 0.12), (6, 0, 0)),
        # (the heavy brows over the eyes, jutting)
        ((0.13, 0.08, 0.56), (0.085, 0.045, 0.15), (0, 10, 0)),
        ((-0.13, 0.08, 0.56), (0.085, 0.045, 0.15), (0, -10, 0)),
        # (where the neck goes in)
        ((0.0, -0.01, 0.04), (0.19, 0.15, 0.13), (0, 0, 0)),
    ], res, smoothing=2)
    upper = cut_below(upper, lip)
    upper = thin(upper, 700 if low else 2200)

    def upper_info(p, n):
        if p.y < lip + 0.012 and n.y < -0.5:
            return MOUTH_C, (MOUTH, 0.0), (0.0, 0.0)
        return head_colour(p, n), (SCALES, 0.0), (0.0, 0.0)

    model.add(upper, upper_info)

    lower = blobs([
        ((0.0, -0.085, 0.34), (0.22, 0.05, 0.32), (0, 0, 0)),
        ((0.0, -0.08, 0.68), (0.15, 0.04, 0.24), (0, 0, 0)),
        ((0.17, -0.08, 0.17), (0.1, 0.06, 0.16), (0, 22, 0)),
        ((-0.17, -0.08, 0.17), (0.1, 0.06, 0.16), (0, -22, 0)),
        ((0.0, -0.09, 0.07), (0.16, 0.08, 0.1), (0, 0, 0)),
    ], res, smoothing=2)
    lower = cut_above(lower, lip)
    lower = thin(lower, 450 if low else 1400)

    def lower_info(p, n):
        if p.y > lip - 0.012 and n.y > 0.5:
            return MOUTH_C, (MOUTH, 1.0), (0.0, 0.0)
        return head_colour(p, n), (SCALES, 1.0), (0.0, 0.0)

    model.add(lower, lower_info)

    # Eyes: set at the sides under the brows, looking out and a little forward and up. No lids.
    for side in (1.0, -1.0):
        centre = V(0.16 * side, 0.045, 0.6)
        look = V(0.85 * side, 0.25, 0.5).normalized()
        across = V(0, 1, 0).cross(look).normalized()
        up = look.cross(across).normalized()
        eye = ellipsoid(tuple(centre), (0.05, 0.05, 0.05), segments=8 if low else 14, rings=6 if low else 10)

        def eye_info(p, n, centre=centre, look=look, across=across, up=up):
            d = (p - centre).normalized()
            return EYE_C, (EYE, 0.0), (d.dot(across) / 0.75, d.dot(up) / 0.75)

        model.add(eye, eye_info)

    # The fangs, folded back along the roof of the mouth (Godot's shader swings them down as the jaw opens).
    for side in (1.0, -1.0):
        base = V(0.075 * side, lip - 0.008, 0.84)
        tip = base + V(0.0, -0.02, -0.22)
        fang = cone(tuple(base), tuple(tip), 0.026, segments=5 if low else 7, bend=(0.0, -1.0, 0.0))

        def fang_info(p, n):
            return FANG_C, (FANG, 0.0), (0.0, 0.0)

        model.add(fang, fang_info)

    # The tongue: a dark forked strap lying in the mouth, from the throat to behind the snout.
    y = lip - 0.022
    shaft = skinned([(0.0, y, 0.3), (0.0, y, 0.5), (0.0, y, 0.66), (0.0, y, 0.76)],
                    [(0.026, 0.011), (0.022, 0.01), (0.017, 0.008), (0.013, 0.007)], levels=1)

    def tongue_info(p, n):
        return TONGUE_C, (TONGUE, 0.0), (smooth(0.3, 0.9, p.z), 0.0)

    model.add(shaft, tongue_info)
    for side in (1.0, -1.0):
        prong = skinned([(0.0, y, 0.75), (0.02 * side, y, 0.83), (0.04 * side, y, 0.9)],
                        [(0.01, 0.007), (0.007, 0.005), (0.003, 0.002)], levels=1)
        model.add(prong, tongue_info)


def cut_below(mesh, y):
    """Cuts away what of `mesh` is below height `y` (Godot), and closes it over there."""
    return _cut(mesh, y, -1.0)


def cut_above(mesh, y):
    return _cut(mesh, y, 1.0)


def _cut(mesh, y, way):
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=0.0001,
                           plane_co=B(V(0, y, 0)), plane_no=B(V(0, way, 0)), clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        made = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
        bmesh.ops.triangulate(bm, faces=made["faces"])
    bm.to_mesh(mesh)
    bm.free()
    return mesh


# --- Putting it out ---

def export(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    options = dict(filepath=path, export_format="GLB", export_yup=True, export_animations=False, export_skins=False,
                   export_morph=False, export_materials="NONE", export_normals=True, export_texcoords=True, use_selection=True)
    try:
        bpy.ops.export_scene.gltf(**options, export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)
    except TypeError:
        bpy.ops.export_scene.gltf(**options, export_colors=True)


def build(name, low):
    clear()
    body_model = Model()
    build_body(body_model, low)
    body = body_model.finish("body")
    head_model = Model()
    build_head(head_model, low)
    head = head_model.finish("head")
    os.makedirs(os.path.join(FOLDER, "models"), exist_ok=True)
    path = os.path.join(FOLDER, "models", name + ".glb")
    export(path, [body, head])
    for obj in (body, head):
        print("BUILT %s %s verts=%d tris=%d" % (name, obj.name, len(obj.data.vertices), sum(len(p.vertices) - 2 for p in obj.data.polygons)))
    if PREVIEW_DIR and not low:
        previews(name, body, head)


def previews(name, body, head):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.render.resolution_x, scene.render.resolution_y = 800, 600
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.38, 0.42)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.lens = 50
    scene.collection.objects.link(camera)
    scene.camera = camera
    head.location = B(V(0.0, 2.2, 3.4))
    centre = B(V(0, 0.9, -0.8))
    views = [("quarter", V(0.8, 0.5, 0.8), centre, 14.0), ("side", V(1.0, 0.1, 0.0), centre, 14.0),
             ("top", V(0.02, 1.0, 0.1), centre, 14.0), ("back", V(-0.6, 0.5, -0.9), centre, 14.0)]
    for view, direction, target, far in views:
        offset = B(direction.normalized()) * far
        camera.location = target + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)
    body.hide_render = True
    head.location = (0, 0, 0)
    middle = B(V(0, 0.0, 0.5))
    for view, direction in (("head_quarter", V(0.8, 0.4, 0.9)), ("head_side", V(1.0, 0.05, 0.0)), ("head_front", V(0.0, 0.1, 1.0)), ("head_below", V(0.3, -0.8, 0.5))):
        offset = B(direction.normalized()) * 2.4
        camera.location = middle + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for model_name, low in (("hydra", False), ("hydra_lo", True)):
        build(model_name, low)

"""Builds the chicken (hen and rooster in one model) and exports it for Godot.

Run from the project root (Blender 4.3):
    blender --background --python creatures/chicken/tools/build_chicken.py
    blender --background --python creatures/chicken/tools/build_chicken.py -- <folder>   # and pictures

Writes creatures/chicken/models/chicken.glb. ChickenBody (creatures/chicken/
chicken_body.gd) reads it and merges it into the flock's mesh, telling the
parts apart by their object and material names. The shader poses the parts
(there is no armature here): which bone carries a part is in its object's
name, and ChickenBody works out how the neck, the hocks and the toes bend from
where each vertex is.

All coordinates below are in Godot space (metres, Y up, the bird facing +Z,
+X its left), converted on the way into Blender. A hen stands about 0.5 m to
the top of her comb; the rooster is the same model (the flock scales him up)
with his own parts.

Objects (a name ending `__h` is the hen's only, `__r` the rooster's only: the
shader hides the other's):
- body: the core, one smooth surface (a metaball family) from the tail's root
  over the back and breast, up the neck to the skull and face; underneath the
  feathers it is the under-down. Material `down`.
- feathers: contour feathers over the body in overlapping rows, each a small
  curved vane with a raised shaft, pointing back and down, the belly's longer
  and fluffier, the crown's tiny. Material `feather`; UV is (across, along)
  the vane; UV2 is (a random number for the feather, its region / 8).
- hackle__h, hackle__r: the neck's long narrow feathers falling over the
  shoulders (the rooster's long, flowing cape); saddle__r: his lancets
  down the sides in front of the tail; tail__h (a short tent of broad
  feathers), tail__r (the same, with two great sickles a side arching back
  and over, and lesser sickles).
- wing_l, wing_r: the wing, folded against the flank, with a shape key `open`
  for it spread: two rows of coverts, ten secondaries along the forearm and ten
  primaries along the hand, fanning.
- thigh_l, thigh_r: the feathered drumstick; shank_l, shank_r: the scaly
  shank from the hock (the ankle, that bends backwards) to the foot, ringed
  with scales, a row of big scutes down the front, and (shank_spur_*__r)
  his spurs; toes_l, toes_r: three toes forward, spread, and one back, each
  jointed and padded, with nails (material `claw`).
- comb__h, comb__r: the single comb, serrated; wattle__h, wattle__r: the
  two lobes under the beak; lobes: the ear lobes; all material `comb` but the
  lobes (`lobe`). The face round the eye is bare red skin (ChickenBody marks
  it from where it is).
- beak: the upper mandible, hooked; jaw: the lower (opened by the shader);
  nostril; eye: beads with UV.y the angle off the eye's axis (iris, pupil).
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "creatures", "chicken", "models", "chicken.glb")

# How much of its radius a lone metaball's surface is at (threshold 0.6, stiffness 2).
SHRINK = 0.672

# Regions, as the shader colours them (UV2.y * 8).
BREAST, BACK, HACKLE, COVERT, FLIGHT, TAIL, SICKLE, SADDLE, CROWN = range(9)

# The joints at rest (keep to ChickenBody's).
NECK_BASE = Vector((0.0, 0.37, 0.1))
HEAD = Vector((0.0, 0.49, 0.168))
KNEE = Vector((0.062, 0.245, 0.005))
HOCK = Vector((0.056, 0.122, -0.032))
FOOT = Vector((0.052, 0.026, 0.012))
SHOULDER = Vector((0.07, 0.355, 0.07))
TAIL_ROOT = Vector((0.0, 0.39, -0.17))

rng = random.Random(7)


def B(p):
    """Godot (x, y, z) to Blender."""
    return Vector((p[0], -p[2], p[1]))


def G(v):
    """Blender to Godot."""
    return Vector((v.x, v.z, -v.y))


def V(x, y, z):
    return Vector((x, y, z))


def clear():
    for thing in list(bpy.data.objects):
        bpy.data.objects.remove(thing, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for ball in list(bpy.data.metaballs):
        bpy.data.metaballs.remove(ball)


COLOURS = {
    "down": (0.36, 0.17, 0.08), "feather": (0.45, 0.2, 0.08), "comb": (0.6, 0.06, 0.05),
    "lobe": (0.65, 0.12, 0.08), "beak": (0.72, 0.6, 0.3), "leg": (0.75, 0.62, 0.25),
    "claw": (0.3, 0.26, 0.2), "eye": (0.8, 0.45, 0.1), "nostril": (0.1, 0.07, 0.05),
}
MATERIALS = {}


def mat(name):
    if name not in MATERIALS:
        made = bpy.data.materials.new(name)
        made.diffuse_color = (*COLOURS[name], 1.0)
        made.use_nodes = True
        shader = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs[0].default_value = (*COLOURS[name], 1.0)
        MATERIALS[name] = made
    return MATERIALS[name]


class Part:
    """A mesh being made: vertices (Godot space), each with UV and UV2 and,
    for a wing, where it goes with the wing open; faces as lists of indices."""

    def __init__(self, name, material):
        self.name = name
        self.material = material
        self.points = []
        self.uv = []
        self.uv2 = []
        self.open = []
        self.faces = []
        self.smooth = []

    def v(self, p, uv=(0.0, 0.0), uv2=(0.0, 0.0), open_p=None):
        self.points.append(Vector(p))
        self.uv.append(uv)
        self.uv2.append(uv2)
        self.open.append(Vector(open_p) if open_p is not None else Vector(p))
        return len(self.points) - 1

    def f(self, idx, smooth=True):
        self.faces.append(list(idx))
        self.smooth.append(smooth)

    def make(self, with_open=False):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([B(p) for p in self.points], [], self.faces)
        mesh.update()
        uv = mesh.uv_layers.new(name="UVMap")
        uv2 = mesh.uv_layers.new(name="UV2")
        for poly, smooth in zip(mesh.polygons, self.smooth):
            poly.use_smooth = smooth
            for loop in poly.loop_indices:
                vi = mesh.loops[loop].vertex_index
                uv.data[loop].uv = self.uv[vi]
                uv2.data[loop].uv = self.uv2[vi]
        made = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(made)
        made.data.materials.append(mat(self.material))
        if with_open:
            made.shape_key_add(name="Basis")
            key = made.shape_key_add(name="open")
            for i, p in enumerate(self.open):
                key.data[i].co = B(p)
        return made


def blobs(name, balls, faces, resolution=0.006):
    """One fused surface from `balls` ((x, y, z), surface radius, (sx, sy, sz)
    stretch): a metaball family, made a mesh, smoothed and thinned to about
    `faces` triangles."""
    ball_data = bpy.data.metaballs.new(name)
    ball_data.resolution = resolution
    ball_data.render_resolution = resolution
    ball_data.threshold = 0.6
    holder = bpy.data.objects.new(name, ball_data)
    bpy.context.scene.collection.objects.link(holder)
    for ball in balls:
        at, radius = ball[0], ball[1]
        stretch = ball[2] if len(ball) > 2 else (1.0, 1.0, 1.0)
        element = ball_data.elements.new(type="ELLIPSOID" if stretch != (1.0, 1.0, 1.0) else "BALL")
        element.co = B(at)
        element.radius = radius / SHRINK
        element.stiffness = 2.0
        if stretch != (1.0, 1.0, 1.0):
            # (Godot x, y, z stretch is Blender x, z, y)
            element.size_x = stretch[0]
            element.size_y = stretch[2]
            element.size_z = stretch[1]
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(holder.evaluated_get(depsgraph))
    bpy.data.objects.remove(holder, do_unlink=True)
    made = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(made)
    bpy.context.view_layer.objects.active = made
    made.select_set(True)
    smooth = made.modifiers.new("smooth", "SMOOTH")
    smooth.factor = 0.5
    smooth.iterations = 3
    bpy.ops.object.modifier_apply(modifier="smooth")
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    thin = made.modifiers.new("thin", "DECIMATE")
    thin.ratio = min(1.0, faces / max(tris, 1))
    bpy.ops.object.modifier_apply(modifier="thin")
    made.select_set(False)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    uv = mesh.uv_layers.new(name="UVMap")
    mesh.uv_layers.new(name="UV2")
    return made


# --- Feathers ---

def frame(d, n):
    """An orthonormal frame: along `d`, `n` made square to it, and the side."""
    d = Vector(d).normalized()
    n = (Vector(n) - d * Vector(n).dot(d)).normalized()
    s = n.cross(d).normalized()
    return d, n, s


def vane_points(root, d, n, length, width, kind="round", lift=0.18, bend=0.0, cup=0.12, rows=3, twist=0.0, skew=0.0, arc=0.0, drape=None, rise=0.004):
    """A feather's vertices: rows of three (one vane edge, the shaft, the
    other edge) out from `root` along `d`, the vane in the plane square to `n`,
    lifted off the surface towards the tip by `lift` of its length, bent along
    its length towards `n` by `bend`, cupped (edges down) by `cup` of its
    width, and a tip. `kind`: round (body feathers), lance (hackles, saddle),
    flight (long, the vanes unequal), broad (tail). Returns the points and
    their (across, along). With `drape` (a BVHTree of the body), the feather
    is laid along the surface, each row `rise` off it (and lifted by `lift`
    towards the tip), as long feathers drape over the shoulders."""
    d, n, s = frame(d, n)

    def draped(middle, t):
        hit, normal, _, _ = drape.find_nearest(B(middle))
        if hit is None:
            return middle
        return G(hit) + G(normal).normalized() * (rise + lift * length * t ** 1.6)

    points = []
    uvs = []
    for r in range(rows + 1):
        t = r / (rows + 0.6)
        if kind == "round":
            half = 0.5 * width * (0.45 + 0.55 * math.sin(math.pi * min(0.18 + t * 0.95, 0.98)) ** 0.7)
        elif kind == "lance":
            half = 0.5 * width * (0.35 + 0.65 * (1.0 - t) ** 0.8) * min(1.0, 0.5 + t * 3.0)
        elif kind == "flight":
            half = 0.5 * width * (0.55 + 0.45 * math.sin(math.pi * min(0.3 + t * 0.75, 0.97)))
        else:
            half = 0.5 * width * (0.5 + 0.5 * math.sin(math.pi * min(0.2 + t * 0.85, 0.97)))
        along = length * t
        up = lift * length * t ** 1.6 + bend * length * t * t
        middle = Vector(root) + d * along + n * up
        if arc > 0.0:
            # (a circular arc `arc` radians round, towards n)
            middle = Vector(root) + (d * math.sin(arc * t) + n * (1.0 - math.cos(arc * t))) * length / arc
        elif drape is not None:
            middle = draped(middle, t)
        tw = twist * t
        side = s * math.cos(tw) + n * math.sin(tw)
        lean = n * math.cos(tw) - s * math.sin(tw)
        left = half * (1.0 - skew)
        right = half * (1.0 + skew)
        points.append(middle + side * left - lean * cup * left)
        uvs.append((-1.0, t))
        points.append(middle + lean * width * 0.07)
        uvs.append((0.0, t))
        points.append(middle - side * right - lean * cup * right)
        uvs.append((1.0, t))
    tip_t = 1.0
    up = lift * length + bend * length
    if arc > 0.0:
        points.append(Vector(root) + (d * math.sin(arc) + n * (1.0 - math.cos(arc))) * length / arc)
    elif drape is not None:
        points.append(draped(Vector(root) + d * length + n * up, 1.0))
    else:
        points.append(Vector(root) + d * length + n * up)
    uvs.append((0.0, tip_t))
    return points, uvs


def vane_faces(base, rows=3):
    faces = []
    for r in range(rows):
        a = base + r * 3
        b = a + 3
        faces.append([a, b, b + 1, a + 1])
        faces.append([a + 1, b + 1, b + 2, a + 2])
    last = base + rows * 3
    tip = last + 3
    faces.append([last, tip, last + 1])
    faces.append([last + 1, tip, last + 2])
    return faces


def feather(part, root, d, n, length, width, region, kind="round", open_frame=None, rows=3, **shape):
    """Adds one feather to `part` (and, for a wing, where it is when open:
    `open_frame` = (root, d, n))."""
    pts, uvs = vane_points(root, d, n, length, width, kind, rows=rows, **shape)
    opened = vane_points(open_frame[0], open_frame[1], open_frame[2], length, width, kind, rows=rows, **shape)[0] if open_frame else pts
    tag = rng.random()
    base = len(part.points)
    for p, uv, q in zip(pts, uvs, opened):
        part.v(p, uv, (tag, (region + 0.5) / 8.0), q)
    for face in vane_faces(base, rows):
        part.f(face)


# --- Solid pieces ---

def tube(part, line, radii, sides=8, uv2=(0.0, 0.0), cap_end=True, cap_start=False, squash=1.0, ridge=None, along_uv=True, up=Vector((0, 1, 0))):
    """A round tube along the points of `line` with a radius at each, its ends
    closed. `ridge`(k, i): extra radius for side k of ring i (scales)."""
    rings = []
    total = sum((line[i + 1] - line[i]).length for i in range(len(line) - 1))
    run = 0.0
    for i, at in enumerate(line):
        if i > 0:
            run += (line[i] - line[i - 1]).length
        ahead = (line[min(i + 1, len(line) - 1)] - line[max(i - 1, 0)]).normalized()
        side = ahead.cross(up)
        if side.length < 0.1:
            side = ahead.cross(Vector((0, 0, 1)))
        side = side.normalized()
        top = side.cross(ahead).normalized()
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            r = radii[i] + (ridge(k, i) if ridge else 0.0)
            p = at + (side * math.cos(a) + top * math.sin(a) * squash) * r
            ring.append(part.v(p, (k / sides, run / max(total, 1e-6)), uv2))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            a, b = rings[i][k], rings[i][(k + 1) % sides]
            c, d = rings[i + 1][(k + 1) % sides], rings[i + 1][k]
            part.f([a, d, c, b])
    if cap_end:
        end = (line[-1] - line[-2]).normalized()
        tip = part.v(line[-1] + end * radii[-1] * 0.6, (0.0, 1.0), uv2)
        for k in range(sides):
            part.f([rings[-1][k], tip, rings[-1][(k + 1) % sides]])
    if cap_start:
        start = (line[0] - line[1]).normalized()
        tip = part.v(line[0] + start * radii[0] * 0.6, (0.0, 0.0), uv2)
        for k in range(sides):
            part.f([rings[0][(k + 1) % sides], tip, rings[0][k]])


def ball(part, middle, radii, segments=8, rings=6, axis=Vector((0, 0, 1)), uv2=(0.0, 0.0), polar_uv=False):
    """An ellipsoid; with `polar_uv`, UV.y is the angle off `axis` (0 at the
    pole that faces along it), for an eye."""
    middle = Vector(middle)
    axis = Vector(axis).normalized()
    one = axis.cross(Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))).normalized()
    two = axis.cross(one).normalized()
    top = part.v(middle + axis * radii[2], (0.0, 0.0), uv2)
    rows = []
    for r in range(1, rings):
        a = math.pi * r / rings
        row = []
        for s in range(segments):
            b = math.tau * s / segments
            p = middle + axis * math.cos(a) * radii[2] + (one * math.cos(b) * radii[0] + two * math.sin(b) * radii[1]) * math.sin(a)
            row.append(part.v(p, (s / segments, a / math.pi if polar_uv else r / rings), uv2))
        rows.append(row)
    bottom = part.v(middle - axis * radii[2], (0.0, 1.0), uv2)
    for s in range(segments):
        t = (s + 1) % segments
        part.f([top, rows[0][s], rows[0][t]])
        part.f([bottom, rows[-1][t], rows[-1][s]])
    for r in range(len(rows) - 1):
        for s in range(segments):
            t = (s + 1) % segments
            part.f([rows[r][s], rows[r + 1][s], rows[r + 1][t], rows[r][t]])


def slab(part, outline, thickness, middle_x=0.0, puff=0.4, uv2=(0.0, 0.0)):
    """A flat shape standing in the YZ plane (a comb, a wattle): the closed
    `outline` ((y, z) points, in order round it) given a thickness that is
    full in its middle and thins to the edge, as a fleshy blade is."""
    centre = Vector((0.0, sum(p[0] for p in outline) / len(outline), sum(p[1] for p in outline) / len(outline)))
    rings = [1.0, 0.62, 0.0]
    count = len(outline)
    sides = []
    for sign in (1.0, -1.0):
        layer = []
        for k, ring in enumerate(rings):
            row = []
            for (y, z) in outline:
                p = Vector((0.0, y, z))
                q = centre + (p - centre) * ring
                swell = thickness * 0.5 * (1.0 - (ring ** 2) * (1.0 - puff))
                row.append(part.v((middle_x + sign * swell, q.y, q.z), (ring, 0.0), uv2))
            layer.append(row)
        sides.append(layer)
    for si, layer in enumerate(sides):
        for k in range(len(rings) - 1):
            for i in range(count):
                j = (i + 1) % count
                quad = [layer[k][i], layer[k][j], layer[k + 1][j], layer[k + 1][i]]
                part.f(quad if si == 0 else list(reversed(quad)))
    # The rim: the two outermost rows joined.
    for i in range(count):
        j = (i + 1) % count
        part.f([sides[0][0][i], sides[1][0][i], sides[1][0][j], sides[0][0][j]])


# --- The bird ---

BODY_BALLS = [
    # The body: an egg, deep in the breast, the back rising to the tail.
    ((0.0, 0.3, 0.075), 0.098, (1.0, 1.0, 1.0)),
    ((0.0, 0.265, 0.0), 0.11, (1.05, 1.0, 1.1)),
    ((0.0, 0.31, -0.06), 0.105, (1.05, 1.0, 1.05)),
    ((0.0, 0.33, -0.13), 0.075, (1.0, 1.0, 1.0)),
    ((0.0, 0.37, -0.175), 0.045, (1.0, 1.0, 1.0)),
    ((0.045, 0.34, 0.04), 0.06), ((-0.045, 0.34, 0.04), 0.06),
    ((0.0, 0.215, -0.04), 0.075, (1.1, 1.0, 1.2)),
    # The neck, an S up from the shoulders to the skull.
    ((0.0, 0.375, 0.105), 0.056),
    ((0.0, 0.41, 0.128), 0.044),
    ((0.0, 0.445, 0.143), 0.035),
    ((0.0, 0.47, 0.155), 0.03),
    # The head: the skull, and the face narrowing to the beak.
    ((0.0, 0.493, 0.165), 0.03, (0.85, 0.95, 1.15)),
    ((0.0, 0.486, 0.186), 0.022, (0.8, 0.95, 1.0)),
]


def body_part():
    body = blobs("body", BODY_BALLS, 950)
    body.data.materials.append(mat("down"))
    return body


def body_feathers(tree):
    """Contour feathers over the body, in rows round it from the breast to
    the tail, each laid on the surface pointing back and down."""
    part = Part("feathers", "feather")
    axis_from = V(0.0, 0.31, 0.15)
    axis_to = V(0.0, 0.35, -0.2)
    rows = 13
    for r in range(rows):
        u = (r + 0.5) / rows
        middle = axis_from.lerp(axis_to, u)
        around = 17 if 0.1 < u < 0.85 else 13
        for k in range(around):
            a = math.tau * (k + 0.5 * (r % 2)) / around
            out = V(math.sin(a), math.cos(a), 0.0)
            hit, normal, _, _ = tree.ray_cast(B(middle + out * 0.4), B(-out))
            if hit is None:
                continue
            at = G(hit)
            nrm = G(normal).normalized()
            below = -out.y
            # (back and down; on the breast's front, down)
            flow = V(0.0, -0.45 - 0.5 * max(below, 0.0), -1.0)
            if nrm.z > 0.6:
                flow = V(0.0, -1.0, -0.25)
            flow = flow - nrm * flow.dot(nrm)
            if flow.length < 0.05:
                flow = V(0.0, -1.0, 0.0)
            flow = flow.normalized()
            jitter = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.1, 0.1), rng.uniform(-0.15, 0.15)))
            flow = (flow + jitter).normalized()
            fluffy = max(below - 0.4, 0.0)
            length = (0.06 + 0.012 * fluffy) * rng.uniform(0.85, 1.2)
            width = (0.048 + 0.01 * fluffy) * rng.uniform(0.85, 1.15)
            back_top = at.y > 0.33 and at.z < -0.03
            region = BACK if back_top else BREAST
            feather(part, at - nrm * 0.004, flow, nrm, length, width, region, "round",
                    lift=0.16 + 0.1 * fluffy + rng.uniform(0.0, 0.1), cup=0.15, twist=rng.uniform(-0.2, 0.2), rows=2)
    # The breast's front, which the rows round the body do not reach: shingled
    # down it from the throat, the higher over the lower.
    for row in range(7):
        y = 0.4 - row * 0.032
        for k in range(5):
            x = (k - 2) * 0.032 + (0.016 if row % 2 else 0.0)
            hit, normal, _, _ = tree.ray_cast(B(V(x, y, 0.5)), B(V(0.0, 0.0, -1.0)))
            if hit is None:
                continue
            at = G(hit)
            nrm = G(normal).normalized()
            if nrm.z < 0.45:
                continue
            flow = V(0.0, -1.0, -0.2)
            flow = (flow - nrm * flow.dot(nrm)).normalized()
            flow = (flow + V(rng.uniform(-0.2, 0.2), 0.0, 0.0)).normalized()
            feather(part, at - nrm * 0.002, flow, nrm, 0.055 * rng.uniform(0.9, 1.15), 0.045, BREAST, "round",
                    lift=0.2, cup=0.15, rows=2, twist=rng.uniform(-0.2, 0.2))
    # The crown: tiny feathers over the top and back of the skull.
    for k in range(14):
        a = rng.uniform(-1.2, 1.2)
        b = rng.uniform(0.0, 1.0)
        origin = HEAD + V(math.sin(a) * 0.2, math.cos(a) * 0.2, -0.05 - 0.15 * b)
        hit, normal, _, _ = tree.ray_cast(B(origin), B((HEAD + V(0, 0, -0.01) - origin).normalized()))
        if hit is None:
            continue
        at = G(hit)
        if at.z > HEAD.z + 0.012:
            continue
        nrm = G(normal).normalized()
        flow = V(0.0, -0.4, -1.0)
        flow = (flow - nrm * flow.dot(nrm)).normalized()
        feather(part, at - nrm * 0.002, flow, nrm, 0.022, 0.014, CROWN, "round", lift=0.3, cup=0.1, rows=2)
    return part


def neck_feathers(tree, rooster):
    """Hackles: rings of long narrow feathers round the neck, from under the
    skull down over the shoulders, longest at the bottom."""
    part = Part("hackle__r" if rooster else "hackle__h", "feather")
    rings = 7
    for r in range(rings):
        u = r / (rings - 1)
        middle = HEAD.lerp(NECK_BASE, 0.18 + 0.82 * u) + V(0.0, 0.0, -0.012)
        around = 12
        for k in range(around):
            a = math.tau * (k + 0.5 * (r % 2)) / around
            # (none on the throat at the top: the wattles hang there)
            if u < 0.35 and abs(a - math.pi) < 0.9:
                pass
            out = V(math.sin(a), 0.0, math.cos(a))
            hit, normal, _, _ = tree.ray_cast(B(middle + out * 0.3), B(-out))
            if hit is None:
                continue
            at = G(hit)
            nrm = G(normal).normalized()
            down = (NECK_BASE - HEAD).normalized() + V(0.0, -0.4, -0.3)
            if out.z > 0.5:
                down = V(0.0, -1.0, 0.15)
            down = (down - nrm * down.dot(nrm)).normalized()
            down = (down + V(rng.uniform(-0.15, 0.15), 0.0, rng.uniform(-0.1, 0.1))).normalized()
            if rooster:
                length = (0.05 + 0.1 * u ** 1.2) * rng.uniform(0.9, 1.15)
                width = 0.018 + 0.008 * u
            else:
                length = (0.04 + 0.05 * u) * rng.uniform(0.9, 1.15)
                width = 0.02 + 0.008 * u
            feather(part, at - nrm * 0.003, down, nrm, length, width, HACKLE, "lance",
                    lift=0.06 + 0.06 * u, cup=0.08, twist=rng.uniform(-0.25, 0.25), rows=2, drape=tree, rise=0.004 + 0.007 * (1.0 - u))
    return part


def saddle_feathers(tree):
    """The rooster's saddle: lancets down the sides of the lower back, in
    front of the tail, falling over the wing tips."""
    part = Part("saddle__r", "feather")
    for r in range(5):
        z = -0.06 - r * 0.025
        for k in range(9):
            a = -1.4 + 2.8 * k / 8
            origin = V(math.sin(a) * 0.3, 0.33 + math.cos(a) * 0.3, z)
            hit, normal, _, _ = tree.ray_cast(B(origin), B((V(0.0, 0.31, z) - origin).normalized()))
            if hit is None:
                continue
            at = G(hit)
            nrm = G(normal).normalized()
            flow = V(math.sin(a) * 0.5, -0.8, -0.7)
            flow = (flow - nrm * flow.dot(nrm)).normalized()
            feather(part, at - nrm * 0.003, flow, nrm, rng.uniform(0.1, 0.14), 0.022, SADDLE, "lance",
                    lift=0.06, cup=0.05, twist=rng.uniform(-0.3, 0.3), drape=tree, rise=0.022)
    return part


def tail(rooster):
    """The tail: two planes of broad feathers meeting along the top like a
    tent, fanned from the tail's root up and back; the rooster's has, over
    them, two great sickles a side and lesser sickles, arching back and over."""
    part = Part("tail__r" if rooster else "tail__h", "feather")
    count = 7
    for side in (1.0, -1.0):
        for k in range(count):
            u = k / (count - 1)
            # (from the top, upright, to the outside, lower and spread)
            rise = 1.25 - 0.85 * u
            d = V(side * (0.08 + 0.3 * u), math.sin(rise), -math.cos(rise)).normalized()
            n = V(side, 0.15, 0.0)
            root = TAIL_ROOT + V(side * (0.008 + 0.012 * u), -0.01 * u, 0.01 * u)
            length = (0.17 if not rooster else 0.2) * (1.0 - 0.25 * u) * rng.uniform(0.92, 1.05)
            feather(part, root, d, n, length, 0.05, TAIL, "broad", lift=0.0, bend=0.06, cup=-0.05, rows=4, twist=side * 0.1)
            # Its covert, shorter, over its root.
            feather(part, root + d * 0.01 + n * 0.008, (d + V(0, 0, -0.3)).normalized(), n, length * 0.5, 0.042, TAIL, "round", lift=0.05, cup=0.0, rows=2)
    if rooster:
        for side in (1.0, -1.0):
            for k in range(5):
                great = k < 2
                length = (0.46 - 0.07 * k) if great else rng.uniform(0.22, 0.3)
                lean = 0.03 + 0.05 * k
                d = V(side * lean, 1.0, -0.1 - 0.12 * k).normalized()
                n = V(0.0, 0.0, -1.0)
                root = TAIL_ROOT + V(side * (0.01 + 0.006 * k), 0.012, 0.02 + 0.01 * k)
                feather(part, root, d, n, length, 0.065 if great else 0.045, SICKLE, "lance",
                        lift=0.0, arc=2.7 if great else 2.0, cup=0.08, rows=7 if great else 4, twist=side * 0.4)
    return part


def wing(side, tree):
    """A wing, folded against the flank (and, by the shape key, spread):
    ten primaries on the hand, ten secondaries on the forearm, and three rows
    of coverts over their roots and the leading edge. Folded, every feather
    lies on the flank a layer out from the one under it: the primaries
    lowest, the secondaries over them (the inner ones on top), the coverts
    over their roots."""
    part = Part("wing_l" if side > 0 else "wing_r", "feather")

    def mx(p):
        return V(p.x * side, p.y, p.z)

    def flank(p, layer):
        """`p` (on the +X side) put on the body's surface, `layer` out from it, and the way out there."""
        hit, normal, _, _ = tree.ray_cast(B(V(0.4, p.y, p.z)), B(V(-1.0, 0.0, 0.0)))
        if hit is None:
            return V(0.1 + layer, p.y, p.z), V(1.0, 0.0, 0.0)
        at = G(hit)
        out = G(normal).normalized()
        return at + out * layer, out

    # Spread: the joints, out along X.
    s_o = SHOULDER
    e_o = V(0.15, 0.36, 0.06)
    w_o = V(0.26, 0.365, 0.075)
    t_o = V(0.37, 0.36, 0.06)
    up_o = V(0.0, 1.0, 0.0)
    # Folded: the forearm along the top of the flank (wrist forward), the hand back under it.
    sec_line = (V(0.1, 0.33, 0.06), V(0.1, 0.338, -0.04))
    pri_line = (V(0.1, 0.312, 0.05), V(0.1, 0.32, 0.0))

    def add(root, aim, length, layer, root_o, d_o, width, region, kind, **shape):
        root_f, n_f = flank(root, layer)
        tip_f, _ = flank(root + aim.normalized() * length, layer + 0.006)
        d_f = tip_f - root_f
        n_o = up_o
        if side < 0:
            root_f, d_f, n_f = mx(root_f), mx(d_f), mx(n_f)
            root_o, d_o, n_o = mx(root_o), mx(d_o), mx(n_o)
        feather(part, root_f, d_f, n_f, length, width, region, kind, open_frame=(root_o, d_o, n_o), **shape)

    # Primaries: from the tip of the hand inwards; folded they lie lowest, the outer under.
    for j in range(10):
        u = j / 9.0
        root_o = t_o.lerp(w_o, u * 0.95)
        a = 1.25 - 0.95 * u
        d_o = V(math.sin(a), 0.0, -math.cos(a))
        root = pri_line[0].lerp(pri_line[1], u)
        length = 0.2 - 0.03 * u
        add(root, V(0.0, -0.1, -1.0), length, 0.004 + 0.0006 * j, root_o, d_o, 0.045, FLIGHT, "flight", lift=0.0, bend=-0.03, cup=0.06, rows=3, skew=0.3)
    # Secondaries: along the forearm, from the wrist in; folded, the inner ones on top.
    for j in range(10):
        u = j / 9.0
        root_o = w_o.lerp(e_o, u).lerp(s_o, 0.25 * u * u)
        a = 0.25 - 0.3 * u
        d_o = V(math.sin(a), 0.0, -math.cos(a))
        root = sec_line[0].lerp(sec_line[1], u)
        length = 0.165 - 0.012 * u
        add(root, V(0.0, -0.36 + 0.12 * u, -1.0), length, 0.011 + 0.0012 * j, root_o, d_o, 0.05, FLIGHT, "flight", lift=0.0, bend=-0.03, cup=0.08, rows=3, skew=0.2)
    # Greater, middle and lesser coverts over the secondaries' roots, up to the leading edge.
    for row, (length, width, back) in enumerate(((0.07, 0.042, 0.0), (0.052, 0.036, 0.03), (0.038, 0.03, 0.055))):
        for j in range(8):
            u = j / 7.0
            root_o = w_o.lerp(s_o + V(0.02, 0.0, 0.0), u) + V(0.0, 0.004 * (row + 1), 0.015 + back * 0.5)
            d_o = V(0.1, 0.0, -1.0)
            root = sec_line[0].lerp(sec_line[1], u) + V(0.0, 0.008 + 0.01 * row, 0.02 + 0.008 * row - 0.012 * u)
            add(root, V(0.0, -0.3, -1.0), length, 0.026 + 0.003 * row, root_o, d_o, width, COVERT, "round", lift=0.1, cup=0.12, rows=2)
    return part


def leg(side, rooster_spur):
    """A leg: the feathered drumstick, the hock, the scaly shank and the toes."""
    k = V(KNEE.x * side, KNEE.y, KNEE.z)
    a = V(HOCK.x * side, HOCK.y, HOCK.z)
    f = V(FOOT.x * side, FOOT.y, FOOT.z)
    name = "l" if side > 0 else "r"
    # The drumstick: a fluffy tapering cluster of feathers from the knee down to the hock.
    thigh = Part("thigh_" + name, "feather")
    down = (a - k).normalized()
    for r in range(3):
        u = r / 3.0
        centre = k.lerp(a, 0.05 + 0.6 * u)
        radius = 0.042 * (1.0 - 0.55 * u)
        for q in range(8):
            ang = math.tau * (q + 0.5 * (r % 2)) / 8
            side_v = down.cross(V(0, 0, 1)).normalized()
            front_v = side_v.cross(down).normalized()
            out = side_v * math.cos(ang) + front_v * math.sin(ang)
            root = centre + out * radius
            d = (down * 1.0 + out * 0.15 + V(0, 0, -0.1)).normalized()
            feather(thigh, root, d, out, rng.uniform(0.05, 0.065), 0.04, BREAST, "round", lift=0.2, cup=0.18, rows=2)
    # The core under them.
    ball(thigh, k.lerp(a, 0.35), (0.035, 0.035, 0.07), 8, 5, axis=down, uv2=(0.5, (BREAST + 0.5) / 8.0))
    shank = Part("shank_" + name, "leg")
    # The shank: from the hock down and forward to the foot, ringed with scales.
    line = [a.lerp(f, t / 9.0) for t in range(10)]
    radii = [0.012 - 0.0022 * (t / 9.0) for t in range(10)]
    radii[0] = 0.015

    def scales(kk, i):
        # (a ring of scales at each step, and a row of big scutes down the front)
        bump = 0.0012 * (1 if (i % 2) == 0 else 0)
        front = 0.0016 if kk in (1, 2) and i > 0 else 0.0
        return bump + front

    tube(shank, line, radii, sides=8, uv2=(0.0, 0.0), cap_end=False, cap_start=True, squash=0.85, ridge=scales, up=V(side, 0, 0))
    # The hock: a knob at the joint.
    ball(shank, a + V(0, 0.003, -0.004), (0.016, 0.015, 0.018), 8, 5)
    # The rooster's spur, low on the back of the shank, curving up.
    spur = None
    if rooster_spur:
        spur = Part("spur_" + name + "__r", "claw")
        base = a.lerp(f, 0.62) + V(-0.004 * side, 0.0, -0.01)
        tube(spur, [base, base + V(-0.006 * side, 0.004, -0.014), base + V(-0.008 * side, 0.012, -0.022)], [0.005, 0.0035, 0.0015], sides=6)
    # The toes: three forward (the middle longest), one back.
    toes = Part("toes_" + name, "leg")
    claws = Part("claws_" + name, "claw")
    for (turn, length, joints) in ((0.0, 0.062, 3), (0.5, 0.048, 3), (-0.5, 0.05, 3), (math.pi, 0.026, 2)):
        ang = turn * side
        d = V(math.sin(ang), 0.0, math.cos(ang))
        if turn == math.pi:
            d = V(0.15 * side, 0.0, -1.0).normalized()
        start = V(f.x, 0.012, f.z)
        pts = []
        rad = []
        for j in range(joints * 2 + 1):
            t = j / (joints * 2)
            # (the toe arches a little between the knuckles, the end touching down)
            pts.append(start + d * length * t + V(0, 0.002 * math.sin(math.pi * t) - 0.004 * t, 0))
            rad.append((0.0075 - 0.003 * t) * (1.12 if j % 2 == 0 else 0.96))
        # UV2.x is how far along the toe it is, for the shader's curl.
        tube(toes, pts, rad, sides=6, uv2=(0.0, 0.0), cap_end=False, squash=0.7, up=V(0, 1, 0))
        for i in range(len(toes.uv2)):
            pass
        nail_root = pts[-1]
        tube(claws, [nail_root, nail_root + d * 0.01 + V(0, -0.003, 0), nail_root + d * 0.016 + V(0, -0.008, 0)], [0.0045, 0.003, 0.0008], sides=4)
    # The ball of the foot, where the toes meet.
    ball(toes, V(f.x, 0.013, f.z), (0.013, 0.008, 0.013), 8, 4, axis=V(0, 1, 0))
    return [thigh, shank, toes, claws] + ([spur] if spur else [])


def comb(rooster):
    """The single comb: a fleshy serrated blade along the top of the head,
    from the beak back over the skull."""
    part = Part("comb__r" if rooster else "comb__h", "comb")
    points = 6 if rooster else 5
    height = 0.062 if rooster else 0.028
    thick = 0.011 if rooster else 0.008
    front = HEAD.z + 0.032
    back = HEAD.z - (0.05 if rooster else 0.028)
    columns = points * 3
    rows = 3
    # A ribbon standing on the skull: columns from the front to the back, each
    # from the base up to the top edge (points with rounded notches between),
    # thick in the middle and thin at the edge and the ends.
    grid = []
    for i in range(columns + 1):
        t = i / columns
        z = front + (back - front) * t
        # (the skull's curve under it)
        base = HEAD.y + 0.02 - 0.5 * ((z - HEAD.z - 0.004) / 0.05) ** 2 * 0.02
        arch = math.sin(math.pi * (0.04 + 0.92 * t)) ** 0.7
        tooth = math.cos(math.pi * (points * t - 0.5)) ** 2
        top = base + height * (0.35 + 0.65 * arch) * (0.5 + 0.5 * tooth ** 0.6)
        # (the blade at the back runs out over the neck)
        back_lean = 0.012 * max(t - 0.8, 0.0) / 0.2 if rooster else 0.0
        ends = math.sin(math.pi * min(max(t, 0.02), 0.98)) ** 0.35
        column = []
        for r in range(rows + 1):
            v = r / rows
            y = base + (top - base) * v
            half = thick * 0.5 * ends * (1.0 - v ** 3) ** 0.6
            pair = []
            for sign in (1.0, -1.0):
                pair.append(part.v((sign * half, y, z - back_lean * v), (v, t)))
            column.append(pair)
        grid.append(column)
    for i in range(columns):
        for r in range(rows):
            for s in (0, 1):
                quad = [grid[i][r][s], grid[i + 1][r][s], grid[i + 1][r + 1][s], grid[i][r + 1][s]]
                part.f(quad if s == 1 else list(reversed(quad)))
    return part


def wattles(rooster):
    """Two lobes hanging under the beak, side by side."""
    part = Part("wattle__r" if rooster else "wattle__h", "comb")
    length = 0.055 if rooster else 0.026
    for side in (1.0, -1.0):
        outline = []
        for i in range(12):
            a = math.tau * i / 16
            # (a drop: narrow at the top, round at the bottom)
            y = -length * 0.5 * (1.0 - math.cos(a)) * 1.0
            z = math.sin(a) * length * 0.32 * (0.6 + 0.4 * (1.0 - math.cos(a)) / 2.0)
            outline.append((HEAD.y - 0.008 + y, HEAD.z + 0.033 + z))
        slab(part, outline, 0.008 if rooster else 0.007, middle_x=side * 0.0055, puff=0.55)
    return part


def ear_lobes():
    part = Part("lobes", "lobe")
    for side in (1.0, -1.0):
        ball(part, HEAD + V(side * 0.019, -0.016, -0.006), (0.004, 0.009, 0.007), 8, 5, axis=V(side, 0, 0))
    return part


def beak():
    """The upper mandible, a curved wedge that hooks over at the tip, and the
    lower, finer, under it."""
    upper = Part("beak", "beak")
    lower = Part("jaw", "beak")
    base = HEAD + V(0.0, -0.002, 0.03)
    rows = 6
    for part, top, depth, length, drop in ((upper, 1.0, 0.012, 0.032, 0.007), (lower, -1.0, 0.006, 0.026, 0.0)):
        rings = []
        for r in range(rows + 1):
            t = r / rows
            width = 0.0105 * (1.0 - t) ** 0.8 + 0.0008
            height = depth * (1.0 - t) ** 0.7 + 0.0006
            z = base.z + length * t
            y = base.y - drop * t * t - (0.0 if top > 0 else 0.004)
            ring = []
            for k in range(8):
                a = math.tau * k / 8
                # (the upper is a rounded ridge over a flat underside; the lower the reverse)
                cy = math.sin(a)
                if top > 0:
                    cy = cy * height if cy > 0 else cy * 0.0015
                else:
                    cy = cy * 0.0015 if cy > 0 else cy * height
                ring.append(part.v((math.cos(a) * width, y + cy, z), (k / 8.0, t)))
            rings.append(ring)
        for r in range(rows):
            for k in range(8):
                a, b = rings[r][k], rings[r][(k + 1) % 8]
                c, d = rings[r + 1][(k + 1) % 8], rings[r + 1][k]
                part.f([a, b, c, d])
        tip = part.v((0.0, base.y - drop * 1.15 - (0.002 if top > 0 else 0.004), base.z + length * 1.03), (0.0, 1.0))
        for k in range(8):
            part.f([rings[-1][k], rings[-1][(k + 1) % 8], tip])
    nostril = Part("nostril", "nostril")
    for side in (1.0, -1.0):
        ball(nostril, base + V(side * 0.0055, 0.008, 0.007), (0.0012, 0.0018, 0.003), 6, 3, axis=V(0, 0, 1))
    return [upper, lower, nostril]


def eyes():
    part = Part("eye", "eye")
    for side in (1.0, -1.0):
        axis = V(side, 0.05, 0.25).normalized()
        ball(part, HEAD + V(side * 0.0185, 0.004, 0.012), (0.0075, 0.0075, 0.0055), 8, 5, axis=axis, polar_uv=True)
    return part


def build():
    clear()
    made = []
    body = body_part()
    made.append(body)
    tree = BVHTree.FromObject(body, bpy.context.evaluated_depsgraph_get())
    parts = [body_feathers(tree), neck_feathers(tree, False), neck_feathers(tree, True), saddle_feathers(tree), tail(False), tail(True)]
    for side in (1.0, -1.0):
        parts.extend(leg(side, True))
    parts += [comb(False), comb(True), wattles(False), wattles(True), ear_lobes(), eyes()] + beak()
    for part in parts:
        made.append(part.make())
    for side in (1.0, -1.0):
        made.append(wing(side, tree).make(with_open=True))
    triangles = 0
    bpy.ops.object.select_all(action="DESELECT")
    for thing in made:
        count = sum(len(p.vertices) - 2 for p in thing.data.polygons)
        triangles += count
        print("  %s: %d" % (thing.name, count))
        thing.select_set(True)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_animations=False,
                              use_selection=True, export_morph=True, export_morph_normal=True, export_apply=False)
    print("BUILT chicken: %d triangles in %d objects" % (triangles, len(made)))
    return made


def previews(folder, made, only=None):
    """Pictures from Blender (flat colours): side, front, three-quarter, back,
    of the hen (the rooster's parts hidden) and of the rooster."""
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_WORKBENCH",):
        try:
            scene.render.engine = engine
        except TypeError:
            pass
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.film_transparent = False
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 85
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = B(V(0.0, 0.3, 0.0))
    for who in ("hen", "rooster"):
        for thing in made:
            hide = (who == "hen" and thing.name.endswith("__r")) or (who == "rooster" and thing.name.endswith("__h"))
            if only and not any(thing.name.startswith(o) for o in only):
                hide = True
            thing.hide_render = hide
        for view, offset in (("side", V(1.6, 0.25, 0.0)), ("front", V(0.0, 0.2, 1.6)), ("three_quarter", V(1.1, 0.45, 1.1)), ("back", V(-0.8, 0.5, -1.4)), ("head", V(0.25, 0.05, 0.35))):
            look_at = target if view != "head" else B(HEAD)
            where = (B(V(0, 0.3, 0)) + B(offset)) if view != "head" else B(HEAD + offset)
            cam.location = where
            direction = look_at - where
            cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(folder, "%s_%s.png" % (who, view))
            bpy.ops.render.render(write_still=True)


made_now = build()
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if args:
    previews(args[0], made_now, args[1].split(",") if len(args) > 1 else None)
